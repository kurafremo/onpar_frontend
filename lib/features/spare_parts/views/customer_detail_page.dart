// lib/features/spare_parts/views/customer_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  final Customer customer;
  const CustomerDetailPage({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  void _showTahsilatModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedPaymentType = 'Nakit';
    bool isSaving = false;

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
          isDense: true,
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tahsilat Al',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPaymentType,
                      decoration: fieldDec('Ödeme Türü', Icons.account_balance_wallet_rounded),
                      items: ['Nakit', 'Kredi Kartı', 'Havale / EFT'].map((String val) {
                        return DropdownMenuItem(value: val, child: Text(val));
                      }).toList(),
                      onChanged: (newVal) {
                        if (newVal != null) setState(() => selectedPaymentType = newVal);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: fieldDec('Alınan Tutar (TL) *', Icons.attach_money_rounded),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Tutar giriniz';
                        if (double.tryParse(val.replaceAll(',', '.')) == null) {
                          return 'Geçerli bir rakam girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: fieldDec('Açıklama (Opsiyonel)', Icons.notes_rounded),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => isSaving = true);
                                try {
                                  final amount =
                                      double.parse(amountController.text.replaceAll(',', '.'));
                                  final userDesc = descController.text.trim();
                                  final finalDesc =
                                      "[$selectedPaymentType] ${userDesc.isEmpty ? 'Tahsilat yapıldı' : userDesc}";

                                  await ref.read(customerProvider.notifier).addTransaction(
                                        widget.customer.id!,
                                        amount,
                                        finalDesc,
                                        type: 'TAHSILAT',
                                      );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    AppSnackBar.showSuccess(
                                      context,
                                      'Tahsilat başarıyla kaydedildi!',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.showError(
                                      context,
                                      'Hata: ${DioErrorHandler.getErrorMessage(e)}',
                                    );
                                  }
                                } finally {
                                  if (context.mounted) setState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text(
                                'TAHSİLATI KAYDET',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCustomerModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: widget.customer.name);
    final companyController = TextEditingController(text: widget.customer.companyName);
    final phoneController = TextEditingController(text: widget.customer.phone);
    final taxNumberController = TextEditingController(text: widget.customer.taxNumber);
    final taxOfficeController = TextEditingController(text: widget.customer.taxOffice);
    final addressController = TextEditingController(text: widget.customer.address);
    bool isSaving = false;

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
          isDense: true,
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cari Bilgilerini Düzenle',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.corporateNavy,
                            ),
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
                        decoration: fieldDec('Usta / Firma Adı *', Icons.person_rounded),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'İsim zorunludur' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: companyController,
                        decoration: fieldDec('Şirket Ünvanı', Icons.business_rounded),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: fieldDec('Telefon', Icons.phone_rounded),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: taxNumberController,
                              decoration: InputDecoration(
                                labelText: 'VKN/TCKN',
                                labelStyle: const TextStyle(color: AppColors.textDark),
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
                                isDense: true,
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
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.corporateNavy),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: fieldDec('Adres', Icons.location_on_rounded),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.corporateNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() => isSaving = true);
                                  try {
                                    final updatedCust = Customer(
                                      id: widget.customer.id,
                                      name: nameController.text.trim(),
                                      companyName: companyController.text.trim(),
                                      phone: phoneController.text.trim(),
                                      taxNumber: taxNumberController.text.trim(),
                                      taxOffice: taxOfficeController.text.trim(),
                                      address: addressController.text.trim(),
                                      balance: widget.customer.balance,
                                    );
                                    await ref
                                        .read(customerProvider.notifier)
                                        .updateCustomer(widget.customer.id!, updatedCust);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      AppSnackBar.showSuccess(context, 'Cari güncellendi!');
                                      Navigator.pop(context);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppSnackBar.showError(context, 'Hata: $e');
                                    }
                                  } finally {
                                    if (context.mounted) setState(() => isSaving = false);
                                  }
                                },
                          child: isSaving
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Text(
                                  'GÜNCELLE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
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
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(customerHistoryProvider(widget.customer.id!));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(widget.customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.corporateNavy),
            tooltip: 'Cari Düzenle',
            onPressed: () => _showEditCustomerModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed),
            tooltip: 'Cariyi Sil',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Cariyi Sil',
                      style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold)),
                  content: Text(
                    '"${widget.customer.name}" isimli müşteriyi silmek istediğinize emin misiniz?\n\nGeçmiş satış verileri bozulmaz ancak bu müşteri artık listede görünmez.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await ref
                              .read(customerProvider.notifier)
                              .deleteCustomer(widget.customer.id!);
                          if (context.mounted) {
                            Navigator.pop(context);
                            AppSnackBar.showSuccess(context, 'Müşteri başarıyla silindi.');
                          }
                        } catch (e) {
                          if (context.mounted) AppSnackBar.showError(context, 'Hata: $e');
                        }
                      },
                      child: const Text('Evet, Sil'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: historyAsync.when(
        data: (summary) {
          final isDebt = summary.currentBalance > 0;
          final isCleared = summary.currentBalance <= 0;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.corporateNavy.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    if (isCleared)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'HESAP KAPALI',
                          style: TextStyle(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Text(
                      'Güncel Bakiye (Müşterinin Borcu)',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(summary.currentBalance),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: isDebt ? AppColors.dangerRed : AppColors.successGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showTahsilatModal(context),
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: const Text('TAHSİLAT AL',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hesap Hareketleri (Ekstre)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.corporateNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: summary.history.isEmpty
                    ? const Center(
                        child: Text(
                          'Henüz hiçbir hesap hareketi yok.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: summary.history.length,
                        itemBuilder: (context, index) {
                          final item = summary.history[index];
                          final isPayment = item.type == 'TRANSACTION';
                          final dateStr =
                              DateFormat('dd.MM.yyyy HH:mm').format(item.date.toLocal());

                          String detailText = dateStr;
                          if (!isPayment && item.quantity != null && item.unitPrice != null) {
                            detailText += '  •  ${item.quantity} Adet x ₺${item.unitPrice}';
                          }

                          return Card(
                            elevation: 0.5,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPayment
                                    ? AppColors.successGreen.withValues(alpha: 0.12)
                                    : AppColors.dangerRed.withValues(alpha: 0.12),
                                child: Icon(
                                  isPayment ? Icons.arrow_downward_rounded : Icons.shopping_cart_rounded,
                                  color: isPayment ? AppColors.successGreen : AppColors.dangerRed,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isPayment
                                          ? (item.description ?? 'Tahsilat')
                                          : (item.partName ?? 'Veresiye Satış'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.corporateNavy,
                                        decoration: isCleared && !isPayment
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (!isPayment && item.paymentMethod != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.energeticOrange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.paymentMethod!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.energeticOrange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(detailText, style: const TextStyle(fontSize: 12)),
                              trailing: Text(
                                '${isPayment ? "-" : "+"} ${currencyFormat.format(item.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isPayment ? AppColors.successGreen : AppColors.dangerRed,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.corporateNavy),
        ),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }
}