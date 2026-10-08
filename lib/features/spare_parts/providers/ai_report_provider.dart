import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_error_handler.dart';
import 'spare_part_provider.dart';
import 'supplier_provider.dart';

/// Yapay Zeka Dükkan ve Finans Raporu Sağlayıcısı
class AiReportNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return null;
  }

  Future<void> generateShopReport() async {
    state = const AsyncValue.loading();

    try {
      final repository = ref.read(sparePartRepositoryProvider);

      List<dynamic> parts = [];
      try {
        parts = await repository.getSpareParts(query: '');
      } catch (_) {}

      List<dynamic> sales = [];
      try {
        sales = await repository.getSalesHistory();
      } catch (_) {}

      List<dynamic> suppliers = [];
      try {
        suppliers = await ref.read(supplierProvider.future);
      } catch (_) {}

      final partsInfo = parts.take(60).map((p) => "- ${p.name} (Stok: ${p.stockQuantity}, Alış: ${p.buyPrice}₺, Satış: ${p.sellPrice}₺)").join('\n');
      final salesInfo = sales.take(50).map((s) => "- ${s.quantity} adet ${s.partName} satıldı.").join('\n');
      final suppliersInfo = suppliers.take(30).map((s) => "- ${s.name}").join('\n');

      final prompt = """
Sen On-Par Otomotiv B2B ERP sisteminin Baş Finans ve İşletme Analistisin.
Aşağıda dükkanımızın anlık verileri bulunmaktadır.

MEVCUT PARÇALAR (İlk 60):
${partsInfo.trim().isEmpty ? "Veritabanında hiç yedek parça bulunmamaktadır." : partsInfo}

SON SATIŞLAR (İlk 50):
${salesInfo.trim().isEmpty ? "Henüz hiç satış yapılmamıştır." : salesInfo}

TEDARİKÇİLER:
${suppliersInfo.trim().isEmpty ? "Kayıtlı tedarikçi bulunmamaktadır." : suppliersInfo}

ÖNEMLİ KURAL (SİSTEM MİMARİSİ): 
Eğer yukarıdaki veriler (parçalar ve satışlar) boşsa, KESİNLİKLE hayal gücünü kullanarak sahte veya uydurma analiz yapma. Raporu yazmayı reddet ve sadece şu mesajı ver: 
"Şu an sistemde analiz edilebilecek kayıtlı ürün veya satış bulunmamaktadır. Rapor oluşturabilmem için lütfen sisteme barkod ile parça ekleyin ve satış işlemi gerçekleştirin."

Eğer veriler BOŞ DEĞİLSE, lütfen şu başlıklar altında kurumsal, net ve aksiyon odaklı bir işletme raporu hazırla:
1. Genel Durum ve Stok Sağlığı
2. Kritik/Tükenmek Üzere Olan Ürünler & Sipariş Tavsiyesi
3. Satış Trendleri ve En Çok Kazandıran Parçalar
4. Tedarikçi İlişkileri & Fiyat/Maliyet İpuçları
5. Gelecek Hafta İçin 3 Kritik Eylem Önerisi

MEVCUT PARÇALAR (İlk 60):
$partsInfo

SON SATIŞLAR (İlk 50):
$salesInfo

TEDARİKÇİLER:
$suppliersInfo
""";

      // [KURAL: Yapay Zeka İçin Özel Timeout (120 Saniye)]
      final aiOptions = Options(
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
      );

      Response response;
      try {
        response = await dioClient.post(
          '/api/ai/generate-report',
          data: {'prompt': prompt},
          options: aiOptions,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 307) {
          response = await dioClient.post(
            '/ai/generate-report',
            data: {'prompt': prompt},
            options: aiOptions,
          );
        } else {
          rethrow;
        }
      }

      final data = response.data;
      final report = data is Map
          ? (data['report'] ?? data['data'] ?? data['result'] ?? data['content'] ?? data.toString())
          : data.toString();
      state = AsyncValue.data(report.toString());
    } on DioException catch (e) {
      final errMsg = DioErrorHandler.getErrorMessage(e);
      state = AsyncValue.error(errMsg, StackTrace.current);
    } catch (error, stackTrace) {
      state = AsyncValue.error(DioErrorHandler.getErrorMessage(error), stackTrace);
    }
  }
}

final aiReportProvider = AsyncNotifierProvider<AiReportNotifier, String?>(
  AiReportNotifier.new,
);