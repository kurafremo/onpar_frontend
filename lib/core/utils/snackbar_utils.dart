import 'package:flutter/material.dart';

/// Global ScaffoldMessengerKey: Context bulunmayan yerlerden (Interceptor, Servisler)
/// doğrudan kurumsal bildirim gösterebilmek için kullanılır.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Global NavigatorKey: Context bulunmayan yerlerden (Interceptor, Arka Plan Servisleri)
/// doğrudan navigasyon yönlendirmesi (Örn: Oturum süresi dolunca Login sayfasına geçiş) yapmak için kullanılır.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// On-Par Otomotiv Kurumsal Bildirim Motoru
class AppSnackBar {
  static void showSuccess(
    BuildContext? context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior? behavior,
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFF1B5E20), // Koyu Yeşil
      icon: Icons.check_circle_outline,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      behavior: behavior,
    );
  }

  static void showError(
    BuildContext? context,
    String message, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior? behavior,
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFFB71C1C), // Kurumsal Kırmızı
      icon: Icons.error_outline,
      actionLabel: onRetry != null ? 'Tekrar Dene' : null,
      onAction: onRetry,
      duration: duration,
      behavior: behavior,
    );
  }

  static void showWarning(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior? behavior,
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFFE65100), // Koyu Turuncu
      icon: Icons.warning_amber_rounded,
      duration: duration,
      behavior: behavior,
    );
  }

  static void showInfo(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior? behavior,
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFF263238), // BlueGrey Dark
      icon: Icons.info_outline,
      duration: duration,
      behavior: behavior,
    );
  }

  static void showOffline(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior? behavior,
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFF37474F), // Slate Grey
      icon: Icons.wifi_off_rounded,
      duration: duration,
      behavior: behavior,
    );
  }

  static void _show({
    required BuildContext? context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior? behavior,
  }) {
    final effectiveBehavior = behavior ??
        (context != null
            ? (Theme.of(context).snackBarTheme.behavior ?? SnackBarBehavior.floating)
            : SnackBarBehavior.floating);
    final isFloating = effectiveBehavior == SnackBarBehavior.floating;

    final snackBar = SnackBar(
      elevation: 6,
      behavior: effectiveBehavior,
      margin: isFloating ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12) : null,
      shape: isFloating ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) : null,
      backgroundColor: backgroundColor,
      duration: duration,
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.yellowAccent,
              onPressed: onAction ?? () {},
            )
          : null,
    );

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    } else {
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    }
  }
}

/// Geriye dönük uyumluluk ve takma ad (Alias)
typedef SnackBarUtils = AppSnackBar;
