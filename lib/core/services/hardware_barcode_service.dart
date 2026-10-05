import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/spare_parts/models/spare_part_model.dart';
import '../../features/spare_parts/models/sale_record_model.dart';
import '../../features/spare_parts/providers/spare_part_provider.dart';
import '../../features/spare_parts/views/part_detail_page.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/print_label_modal_sheet.dart';

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

/// Tüm uygulamayı saran Global Barkod Dinleyici Bileşeni (MaterialApp.builder içinde kullanılır)
class GlobalBarcodeListenerWidget extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalBarcodeListenerWidget({super.key, required this.child});

  @override
  ConsumerState<GlobalBarcodeListenerWidget> createState() =>
      _GlobalBarcodeListenerWidgetState();
}

class _GlobalBarcodeListenerWidgetState
    extends ConsumerState<GlobalBarcodeListenerWidget> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    final service = ref.read(hardwareBarcodeServiceProvider);
    _sub = service.onBarcodeScanned.listen(_handleScannedBarcode);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleScannedBarcode(String barcode) async { 
    if (HardwareBarcodeService().isGlobalModalSuppressed) return; 

    final localParts = ref.read(sparePartsProvider).value ?? []; 
    SparePart? matchedPart; 

    try { 
      matchedPart = localParts.firstWhere( 
        (p) => 
            (p.barcode != null && p.barcode!.trim().toLowerCase() == barcode.toLowerCase()) || 
            (p.oemCode != null && p.oemCode!.trim().toLowerCase() == barcode.toLowerCase()), 
      ); 
    } catch (_) { 
      matchedPart = null; 
    } 

    if (matchedPart == null) { 
      try { 
        final repo = ref.read(sparePartRepositoryProvider); 
        final results = await repo.getSpareParts(query: barcode, limit: 1); 
        if (results.isNotEmpty) { 
          matchedPart = results.first; 
        } 
      } catch (e) { 
        debugPrint('Barkod sunucu sorgusu başarısız: $e'); 
      } 
    } 

    if (!mounted) return; 

    if (matchedPart != null) { 
      // PARÇA BULUNDU! DOĞRUDAN ETİKET BASMA VE STOK EKLEME PANELİNİ AÇ
      PrintLabelBottomSheet.show(context, part: matchedPart);
    } else { 
      // Parça bulunamadı
      AppSnackBar.showWarning( 
        context, 
        'Barkod Okundu: "$barcode" (Sistemde kayıtlı ürün bulunamadı)', 
      ); 
    } 
  } 

// (En alttaki eski _showBarcodeActionModal ve _showDirectSaleModal fonksiyonlarını tamamen SİLEBİLİRSİN, artık onlara ihtiyacımız yok).

  void _showBarcodeActionModal(SparePart part) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isOutOfStock = part.stockQuantity <= 0;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Colors.blueGrey, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Donanım Barkodu Okundu',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          part.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Barkod: ${part.barcode ?? 'Belirtilmemiş'}',
                    style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'OEM: ${part.oemCode ?? '-'}',
                    style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Satış Fiyatı: ₺${part.sellPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutOfStock ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOutOfStock ? 'STOK TÜKENDİ' : 'Stok: ${part.stockQuantity} Adet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock ? Colors.red : Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PartDetailPage(part: part)),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Ürün Detayı'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock ? Colors.grey : Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isOutOfStock
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _showDirectSaleModal(part);
                            },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('Hızlı Satış', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDirectSaleModal(SparePart part) {
    final qtyCtrl = TextEditingController(text: '1');
    final buyerCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          int qty = int.tryParse(qtyCtrl.text) ?? 1;
          double total = qty * part.sellPrice;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Satışı Onayla: ${part.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Adet: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: qty > 1 ? () => setMState(() => qtyCtrl.text = '${qty - 1}') : null,
                    ),
                    Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: qty < part.stockQuantity ? () => setMState(() => qtyCtrl.text = '${qty + 1}') : null,
                    ),
                    const Spacer(),
                    Text('₺${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                TextField(
                  controller: buyerCtrl,
                  decoration: const InputDecoration(labelText: 'Müşteri / Plaka (Opsiyonel)'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final record = SaleRecord(
                        partId: part.id!,
                        partName: part.name,
                        quantity: qty,
                        unitPrice: part.sellPrice,
                        totalPrice: total,
                        buyerName: buyerCtrl.text.trim(),
                      );
                      try {
                        await ref.read(sparePartsProvider.notifier).recordSale(record);
                        if (mounted) {
                          AppSnackBar.showSuccess(context, 'Satış başarıyla kaydedildi!');
                        }
                      } catch (e) {
                        if (mounted) {
                          AppSnackBar.showError(context, 'Satış kaydedilemedi: $e');
                        }
                      }
                    },
                    child: const Text('SATIŞI TAMAMLA', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
