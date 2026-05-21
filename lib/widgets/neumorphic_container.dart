import 'package:flutter/material.dart';
import '../app_colors.dart';

class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double depth;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.depth = 5.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    if (isDark) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkShadow,
              offset: Offset(depth, depth),
              blurRadius: depth * 2,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: AppColors.darkHighlight,
              offset: Offset(-depth, -depth),
              blurRadius: depth * 2,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      );
    }

    // Light mode — standard container with subtle shadow
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
