import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/spare_part_provider.dart';
import '../models/spare_part_model.dart';
import 'brand_parts_page.dart';
import 'add_part_page.dart';
import 'part_detail_page.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import '../../../core/widgets/state_feedback_widget.dart';

class PartsListPage extends ConsumerStatefulWidget {
  const PartsListPage({super.key});

  @override
  ConsumerState<PartsListPage> createState() => _PartsListPageState();
}

class _PartsListPageState extends ConsumerState<PartsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(sparePartsProvider.notifier).fetchMore();
    }
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        ref.read(sparePartsProvider.notifier).search(val.trim());
      }
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
    ref.read(sparePartsProvider.notifier).search('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- MARKA İSİM DÜZENLEME DİYALOĞU ---
  void _editBrand(String oldBrand) {
    if (oldBrand == 'Diğer / Markasız') return;

    final editCtrl = TextEditingController(text: oldBrand);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Markayı Düzenle',
            style: TextStyle(color: AppColors.corporateNavy, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editCtrl,
          decoration: InputDecoration(
            labelText: 'Yeni Marka İsmi',
            labelStyle: const TextStyle(color: AppColors.corporateNavy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.corporateNavy),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.corporateNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = editCtrl.text.trim();
              if (newName.isEmpty || newName == oldBrand) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context);
              try {
                await ref
                    .read(sparePartsProvider.notifier)
                    .updateBrandName(oldBrand, newName);
                if (!context.mounted) return;
                AppSnackBar.showSuccess(context, 'Marka başarıyla güncellendi!');
              } catch (e) {
                if (!context.mounted) return;
                AppSnackBar.showError(
                  context,
                  'Marka güncellenemedi: ${DioErrorHandler.getErrorMessage(e)}',
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // --- MARKA SİLME DİYALOĞU ---
  void _deleteBrand(String brandName, int productCount) {
    if (brandName == 'Diğer / Markasız') return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Markayı Sil',
            style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold)),
        content: Text(
          'DİKKAT: $brandName markasını silerseniz, bu markaya ait $productCount adet ürün de stoktan kalıcı olarak silinecektir.\n\nEmin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(sparePartsProvider.notifier)
                    .deleteBrand(brandName);
                if (!context.mounted) return;
                AppSnackBar.showSuccess(context, 'Marka ve tüm ürünleri başarıyla silindi!');
              } catch (e) {
                if (!context.mounted) return;
                AppSnackBar.showError(
                  context,
                  'Silme hatası: ${DioErrorHandler.getErrorMessage(e)}',
                );
              }
            },
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.trim().isNotEmpty;
    final searchPartsAsync = isSearching ? ref.watch(sparePartsProvider) : null;
    final brandSummaryAsync = !isSearching ? ref.watch(brandSummaryProvider) : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          isSearching ? 'Parça Arama Sonuçları' : 'Marka Kataloğu',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.corporateNavy.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Parça adı, OEM, Barkod veya Marka ara...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.corporateNavy),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: isSearching
                ? _buildGlobalSearchResults(searchPartsAsync!)
                : _buildBrandGrid(brandSummaryAsync!),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'parts_list_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddPartPage()),
        ),
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Yeni Parça Ekle',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildBrandGrid(AsyncValue<List<Map<String, dynamic>>> brandSummaryAsync) {
    return brandSummaryAsync.when(
      data: (summaries) {
        if (summaries.isEmpty) {
          return StateFeedbackWidget.empty(
            icon: Icons.category_outlined,
            title: 'Kayıtlı Marka Bulunamadı',
            message:
                'Stokta henüz kayıtlı herhangi bir marka veya parça bulunmuyor.\nAlttaki butona dokunarak ilk parçanızı ekleyebilirsiniz.',
          );
        }

        final sortedList = List<Map<String, dynamic>>.from(summaries);
        sortedList.sort((a, b) {
          final brandA = a['brand'] as String? ?? 'Diğer / Markasız';
          final brandB = b['brand'] as String? ?? 'Diğer / Markasız';
          if (brandA == 'Diğer / Markasız') return 1;
          if (brandB == 'Diğer / Markasız') return -1;
          return brandA.compareTo(brandB);
        });

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 125).floor().clamp(2, 6);
            return RefreshIndicator(
              color: AppColors.energeticOrange,
              onRefresh: () async => ref.invalidate(brandSummaryProvider),
              child: GridView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: crossAxisCount <= 2 ? 1.35 : 1.05,
                ),
                itemCount: sortedList.length,
                itemBuilder: (context, index) {
                  final item = sortedList[index];
                  final brand = item['brand'] as String? ?? 'Diğer / Markasız';
                  final rawCount = item['total_items'] ??
                      item['totalItems'] ??
                      item['count'] ??
                      item['total_count'] ??
                      item['total_parts'] ??
                      0;
                  final count = int.tryParse(rawCount.toString()) ?? 0;
                  final isSystemBrand = brand == 'Diğer / Markasız';

                  return Stack(
                    children: [
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BrandPartsPage(brandName: brand),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.corporateNavy.withValues(alpha: 0.07),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.corporateNavy.withValues(alpha: 0.07),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.corporateNavy.withValues(alpha: 0.08),
                                child: Text(
                                  isSystemBrand
                                      ? '?'
                                      : brand.isNotEmpty ? brand[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.corporateNavy,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  brand,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.corporateNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.energeticOrange.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count Ürün',
                                  style: const TextStyle(
                                    color: AppColors.energeticOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isSystemBrand)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'edit') _editBrand(brand);
                              if (val == 'delete') _deleteBrand(brand, count);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Düzenle'),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete, size: 16, color: AppColors.dangerRed),
                                  SizedBox(width: 8),
                                  Text('Sil', style: TextStyle(color: AppColors.dangerRed)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const BrandGridShimmer(),
      error: (error, stack) => StateFeedbackWidget.error(
        error: error,
        onRetry: () => ref.refresh(brandSummaryProvider),
      ),
    );
  }

  Widget _buildGlobalSearchResults(AsyncValue<List<SparePart>> searchPartsAsync) {
    return searchPartsAsync.when(
      data: (parts) {
        if (parts.isEmpty) {
          return StateFeedbackWidget.empty(
            icon: Icons.search_off_rounded,
            title: 'Parça Bulunamadı',
            message: '"$_searchQuery" aramasıyla eşleşen parça kaydı bulunamadı.',
            actionLabel: 'Aramayı Temizle',
            actionIcon: Icons.clear,
            onAction: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              ref.read(sparePartsProvider.notifier).search('');
            },
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: parts.length + 1,
          itemBuilder: (context, index) {
            if (index == parts.length) return const SizedBox(height: 20);
            final part = parts[index];
            final isLowStock = part.stockQuantity <= 5;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: AppColors.corporateNavy.withValues(alpha: 0.08),
                  child: const Icon(Icons.build_rounded, color: AppColors.corporateNavy, size: 20),
                ),
                title: Text(
                  part.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.corporateNavy,
                  ),
                ),
                subtitle: Text(
                  'Marka: ${part.brand ?? "Belirtilmemiş"} | OEM: ${part.oemCode ?? "-"} | Barkod: ${part.barcode ?? "-"}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${part.sellPrice.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Stok: ${part.stockQuantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLowStock ? AppColors.dangerRed : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PartDetailPage(part: part)),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.corporateNavy),
      ),
      error: (e, st) => StateFeedbackWidget.error(
        error: e,
        onRetry: () => ref.read(sparePartsProvider.notifier).search(_searchQuery.trim()),
      ),
    );
  }
}
