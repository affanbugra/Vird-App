import 'package:flutter/material.dart';
import '../../app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Assuming we have a white logo version for teal background,
            // or just use a text for now if logo is not suitable
            Image.asset(
              'assets/images/vird_logo.png',
              height: 120,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.menu_book,
                size: 80,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppColors.white,
            ),
          ],
        ),
      ),
    );
  }
}
