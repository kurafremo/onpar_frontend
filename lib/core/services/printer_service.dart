// lib/core/services/printer_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PrinterService {
  static const String printerIp = '192.168.1.100'; 
  static const int printerPort = 9100;
  static const String windowsSharedPrinterName = 'PalmX';

  static String clearTurkishChars(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('Ü', 'U').replaceAll('ü', 'u')
        .replaceAll('Ğ', 'G').replaceAll('ğ', 'g')
        .replaceAll('Ş', 'S').replaceAll('ş', 's')
        .replaceAll('İ', 'I').replaceAll('ı', 'i')
        .replaceAll('Ö', 'O').replaceAll('ö', 'o')
        .replaceAll('Ç', 'C').replaceAll('ç', 'c');
  }

  static Future<bool> _sendTsplCommand(String tsplCommand) async {
    try {
      final socket = await Socket.connect(printerIp, printerPort, timeout: const Duration(seconds: 2));
      socket.add(utf8.encode(tsplCommand));
      await socket.flush();
      await socket.close();
      debugPrint('[PRINTER] Ağ (IP) üzerinden yazdırma kusursuz çalıştı.');
      return true;
    } catch (e) {
      debugPrint('[PRINTER] Ağ yazıcısı bulunamadı veya kablo takılı değil. B Planına geçiliyor...');
    }

    if (!kIsWeb && Platform.isWindows) {
      debugPrint('[PRINTER] Windows tespit edildi. USB portu üzerinden deneniyor...');
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}\\print_job.tspl');
        await file.writeAsString(tsplCommand);

        final process = await Process.run(
          'cmd', 
          ['/c', 'copy', file.path, '\\\\127.0.0.1\\$windowsSharedPrinterName']
        );

        if (process.exitCode == 0) {
          debugPrint('[PRINTER] Windows USB üzerinden yazdırma başarılı.');
          return true;
        } else {
          debugPrint('[PRINTER] USB CMD Hatası: ${process.stderr}');
          return false;
        }
      } catch (usbError) {
        debugPrint('[PRINTER] USB yazdırma sistemi hatası: $usbError');
        return false;
      }
    }
    debugPrint('[PRINTER] HATA: Yazıcı ağda bulunamadı.');
    return false;
  }

  /// 100x70 Büyük Etiket (Dinamik Satır Kaydırmalı)
  static Future<bool> printLargeLabel({
    required String partName,
    required String oemCode,
    required String barcodeData,
    required int quantity,
    required String brand,
    required String model,
    String? location, // İsteğe bağlı hale getirildi
  }) async {
    String safePartName = clearTurkishChars(partName);
    String safeOem = clearTurkishChars(oemCode);
    String safeBrand = clearTurkishChars(brand);
    String safeModel = clearTurkishChars(model);
    String safeLocation = location != null ? clearTurkishChars(location) : '';

    int currentY = 130; // Yazıların başladığı Y ekseni
    String tsplCommand = '''
SIZE 100 mm, 70 mm
GAP 2 mm, 0 mm
DIRECTION 1
REFERENCE 0,0
CLS
TEXT 120,50,"3",0,2,2,"ON-PAR OTOMOTIV"
''';

    tsplCommand += 'TEXT 120,$currentY,"2",0,1,1,"Urun: $safePartName"\n';
    currentY += 50;
    tsplCommand += 'TEXT 120,$currentY,"2",0,1,1,"Marka: $safeBrand"\n';
    currentY += 50;
    tsplCommand += 'TEXT 120,$currentY,"2",0,1,1,"Arac: $safeModel"\n';
    currentY += 50;

    // EĞER KONUM GİRİLDİYSE YAZDIR (Müşteri anlamasın diye şifreli gibi bas)
    if (safeLocation.isNotEmpty) {
      tsplCommand += 'TEXT 120,$currentY,"2",0,1,1,"** $safeLocation **"\n';
      currentY += 50;
    }

    tsplCommand += 'TEXT 120,$currentY,"2",0,1,1,"OEM: $safeOem"\n';
    currentY += 70; // Barkod için ekstra boşluk
    
    tsplCommand += 'BARCODE 120,$currentY,"128",100,1,0,2,2,"$barcodeData"\n';
    tsplCommand += 'PRINT $quantity,1\n';

    return await _sendTsplCommand(tsplCommand);
  }

  /// 60x40 Küçük Etiket (Dinamik Satır Kaydırmalı)
  static Future<bool> printSmallLabel({
    required String partName,
    required String oemCode,
    required String qrData,
    required int quantity,
    required String brand,
    required String model,
    String? location, // İsteğe bağlı hale getirildi
  }) async {
    String safePartName = clearTurkishChars(partName);
    String safeOem = clearTurkishChars(oemCode);
    String safeBrand = clearTurkishChars(brand);
    String safeModel = clearTurkishChars(model);
    String safeLocation = location != null ? clearTurkishChars(location) : '';

    int currentY = 60;
    String tsplCommand = '''
SIZE 60 mm, 40 mm
GAP 2 mm, 0 mm
DIRECTION 1
REFERENCE 0,0
CLS
TEXT 40,20,"2",0,1,1,"ON-PAR"
''';

    tsplCommand += 'TEXT 40,$currentY,"1",0,1,1,"$safePartName"\n';
    currentY += 40;
    tsplCommand += 'TEXT 40,$currentY,"1",0,1,1,"Mrk: $safeBrand"\n';
    currentY += 40;
    tsplCommand += 'TEXT 40,$currentY,"1",0,1,1,"Arac: $safeModel"\n';
    currentY += 40;

    // EĞER KONUM GİRİLDİYSE YAZDIR 
    if (safeLocation.isNotEmpty) {
      tsplCommand += 'TEXT 40,$currentY,"1",0,1,1,"*$safeLocation*"\n';
      currentY += 40;
    }

    tsplCommand += 'TEXT 40,$currentY,"1",0,1,1,"OEM: $safeOem"\n';
    tsplCommand += 'QRCODE 260,60,L,4,A,0,"$qrData"\n';
    tsplCommand += 'PRINT $quantity,1\n';

    return await _sendTsplCommand(tsplCommand);
  }
}