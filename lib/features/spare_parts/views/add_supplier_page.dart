import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';

/// Kurumsal B2B Tedarikçi Ekleme Sayfası - Executive Slate Teması
class AddSupplierPage extends ConsumerStatefulWidget {
  const AddSupplierPage({super.key});

  @override
  ConsumerState<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends ConsumerState<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newSupplier = Supplier(
        name: _nameController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isNotEmpty
            ? _contactPersonController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        taxNumber: _taxNumberController.text.trim().isNotEmpty
            ? _taxNumberController.text.trim()
            : null,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      await ref.read(supplierProvider.notifier).addSupplier(newSupplier);

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Tedarikçi başarıyla kaydedildi!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Tedarikçi eklenemedi: ${DioErrorHandler.getErrorMessage(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Yeni Tedarikçi Ekle',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // B2B Kurumsal Başlık Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.corporateNavy,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.corporateNavy.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.energeticOrange.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: AppColors.energeticOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'B2B Tedarikçi Kartı',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Toptancı ve yedek parça üretici firma kaydı',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Şirket Unvanı
              _buildTextCard(
                controller: _nameController,
                label: 'Firma / Şirket Unvanı *',
                hint: 'Örn: Toros Toptan Otomotiv A.Ş.',
                icon: Icons.business_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Firma unvanı zorunludur.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Yetkili Kişi
              _buildTextCard(
                controller: _contactPersonController,
                label: 'Yetkili Kişi',
                hint: 'Örn: Yusuf Yılmaz',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),

              // Telefon Numarası
              _buildTextCard(
                controller: _phoneController,
                label: 'Telefon Numarası',
                hint: 'Örn: 0532 111 22 33',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // Vergi Numarası
              _buildTextCard(
                controller: _taxNumberController,
                label: 'Vergi Numarası / VKN',
                hint: '10 haneli VKN veya 11 haneli TCKN',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Adres
              _buildTextCard(
                controller: _addressController,
                label: 'Firma Adresi',
                hint: 'İl, ilçe, cadde ve sokak detayları...',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Özel Notlar
              _buildTextCard(
                controller: _notesController,
                label: 'Tedarikçi Notları / Parça Grupları',
                hint: 'Örn: Sadece VAG grubu filtre ve balata temin edilir.',
                icon: Icons.note_alt_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 28),

              // Kaydet Butonu
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isLoading ? 'Kaydediliyor...' : 'Tedarikçiyi Sisteme Kaydet',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.corporateNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
  }

  Widget _buildTextCard({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.corporateNavy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          icon: Icon(icon, color: AppColors.corporateNavy, size: 22),
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textDark, fontSize: 14),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
