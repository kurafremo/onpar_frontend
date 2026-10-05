import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/spare_part_model.dart';
import '../repositories/spare_part_repository.dart';
import '../models/sale_record_model.dart';

final sparePartRepositoryProvider = Provider<SparePartRepository>((ref) {
  return SparePartRepository();
});

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void updateQuery(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() {
  return SearchQueryNotifier();
});

class SparePartsNotifier extends AsyncNotifier<List<SparePart>> {
  int _skip = 0;
  final int _limit = 50;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  bool get hasMore => _hasMore;
  bool get isFetchingMore => _isFetchingMore;

  @override
  Future<List<SparePart>> build() async {
    _skip = 0;
    _hasMore = true;
    final query = ref.read(searchQueryProvider);
    final repository = ref.read(sparePartRepositoryProvider);
    
    final initialParts = await repository.getSpareParts(query: query, skip: _skip, limit: _limit);
    if (initialParts.length < _limit) _hasMore = false;
    return initialParts;
  }

  Future<void> search(String query) async {
    ref.read(searchQueryProvider.notifier).updateQuery(query);
    _skip = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(sparePartRepositoryProvider);
      final parts = await repository.getSpareParts(query: query, skip: _skip, limit: _limit);
      if (parts.length < _limit) _hasMore = false;
      return parts;
    });
  }

  Future<void> fetchMore() async {
    if (!_hasMore || _isFetchingMore || state.isLoading || state.hasError) return;

    _isFetchingMore = true;
    _skip += _limit; 

    try {
      final query = ref.read(searchQueryProvider);
      final repository = ref.read(sparePartRepositoryProvider);
      final newParts = await repository.getSpareParts(query: query, skip: _skip, limit: _limit);

      if (newParts.isEmpty || newParts.length < _limit) _hasMore = false;
      if (newParts.isNotEmpty) {
        state = AsyncValue.data([...state.value ?? [], ...newParts]); 
      }
    } catch (e) {
      _skip -= _limit; 
    } finally {
      _isFetchingMore = false;
    }
  }

  Future<void> addPart(SparePart newPart) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      final createdPart = await repository.addSparePart(newPart);

      final currentList = state.value ?? [];
      state = AsyncValue.data([createdPart, ...currentList]);

      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePart(SparePart updatedPart) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.updateSparePart(updatedPart);

      final currentList = state.value ?? [];
      state = AsyncValue.data(
        currentList.map((p) => p.id == updatedPart.id ? updatedPart : p).toList(),
      );

      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePart(String partId) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.deleteSparePart(partId);

      final currentList = state.value ?? [];
      state = AsyncValue.data(currentList.where((p) => p.id != partId).toList());
      
      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidateSelf();
    } catch (e) {
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> recordSale(SaleRecord record) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.recordSale(record);
      
      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidate(dailySalesProvider);
      ref.invalidate(monthlySalesProvider);
      ref.invalidateSelf();
    } catch (e) {
      if (DioErrorHandler.isConnectionError(e)) {
        await OfflineSyncManager().enqueueSale(record);
        return;
      }
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> recordBulkSale(List<SaleRecord> records) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.recordBulkSale(records);

      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidate(dailySalesProvider);
      ref.invalidate(monthlySalesProvider);
      ref.invalidateSelf();
    } catch (e) {
      if (DioErrorHandler.isConnectionError(e)) {
        await OfflineSyncManager().enqueueBulkSale(records);
        return;
      }
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> cleanupDuplicates() async {
    final repository = ref.read(sparePartRepositoryProvider);
    final result = await repository.cleanupDuplicates();
    ref.invalidate(brandSummaryProvider);
    ref.invalidate(brandPartsProvider);
    ref.invalidateSelf();
    return result;
  }

  Future<Map<String, dynamic>> fixUnassignedBrands() async {
    final repository = ref.read(sparePartRepositoryProvider);
    final result = await repository.fixUnassignedBrands();
    ref.invalidate(brandSummaryProvider);
    ref.invalidate(brandPartsProvider);
    ref.invalidateSelf();
    return result;
  }

  Future<void> updateBrandName(String oldBrand, String newBrand) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.updateBrandName(oldBrand, newBrand);
      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidateSelf();
    } catch (e) {
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> deleteBrand(String brandName) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.deleteBrand(brandName);
      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidateSelf();
    } catch (e) {
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> deleteSale(SaleRecord record) async {
    try {
      if (record.id == null) return;
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.deleteSale(record.id!);
      ref.invalidate(dailySalesProvider);
      ref.invalidate(monthlySalesProvider);
      ref.invalidateSelf();
    } catch (e) {
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> updateExistingSale(String saleId, SaleRecord updatedRecord) async {
    try {
      final repository = ref.read(sparePartRepositoryProvider);
      await repository.updateSale(saleId, updatedRecord);
      ref.invalidate(brandSummaryProvider);
      ref.invalidate(brandPartsProvider);
      ref.invalidate(dailySalesProvider);
      ref.invalidate(monthlySalesProvider);
      ref.invalidateSelf();
    } catch (e) {
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }
}

final sparePartsProvider = AsyncNotifierProvider<SparePartsNotifier, List<SparePart>>(() {
  return SparePartsNotifier();
});

class BrandPartsNotifier extends AsyncNotifier<List<SparePart>> {
  final String brand;
  BrandPartsNotifier(this.brand);

  int _skip = 0;
  final int _limit = 50;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  bool get hasMore => _hasMore;
  bool get isFetchingMore => _isFetchingMore;

  @override
  Future<List<SparePart>> build() async {
    _skip = 0;
    _hasMore = true;
    _isFetchingMore = false;
    final repository = ref.read(sparePartRepositoryProvider);
    final initialParts = await repository.getSpareParts(brand: brand, skip: _skip, limit: _limit);
    if (initialParts.length < _limit) _hasMore = false;
    return initialParts;
  }

  Future<void> init([String? brandName]) async {
    _skip = 0;
    _hasMore = true;
    _isFetchingMore = false;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(sparePartRepositoryProvider);
      final targetBrand = (brandName != null && brandName.isNotEmpty) ? brandName : brand;
      final initialParts = await repository.getSpareParts(brand: targetBrand, skip: _skip, limit: _limit);
      if (initialParts.length < _limit) _hasMore = false;
      return initialParts;
    });
  }

  Future<void> fetchNextPage() async {
    if (!_hasMore || _isFetchingMore || state.isLoading || state.hasError) return;

    _isFetchingMore = true;
    _skip += _limit;

    try {
      final repository = ref.read(sparePartRepositoryProvider);
      final newParts = await repository.getSpareParts(brand: brand, skip: _skip, limit: _limit);

      if (newParts.isEmpty || newParts.length < _limit) _hasMore = false;
      if (newParts.isNotEmpty) {
        state = AsyncValue.data([...state.value ?? [], ...newParts]);
      }
    } catch (e) {
      _skip -= _limit;
    } finally {
      _isFetchingMore = false;
    }
  }

  Future<void> fetchMoreBrandParts() async {
    await fetchNextPage();
  }
}

final brandPartsProvider = AsyncNotifierProvider.family<BrandPartsNotifier, List<SparePart>, String>(
  (brand) => BrandPartsNotifier(brand),
);

final brandSummaryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(sparePartRepositoryProvider);
  return await repo.getBrandsSummary();
});

final dailySalesProvider = FutureProvider<List<SaleRecord>>((ref) async {
  final repository = ref.read(sparePartRepositoryProvider);
  final allSales = await repository.getSalesHistory();
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return allSales.where((s) => s.createdAt != null && s.createdAt!.isAfter(startOfDay)).toList();
});

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }
  void updateMonth(DateTime newMonth) => state = newMonth;
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(() => SelectedMonthNotifier());

final monthlySalesProvider = FutureProvider.autoDispose<List<SaleRecord>>((ref) async {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repository = ref.read(sparePartRepositoryProvider);
  final allSales = await repository.getSalesHistory();
  final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
  final filteredSales = allSales.where((sale) {
    if (sale.createdAt == null) return false;
    return sale.createdAt!.isAfter(startOfMonth.subtract(const Duration(days: 1))) && sale.createdAt!.isBefore(endOfMonth);
  }).toList();
  filteredSales.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  return filteredSales;
});