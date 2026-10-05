// lib/features/spare_parts/repositories/customer_repository.dart

import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  CustomerRepository();

  Future<List<Customer>> getCustomers() async {
    try {
      Response response;
      try {
        response = await dioClient.get('/api/customers');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          response = await dioClient.get('/customers');
        } else {
          rethrow;
        }
      }
      final list = (response.data is List) ? response.data as List : [];
      return list.map((e) => Customer.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw Exception('Müşteriler çekilemedi: $e');
    }
  }

  Future<Customer> addCustomer(Customer customer) async {
    try {
      Response response;
      try {
        response = await dioClient.post('/api/customers', data: customer.toJson());
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          response = await dioClient.post('/customers', data: customer.toJson());
        } else {
          rethrow;
        }
      }
      return Customer.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Müşteri eklenemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  Future<void> addCustomerTransaction(int customerId, double amount, String description, String type) async {
    try {
      try {
        await dioClient.post(
          '/api/customers/$customerId/transaction',
          data: {
            'amount': amount,
            'description': description,
            'transaction_type': type, // 'TAHSILAT' veya 'BORCLANDIRMA'
          },
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.post(
            '/customers/$customerId/transaction',
            data: {
              'amount': amount,
              'description': description,
              'transaction_type': type,
            },
          );
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw Exception('İşlem kaydedilemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  Future<void> updateCustomer(int id, Customer customer) async {
    try {
      try {
        await dioClient.put('/api/customers/$id', data: customer.toJson());
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.put('/customers/$id', data: customer.toJson());
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw Exception('Müşteri güncellenemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  Future<void> deleteCustomer(int id) async {
    try {
      try {
        await dioClient.delete('/api/customers/$id');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          await dioClient.delete('/customers/$id');
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw Exception('Müşteri silinemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }

  Future<CustomerHistorySummary> getCustomerHistory(int customerId) async {
    try {
      Response response;
      try {
        response = await dioClient.get('/api/customers/$customerId/history');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          response = await dioClient.get('/customers/$customerId/history');
        } else {
          rethrow;
        }
      }
      return CustomerHistorySummary.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Hesap özeti çekilemedi: ${DioErrorHandler.getErrorMessage(e)}');
    }
  }
}