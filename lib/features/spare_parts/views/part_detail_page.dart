import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spare_part_model.dart';
import '../models/sale_record_model.dart';
import '../providers/spare_part_provider.dart';
import 'edit_part_page.dart';
import '../../../core/widgets/print_label_modal_sheet.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import 'new_sale_page.dart';
import '../providers/cart_provider.dart';

class PartDetailPage extends ConsumerWidget {
  final SparePart part;

  const PartDetailPage({super.key, required this.part});

  void _showQuickSaleModal(BuildContext context, WidgetRef ref) {
    final quantityController = TextEditingController(text: '1');
    final buyerController = TextEditingController();
    final plateController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            int quantity = int.tryParse(quantityController.text) ?? 1;
            double totalPrice = quantity * part.sellPrice;
            bool isLoading = false;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hızlı Satış Çıkışı',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  Text(
                    '${part.name} (Stok: ${part.stockQuantity})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Text(
                        'Adet:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: quantity > 1
                            ? () {
                                setState(() {
                                  quantityController.text = (quantity - 1)
                                      .toString();
                                });
                              }
                            : null,
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: quantityController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: quantity < part.stockQuantity
                            ? () {
                                setState(() {
                                  quantityController.text = (quantity + 1)
                                      .toString();
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Araç Plakası (İsteğe Bağlı)',
                      prefixIcon: Icon(Icons.directions_car),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buyerController,
                    decoration: const InputDecoration(
                      labelText: 'Müşteri / Usta Adı (İsteğe Bağlı)',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Toplam Tutar',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            '₺${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            isLoading ||
                                quantity > part.stockQuantity ||
                                quantity < 1
                            ? null
                            : () async {
                                setState(() => isLoading = true);
                                try {
                                  final record = SaleRecord(
                                    partId: part.id!,
                                    partName:
                                    part.name, // Data Duplication mühürü
                                    quantity: quantity,
                                    unitPrice: part.sellPrice,
                                    totalPrice: totalPrice,
                                    buyerName: buyerController.text.trim(),
                                    vehiclePlate: plateController.text.trim(),
                                  );

                                  await ref
                                      .read(sparePartsProvider.notifier)
                                      .recordSale(record);

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    AppSnackBar.showSuccess(
                                      context,
                                      'Satış başarıyla kaydedildi!',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.showError(
                                      context,
                                      'Satış kaydedilemedi: ${DioErrorHandler.getErrorMessage(e)}',
                                    );
                                  }
                                } finally {
                                  if (context.mounted)
                                    setState(() => isLoading = false);
                                }
                              },
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'SATIŞI ONAYLA',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCritical = part.stockQuantity <= part.criticalStockLevel;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Parça Detayı'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppColors.corporateNavy),
            tooltip: 'Print Label',
            onPressed: () => PrintLabelBottomSheet.show(context, part: part),
          ),
          // ÇALIŞAN DA ÜRÜN BİLGİSİNİ DÜZENLEYEBİLİR
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueGrey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPartPage(part: part),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(
                          'Marka',
                          part.brand ?? 'Belirtilmemiş',
                          Icons.branding_watermark,
                        ),
                        _buildInfoChip(
                          'OEM',
                          part.oemCode ?? 'Yok',
                          Icons.numbers,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Stok Miktarı',
                    value: '${part.stockQuantity} Adet',
                    valueColor: isCritical
                        ? Colors.redAccent
                        : Colors.green[700]!,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Satış Fiyatı',
                    value: '₺${part.sellPrice.toStringAsFixed(2)}',
                    valueColor: Colors.blueGrey[900]!,
                    icon: Icons.sell_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ÇALIŞAN DA GELİŞ FİYATINI GÖREBİLİR
            Card(
              color: Colors.blueGrey[50],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueGrey[200]!),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.blueGrey[700],
                ),
                title: const Text(
                  'Geliş (Alış) Fiyatı',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Text(
                  '₺${part.buyPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Print Label Modal Trigger
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.corporateNavy.withOpacity(0.2), width: 1.2),
                ),
                child: IconButton(
                  tooltip: 'Print Product Labels',
                  onPressed: () => PrintLabelBottomSheet.show(context, part: part),
                  icon: const Icon(
                    Icons.print_outlined,
                    color: AppColors.corporateNavy,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
           // SATIŞ YAP Butonu
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: part.stockQuantity <= 0
                      ? null 
                      : () {
                          // 1. ÜRÜNÜ KÜRESEL SEPETE EKLE
                          ref.read(cartProvider.notifier).addToCart(part); 

                          // 2. Doğrudan Sepet Ekranına Yönlendir (Barkod göndermeye gerek yok)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NewSalePage(),
                            ),
                          );  
                        },
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Satış Yap (Sepete At)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueGrey, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

