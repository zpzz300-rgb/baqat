// lib/widgets/money_words.dart
// 💬 كلمات الفلوس — **مصدر واحد** لأسماء الأرقام في البرنامج كله.
//
// المشكلة اللي بيحلّها: نفس الرقم كان ليه أربع أسامي في أربع شاشات —
// «قيمة الفاتورة»، «المبلغ الثابت»، «سعر الفاتورة»، «فاتورة الشركة».
// فتعدّل رقم في شاشة وتستنّاه يظهر في شاشة تانية وما يظهرش، وتفتكر إن
// البرنامج بايظ — وهو أصلاً رقمين مختلفين اتسمّوا بنفس الاسم.
//
// دلوقتي في **تلات أرقام بس**، لكل واحد اسم واحد ما بيتغيّرش:
//
//   1️⃣ فاتورة الشركة      = اللي الشركة بتاخده فعلاً (٤٢٥٠ للـ٣٨٠٠)
//   2️⃣ أساس الربح         = تكلفة الشهر الواحد اللي الربح بيتحسب عليها
//   3️⃣ الفاتورة اللي نزلت = الرقم اللي انت سجّلته لما الفاتورة جت
//
// أي شاشة جديدة بتعرض فلوس لازم تاخد الاسم من هنا، مش تخترع اسم جديد.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_theme.dart';

/// أسماء الأرقام الموحّدة. استخدمها في كل label و hint و عنوان.
abstract final class MoneyWords {
  /// 💰 السعر الخام اللي الشركة بتاخده في الفاتورة.
  static const rawBill = 'فاتورة الشركة';
  static const rawBillLabel = '💰 فاتورة الشركة (ج)';
  static const rawBillWhat =
      'الرقم اللي الشركة بتاخده فعلاً. لو الخط «شهر وشهر»، ده رقم الشهر '
      'اللي بتنزل فيه — مش نصه.';

  /// 📊 تكلفة الشهر الواحد اللي الربح بيتحسب عليها.
  static const profitBasis = 'أساس الربح';
  static const profitBasisLabel = '📊 أساس الربح — الشهر الواحد (ج)';
  static const profitBasisWhat =
      'التكلفة اللي بتتشال من دخلك كل شهر. للخط «شهر وشهر» دي عادةً نص '
      'فاتورة الشركة، لأنها بتتوزّع على شهرين.';

  /// 🧾 الرقم اللي اتسجّل لما الفاتورة نزلت فعلاً.
  static const actualBill = 'الفاتورة اللي نزلت';
  static const actualBillLabel = '🧾 الفاتورة اللي نزلت (ج)';
  static const actualBillWhat =
      'الرقم اللي انت كتبته لما الفاتورة جت. لو مختلف عن المتوقع، الفرق '
      'ده هو اللي بتراجع عليه الشركة.';

  /// 🔮 اللي البرنامج متوقّع إنه ينزل — محسوب، مش متكتوب بإيدك.
  static const expected = 'المتوقع';
  static const expectedWhat =
      'مجموع فواتير الشركة للخطوط اللي دورها الشهر ده. البرنامج بيحسبه '
      'لوحده، مابتكتبوش.';
}

/// ❓ زرار صغير بيشرح الفرق بين الأرقام التلاتة.
///
/// حطّه جنب أي عنوان فيه فلوس. أول ما المستخدم يحتار «ده أنهي رقم؟»
/// يلاقي الجواب في نفس الشاشة، مش محتاج يسأل ولا يجرّب.
class MoneyWordsHelp extends StatelessWidget {
  const MoneyWordsHelp({super.key, this.compact = false});

  /// نسخة أصغر — للأماكن الضيّقة.
  final bool compact;

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('إيه الفرق بين الأرقام؟',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WordRow(
                  name: MoneyWords.rawBill,
                  what: MoneyWords.rawBillWhat,
                  color: AppColors.blue2,
                ),
                _WordRow(
                  name: MoneyWords.profitBasis,
                  what: MoneyWords.profitBasisWhat,
                  color: AppColors.green2,
                ),
                _WordRow(
                  name: MoneyWords.actualBill,
                  what: MoneyWords.actualBillWhat,
                  color: AppColors.orange,
                ),
                _WordRow(
                  name: MoneyWords.expected,
                  what: MoneyWords.expectedWhat,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 10),
                const _Example(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('تمام', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        icon: Icon(Icons.help_outline, size: 17, color: AppColors.muted),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        tooltip: 'إيه الفرق بين الأرقام؟',
        onPressed: () => show(context),
      );
    }
    return TextButton.icon(
      onPressed: () => show(context),
      icon: Icon(Icons.help_outline, size: 15, color: AppColors.blue2),
      label: Text('إيه الفرق بين الأرقام؟',
          style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.blue2)),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.name, required this.what, required this.color});

  final String name;
  final String what;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: GoogleFonts.cairo(
                  fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
          Text(what,
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.text)),
        ],
      ),
    );
  }
}

/// مثال بأرقام حقيقية — أسرع من أي شرح.
class _Example extends StatelessWidget {
  const _Example();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'مثال — خط ٣٨٠٠ «شهر وشهر»:\n\n'
        '• ${MoneyWords.rawBill}: ٤٢٥٠ ج (بتنزل شهر وشهر لأ)\n'
        '• ${MoneyWords.profitBasis}: ٢١٢٥ ج (٤٢٥٠ ÷ ٢)\n'
        '• ${MoneyWords.expected} في الشهر اللي دوره: ٤٢٥٠ ج\n'
        '• ${MoneyWords.actualBill}: ٤٣٠٠ ج → في ٥٠ ج زيادة تراجع عليها',
        style: GoogleFonts.cairo(fontSize: 11, height: 1.7),
      ),
    );
  }
}
