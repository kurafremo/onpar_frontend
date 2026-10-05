import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/spare_part_provider.dart';
import 'part_detail_page.dart';

class CriticalStockPage extends ConsumerWidget {
  const CriticalStockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partsAsync = ref.watch(sparePartsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kritik & Tükenen Stoklar'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: partsAsync.when(
        data: (parts) {
          final criticalParts = parts.where((p) {
            final criticalLevel = p.criticalStockLevel ?? 5;
            return p.stockQuantity <= criticalLevel;
          }).toList();

          criticalParts.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

          if (criticalParts.isEmpty) {
            return const Center(
              child: Text(
                'Harika! Kritik seviyede stok bulunmuyor.',
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: criticalParts.length,
            itemBuilder: (context, index) {
              final part = criticalParts[index];
              final isOutOfStock = part.stockQuantity == 0;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isOutOfStock ? Colors.red[400]! : Colors.orange[300]!,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOutOfStock ? Colors.red[100] : Colors.orange[100],
                    child: Icon(
                      isOutOfStock ? Icons.cancel : Icons.warning_amber,
                      color: isOutOfStock ? Colors.red : Colors.orange[800],
                    ),
                  ),
                  title: Text(
                    part.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        isOutOfStock ? 'STOK TÜKENDİ!' : 'Kalan Stok: ${part.stockQuantity}',
                        style: TextStyle(
                          color: isOutOfStock ? Colors.red : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Son Alış: ₺${part.buyPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PartDetailPage(part: part)),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}