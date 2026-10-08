// lib/features/spare_parts/views/audit_logs_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';

final auditLogsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await dioClient.get('/api/audit-logs');
  return response.data as List<dynamic>;
});

class AuditLogsPage extends ConsumerWidget {
  const AuditLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Personel İşlem Kayıtları',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'Henüz hiçbir işlem kaydı yok.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.corporateNavy,
            onRefresh: () async => ref.refresh(auditLogsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final dateStr = DateFormat('dd.MM.yyyy HH:mm')
                    .format(DateTime.parse(log['date']).toLocal());

                Color actionColor = Colors.blueGrey;
                IconData icon = Icons.info_outline;

                if (log['action'] == 'DELETE') {
                  actionColor = AppColors.dangerRed;
                  icon = Icons.delete_outline_rounded;
                } else if (log['action'] == 'SALE') {
                  actionColor = AppColors.successGreen;
                  icon = Icons.attach_money_rounded;
                } else if (log['action'] == 'CREATE') {
                  actionColor = const Color(0xFF2563EB);
                  icon = Icons.add_circle_outline_rounded;
                } else if (log['action'] == 'UPDATE') {
                  actionColor = const Color(0xFF2563EB);
                  icon = Icons.edit_note_rounded;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.corporateNavy.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.corporateNavy.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: Container(color: actionColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: actionColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        log['username'] ?? 'Bilinmiyor',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.corporateNavy,
                                        ),
                                      ),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    log['details'] ?? 'Detay yok',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textDark,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.corporateNavy),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Hata: $err',
              style: const TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ),
      ),
    );
  }
}