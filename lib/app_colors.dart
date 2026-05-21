import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF2A7F8C);
  static const tealDark = Color(0xFF1F6370);
  static const tealLight = Color(0xFFE8F5F7);

  static const orange = Color(0xFFFF9600);
  static const orangeDark = Color(0xFFCC7A00);

  static const gold = Color(0xFFFFC200);

  static const white = Color(0xFFFFFFFF);
  static const lightGrey = Color(0xFFF7F7F7);
  static const borderGrey = Color(0xFFE5E5E5);

  static const textDark = Color(0xFF3C3C3C);
  static const textMid = Color(0xFF777777);
  static const textLight = Color(0xFFABABAB);

  static const successGreen = Color(0xFF58CC02);
  static const successBg = Color(0xFFD7FFB8);
  static const errorRed = Color(0xFFFF4B4B);
  static const errorBg = Color(0xFFFFDFE0);
  static const infoBlue = Color(0xFF1CB0F6);

  // Dark Theme Colors
  static const darkBg = Color(0xFF13151A);
  static const darkCard = Color(0xFF1C1F26);
  static const darkTile = Color(0xFF252A34);
  static const darkBorder = Color(0xFF2E3440);
  static const darkShadow = Color(0xFF000000);
  static const darkHighlight = Color(0xFF1E222A);
}

/// Context-aware color extension for classic light/dark mode support.
extension ThemeColorsExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get scaffoldBg => isDarkMode ? AppColors.darkBg : AppColors.white;
  Color get cardBg => isDarkMode ? AppColors.darkCard : AppColors.white;
  Color get tileBg => isDarkMode ? AppColors.darkTile : AppColors.lightGrey;
  Color get borderColor => isDarkMode ? AppColors.darkBorder : AppColors.borderGrey;
  Color get bottomSheetBg => isDarkMode ? AppColors.darkCard : AppColors.white;

  // Classic dark mode: light text on dark, dark text on light
  Color get adaptiveTextDark => isDarkMode ? const Color(0xFFF3F4F6) : AppColors.textDark;
  Color get adaptiveTextMid => isDarkMode ? const Color(0xFF9CA3AF) : AppColors.textMid;
  Color get adaptiveTextLight => isDarkMode ? const Color(0xFF6B7280) : AppColors.textLight;

  // For elements that should stay light-grey-ish on light but become darker on dark
  Color get adaptiveLightGrey => isDarkMode ? AppColors.darkTile : AppColors.lightGrey;
  Color get adaptiveTealLight => isDarkMode ? AppColors.teal.withValues(alpha: 0.15) : AppColors.tealLight;
}

