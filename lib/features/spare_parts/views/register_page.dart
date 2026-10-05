import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:on_par/core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  // 1. MİMARİ KURAL: ENCAPSULATION (KAPSÜLLEME)
  // Değişkenler her zaman ait oldukları State sınıfının içinde (private olarak, '_' ile) tanımlanmalıdır.
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _masterKeyController = TextEditingController(); 
  bool _isLoading = false;

  Future<void> _register() async {
    FocusScope.of(context).unfocus(); // Klavyeyi kapatır

    // 2. MİMARİ KURAL: FAIL-FAST (HIZLI BAŞARISIZ OLMA)
    // Eskiden burada manuel if() kontrolleri vardı. Artık işi Form'un zekasına devrediyoruz.
    // Eğer TextFormField'lardaki validator'lardan biri bile hata verirse (false dönerse), 
    // sistem return ile fonksiyonu anında keser, sunucuya hiç gitmez.
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    setState(() => _isLoading = true);

   try {
      final masterKeyText = _masterKeyController.text.trim();

      // Standart kurumsal /api/register kaydı
      await ref.read(authStateProvider.notifier).register(
        _usernameController.text,
        _pinController.text,
        masterKey: masterKeyText.isNotEmpty ? masterKeyText : null,
      );

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(
          context,
          'Sistem hesabı başarıyla oluşturuldu! Giriş yapabilirsiniz.',
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final errorMessage = e.response?.data is Map && e.response?.data['detail'] != null
            ? e.response?.data['detail']
            : 'Kayıt sırasında bir hata oluştu (${e.response?.statusCode ?? "Ağ Hatası"})';
        AppSnackBar.showError(context, errorMessage.toString());
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, DioErrorHandler.getErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // MEMORY LEAK (Bellek Sızıntısı) ÖNLEMİ:
    // Sayfa kapatıldığında RAM'de yer kaplamamaları için controller'ları temizliyoruz.
    _usernameController.dispose();
    _pinController.dispose();
    _masterKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          // 3. MİMARİ KURAL: WIDGET TREE TRAVERSAL (AĞAÇ GEZİNİMİ)
          // Tüm input alanlarını tek bir 'Form' çatısı altında topluyoruz.
          child: Form(
            key: _formKey, // Anahtarımızı taktık
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_alt_1, size: 80, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'YENİ HESAP',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Oluşturulan tüm hesaplar standart "Çalışan" yetkisiyle açılır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 48),

                // KULLANICI ADI ALANI
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı Adı (Örn: Ahmet Usta)',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.badge, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.blueGrey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kullanıcı adı boş bırakılamaz!';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ŞİFRE (PIN) ALANI
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Şifre',
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      letterSpacing: 2,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.blueGrey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  // SENIOR ALGORİTMASI: REGEX İLE GÜVENLİK
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen bir şifre girin.';
                    }
                    // Pattern: En az 1 harf, en az 1 rakam, minimum 6 karakter
                    final regex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).{6,}$');
                    if (!regex.hasMatch(value)) {
                      return 'En az 6 hane olmalı, harf ve rakam içermelidir!';
                    }
                    return null; 
                  },
                ),
                const SizedBox(height: 16),

                // GİZLİ PATRON ŞİFRESİ ALANI
                TextFormField(
                  controller: _masterKeyController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Patron Şifresi (Sadece Yöneticiler)',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.key, color: Colors.white24),
                    filled: true,
                    fillColor: Colors.blueGrey[900], 
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // KAYIT BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'KAYDI TAMAMLA',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}