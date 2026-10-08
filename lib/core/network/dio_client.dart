import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/constants.dart';
import 'dio_error_handler.dart';
import '../utils/snackbar_utils.dart';
import '../../features/spare_parts/views/login_page.dart';

/// Zırhlı Kurumsal Dio İstemcisi (Enterprise Dio Client with Silent Refresh Token Rotation & Dedektif Log)
class DioClient {
  late final Dio _dio;
  late final Dio _refreshDio; // Döngüsel interceptor tetiklenmesini önleyen yalın istemci
  final _storage = const FlutterSecureStorage();

  /// 401 Oturum aşımı anında Riverpod auth state'ini sıfırlayan global callback
  static VoidCallback? onSessionExpired;

  // Eşzamanlı (Concurrent) isteklerin aynı anda birden fazla refresh isteği atmasını önleyen Kilit (Mutex)
  Future<bool>? _refreshFuture;

  /// Dinamik ve Güvenli Base URL Belirleme
  static String getEffectiveBaseUrl() {
    String url = dotenv.env['BASE_URL'] ?? ApiConstants.baseUrl;
    url = url.trim();
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  DioClient() {
    final baseUrl = getEffectiveBaseUrl();
    final baseOptions = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    );

    // 1. Temel API İstemcisi
    _dio = Dio(baseOptions);
    _dio.options.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    // 2. Sadece Token Yenileme İçin Kullanılan Bağımsız İstemci
    _refreshDio = Dio(baseOptions);
    _refreshDio.options.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    // 3. Araya Girici (Interceptor) - Güvenlik, Rota Temizliği ve Sessiz Token Rotasyonu
    _dio.interceptors.add(
      InterceptorsWrapper(
        // İstek Giderken:
        onRequest: (options, handler) async {
          options.baseUrl = getEffectiveBaseUrl();

          var path = options.path.trim();

          // Çift veya çoklu slash'ları teke indir (Örn: //api//login -> /api/login)
          path = path.replaceAll(RegExp(r'/+'), '/');

          // Başta slash yoksa ekle
          if (!path.startsWith('/')) {
            path = '/$path';
          }

          options.path = path;

          // Whitelist kontrolü: Açık rotalara asla token ekleme!
          if (_isPublicRoute(options)) {
            options.headers.remove('Authorization');
            return handler.next(options);
          }

          final token = await _storage.read(key: 'jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        // Hata Geldiğinde:
        onError: (DioException e, handler) async {
          final statusCode = e.response?.statusCode;

          // 1. [GÖREV 3]: SADECE 401 Unauthorized durumunda oturum kapatılır veya yenilenir!
          // 404, 422 veya 500 gibi hatalarda kullanıcı ASLA sistemden atılmaz, token silinmez.
          if (statusCode == 401) {
            if (_isPublicRoute(e.requestOptions)) {
              return handler.next(e);
            } else {
              // Korumalı bir rotada 401 alındı -> Arka planda sessizce Access Token'ı yenilemeyi dene!
              final refreshed = await _refreshToken();
              if (refreshed) {
                final newToken = await _storage.read(key: 'jwt_token');
                final requestOptions = e.requestOptions;
                requestOptions.headers['Authorization'] = 'Bearer $newToken';

                try {
                  final retryResponse = await _dio.fetch(requestOptions);
                  return handler.resolve(retryResponse);
                } catch (retryError) {
                  return handler.next(e);
                }
              }

              // Refresh Token da geçersiz veya süresi dolmuşsa:
              // Oturumu tamamen sonlandır, storage'ı temizle, kullanıcıyı uyar ve Login'e yönlendir!
              await _storage.delete(key: 'jwt_token');
              await _storage.delete(key: 'refresh_token');

              AppSnackBar.showWarning(
                null,
                'Oturum süreniz doldu. Güvenliğiniz için lütfen tekrar giriş yapın.',
              );

              // Riverpod authState'ini sıfırla
              onSessionExpired?.call();

              // Login sayfasına yönlendir
              rootNavigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );

              return handler.next(e);
            }
          }

          // 2. [GÖREV 3]: 403 Forbidden - Yetkisiz İşlem (Patron Rolü vb.)
          if (statusCode == 403) {
            String forbiddenMsg = 'Bu işlemi yapmak için yetkiniz (Örn: Patron rolü) bulunmuyor.';
            final responseData = e.response?.data;
            if (responseData is Map<String, dynamic> && responseData.containsKey('detail')) {
              forbiddenMsg = responseData['detail'].toString();
            }

            // Ekranın altında şık, kurumsal uyarı göster (Oturum kapatılmaz!)
            AppSnackBar.showWarning(null, forbiddenMsg);
            return handler.next(e);
          }

          // 3. [GÖREV 3]: 500+ Sunucu Hatası (Internal Server Error, Service Unavailable vb.)
          // ASLA oturum kapatılmaz, token silinmez! Kullanıcı dostu bildirim gösterilir.
          if (statusCode != null && statusCode >= 500) {
            AppSnackBar.showWarning(
              null,
              'Sunucu şu an meşgul, lütfen tekrar deneyin.',
            );
            return handler.next(e);
          }

          // 4. [GÖREV 3]: 404 Not Found Hatası - Oturum ASLA kapatılmaz!
          if (statusCode == 404) {
            return handler.next(e);
          }

          // 5. Çevrimdışı / Ağ Kopması Durumu
          if (DioErrorHandler.isConnectionError(e)) {
            AppSnackBar.showOffline(
              null,
              'Sunucuya ulaşılamıyor. Çevrimdışı moda geçildi.',
            );
            return handler.next(e);
          }

          // 6. Diğer API Hataları (422 vb.) -> Sadece hatayı ilet, oturumu asla kapatma!
          return handler.next(e);
        },
      ),
    );

    // 4. [LogInterceptor] Dedektif Modu
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ),
    );
  }

  /// Whitelist (Tokensız Açık Rotalar) Kontrol Fonksiyonu
  bool _isPublicRoute(RequestOptions options) {
    final path = options.path.toLowerCase().trim();
    // Bildirim ve cihaz kayıt rotaları kesinlikle token gerektirir
    if (path.contains('register-device') || path.contains('/notifications/')) {
      return false;
    }
    return path == '/login' ||
        path == '/api/login' ||
        path == '/register' ||
        path == '/api/register' ||
        path.contains('/refresh-token') ||
        path == '/health' ||
        path == '/api/health';
  }

  /// Arka planda Refresh Token kullanarak yeni Access Token temin eder
  Future<bool> _refreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = () async {
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken == null || refreshToken.isEmpty) {
          return false;
        }

        _refreshDio.options.baseUrl = getEffectiveBaseUrl();

        final response = await _refreshDio.post(
          '/api/refresh-token',
          data: {'refresh_token': refreshToken},
        );

        if (response.statusCode == 200 && response.data != null) {
          final newAccessToken = response.data['access_token'];
          final newRefreshToken = response.data['refresh_token'];

          if (newAccessToken != null && newAccessToken.toString().isNotEmpty) {
            await _storage.write(key: 'jwt_token', value: newAccessToken.toString());
          }
          if (newRefreshToken != null && newRefreshToken.toString().isNotEmpty) {
            await _storage.write(key: 'refresh_token', value: newRefreshToken.toString());
          }
          return true;
        }
        return false;
      } catch (_) {
        return false;
      } finally {
        _refreshFuture = null;
      }
    }();

    return _refreshFuture!;
  }

  // Dışarıdan Dio objesine erişim
  Dio get instance => _dio;
}

// Tüm uygulamada tek bir DioClient kullanmak için (Singleton instance)
final dioClient = DioClient().instance;