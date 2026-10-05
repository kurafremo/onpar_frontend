import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ağ durumunu (Online / Offline) anlık olarak dinleyen Riverpod Sağlayıcısı
final networkConnectivityStreamProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    // Listede wifi, mobile veya ethernet varsa cihaz bağlı kabul edilir
    final isOnline = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);
    return isOnline;
  });
});

/// UI tarafında ref.watch(isOnlineProvider) ile kolayca boolean erişim
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(networkConnectivityStreamProvider);
  return connectivityAsync.value ?? true; // Varsayılan olarak online kabul et
});
