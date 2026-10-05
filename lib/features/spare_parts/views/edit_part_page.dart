import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spare_part_model.dart';
import '../providers/spare_part_provider.dart';
import '../providers/supplier_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';

class EditPartPage extends ConsumerStatefulWidget {
  final SparePart part;

  const EditPartPage({super.key, required this.part});

  @override
  ConsumerState<EditPartPage> createState() => _EditPartPageState();
}

class _EditPartPageState extends ConsumerState<EditPartPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _oemController;
  late TextEditingController _barcodeController;
  late TextEditingController _brandController;
  late TextEditingController _vehiclesController;
  late TextEditingController _buyPriceController;
  late TextEditingController _sellPriceController;
  late TextEditingController _stockController;
  late TextEditingController _criticalStockController;

  String? _selectedSupplierId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSupplierId = widget.part.supplierId;
    _nameController = TextEditingController(text: widget.part.name);
    _oemController = TextEditingController(text: widget.part.oemCode ?? '');
    _barcodeController = TextEditingController(text: widget.part.barcode ?? '');
    _brandController = TextEditingController(text: widget.part.brand ?? '');
    _vehiclesController = TextEditingController(
      text: widget.part.compatibleVehicles.join(', '),
    );
    _buyPriceController = TextEditingController(
      text: widget.part.buyPrice.toString(),
    );
    _sellPriceController = TextEditingController(
      text: widget.part.sellPrice.toString(),
    );
    _stockController = TextEditingController(
      text: widget.part.stockQuantity.toString(),
    );
    _criticalStockController = TextEditingController(
      text: widget.part.criticalStockLevel.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _oemController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _vehiclesController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _criticalStockController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final vehiclesList = _vehiclesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updatedPart = widget.part.copyWith(
        name: _nameController.text.trim(),
        oemCode: _oemController.text.trim().isEmpty
            ? null
            : _oemController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        compatibleVehicles: vehiclesList,
        buyPrice: double.tryParse(_buyPriceController.text.replaceAll(',', '.').trim()) ?? widget.part.buyPrice,
        sellPrice: double.tryParse(_sellPriceController.text.replaceAll(',', '.').trim()) ?? widget.part.sellPrice,
        stockQuantity: int.tryParse(_stockController.text.trim()) ?? widget.part.stockQuantity,
        criticalStockLevel: int.tryParse(_criticalStockController.text.trim()) ?? widget.part.criticalStockLevel,
        supplierId: _selectedSupplierId,
      );

      await ref.read(sparePartsProvider.notifier).updatePart(updatedPart);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        AppSnackBar.showSuccess(
          context,
          'Parça başarıyla güncellendi!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Güncelleme başarısız: ${DioErrorHandler.getErrorMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürünü Düzenle'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Temel Bilgiler',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            suppliersAsync.when(
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'Tedarikçi (Toptancı)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    hint: const Text('Kimden alındı? (İsteğe Bağlı)'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tedarikçi Seçilmedi'),
                      ),
                      ...suppliers.map((supplier) {
                        return DropdownMenuItem(
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
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
            TextFormField(
              controller: _nameController,
              textInputAction:
                  TextInputAction.next, // YENİ: Klavye ileri butonu
              decoration: const InputDecoration(
                labelText: 'Parça Adı',
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Boş bırakılamaz' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _oemController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'OEM Kodu',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Barkod',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Marka',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehiclesController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Uyumlu Araçlar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Fiyat ve Stok',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyPriceController,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Alış Fiyatı (₺)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPriceController,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Satış Fiyatı (₺)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok Miktarı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _criticalStockController,
                    textInputAction:
                        TextInputAction.done, // YENİ: Son kutucuk bitti butonu
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kritik Sınır',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Değişiklikleri Kaydet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
