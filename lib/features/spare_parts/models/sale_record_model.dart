import 'package:uuid/uuid.dart';

class SaleRecord {
  final String? id;
  final String clientTransactionId; // Çift Satışı Önleyen Benzersiz Idempotency Anahtarı
  final String partId;
  final String? partName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String paymentMethod;
  final String? buyerName;
  final String? companyName;
  final String? vehiclePlate;
  final String? vehicleBrandModel;
  final String? vehicleInfo;
  final String? notes;
  final DateTime? createdAt;
  final int? customerId;

  SaleRecord({
    this.id,
    String? clientTransactionId,
    required this.partId,
    this.partName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.paymentMethod = 'Nakit',
    this.buyerName,
    this.companyName,
    this.vehiclePlate,
    this.vehicleBrandModel,
    this.vehicleInfo,
    this.notes,
    this.createdAt,
    this.customerId,
  }) : clientTransactionId = clientTransactionId ?? const Uuid().v4();

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? defaultValue;
    }
    return defaultValue;
  }

  static int _parseInt(dynamic value, {int defaultValue = 1}) {
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

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    final rawDate = json['sale_date'] ?? json['created_at'];
    final pId = (json['spare_part_id'] ?? json['part_id'])?.toString().trim() ?? '';
    final rawPartName = (json['part_name'] ?? json['name'] ?? json['product_name'])?.toString().trim();
    final rawTxId = json['client_transaction_id']?.toString().trim();

    return SaleRecord(
      id: json['id']?.toString(),
      clientTransactionId: (rawTxId != null && rawTxId.isNotEmpty) ? rawTxId : const Uuid().v4(),
      partId: pId,
      partName: (rawPartName != null && rawPartName.isNotEmpty) ? rawPartName : null,
      quantity: _parseInt(json['quantity'], defaultValue: 1),
      unitPrice: _parseDouble(json['unit_price'] ?? json['unitPrice']),
      totalPrice: _parseDouble(json['total_price'] ?? json['totalPrice']),
      paymentMethod: json['payment_method']?.toString().trim() ?? 'Nakit',
      buyerName: json['buyer_name']?.toString().trim(),
      companyName: json['company_name']?.toString().trim(),
      vehiclePlate: json['vehicle_plate']?.toString().trim(),
      vehicleBrandModel: json['vehicle_brand_model']?.toString().trim(),
      vehicleInfo: json['vehicle_info']?.toString().trim(),
      notes: (json['note'] ?? json['notes'])?.toString().trim(),
      createdAt: _parseDate(rawDate),
      customerId: json['customer_id'] != null ? int.tryParse(json['customer_id'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final int parsedPartId = int.tryParse(partId) ?? 0;
    final noteCombined = [
      if (buyerName != null && buyerName!.isNotEmpty) 'Müşteri: $buyerName',
      if (vehiclePlate != null && vehiclePlate!.isNotEmpty) 'Plaka: $vehiclePlate',
      if (vehicleBrandModel != null && vehicleBrandModel!.isNotEmpty) 'Model: $vehicleBrandModel',
      if (notes != null && notes!.isNotEmpty) notes!,
    ].join(' | ');

    return {
      if (id != null) 'id': int.tryParse(id!),
      'spare_part_id': parsedPartId,
      'part_id': parsedPartId, // Geriye dönük uyumluluk
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'payment_method': paymentMethod,
      'note': noteCombined.isNotEmpty ? noteCombined : null,
      'notes': notes,
      'client_transaction_id': clientTransactionId,
      if (partName != null) 'part_name': partName,
      if (buyerName != null && buyerName!.isNotEmpty) 'buyer_name': buyerName,
      if (companyName != null && companyName!.isNotEmpty) 'company_name': companyName,
      if (vehiclePlate != null && vehiclePlate!.isNotEmpty) 'vehicle_plate': vehiclePlate,
      if (vehicleBrandModel != null && vehicleBrandModel!.isNotEmpty) 'vehicle_brand_model': vehicleBrandModel,
      if (customerId != null) 'customer_id': customerId,
    };
  }
}
