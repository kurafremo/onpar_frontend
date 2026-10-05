import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale_record_model.dart';

class ReceiptDetailPage extends StatelessWidget {
  final String receiptId;
  final List<SaleRecord> records;

  const ReceiptDetailPage({
    super.key,
    required this.receiptId,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    // Fişteki genel bilgileri ilk üründen alıyoruz (Hepsi aynı sepette olduğu için aynıdır)
    final firstRecord = records.first;
    final totalAmount = records.fold(0.0, (sum, item) => sum + item.totalPrice);
    final dateString = firstRecord.createdAt != null
        ? "${firstRecord.createdAt!.day.toString().padLeft(2, '0')}.${firstRecord.createdAt!.month.toString().padLeft(2, '0')}.${firstRecord.createdAt!.year}  ${firstRecord.createdAt!.hour.toString().padLeft(2, '0')}:${firstRecord.createdAt!.minute.toString().padLeft(2, '0')}"
        : "-";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Satış Fişi Detayı',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- ÜST BİLGİ KARTI ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fiş No: ${receiptId.replaceAll('FIS-', '')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      dateString,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (firstRecord.buyerName?.isNotEmpty == true) ...[
                  Text(
                    'Müşteri: ${firstRecord.buyerName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (firstRecord.companyName?.isNotEmpty == true) ...[
                  Text(
                    'Şirket: ${firstRecord.companyName}',
                    style: TextStyle(color: Colors.blueGrey[700]),
                  ),
                  const SizedBox(height: 4),
                ],
                if (firstRecord.vehiclePlate?.isNotEmpty == true) ...[
                  Text(
                    'Araç/Plaka: ${firstRecord.vehiclePlate} ${firstRecord.vehicleBrandModel ?? ''}',
                    style: TextStyle(color: Colors.blueGrey[700]),
                  ),
                  const SizedBox(height: 4),
                ],
                if (firstRecord.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Not: ${firstRecord.notes}',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GENEL TOPLAM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    Text(
                      currencyFormat.format(totalAmount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- SATILAN ÜRÜNLER LİSTESİ ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Satılan Ürünler (${records.length} Çeşit)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final item = records[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[50],
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                    title: Text(
                      item.partName ?? 'Bilinmeyen Ürün',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${item.quantity} Adet x ${currencyFormat.format(item.unitPrice)}',
                    ),
                    trailing: Text(
                      currencyFormat.format(item.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
