import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../providers/theme_provider.dart';

class AppTheme {
  static ThemeData getTheme(ThemeType type) {
    switch (type) {
      case ThemeType.light:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.teal,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.nunitoTextTheme(),
          scaffoldBackgroundColor: AppColors.white,
          useMaterial3: true,
        );
      
      case ThemeType.dark:
        final darkColorScheme = ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF1C1F26),
          primary: AppColors.teal,
        );
        return ThemeData(
          colorScheme: darkColorScheme,
          textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
          scaffoldBackgroundColor: const Color(0xFF13151A),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF13151A),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1C1F26),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF1C1F26),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFF1C1F26),
          ),
          popupMenuTheme: const PopupMenuThemeData(
            color: Color(0xFF1C1F26),
          ),
          bottomAppBarTheme: const BottomAppBarThemeData(
            color: Color(0xFF13151A),
          ),
          dividerTheme: DividerThemeData(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF252A34),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        );
    }
  }
}
