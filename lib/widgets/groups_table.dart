// lib/widgets/groups_table.dart
//
// 📊 وضع الجدول — كل خط في سطر واحد بدل كارت كامل.
//
// الكارت بياخد ~200 بكسل طول، فالشاشة بتشيل ٣ أو ٤ خطوط. السطر هنا بياخد
// ~40 بكسل، يعني نفس الشاشة بتشيل **١٥ لـ ٢٠ خط** — ده اللي المالك طلبه
// («الشاشة تشيل الضعف تلات مرات»).
//
// بيشتغل على أي مقاس، بس الفايدة الحقيقية على التاب والكمبيوتر.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/export_service.dart';
import 'group_card.dart' show cycleShortLabel;

/// أعمدة الجدول — المفتاح بيتخزن عشان الترتيب
enum _Col { phone, provider, cycle, clients, bill, debt, profit, assignee }

const _providerShort = {
  'vodafone': 'VODA',
  'etisalat': 'ETIS',
  'orange': 'ORNG',
  'we': 'WE',
};

const _providerColors = {
  'vodafone': Color(0xFFe53935),
  'etisalat': Color(0xFF43a047),
  'orange': Color(0xFFfb8c00),
  'we': Color(0xFF5e35b1),
};

class GroupsTable extends StatefulWidget {
  final List<Group> groups;
  final void Function(Group) onOpen;
  const GroupsTable({super.key, required this.groups, required this.onOpen});

  @override
  State<GroupsTable> createState() => _GroupsTableState();
}

class _GroupsTableState extends State<GroupsTable> {
  _Col _sortBy = _Col.phone;
  bool _asc = true;

