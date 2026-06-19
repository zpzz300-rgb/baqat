// lib/screens/billing_matrix_screen.dart
// 📊 جدول المصفوفة: صفوف = الخطوط، أعمدة = الشهور.
// كل خانة تعرض المتبقي + لون الحالة (أحمر=عليه فلوس، أخضر=مسدد، رمادي=مفيش فاتورة).
// عرض للقراءة فقط — مبني فوق companyBills الموجودة (مايلمسش أي حسابات).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/app_theme.dart';

class BillingMatrixScreen extends StatefulWidget {
  const BillingMatrixScreen({super.key});
  @override
  State<BillingMatrixScreen> createState() => _BillingMatrixScreenState();
}

class _BillingMatrixScreenState extends State<BillingMatrixScreen> {
  String _search = '';

  static const double _nameW = 130; // عرض عمود الخط
  static const double _cellW = 84;  // عرض خانة الشهر

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;

    // كل الشهور اللي فيها فواتير، مرتبة تصاعدي
    final months = db.companyBills.map((b) => b.month).toSet().toList()..sort();

    // الخطوط اللي عليها أي فاتورة + فلتر البحث
    final groupsWithBills = db.groups.where((g) {
      final hasBill = db.companyBills.any((b) => b.groupId == g.id);
      if (!hasBill) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return g.phone.contains(q) ||
          (g.ownerName ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.phone.compareTo(b.phone));

    // فهرسة سريعة للفواتير: gid|month -> bill
    final billIndex = <String, CompanyBill>{};
    for (final b in db.companyBills) {
      final k = '${b.groupId}|${b.month}';
      // لو فيه أكتر من فاتورة لنفس الشهر، اجمع المتبقي على أول واحدة
      final existing = billIndex[k];
      if (existing == null) {
        billIndex[k] = b;
      }
    }

    final totalDue = db.companyBills
        .where((b) => !b.isPaid)
        .fold(0.0, (s, b) => s + b.remaining);

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────
      Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(children: [
          Row(children: [
            const Text('📊', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('جدول الفواتير شهرياً',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
            _chip('${groupsWithBills.length} خط', Colors.white24),
            const SizedBox(width: 6),
            _chip('متبقي: ${totalDue.toStringAsFixed(0)} ج',
                const Color(0x33ff5252)),
          ]),
          const SizedBox(height: 10),
          // بحث
          SizedBox(
            height: 38,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                hintText: '🔍 بحث بالرقم أو الاسم...',
                hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
        ]),
      ),
      // ── Legend ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          _legend(AppColors.redLight, AppColors.red2, 'عليه فلوس'),
          const SizedBox(width: 10),
          _legend(AppColors.greenLight, const Color(0xFF00695c), 'مسدد'),
          const SizedBox(width: 10),
          _legend(const Color(0xFFFFF3E0), const Color(0xFFE65100), 'مؤجل'),
          const SizedBox(width: 10),
          _legend(const Color(0xFFF5F5F5), AppColors.muted, 'مفيش فاتورة'),
        ]),
      ),
      // ── Matrix ──────────────────────────────────────────────────
      Expanded(
        child: (months.isEmpty || groupsWithBills.isEmpty)
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📊', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('لا توجد فواتير لعرضها',
                      style: GoogleFonts.cairo(color: AppColors.muted)),
                ]),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صف العناوين (الشهور)
                      Row(children: [
                        _headerCell('الخط', _nameW),
                        for (final m in months) _headerCell(_fmtMonth(m), _cellW),
                      ]),
                      // صفوف الخطوط
                      for (final g in groupsWithBills)
                        Row(children: [
                          _nameCell(g),
                          for (final m in months)
                            _dataCell(billIndex['${g.id}|$m']),
                        ]),
                    ],
                  ),
                ),
              ),
      ),
    ]);
  }

  // ── الخلية: متبقي + لون ──────────────────────────────────────
  Widget _dataCell(CompanyBill? bill) {
    Color bg;
    Color fg;
    String text;
    if (bill == null) {
      bg = const Color(0xFFF5F5F5);
      fg = AppColors.muted;
      text = '—';
    } else if (bill.isDeferred) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      text = '⏸ ${bill.remaining.toStringAsFixed(0)}';
    } else if (bill.isPaid) {
      bg = AppColors.greenLight;
      fg = const Color(0xFF00695c);
      text = '✅';
    } else {
      bg = AppColors.redLight;
      fg = AppColors.red2;
      text = bill.remaining.toStringAsFixed(0);
    }
    return Container(
      width: _cellW,
      height: 44,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.cairo(
              fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _nameCell(Group g) => Container(
        width: _nameW,
        height: 44,
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(g.phone,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (g.ownerName != null && g.ownerName!.isNotEmpty)
              Text(g.ownerName!,
                  style: GoogleFonts.cairo(fontSize: 9, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _headerCell(String text, double w) => Container(
        width: w,
        height: 38,
        margin: const EdgeInsets.all(1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.blue2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: GoogleFonts.cairo(
                fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
      );

  Widget _chip(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: GoogleFonts.cairo(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _legend(Color bg, Color fg, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
        ],
      );

  // "2026-05" → "٥/٢٦"  (شهر/سنة مختصر)
  String _fmtMonth(String m) {
    final parts = m.split('-');
    if (parts.length != 2) return m;
    final yy = parts[0].length >= 2 ? parts[0].substring(2) : parts[0];
    final mm = int.tryParse(parts[1]) ?? 0;
    return 'ش$mm/$yy';
  }
}
