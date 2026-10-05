class Supplier {
  final String? id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? taxOffice;
  final String? notes;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.taxOffice,
    this.notes,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['company_name'] ?? json['supplier_name'])?.toString().trim();
    final rawDeleted = json['is_deleted'] ?? json['deleted'];

    return Supplier(
      id: json['id']?.toString(),
      name: (rawName != null && rawName.isNotEmpty) ? rawName : 'Belirtilmemiş Tedarikçi',
      contactPerson: (json['contact_person'] ?? json['contactPerson'])?.toString().trim(),
      phone: (json['phone'] ?? json['phone_number'])?.toString().trim(),
      email: (json['email'] ?? json['mail'])?.toString().trim(),
      address: (json['address'] ?? json['location'])?.toString().trim(),
      taxNumber: (json['tax_number'] ?? json['taxNumber'] ?? json['vkn'])?.toString().trim(),
      taxOffice: (json['tax_office'] ?? json['taxOffice'])?.toString().trim(),
      notes: (json['note'] ?? json['notes'] ?? json['description'])?.toString().trim(),
      isDeleted: rawDeleted == true || rawDeleted == 1 || rawDeleted == 'true' || rawDeleted == '1',
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      if (value > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': int.tryParse(id!) ?? id,
      'name': name,
      if (contactPerson != null && contactPerson!.isNotEmpty) 'contact_person': contactPerson,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (taxNumber != null && taxNumber!.isNotEmpty) 'tax_number': taxNumber,
      if (taxOffice != null && taxOffice!.isNotEmpty) 'tax_office': taxOffice,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Supplier copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? taxOffice,
    String? notes,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      taxOffice: taxOffice ?? this.taxOffice,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
