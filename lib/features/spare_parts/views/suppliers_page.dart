import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/state_feedback_widget.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (context.mounted) {
        AppSnackBar.showError(context, 'Arama başlatılamadı. Numarayı kontrol edin.');
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tedarikçiyi Sil',
            style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold)),
        content: Text(
          '${supplier.name} adlı tedarikçiyi silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İPTAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SİL'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supplierProvider.notifier).deleteSupplier(int.parse(supplier.id!));
        if (context.mounted) {
          AppSnackBar.showSuccess(context, 'Tedarikçi başarıyla silindi!');
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            'Tedarikçi silinemedi: ${DioErrorHandler.getErrorMessage(e)}',
          );
        }
      }
    }
  }

  // ── Add / Edit modal ─────────────────────────────────────────────────────────
  void _showSupplierModal(
    BuildContext context,
    WidgetRef ref, {
    Supplier? existingSupplier,
  }) {
    final formKey = GlobalKey<FormState>();
    final isEditing = existingSupplier != null;

    final nameController = TextEditingController(text: existingSupplier?.name ?? '');
    final contactController = TextEditingController(text: existingSupplier?.contactPerson ?? '');
    final phoneController = TextEditingController(text: existingSupplier?.phone ?? '');
    final emailController = TextEditingController(text: existingSupplier?.email ?? '');
    final addressController = TextEditingController(text: existingSupplier?.address ?? '');
    final taxNumberController = TextEditingController(text: existingSupplier?.taxNumber ?? '');
    final taxOfficeController = TextEditingController(text: existingSupplier?.taxOffice ?? '');
    final notesController = TextEditingController(text: existingSupplier?.notes ?? '');

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
        bool isLoading = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ────────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditing ? 'Tedarikçiyi Düzenle' : 'Yeni Tedarikçi Ekle',
                            style: const TextStyle(
                              fontSize: 20,
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
                        decoration: fieldDec('Firma / Toptancı Adı *', Icons.business),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Firma adı gereklidir' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: contactController,
                              decoration: fieldDec('İlgili Kişi', Icons.person_outline),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: fieldDec('Telefon', Icons.phone),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: fieldDec('E-Posta', Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: taxNumberController,
                              decoration: fieldDec('Vergi No (VKN)', Icons.badge_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: taxOfficeController,
                              decoration: fieldDec('Vergi Dairesi', Icons.account_balance_outlined),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: addressController,
                              decoration: fieldDec('Adres', Icons.location_on_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: fieldDec('Özel Notlar', Icons.note_alt_outlined),
                      ),
                      const SizedBox(height: 24),

                      // ── Save button ───────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.corporateNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() => isLoading = true);

                                  try {
                                    final supplierData = Supplier(
                                      id: existingSupplier?.id,
                                      name: nameController.text.trim(),
                                      contactPerson: contactController.text.trim().isEmpty
                                          ? null
                                          : contactController.text.trim(),
                                      phone: phoneController.text.trim().isEmpty
                                          ? null
                                          : phoneController.text.trim(),
                                      email: emailController.text.trim().isEmpty
                                          ? null
                                          : emailController.text.trim(),
                                      address: addressController.text.trim().isEmpty
                                          ? null
                                          : addressController.text.trim(),
                                      taxNumber: taxNumberController.text.trim().isEmpty
                                          ? null
                                          : taxNumberController.text.trim(),
                                      taxOffice: taxOfficeController.text.trim().isEmpty
                                          ? null
                                          : taxOfficeController.text.trim(),
                                      notes: notesController.text.trim().isEmpty
                                          ? null
                                          : notesController.text.trim(),
                                    );

                                    if (isEditing) {
                                      await ref
                                          .read(supplierProvider.notifier)
                                          .updateSupplier(supplierData);
                                    } else {
                                      await ref
                                          .read(supplierProvider.notifier)
                                          .addSupplier(supplierData);
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      AppSnackBar.showSuccess(
                                        context,
                                        isEditing
                                            ? 'Tedarikçi başarıyla güncellendi!'
                                            : 'Tedarikçi başarıyla eklendi!',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppSnackBar.showError(
                                        context,
                                        'İşlem başarısız: ${DioErrorHandler.getErrorMessage(e)}',
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setState(() => isLoading = false);
                                    }
                                  }
                                },
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Text(
                                  'KAYDET',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  // ── Supplier details bottom sheet ────────────────────────────────────────────
  void _showSupplierDetailsModal(BuildContext context, Supplier supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.corporateNavy.withValues(alpha: 0.10),
                    child: const Icon(Icons.business, color: AppColors.corporateNavy, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      supplier.name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.corporateNavy),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32, thickness: 1),

              _buildDetailRow(Icons.person, 'Yetkili', supplier.contactPerson),
              _buildDetailRow(Icons.phone, 'Telefon', supplier.phone),
              _buildDetailRow(Icons.email, 'E-posta', supplier.email),
              _buildDetailRow(Icons.location_on, 'Adres', supplier.address),
              _buildDetailRow(Icons.receipt_long, 'Vergi Dairesi', supplier.taxOffice),
              _buildDetailRow(Icons.numbers, 'Vergi No (VKN)', supplier.taxNumber),

              if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
                const Divider(height: 24, thickness: 1),
                Row(
                  children: [
                    Icon(Icons.note_alt, color: AppColors.energeticOrange, size: 20),
                    const SizedBox(width: 8),
                    const Text('Özel Notlar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.energeticOrange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.energeticOrange.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    supplier.notes!,
                    style: TextStyle(
                      color: AppColors.energeticOrange.withValues(alpha: 0.90),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.corporateNavy, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredSuppliersAsync = ref.watch(filteredSuppliersProvider);
    final searchQuery = ref.watch(supplierSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Tedarikçilerim'),
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              onChanged: (value) =>
                  ref.read(supplierSearchQueryProvider.notifier).updateQuery(value),
              decoration: InputDecoration(
                hintText: 'Toptancı Ara (İsim, Yetkili, Tel, Vergi No)...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.corporateNavy),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                        onPressed: () {
                          ref.read(supplierSearchQueryProvider.notifier).updateQuery('');
                        },
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
            child: filteredSuppliersAsync.when(
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  if (searchQuery.isNotEmpty) {
                    return StateFeedbackWidget.empty(
                      icon: Icons.search_off_rounded,
                      title: 'Tedarikçi Bulunamadı',
                      message: '"$searchQuery" aramasına uygun tedarikçi kaydı bulunamadı.',
                      actionLabel: 'Aramayı Temizle',
                      actionIcon: Icons.clear,
                      onAction: () =>
                          ref.read(supplierSearchQueryProvider.notifier).updateQuery(''),
                    );
                  }
                  return StateFeedbackWidget.empty(
                    icon: Icons.local_shipping_outlined,
                    title: 'Tedarikçi Bulunmuyor',
                    message: 'Sisteme kayıtlı herhangi bir toptancı / tedarikçi yok.',
                    actionLabel: 'Yeni Tedarikçi Ekle',
                    actionIcon: Icons.add,
                    onAction: () => _showSupplierModal(context, ref),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.energeticOrange,
                  onRefresh: () async => ref.invalidate(supplierProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: suppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = suppliers[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showSupplierDetailsModal(context, supplier),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.corporateNavy.withValues(alpha: 0.10),
                                child: const Icon(Icons.business,
                                    color: AppColors.corporateNavy),
                              ),
                              title: Text(
                                supplier.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.corporateNavy,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  if (supplier.contactPerson != null &&
                                      supplier.contactPerson!.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(supplier.contactPerson!,
                                            style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  if (supplier.phone != null && supplier.phone!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: InkWell(
                                        onTap: () =>
                                            _makePhoneCall(context, supplier.phone!),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone,
                                                size: 14, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text(
                                              supplier.phone!,
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (supplier.taxNumber != null &&
                                      supplier.taxNumber!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'VKN: ${supplier.taxNumber}${supplier.taxOffice != null ? " (${supplier.taxOffice})" : ""}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (supplier.notes != null && supplier.notes!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Not: ${supplier.notes}',
                                        style: const TextStyle(
                                          color: AppColors.textDark,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AppColors.energeticOrange),
                                    tooltip: 'Düzenle',
                                    onPressed: () => _showSupplierModal(
                                      context,
                                      ref,
                                      existingSupplier: supplier,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.dangerRed),
                                    tooltip: 'Sil',
                                    onPressed: () =>
                                        _confirmDelete(context, ref, supplier),
                                  ),
                                ],
                              ),
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
                onRetry: () => ref.refresh(supplierProvider),
              ),
            ),
          ),
        ],
      ),
      // ONE FloatingActionButton — no AppBar add icon
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'suppliers_fab',
        onPressed: () => _showSupplierModal(context, ref),
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tedarikçi Ekle',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}