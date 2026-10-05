import 'package:flutter/material.dart';
import '../network/dio_error_handler.dart';

/// Kurumsal Durum ve Geri Bildirim Görselleştirme Motoru
/// Kırmızı hata kutularını önler; yerine şık, kurumsal ve aksiyon alınabilir arayüzler sunar.
class StateFeedbackWidget extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const StateFeedbackWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  /// Boş Durum (Veri Yok) Tasarımı
  factory StateFeedbackWidget.empty({
    Key? key,
    IconData icon = Icons.inbox_outlined,
    String title = 'Kayıt Bulunamadı',
    String message = 'Görüntülenecek herhangi bir veri kaydı bulunmuyor.',
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return StateFeedbackWidget(
      key: key,
      icon: icon,
      iconColor: Colors.blueGrey,
      iconBgColor: Colors.blueGrey.withValues(alpha: 0.08),
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: onAction,
    );
  }

  /// Çevrimdışı / Bağlantı Hatası Tasarımı
  factory StateFeedbackWidget.offline({
    Key? key,
    String title = 'Bağlantı Kurulamadı',
    String message = 'Sunucuya ulaşılamıyor. İnternet bağlantınızı veya ağ durumunu kontrol edin.',
    VoidCallback? onRetry,
  }) {
    return StateFeedbackWidget(
      key: key,
      icon: Icons.wifi_off_rounded,
      iconColor: Colors.orange[800]!,
      iconBgColor: Colors.orange.withValues(alpha: 0.1),
      title: title,
      message: message,
      actionLabel: onRetry != null ? 'Tekrar Dene' : null,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
    );
  }

  /// Yetkisiz Erişim (403 Forbidden) Tasarımı
  factory StateFeedbackWidget.forbidden({
    Key? key,
    String title = 'Yetkisiz İşlem',
    String message = 'Bu verileri görüntülemek veya bu işlemi yapmak için yetkiniz (Örn: Patron rolü) bulunmuyor.',
    VoidCallback? onRetry,
  }) {
    return StateFeedbackWidget(
      key: key,
      icon: Icons.lock_outline_rounded,
      iconColor: Colors.amber[900]!,
      iconBgColor: Colors.amber.withValues(alpha: 0.12),
      title: title,
      message: message,
      actionLabel: onRetry != null ? 'Yenile' : null,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
    );
  }

  /// Genel Hata Çözümleyici ve Gösterici
  /// Hata nesnesini otomatik analiz eder (Bağlantı, 403 veya Genel Hata)
  factory StateFeedbackWidget.error({
    Key? key,
    required dynamic error,
    VoidCallback? onRetry,
    String? customTitle,
    String? customMessage,
  }) {
    final errorString = error.toString().toLowerCase();

    // 1. Bağlantı / Çevrimdışı Hatası Kontrolü
    if (DioErrorHandler.isConnectionError(error)) {
      return StateFeedbackWidget.offline(key: key, onRetry: onRetry);
    }

    // 2. Yetkisiz Erişim Kontrolü
    if (errorString.contains('403') || errorString.contains('yetki')) {
      return StateFeedbackWidget.forbidden(
        key: key,
        message: customMessage ?? DioErrorHandler.getErrorMessage(error),
        onRetry: onRetry,
      );
    }

    // 3. Genel Sunucu / API Hatası
    final friendlyMessage = customMessage ?? DioErrorHandler.getErrorMessage(error);
    final isServerError = errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        friendlyMessage.toLowerCase().contains('meşgul') ||
        friendlyMessage.toLowerCase().contains('sunucu');
    final isNotFound = errorString.contains('404') || friendlyMessage.toLowerCase().contains('bulunamadı');

    final IconData displayIcon;
    final Color displayColor;
    final Color displayBg;
    final String displayTitle;

    if (isServerError) {
      displayIcon = Icons.dns_outlined;
      displayColor = Colors.orange[800]!;
      displayBg = Colors.orange.withValues(alpha: 0.1);
      displayTitle = customTitle ?? 'Sunucu Şu An Meşgul';
    } else if (isNotFound) {
      displayIcon = Icons.search_off_rounded;
      displayColor = Colors.blueGrey[700]!;
      displayBg = Colors.blueGrey.withValues(alpha: 0.08);
      displayTitle = customTitle ?? 'Kayıt Bulunamadı';
    } else {
      displayIcon = Icons.error_outline_rounded;
      displayColor = Colors.red[700]!;
      displayBg = Colors.red.withValues(alpha: 0.08);
      displayTitle = customTitle ?? 'Bir Sorun Oluştu';
    }

    return StateFeedbackWidget(
      key: key,
      icon: displayIcon,
      iconColor: displayColor,
      iconBgColor: displayBg,
      title: displayTitle,
      message: friendlyMessage,
      actionLabel: onRetry != null ? 'Tekrar Dene' : null,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Yumuşak İkon Arka Planı
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 40,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Başlık
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Açıklayıcı Mesaj
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

            // Aksiyon Butonu (Örn: Tekrar Dene)
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[800],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
