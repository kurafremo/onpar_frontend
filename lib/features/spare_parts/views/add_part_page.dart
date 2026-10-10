// lib/features/spare_parts/views/add_part_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hardware_barcode_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/spare_part_model.dart';
import '../providers/spare_part_provider.dart';
import '../providers/supplier_provider.dart';
import '../../../core/widgets/print_label_modal_sheet.dart';

class AddPartPage extends ConsumerStatefulWidget {
  final String? initialBarcode;
  const AddPartPage({super.key, this.initialBarcode});

  @override
  ConsumerState<AddPartPage> createState() => _AddPartPageState();
}

class _AddPartPageState extends ConsumerState<AddPartPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _oemController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _brandController = TextEditingController();
  final _vehiclesController = TextEditingController();
  final _locationController = TextEditingController(); // RAF KONUMU EKLENDİ
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _criticalStockController = TextEditingController(text: '5');

  String? _selectedSupplierId;
  bool _isLoading = false;
  bool _isAiLoading = false;
  StreamSubscription<String>? _barcodeSubscription;

  @override
  void initState() {
    super.initState();
    HardwareBarcodeService().isGlobalModalSuppressed = true;

    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchAiSmartBarcode();
      });
    }

    _barcodeSubscription =
        HardwareBarcodeService().onBarcodeScanned.listen((scannedBarcode) {
      if (mounted) {
        setState(() {
          _barcodeController.text = scannedBarcode.trim();
        });
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        AppSnackBar.showSuccess(
          context,
          'Barkod okundu: ${scannedBarcode.trim()}',
          behavior: SnackBarBehavior.fixed,
        );
      }
    });
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    HardwareBarcodeService().isGlobalModalSuppressed = false;

    _nameController.dispose();
    _oemController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _vehiclesController.dispose();
    _locationController.dispose(); // RAF KONUMU TEMİZLENDİ
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _criticalStockController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcodeWithCamera() async {
    try {
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
        setState(() {
          _barcodeController.text = res.trim();
        });
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            'Barkod kameradan okundu: ${res.trim()}',
            behavior: SnackBarBehavior.fixed,
          );
        }
      }
    } catch (e) {
      debugPrint('Kamera hatası: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Kamera açılırken bir hata oluştu.',
          behavior: SnackBarBehavior.fixed,
        );
      }
    }
  }

  Future<void> _fetchAiSmartBarcode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final barcode = _barcodeController.text.trim();
    final name = _nameController.text.trim();

    if (barcode.isEmpty && name.isEmpty) {
      FocusManager.instance.primaryFocus?.unfocus();
      AppSnackBar.showWarning(
        context,
        'Yapay zekanın analiz edebilmesi için önce bir barkod okutun veya parça adı girin.',
        behavior: SnackBarBehavior.fixed,
      );
      return;
    }

    setState(() => _isAiLoading = true);

    try {
      final repo = ref.read(sparePartRepositoryProvider);
      final data = await repo.fetchAiSmartBarcode(
        barcode.isNotEmpty ? barcode : name,
        promptHint: name.isNotEmpty ? name : null,
      );

      setState(() {
        if (data['brand'] != null && data['brand'].toString().isNotEmpty) {
          _brandController.text = data['brand'].toString();
        }
        if (data['oem_code'] != null && data['oem_code'].toString().isNotEmpty) {
          _oemController.text = data['oem_code'].toString();
        }
        final partTitle = data['name'] ?? data['product_type'];
        if (partTitle != null && partTitle.toString().isNotEmpty) {
          if (_nameController.text.trim().isEmpty || _nameController.text == barcode) {
            _nameController.text = partTitle.toString();
          }
        }
        if (data['model'] != null && data['model'].toString().isNotEmpty) {
          _vehiclesController.text = data['model'].toString();
        } else if (data['compatible_vehicles'] != null &&
            data['compatible_vehicles'] is List) {
          final vehicles = (data['compatible_vehicles'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .join(', ');
          if (vehicles.isNotEmpty) {
            _vehiclesController.text = vehicles;
          }
        }
        if (data['estimated_buy_price'] != null) {
          final buyP = num.tryParse(data['estimated_buy_price'].toString()) ?? 0;
          if (buyP > 0 &&
              (_buyPriceController.text.isEmpty || _buyPriceController.text == '0')) {
            _buyPriceController.text = buyP.toStringAsFixed(2);
          }
        }
        if (data['estimated_sell_price'] != null) {
          final sellP = num.tryParse(data['estimated_sell_price'].toString()) ?? 0;
          if (sellP > 0 &&
              (_sellPriceController.text.isEmpty || _sellPriceController.text == '0')) {
            _sellPriceController.text = sellP.toStringAsFixed(2);
          }
        }
      });

      HapticFeedback.mediumImpact();
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        AppSnackBar.showSuccess(
          context,
          '✨ Gemini AI: Parça bilgileri, Marka ve OEM başarıyla dolduruldu!',
          behavior: SnackBarBehavior.fixed,
        );
      }
    } catch (e) {
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        AppSnackBar.showError(
          context,
          'Yapay zeka analiz hatası: ${DioErrorHandler.getErrorMessage(e)}',
          behavior: SnackBarBehavior.fixed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
      }
    }
  }

  // ─── MÜHENDİSLİK (DOKUNULMAMASI GEREKEN KISIM) ─────────────────────────────
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final vehiclesList = _vehiclesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final newPart = SparePart(
        name: _nameController.text.trim(),
        oemCode: _oemController.text.trim().isEmpty ? null : _oemController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        compatibleVehicles: vehiclesList,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(), // RAF KONUMU VERİTABANINA BAĞLANDI
        buyPrice: double.tryParse(_buyPriceController.text.replaceAll(',', '.').trim()) ?? 0.0,
        sellPrice: double.tryParse(_sellPriceController.text.replaceAll(',', '.').trim()) ?? 0.0,
        stockQuantity: 0,
        criticalStockLevel: int.tryParse(_criticalStockController.text.trim()) ?? 5,
        supplierId: _selectedSupplierId,
      );

      await ref.read(sparePartsProvider.notifier).addPart(newPart);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        PrintLabelBottomSheet.show(context, part: newPart, isNewRegistration: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(
          context,
          'Parça eklenemedi: ${DioErrorHandler.getErrorMessage(e)}',
          behavior: SnackBarBehavior.fixed,
        );
      }
    }
  }
  // ────────────────────────────────────────────────────────────────────────────

  // ── Shared input decoration ─────────────────────────────────────────────────
  InputDecoration _inputDec(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textDark),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.corporateNavy, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.corporateNavy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierProvider);

    return Theme(
      data: Theme.of(context).copyWith(
        snackBarTheme: Theme.of(context).snackBarTheme.copyWith(
              behavior: SnackBarBehavior.fixed,
            ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Yeni Parça Ekle'),
        ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── Section: Temel Bilgiler ────────────────────────────────────
            _sectionHeader('Temel Bilgiler', Icons.inventory_2_outlined),
            const SizedBox(height: 10),

            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barkod veya OEM Kodu (Opsiyonel)',
                hintText: 'Okutun veya boş bırakın, sistem otomatik üretir',
                labelStyle: const TextStyle(color: AppColors.textDark),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppColors.corporateNavy),
                  tooltip: 'Barkod Okuyucu / Kamera',
                  onPressed: _scanBarcodeWithCamera,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt, color: AppColors.corporateNavy),
                  tooltip: 'Kamera ile Tara',
                  onPressed: _scanBarcodeWithCamera,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.corporateNavy),
                ),
              ),
              validator: (value) => null,
            ),
            const SizedBox(height: 10),

            _buildAiAssistantCard(),
            const SizedBox(height: 12),

            // ── Supplier dropdown ─────────────────────────────────────────
            suppliersAsync.when(
              data: (suppliers) {
                return DropdownButtonFormField<String?>(
                  initialValue: _selectedSupplierId,
                  decoration: InputDecoration(
                    labelText: 'Tedarikçi / Toptancı',
                    labelStyle: const TextStyle(color: AppColors.textDark),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.corporateNavy),
                    ),
                    prefixIcon: const Icon(Icons.local_shipping_outlined,
                        color: AppColors.corporateNavy),
                    helperText: suppliers.isEmpty
                        ? 'Henüz kayıtlı tedarikçi yok (İsteğe bağlı parça ekleyebilirsiniz)'
                        : 'Ürünün temin edildiği toptancıyı seçin',
                    helperStyle: TextStyle(
                      color: suppliers.isEmpty ? Colors.amber[800] : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                  hint: const Text('Tedarikçi Seçin (İsteğe Bağlı)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tedarikçi Belirtilmemiş (Yok)'),
                    ),
                    ...suppliers.map((supplier) {
                      return DropdownMenuItem<String?>(
                        value: supplier.id,
                        child: Text(supplier.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSupplierId = value;
                    });
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(
                    color: AppColors.corporateNavy, minHeight: 3),
              ),
              error: (e, stack) => DropdownButtonFormField<String?>(
                initialValue: null,
                decoration: InputDecoration(
                  labelText: 'Tedarikçi / Toptancı',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.local_shipping_outlined,
                      color: AppColors.corporateNavy),
                  helperText:
                      'Tedarikçi listesi yüklenemedi ancak parça eklemeye devam edebilirsiniz',
                  helperStyle: const TextStyle(color: Colors.orange, fontSize: 11),
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tedarikçi Belirtilmemiş (Sunucu Çevrimdışı)'),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _oemController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec('OEM Kodu'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec('Parça Adı'),
                    validator: (val) => val == null || val.isEmpty ? 'Gerekli' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              textInputAction: TextInputAction.next,
              decoration: _inputDec('Marka', icon: Icons.label_outline),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehiclesController,
              textInputAction: TextInputAction.next,
              decoration: _inputDec(
                'Uyumlu Araçlar',
                icon: Icons.directions_car_outlined,
                hint: 'Örn: Megane 4, Egea',
              ),
            ),
            
            // RAF KONUMU UI KUTUSU EKLENDİ
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              textInputAction: TextInputAction.next,
              decoration: _inputDec(
                'Raf Konumu',
                icon: Icons.place_outlined,
                hint: 'Örn: A-12-03',
              ),
            ),

            const SizedBox(height: 24),
            // ── Section: Fiyat ve Uyarılar ────────────────────────────────
            _sectionHeader('Fiyat ve Uyarılar', Icons.attach_money),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyPriceController,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDec('Alış Fiyatı (₺)', icon: Icons.arrow_downward),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Gerekli' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPriceController,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDec('Satış Fiyatı (₺)', icon: Icons.arrow_upward),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Gerekli' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _criticalStockController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              decoration: _inputDec(
                'Kritik Sınır Uyarı Seviyesi',
                icon: Icons.warning_amber_outlined,
                hint: 'Örn: 5',
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Gerekli' : null,
            ),

            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.corporateNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Parçayı Kaydet',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }

  // ── Section header ──────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.corporateNavy),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.corporateNavy,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  // ── AI assistant card ───────────────────────────────────────────────────────
  Widget _buildAiAssistantCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.corporateNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.corporateNavy.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.corporateNavy.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.corporateNavy, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yapay Zeka (Gemini 3.5 Flash-Lite)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.corporateNavy,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Marka, OEM ve Araçları otomatik bulur',
                  style: TextStyle(color: AppColors.textDark, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isAiLoading ? null : _fetchAiSmartBarcode,
            icon: _isAiLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.flash_on, size: 16),
            label: Text(_isAiLoading ? '...' : 'AI Doldur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.energeticOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}