import 'package:flutter/material.dart';
import '../app_colors.dart';

class HatimlerimScreen extends StatelessWidget {
  const HatimlerimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Hatimlerim',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
