import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/network_status_provider.dart';
import '../offline/offline_sync_manager.dart';

/// Ekranın üstünde bağlantı koptuğunda beliren kurumsal çevrimdışı banner'ı
class OfflineStatusBanner extends ConsumerWidget {
  final Widget child;
  const OfflineStatusBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final queueCount = ref.watch(offlineQueueCountProvider);

    // Ağ geri geldiğinde bekleyen satış varsa otomatik senkronizasyonu tetikle
    ref.listen<bool>(isOnlineProvider, (previous, current) {
      if (previous == false && current == true) {
        ref.read(offlineSyncManagerProvider).syncPendingSales().then((_) {
          ref.read(offlineQueueCountProvider.notifier).refresh();
        });
      }
    });

    return Column(
      children: [
        if (!isOnline)
          Material(
            color: const Color(0xFF37474F), // Slate Grey
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        queueCount > 0
                            ? 'Çevrimdışı Mod: $queueCount adet satış kuyrukta bekliyor.'
                            : 'Çevrimdışı Mod: İnternet bağlantısı yok.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (queueCount > 0)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: Colors.amberAccent,
                        ),
                        onPressed: () {
                          ref.read(offlineSyncManagerProvider).syncPendingSales().then((_) {
                            ref.read(offlineQueueCountProvider.notifier).refresh();
                          });
                        },
                        child: const Text('Şimdi Dene', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
