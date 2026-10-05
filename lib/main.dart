import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // YENİ: Uygulamadan çıkış için eklendi
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/spare_parts/views/home_page.dart';
import 'features/spare_parts/views/part_list_page.dart';
import 'features/spare_parts/views/new_sale_page.dart';
import 'features/spare_parts/views/login_page.dart';
import 'features/spare_parts/providers/auth_provider.dart';
import 'core/services/hardware_barcode_service.dart';
import 'core/network/dio_client.dart';
import 'core/widgets/offline_status_banner.dart';
import 'core/widgets/pos_inactivity_lock.dart';
import 'core/offline/offline_sync_manager.dart';
import 'core/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // YENİ: Uygulama açılmadan hemen önce .env kasasını belleğe yüklüyoruz.
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('tr_TR', null);
  
  // Uygulama başlarken bekleyen çevrimdışı satışlar varsa arka planda senkronizasyonu dene
  OfflineSyncManager().syncPendingSales();

  runApp(const ProviderScope(child: OnParApp()));
}

class OnParApp extends ConsumerWidget {
  const OnParApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 401 oturum aşımı durumunda Riverpod authState'ini otomatik sıfırla
    DioClient.onSessionExpired = () {
      ref.read(authStateProvider.notifier).logout();
    };

    final authState = ref.watch(authStateProvider);

   return MaterialApp(
      title: 'On-Par ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ANA RENK PALETİNİ BURAYA VERİYORUZ
        primaryColor: AppColors.corporateNavy,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        
        // TÜM SAYFALARIN APPBAR (Üst Menü) TASARIMINI TEK SEFERDE YAPIYORUZ
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.corporateNavy,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.corporateNavy),
          titleTextStyle: TextStyle(color: AppColors.corporateNavy, fontSize: 18, fontWeight: FontWeight.bold),
        ),

        // BUTON VE KART TASARIMLARI
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.energeticOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      builder: (context, child) {
        // 1. Kasa Güvenliği: 10 dakika hareketsizlikte otomatik kilit
        // 2. Fiziksel Barkod Dinleyici: Ekranda TextField odaklı olmasa bile okunan donanım barkodlarını yakalar
        // 3. Çevrimdışı Durum Çubuğu: Ağ koptuğunda ve kuyrukta veri olduğunda en üstte kurumsal bildirim çubuğu gösterir
        return PosInactivityLockWrapper(
          child: GlobalBarcodeListenerWidget(
            child: OfflineStatusBanner(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: authState != null
          ? const MainNavigationScreen()
          : const LoginPage(),
    );
  }
}

// --- SENİOR DOKUNUŞU: NESTED (İÇ İÇE) NAVİGASYON VE KALICI ALT MENÜ ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Her sekme için ayrı bir Navigator Anahtarı (Key) oluşturuyoruz
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Her sekmede ilk açılacak sayfalar
  final List<Widget> _pages = [
    const HomePage(),
    const PartsListPage(),
    const NewSalePage(),
  ];

  // Alt menüdeki sekmeler arası geçiş
  void _selectTab(int index) {
    if (_currentIndex == index) {
      // Eğer kullanıcı zaten bulunduğu sekmeye tekrar tıklarsa, o sekmeyi en başa (root) döndür
      _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  // Her sekmenin kendi içindeki navigasyon motorunu kuruyoruz
  Widget _buildTabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => _pages[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Android geri tuşunu manuel yöneteceğimiz için varsayılanı kapatıyoruz
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Mevcut sekmedeki iç navigatörde geri gidilebilecek bir sayfa var mı bak
        final isFirstRouteInCurrentTab = !await _navigatorKeys[_currentIndex]
            .currentState!
            .maybePop();

        // Eğer sekmenin en başındaysak (geri gidilecek alt sayfa yoksa)
        if (isFirstRouteInCurrentTab) {
          if (_currentIndex != 0) {
            // Ana sayfada değilsek ana sayfaya dön
            _selectTab(0);
          } else {
            // Ana sayfadaysak uygulamayı kapat
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0), // 1. Sekme (Ana Sayfa İç Mimarisi)
            _buildTabNavigator(1), // 2. Sekme (Katalog İç Mimarisi)
            _buildTabNavigator(2), // 3. Sekme (Sepet İç Mimarisi)
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: AppColors.corporateNavy,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          onTap: _selectTab,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2),
              label: 'Katalog',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Sepet / Satış',
            ),
          ],
        ),
      ),
    );
  }
}
