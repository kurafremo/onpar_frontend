// lib/core/services/printer_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PrinterService {
  // TODO: Cihazı kurduğunda modemin yazıcıya verdiği IP adresini buraya gir
  static const String printerIp = '192.168.1.100'; 
  static const int printerPort = 9100;

  /// 100x70 Büyük Etiket (1D Code 128)
  static Future<bool> printLargeLabel({
    required String partName,
    required String oemCode,
    required String barcodeData,
    required int quantity,
  }) async {
    try {
      final socket = await Socket.connect(printerIp, printerPort, timeout: const Duration(seconds: 5));
      String tsplCommand = '''
SIZE 100 mm, 70 mm
GAP 2 mm, 0 mm
DIRECTION 1
CLS
TEXT 50,50,"3",0,2,2,"ON-PAR OTOMOTIV"
TEXT 50,150,"2",0,1,1,"Urun: $partName"
TEXT 50,220,"2",0,1,1,"OEM: $oemCode"
BARCODE 50,300,"128",100,1,0,2,2,"$barcodeData"
PRINT $quantity,1
''';
      socket.add(utf8.encode(tsplCommand));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Yazıcı Bağlantı Hatası: $e');
      return false;
    }
  }

  /// 58x40 Küçük Etiket (2D QR Code)
  static Future<bool> printSmallLabel({
    required String partName,
    required String oemCode,
    required String qrData,
    required int quantity,
  }) async {
    try {
      final socket = await Socket.connect(printerIp, printerPort, timeout: const Duration(seconds: 5));
      String tsplCommand = '''
SIZE 58 mm, 40 mm
GAP 2 mm, 0 mm
DIRECTION 1
CLS
TEXT 20,20,"2",0,1,1,"ON-PAR"
TEXT 20,60,"1",0,1,1,"$partName"
TEXT 20,100,"1",0,1,1,"OEM: $oemCode"
QRCODE 250,20,L,4,A,0,"$qrData"
PRINT $quantity,1
''';
      socket.add(utf8.encode(tsplCommand));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Yazıcı Bağlantı Hatası: $e');
      return false;
    }
  }
}