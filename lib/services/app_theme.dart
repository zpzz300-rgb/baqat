// lib/services/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ⭕ ألوان «خطوط الزيادة» (أرضي / هوم فور جي).
///
/// الفيروزي ده **مش مستخدم في أي حتة تانية في البرنامج** (البرنامج كحلي/
/// أخضر/أحمر/برتقالي/بنفسجي) — عشان خط الزيادة يتشاف من بصة واحدة وانت
/// بتقلّب بسرعة، من غير ما يتلخبط مع أي حالة تانية.
const kExtraTealA = Color(0xFF00796B); // أرضي — أخضر مزرق غامق
const kExtraTealB = Color(0xFF00BFA5); // أرضي — فيروزي فاتح
const kExtraCyanA = Color(0xFF00838F); // هوم 4G — أزرق مخضر غامق
const kExtraCyanB = Color(0xFF26C6DA); // هوم 4G — سماوي فاتح

/// 🎨 ألوان البرنامج — **بتتغيّر مع الوضع الليلي**.
///
/// قبل كده كانت كلها `const` بلون واحد ثابت، فالوضع الليلي كان بيغيّر
/// خلفية الشاشة بس والباقي يفضل أبيض. دلوقتي كل لون بقى getter بيرجّع
/// النسخة المناسبة حسب [AppColors.dark].
///
/// الفلاق بيتظبّط مرّة واحدة في [AppTheme.resolve] قبل ما الواجهة تتبني.
class AppColors {
  /// هل احنا في الوضع الليلي دلوقتي؟ (بيتظبّط من AppTheme.resolve)
  static bool dark = false;

  static Color _p(int light, int darkValue) =>
      Color(dark ? darkValue : light);

  // ── الأسطح والنصوص ──────────────────────────────────────────
  /// خلفية الصفحة.
  static Color get bg => _p(0xFFf0f7ff, 0xFF0d1b2e);

  /// خلفية الكروت والشيتات (كانت `Colors.white` منتشرة في كل حتة).
  static Color get surface => _p(0xFFffffff, 0xFF16263c);

  /// سطح تاني أهدى — خانات، صفوف بديلة، خلفيات خفيفة.
  static Color get surfaceAlt => _p(0xFFf0f4f8, 0xFF1d3050);

  static Color get white => surface;
  static Color get text => _p(0xFF0d1b2e, 0xFFe8eef7);
  static Color get muted => _p(0xFF607d9b, 0xFF8fa6c4);
  static Color get border => _p(0xFFc5d8f0, 0xFF2e4666);

  // ── الأزرق (اللون الأساسي) ─────────────────────────────────
  static Color get blue => _p(0xFF1e88e5, 0xFF42a5f5);
  static Color get blue2 => _p(0xFF0d47a1, 0xFF64b5f6);
  static Color get blue3 => _p(0xFF1565c0, 0xFF5c9ce6);
  static Color get blueLight => _p(0xFFe3f2fd, 0xFF17304d);
  static Color get blueMid => _p(0xFF90caf9, 0xFF2f5a8a);

  // ── الأخضر / البرتقالي / الأحمر / البنفسجي ──────────────────
  static Color get green => _p(0xFF00897b, 0xFF26a69a);
  static Color get green2 => _p(0xFF2e7d32, 0xFF66bb6a);
  static Color get greenLight => _p(0xFFe0f2f1, 0xFF12332c);
  static Color get orange => _p(0xFFf57c00, 0xFFffa726);
  static Color get orangeLight => _p(0xFFfff3e0, 0xFF3a2a12);
  static Color get red => _p(0xFFe53935, 0xFFef5350);
  static Color get red2 => _p(0xFFc62828, 0xFFe57373);
  static Color get redLight => _p(0xFFffebee, 0xFF3a1a1c);
  static Color get purple => _p(0xFF6a1b9a, 0xFFba68c8);
  static Color get purpleLight => _p(0xFFab47bc, 0xFFce93d8);

  /// أخضر واتساب — علامة تجارية، مابيتغيّرش.
  static const waGreen = Color(0xFF25D366);

  /// نص فوق سطح ملوّن (هيدر/زرار متملّي) — أبيض في الوضعين.
  static const onAccent = Color(0xFFffffff);

  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF0a2440), Color(0xFF0d3a6e), Color(0xFF14528f)]
            : const [Color(0xFF0d47a1), Color(0xFF1565c0), Color(0xFF1e88e5)],
      );

  static LinearGradient get groupHeadGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF16263c), Color(0xFF1a2e48)]
            : const [Color(0xFFe8f4fd), Color(0xFFdbeeff)],
      );
}

class AppTheme {
  // Pick theme based on style string
  static ThemeData resolve(String style, String fontSize, bool dark) {
    // 🌙 أهم سطر: بيقلب كل ألوان AppColors للنسخة الليلية/النهارية
    // قبل ما أي شاشة تتبني — فالبرنامج كله بيتغيّر مع بعضه.
    AppColors.dark = dark;
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
        surface: AppColors.surfaceAlt,
      ),
      scaffoldBackgroundColor: AppColors.surfaceAlt,
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
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.blue, width: 1.5),
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
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyMedium: GoogleFonts.cairo(fontSize: base, color: AppColors.text),
        bodyLarge: GoogleFonts.cairo(fontSize: base + 2, color: AppColors.text),
        bodySmall: GoogleFonts.cairo(fontSize: base - 2, color: AppColors.muted),
        titleMedium: GoogleFonts.cairo(fontSize: base + 2, fontWeight: FontWeight.w700, color: AppColors.text),
        titleLarge: GoogleFonts.cairo(fontSize: base + 4, fontWeight: FontWeight.w900, color: AppColors.blue2),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue2,
          foregroundColor: AppColors.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: base),
        ),
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
        color: AppColors.surface,
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
        color: AppColors.surface,
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

  /// 🔠 معامل تكبير النص لكل البرنامج.
  ///
  /// بيتظبّط في [MediaQuery] فوق كل الشاشات، فبيأثّر على كل نص —
  /// حتى اللي مكتوب حجمه بالإيد جوه الشاشات.
  /// الأرقام مضبوطة تكون محسوسة من غير ما تكسّر تصميم الكروت.
  static double textScale(String s) {
    switch (s) {
      case 'small': return 0.88;
      case 'large': return 1.14;
      default: return 1.0;
    }
  }

  static double _baseFontSize(String s) {
    switch (s) {
      case 'small': return 11;
      case 'large': return 15;
      default: return 13;
    }
  }
}
