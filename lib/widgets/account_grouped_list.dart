// lib/widgets/account_grouped_list.dart
//
// 👛 عرض الخطوط «بالحساب» — الخطوط اللي بتنزل في فاتورة واحدة من الشركة
// بتبان تحت هيدر واحد بمجموعها، بدل ما تكون متفرّقة في القايمة.
//
// ليه: لما تراجع مع الشركة، هي بتشوف الحساب مش الخط. فلو الحساب فيه ٣ خطوط
// وأرضي وهوم 4G، لازم تشوفهم كلهم مع بعض في مكان واحد — تعرف مجموع الشهر
// ومين دوره ينزل، ولو الشركة قالت «الزيادة بسبب الأرضي» تلاقي رقمه قدامك.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/breakpoints.dart';
import 'group_card.dart';

class AccountGroupedList extends StatelessWidget {
  const AccountGroupedList({
    super.key,
    required this.prov,
    required this.groups,
    this.initiallyExpanded = false,
  });

  final AppProvider prov;

  /// الخطوط بعد الفلترة والترتيب — بنعيد تجميعها بالحساب من غير ما نضيف
  /// ولا نشيل خط، فأي فلتر شغّال فوق بيفضل شغّال.
  final List<Group> groups;

  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final db = prov.db;
    final shown = {for (final g in groups) g.id};

    // كل خط بيروح لحسابه: الخط الرئيسي بتاعه لو مضموم، وإلا هو نفسه حساب.
    final byAccount = <String, List<Group>>{};
    for (final g in groups) {
      final head = prov.accountHeadOf(g.id) ?? g;
      byAccount.putIfAbsent(head.id, () => []).add(g);
    }

    // ترتيب الحسابات = ترتيب أول خط بيظهر منها في القايمة الأصلية، فالترتيب
    // اللي انت مختاره فوق (يدوي/بالاسم/بالمديونية) بيفضل محسوس.
    final order = <String>[];
    for (final g in groups) {
      final head = prov.accountHeadOf(g.id) ?? g;
      if (!order.contains(head.id)) order.add(head.id);
    }

    Widget? blockAt(int i) {
      final headId = order[i];
      final head = db.groups.where((g) => g.id == headId).firstOrNull;
      final lines = byAccount[headId] ?? const <Group>[];
      if (head == null || lines.isEmpty) return null;
      return _AccountBlock(
        prov: prov,
        head: head,
        lines: lines,
        // عدد خطوط الحساب الحقيقي — عشان لو الفلتر مخبّي بعضهم تعرف
        hiddenCount: prov
            .accountLines(headId)
            .where((l) => !shown.contains(l.id))
            .length,
        initiallyExpanded: initiallyExpanded,
      );
    }

    // 📐 على التاب والكمبيوتر: الحسابات جنب بعض في عمودين/تلاتة زي باقي
    // القايمة. كل عمود ListView لوحده عشان اللي برّه الشاشة مايتبنيش أصلاً
    // والتمرير يفضل خفيف مهما زاد عدد الحسابات.
    final cols = context.groupCols;
    if (cols > 1 && order.length > 1) {
      final buckets = List.generate(cols, (_) => <int>[]);
      for (var i = 0; i < order.length; i++) {
        buckets[i % cols].add(i);
      }
      final g = context.gutter;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: g / 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < cols; c++) ...[
              if (c > 0) SizedBox(width: g / 2),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 90),
                  itemCount: buckets[c].length,
                  itemBuilder: (_, i) =>
                      blockAt(buckets[c][i]) ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
      itemCount: order.length,
      itemBuilder: (_, i) => blockAt(i) ?? const SizedBox.shrink(),
    );
  }
}

class _AccountBlock extends StatefulWidget {
  const _AccountBlock({
    required this.prov,
    required this.head,
    required this.lines,
    required this.hiddenCount,
    required this.initiallyExpanded,
  });

