// lib/features/spare_parts/views/home_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import '../providers/spare_part_provider.dart';
import '../providers/auth_provider.dart';
import 'add_part_page.dart';
import 'part_detail_page.dart';
import 'sales_ledger_page.dart';
import 'app_drawer.dart';
import 'new_sale_page.dart';
import 'critical_stock_page.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/state_feedback_widget.dart';

// YENİ KURUMSAL KİMLİK İMPORTLARI (Yollarını kendi klasör yapına göre ayarlayabilirsin)
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/corporate_logo.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).updateQuery(query);
      ref.read(sparePartsProvider.notifier).search(query);
    });
  }

  void _onBarcodeScanned(String barcode) {
    if (barcode.trim().isEmpty) return;
    _searchController.clear();
    FocusScope.of(context).unfocus();
    ref.read(searchQueryProvider.notifier).updateQuery('');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewSalePage(initialBarcode: barcode.trim()),
      ),
    );
  }

  Future<void> _scanBarcodeWithCamera() async {
    String? barcode = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleBarcodeScannerPage(),
      ),
    );

    if (barcode != null && barcode != '-1' && barcode.isNotEmpty) {
      _onBarcodeScanned(barcode.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- ANTIGRAVITY KONSEPT A: GRID ACTION KARTI ---
  Widget _buildActionCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.corporateNavy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.corporateNavy.withValues(alpha:0.15), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white70, size: 28),
                  const Spacer(),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.energeticOrange,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partsAsync = ref.watch(sparePartsProvider);
    final roleAsync = ref.watch(userRoleProvider);
    final user = ref.watch(authStateProvider);
    final isAdmin = roleAsync.value == 'admin' || roleAsync.value == 'patron';
    final searchQuery = ref.watch(searchQueryProvider);
    final dailySalesAsync = ref.watch(dailySalesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight, // Antigravity: #F8FAFC
      drawer: const AppDrawer(),
      appBar: AppBar(
        // Akıllı Logomuz Burada! (Eğer logon JPG ise CorporateLogo içindeki yolu ona göre düzelt)
        title: const CorporateLogo(isVertical: false, iconSize: 32, fontSize: 20),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.corporateNavy,
        actions: [
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. KULLANICI KARŞILAMA (GREETING)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.corporateNavy.withValues(alpha:0.1),
                    child: const Icon(Icons.person, color: AppColors.corporateNavy, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İyi çalışmalar, ${user?.username ?? "Kullanıcı"}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.corporateNavy),
                      ),
                      Text(
                        isAdmin ? 'Yönetici (Patron)' : 'Personel (Çalışan)',
                        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. FİNANSAL ÖZET KARTI (HERO CARD - EXECUTIVE SLATE)
          if (isAdmin)
            SliverToBoxAdapter(
              child: dailySalesAsync.when(
                data: (sales) {
                  double todayRevenue = 0;
                  int todaySalesCount = 0;
                  for (var sale in sales) {
                    todayRevenue += sale.totalPrice;
                    todaySalesCount += sale.quantity;
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.corporateNavy,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: AppColors.corporateNavy.withValues(alpha:0.25), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bugünkü Kasa (Ciro)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₺${todayRevenue.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.successGreen.withValues(alpha:0.2), borderRadius: BorderRadius.circular(8)),
                              child: const Text('+ Aktif', style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24, height: 1)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Günlük İşlem Hacmi', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text('$todaySalesCount Adet Parça', style: const TextStyle(color: AppColors.energeticOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                error: (e, stack) => const SizedBox(),
              ),
            ),

          // ... home_page.dart içindeki Sliver kısımları (1, 2 ve 3 aynı kalacak) ...

          // 3. KRİTİK STOK UYARISI (Eski kodunla aynı)
          SliverToBoxAdapter(
            child: partsAsync.maybeWhen(
              data: (parts) {
                final criticalCount = parts.where((p) => p.stockQuantity > 0 && p.stockQuantity <= (p.criticalStockLevel ?? 5)).length;
                final outOfStockCount = parts.where((p) => p.stockQuantity == 0).length;
                if (criticalCount == 0 && outOfStockCount == 0) return const SizedBox();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CriticalStockPage())),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha:0.1),
                        border: Border.all(color: AppColors.dangerRed.withValues(alpha:0.3)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.dangerRed, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Kritik Stok Uyarısı', style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('$outOfStockCount ürün tükendi, $criticalCount ürün kritik.', style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.dangerRed),
                        ],
                      ),
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox(),
            ),
          ),

          // YENİ 4. ARAMA ÇUBUĞU (YUKARI TAŞINDI)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parça Sorgula / Barkod Okut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha:0.1), blurRadius: 10, offset: const Offset(0, 4))],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onBarcodeScanned,
                      decoration: InputDecoration(
                        hintText: 'OEM Kodu veya Parça Adı...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.energeticOrange),
                          onPressed: _scanBarcodeWithCamera,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _onSearchChanged(''); })
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // YENİ 5. HIZLI İŞLEM MENÜSÜ (3 BUTONA DÜŞÜRÜLDÜ)
          if (searchQuery.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.35,
                children: [
                  _buildActionCard(context, 'Hızlı Satış (POS)', Icons.shopping_cart_checkout_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewSalePage()))),
                  _buildActionCard(context, 'Satış Defteri', Icons.receipt_long_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesLedgerPage()))),
                  _buildActionCard(context, 'Yeni Parça Ekle', Icons.add_box_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPartPage()))),
                ],
              ),
            ),

          // 6. ARAMA SONUÇLARI LİSTESİ
          if (searchQuery.isNotEmpty)
            partsAsync.when(
              data: (parts) {
                if (parts.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('Aranan parça bulunamadı.', style: TextStyle(color: Colors.grey, fontSize: 16))),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final part = parts[index];
                    final isOutOfStock = part.stockQuantity <= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.settings, color: AppColors.corporateNavy),
                          ),
                          title: Text(
                            part.name,
                            style: TextStyle(fontWeight: FontWeight.bold, decoration: isOutOfStock ? TextDecoration.lineThrough : null, color: isOutOfStock ? Colors.grey : AppColors.corporateNavy),
                          ),
                          subtitle: Text('₺${part.sellPrice.toStringAsFixed(2)} | Stok: ${part.stockQuantity}', style: const TextStyle(color: AppColors.textDark)),
                          trailing: isOutOfStock
                              ? const Text('TÜKENDİ', style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold))
                              : const Icon(Icons.chevron_right, color: AppColors.energeticOrange),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PartDetailPage(part: part))),
                        ),
                      ),
                    );
                  }, childCount: parts.length),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox(height: 350, child: PartListShimmer(itemCount: 4))),
              error: (e, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
                  child: StateFeedbackWidget.error(error: e, customTitle: 'Parçalar Yüklenemedi', onRetry: () => ref.refresh(sparePartsProvider)),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}