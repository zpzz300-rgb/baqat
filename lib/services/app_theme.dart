// lib/services/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFf0f7ff);
  static const white = Color(0xFFffffff);
  static const blue = Color(0xFF1e88e5);
  static const blue2 = Color(0xFF0d47a1);
  static const blue3 = Color(0xFF1565c0);
  static const blueLight = Color(0xFFe3f2fd);
  static const blueMid = Color(0xFF90caf9);
  static const green = Color(0xFF00897b);
  static const green2 = Color(0xFF2e7d32);
  static const greenLight = Color(0xFFe0f2f1);
  static const orange = Color(0xFFf57c00);
  static const orangeLight = Color(0xFFfff3e0);
  static const red = Color(0xFFe53935);
  static const red2 = Color(0xFFc62828);
  static const redLight = Color(0xFFffebee);
  static const text = Color(0xFF0d1b2e);
  static const muted = Color(0xFF607d9b);
  static const border = Color(0xFFc5d8f0);
  static const purple = Color(0xFF6a1b9a);
  static const purpleLight = Color(0xFFab47bc);
  static const waGreen = Color(0xFF25D366);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0d47a1), Color(0xFF1565c0), Color(0xFF1e88e5)],
  );

  static const groupHeadGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFe8f4fd), Color(0xFFdbeeff)],
  );
}

class AppTheme {
  // Pick theme based on style string
  static ThemeData resolve(String style, String fontSize, bool dark) {
    if (dark) return AppTheme.dark(fontSize);
    switch (style) {
      case 'emerald': return AppTheme.emerald(fontSize);
      case 'purple':  return AppTheme.purple(fontSize);
      default:        return AppTheme.light(fontSize);
    }
  }

  static ThemeData light(String fontSize) {
    final base = _baseFontSize(fontSize);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue2,
        surface: const Color(0xFFf0f4f8),
      ),
      scaffoldBackgroundColor: const Color(0xFFf0f4f8),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        bodyMedium: GoogleFonts.cairo(fontSize: base, color: AppColors.text),
        bodyLarge: GoogleFonts.cairo(fontSize: base + 2, color: AppColors.text),
        bodySmall: GoogleFonts.cairo(fontSize: base - 2, color: AppColors.muted),
        titleMedium: GoogleFonts.cairo(fontSize: base + 2, fontWeight: FontWeight.w700, color: AppColors.text),
        titleLarge: GoogleFonts.cairo(fontSize: base + 4, fontWeight: FontWeight.w900, color: AppColors.blue2),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue2,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: base),
        ),
      ),
    );
  }

  static ThemeData dark(String fontSize) {
    final base = _baseFontSize(fontSize);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0d1b2e),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyMedium: GoogleFonts.cairo(fontSize: base, color: Colors.white),
        bodySmall: GoogleFonts.cairo(fontSize: base - 2, color: Colors.white70),
        titleLarge: GoogleFonts.cairo(fontSize: base + 4, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }

  static ThemeData emerald(String fontSize) {
    final base = _baseFontSize(fontSize);
    const primary = Color(0xFF1b5e20);
    const seed    = Color(0xFF43a047);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, surface: const Color(0xFFf1f8f1)),
      scaffoldBackgroundColor: const Color(0xFFf1f8f1),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        bodyMedium: GoogleFonts.cairo(fontSize: base, color: const Color(0xFF0d2b0d)),
        bodyLarge:  GoogleFonts.cairo(fontSize: base + 2, color: const Color(0xFF0d2b0d)),
        bodySmall:  GoogleFonts.cairo(fontSize: base - 2, color: const Color(0xFF4a7c4a)),
        titleMedium: GoogleFonts.cairo(fontSize: base + 2, fontWeight: FontWeight.w700, color: const Color(0xFF0d2b0d)),
        titleLarge:  GoogleFonts.cairo(fontSize: base + 4, fontWeight: FontWeight.w900, color: primary),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFa5d6a7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFe8f5e9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFa5d6a7), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFa5d6a7), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: seed, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: base),
        ),
      ),
    );
  }

  static ThemeData purple(String fontSize) {
    final base = _baseFontSize(fontSize);
    const primary = Color(0xFF4a148c);
    const seed    = Color(0xFF7b1fa2);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, surface: const Color(0xFFf8f0ff)),
      scaffoldBackgroundColor: const Color(0xFFf8f0ff),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        bodyMedium: GoogleFonts.cairo(fontSize: base, color: const Color(0xFF1a0030)),
        bodyLarge:  GoogleFonts.cairo(fontSize: base + 2, color: const Color(0xFF1a0030)),
        bodySmall:  GoogleFonts.cairo(fontSize: base - 2, color: const Color(0xFF7c5a9e)),
        titleMedium: GoogleFonts.cairo(fontSize: base + 2, fontWeight: FontWeight.w700, color: const Color(0xFF1a0030)),
        titleLarge:  GoogleFonts.cairo(fontSize: base + 4, fontWeight: FontWeight.w900, color: primary),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFce93d8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFf3e5f5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFce93d8), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFce93d8), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: seed, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: base),
        ),
      ),
    );
  }

  static double _baseFontSize(String s) {
    switch (s) {
      case 'small': return 11;
      case 'large': return 15;
      default: return 13;
    }
  }
}
