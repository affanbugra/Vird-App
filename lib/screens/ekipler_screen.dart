import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../app_assets.dart';
import '../widgets/duolingo_button.dart';

class EkiplerScreen extends StatelessWidget {
  const EkiplerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Ekipler',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Takım Butonu
            SizedBox(
              width: 140,
              child: DuolingoButton(
                onPressed: () {},
                color: const Color(0xFFF3F4F6),
                bottomColor: const Color(0xFFD1D5DB),
                borderRadius: 28.0,
                height: 140,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: Image.asset(
                      AppAssets.ricalIFarkLogo,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ricâl-i Fark',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 48),
            // Alt Bilgi
            Text(
              'Ekipler özelliği çok yakında!',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kendi ekibini oluştur, arkadaşlarınla\nyarışarak hayra öncülük et.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}
