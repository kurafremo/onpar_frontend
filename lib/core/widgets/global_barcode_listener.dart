import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/spare_parts/models/spare_part_model.dart';
import '../../features/spare_parts/providers/cart_provider.dart';
import '../../features/spare_parts/providers/spare_part_provider.dart';
import '../../features/spare_parts/views/add_part_page.dart';
import '../services/hardware_barcode_service.dart';
import '../utils/snackbar_utils.dart';
import 'barcode_action_bottom_sheet.dart';
import 'print_label_modal_sheet.dart';

/// ============================================================================
/// GLOBAL DONANIM BARKOD DİNLİYİCİSİ (GLOBAL HARDWARE BARCODE LISTENER)
/// ============================================================================
/// Ekranda herhangi bir TextField odaklı olsun veya olmasın, USB / Bluetooth /
/// El Terminali fiziksel barkod okuyucularından gelen tüm seri girdileri yakalar.
///
/// "Duruma Bağlı Zeka (Context-Aware)" Mantığı:
/// 1. Parça Bulunamadıysa: AddPartPage'e yönlendir (Barkod otomatik aktarılır).
/// 2. Parça Bulundu ve Stok <= 0 ise: Mal kabul ve raf etiketi basımı için PrintLabelBottomSheet aç.
/// 3. Parça Bulundu ve Stok > 0 ise:
///    - Kullanıcı Sepet/Hızlı Satış sayfasındaysa (Tab 2 - NewSalePage):
///      Doğrudan sepete ekle, kullanıcıyı popup ile bölme, hızlı yeşil SnackBar ver.
///    - Kullanıcı diğer sayfalardaysa (Ana Sayfa, Katalog vb.):
///      Executive Slate temalı Aksiyon Modalı aç (Sepete Ekle vs Mal Kabul/Etiket).
/// ============================================================================
class GlobalBarcodeListenerWidget extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalBarcodeListenerWidget({super.key, required this.child});

  @override
  ConsumerState<GlobalBarcodeListenerWidget> createState() =>
      _GlobalBarcodeListenerWidgetState();
}

class _GlobalBarcodeListenerWidgetState
    extends ConsumerState<GlobalBarcodeListenerWidget> {
  StreamSubscription<String>? _barcodeSubscription;
  DateTime? _lastScannedTime;
  String? _lastScannedBarcode;

  @override
  void initState() {
    super.initState();
    // Donanım barkod servisinin merkezi yayın akışını dinlemeye başla
    final service = ref.read(hardwareBarcodeServiceProvider);
    _barcodeSubscription =
        service.onBarcodeScanned.listen(_handleScannedBarcode);
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    super.dispose();
  }

  /// Barkod Okuma Olay Yöneticisi
  Future<void> _handleScannedBarcode(String barcode) async {
    final cleaned = barcode.trim();
    if (cleaned.isEmpty) return;

    // 0. KORUMA: Form sayfalarında (Örn: Parça Ekleme) veya açık modallarda global aksiyonu sustur
    if (HardwareBarcodeService().isGlobalModalSuppressed) return;

    // 0.1 DEBOUNCE & DEDUPLICATION: Seri okuyuculardan 500 ms içinde gelen mükerrer verileri yoksay
    final now = DateTime.now();
    if (_lastScannedBarcode == cleaned &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!).inMilliseconds < 500) {
      return;
    }
    _lastScannedBarcode = cleaned;
    _lastScannedTime = now;

    // 0.2 FOCUS STEALING ÖNLEMİ: Ekranda arama kutusu vb. TextField odaktaysa klavye odağını düşür
    FocusManager.instance.primaryFocus?.unfocus();

    // 1. Önce yerel önbellekten (Riverpod sparePartsProvider) ara
    final localParts = ref.read(sparePartsProvider).value ?? [];
    SparePart? matchedPart;

    try {
      matchedPart = localParts.firstWhere(
        (p) =>
            (p.barcode != null &&
                p.barcode!.trim().toLowerCase() == cleaned.toLowerCase()) ||
            (p.oemCode != null &&
                p.oemCode!.trim().toLowerCase() == cleaned.toLowerCase()),
      );
    } catch (_) {
      matchedPart = null;
    }

    // 2. Yerelde bulunamadıysa sunucu veritabanı üzerinden ara
    if (matchedPart == null) {
      try {
        final repo = ref.read(sparePartRepositoryProvider);
        final results = await repo.getSpareParts(query: cleaned, limit: 1);
        if (results.isNotEmpty) {
          matchedPart = results.first;
        }
      } catch (e) {
        debugPrint('[GlobalBarcodeListener] Sunucu sorgu hatası: $e');
      }
    }

    // Async arama sonrası widget ve navigator context güvenliğini kontrol et
    if (!mounted) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    // -------------------------------------------------------------------------
    // KURAL 1: PARÇA SİSTEMDE BULUNAMADI (NOT FOUND)
    // -------------------------------------------------------------------------
    // Kullanıcıyı yeni parça ekleme sayfasına yönlendir, okunan barkodu forma aktar.
    if (matchedPart == null) {
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AddPartPage(initialBarcode: cleaned),
        ),
      );
      return;
    }

    // -------------------------------------------------------------------------
    // KURAL 2: PARÇA BULUNDU ve stockQuantity <= 0 (STOK TÜKENDİ)
    // -------------------------------------------------------------------------
    // Satış yapılamayacağı için doğrudan Mal Kabul & Etiket Basma sayfasını aç.
    if (matchedPart.stockQuantity <= 0) {
      HardwareBarcodeService().isGlobalModalSuppressed = true;
      try {
        await PrintLabelBottomSheet.show(navContext, part: matchedPart);
      } finally {
        HardwareBarcodeService().isGlobalModalSuppressed = false;
      }
      return;
    }

    // -------------------------------------------------------------------------
    // KURAL 3: PARÇA BULUNDU ve stockQuantity > 0 (DURUMA BAĞLI ZEKA)
    // -------------------------------------------------------------------------
    final activeTabIndex = ref.read(activeBottomTabIndexProvider);
    final isCurrentlyOnNewSale = activeTabIndex == 2;

    if (isCurrentlyOnNewSale) {
      // 3.1: Kullanıcı Hızlı Satış / Sepet sayfasında!
      // Kasada seri işlem yapan kasiyeri durdurma: Doğrudan sepete ekle ve yeşil SnackBar göster.
      final cart = ref.read(cartProvider);
      final currentQtyInCart = cart
          .where((item) => item.part.id == matchedPart!.id)
          .fold(0, (sum, item) => sum + item.quantity);

      if (currentQtyInCart >= matchedPart.stockQuantity) {
        AppSnackBar.showWarning(
          navContext,
          'Stokta daha fazla ürün yok! (Mevcut: ${matchedPart.stockQuantity} Adet)',
        );
      } else {
        ref.read(cartProvider.notifier).addToCart(matchedPart);
        AppSnackBar.showSuccess(
          navContext,
          '🛒 ${matchedPart.name} sepete eklendi (${currentQtyInCart + 1}. adet)',
        );
      }
    } else {
      // 3.2: Kullanıcı diğer sayfalarda (Ana Sayfa, Katalog vb.)!
      // Kullanıcıya şık ve hızlı "Executive Slate" Aksiyon Modalı aç.
      HardwareBarcodeService().isGlobalModalSuppressed = true;
      try {
        await BarcodeActionBottomSheet.show(navContext, part: matchedPart);
      } finally {
        HardwareBarcodeService().isGlobalModalSuppressed = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
