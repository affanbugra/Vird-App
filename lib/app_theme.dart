import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Temaya bağlı renkler — light ve dark için iki ayrı set.
/// Semantic renkler (teal, orange, gold, vs.) AppColors'ta sabit kalır.
class VirdColors extends ThemeExtension<VirdColors> {
  final Color surface;         // ana arka plan / scaffold
  final Color surfaceVariant;  // kart, container, açık gri alanlar
  final Color border;          // kenarlık, ayırıcı
  final Color textPrimary;     // birincil metin
  final Color textSecondary;   // ikincil metin
  final Color textTertiary;    // ipucu / placeholder metin
  final Color tealSurface;     // teal tonlu yüzey (tealLight karşılığı)

  const VirdColors({
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.tealSurface,
  });

  static const light = VirdColors(
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF7F7F7),
    border: Color(0xFFE5E5E5),
    textPrimary: Color(0xFF3C3C3C),
    textSecondary: Color(0xFF777777),
    textTertiary: Color(0xFFABABAB),
    tealSurface: Color(0xFFE8F5F7),
  );

  // Koyu ama sıcak — ham siyah değil, teal tonlarıyla renklendirilen derin lacivert-yeşil
  static const dark = VirdColors(
    surface: Color(0xFF0D1E24),
    surfaceVariant: Color(0xFF152D35),
    border: Color(0xFF2A4550),
    textPrimary: Color(0xFFE8F0F1),
    textSecondary: Color(0xFF8AACB2),
    textTertiary: Color(0xFF4A7A82),
    tealSurface: Color(0xFF0D2E35),
  );

  @override
  VirdColors copyWith({
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? tealSurface,
  }) =>
      VirdColors(
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        tealSurface: tealSurface ?? this.tealSurface,
      );

  @override
  VirdColors lerp(VirdColors? other, double t) {
    if (other == null) return this;
    return VirdColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      tealSurface: Color.lerp(tealSurface, other.tealSurface, t)!,
    );
  }
}

extension VirdColorsX on BuildContext {
  VirdColors get colors => Theme.of(this).extension<VirdColors>()!;
}

class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal),
        textTheme: GoogleFonts.nunitoTextTheme(),
        scaffoldBackgroundColor: VirdColors.light.surface,
        extensions: const [VirdColors.light],
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        scaffoldBackgroundColor: VirdColors.dark.surface,
        extensions: const [VirdColors.dark],
      );
}
