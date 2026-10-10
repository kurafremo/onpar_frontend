class SparePart {
  final String? id;
  final String name;
  final String? oemCode;
  final String? barcode;
  final String? brand;
  final String? supplierId;
  final List<String> compatibleVehicles;
  final double buyPrice;
  final double sellPrice;
  final int stockQuantity;
  final int criticalStockLevel;
  final String? location;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SparePart({
    this.id,
    this.supplierId,
    required this.name,
    this.oemCode,
    this.barcode,
    this.brand,
    this.compatibleVehicles = const [],
    required this.buyPrice,
    required this.sellPrice,
    this.stockQuantity = 0,
    this.criticalStockLevel = 5,
    this.location,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? defaultValue;
    }
    return defaultValue;
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ??
          (double.tryParse(value.replaceAll(',', '.').trim())?.toInt() ?? defaultValue);
    }
    return defaultValue;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return value > 10000000000
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<String> _parseVehicles(dynamic vehicles, dynamic model) {
    if (vehicles is List) {
      return vehicles.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (model != null && model.toString().trim().isNotEmpty) {
      return model.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (vehicles is String && vehicles.trim().isNotEmpty) {
      return vehicles.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  // REST API'den gelen JSON verisini patlamadan, %100 null-safe şekilde Dart nesnesine çevirir
  factory SparePart.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['part_name'] ?? json['product_name'])?.toString().trim();
    final rawBrand = (json['brand'] ?? json['brand_name'])?.toString().trim();
    final rawOem = (json['oem_code'] ?? json['oemCode'])?.toString().trim();
    final rawBarcode = (json['barcode'] ?? json['barcode_number'])?.toString().trim();
    final rawSupplierId = (json['supplier_id'] ?? json['supplierId'])?.toString().trim();
    final rawLocation = (json['location'] ?? json['shelf_location'] ?? json['shelfLocation'])?.toString().trim();
    final rawDeleted = json['is_deleted'] ?? json['deleted'];

    return SparePart(
      id: (json['id'] ?? json['spare_part_id'])?.toString(),
      name: (rawName != null && rawName.isNotEmpty) ? rawName : 'İsimsiz Parça',
      oemCode: (rawOem != null && rawOem.isNotEmpty) ? rawOem : null,
      barcode: (rawBarcode != null && rawBarcode.isNotEmpty) ? rawBarcode : null,
      brand: (rawBrand != null && rawBrand.isNotEmpty) ? rawBrand : 'Belirtilmemiş',
      supplierId: (rawSupplierId != null && rawSupplierId.isNotEmpty && rawSupplierId != 'null' && rawSupplierId != '0')
          ? rawSupplierId
          : null,
      compatibleVehicles: _parseVehicles(json['compatible_vehicles'], json['model']),
      buyPrice: _parseDouble(json['buy_price'] ?? json['buyPrice']),
      sellPrice: _parseDouble(json['sell_price'] ?? json['sellPrice']),
      stockQuantity: _parseInt(json['stock_quantity'] ?? json['stockQuantity']),
      criticalStockLevel: _parseInt(
        json['min_stock_alert'] ?? json['critical_stock_level'] ?? json['criticalStockLevel'],
        defaultValue: 5,
      ),
      location: (rawLocation != null && rawLocation.isNotEmpty) ? rawLocation : null,
      isDeleted: rawDeleted == true || rawDeleted == 1 || rawDeleted == 'true' || rawDeleted == '1',
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  // Dart nesnesini API'ye gönderilmek üzere JSON formatına çevirir
  Map<String, dynamic> toJson() {
    final int? parsedSupplierId = supplierId != null ? int.tryParse(supplierId!) : null;
    return {
      if (id != null) 'id': int.tryParse(id!) ?? id,
      'name': name,
      if (oemCode != null && oemCode!.isNotEmpty) 'oem_code': oemCode,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      'brand': (brand != null && brand!.isNotEmpty) ? brand : 'Belirtilmemiş',
      'model': compatibleVehicles.isNotEmpty ? compatibleVehicles.join(', ') : null,
      'compatible_vehicles': compatibleVehicles,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'stock_quantity': stockQuantity,
      'min_stock_alert': criticalStockLevel,
      'critical_stock_level': criticalStockLevel,
      if (location != null && location!.isNotEmpty) 'location': location,
      'is_deleted': isDeleted,
      'supplier_id': parsedSupplierId,
    };
  }

  SparePart copyWith({
    String? id,
    String? name,
    String? oemCode,
    String? barcode,
    String? brand,
    String? supplierId,
    List<String>? compatibleVehicles,
    double? buyPrice,
    double? sellPrice,
    int? stockQuantity,
    int? criticalStockLevel,
    String? location,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SparePart(
      id: id ?? this.id,
      name: name ?? this.name,
      oemCode: oemCode ?? this.oemCode,
      barcode: barcode ?? this.barcode,
      brand: brand ?? this.brand,
      supplierId: supplierId ?? this.supplierId,
      compatibleVehicles: compatibleVehicles ?? this.compatibleVehicles,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      criticalStockLevel: criticalStockLevel ?? this.criticalStockLevel,
      location: location ?? this.location,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BrandSummary {
  final String brand;
  final int totalItems;

  const BrandSummary({
    required this.brand,
    required this.totalItems,
  });

  factory BrandSummary.fromJson(Map<String, dynamic> json) {
    final rawBrand = (json['brand'] ?? json['brand_name'] ?? json['name'])?.toString().trim();
    
    final rawCount = json['total_items'] ??
        json['totalItems'] ??
        json['count'] ??
        json['total_count'] ??
        json['total_parts'] ??
        json['totalParts'] ??
        0;

    final count = int.tryParse(rawCount.toString()) ?? 0;

    return BrandSummary(
      brand: (rawBrand != null && rawBrand.isNotEmpty) ? rawBrand : 'Diğer / Markasız',
      totalItems: count,
    );
  }

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'total_items': totalItems,
    'totalItems': totalItems,
    'count': totalItems,
  };
}