import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/supplier_model.dart';
import '../repositories/supplier_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository();
});

class SupplierNotifier extends AsyncNotifier<List<Supplier>> {
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
        } catch (_) {}
      }
    }
    return suppliers;
  }

  @override
  Future<List<Supplier>> build() async {
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
      return <Supplier>[];
    }
  }

  /// [KURAL 2]: Trailing Slash OLMADAN Tedarikçi Ekleme (POST)
  Future<void> addSupplier(Supplier supplier) async {
    try {
      try {
        await dioClient.post(
          '/api/suppliers',
          data: supplier.toJson(),
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.post(
            '/suppliers',
            data: supplier.toJson(),
          );
        } else {
          rethrow;
        }
      }
      ref.invalidateSelf();
    } on DioException catch (e) {
      throw Exception('Tedarikçi eklenemedi: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      rethrow;
    }
  }

  /// [KURAL 2]: Trailing Slash OLMADAN Tedarikçi Güncelleme (PUT)
  /// Backend rotası: @app.put("/suppliers/{supplier_id}")
  Future<void> updateSupplier(Supplier supplier) async {
    if (supplier.id == null) {
      throw Exception('Güncellenecek tedarikçinin ID bilgisi eksik!');
    }

    try {
      try {
        await dioClient.put(
          '/api/suppliers/${supplier.id}',
          data: supplier.toJson(),
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.put(
            '/suppliers/${supplier.id}',
            data: supplier.toJson(),
          );
        } else {
          rethrow;
        }
      }
      ref.invalidateSelf();
    } on DioException catch (e) {
      throw Exception('Güncelleme başarısız: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Güncelleme hatası: $e');
    }
  }

  /// [KURAL 2]: Trailing Slash OLMADAN Tedarikçi Silme (DELETE)
  /// Backend rotası: @app.delete("/suppliers/{supplier_id}")
  Future<void> deleteSupplier(dynamic id) async {
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
      ref.invalidateSelf();
    } on DioException catch (e) {
      throw Exception('Silme işlemi başarısız: ${DioErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Silme hatası: $e');
    }
  }
}

final supplierProvider =
    AsyncNotifierProvider<SupplierNotifier, List<Supplier>>(
      SupplierNotifier.new,
    );

class SupplierSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void updateQuery(String query) => state = query;
}

final supplierSearchQueryProvider =
    NotifierProvider<SupplierSearchNotifier, String>(
      SupplierSearchNotifier.new,
    );

final filteredSuppliersProvider = Provider<AsyncValue<List<Supplier>>>((ref) {
  final query = ref.watch(supplierSearchQueryProvider).trim().toLowerCase();
  final suppliersAsync = ref.watch(supplierProvider);

  return suppliersAsync.whenData((suppliers) {
    if (query.isEmpty) return suppliers;
    return suppliers.where((s) {
      final nameMatch = s.name.toLowerCase().contains(query);
      final personMatch = s.contactPerson?.toLowerCase().contains(query) ?? false;
      final phoneMatch = s.phone?.contains(query) ?? false;
      final taxMatch = s.taxNumber?.contains(query) ?? false;
      return nameMatch || personMatch || phoneMatch || taxMatch;
    }).toList();
  });
});