  void _sort(_Col c) => setState(() {
        if (_sortBy == c) {
          _asc = !_asc;
        } else {
          _sortBy = c;
          _asc = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;

    // القيم اللي بنرتّب بيها — بنحسبها مرة واحدة بدل ما نحسبها جوّه المقارنة
    // (الترتيب بينادي المقارنة آلاف المرات، والحسابات دي بتلف على العملاء).
    final rows = [
      for (final g in widget.groups)
        (
          g: g,
          members: db.membersOf(g.id).length,
          debt: db.groupDebt(g.id),
          profit: db.groupProfit(g.id),
          bill: g.billDebt > 0 ? g.billDebt : g.lastBillAmount,
          assignee: prov.assigneeOf(g.id) ?? '',
        )
    ];

    int cmp(dynamic a, dynamic b) =>
        a is String ? a.compareTo(b as String) : (a as num).compareTo(b as num);

    dynamic key(({Group g, int members, double debt, double profit,
            double bill, String assignee}) r) =>
        switch (_sortBy) {
          _Col.phone => r.g.phone,
          _Col.provider => _providerShort[r.g.provider] ?? 'ZZ',
          _Col.cycle => cycleShortLabel(r.g),
          _Col.clients => r.members,
          _Col.bill => r.bill,
          _Col.debt => r.debt,
          _Col.profit => r.profit,
          _Col.assignee => r.assignee,
        };

    // ترتيب ثابت: لو القيمتين متساويين نرجع لترتيب الرقم عشان الصفوف
    // ما تنطّش من مكانها كل ما الشاشة تتبني (sort في Dart مش stable).
    final sorted = [...rows]..sort((a, b) {
        final c = cmp(key(a), key(b));
        return c != 0 ? (_asc ? c : -c) : a.g.phone.compareTo(b.g.phone);
      });

    final totalDebt = rows.fold<double>(0, (s, r) => s + r.debt);
    final totalProfit = rows.fold<double>(0, (s, r) => s + r.profit);
    final totalBill = rows.fold<double>(0, (s, r) => s + r.bill);
    final totalClients = rows.fold<int>(0, (s, r) => s + r.members);

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 760,
            child: Column(children: [
              _header(),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: sorted.length,
                  itemExtent: 38,
                  itemBuilder: (_, i) => _row(sorted[i], i),
                ),
              ),
            ]),
          ),
        ),
      ),
      // ─── صف المجاميع ───────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          border: Border(top: BorderSide(color: AppColors.blueMid, width: 1.5)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _total('الخطوط', '${rows.length}', AppColors.blue2),
            _total('العملاء', '$totalClients', AppColors.blue2),
            _total('الفواتير', totalBill.toStringAsFixed(0), AppColors.purple),
            _total('المديونية', totalDebt.toStringAsFixed(0), AppColors.red2),
            _total('الربح', totalProfit.toStringAsFixed(0),
                const Color(0xFF2E7D32)),
            // 📤 تصدير اللي ظاهر بالظبط (بالفلاتر والترتيب الحالي)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 12),
              child: Tooltip(
                message: 'صدّر اللي ظاهر لإكسل',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ExportService.exportGroupsTable(
                      context, prov, [for (final r in sorted) r.g]),
                  icon: Icon(Icons.download,
                      size: 20, color: AppColors.blue2),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _total(String label, String value, Color c) => Padding(
        padding: const EdgeInsets.only(left: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: 14, fontWeight: FontWeight.w900, color: c)),
        ]),
      );

  static const _widths = {
    _Col.phone: 120.0,
    _Col.provider: 62.0,
    _Col.cycle: 52.0,
    _Col.clients: 52.0,
    _Col.bill: 88.0,
    _Col.debt: 88.0,
    _Col.profit: 88.0,
    _Col.assignee: 100.0,
  };

  static const _labels = {
    _Col.phone: 'الرقم',
    _Col.provider: 'الشركة',
    _Col.cycle: 'السيكل',
    _Col.clients: 'عملاء',
    _Col.bill: 'فاتورة',
    _Col.debt: 'مديونية',
    _Col.profit: 'ربح',
    _Col.assignee: 'المتابع',
  };

  Widget _header() => Container(
        height: 36,
        color: AppColors.surfaceAlt,
        child: Row(
          children: [
            for (final c in _Col.values)
              SizedBox(
                width: _widths[c],
                child: InkWell(
                  onTap: () => _sort(c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(children: [
                      Flexible(
                        child: Text(_labels[c]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _sortBy == c
                                    ? AppColors.blue2
                                    : AppColors.muted)),
                      ),
                      if (_sortBy == c)
                        Icon(_asc ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            size: 16, color: AppColors.blue2),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _row(
      ({Group g, int members, double debt, double profit, double bill,
              String assignee})
          r,
      int i) {
    final g = r.g;
    final pc = _providerColors[g.provider] ?? AppColors.muted;
    // تلوين الصف حسب الحالة — أحمر خفيف لو عليه مديونية
    final bg = r.debt > 0
        ? AppColors.redLight.withValues(alpha: 0.55)
        : (i.isEven ? AppColors.surface : AppColors.surfaceAlt);

    Widget cell(_Col c, Widget child) =>
        SizedBox(width: _widths[c], child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6), child: child));

    Widget txt(String s,
            {Color? color, double size = 12, FontWeight w = FontWeight.w700}) =>
        Text(s,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
                fontSize: size, fontWeight: w, color: color ?? AppColors.text));

    return InkWell(
      onTap: () => widget.onOpen(g),
      child: Container(
        color: bg,
        child: Row(children: [
          cell(
              _Col.phone,
              Text(g.phone,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue2))),
          cell(
              _Col.provider,
              g.provider == null
                  ? txt('—', color: AppColors.muted)
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: pc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(_providerShort[g.provider] ?? '',
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: pc)),
                    )),
          cell(_Col.cycle, txt(cycleShortLabel(g), size: 11)),
          cell(_Col.clients, txt('${r.members}', w: FontWeight.w900)),
          cell(
              _Col.bill,
              txt(r.bill == 0 ? '—' : r.bill.toStringAsFixed(0),
                  color: r.bill == 0 ? AppColors.muted : AppColors.purple,
                  w: FontWeight.w900)),
          cell(
              _Col.debt,
              txt(r.debt == 0 ? '—' : r.debt.toStringAsFixed(0),
                  color: r.debt == 0 ? AppColors.muted : AppColors.red2,
                  w: FontWeight.w900)),
          cell(
              _Col.profit,
              txt(r.profit.toStringAsFixed(0),
                  color: const Color(0xFF2E7D32), w: FontWeight.w900)),
          cell(
              _Col.assignee,
              txt(r.assignee.isEmpty ? '—' : r.assignee,
                  size: 10,
                  color: r.assignee.isEmpty ? AppColors.muted : AppColors.purple)),
        ]),
      ),
    );
  }
}
