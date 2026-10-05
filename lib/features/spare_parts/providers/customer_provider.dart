// lib/features/spare_parts/providers/customer_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

class CustomerNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() async {
    final repo = ref.read(customerRepositoryProvider);
    return await repo.getCustomers();
  }

  Future<void> addCustomer(Customer customer) async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.addCustomer(customer);
      ref.invalidateSelf(); // Listeyi yeniler
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addTransaction(int customerId, double amount, String description, {String type = 'TAHSILAT'}) async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.addCustomerTransaction(customerId, amount, description, type);
      ref.invalidateSelf(); // Ana müşteri listesini (bakiyeleri) yeniler
      ref.invalidate(customerHistoryProvider(customerId)); // Varsa açık olan ekstreyi yeniler
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCustomer(int id, Customer customer) async {
    final repo = ref.read(customerRepositoryProvider);
    await repo.updateCustomer(id, customer);
    ref.invalidateSelf();
    ref.invalidate(customerHistoryProvider(id));
  }

  Future<void> deleteCustomer(int id) async {
    final repo = ref.read(customerRepositoryProvider);
    await repo.deleteCustomer(id);
    ref.invalidateSelf(); // Listeden anında kaybolması için
  }
}

final customerProvider = AsyncNotifierProvider<CustomerNotifier, List<Customer>>(CustomerNotifier.new);

// Arama Metni İçin State
class CustomerSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void updateQuery(String query) => state = query;
}

final customerSearchQueryProvider = NotifierProvider<CustomerSearchNotifier, String>(CustomerSearchNotifier.new);

// Ekstre Detayı İçin Ayrı Bir FutureProvider
final customerHistoryProvider = FutureProvider.family.autoDispose<CustomerHistorySummary, int>((ref, customerId) async {
  final repo = ref.read(customerRepositoryProvider);
  return await repo.getCustomerHistory(customerId);
});

// Arama Sonuçlarını Filtreleyen Provider
final filteredCustomersProvider = Provider<AsyncValue<List<Customer>>>((ref) {
  final query = ref.watch(customerSearchQueryProvider).trim().toLowerCase();
  final customersAsync = ref.watch(customerProvider);

  return customersAsync.whenData((customers) {
    if (query.isEmpty) return customers;
    return customers.where((c) {
      final nameMatch = c.name.toLowerCase().contains(query);
      final companyMatch = c.companyName?.toLowerCase().contains(query) ?? false;
      final phoneMatch = c.phone?.contains(query) ?? false;
      return nameMatch || companyMatch || phoneMatch;
    }).toList();
  });
});