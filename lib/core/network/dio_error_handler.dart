import 'package:dio/dio.dart';

/// Dio ve Ağ Hatalarını Yöneten Kurumsal Hata Dönüştürücü
class DioErrorHandler {
  /// Hatayı kullanıcı dostu Türkçe açıklamaya dönüştürür
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
          return 'Sunucu yanıt vermiyor. Bağlantı zaman aşımına uğradı.';
        case DioExceptionType.receiveTimeout:
          return 'Sunucudan veri alma zaman aşımına uğradı.';
        case DioExceptionType.connectionError:
          return 'Sunucuya bağlanılamadı. İnternet bağlantınızı veya VPN/Tünel durumunu kontrol edin.';
        case DioExceptionType.badCertificate:
          return 'Güvenlik sertifikası doğrulanamadı (SSL/TLS Hatası).';
        case DioExceptionType.cancel:
          return 'İstek iptal edildi.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final responseData = error.response?.data;
          
          // Eğer FastAPI detail alanı döndüyse onu al
          String? serverDetail;
          if (responseData is Map<String, dynamic> && responseData.containsKey('detail')) {
            serverDetail = responseData['detail'].toString();
          }

          switch (statusCode) {
            case 400:
              return serverDetail ?? 'Geçersiz istek gönderildi. Lütfen girdiğiniz bilgileri kontrol edin.';
            case 401:
              return serverDetail ?? 'Oturum süreniz doldu veya yetkisiz işlem. Lütfen tekrar giriş yapın.';
            case 403:
              return serverDetail ?? 'Bu işlemi yapmak için yetkiniz (Örn: Patron rolü) bulunmuyor.';
            case 404:
              return serverDetail ?? 'İstenen kaynak veya parça sunucuda bulunamadı.';
            case 409:
              return serverDetail ?? 'Çakışma hatası: Bu kayıt sistemde zaten mevcut olabilir.';
            case 422:
              return serverDetail ?? 'Doğrulama hatası: Sunucu gönderilen veri şemasını kabul etmedi.';
            case 500:
            case 502:
            case 503:
              return serverDetail ?? 'Sunucu şu an meşgul, lütfen tekrar deneyin.';
            default:
              return serverDetail ?? 'Sunucu hatası: HTTP $statusCode';
          }
        case DioExceptionType.unknown:
        default:
          return 'Beklenmeyen bir ağ hatası oluştu. Lütfen tekrar deneyin.';
      }
    }

    if (error is FormatException) {
      return 'Veri formatı hatalı işlendi.';
    }

    String msg = error.toString();
    msg = msg.replaceAll(RegExp(r'^Exception:\s*'), '');
    msg = msg.replaceAll(RegExp(r'^API Hatası:\s*'), '');
    if (msg.contains('DioException') || msg.contains('bad response')) {
      if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
        return 'Sunucu şu an meşgul, lütfen tekrar deneyin.';
      }
      if (msg.contains('404')) {
        return 'İstenen kaynak veya parça sunucuda bulunamadı.';
      }
      return 'Sunucuyla iletişim kurulurken bir hata oluştu.';
    }
    return msg.trim();
  }

  /// Hatayı analiz ederek bağlantı kopukluğu (offline) durumu olup olmadığını belirler
  static bool isConnectionError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('failed host lookup') ||
        str.contains('network is unreachable');
  }
}
