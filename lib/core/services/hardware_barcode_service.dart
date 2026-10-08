import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

export '../widgets/global_barcode_listener.dart';
/// Fiziksel Donanım Barkod Okuyucu Servisi (USB, Bluetooth, El Terminali)
/// Ekranda hiçbir TextField odaklı olmasa dahi donanımdan gelen klavye serilerini yakalar.
class HardwareBarcodeService {
  static final HardwareBarcodeService _instance = HardwareBarcodeService._internal();
  factory HardwareBarcodeService() => _instance;
  HardwareBarcodeService._internal();

  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();

  // Barkod akışını dinlemek isteyen ekranlar için Stream
  final StreamController<String> _barcodeStreamController =
      StreamController<String>.broadcast();
  Stream<String> get onBarcodeScanned => _barcodeStreamController.stream;

  // Form sayfalarında (Örn: Parça Ekleme) global aksiyon modalını susturma bayrağı
  bool isGlobalModalSuppressed = false;

  bool _isListening = false;

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }

  /// TEK MERKEZİ TETİKLEYİCİ: Hem kamera hem de donanım burayı çağırır
  void triggerBarcodeScanned(String barcode) {
    final cleaned = barcode.trim();
    if (cleaned.length >= 3) {
      // Saha Geri Bildirimi: Titreşim ve Bip Sesi
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      debugPrint('[BarcodeManager] Barkod İşleniyor: $cleaned');
      _barcodeStreamController.add(cleaned);
    }
  }

  /// Kamera ile Barkod Okuma Arayüzünü Başlatan Yardımcı
  Future<void> openCameraScanner(BuildContext context) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleBarcodeScannerPage(
          scanType: ScanType.barcode,
          isShowFlashIcon: true,
        ),
      ),
    );

    if (res is String && res.isNotEmpty && res != '-1') {
      triggerBarcodeScanned(res);
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Sadece tuşa basılma anını (KeyDownEvent) yakala
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final difference = now.difference(_lastKeystrokeTime).inMilliseconds;
    _lastKeystrokeTime = now;

    // Eğer iki tuş basımı arası 200 ms'den fazlaysa ve enter gelmediyse,
    // muhtemelen insan klavye yazımıdır veya eski bir okumadır; tamponu sıfırla.
    if (difference > 200 && _buffer.isNotEmpty) {
      _buffer.clear();
    }

    // Barkod okuyucular seri okumayı 'Enter' ile sonlandırır
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final barcode = _buffer.toString();
      _buffer.clear();
      triggerBarcodeScanned(barcode);
      return true;
    }

    // Karakteri tampona ekle
    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      _buffer.write(char);
    }

    return false; // Diğer widget'ların tuş olaylarını bloke etme
  }

  void dispose() {
    stopListening();
    _barcodeStreamController.close();
  }
}

/// Riverpod Sağlayıcısı
final hardwareBarcodeServiceProvider = Provider<HardwareBarcodeService>((ref) {
  final service = HardwareBarcodeService();
  service.startListening();
  ref.onDispose(() => service.stopListening());
  return service;
});

/// Fiziksel Barkod Stream Sağlayıcısı
final hardwareBarcodeStreamProvider = StreamProvider<String>((ref) {
  final service = ref.watch(hardwareBarcodeServiceProvider);
  return service.onBarcodeScanned;
});


