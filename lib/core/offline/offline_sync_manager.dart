import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/spare_parts/models/sale_record_model.dart';
import '../../features/spare_parts/models/spare_part_model.dart';
import '../network/dio_client.dart';
import '../utils/snackbar_utils.dart';
import 'local_database_helper.dart';

/// Çevrimdışı Kuyruk ve Senkronizasyon Yöneticisi (Enterprise Offline Sync Engine - SQLite Powered)
/// Bellek şişmesini (RAM leak/OOM) önlemek için SQLite disk tabanlı mimari kullanır.
class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper();
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Bekleyen satış sayısını döner (Disk üzerinden COUNT)
  Future<int> getPendingQueueCount() async {
    return await _dbHelper.getQueueCount();
  }

  /// Satışı yerel SQLite kuyruğuna ekler (FIFO)
  Future<void> enqueueSale(SaleRecord record) async {
    await _dbHelper.enqueueSale(record);

    AppSnackBar.showOffline(
      null,
      'İnternet yok: Satış SQLite disk kuyruğuna kaydedildi. Bağlantı kurulduğunda sunucuya aktarılacak.',
    );
  }

  /// Toplu satışları yerel SQLite kuyruğuna ekler
  Future<void> enqueueBulkSale(List<SaleRecord> records) async {
    await _dbHelper.enqueueBulkSale(records);

    AppSnackBar.showOffline(
      null,
      '${records.length} parça SQLite kuyruğuna alındı. Ağ açıldığında otomatik senkronize edilecek.',
    );
  }

  /// Ağ geri geldiğinde bekleyen kuyruktaki tüm satışları sırayla sunucuya gönderir (FIFO)
  Future<int> syncPendingSales() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    try {
      final pendingQueue = await _dbHelper.getPendingSalesQueue();
      if (pendingQueue.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      int successCount = 0;

      for (final row in pendingQueue) {
        final queueId = row['id'] as int;
        try {
          // Satış nesnesini oluştur ve sunucuya gönder
          final payload = {
            'client_transaction_id': row['client_transaction_id'],
            'part_id': row['part_id'],
            'part_name': row['part_name'],
            'quantity': row['quantity'],
            'unit_price': row['unit_price'],
            'total_price': row['total_price'],
            'buyer_name': row['buyer_name'],
            'company_name': row['company_name'],
            'vehicle_plate': row['vehicle_plate'],
            'vehicle_brand_model': row['vehicle_brand_model'],
            'vehicle_info': row['vehicle_info'],
            'notes': row['notes'],
          };

          await dioClient.post('/sales', data: payload);
          // Başarılıysa diskteki kuyruktan temizle
          await _dbHelper.removeSaleFromQueue(queueId);
          successCount++;
        } catch (e) {
          // Bu kayıt başarısız olursa kuyrukta kalır ve bir sonraki turda tekrar denenir
          debugPrint('SQLite kuyruğundaki satış ($queueId) senkronize edilemedi: $e');
        }
      }

      if (successCount > 0) {
        AppSnackBar.showSuccess(
          null,
          'Senkronizasyon Başarılı: $successCount adet çevrimdışı satış sunucuya aktarıldı!',
        );
      }

      return successCount;
    } finally {
      _isSyncing = false;
    }
  }

  /// Stok kataloğunu SQLite tablosuna batch olarak yazar (RAM şişmez, diske saklanır)
  Future<void> cacheSpareParts(List<SparePart> parts) async {
    try {
      await _dbHelper.upsertSpareParts(parts);
    } catch (e) {
      debugPrint('SQLite stok önbelleğe alma hatası: $e');
    }
  }

  /// Çevrimdışı durumdayken diskten 50'şerli (LIMIT/OFFSET) sayfalama ile okur
  Future<List<SparePart>> getCachedSparePartsPaged({
    String query = '',
    String? brand,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _dbHelper.getSparePartsPaged(
        query: query,
        brand: brand,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('SQLite önbellek okuma hatası: $e');
      return [];
    }
  }

  /// Çevrimdışı durumdayken kritik stok listesini diskten okur
  Future<List<SparePart>> getCachedCriticalParts() async {
    try {
      return await _dbHelper.getCriticalStockParts();
    } catch (e) {
      debugPrint('SQLite kritik stok okuma hatası: $e');
      return [];
    }
  }
}

/// Riverpod Sağlayıcısı
final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  return OfflineSyncManager();
});

/// Bekleyen kuyruktaki satış adedini dinleyen Notifier
class OfflineQueueCountNotifier extends Notifier<int> {
  @override
  int build() {
    _loadCount();
    return 0;
  }

  Future<void> _loadCount() async {
    final count = await OfflineSyncManager().getPendingQueueCount();
    state = count;
  }

  Future<void> refresh() async {
    await _loadCount();
  }
}

final offlineQueueCountProvider =
    NotifierProvider<OfflineQueueCountNotifier, int>(() {
  return OfflineQueueCountNotifier();
});
