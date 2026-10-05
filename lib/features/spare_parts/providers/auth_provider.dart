import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:on_par/core/network/dio_client.dart';
import 'package:on_par/core/services/notification_service.dart';
import '../../../core/network/dio_error_handler.dart';

const _secureStorage = FlutterSecureStorage();

class AppUser {
  final String username;
  final String role;
  AppUser({required this.username, required this.role});

  bool get isAdmin =>
      role.toLowerCase() == 'patron' || role.toLowerCase() == 'admin';
}

Map<String, dynamic> _decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw Exception('Geçersiz Token Formatı');
  final payload = parts[1];
  final normalized = base64Url.normalize(payload);
  final resp = utf8.decode(base64Url.decode(normalized));
  return json.decode(resp);
}

class AuthNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    _checkSavedToken();
    return null; 
  }

  /// Uygulama açılırken kaydedilmiş token'ları kontrol eder ve gerekirse sessizce yeniler
  Future<void> _checkSavedToken() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    final refreshToken = await _secureStorage.read(key: 'refresh_token');

    if (token != null && token.isNotEmpty) {
      try {
        final decodedData = _decodeJwt(token);
        final exp = decodedData['exp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        
        if (now < exp) {
          // [KURAL 1]: Uygulama ilk açıldığında kaydedilen token varsa, bunu Dio headers'ına eklemeden API isteklerini başlatma.
          dioClient.options.headers['Authorization'] = 'Bearer $token';

          state = AppUser(
            username: decodedData['sub'] ?? '',
            role: decodedData['role'] ?? 'çalışan',
          );
          // [KURAL 2]: Bildirim kaydını senkronize et ve güvenle bekle
          try {
            await NotificationService().registerDeviceToken(authToken: token);
          } catch (e) {
            debugPrint('[AUTH] Başlangıç bildirim cihaz kaydı hatası (sessiz): $e');
          }
          return;
        }
      } catch (_) {}
    }

    // Access token süresi bitmişse, Refresh Token ile oturumu otomatik ayağa kaldır
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final response = await dioClient.post(
          '/api/refresh-token',
          data: {'refresh_token': refreshToken},
        );

        if (response.statusCode == 200 && response.data != null) {
          final newAccessToken = response.data['access_token'];
          final newRefreshToken = response.data['refresh_token'];

          if (newAccessToken != null && newAccessToken.toString().isNotEmpty) {
            final accToken = newAccessToken.toString();
            await _secureStorage.write(key: 'jwt_token', value: accToken);
            dioClient.options.headers['Authorization'] = 'Bearer $accToken';
          }
          if (newRefreshToken != null && newRefreshToken.toString().isNotEmpty) {
            await _secureStorage.write(key: 'refresh_token', value: newRefreshToken.toString());
          }

          final decoded = _decodeJwt(newAccessToken.toString());
          state = AppUser(
            username: decoded['sub'] ?? '',
            role: decoded['role'] ?? 'çalışan',
          );
          try {
            await NotificationService().registerDeviceToken(authToken: newAccessToken.toString());
          } catch (e) {
            debugPrint('[AUTH] Refresh sonrası bildirim cihaz kaydı hatası (sessiz): $e');
          }
          return;
        }
      } catch (_) {
        await logout();
      }
    } else {
      await logout();
    }
  }

  /// [GÖREV 1]: OAuth2 Standart Form-Data ile Güvenli Giriş (/api/login)
  Future<void> login(String username, String password) async {
    try {
      final cleanUsername = username.trim();
      final cleanPassword = password.trim();

      // Backend SADECE application/x-www-form-urlencoded ve 'username', 'password' alanlarını kabul eder!
      final formData = {
        'username': cleanUsername,
        'password': cleanPassword,
      };

      Response response;
      try {
        response = await dioClient.post(
          '/api/login',
          data: formData,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
          ),
        );
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 404) {
          // Kök rota yedeği
          response = await dioClient.post(
            '/login',
            data: formData,
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
            ),
          );
        } else {
          rethrow;
        }
      }

      final token = response.data['access_token'];
      final refreshToken = response.data['refresh_token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Sunucudan geçerli bir kimlik doğrulama anahtarı alınamadı.');
      }

      final tokenStr = token.toString();

      // [KURAL 1]: Token değerini güvenli bir şekilde kaydet VE uygulamanın Dio instance'ının Headers'ına anında ekle
      await _secureStorage.write(key: 'jwt_token', value: tokenStr);
      dioClient.options.headers['Authorization'] = 'Bearer $tokenStr';

      if (refreshToken != null && refreshToken.toString().isNotEmpty) {
        await _secureStorage.write(key: 'refresh_token', value: refreshToken.toString());
      }

      // Backend'den rol bilgisini güvenle ayıkla
      String userRole = 'çalışan';
      if (response.data is Map) {
        final data = response.data as Map;
        if (data['user_info'] != null && data['user_info']['role'] != null) {
          userRole = data['user_info']['role'].toString();
        } else if (data['role'] != null) {
          userRole = data['role'].toString();
        }
      }
      
      if (userRole == 'çalışan') {
        try {
          final decodedData = _decodeJwt(tokenStr);
          userRole = decodedData['role'] ?? 'çalışan';
        } catch (_) {}
      }

      state = AppUser(
        username: cleanUsername,
        role: userRole,
      );

      // [KURAL 2]: Bildirim Kaydı Sıralaması
      // api/notifications/register-device isteği kesinlikle Login işlemi bittikten ve token Dio instance'ına eklendikten SONRA atılmalı (await NotificationService().registerDeviceToken(...)).
      // Bu istek hata alsa bile (örneğin bildirim servisi kapalıysa) kullanıcının login akışını bozmamalı, sessizce loglanmalı.
      try {
        await NotificationService().registerDeviceToken(authToken: tokenStr);
      } catch (notifErr) {
        debugPrint('[AUTH] Cihaz bildirim kaydı hatası (login akışı bozulmadı): $notifErr');
      }

    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        final serverDetail = e.response?.data is Map && e.response?.data['detail'] != null
            ? e.response?.data['detail']
            : 'Hatalı Kullanıcı Adı veya Şifre!';
        throw Exception(serverDetail);
      } else if (e.response?.statusCode == 429) {
        final detail = e.response?.data is Map ? e.response?.data['detail'] : 'Çok fazla deneme yapıldı. Lütfen bekleyin.';
        throw Exception(detail);
      } else {
        throw Exception(DioErrorHandler.getErrorMessage(e));
      }
    }
  }

  /// [GÖREV 1]: Kurumsal Kullanıcı Kaydı (/api/register)
  Future<void> register(String username, String password, {String? masterKey}) async {
    try {
      final cleanUsername = username.trim();
      final cleanPassword = password.trim();
      final assignedRole = (masterKey != null && masterKey.trim().isNotEmpty) ? 'patron' : 'çalışan';

      final payload = {
        'username': cleanUsername,
        'password': cleanPassword,
        'role': assignedRole,
      };

      try {
        await dioClient.post(
          '/api/register',
          data: payload,
        );
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 404) {
          await dioClient.post('/register', data: payload);
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'jwt_token');
    await _secureStorage.delete(key: 'refresh_token');
    dioClient.options.headers.remove('Authorization');
    state = null;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AppUser?>(() {
  return AuthNotifier();
});

final userRoleProvider = Provider<AsyncValue<String>>((ref) {
  final user = ref.watch(authStateProvider);
  if (user == null) {
    return const AsyncData('çalışan');
  }
  return AsyncData(user.role);
});