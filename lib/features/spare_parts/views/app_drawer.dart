// lib/features/spare_parts/views/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/spare_part_provider.dart';

import 'suppliers_page.dart';
import 'add_supplier_page.dart';
import 'ai_report_page.dart';
import 'sales_ledger_page.dart';
import 'part_list_page.dart';
import 'settings_page.dart';
import 'customers_page.dart'; 

import '../../../core/constants/app_colors.dart';

/// Kurumsal B2B Standartlarında Yan Menü (Drawer) - Executive Slate Teması
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
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
          'On-Par ERP oturumunuz kapatılacaktır. Onaylıyor musunuz?',
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
              Navigator.pop(context); 
              ref.read(authStateProvider.notifier).logout();
              ref.invalidate(monthlySalesProvider);
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userRoleProvider);
    final user = ref.watch(authStateProvider);
    final role = userAsync.value ?? '';
    final isAdmin = role == 'admin' || role == 'patron';

    return Drawer(
      backgroundColor: AppColors.backgroundLight,
      child: Column(
        children: [
          // 1. YENİ PROFESYONEL DRAWER HEADER (Lacivert ve Turuncu Vurgulu)
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 24, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: AppColors.corporateNavy,
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(32)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.energeticOrange.withOpacity(0.15),
                  child: const Icon(Icons.person, color: AppColors.energeticOrange, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? 'Misafir',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.amber.withOpacity(0.2) : Colors.teal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isAdmin ? Colors.amber.withOpacity(0.5) : Colors.tealAccent.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isAdmin ? 'YÖNETİCİ (PATRON)' : 'PERSONEL (ÇALIŞAN)',
                          style: TextStyle(
                            color: isAdmin ? Colors.amber[300] : Colors.tealAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
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
          const SizedBox(height: 12),

          // 2. MENÜ LİSTESİ (Sade, Net ve Kurumsal İkonlar)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(context, 'Yedek Parçalar (Katalog)', Icons.inventory_2_outlined, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PartsListPage()));
                }),
                _buildMenuItem(context, 'Satış Defteri / POS', Icons.receipt_long_outlined, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesLedgerPage()));
                }),
                _buildMenuItem(context, 'Müşterilerim (Veresiye)', Icons.people_alt_outlined, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomersPage()));
                }),
                _buildMenuItem(context, 'Tedarikçilerim', Icons.local_shipping_outlined, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SuppliersPage()));
                }),
                _buildMenuItem(context, 'Yeni Tedarikçi Ekle', Icons.add_business_outlined, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSupplierPage()));
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 24, thickness: 1, color: Colors.black12),
                ),
                _buildMenuItem(context, 'Yapay Zeka Raporları', Icons.auto_awesome_outlined, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AiReportPage()));
                }, iconColor: AppColors.energeticOrange),
                _buildMenuItem(context, 'Sistem Ayarları', Icons.settings_outlined, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                }),
              ],
            ),
          ),

          // 3. ALT BÖLÜM (Çıkış Butonu ve Versiyon Bilgisi)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dangerRed.withOpacity(0.1),
                    foregroundColor: AppColors.dangerRed,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.dangerRed.withOpacity(0.3)),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Oturumu Kapat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () => _showLogoutDialog(context, ref),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('v4.0.0 (Enterprise)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(
                      'On-Par ERP',
                      style: TextStyle(
                        color: AppColors.corporateNavy.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Yardımcı Menü Elemanı (Tile) Oluşturucu
  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback onTap, {Color? iconColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: iconColor ?? AppColors.corporateNavy, size: 26),
      title: Text(
        title, 
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}