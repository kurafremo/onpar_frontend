// lib/features/spare_parts/widgets/print_label_modal_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/spare_parts/models/spare_part_model.dart';
import '../../features/spare_parts/providers/spare_part_provider.dart';
import '../constants/app_colors.dart';
import '../services/printer_service.dart';
import '../utils/snackbar_utils.dart';

enum LabelFormat { largeBox1D, smallPart2D }

class PrintLabelBottomSheet extends ConsumerStatefulWidget {
  final SparePart part;
  final String printerName;
  final bool isNewRegistration; 

  const PrintLabelBottomSheet({
    super.key,
    required this.part,
    this.printerName = 'PalmX DXP-400',
    this.isNewRegistration = false,
  });

  static Future<void> show(
    BuildContext context, {
    required SparePart part,
    bool isNewRegistration = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrintLabelBottomSheet(
        part: part,
        isNewRegistration: isNewRegistration,
      ),
    );
  }

  @override
  ConsumerState<PrintLabelBottomSheet> createState() => _PrintLabelBottomSheetState();
}

class _PrintLabelBottomSheetState extends ConsumerState<PrintLabelBottomSheet> {
  LabelFormat _selectedFormat = LabelFormat.largeBox1D;
  late TextEditingController _quantityController;
  int _quantity = 1;
  bool _isPrinting = false;
  late bool _addToStock;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _addToStock = !widget.isNewRegistration;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int newQty) {
    if (newQty < 1) newQty = 1;
    if (newQty > 999) newQty = 999;
    setState(() {
      _quantity = newQty;
      _quantityController.text = _quantity.toString();
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    HapticFeedback.mediumImpact();

    SparePart targetPart = widget.part;
    if (targetPart.id == null) {
      final currentParts = ref.read(sparePartsProvider).value ?? [];
      try {
        final match = currentParts.where((p) => p.id != null).firstWhere(
          (p) =>
              (targetPart.barcode != null && targetPart.barcode!.isNotEmpty && p.barcode == targetPart.barcode) ||
              (targetPart.oemCode != null && targetPart.oemCode!.isNotEmpty && p.oemCode == targetPart.oemCode) ||
              p.name == targetPart.name,
          orElse: () => currentParts.isNotEmpty && currentParts.first.id != null ? currentParts.first : targetPart,
        );
        if (match.id != null) {
          targetPart = match;
        }
      } catch (_) {}
    }

    final barcodeToPrint = targetPart.barcode ?? targetPart.oemCode ?? (targetPart.id != null ? 'ONPAR-${targetPart.id}' : 'ONPAR-0');
    bool printSuccess = false;

    // GERÇEK YAZICI MOTORU BAĞLANTISI VE KURUMSAL VERİLERİN GÖNDERİMİ
    try {
      // Araç modellerini virgülle birleştirip tek metin yapıyoruz (Örn: "Clio, Megane")
      final vehicleModelText = targetPart.compatibleVehicles.isNotEmpty 
          ? targetPart.compatibleVehicles.join(', ') 
          : 'Genel';

      if (_selectedFormat == LabelFormat.largeBox1D) {
        printSuccess = await PrinterService.printLargeLabel(
          partName: targetPart.name,
          oemCode: targetPart.oemCode ?? '-',
          barcodeData: barcodeToPrint,
          quantity: _quantity,
          brand: targetPart.brand ?? 'Belirtilmemis',
          model: vehicleModelText, 
          location: targetPart.location,
        );
      } else {
        printSuccess = await PrinterService.printSmallLabel(
          partName: targetPart.name,
          oemCode: targetPart.oemCode ?? '-',
          qrData: barcodeToPrint,
          quantity: _quantity,
          brand: targetPart.brand ?? 'Belirtilmemis',
          model: vehicleModelText, 
          location: targetPart.location,
        );
      }
    } catch (e) {
      debugPrint('Yazıcı Bağlantı Hatası: $e');
      printSuccess = false;
    }

    bool stockUpdated = false;
    if (_addToStock) {
      try {
        if (targetPart.id == null) {
          final query = targetPart.barcode ?? targetPart.oemCode ?? targetPart.name;
          final fetched = await ref.read(sparePartRepositoryProvider).getSpareParts(query: query, limit: 5);
          if (fetched.isNotEmpty) {
            targetPart = fetched.firstWhere(
              (p) =>
                  (targetPart.barcode != null && p.barcode == targetPart.barcode) ||
                  (targetPart.oemCode != null && p.oemCode == targetPart.oemCode) ||
                  p.name == targetPart.name,
              orElse: () => fetched.first,
            );
          }
        }

        if (targetPart.id != null) {
          final updatedPart = targetPart.copyWith(
            stockQuantity: targetPart.stockQuantity + _quantity,
          );
          await ref.read(sparePartsProvider.notifier).updatePart(updatedPart);
          ref.invalidate(sparePartsProvider);
          ref.invalidate(brandSummaryProvider);
          ref.invalidate(brandPartsProvider);
          stockUpdated = true;
        }
      } catch (e) {
        debugPrint('Stok güncelleme hatası: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isPrinting = false);

    if (printSuccess) {
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          '$_quantity Adet Etiket Basıldı${_addToStock ? ' ve Stoğa Eklendi!' : '.'}',
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        if (_addToStock && stockUpdated) {
          AppSnackBar.showWarning(
            context,
            'Yazıcı bağlantı hatası! ($_quantity adet ürün STOĞA EKLENDİ)',
          );
        } else {
          AppSnackBar.showError(
            context,
            'Yazıcı bağlantı hatası!${_addToStock ? ' (Ancak ürünler STOĞA EKLENDİ)' : ''}',
          );
        }
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -6))],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHandle(),
              _buildHeader(context),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductSummaryCard(),
                    const SizedBox(height: 18),
                    _buildSectionTitle(title: 'ETİKET FORMATI SEÇİN', badge: 'Termal Transfer (203 DPI)'),
                    const SizedBox(height: 10),
                    _buildLabelFormatSelector(),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Basılan Adet Kadar Stoğa Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        widget.isNewRegistration ? 'Ürün yeni kaydedildiği için bu seçenek kapalı.' : 'Gelen malları içeri alırken kullanın.',
                        style: TextStyle(fontSize: 11, color: widget.isNewRegistration ? Colors.orange : Colors.grey)
                      ),
                      value: _addToStock,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (val) => setState(() => _addToStock = val),
                    ),
                    const Divider(),
                    _buildSectionTitle(title: 'BASKI ADEDİ', badge: 'Mevcut Stok: ${widget.part.stockQuantity} Adet'),
                    const SizedBox(height: 10),
                    _buildQuantityInput(),
                    const SizedBox(height: 24),
                    _buildPrimaryActionButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 44, height: 4.5,
        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.corporateNavy,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x221E293B), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: const Icon(Icons.print_outlined, color: AppColors.energeticOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Etiket Yazdır', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.corporateNavy, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${widget.printerName} Çevrimiçi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey[600])),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), shape: const CircleBorder(), padding: const EdgeInsets.all(8)),
            icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSummaryCard() {
    final oem = widget.part.oemCode?.isNotEmpty == true ? widget.part.oemCode! : 'N/A';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.part.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.corporateNavy, height: 1.25)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('OEM: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    Text(oem, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.corporateNavy)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required String badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF64748B))),
        Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey[400])),
      ],
    );
  }

  Widget _buildLabelFormatSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildFormatCard(
            format: LabelFormat.largeBox1D, title: 'Büyük Etiket', dimensions: '100 × 70 mm', barcodeType: '1D Barcode', subtitle: 'Koli & Dış Koli Sevkiyatı',
            isSelected: _selectedFormat == LabelFormat.largeBox1D, wireframe: _build1DWireframe(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFormatCard(
            format: LabelFormat.smallPart2D, title: 'Küçük Etiket', dimensions: '60 × 40 mm', barcodeType: '2D QR Code', subtitle: 'Tekli Poşet & Kutu',
            isSelected: _selectedFormat == LabelFormat.smallPart2D, wireframe: _build2DWireframe(),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatCard({required LabelFormat format, required String title, required String dimensions, required String barcodeType, required String subtitle, required bool isSelected, required Widget wireframe}) {
    return InkWell(
      onTap: () {
        setState(() => _selectedFormat = format);
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.energeticOrange : const Color(0xFFE2E8F0), width: isSelected ? 2.0 : 1.2),
          boxShadow: isSelected ? const [BoxShadow(color: Color(0x22FF6B00), blurRadius: 10, offset: Offset(0, 4))] : const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isSelected ? AppColors.corporateNavy : const Color(0xFF475569)))),
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: isSelected ? AppColors.energeticOrange : Colors.transparent,
                    border: Border.all(color: isSelected ? AppColors.energeticOrange : const Color(0xFFCBD5E1), width: 2),
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(dimensions, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey[600])),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: isSelected ? const Color(0xFFFFEEDB) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                  child: Text(barcodeType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? AppColors.energeticOrange : const Color(0xFF64748B))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            wireframe,
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.blueGrey[400])),
          ],
        ),
      ),
    );
  }

  Widget _build1DWireframe() {
    return Container(
      height: 76, width: double.infinity, padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Container(width: 28, height: 4, color: AppColors.corporateNavy), Container(width: 14, height: 3, color: const Color(0xFF94A3B8))],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Container(width: 50, height: 3, color: const Color(0xFF334155)), const SizedBox(height: 2), Container(width: 32, height: 2.5, color: const Color(0xFF94A3B8))],
          ),
          Container(
            width: double.infinity, height: 22, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(16, (i) => Container(width: (i % 3 == 0) ? 2.5 : ((i % 2 == 0) ? 1.5 : 1.0), height: 14, color: const Color(0xFF0F172A))),
            ),
          ),
          Center(child: Container(width: 40, height: 2, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _build2DWireframe() {
    return Container(
      height: 76, width: double.infinity, padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [Container(width: 24, height: 4, color: AppColors.corporateNavy), Container(width: 42, height: 3, color: const Color(0xFF334155)), Container(width: 30, height: 2.5, color: const Color(0xFF94A3B8)), Container(width: 20, height: 2, color: const Color(0xFFCBD5E1))],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 38, height: 38, padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCBD5E1))),
            child: const Icon(Icons.qr_code_2, size: 30, color: AppColors.corporateNavy),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: Row(
                    children: [
                      IconButton(onPressed: _quantity > 1 ? () => _updateQuantity(_quantity - 1) : null, icon: const Icon(Icons.remove, size: 20), color: AppColors.corporateNavy),
                      Expanded(
                        child: TextField(
                          controller: _quantityController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.corporateNavy),
                          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed > 0) setState(() => _quantity = parsed);
                          },
                        ),
                      ),
                      IconButton(onPressed: () => _updateQuantity(_quantity + 1), icon: const Icon(Icons.add, size: 20), color: AppColors.corporateNavy),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPresetChip('+5', 5),
              const SizedBox(width: 6),
              _buildPresetChip('+10', 10),
              const SizedBox(width: 6),
              _buildStockMatchChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, int addCount) {
    return InkWell(
      onTap: () => _updateQuantity(_quantity + addCount),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48, padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
      ),
    );
  }

  Widget _buildStockMatchChip() {
    final stock = widget.part.stockQuantity;
    return InkWell(
      onTap: stock > 0 ? () => _updateQuantity(stock) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48, padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
        alignment: Alignment.center,
        child: Text('Tümü ($stock)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
      ),
    );
  }

  Widget _buildPrimaryActionButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isPrinting ? null : _handlePrint,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.energeticOrange,
          foregroundColor: Colors.white,
          elevation: 4, shadowColor: const Color(0x66FF6B00),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isPrinting
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)), SizedBox(width: 12), Text('Yazıcıya Gönderiliyor...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.print, size: 22, color: Colors.white), const SizedBox(width: 10), Text('Yazdır (${widget.printerName})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))]),
      ),
    );
  }
}