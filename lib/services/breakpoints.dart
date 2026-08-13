// lib/services/breakpoints.dart
//
// 📐 مقاسات الشاشات — **مصدر واحد** لكل البرنامج.
//
// البرنامج بيشتغل على الموبايل والتاب والكمبيوتر (ويندوز). بدل ما كل شاشة
// تحسب لنفسها، الحسابات كلها هنا. أي شاشة عايزة تعرف «أنا على إيه دلوقتي؟»
// بتقول `context.bp` أو `context.cols` وخلاص.
//
// مهم: بنقيس **عرض النافذة**، مش نوع الجهاز. يعني لو صغّرت نافذة الويندوز
// البرنامج يرجع لشكل الموبايل لوحده — وده الصح.

import 'package:flutter/material.dart';

/// 🗜 الوضع المضغوط — بيتظبط من الإعدادات وبيصغّر كل حاجة أكتر 12%.
/// متغيّر عام (زي `AppColors.dark`) عشان أي widget يوصله من غير ما نمرّره
/// من شاشة لشاشة، وبيتحدّث من `main.dart` مع كل بناء.
bool kCompactMode = false;

/// مقاس الشاشة الحالي
enum Bp {
  /// موبايل عادي — أقل من 600
  phone,

  /// موبايل كبير / تاب صغير بالطول — 600 لـ 900
  phoneWide,

  /// تاب — 900 لـ 1300
  tablet,

  /// كمبيوتر / تاب كبير — أكبر من 1300
  desktop,
}

/// حدود المقاسات (عرض النافذة بالـ dp)
///
/// ⚠️ الأرقام دي متظبطة على **أجهزة المالك الفعلية** مش على أرقام نظرية:
///   • هواوي T8   = 533dp بالطول  · 853dp بالعرض
///   • Tab A9+    = 800dp بالطول  · 1280dp بالعرض
/// الحدود القديمة (600/900) كانت بتحط الجهازين في الخانة الغلط: التاب
/// A9+ كان بياخد شكل الموبايل بالطول، والهواوي كان مقفول عن اللف خالص.
const double kBpPhoneWide = 480;
const double kBpTablet = 760;
const double kBpDesktop = 1250;

/// أقصى عرض للمحتوى — بعد كده مفيش فايدة من التمدد، النص بيبقى
/// صعب تقراه لأن عينك بتمشي مسافة طويلة من آخر السطر لأول اللي بعده.
const double kContentMaxWidth = 1800;

Bp bpOf(double width) {
  if (width >= kBpDesktop) return Bp.desktop;
  if (width >= kBpTablet) return Bp.tablet;
  if (width >= kBpPhoneWide) return Bp.phoneWide;
  return Bp.phone;
}

extension BpContext on BuildContext {
  /// المقاس الحالي حسب عرض النافذة
  Bp get bp => bpOf(MediaQuery.sizeOf(this).width);

  /// موبايل؟ (عمود واحد، كل حاجة فوق بعضها)
  bool get isPhone => bp == Bp.phone;

  /// شاشة عريضة؟ (تاب أو كمبيوتر — فيه مساحة لأكتر من عمود)
  bool get isWide => bp == Bp.tablet || bp == Bp.desktop;

  /// كمبيوتر؟
  bool get isDesktop => bp == Bp.desktop;

  /// عدد أعمدة قايمة الخطوط
  int get groupCols => switch (bp) {
        Bp.phone => 1,
        Bp.phoneWide => 1,
        Bp.tablet => 2,
        Bp.desktop => 3,
      };

  /// عدد كروت العملاء في الصف جوّه المجموعة
  int get memberCols => switch (bp) {
        Bp.phone => 3,
        Bp.phoneWide => 4,
        Bp.tablet => 6,
        Bp.desktop => 8,
      };

  /// 📐 أقصى ارتفاع للهيدر الثابت (نسبة من الشاشة).
  ///
  /// كان 0.55 على كل الأجهزة — يعني نص الشاشة هيدر حتى على الكمبيوتر،
  /// والبيانات اللي بتتحرك تحت مضغوطة في النص التاني. على الشاشة
  /// العريضة الهيدر مش محتاج المساحة دي أصلاً.
  double get headerMaxRatio => switch (bp) {
        Bp.phone => 0.55,
        Bp.phoneWide => 0.42,
        Bp.tablet => 0.32,
        Bp.desktop => 0.26,
      };

  /// الهيدر الكبير يفتح افتراضياً؟ على الشاشة العريضة لأ — البيانات أهم.
  bool get headerOpenByDefault => bp == Bp.phone || bp == Bp.phoneWide;

  /// عدد أعمدة أي قايمة كروت عادية (الشاشات التانية)
  int get listCols => switch (bp) {
        Bp.phone => 1,
        Bp.phoneWide => 1,
        Bp.tablet => 2,
        Bp.desktop => 2,
      };

  /// هل القايمة الجانبية ☰ تفضل مفتوحة على الجنب بدل ما تتفتح وتتقفل؟
  bool get hasSideRail => bp == Bp.desktop;

  /// النوافذ المنبثقة: على الكمبيوتر تبقى نافذة في النص بدل ورقة من تحت
  bool get sheetsAsDialogs => bp == Bp.desktop;

  /// مسافات الحواف — أوسع على الشاشات الكبيرة
  double get gutter => switch (bp) {
        Bp.phone => 12,
        Bp.phoneWide => 16,
        Bp.tablet => 20,
        Bp.desktop => 24,
      };

  /// معامل حجم الخط حسب الشاشة — بيتضرب في إعداد المستخدم.
  ///
  /// الشاشة الكبيرة الهدف منها **بيانات أكتر** مش خط أكبر. الخط بيصغر
  /// شوية عشان الشاشة تشيل عدد أكبر من الخطوط والعملاء في نفس المساحة.
  double get bpTextScale =>
      switch (bp) {
        Bp.phone => 1.0,
        Bp.phoneWide => 0.98,
        Bp.tablet => 0.94,
        Bp.desktop => 0.90,
      } *
      (kCompactMode ? 0.92 : 1.0);

  /// معامل تصغير المسافات والحشو — كثافة أعلى = بيانات أكتر في الشاشة
  double get density =>
      switch (bp) {
        Bp.phone => 1.0,
        Bp.phoneWide => 0.94,
        Bp.tablet => 0.86,
        Bp.desktop => 0.80,
      } *
      (kCompactMode ? 0.85 : 1.0);

  /// يصغّر أي مقاس (حشو/مسافة) حسب كثافة الشاشة
  double d(double v) => v * density;
}

/// 📄 قالب الصفحة — بيحد أقصى عرض للمحتوى ويحطّه في النص.
///
/// من غيره، على شاشة 1900 بكسل الكارت بيتمدّ من أول الشاشة لآخرها، فالرقم
/// يبقى في ناحية والفاتورة في الناحية التانية وعينك تتعب وهي بتلف.
class ContentShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentShell({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w <= maxWidth) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
