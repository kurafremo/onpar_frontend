// lib/features/spare_parts/views/audit_logs_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Personel İşlem Kayıtları', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('Henüz hiçbir işlem kaydı yok.', style: TextStyle(color: Colors.grey)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(auditLogsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(log['date']).toLocal());
                
                Color actionColor = Colors.blueGrey;
                IconData icon = Icons.info_outline;
                
                if (log['action'] == 'DELETE') { actionColor = Colors.red; icon = Icons.delete; }
                else if (log['action'] == 'SALE') { actionColor = Colors.green; icon = Icons.attach_money; }
                else if (log['action'] == 'CREATE') { actionColor = Colors.blue; icon = Icons.add_circle; }
                else if (log['action'] == 'UPDATE') { actionColor = Colors.orange; icon = Icons.edit; }

                return Card(
                  elevation: 0.5,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: actionColor.withOpacity(0.1),
                      child: Icon(icon, color: actionColor),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(log['username'] ?? 'Bilinmiyor', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(log['details'] ?? 'Detay yok', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }
}