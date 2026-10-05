import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../features/spare_parts/models/sale_record_model.dart';
import '../../features/spare_parts/models/spare_part_model.dart';

/// SQLite Yerel Veritabanı Yöneticisi (Offline-First Enterprise Database Helper)
/// RAM şişmesini önlemek için disk tabanlı depolama ve 'LIMIT 50 OFFSET ?' sorgulama kullanır.
class LocalDatabaseHelper {
  static final LocalDatabaseHelper _instance = LocalDatabaseHelper._internal();
  factory LocalDatabaseHelper() => _instance;
  LocalDatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'on_par_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. Yedek Parça Önbellek Tablosu
        await db.execute('''
          CREATE TABLE cached_spare_parts (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            oem_code TEXT,
            barcode TEXT,
            brand TEXT,
            supplier_id TEXT,
            compatible_vehicles TEXT,
            buy_price REAL,
            sell_price REAL,
            stock_quantity INTEGER,
            critical_stock_level INTEGER,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        // Hızlı arama için SQL İndeksleri
        await db.execute('CREATE INDEX idx_parts_name ON cached_spare_parts (name);');
        await db.execute('CREATE INDEX idx_parts_barcode ON cached_spare_parts (barcode);');
        await db.execute('CREATE INDEX idx_parts_oem ON cached_spare_parts (oem_code);');
        await db.execute('CREATE INDEX idx_parts_brand ON cached_spare_parts (brand);');

        // 2. Çevrimdışı Satış Kuyruğu Tablosu (FIFO Queue - Idempotency Korumalı)
        await db.execute('''
          CREATE TABLE offline_sales_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_transaction_id TEXT UNIQUE,
            part_id TEXT NOT NULL,
            part_name TEXT,
            quantity INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            total_price REAL NOT NULL,
            buyer_name TEXT,
            company_name TEXT,
            vehicle_plate TEXT,
            vehicle_brand_model TEXT,
            vehicle_info TEXT,
            notes TEXT,
            created_at TEXT
          )
        ''');
      },
    );
  }

  // ==================== YEDEK PARÇA ÖNBELLEKLEME (DISK TABANLI) ====================

  /// API'den gelen parçaları SQLite'a toplu (Batch Transaction) olarak yazar
  Future<void> upsertSpareParts(List<SparePart> parts) async {
    if (parts.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final part in parts) {
      final partId = int.tryParse(part.id ?? '');
      batch.insert(
        'cached_spare_parts',
        {
          if (partId != null) 'id': partId,
          'name': part.name,
          'oem_code': part.oemCode,
          'barcode': part.barcode,
          'brand': part.brand,
          'supplier_id': part.supplierId,
          'compatible_vehicles': jsonEncode(part.compatibleVehicles),
          'buy_price': part.buyPrice,
          'sell_price': part.sellPrice,
          'stock_quantity': part.stockQuantity,
          'critical_stock_level': part.criticalStockLevel,
          'created_at': part.createdAt?.toIso8601String(),
          'updated_at': part.updatedAt?.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// RAM Şişmesini Önleyen Disk Tabanlı Sayfalama (LIMIT 50 OFFSET ?)
  Future<List<SparePart>> getSparePartsPaged({
    String query = '',
    String? brand,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (query.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR barcode LIKE ? OR oem_code LIKE ?)');
      final searchPattern = '%${query.trim()}%';
      whereArgs.addAll([searchPattern, searchPattern, searchPattern]);
    }

    if (brand != null && brand.isNotEmpty && brand != 'Diğer / Markasız') {
      whereClauses.add('brand = ?');
      whereArgs.add(brand);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      'cached_spare_parts',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      limit: limit,
      offset: offset,
      orderBy: 'name ASC',
    );

    return rows.map((row) {
      List<String> vehicles = [];
      final rawVehicles = row['compatible_vehicles'] as String?;
      if (rawVehicles != null && rawVehicles.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawVehicles);
          if (decoded is List) {
            vehicles = List<String>.from(decoded);
          }
        } catch (_) {
          vehicles = rawVehicles.split(',').map((e) => e.trim()).toList();
        }
      }

      return SparePart(
        id: row['id']?.toString(),
        name: row['name'] as String,
        oemCode: row['oem_code'] as String?,
        barcode: row['barcode'] as String?,
        brand: row['brand'] as String?,
        supplierId: row['supplier_id'] as String?,
        compatibleVehicles: vehicles,
        buyPrice: (row['buy_price'] as num?)?.toDouble() ?? 0.0,
        sellPrice: (row['sell_price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (row['stock_quantity'] as int?) ?? 0,
        criticalStockLevel: (row['critical_stock_level'] as int?) ?? 5,
        createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at'] as String) : null,
        updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at'] as String) : null,
      );
    }).toList();
  }

  /// Kritik stok seviyesindeki parçaları diskten okur
  Future<List<SparePart>> getCriticalStockParts({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'cached_spare_parts',
      where: 'stock_quantity <= critical_stock_level',
      orderBy: 'stock_quantity ASC',
      limit: limit,
    );

    return rows.map((row) {
      return SparePart(
        id: row['id']?.toString(),
        name: row['name'] as String,
        oemCode: row['oem_code'] as String?,
        barcode: row['barcode'] as String?,
        brand: row['brand'] as String?,
        buyPrice: (row['buy_price'] as num?)?.toDouble() ?? 0.0,
        sellPrice: (row['sell_price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (row['stock_quantity'] as int?) ?? 0,
        criticalStockLevel: (row['critical_stock_level'] as int?) ?? 5,
      );
    }).toList();
  }

  // ==================== ÇEVRİMDIŞI SATIŞ KUYRUĞU (FIFO QUEUE) ====================

  /// Yeni bir satışı SQLite kuyruğuna ekler
  Future<int> enqueueSale(SaleRecord record) async {
    final db = await database;
    return await db.insert('offline_sales_queue', {
      'client_transaction_id': record.clientTransactionId,
      'part_id': record.partId,
      'part_name': record.partName,
      'quantity': record.quantity,
      'unit_price': record.unitPrice,
      'total_price': record.totalPrice,
      'buyer_name': record.buyerName,
      'company_name': record.companyName,
      'vehicle_plate': record.vehiclePlate,
      'vehicle_brand_model': record.vehicleBrandModel,
      'vehicle_info': record.vehicleInfo,
      'notes': record.notes,
      'created_at': (record.createdAt ?? DateTime.now()).toIso8601String(),
    });
  }

  /// Toplu satışları SQLite kuyruğuna ekler
  Future<void> enqueueBulkSale(List<SaleRecord> records) async {
    if (records.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final record in records) {
      batch.insert('offline_sales_queue', {
        'client_transaction_id': record.clientTransactionId,
        'part_id': record.partId,
        'part_name': record.partName,
        'quantity': record.quantity,
        'unit_price': record.unitPrice,
        'total_price': record.totalPrice,
        'buyer_name': record.buyerName,
        'company_name': record.companyName,
        'vehicle_plate': record.vehiclePlate,
        'vehicle_brand_model': record.vehicleBrandModel,
        'vehicle_info': record.vehicleInfo,
        'notes': record.notes,
        'created_at': (record.createdAt ?? DateTime.now()).toIso8601String(),
      });
    }

    await batch.commit(noResult: true);
  }

  /// Bekleyen satışları FIFO (First In First Out) sırasıyla getirir
  Future<List<Map<String, dynamic>>> getPendingSalesQueue() async {
    final db = await database;
    return await db.query(
      'offline_sales_queue',
      orderBy: 'id ASC',
    );
  }

  /// Başarıyla sunucuya aktarılan satışı kuyruktan siler
  Future<void> removeSaleFromQueue(int queueId) async {
    final db = await database;
    await db.delete('offline_sales_queue', where: 'id = ?', whereArgs: [queueId]);
  }

  /// Bekleyen işlem sayısını döner (UI Rozetleri ve Bildirimler İçin)
  Future<int> getQueueCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM offline_sales_queue');
    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as int);
    }
    return 0;
  }

  /// Tüm kuyruğu temizler
  Future<void> clearQueue() async {
    final db = await database;
    await db.delete('offline_sales_queue');
  }
}
