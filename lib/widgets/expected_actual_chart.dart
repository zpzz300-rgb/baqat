// lib/widgets/expected_actual_chart.dart
// 📊 المتوقع ضد اللي نزل — شهر في كل صف.
//
// السؤال اللي بيجاوب عليه: «الشركة نزّلت أكتر من المفروض في أنهي شهر؟»
// عشان كده الرسم بيوري **الفرق** مش الرقمين جنب بعض: لو وريناهم عمودين
// متجاورين، بتفضل تقارن طولين متقاربين بعينك عشان تعرف مين أكبر — والفرق
// اللي بيهمّك (٣٠٠ ج) بيبقى أصغر حاجة في الصورة.
//
// 🎨 اللونين اتفحصوا بالحساب مش بالنظر (OKLab ΔE تحت محاكاة عمى الألوان):
//   • أحمر/أخضر — الاختيار البديهي — أسوأ حاجة ممكنة: تحت deutan الفرق
//     بينهم ٢.٥ من ١٠٠، يعني نفس اللون تقريباً لواحد من كل ١٢ راجل.
//   • برتقالي/أخضر برضه بيسقط في الوضع الليلي (protan = ٥.٩).
//   • أحمر/أزرق عدّى في الوضعين بهامش واسع (أسوأ حالة ٢٠.٣).
// وكمان الاتجاه (يمين/شمال) والرقم بعلامته مكتوبين — فحتى لو حد ماشافش
// اللون خالص، المعلومة كاملة.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/app_theme.dart';
import '../services/breakpoints.dart';

/// ألوان الرسم — درجات متفحوصة، مش أي أحمر وأزرق.
abstract final class _ChartColors {
  static Color _p(int light, int dark) => Color(AppColors.dark ? dark : light);

  /// نزلت **أكتر** من المتوقع — الفلوس اللي راحت منك.
  static Color get over => _p(0xFFe53935, 0xFFef5350);

  /// نزلت **أقل** من المتوقع.
  static Color get under => _p(0xFF1565c0, 0xFF4a90d9);
}

/// 📊 رسم المتوقع ضد اللي نزل.
///
/// [months] عدد الشهور المعروضة من الأحدث.
class ExpectedActualChart extends StatelessWidget {
  const ExpectedActualChart({
    super.key,
    required this.db,
    this.months = 8,
    this.onMonthTap,
  });

  final AppDB db;
  final int months;
  final void Function(String month)? onMonthTap;

  @override
  Widget build(BuildContext context) {
    final rows = db.companyStatement(null).take(months).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    // مقياس الرسم = أكبر فرق. لو كل الشهور مظبوطة، مفيش رسم يتعرض —
    // بنقول كده بالعربي بدل ما نرسم صفوف فاضية.
    final maxAbs = rows.fold<double>(
        0, (m, r) => r.diff.abs() > m ? r.diff.abs() : m);
    final wide = context.isWide;

    return Container(
      padding: EdgeInsets.all(wide ? 14 : 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('الفرق بين المتوقع واللي نزل',
            style: GoogleFonts.cairo(
                fontSize: wide ? 14 : 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        Text('كل شهر: نزل أكتر ولا أقل من المفروض',
            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
        const SizedBox(height: 10),

        if (maxAbs == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text('كل الشهور نزلت زي المتوقع بالظبط ✅',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green2)),
          )
        else
          for (final r in rows) ...[
            _DiffRow(
              month: r.month,
              diff: r.diff,
              expected: r.expected,
              actual: r.actual,
              maxAbs: maxAbs,
              wide: wide,
              onTap: onMonthTap == null ? null : () => onMonthTap!(r.month),
            ),
            // فاصل ٢ بكسل بين الأعمدة — من غيره العمودين المتجاورين
            // بيلزقوا ويبانوا عمود واحد طويل.
            const SizedBox(height: 2),
          ],

        if (maxAbs > 0) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _key(_ChartColors.under, 'نزل أقل'),
            const SizedBox(width: 14),
            _key(_ChartColors.over, 'نزل أكتر'),
          ]),
        ],
      ]),
    );
  }

  Widget _key(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 11,
          height: 11,
          decoration:
              BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        // النص بلون النص العادي — اللون بيبان في المربع جنبه بس.
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.muted)),
      ]);
}

/// صف شهر واحد: الاسم، عمود بيطلع من النص، والرقم بعلامته.
class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.month,
    required this.diff,
    required this.expected,
    required this.actual,
    required this.maxAbs,
    required this.wide,
    this.onTap,
  });

  final String month;
  final double diff, expected, actual, maxAbs;
  final bool wide;
  final VoidCallback? onTap;

  static const _arMonths = [
    '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String get _label {
    final p = month.split('-');
    if (p.length < 2) return month;
    final m = int.tryParse(p[1]) ?? 0;
    return m >= 1 && m <= 12 ? '${_arMonths[m]} ${p[0]}' : month;
  }

  @override
  Widget build(BuildContext context) {
    final over = diff > 0;
    final color = over ? _ChartColors.over : _ChartColors.under;
    final frac = maxAbs == 0 ? 0.0 : (diff.abs() / maxAbs).clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: wide ? 5 : 4),
        child: Row(children: [
          SizedBox(
            width: wide ? 92 : 74,
            child: Text(_label,
                style: GoogleFonts.cairo(
                    fontSize: wide ? 11.5 : 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ),
          // ── العمود: بيطلع من خط الصفر في النص ──────────────
          Expanded(
            child: SizedBox(
              height: wide ? 18 : 15,
              child: Row(children: [
                // النص الشمال = نزل أقل
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FractionallySizedBox(
                      widthFactor: over ? 0 : frac,
                      child: _bar(color, start: true),
                    ),
                  ),
                ),
                // خط الصفر — باهت عن قصد، مالوش يبقى أوضح من البيانات
                Container(width: 1, color: AppColors.border),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: over ? frac : 0,
                      child: _bar(color, start: false),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 7),
          // ── الرقم بعلامته — المعلومة كاملة من غير لون ─────
          SizedBox(
            width: wide ? 74 : 62,
            child: Text(
              diff == 0
                  ? 'مظبوط'
                  : '${over ? '+' : '−'}${diff.abs().toStringAsFixed(0)} ج',
              textAlign: TextAlign.end,
              style: GoogleFonts.cairo(
                  fontSize: wide ? 12 : 11,
                  fontWeight: FontWeight.w900,
                  color: diff == 0 ? AppColors.muted : color),
            ),
          ),
        ]),
      ),
    );
  }

  /// عمود رفيع بأطراف مدوّرة من ناحية القيمة بس — الناحية اللي على خط
  /// الصفر بتفضل مربّعة عشان تبان ملزوقة في الخط فعلاً.
  Widget _bar(Color color, {required bool start}) => Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadiusDirectional.horizontal(
            start: Radius.circular(start ? 4 : 0),
            end: Radius.circular(start ? 0 : 4),
          ),
        ),
      );
}
