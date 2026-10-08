import 'package:dio/dio.dart';
import 'package:on_par/core/network/dio_client.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/spare_part_model.dart';
import '../models/sale_record_model.dart';

class SparePartRepository {
  SparePartRepository();

  /// [GÖREV 1]: Kebab-Case ve /api/ Uyumlu Parça Ekleme
  Future<SparePart> addSparePart(SparePart part) async {
    try {
      final response = await dioClient.post('/api/spare-parts/', data: part.toJson());
      final data = (response.data is Map && response.data['data'] != null)
          ? response.data['data']
          : response.data;
      return SparePart.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final fallback = await dioClient.post('/spare-parts/', data: part.toJson());
        final data = (fallback.data is Map && fallback.data['data'] != null)
            ? fallback.data['data']
            : fallback.data;
        return SparePart.fromJson(Map<String, dynamic>.from(data as Map));
      }
      throw Exception('API Hatası: Parça eklenemedi - ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  Future<SparePart> addPart(SparePart part) => addSparePart(part);

  /// [GÖREV 1]: Kebab-Case ve /api/ Uyumlu Parça Güncelleme
  Future<void> updateSparePart(SparePart part) async {
    try {
      if (part.id == null) throw Exception("Güncellenecek parçanın ID'si eksik!");
      await dioClient.put('/api/spare-parts/${part.id}', data: part.toJson());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await dioClient.put('/spare-parts/${part.id}', data: part.toJson());
        return;
      }
      throw Exception('API Hatası: Parça güncellenemedi - ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  Future<void> updatePart(SparePart part) => updateSparePart(part);

  /// [GÖREV 1]: Kebab-Case ve /api/ Uyumlu Parça Silme (Soft-Delete)
  Future<void> deleteSparePart(String partId) async {
    try {
      await dioClient.delete('/api/spare-parts/$partId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await dioClient.delete('/spare-parts/$partId');
        return;
      }
      throw Exception('API Hatası: Parça silinemedi - ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  /// [GÖREV 1]: Kebab-Case ve /api/ Uyumlu Satış Kaydı
  Future<void> recordSale(SaleRecord record) async {
    try {
      await dioClient.post('/api/sales/', data: record.toJson());
    } on DioException catch (e) {
      if (DioErrorHandler.isConnectionError(e)) {
        await OfflineSyncManager().enqueueSale(record);
        return;
      }
      if (e.response?.statusCode == 404) {
        await dioClient.post('/sales/', data: record.toJson());
        return;
      }
      throw Exception('Satış reddedildi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  /// [GÖREV 1]: Kebab-Case ve /api/ Uyumlu Toplu Satış
  Future<void> recordBulkSale(List<SaleRecord> records) async {
    try {
      final payload = {
        'items': records.map((r) => r.toJson()).toList(),
      };
      await dioClient.post('/api/sales/bulk', data: payload);
    } on DioException catch (e) {
      if (DioErrorHandler.isConnectionError(e)) {
        await OfflineSyncManager().enqueueBulkSale(records);
        return;
      }
      if (e.response?.statusCode == 404) {
        await dioClient.post('/sales/bulk', data: {'items': records.map((r) => r.toJson()).toList()});
        return;
      }
      throw Exception('Toplu satış reddedildi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  /// [GÖREV 1]: Kebab-Case ve /api/ Uyumlu Parça Listeleme (Parametre: search)
  Future<List<SparePart>> getSpareParts({
    String query = '', 
    String? brand, 
    int skip = 0, 
    int limit = 50
  }) async {
    try {
      final response = await dioClient.get(
        '/api/spare-parts/',
        queryParameters: {
          if (query.isNotEmpty) 'search': query,
          if (brand != null && brand.isNotEmpty && brand != 'Diğer / Markasız') 'brand': brand,
          'skip': skip,
          'limit': limit,
        },
      );
      final parts = _parseSparePartsList(response.data);
      
      if (parts.isNotEmpty) {
        OfflineSyncManager().cacheSpareParts(parts);
      }
      return parts;
    } on DioException catch (e) {
      if (DioErrorHandler.isConnectionError(e)) {
        return await OfflineSyncManager().getCachedSparePartsPaged(
          query: query,
          brand: brand,
          limit: limit,
          offset: skip,
        );
      }
      if (e.response?.statusCode == 404) {
        final fallback = await dioClient.get(
          '/spare-parts/',
          queryParameters: {
            if (query.isNotEmpty) 'search': query,
            if (brand != null && brand.isNotEmpty) 'brand': brand,
            'skip': skip,
            'limit': limit,
          },
        );
        final parts = _parseSparePartsList(fallback.data);
        if (parts.isNotEmpty) {
          OfflineSyncManager().cacheSpareParts(parts);
        }
        return parts;
      }
      throw Exception('Parçalar çekilemedi: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Parçalar işlenemedi: $e');
    }
  }

  /// Satış Geçmişi (/api/sales/history)
  Future<List<SaleRecord>> getSalesHistory() async {
    try {
      final response = await dioClient.get('/api/sales/history');
      return _parseSalesList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final fallback = await dioClient.get('/sales/history');
        return _parseSalesList(fallback.data);
      }
      throw Exception('Satış geçmişi çekilemedi: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Satış verisi işlenemedi: $e');
    }
  }

  /// Marka Özetleri (/api/brands/summary)
  Future<List<Map<String, dynamic>>> getBrandsSummary() async {
    try {
      final response = await dioClient.get('/api/brands/summary');
      return _parseBrandsList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final fallback = await dioClient.get('/brands/summary');
        return _parseBrandsList(fallback.data);
      }
      throw Exception('Marka özeti alınamadı: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Marka verisi işlenemedi: $e');
    }
  }

  List<SparePart> _parseSparePartsList(dynamic rawData) {
    if (rawData == null) return [];
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map) {
      list = (rawData['data'] ?? rawData['items'] ?? rawData['spare_parts'] ?? []) as List<dynamic>;
    } else {
      return [];
    }
    final parts = <SparePart>[];
    for (final item in list) {
      if (item is Map) {
        try {
          final part = SparePart.fromJson(Map<String, dynamic>.from(item));
          if (!part.isDeleted) {
            parts.add(part);
          }
        } catch (_) {
          // Bireysel parse hatasında diğer ürünleri feda etme
        }
      }
    }
    return parts;
  }

  List<SaleRecord> _parseSalesList(dynamic rawData) {
    if (rawData == null) return [];
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map) {
      list = (rawData['data'] ?? rawData['items'] ?? rawData['sales'] ?? []) as List<dynamic>;
    } else {
      return [];
    }
    final sales = <SaleRecord>[];
    for (final item in list) {
      if (item is Map) {
        try {
          sales.add(SaleRecord.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }
    return sales;
  }

  List<Map<String, dynamic>> _parseBrandsList(dynamic rawData) {
    if (rawData == null) return [];
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map) {
      list = (rawData['data'] ?? rawData['items'] ?? rawData['brands'] ?? []) as List<dynamic>;
    } else {
      return [];
    }
    final brands = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is Map) {
        try {
          final summary = BrandSummary.fromJson(Map<String, dynamic>.from(item));
          brands.add(summary.toJson());
        } catch (_) {
          final map = Map<String, dynamic>.from(item);
          final rawCount = map['total_items'] ?? map['totalItems'] ?? map['count'] ?? 0;
          final count = int.tryParse(rawCount.toString()) ?? 0;
          map['total_items'] = count;
          map['totalItems'] = count;
          map['count'] = count;
          brands.add(map);
        }
      }
    }
    return brands;
  }

  /// [GÖREV 3]: Gemini AI Akıllı Barkod (/api/ai/smart-barcode)
  Future<Map<String, dynamic>> fetchAiSmartBarcode(String barcode, {String? promptHint}) async {
    try {
      final response = await dioClient.post(
        '/api/ai/smart-barcode',
        data: {
          'barcode': barcode.trim(),
          if (promptHint != null && promptHint.trim().isNotEmpty)
            'prompt_hint': promptHint.trim(),
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      if (response.data is Map && response.data['data'] != null) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final fallback = await dioClient.post(
          '/ai/smart-barcode',
          data: {
            'barcode': barcode.trim(),
            if (promptHint != null && promptHint.trim().isNotEmpty)
              'prompt_hint': promptHint.trim(),
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
          ),
        );
        if (fallback.data is Map && fallback.data['data'] != null) {
          return Map<String, dynamic>.from(fallback.data['data']);
        }
        return Map<String, dynamic>.from(fallback.data);
      }
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  /// [GÖREV 4]: Mükerrer Kayıtları Temizle (/api/cleanup-duplicates)
  Future<Map<String, dynamic>> cleanupDuplicates() async {
    try {
      final response = await dioClient.post('/api/cleanup-duplicates');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final fallback = await dioClient.post('/cleanup-duplicates');
        return Map<String, dynamic>.from(fallback.data);
      }
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  /// [GÖREV 4]: Kayıp Markaları Otomatik Onar (/api/fix-unassigned-brands)
  Future<Map<String, dynamic>> fixUnassignedBrands() async {
    try {
      final response = await dioClient.post('/api/fix-unassigned-brands');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final fallback = await dioClient.post('/fix-unassigned-brands');
        return Map<String, dynamic>.from(fallback.data);
      }
      throw Exception(DioErrorHandler.getErrorMessage(e));
    }
  }

  /// Satış Silme / İptal (/api/sales/:id)
  Future<void> deleteSale(String saleId) async {
    try {
      await dioClient.delete('/api/sales/$saleId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await dioClient.delete('/sales/$saleId');
        return;
      }
      throw Exception('Satış silinemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Satış Güncelleme (/api/sales/:id)
  Future<void> updateSale(String saleId, SaleRecord updatedRecord) async {
    try {
      await dioClient.put('/api/sales/$saleId', data: updatedRecord.toJson());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await dioClient.put('/sales/$saleId', data: updatedRecord.toJson());
        return;
      }
      throw Exception('Satış güncellenemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Marka İsmi Güncelleme
  Future<void> updateBrandName(String oldBrand, String newBrand) async {
    try {
      await dioClient.put(
        '/api/spare-parts/brand',
        data: {'old_brand': oldBrand, 'new_brand': newBrand},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await dioClient.put(
          '/spare_parts/brand',
          data: {'old_brand': oldBrand, 'new_brand': newBrand},
        );
        return;
      }
      throw Exception('Marka güncellenemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Marka ve Ürünlerini Silme
  Future<void> deleteBrand(String brandName) async {
    try {
      await dioClient.delete('/api/spare-parts/brand/$brandName');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await dioClient.delete('/spare_parts/brand/$brandName');
        return;
      }
      throw Exception('Marka silinemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }
}