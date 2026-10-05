import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// On-Par Otomotiv Kurumsal Shimmer (İskelet Yükleme) Bileşenleri
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Yuvarlak veya Köşeli Shimmer Kutusu
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Parça Listesi için Kurumsal Shimmer İskeleti (CircularProgressIndicator Yerine)
class PartListShimmer extends StatelessWidget {
  final int itemCount;
  const PartListShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  ShimmerBox(width: 44, height: 44, borderRadius: 22),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: double.infinity, height: 16),
                        SizedBox(height: 8),
                        ShimmerBox(width: 140, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  ShimmerBox(width: 60, height: 32, borderRadius: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Marka Kataloğu Grid İskeleti
class BrandGridShimmer extends StatelessWidget {
  final int itemCount;
  const BrandGridShimmer({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 125).floor().clamp(2, 6);
        return AppShimmer(
          child: GridView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: crossAxisCount <= 2 ? 1.35 : 1.05,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerBox(width: 36, height: 36, borderRadius: 18),
                    SizedBox(height: 8),
                    ShimmerBox(width: 60, height: 12),
                    SizedBox(height: 4),
                    ShimmerBox(width: 40, height: 10),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