  final AppProvider prov;
  final Group head;
  final List<Group> lines;
  final int hiddenCount;
  final bool initiallyExpanded;

  @override
  State<_AccountBlock> createState() => _AccountBlockState();
}

class _AccountBlockState extends State<_AccountBlock> {
  /// الأرقام الجانبية مقفولة افتراضياً — بتزحم الهيدر وانت مش محتاجها
  /// غير وقت المراجعة مع الشركة.
  bool _showSides = false;

  static String _monthKeyNow() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final head = widget.head;
    final lines = widget.lines;
    final hiddenCount = widget.hiddenCount;
    final initiallyExpanded = widget.initiallyExpanded;

    final all = prov.accountLines(head.id);
    final single = all.length == 1;
    final month = _monthKeyNow();
    final expected = prov.expectedAccountAmount(head.id, month);
    final anyBimonthly = all.any((l) => l.isBimonthly);
    final wide = context.isWide;
    final sides = prov.sideNumbersOf(head.id);

    // خط واحد من غير أي ضم ولا أرقام مربوطة → مفيش داعي لهيدر
    if (single && sides.isEmpty) {
      return GroupCard(group: head, initiallyExpanded: initiallyExpanded);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blueMid.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // ── هيدر الحساب ──────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(wide ? 14 : 11, 10, wide ? 14 : 11, 9),
          decoration: BoxDecoration(gradient: AppColors.groupHeadGradient),
          child: Column(children: [
            Row(children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: wide ? 20 : 17, color: AppColors.blue2),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      head.groupInvoiceName?.trim().isNotEmpty == true
                          ? head.groupInvoiceName!
                          : 'حساب ${head.phone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontSize: wide ? 15 : 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text),
                    ),
                    Text(
                      '${all.length} خط في فاتورة واحدة'
                      '${hiddenCount > 0 ? ' • $hiddenCount مخبّي بالفلتر' : ''}',
                      style: GoogleFonts.cairo(
                          fontSize: wide ? 11 : 9.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (anyBimonthly)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      expected > 0 ? expected.toStringAsFixed(0) : '٠',
                      style: GoogleFonts.cairo(
                          fontSize: wide ? 19 : 16,
                          fontWeight: FontWeight.w900,
                          color: expected > 0
                              ? AppColors.blue2
                              : AppColors.muted),
                    ),
                    Text(
                      expected > 0 ? 'فاتورة الشهر ده' : 'مفيش فاتورة الشهر ده',
                      style: GoogleFonts.cairo(
                          fontSize: wide ? 10 : 8.5,
                          fontWeight: FontWeight.w800,
                          color: expected > 0
                              ? AppColors.blue3
                              : AppColors.muted),
                    ),
                  ],
                ),
            ]),

            // ── ☎️ الأرضي والهوم 4G — مقفولين لحد ما تطلبهم ─────
            if (sides.isNotEmpty) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => setState(() => _showSides = !_showSides),
                borderRadius: BorderRadius.circular(7),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        _showSides
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 13,
                        color: AppColors.muted),
                    const SizedBox(width: 5),
                    Text(
                      _showSides
                          ? 'اخفي الأرضي والهوم 4G'
                          : 'ورّيني الأرضي والهوم 4G (${sides.length})',
                      style: GoogleFonts.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted),
                    ),
                  ]),
                ),
              ),
              if (_showSides)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      for (final m in sides)
                        Text(
                          '${m.type == 'landline' ? 'أرضي' : 'هوم 4G'} ${m.phone}'
                          '${m.name.isNotEmpty ? ' — ${m.name}' : ''}',
                          style: GoogleFonts.cairo(
                              fontSize: 9.5,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
            ],
          ]),
        ),

        // ── كروت خطوط الحساب ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
          child: Column(children: [
            for (final l in lines)
              GroupCard(group: l, initiallyExpanded: initiallyExpanded),
          ]),
        ),
      ]),
    );
  }
}
