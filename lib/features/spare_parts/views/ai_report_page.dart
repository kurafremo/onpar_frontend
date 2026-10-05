import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart'; // YENİ: Klasör yolları için eklendi
import '../providers/ai_report_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/state_feedback_widget.dart';

class AiReportPage extends ConsumerStatefulWidget {
  const AiReportPage({super.key});

  @override
  ConsumerState<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends ConsumerState<AiReportPage> {
  bool _isGeneratingPdf = false;

  // --- DİREKT WHATSAPP ENTEGRASYONU ---
  Future<void> _shareViaWhatsApp(String reportText) async {
    final String welcomeMessage =
        "*ON-PAR YAPAY ZEKA RAPORU*\n\n$reportText\n\n_Bu rapor On-Par ERP Sistemi tarafından otomatik oluşturulmuştur._";
    final Uri whatsappUri = Uri.parse(
      "whatsapp://send?text=${Uri.encodeComponent(welcomeMessage)}",
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'WhatsApp cihazınızda yüklü değil veya erişilemiyor!',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("WhatsApp açılırken hata: $e");
    }
  }

  // --- AKILLI PDF DİZGİ VE DİREKT İNDİRME MOTORU ---
  Future<void> _handlePdfAction(
    String reportText, {
    required bool isShare,
  }) async {
    setState(() => _isGeneratingPdf = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isShare ? 'Paylaşım penceresi hazırlanıyor...' : 'PDF İndiriliyor...',
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final pdf = pw.Document();
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final List<pw.Widget> pdfContent = [];
      final lines = reportText.split('\n');
      List<List<String>> currentTable = [];

      void flushTable() {
        if (currentTable.isNotEmpty) {
          pdfContent.add(
            pw.TableHelper.fromTextArray(
              context: null,
              data: currentTable,
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
          );
          pdfContent.add(pw.SizedBox(height: 12));
          currentTable.clear();
        }
      }

      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          pdfContent.add(pw.SizedBox(height: 6));
          continue;
        }

        if (trimmed.startsWith('|')) {
          final cells = trimmed.split('|').map((e) => e.trim()).toList();
          if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
          if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();

          if (!cells.every((c) => c.replaceAll('-', '').isEmpty)) {
            currentTable.add(cells);
          }
        } else {
          flushTable();
          final cleanLine = trimmed.replaceAll('**', '');

          if (cleanLine.startsWith('# ')) {
            pdfContent.add(
              pw.Text(
                cleanLine.substring(2),
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: PdfColors.blueGrey900,
                ),
              ),
            );
            pdfContent.add(pw.SizedBox(height: 8));
          } else if (cleanLine.startsWith('## ')) {
            pdfContent.add(
              pw.Text(
                cleanLine.substring(3),
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.blueGrey800,
                ),
              ),
            );
            pdfContent.add(pw.SizedBox(height: 6));
          } else if (cleanLine.startsWith('### ')) {
            pdfContent.add(
              pw.Text(
                cleanLine.substring(4),
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  color: PdfColors.blueGrey700,
                ),
              ),
            );
            pdfContent.add(pw.SizedBox(height: 4));
          } else if (cleanLine.startsWith('- ') || cleanLine.startsWith('* ')) {
            pdfContent.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 6, top: 1),
                    child: pw.Text(
                      '•',
                      style: pw.TextStyle(font: fontBold, fontSize: 12),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      cleanLine.substring(2),
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 11,
                        lineSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            final numberedMatch = RegExp(
              r'^(\d+)\.\s(.*)',
            ).firstMatch(cleanLine);
            if (numberedMatch != null) {
              pdfContent.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 6),
                      child: pw.Text(
                        '${numberedMatch.group(1)}.',
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        numberedMatch.group(2)!,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 11,
                          lineSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              pdfContent.add(
                pw.Text(
                  cleanLine,
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 11,
                    lineSpacing: 1.5,
                  ),
                  textAlign: pw.TextAlign.justify,
                ),
              );
            }
          }
          pdfContent.add(pw.SizedBox(height: 4));
        }
      }
      flushTable();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (pw.Context context) {
            return pw.Column(
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
                          'Yapay Zeka Strateji ve Analiz Raporu',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Tarih: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2, color: PdfColors.blueGrey300),
                pw.SizedBox(height: 20),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'On-Par Otomotiv ERP Sistemi - AI Raporu',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          build: (pw.Context context) => pdfContent,
        ),
      );

      final bytes = await pdf.save();
      const fileName = 'On-Par_Yapay_Zeka_Raporu.pdf';

      if (isShare) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        // --- SENİOR DOKUNUŞU: DİREKT KLASÖRE KAYDETME ---
        Directory? directory;
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          directory =
              await getDownloadsDirectory(); // Windows'ta İndirilenler klasörü
        } else {
          directory =
              await getApplicationDocumentsDirectory(); // Mobil cihazlar için
        }

        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF Başarıyla İndirildi:\n${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiReportAsync = ref.watch(aiReportProvider);

   return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text(
            'Yapay Zeka Analizi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: AppColors.corporateNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            aiReportAsync.maybeWhen(
              data: (text) => text != null
                  ? Row(
                      children: [
                        // PDF İNDİR BUTONU
                        IconButton(
                          icon: _isGeneratingPdf
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                ),
                          tooltip: 'Cihaza İndir',
                          onPressed: _isGeneratingPdf
                              ? null
                              : () => _handlePdfAction(text, isShare: false),
                        ),
                        // PAYLAŞ BUTONU
                        IconButton(
                          icon: const Icon(
                            Icons.share_rounded,
                            color: AppColors.energeticOrange,
                          ),
                          tooltip: 'Dosyayı Paylaş',
                          onPressed: _isGeneratingPdf
                              ? null
                              : () => _handlePdfAction(text, isShare: true),
                        ),
                      ],
                    )
                  : const SizedBox(),
              orElse: () => const SizedBox(),
            ),
          ],
        ),
        body: aiReportAsync.when(
          data: (reportText) {
            if (reportText == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.corporateNavy.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 64,
                          color: AppColors.corporateNavy,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Dükkanının Röntgenini Çekmeye Hazır mısın?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.corporateNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Yapay zeka tüm stoklarını, toptancılarını ve satışlarını analiz ederek sana özel stratejik bir rapor hazırlayacak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: AppColors.textDark, height: 1.4),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => ref
                              .read(aiReportProvider.notifier)
                              .generateShopReport(),
                          icon: const Icon(Icons.analytics_rounded, color: AppColors.energeticOrange),
                          label: const Text(
                            'Analizi Başlat',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.corporateNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.corporateNavy,
                padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.energeticOrange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'On-Par Otomotiv AI Yönetici Raporu',
                      style: TextStyle(
                        color: AppColors.energeticOrange,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.corporateNavy.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Markdown(
                      data: reportText,
                      padding: const EdgeInsets.all(20),
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(
                          color: AppColors.corporateNavy,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          color: AppColors.corporateNavy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        p: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textDark),
                        listBullet: const TextStyle(
                          color: AppColors.corporateNavy,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ref
                            .read(aiReportProvider.notifier)
                            .generateShopReport(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Raporu Yenile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.corporateNavy,
                          side: const BorderSide(color: AppColors.corporateNavy),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareViaWhatsApp(reportText),
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text('WP ile Gönder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.corporateNavy),
              const SizedBox(height: 24),
              const Text(
                'Yapay Zeka verileri inceliyor...',
                style: TextStyle(
                  color: AppColors.corporateNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        error: (err, stack) => StateFeedbackWidget.error(
          error: err,
          customTitle: 'Yapay Zeka Analizi Hazırlanamadı',
          onRetry: () => ref.read(aiReportProvider.notifier).generateShopReport(),
        ),
      ),
    ),
    );
  }
}
