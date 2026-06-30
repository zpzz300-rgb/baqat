// lib/screens/unified_billing_screen.dart
// 🧾 شاشة الفواتير الموحّدة — وضعين بزرّ واحد:
//   • ليستة   → BillsScreen          (عرض سريع لكل الفواتير)
//   • مراجعة  → CompanyInvoicesScreen (المراجعة الذكية: شهر وشهر + تحذير الزيادة)
// (تاب «الخطوط الرئيسية» القديم اتشال — مميزاته اتنقلت لكروت المجموعات)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_theme.dart';
import 'bills_screen.dart';
import 'company_invoices_screen.dart';
import 'billing_matrix_screen.dart';

class UnifiedBillingScreen extends StatefulWidget {
  const UnifiedBillingScreen({super.key});

  @override
  State<UnifiedBillingScreen> createState() => _UnifiedBillingScreenState();
}

class _UnifiedBillingScreenState extends State<UnifiedBillingScreen> {
  int _mode = 1; // 0 = ليستة | 1 = مراجعة (الافتراضي الأذكى)
  bool _switcherOpen = false; // مبدّل الوضع منطوي افتراضياً عشان مايعملش زحمة

  static const _modeLabels = ['ليستة', 'مراجعة', 'جدول'];
  static const _modeEmojis = ['📋', '🧾', '📊'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── مبدّل الوضع (منطوي) ──────────────────────────────────
        Material(
          color: AppColors.blue2,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Column(children: [
                // شريط مضغوط: الوضع الحالي + سهم يفتح/يقفل
                GestureDetector(
                  onTap: () => setState(() => _switcherOpen = !_switcherOpen),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Text('${_modeEmojis[_mode]} ${_modeLabels[_mode]}',
                          style: GoogleFonts.cairo(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(width: 8),
                      Text('— اضغط لتغيير العرض',
                          style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11)),
                      const Spacer(),
                      Icon(_switcherOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.white, size: 22),
                    ]),
                  ),
                ),
                if (_switcherOpen) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    _modeBtn(0, '📋', 'ليستة'),
                    const SizedBox(width: 8),
                    _modeBtn(1, '🧾', 'مراجعة'),
                    const SizedBox(width: 8),
                    _modeBtn(2, '📊', 'جدول'),
                  ]),
                ],
              ]),
            ),
          ),
        ),
        // ── المحتوى — IndexedStack عشان يحافظ على الفلاتر والـ scroll ─
        Expanded(
          child: IndexedStack(
            index: _mode,
            children: const [
              BillsScreen(),
              CompanyInvoicesScreen(),
              BillingMatrixScreen(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeBtn(int idx, String emoji, String label) {
    final sel = _mode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _mode = idx; _switcherOpen = false; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: sel ? Colors.white : Colors.white.withValues(alpha: 0.25),
                width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: sel ? AppColors.blue2 : Colors.white)),
          ]),
        ),
      ),
    );
  }
}
