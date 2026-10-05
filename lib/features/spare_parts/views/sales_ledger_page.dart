import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sale_record_model.dart';
import '../providers/spare_part_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/state_feedback_widget.dart';
import '../../../core/network/dio_error_handler.dart';

// --- GÜNLÜK FİLTRELEME ---
class LedgerDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void setDate(DateTime date) => state = date;
}

final ledgerDateProvider = NotifierProvider<LedgerDateNotifier, DateTime>(() {
  return LedgerDateNotifier();
});

final dailyLedgerSalesProvider = FutureProvider.autoDispose<List<SaleRecord>>((
  ref,
) async {
  final selectedDate = ref.watch(ledgerDateProvider);
  final repository = ref.read(sparePartRepositoryProvider);
  final allSales = await repository.getSalesHistory();

  final startOfDay = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final filteredSales = allSales.where((sale) {
    if (sale.createdAt == null) return false;
    final localDate = sale.createdAt!.toLocal();
    return localDate.isAfter(
          startOfDay.subtract(const Duration(milliseconds: 1)),
        ) &&
        localDate.isBefore(endOfDay);
  }).toList();

  filteredSales.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  return filteredSales;
});

class SalesLedgerPage extends ConsumerStatefulWidget {
  const SalesLedgerPage({super.key});

  @override
  ConsumerState<SalesLedgerPage> createState() => _SalesLedgerPageState();
}

