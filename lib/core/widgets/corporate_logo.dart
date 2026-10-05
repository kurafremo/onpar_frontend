// lib/core/widgets/corporate_logo.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CorporateLogo extends StatelessWidget {
  final bool isVertical;
  final double iconSize;
  final double fontSize;
  final bool isDark;

  const CorporateLogo({
    super.key,
    this.isVertical = false,
    this.iconSize = 36.0,
    this.fontSize = 24.0,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(
            text: 'On',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.corporateNavy,
            ),
          ),
          const TextSpan(
            text: '-Par',
            style: TextStyle(color: AppColors.energeticOrange),
          ),
        ],
      ),
    );

    final iconWidget = Image.asset(
      'assets/branding/onpar_logo_icon.png',
      height: iconSize,
      width: iconSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.precision_manufacturing_rounded,
        size: iconSize,
        color: AppColors.energeticOrange,
      ),
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 12),
          textWidget,
          const SizedBox(height: 4),
          Text(
            'AUTOMOTIVE ERP & POS',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textDark,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 10),
        textWidget,
      ],
    );
  }
}