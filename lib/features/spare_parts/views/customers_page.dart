// lib/features/spare_parts/views/customers_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/state_feedback_widget.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import 'customer_detail_page.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  void _showAddCustomerModal(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    final taxNumberController = TextEditingController();
    final taxOfficeController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    bool isLoading = false;

    InputDecoration fieldDec(String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textDark),
          prefixIcon: Icon(icon, color: AppColors.corporateNavy, size: 20),
          filled: true,
          fillColor: AppColors.backgroundLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.corporateNavy),
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ──────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Yeni Cari / Usta Ekle',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.corporateNavy),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: nameController,
                        decoration: fieldDec('Usta / Firma Adı *', Icons.person),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'İsim zorunludur' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: companyController,
                        decoration: fieldDec(
                            'Dükkan / Şirket Ünvanı (Opsiyonel)', Icons.business),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: fieldDec('Telefon', Icons.phone),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: taxNumberController,
                              decoration: InputDecoration(
                                labelText: 'Vergi No / TCKN',
                                labelStyle: const TextStyle(color: AppColors.textDark),
                                filled: true,
                                fillColor: AppColors.backgroundLight,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: AppColors.corporateNavy),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: taxOfficeController,
                              decoration: InputDecoration(
                                labelText: 'Vergi Dairesi',
                                labelStyle: const TextStyle(color: AppColors.textDark),
                                filled: true,
                                fillColor: AppColors.backgroundLight,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: AppColors.corporateNavy),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: fieldDec('Adres', Icons.location_on),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: fieldDec('Özel Notlar', Icons.note_alt),
                      ),
                      const SizedBox(height: 24),

                      // ── Save button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.corporateNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() => isLoading = true);
                                  try {
                                    final newCustomer = Customer(
                                      name: nameController.text.trim(),
                                      companyName: companyController.text.trim(),
                                      phone: phoneController.text.trim(),
                                      taxNumber: taxNumberController.text.trim(),
                                      taxOffice: taxOfficeController.text.trim(),
                                      address: addressController.text.trim(),
                                      notes: notesController.text.trim(),
                                    );
                                    await ref
                                        .read(customerProvider.notifier)
                                        .addCustomer(newCustomer);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      AppSnackBar.showSuccess(
                                          context, 'Cari hesap başarıyla açıldı!');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppSnackBar.showError(context,
                                          'Hata: ${DioErrorHandler.getErrorMessage(e)}');
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setState(() => isLoading = false);
                                    }
                                  }
                                },
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                              : const Text('KAYDET',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredCustomersAsync = ref.watch(filteredCustomersProvider);
    final searchQuery = ref.watch(customerSearchQueryProvider);
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Müşterilerim (Veresiye)',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              onChanged: (value) =>
                  ref.read(customerSearchQueryProvider.notifier).updateQuery(value),
              decoration: InputDecoration(
                hintText: 'Müşteri, Usta veya Firma Ara...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.corporateNavy),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                        onPressed: () =>
                            ref.read(customerSearchQueryProvider.notifier).updateQuery(''),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          Expanded(
            child: filteredCustomersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return StateFeedbackWidget.empty(
                    icon: Icons.people_outline,
                    title: 'Kayıtlı Cari / Müşteri bulunamadı',
                    message: 'Alttaki butona dokunarak yeni bir cari hesap açabilirsiniz.',
                    actionLabel: 'Cari Ekle',
                    actionIcon: Icons.person_add,
                    onAction: () => _showAddCustomerModal(context, ref),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.energeticOrange,
                  onRefresh: () async => ref.invalidate(customerProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final isDebt = customer.balance > 0;
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    CustomerDetailPage(customer: customer)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppColors.corporateNavy.withValues(alpha: 0.10),
                                  child: const Icon(Icons.person,
                                      color: AppColors.corporateNavy),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.corporateNavy,
                                        ),
                                      ),
                                      if (customer.companyName != null &&
                                          customer.companyName!.isNotEmpty)
                                        Text(
                                          customer.companyName!,
                                          style: TextStyle(
                                              color: Colors.grey[600], fontSize: 13),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Bakiye',
                                        style:
                                            TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(
                                      currencyFormat.format(customer.balance),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDebt
                                            ? AppColors.dangerRed
                                            : AppColors.successGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.corporateNavy),
              ),
              error: (err, stack) => StateFeedbackWidget.error(
                error: err,
                onRetry: () => ref.invalidate(customerProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab',
        onPressed: () => _showAddCustomerModal(context, ref),
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Cari Ekle', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}