class _SalesLedgerPageState extends ConsumerState<SalesLedgerPage> {
  bool _isGeneratingPdf = false;
  final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  // --- SENİOR DOKUNUŞU: Çökmeye Karşı %100 ZIRHLI Takvim Mimarisi ---
  void _selectDateCupertino(BuildContext context, WidgetRef ref, bool isAdmin) {
    // 1. ÇALIŞAN KONTROLÜ: Çalışan geçmişi göremez, tıklarsa şık bir uyarı verip kesiyoruz.
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Çalışan yetkisiyle sadece bugünün kayıtlarını görüntüleyebilirsiniz.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 2. PATRON KONTROLÜ: Saatleri ve milisaniyeleri temizle
    final currentDate = ref.read(ledgerDateProvider);
    final now = DateTime.now();

    final cleanCurrent = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final cleanMax = DateTime(now.year, now.month, now.day);
    final cleanMin = DateTime(2020, 1, 1);

    // MUTLAK ÇÖZÜM: Çark dönerken bu yerel değişken güncellenecek, Riverpod tetiklenmeyecek!
    DateTime selectedTmpDate = cleanCurrent.isAfter(cleanMax)
        ? cleanMax
        : cleanCurrent;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext modalContext) => Container(
        height: 300,
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                  CupertinoButton(
                    child: const Text(
                      'Tamam',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      // KULLANICI ONAYLADI: Riverpod'u şimdi tek bir seferde güncelliyoruz!
                      ref
                          .read(ledgerDateProvider.notifier)
                          .setDate(selectedTmpDate);
                      Navigator.pop(modalContext); // Güvenli şekilde kapat
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selectedTmpDate,
                  minimumDate: cleanMin,
                  maximumDate: cleanMax,
                  onDateTimeChanged: (DateTime newDate) {
                    // Çark dönerken SADECE yerel değişkeni değiştir, arkadaki ekranı rebuild etme!
                    selectedTmpDate = newDate;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteSaleRecord(SaleRecord sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Satışı İptal Et',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'DİKKAT: "${sale.partName}" adlı satışı iptal ederseniz, satılan ${sale.quantity} adet ürün STOĞA GERİ EKLENECEKTİR.\n\nEmin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(sparePartsProvider.notifier).deleteSale(sale);
                if (mounted) {
                  ref.invalidate(dailyLedgerSalesProvider);
                  AppSnackBar.showSuccess(
                    context,
                    'Satış iptal edildi ve stok iade edildi.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(
                    context,
                    'Satış iptal edilemedi: ${DioErrorHandler.getErrorMessage(e)}',
                  );
                }
              }
            },
            child: const Text(
              'Evet, Sil',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- YERİNDE DÜZENLEME MODALI (IN-PLACE EDIT) ---
  void _showEditSaleModal(SaleRecord sale) {
    final qtyCtrl = TextEditingController(text: sale.quantity.toString());
    final priceCtrl = TextEditingController(text: sale.unitPrice.toString());
    final buyerCtrl = TextEditingController(text: sale.buyerName);
    final plateCtrl = TextEditingController(text: sale.vehiclePlate);
    final notesCtrl = TextEditingController(text: sale.notes);
    
    // PROFESYONEL ÇÖZÜM: Mevcut ödeme türünü yakala, listede yoksa varsayılan 'Nakit' yap
    String selectedPaymentMethod = ['Nakit', 'Kredi Kartı', 'Havale'].contains(sale.paymentMethod) 
        ? sale.paymentMethod 
        : 'Nakit';

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Satışı Düzenle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.corporateNavy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    sale.partName ?? 'Ürün',
                    style: const TextStyle(
                      color: AppColors.corporateNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          qtyCtrl,
                          'Adet',
                          Icons.numbers,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          priceCtrl,
                          'Birim Fiyat',
                          Icons.attach_money,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          buyerCtrl,
                          'Müşteri',
                          Icons.person,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          plateCtrl,
                          'Plaka',
                          Icons.pin_drop,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(notesCtrl, 'Notlar', Icons.note_alt),
                  const SizedBox(height: 12),
                  
                  // YENİ EKLENEN KISIM: Ödeme Yöntemi Dropdown'u
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    decoration: InputDecoration(
                      labelText: 'Ödeme Yöntemi',
                      labelStyle: const TextStyle(color: AppColors.textDark),
                      prefixIcon: const Icon(Icons.payment, size: 20, color: AppColors.corporateNavy),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.corporateNavy),
                      ),
                      isDense: true,
                    ),
                    items: ['Nakit', 'Kredi Kartı', 'Havale'].map((String method) {
                      return DropdownMenuItem(value: method, child: Text(method));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedPaymentMethod = val);
                      }
                    },
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.corporateNavy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setState(() => isSaving = true);
                              try {
                                final newQty = int.tryParse(qtyCtrl.text) ?? sale.quantity;
                                final newPrice = double.tryParse(priceCtrl.text) ?? sale.unitPrice;

                                final updatedRecord = SaleRecord(
                                  id: sale.id,
                                  partId: sale.partId,
                                  partName: sale.partName,
                                  quantity: newQty,
                                  unitPrice: newPrice,
                                  totalPrice: newQty * newPrice,
                                  buyerName: buyerCtrl.text.trim(),
                                  companyName: sale.companyName,
                                  vehiclePlate: plateCtrl.text.trim(),
                                  vehicleBrandModel: sale.vehicleBrandModel,
                                  notes: notesCtrl.text.trim(),
                                  paymentMethod: selectedPaymentMethod, // YENİ: Seçilen ödeme yöntemini backend'e iletiyoruz
                                  createdAt: sale.createdAt,
                                );

                                await ref
                                    .read(sparePartsProvider.notifier)
                                    .updateExistingSale(
                                      sale.id!.toString(),
                                      updatedRecord,
                                    );

                                if (context.mounted) {
                                  ref.invalidate(dailyLedgerSalesProvider);
                                  Navigator.pop(context);
                                  AppSnackBar.showSuccess(
                                    context,
                                    'Satış başarıyla güncellendi!',
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppSnackBar.showError(
                                    context,
                                    'Güncelleme başarısız: ${DioErrorHandler.getErrorMessage(e)}',
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() => isSaving = false);
                                }
                              }
                            },
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'KAYDET',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textDark),
        prefixIcon: Icon(icon, size: 20, color: AppColors.corporateNavy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.corporateNavy),
        ),
        isDense: true,
      ),
    );
  }

  // --- PDF İNDİRME ---
  Future<void> _handlePdfAction(
    List<SaleRecord> sales,
    DateTime selectedDate,
    double totalRevenue, {
    required bool isShare,
  }) async {
    setState(() => _isGeneratingPdf = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isShare ? 'Paylaşım hazırlanıyor...' : 'PDF İndiriliyor...',
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final pdf = pw.Document();
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      final dateName = DateFormat('dd MMMM yyyy', 'tr_TR').format(selectedDate);

      final tableData = <List<String>>[
        [
          'Saat',
          'Ürün / Marka',
          'Adet',
          'BirimFiyat',
          'Toplam',
          'Müşteri / Plaka',
        ],
      ];

      for (var sale in sales) {
        final localDate = sale.createdAt?.toLocal();
        final timeString = localDate != null
            ? DateFormat('HH:mm').format(localDate)
            : '-';
        final product = sale.partName ?? 'Bilinmeyen Ürün';
        final customerInfo = [
          sale.buyerName ?? '',
          sale.vehiclePlate ?? '',
        ].where((e) => e.isNotEmpty).join(' - ');

        tableData.add([
          timeString,
          product,
          sale.quantity.toString(),
          currencyFormat.format(sale.unitPrice),
          currencyFormat.format(sale.totalPrice),
          customerInfo.isEmpty ? 'Peşin' : customerInfo,
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ON-PAR OTOMOTİV',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 24,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                        pw.Text(
                          'Günlük Satış Defteri Raporu',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Tarih: $dateName',
                          style: pw.TextStyle(font: fontBold, fontSize: 14),
                        ),
                        pw.Text(
                          'Toplam Ciro: ${currencyFormat.format(totalRevenue)}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2, color: PdfColors.blueGrey300),
                pw.SizedBox(height: 20),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(2.5),
                },
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final safeDateStr = DateFormat('dd_MM_yyyy').format(selectedDate);
      final fileName = 'OnPar_Satis_Defteri_$safeDateStr.pdf';

      if (isShare) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        Directory? directory;
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          directory = await getDownloadsDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(bytes);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF Başarıyla İndirildi:\n${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(dailyLedgerSalesProvider);
    final selectedDate = ref.watch(ledgerDateProvider);
    final formattedDate = DateFormat(
      'dd MMMM yyyy',
      'tr_TR',
    ).format(selectedDate);

    final roleAsync = ref.watch(userRoleProvider);
    final isAdmin = roleAsync.value == 'admin' || roleAsync.value == 'patron';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Günlük Satış Defteri',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isAdmin)
            salesAsync.maybeWhen(
              data: (sales) {
                if (sales.isEmpty) return const SizedBox();
                final total = sales.fold<double>(
                  0,
                  (sum, item) => sum + item.totalPrice,
                );
                if (_isGeneratingPdf) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.energeticOrange,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                }
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: AppColors.corporateNavy,
                      ),
                      tooltip: 'Cihaza İndir',
                      onPressed: () => _handlePdfAction(
                        sales,
                        selectedDate,
                        total,
                        isShare: false,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: AppColors.energeticOrange),
                      tooltip: 'WP / Mail ile Paylaş',
                      onPressed: () => _handlePdfAction(
                        sales,
                        selectedDate,
                        total,
                        isShare: true,
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox(),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.corporateNavy,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.corporateNavy.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _selectDateCupertino(context, ref, isAdmin),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.energeticOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (isAdmin)
                  salesAsync.when(
                    data: (sales) {
                      final totalRevenue = sales.fold<double>(
                        0,
                        (sum, item) => sum + item.totalPrice,
                      );
                      return Column(
                        children: [
                          const Text(
                            'Seçili Gün Cirosu',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(totalRevenue),
                            style: const TextStyle(
                              color: AppColors.successGreen,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      height: 50,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.successGreen,
                        ),
                      ),
                    ),
                    error: (e, s) => InkWell(
                      onTap: () => ref.refresh(dailyLedgerSalesProvider),
                      child: Text(
                        'Hesaplanamadı (Yenile)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  )
                else
                  const Column(
                    children: [
                      Text(
                        'Günün Satış Kayıtları',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Kolay Gelsin!',
                        style: TextStyle(
                          color: AppColors.successGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: salesAsync.when(
              data: (sales) {
                if (sales.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$formattedDate tarihine ait satış kaydı yok.',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    final localDate = sale.createdAt?.toLocal();
                    final timeString = localDate != null
                        ? DateFormat('HH:mm').format(localDate)
                        : "-";

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sale.partName ?? 'Bilinmeyen Parça',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.corporateNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeString,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: sale.paymentMethod == 'Nakit' 
                                                  ? AppColors.successGreen.withValues(alpha: 0.12) 
                                                  : sale.paymentMethod == 'Kredi Kartı' 
                                                      ? AppColors.corporateNavy.withValues(alpha: 0.1) 
                                                      : AppColors.energeticOrange.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  sale.paymentMethod == 'Nakit' 
                                                      ? Icons.money_rounded 
                                                      : sale.paymentMethod == 'Kredi Kartı' 
                                                          ? Icons.credit_card_rounded 
                                                          : Icons.account_balance_wallet_rounded,
                                                  size: 12,
                                                  color: sale.paymentMethod == 'Nakit' 
                                                      ? AppColors.successGreen 
                                                      : sale.paymentMethod == 'Kredi Kartı' 
                                                          ? AppColors.corporateNavy 
                                                          : AppColors.energeticOrange,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  sale.paymentMethod,
                                                  style: TextStyle(
                                                    color: sale.paymentMethod == 'Nakit' 
                                                        ? AppColors.successGreen 
                                                        : sale.paymentMethod == 'Kredi Kartı' 
                                                            ? AppColors.corporateNavy 
                                                            : AppColors.energeticOrange,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '+ ${currencyFormat.format(sale.totalPrice)}',
                                      style: const TextStyle(
                                        color: AppColors.successGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: AppColors.dangerRed,
                                          ),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                            right: 8,
                                          ),
                                          onPressed: () =>
                                              _deleteSaleRecord(sale),
                                        ),
                                        InkWell(
                                          onTap: () => _showEditSaleModal(sale),
                                          child: const Padding(
                                            padding: EdgeInsets.only(top: 8.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.edit_rounded,
                                                  size: 14,
                                                  color: AppColors.corporateNavy,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Düzenle',
                                                  style: TextStyle(
                                                    color: AppColors.corporateNavy,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.tag_rounded,
                                    '${sale.quantity} Adet (Birim: ${currencyFormat.format(sale.unitPrice)})',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.person_outline_rounded,
                                    sale.buyerName?.isNotEmpty == true
                                        ? sale.buyerName!
                                        : 'Peşin Müşteri',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.directions_car_outlined,
                                    sale.vehiclePlate?.isNotEmpty == true
                                        ? sale.vehiclePlate!
                                        : 'Plakasız',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.business_rounded,
                                    sale.companyName?.isNotEmpty == true
                                        ? sale.companyName!
                                        : 'Şahıs',
                                  ),
                                ),
                              ],
                            ),
                            if (sale.vehicleBrandModel != null &&
                                sale.vehicleBrandModel!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildDetailItem(
                                Icons.info_outline_rounded,
                                'Model: ${sale.vehicleBrandModel}',
                              ),
                            ],
                            if (sale.notes != null &&
                                sale.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.energeticOrange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.energeticOrange.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.note_alt_rounded,
                                      size: 16,
                                      color: AppColors.energeticOrange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sale.notes!,
                                        style: TextStyle(
                                          color: AppColors.energeticOrange.withValues(alpha: 0.95),
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.corporateNavy),
              ),
              error: (err, stack) => StateFeedbackWidget.error(
                error: err,
                onRetry: () => ref.refresh(dailyLedgerSalesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey[400]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
