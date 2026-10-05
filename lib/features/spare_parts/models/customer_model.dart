// lib/features/spare_parts/models/customer_model.dart

class Customer {
  final int? id;
  final String name;
  final String? companyName;
  final String? phone;
  final String? taxNumber;
  final String? taxOffice;
  final String? address;
  final double balance; // Kilit: Müşterinin bize olan toplam borcu
  final String? notes;
  final DateTime? createdAt;

  Customer({
    this.id,
    required this.name,
    this.companyName,
    this.phone,
    this.taxNumber,
    this.taxOffice,
    this.address,
    this.balance = 0.0,
    this.notes,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int?,
      name: json['name']?.toString() ?? 'Bilinmeyen Müşteri',
      companyName: json['company_name']?.toString(),
      phone: json['phone']?.toString(),
      taxNumber: json['tax_number']?.toString(),
      taxOffice: json['tax_office']?.toString(),
      address: json['address']?.toString(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (companyName != null && companyName!.isNotEmpty) 'company_name': companyName,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (taxNumber != null && taxNumber!.isNotEmpty) 'tax_number': taxNumber,
      if (taxOffice != null && taxOffice!.isNotEmpty) 'tax_office': taxOffice,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}

// Hesap Hareketleri (Ekstre) İçin Model
class CustomerTransactionHistory {
  final String type; // 'SALE' (Satış) veya 'TRANSACTION' (Ödeme)
  final String? transactionType; // Sadece TRANSACTION için: TAHSILAT, BORCLANDIRMA
  final int? saleId; 
  final String? partName; 
  final int? quantity; 
  final double? unitPrice; 
  final double amount; // Tutar
  final String? paymentMethod; 
  final String? description; 
  final DateTime date;

  CustomerTransactionHistory({
    required this.type,
    this.transactionType,
    this.saleId,
    this.partName,
    this.quantity,
    this.unitPrice,
    required this.amount,
    this.paymentMethod,
    this.description,
    required this.date,
  });

  factory CustomerTransactionHistory.fromJson(Map<String, dynamic> json) {
    return CustomerTransactionHistory(
      type: json['type']?.toString() ?? 'UNKNOWN',
      transactionType: json['transaction_type']?.toString(),
      saleId: json['sale_id'] as int?,
      partName: json['part_name']?.toString(),
      quantity: json['quantity'] as int?,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString(),
      description: json['description']?.toString(),
      date: json['date'] != null 
          ? DateTime.parse(json['date'].toString()) 
          : DateTime.now(),
    );
  }
}

// Müşteri Ekstre Özeti Modeli
class CustomerHistorySummary {
  final String customerName;
  final double currentBalance;
  final List<CustomerTransactionHistory> history;

  CustomerHistorySummary({
    required this.customerName,
    required this.currentBalance,
    required this.history,
  });

  factory CustomerHistorySummary.fromJson(Map<String, dynamic> json) {
    var historyList = json['history'] as List? ?? [];
    return CustomerHistorySummary(
      customerName: json['customer_name']?.toString() ?? '',
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      history: historyList.map((h) => CustomerTransactionHistory.fromJson(h)).toList(),
    );
  }
}