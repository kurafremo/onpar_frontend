import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/spare_part_provider.dart';
import '../models/spare_part_model.dart';
import '../models/sale_record_model.dart';
import 'part_detail_page.dart';
import 'add_part_page.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/state_feedback_widget.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import '../providers/auth_provider.dart';

class BrandPartsPage extends ConsumerStatefulWidget {
  final String brandName;
  const BrandPartsPage({super.key, required this.brandName});

  @override
  ConsumerState<BrandPartsPage> createState() => _BrandPartsPageState();
}

class _BrandPartsPageState extends ConsumerState<BrandPartsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  
  final ScrollController _scrollController = ScrollController();
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBrandParts();
    });
  }

  Future<void> _loadBrandParts() async {
    setState(() => _isInitialLoading = true);
    try {
      await ref.read(brandPartsProvider(widget.brandName).notifier).init(widget.brandName);
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(brandPartsProvider(widget.brandName).notifier).fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partsAsync = ref.watch(brandPartsProvider(widget.brandName));
    final notifier = ref.read(brandPartsProvider(widget.brandName).notifier);
    
    // [KURAL 1]: Rol Bazlı Ticari Veri Gizliliği (Admin / Patron Kontrolü)
    final user = ref.watch(authStateProvider);
    final bool isAdminOrPatron = user?.isAdmin ?? false;

    final bool isLoading = _isInitialLoading || partsAsync.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.brandName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              _loadBrandParts();
            },
          ),
        ],
      ),
      body: isLoading
          ? const PartListShimmer()
          : partsAsync.when(
              data: (brandParts) {
                final filteredParts = brandParts.where((part) {
                  final q = _searchQuery.toLowerCase();
                  final nameMatch = part.name.toLowerCase().contains(q);
                  final oemMatch = part.oemCode?.toLowerCase().contains(q) ?? false;
                  final barcodeMatch = part.barcode?.toLowerCase().contains(q) ?? false;
                  return nameMatch || oemMatch || barcodeMatch;
                }).toList();

                final totalStockCount = filteredParts.fold<int>(0, (sum, item) => sum + item.stockQuantity);
                final totalInventoryValue = filteredParts.fold<double>(
                  0.0, 
                  (sum, item) => sum + (item.buyPrice * item.stockQuantity)
                );

                return RefreshIndicator(
                  color: const Color(0xFF0F172A),
                  onRefresh: () async {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    await _loadBrandParts();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: '${widget.brandName} içinde parça adı, OEM veya Barkod ara...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.blueGrey.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${filteredParts.length} Çeşit Parça',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blueGrey.shade200),
                                      ),
                                      child: Text(
                                        '$totalStockCount Adet',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueGrey.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // [KURAL 1]: Envanter Toplam Değeri Sadece Admin / Patron İçin Görünür
                                if (isAdminOrPatron)
                                  Text(
                                    'Envanter: ${currencyFormat.format(totalInventoryValue)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (filteredParts.isEmpty)
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
                              child: StateFeedbackWidget.empty(
                                message: _searchQuery.isEmpty
                                    ? '"${widget.brandName}" markasına ait henüz parça bulunmuyor.'
                                    : '"$_searchQuery" aramasına uygun parça bulunamadı.',
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                            itemCount: filteredParts.length + (notifier.hasMore ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              if (index == filteredParts.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    ),
                                  ),
                                );
                              }

                              final part = filteredParts[index];
                              final isCritical = part.stockQuantity <= 3;
                              final isOut = part.stockQuantity <= 0;

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isOut 
                                        ? Colors.red.shade200 
                                        : (isCritical ? Colors.amber.shade200 : Colors.grey.shade200),
                                  ),
                                ),
                                color: Colors.white,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PartDetailPage(part: part),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: isOut 
                                                ? Colors.red.shade50 
                                                : (isCritical ? Colors.amber.shade50 : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isOut 
                                                  ? Colors.red.shade300 
                                                  : (isCritical ? Colors.amber.shade300 : const Color(0xFFCBD5E1)),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${part.stockQuantity}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isOut 
                                                      ? Colors.red.shade700 
                                                      : (isCritical ? Colors.amber.shade900 : const Color(0xFF0F172A)),
                                                ),
                                              ),
                                              Text(
                                                'ADET',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isOut 
                                                      ? Colors.red.shade700 
                                                      : (isCritical ? Colors.amber.shade800 : const Color(0xFF64748B)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                part.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (part.oemCode != null && part.oemCode!.isNotEmpty) ...[
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'OEM: ${part.oemCode}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(0xFF475569),
                                                          fontFamily: 'monospace',
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  if (part.location != null && part.location!.isNotEmpty)
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          part.location!,
                                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(
                                                    currencyFormat.format(part.sellPrice),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 14,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  // [KURAL 1]: Alış Fiyatı Sadece Admin / Patron İçin Görünür
                                                  if (isAdminOrPatron) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Alış: ${currencyFormat.format(part.buyPrice)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade600,
                                                        decoration: TextDecoration.none,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 22),
                                          tooltip: 'Hızlı Satış Yap',
                                          onPressed: part.stockQuantity <= 0 
                                              ? null 
                                              : () => _showQuickSaleModal(context, ref, part),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const PartListShimmer(),
              error: (error, stack) => StateFeedbackWidget.error(
                error: error,
                onRetry: _loadBrandParts,
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'brand_parts_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddPartPage()),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Yeni Parça Ekle',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  void _showQuickSaleModal(BuildContext context, WidgetRef ref, SparePart part) {
    int qty = 1;
    final sellPriceCtrl = TextEditingController(text: part.sellPrice.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentUnitPrice = double.tryParse(sellPriceCtrl.text) ?? part.sellPrice;
            final currentTotal = currentUnitPrice * qty;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hızlı Satış',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    part.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mevcut Stok: ${part.stockQuantity} Adet',
                    style: TextStyle(
                      fontSize: 12,
                      color: part.stockQuantity <= 3 ? Colors.red : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sellPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Birim Satış Fiyatı (₺)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: qty > 1
                                  ? () => setModalState(() => qty--)
                                  : null,
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: qty < part.stockQuantity
                                  ? () => setModalState(() => qty++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Toplam Tutar:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          currencyFormat.format(currentTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Satışı Onayla ve Stoktan Düş', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final parsedPrice = double.tryParse(sellPriceCtrl.text) ?? part.sellPrice;
                        if (parsedPrice <= 0) {
                          SnackBarUtils.showError(context, 'Geçerli bir satış fiyatı giriniz.');
                          return;
                        }

                        Navigator.pop(ctx);
                        try {
                          final sale = SaleRecord(
                            partId: part.id?.toString() ?? '',
                            partName: part.name,
                            quantity: qty,
                            unitPrice: parsedPrice,
                            totalPrice: parsedPrice * qty,
                            paymentMethod: 'Nakit',
                            createdAt: DateTime.now(),
                          );
                          await ref.read(sparePartsProvider.notifier).recordSale(sale);
                          ref.invalidate(brandPartsProvider(widget.brandName));
                          ref.invalidate(sparePartsProvider);
                          ref.invalidate(brandSummaryProvider);
                          if (context.mounted) {
                            SnackBarUtils.showSuccess(context, '$qty adet "${part.name}" satışı kaydedildi.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            SnackBarUtils.showError(context, DioErrorHandler.getErrorMessage(e));
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}