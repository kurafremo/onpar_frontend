import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/dio_client.dart';

/// Kurumsal B2B Anlık Bildirim (Push Notification - FCM / OneSignal) Servisi
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _storage = const FlutterSecureStorage();
  static const String _tokenStorageKey = 'device_push_token';

  /// Cihaz bildirim token'ını backend'e (/api/notifications/register-device) kaydeder
  Future<bool> registerDeviceToken({String? customToken, String? authToken}) async {
    try {
      // 1. JWT Yetkilendirme Token Doğrulaması
      String? jwt = authToken;
      if (jwt == null || jwt.isEmpty) {
        final headerAuth = dioClient.options.headers['Authorization'];
        if (headerAuth != null && headerAuth.toString().isNotEmpty) {
          jwt = headerAuth.toString().replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '').trim();
        }
      }
      if (jwt == null || jwt.isEmpty) {
        jwt = await _storage.read(key: 'jwt_token');
      }

      // Güvenlik Kilidi: Eğer geçerli bir kullanıcı JWT oturumu yoksa istek atma (401 engelleme)
      if (jwt == null || jwt.isEmpty) {
        debugPrint('[NOTIFICATION] Yetkilendirme token\'ı (JWT) bulunamadı. Cihaz kaydı atlanıyor.');
        return false;
      }

      // Dio headers'ında Authorization olduğundan emin ol
      dioClient.options.headers['Authorization'] = 'Bearer $jwt';

      // 2. Cihaz Push Token'ını Hazırla
      String token = customToken ?? '';
      
      // Eğer dışarıdan FCM/OneSignal token verilmediyse, kayıtlı veya benzersiz cihaz kimliği üret
      if (token.isEmpty) {
        final saved = await _storage.read(key: _tokenStorageKey);
        if (saved != null && saved.isNotEmpty) {
          token = saved;
        } else {
          // Kurumsal Deterministik Cihaz Token Simülasyonu (FCM / OneSignal bağlandığında gerçek token alınır)
          final platformPrefix = kIsWeb
              ? 'web'
              : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'desktop'));
          token = 'fcm_token_${platformPrefix}_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
          await _storage.write(key: _tokenStorageKey, value: token);
        }
      }

      final platformStr = kIsWeb
          ? 'web'
          : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'));

      debugPrint('[NOTIFICATION] Cihaz token backend\'e kaydediliyor: $token ($platformStr)');

      Response response;
      try {
        response = await dioClient.post(
          '/api/notifications/register-device',
          data: {
            'token': token,
            'platform': platformStr,
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $jwt',
            },
          ),
        );
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 404) {
          // Kök rota yedeği
          response = await dioClient.post(
            '/notifications/register-device',
            data: {
              'token': token,
              'platform': platformStr,
            },
            options: Options(
              headers: {
                'Authorization': 'Bearer $jwt',
              },
            ),
          );
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[NOTIFICATION] Cihaz bildirim kaydı başarılı: ${response.data}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[NOTIFICATION] Cihaz token kayıt hatası (Login akışını etkilemez): $e');
      return false;
    }
  }

  /// Kayıtlı token'ı getir
  Future<String?> getSavedToken() async {
    return await _storage.read(key: _tokenStorageKey);
  }
}