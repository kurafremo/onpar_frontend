// lib/features/spare_parts/views/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/spare_part_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/services/notification_service.dart';
import 'audit_logs_page.dart';

/// Kurumsal B2B ERP Ayarlar, Profil ve Veritabanı Yönetim Sayfası
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _criticalStockNotification = true;
  bool _highValueSaleNotification = true;
  bool _isCleaningDuplicates = false;
  bool _isFixingBrands = false;

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Oturumu Kapat'),
          ],
        ),
        content: const Text(
          'ERP oturumunuz kapatılacaktır. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _promptCleanupDuplicates() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text('Mükerrer Ürünleri Temizle'),
            ),
          ],
        ),
        content: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Excel aktarımı veya çift giriş nedeniyle mükerrer oluşan ürünlerin stokları ana kayıtta birleştirilecek ve fazlalıklar güvenle temizlenecektir.\n\nBu işlemi başlatmak istiyor musunuz?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isCleaningDuplicates = true);
              try {
                final result = await ref.read(sparePartsProvider.notifier).cleanupDuplicates();
                if (mounted) {
                  final msg = result['message'] ?? 'Mükerrer ürünler temizlendi!';
                  AppSnackBar.showSuccess(context, msg.toString());
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(context, 'Temizleme işlemi başarısız: $e');
                }
              } finally {
                if (mounted) setState(() => _isCleaningDuplicates = false);
              }
            },
            child: const Text('Temizle ve Birleştir'),
          ),
        ],
      ),
    );
  }

  void _promptFixUnassignedBrands() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Expanded(
              child: Text('Markaları Otomatik Onar'),
            ),
          ],
        ),
        content: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Markası boş veya belirtilmemiş olan parçaların isimleri taranarak (Renault, Fiat, Bosch, Valeo vb.) üretici markaları veritabanında otomatik atanacaktır.\n\nİşlemi onaylıyor musunuz?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isFixingBrands = true);
              try {
                final result = await ref.read(sparePartsProvider.notifier).fixUnassignedBrands();
                if (mounted) {
                  final msg = result['message'] ?? 'Kayıp markalar başarıyla onarıldı!';
                  AppSnackBar.showSuccess(context, msg.toString());
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(context, 'Onarma işlemi başarısız: $e');
                }
              } finally {
                if (mounted) setState(() => _isFixingBrands = false);
              }
            },
            child: const Text('Markaları Onar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final role = user?.role.toLowerCase() ?? '';
    final isAdmin = role == 'admin' || role == 'patron';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Sistem & ERP Ayarları',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. KULLANICI PROFİL VE B2B ROL KARTI
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey[900]!, Colors.blueGrey[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueGrey.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.badge_outlined,
                    size: 34,
                    color: isAdmin ? Colors.amber[400] : Colors.lightBlueAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? 'Giriş Yapılmadı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Colors.amber.withValues(alpha: 0.25)
                              : Colors.teal.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAdmin ? Colors.amber : Colors.tealAccent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isAdmin ? 'YÖNETİCİ (PATRON)' : 'PERSONEL (ÇALIŞAN)',
                          style: TextStyle(
                            color: isAdmin ? Colors.amber[300] : Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // YENİ EKLENEN KISIM: PERSONEL İŞLEM KAYITLARI (SADECE PATRON)
          if (isAdmin) ...[
            _buildSectionHeader('Yönetim ve Güvenlik Araçları'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.admin_panel_settings, color: Colors.indigo[600]),
                ),
                title: const Text('Personel İşlem Kayıtları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Kim ne sattı, ne ekledi, ne sildi? (Sistem Logları)', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AuditLogsPage()));
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 2. VERİTABANI VE BAKIM İŞLEMLERİ (SADECE PATRON)
          if (isAdmin) ...[
            _buildSectionHeader('Veritabanı ve Bakım İşlemleri'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                    ),
                    title: const Text(
                      'Mükerrer Kayıtları Temizle',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Çiftleyen barkod kayıtlarının stoklarını birleştirip temizler',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: _isCleaningDuplicates
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _promptCleanupDuplicates,
                            child: const Text('Temizle'),
                          ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_fix_high_rounded, color: Colors.indigo),
                    ),
                    title: const Text(
                      'Kayıp Markaları Otomatik Onar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Markası boş olan parçaların üreticilerini isminden otomatik atar',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: _isFixingBrands
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _promptFixUnassignedBrands,
                            child: const Text('Onar'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. B2B ANLIK BİLDİRİM TERCİHLERİ (FCM)
          _buildSectionHeader('B2B Bildirim Ayarları (FCM)'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: const Text('Kritik Stok Uyarıları'),
                  subtitle: const Text('Stoku kritik eşiğe veya sıfıra düşen parçalar için bildirim al'),
                  value: _criticalStockNotification,
                  activeTrackColor: Colors.blueGrey[900],
                  onChanged: (val) {
                    setState(() => _criticalStockNotification = val);
                    NotificationService().registerDeviceToken();
                    AppSnackBar.showSuccess(
                      context,
                      val ? 'Kritik stok bildirimleri açıldı.' : 'Kritik stok bildirimleri kapatıldı.',
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.monetization_on_outlined, color: Colors.green),
                  title: const Text('Yüksek Montanlı Satış Bildirimi'),
                  subtitle: const Text('10.000 ₺ üzeri toptan satışlarda yönetici uyarısı fırlat'),
                  value: _highValueSaleNotification,
                  activeTrackColor: Colors.blueGrey[900],
                  onChanged: (val) {
                    setState(() => _highValueSaleNotification = val);
                    NotificationService().registerDeviceToken();
                    AppSnackBar.showSuccess(
                      context,
                      val ? 'Yüksek montanlı satış bildirimleri açıldı.' : 'Bildirimler kapatıldı.',
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: Colors.blueGrey),
                  title: const Text('Cihaz Bildirimlerini Yeniden Bağla'),
                  subtitle: const Text('Bu cihazın token\'ını backend\'e senkronize et'),
                  trailing: TextButton(
                    onPressed: () async {
                      final success = await NotificationService().registerDeviceToken();
                      if (context.mounted) {
                        if (success) {
                          AppSnackBar.showSuccess(context, 'Cihaz bildirimi backend ile senkronize edildi.');
                        } else {
                          AppSnackBar.showWarning(context, 'Bildirim bağlantısı yenilendi.');
                        }
                      }
                    },
                    child: const Text('Senkronize Et'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. SİSTEM & AĞ BİLGİSİ (Teknik / IP bilgileri gizlendi, profesyonelleştirildi)
          _buildSectionHeader('Sistem ve Altyapı Bilgisi'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_outlined, color: Colors.blueGrey),
                  title: const Text('Çevrimdışı Kuyruğu Senkronize Et'),
                  subtitle: const Text('Bekleyen yerel satışları sunucuya gönder'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.blueGrey),
                    onPressed: () async {
                      await OfflineSyncManager().syncPendingSales();
                      if (context.mounted) {
                        AppSnackBar.showSuccess(context, 'Senkronizasyon kontrol edildi.');
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blueGrey),
                  title: Text('ERP Yazılım Sürümü'),
                  subtitle: Text('On-Par Enterprise v4.0.0 (B2B Local Server)'),
                  trailing: Icon(Icons.verified, color: Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. OTURUMU KAPAT BUTONU
          ElevatedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'Oturumu Güvenli Kapat',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}