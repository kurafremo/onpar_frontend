import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/supplier_model.dart';

/// Tedarikçi Veri Deposu (/api/suppliers/ rotaları ile tam uyumlu)
class SupplierRepository {
  SupplierRepository();

  List<Supplier> _parseSuppliersList(dynamic rawData) {
    if (rawData == null) return [];
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map) {
      list = (rawData['data'] ?? rawData['items'] ?? rawData['suppliers'] ?? []) as List<dynamic>;
    } else {
      return [];
    }
    final suppliers = <Supplier>[];
    for (final item in list) {
      if (item is Map) {
        try {
          final supplier = Supplier.fromJson(Map<String, dynamic>.from(item));
          if (!supplier.isDeleted) {
            suppliers.add(supplier);
          }
        } catch (_) {
          // Bireysel hata tüm listeyi bozmasın
        }
      }
    }
    return suppliers;
  }

  Future<List<Supplier>> getSuppliers() async {
    try {
      Response response;
      try {
        response = await dioClient.get('/api/suppliers');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          response = await dioClient.get('/suppliers');
        } else {
          rethrow;
        }
      }
      return _parseSuppliersList(response.data);
    } catch (e) {
      throw Exception('Tedarikçi listesi yüklenemedi: $e');
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    try {
      try {
        await dioClient.post('/api/suppliers', data: supplier.toJson());
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.post('/suppliers', data: supplier.toJson());
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw Exception('Tedarikçi eklenemedi: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Ağ hatası: $e');
    }
  }

  Future<void> updateSupplier(Supplier supplier) async {
    try {
      if (supplier.id == null) throw Exception("Güncellenecek tedarikçi ID'si eksik!");
      try {
        await dioClient.put('/api/suppliers/${supplier.id}', data: supplier.toJson());
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.put('/suppliers/${supplier.id}', data: supplier.toJson());
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw Exception('Güncelleme hatası: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Ağ hatası: $e');
    }
  }

  Future<void> deleteSupplier(String id) async {
    try {
      try {
        await dioClient.delete('/api/suppliers/$id');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.delete('/suppliers/$id');
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw Exception('Silme işlemi başarısız: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Ağ hatası: $e');
    }
  }
}