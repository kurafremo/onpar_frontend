import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../utils/snackbar_utils.dart';
import '../../features/spare_parts/models/spare_part_model.dart';
import '../../features/spare_parts/providers/cart_provider.dart';
import 'print_label_modal_sheet.dart';

/// Sekme değiştirici ve durum izleyici Notifier
class ActiveBottomTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

final activeBottomTabIndexProvider =
    NotifierProvider<ActiveBottomTabNotifier, int>(ActiveBottomTabNotifier.new);

/// Executive Slate Temalı Hızlı Barkod Aksiyon Modalı
class BarcodeActionBottomSheet extends ConsumerWidget {
  final SparePart part;

  const BarcodeActionBottomSheet({super.key, required this.part});

  static Future<void> show(BuildContext context, {required SparePart part}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeActionBottomSheet(part: part),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutOfStock = part.stockQuantity <= 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331E293B), // Corporate Navy gölge efekti
            blurRadius: 24,
            offset: Offset(0, -6),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Sürükleme Tutamacı
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Başlık Satırı
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.corporateNavy,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x221E293B),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.energeticOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DONANIM BARKODU OKUNDU',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          part.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.corporateNavy,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Ürün Detay Kartı (OEM, Barkod, Fiyat, Stok)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildBadge(
                          label: 'OEM',
                          value: part.oemCode?.isNotEmpty == true ? part.oemCode! : '-',
                          isMonospace: true,
                        ),
                        _buildBadge(
                          label: 'Barkod',
                          value: part.barcode?.isNotEmpty == true ? part.barcode! : '-',
                          isMonospace: true,
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Satış Fiyatı',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '₺${part.sellPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.corporateNavy,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? AppColors.dangerRed.withValues(alpha: 0.1)
                                : AppColors.successGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOutOfStock
                                  ? AppColors.dangerRed.withValues(alpha: 0.3)
                                  : AppColors.successGreen.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOutOfStock ? Icons.error_outline : Icons.check_circle_outline,
                                size: 16,
                                color: isOutOfStock ? AppColors.dangerRed : AppColors.successGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOutOfStock ? 'STOK TÜKENDİ' : 'Stok: ${part.stockQuantity} Adet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isOutOfStock ? AppColors.dangerRed : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // AKSİYON A: SEPETE EKLE (SATIŞ)
              InkWell(
                onTap: isOutOfStock
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);

                        // Stok adedi kontrolü
                        final cart = ref.read(cartProvider);
                        final currentQty = cart
                            .where((item) => item.part.id == part.id)
                            .fold(0, (sum, item) => sum + item.quantity);

                        if (currentQty >= part.stockQuantity) {
                          AppSnackBar.showWarning(
                            context,
                            'Stokta daha fazla ürün yok! (Mevcut: ${part.stockQuantity} Adet)',
                          );
                          return;
                        }

                        ref.read(cartProvider.notifier).addToCart(part);
                        AppSnackBar.showSuccess(
                          context,
                          '🛒 ${part.name} sepete eklendi.',
                          actionLabel: 'Sepete Git',
                          onAction: () {
                            ref.read(activeBottomTabIndexProvider.notifier).setTab(2);
                          },
                        );
                      },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isOutOfStock ? const Color(0xFFF1F5F9) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOutOfStock ? const Color(0xFFE2E8F0) : const Color(0xFFA7F3D0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isOutOfStock ? const Color(0xFFCBD5E1) : AppColors.successGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🛒 Sepete Ekle (Satış)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOutOfStock
                                  ? 'Stok bittiği için doğrudan satış yapılamaz'
                                  : 'Ürünü hızlı satış sepetine ekler ve kasaya hazırlar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isOutOfStock ? const Color(0xFFCBD5E1) : const Color(0xFF059669),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // AKSİYON B: STOK EKLE / ETİKET BAS (MAL KABUL)
              InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  // Mal kabul & etiket basma modalını aç
                  PrintLabelBottomSheet.show(context, part: part);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.energeticOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📦 Stok Ekle / Etiket Bas (Mal Kabul)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF9A3412),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Gelen parti mal kabulünü yap ve raf etiketi bas',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFEA580C),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({required String label, required String value, bool isMonospace = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: isMonospace ? 'monospace' : null,
              color: AppColors.corporateNavy,
            ),
          ),
        ],
      ),
    );
  }
}
