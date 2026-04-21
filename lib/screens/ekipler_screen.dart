import 'package:flutter/material.dart';
import '../app_colors.dart';

class EkiplerScreen extends StatelessWidget {
  const EkiplerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Ekipler',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
