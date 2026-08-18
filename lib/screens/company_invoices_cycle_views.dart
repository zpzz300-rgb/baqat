// lib/screens/company_invoices_cycle_views.dart
//
// 🔁 عروض دورة «شهر وشهر» — خمس طرق تبصّ بيها على نفس المعلومة.
//
// الفكرة كلها حاجتين بس لكل خط: **رقم** (الفاتورة بتنزل بكام) و**علامة**
// (آخر فاتورة نزلت شهر كام). منهم البرنامج يعرف أي شهر — ماضي أو مستقبل —
// الخط ده دوره ولا لأ، من غير ما تقعد تكتب كل شهر.
//
// الفواتير الثابتة (اللي بتنزل بنفس الرقم كل شهر) مالهاش دعوة بالعروض دي —
// انت عارفها وحافظها. العروض دي للخطوط اللي بتنزل شهر وشهر عشان لو الشركة
// نزّلت فاتورتين ورا بعض تمسكها بصّة عين.
part of 'company_invoices_screen.dart';

/// طرق العرض الخمسة.
enum _CycleView {
  cards, // 🗂 كروت — التفاصيل الكاملة زي ما كانت
  accounts, // 👛 حسابات — كل كام خط تحت هيدر واحد بالمجموع
  grid, // 🗓 جدول — صفوف خطوط × أعمدة شهور، مربع ومربع فاضي
  bars, // 📊 أعمدة — سجل كل خط في سطر واحد
  month, // ✅ الشهر ده — مين عليه فاتورة ومين ببلاش، وخلاص
}

extension _CycleViewX on _CycleView {
  String get label => switch (this) {
        _CycleView.cards => 'كروت',
        _CycleView.accounts => 'حسابات',
        _CycleView.grid => 'جدول',
        _CycleView.bars => 'أعمدة',
        _CycleView.month => 'الشهر ده',
      };

  IconData get icon => switch (this) {
        _CycleView.cards => Icons.view_agenda_outlined,
        _CycleView.accounts => Icons.account_balance_wallet_outlined,
        _CycleView.grid => Icons.grid_on,
        _CycleView.bars => Icons.bar_chart,
        _CycleView.month => Icons.checklist_rtl,
      };

  /// شرح بالعامية تحت الشريط — عشان تعرف انت بتبصّ على إيه.
  String get hint => switch (this) {
        _CycleView.cards => 'كل فاتورة في كارت لوحدها بكل تفاصيلها',
        _CycleView.accounts =>
          'الخطوط اللي مع بعض في حساب واحد تحت هيدر واحد بمجموعهم',
        _CycleView.grid =>
          'مربع فيه رقم = فاتورة نازلة، مربع فاضي = مفيش. الغلط بيبان لوحده',
        _CycleView.bars => 'سطر لكل خط: عمود = نزلت، فراغ = ما نزلتش',
        _CycleView.month => 'الشهر ده مين عليه فاتورة ومين ببلاش — قايمة وخلاص',
      };
}

/// حالة الخانة في الجدول والأعمدة.
enum _CellState {
  free, // ⬜ مش دوره ومفيش فاتورة — تمام
  billed, // ✅ دوره ونزلت — تمام
  missing, // ❗ دوره وما نزلتش
  unexpected, // ⚠️ مش دوره ونزلت — دي الغلطة اللي بتخاف منها
  unknown, // ❔ الخط ما اتعلّمش عليه لسه
}

extension _CellStateX on _CellState {
  Color get fg => switch (this) {
        _CellState.free => AppColors.muted,
        _CellState.billed => AppColors.green2,
        _CellState.missing => AppColors.orange,
        _CellState.unexpected => AppColors.red2,
        _CellState.unknown => AppColors.muted,
      };

  Color get bg => switch (this) {
        _CellState.free => AppColors.surfaceAlt,
        _CellState.billed => AppColors.greenLight,
        _CellState.missing => AppColors.orangeLight,
        _CellState.unexpected => AppColors.redLight,
        _CellState.unknown => AppColors.surfaceAlt,
      };

  String get mark => switch (this) {
        _CellState.free => '',
        _CellState.billed => '✓',
        _CellState.missing => '!',
        _CellState.unexpected => '⚠',
        _CellState.unknown => '؟',
      };

  String get say => switch (this) {
        _CellState.free => 'مفيش فاتورة — وده صح',
        _CellState.billed => 'نزلت زي المتوقع',
        _CellState.missing => 'المفروض تنزل وما نزلتش',
        _CellState.unexpected => 'نزلت وهي مش المفروض تنزل — راجع الشركة',
        _CellState.unknown => 'الخط ده لسه ما اتعلّمش عليه',
      };
}

// ══════════════════════════════════════════════════════════════════════════
// أدوات مشتركة بين العروض
// ══════════════════════════════════════════════════════════════════════════

class _Cycle {
  const _Cycle._();

  /// نافذة الشهور المعروضة: [count] شهر بينتهوا عند [lastMonth].
  static List<String> months(String lastMonth, int count) {
    final p = lastMonth.split('-');
    final y = int.tryParse(p[0]) ?? DateTime.now().year;
    final m = int.tryParse(p.length > 1 ? p[1] : '1') ?? 1;
    return [
      for (var i = count - 1; i >= 0; i--) _monthKey(DateTime(y, m - i)),
    ];
  }

  /// اسم الشهر قصير للأعمدة — «أغسطس» من غير السنة.
  static String shortLabel(String key) => _monthLabel(key).split(' ').first;

  /// الشهر بعد [month] بـ [n] شهر (بالسالب يرجّع ورا).
  static String addMonths(String month, int n) {
    final p = month.split('-');
    final y = int.tryParse(p[0]) ?? DateTime.now().year;
    final m = int.tryParse(p.length > 1 ? p[1] : '1') ?? 1;
    return _monthKey(DateTime(y, m + n));
  }

  /// الحسابات المعروضة: كل خط «شهر وشهر» مش مضموم على غيره = حساب.
  /// المضمومين بيتعرضوا جوّه حسابهم، مش لوحدهم.
  static List<Group> accountHeads(AppDB db,
      {String? provFilter, String search = ''}) {
    final terms = searchTerms(search);
    return db.groups.where((g) {
      final pid = g.parentGroupId;
      if (pid != null && pid.isNotEmpty) return false;
      final lines = [g, ...db.groups.where((x) => x.parentGroupId == g.id)];
      // الحساب يهمّنا لو فيه خط واحد على الأقل «شهر وشهر»
      if (!lines.any((l) => l.isBimonthly)) return false;
      if (provFilter != null &&
          provFilter != 'all' &&
          g.provider != provFilter) {
        return false;
      }
      if (terms.isNotEmpty) {
        final hay = [
          for (final l in lines) ...[
            l.phone,
            l.ownerName ?? '',
            l.groupInvoiceName ?? '',
          ]
        ];
        if (searchHitsOf(terms, hay) == null) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.phone.compareTo(b.phone));
  }

  /// فاتورة الحساب المسجّلة في الشهر ده (بتتسجّل على الخط الرئيسي).
  static CompanyBill? billOf(AppDB db, String headGid, String month) {
    for (final b in db.companyBills) {
      if (b.groupId == headGid && b.month == month && b.actualAmount > 0) {
        return b;
      }
    }
    return null;
  }

  /// حالة خانة الحساب في شهر: المتوقع مقابل اللي نزل فعلاً.
  static _CellState stateOf(
      AppProvider prov, AppDB db, Group head, String month) {
    final lines = prov.accountLines(head.id);
    // لو ولا خط في الحساب متعلّم عليه ومفيش نظام شقّين → «مش عارفين»
    final anyKnown = lines.any((l) => l.isDueIn(month) != null) ||
        lines.any((l) => prov.accountOfGroup(l.id) != null);
    final expected = prov.expectedAccountAmount(head.id, month);
    final bill = billOf(db, head.id, month);
    if (!anyKnown && bill == null) return _CellState.unknown;
    if (expected > 0) {
      return bill != null ? _CellState.billed : _CellState.missing;
    }
    return bill != null ? _CellState.unexpected : _CellState.free;
  }

  static String sideLabel(Member m) => m.type == 'landline' ? 'أرضي' : 'هوم 4G';

  /// 📋 الجدول كنص مفصول بـ Tab — تلزقه في إكسل فيتوزّع على الخانات لوحده.
  ///
  /// اخترنا النسخ للحافظة بدل تصدير ملف عن قصد: الملف بيتحفظ في مكان
  /// وبتدوّر عليه وتفتحه؛ اللزق بيوصل الجدول لإكسل في تلات ثواني وانت
  /// واقف قدام الشركة.
  ///
  /// المبالغ بتتكتب أرقام صافية (من غير «ج») عشان إكسل يعرف يجمعها.
  static String gridAsTsv(
    AppProvider prov,
    List<Group> heads,
    List<String> months,
  ) {
    final b = StringBuffer();
    b.write('الحساب\tصاحب الخط');
    for (final m in months) {
      b.write('\t${shortLabel(m)}');
    }
    b.writeln();
    for (final r in gridRows(prov, heads, months)) {
      b.writeln([r.name, r.owner, ...r.cells].join('\t'));
    }
    return b.toString();
  }

  /// صفوف الجدول كنصوص — مصدر واحد للنسخ وللطباعة.
  ///
  /// مهم إنهم يطلعوا من نفس المكان: لو الطباعة حسبت الأرقام لوحدها، ممكن
  /// تطبع ورقة أرقامها مختلفة عن اللي على الشاشة — وتروح بيها للشركة.
  static List<({String name, String owner, List<String> cells})> gridRows(
    AppProvider prov,
    List<Group> heads,
    List<String> months,
  ) {
    final db = prov.db;
    return [
      for (final h in heads)
        (
          name: h.phone,
          owner: h.ownerName ?? '',
          cells: [
            for (final m in months) _cellText(prov, db, h, m),
          ],
        ),
    ];
  }

  static String _cellText(AppProvider prov, AppDB db, Group h, String m) {
    final bill = billOf(db, h.id, m);
    final expected = prov.expectedAccountAmount(h.id, m);
    // اللي نزل فعلاً أهم من المتوقع — ده اللي بتراجع عليه.
    // مفيش فاتورة ومفيش متوقع = خانة فاضية، مش صفر: الصفر رقم بيتجمع
    // في إكسل، والفاضي بيقول «مافيش» بجد.
    final v = bill?.actualAmount ?? (expected > 0 ? expected : null);
    return v == null ? '' : v.toStringAsFixed(0);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🎚 شريط اختيار طريقة العرض
// ══════════════════════════════════════════════════════════════════════════

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.value, required this.onChanged});

  final _CycleView value;
  final ValueChanged<_CycleView> onChanged;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Row(
          children: [
            for (final v in _CycleView.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: EdgeInsets.symmetric(vertical: wide ? 10 : 7),
                    decoration: BoxDecoration(
                      color: v == value ? AppColors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(children: [
                      Icon(v.icon,
                          size: wide ? 20 : 16,
                          color: v == value
                              ? AppColors.onAccent
                              : AppColors.muted),
                      const SizedBox(height: 2),
                      Text(
                        v.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: wide ? 12 : 9.5,
                          fontWeight: FontWeight.w800,
                          color:
                              v == value ? AppColors.onAccent : AppColors.muted,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 2),
          child: Text(
            value.hint,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                fontSize: wide ? 11 : 9.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 👛 عرض الحسابات — كل كام خط تحت هيدر واحد
// ══════════════════════════════════════════════════════════════════════════

class _AccountsView extends StatelessWidget {
  const _AccountsView({
    required this.prov,
    required this.month,
    required this.provFilter,
    required this.search,
  });

  final AppProvider prov;
  final String month;
  final String provFilter;
  final String search;

  @override
  Widget build(BuildContext context) {
    final db = prov.db;
    final heads =
        _Cycle.accountHeads(db, provFilter: provFilter, search: search);
    if (heads.isEmpty) return const _CycleEmpty();

    return _CycleColumns(
      children: [
        for (final h in heads)
          _AccountHeaderCard(prov: prov, head: h, month: month),
      ],
    );
  }
}

/// 📐 على التاب والكمبيوتر بنوزّع الكروت على عمودين/تلاتة بالتبادل بدل
/// عمود واحد طويل. الشاشة العريضة الهدف منها **بيانات أكتر** في نفس
/// النظرة، مش كارت مفرود على عرض الشاشة كله وعينك بتلف عليه.
class _CycleColumns extends StatelessWidget {
  const _CycleColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cols = context.listCols;
    if (cols <= 1 || children.length < 2) {
      return Column(children: children);
    }
    final buckets = List.generate(cols, (_) => <Widget>[]);
    for (var i = 0; i < children.length; i++) {
      buckets[i % cols].add(children[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < cols; c++) ...[
          if (c > 0) const SizedBox(width: 10),
          Expanded(child: Column(children: buckets[c])),
        ],
      ],
    );
  }
}

/// 🧾 هيدر الحساب الواحد: المجموع المتوقع الشهر ده، الخطوط اللي دورها،
/// وأرقام الأرضي والهوم 4G **مخفية** لحد ما تدوس على زرار الإظهار.
class _AccountHeaderCard extends StatefulWidget {
  const _AccountHeaderCard({
    required this.prov,
    required this.head,
    required this.month,
  });

  final AppProvider prov;
  final Group head;
  final String month;

  @override
  State<_AccountHeaderCard> createState() => _AccountHeaderCardState();
}

class _AccountHeaderCardState extends State<_AccountHeaderCard> {
  /// الأرقام الجانبية مقفولة افتراضياً عشان ماتزحّمش الهيدر — الحساب ممكن
  /// يكون فيه ٢ أو ٣ خطوط ٤G وكل واحد وراه أرضي وهوم 4G.
  bool _showSides = false;

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final head = widget.head;
    final month = widget.month;
    final db = prov.db;
    final lines = prov.accountLines(head.id);
    final due = prov.dueLinesOfAccount(head.id, month);
    final expected = prov.expectedAccountAmount(head.id, month);
    final bill = _Cycle.billOf(db, head.id, month);
    final state = _Cycle.stateOf(prov, db, head, month);
    final sides = prov.sideNumbersOf(head.id);
    final wide = context.isWide;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: state.fg.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Column(children: [
        // ── هيدر الحساب ──────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(wide ? 14 : 11),
          decoration: BoxDecoration(
            color: state.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    head.groupInvoiceName?.trim().isNotEmpty == true
                        ? head.groupInvoiceName!
                        : 'حساب ${head.phone}',
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 15 : 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text),
                  ),
                  Text(
                    '${lines.length} خط في الحساب • ${_monthLabel(month)}',
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 11.5 : 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            // 💰 الرقم الكبير: فاتورة الشهر ده كام — أو صفر بالعربي
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  expected <= 0 ? '٠' : expected.toStringAsFixed(0),
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 24 : 20,
                      fontWeight: FontWeight.w900,
                      color: state.fg),
                ),
                Text(
                  expected <= 0
                      ? 'مفيش فاتورة الشهر ده'
                      : 'المفروض تنزل • ${due.length} خط',
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 11 : 9.5,
                      fontWeight: FontWeight.w800,
                      color: state.fg),
                ),
              ],
            ),
          ]),
        ),

        // ── تنبيه الغلط ──────────────────────────────────────────
        if (state == _CellState.unexpected || state == _CellState.missing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: state.bg,
            child: Text(
              state == _CellState.unexpected
                  ? '⚠️ نزلت فاتورة ${bill!.actualAmount.toStringAsFixed(0)} ج '
                      'والشهر ده المفروض ببلاش — راجع الشركة'
                  : '❗ المفروض تنزل ${expected.toStringAsFixed(0)} ج وما نزلتش لسه',
              style: GoogleFonts.cairo(
                  fontSize: wide ? 12 : 10.5,
                  fontWeight: FontWeight.w800,
                  color: state.fg),
            ),
          ),

        // ── الخطوط جوّه الحساب ───────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 14 : 10, 8, wide ? 14 : 10, 4),
          child: Column(children: [
            for (final l in lines)
              _AccountLineRow(prov: prov, line: l, month: month, wide: wide),
            Row(children: [
              // 🌿 ضم الخطوط — علّم ✔ على اللي في نفس الفاتورة
              InkWell(
                onTap: () => _CycleSheets.linkLines(context, prov, head),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.account_tree_outlined,
                        size: 14, color: AppColors.blue),
                    const SizedBox(width: 5),
                    Text(
                      lines.length > 1
                          ? 'عدّل الخطوط (${lines.length})'
                          : '+ ضمّ خطوط',
                      style: GoogleFonts.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blue),
                    ),
                  ]),
                ),
              ),
              // 📌 تعليم دورة كل الخطوط مرة واحدة — بيبان لما يكون فيه
              // أكتر من خط شهر وشهر، لأن دي الحالة اللي بتوجع.
              if (lines.where((l) => l.isBimonthly).length > 1) ...[
                const SizedBox(width: 14),
                InkWell(
                  onTap: () =>
                      _CycleSheets.anchorAll(context, prov, head, month),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.repeat, size: 14, color: AppColors.green2),
                      const SizedBox(width: 5),
                      Text('ظبّط دورة الكل',
                          style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green2)),
                    ]),
                  ),
                ),
              ],
            ]),
          ]),
        ),

        // ── ☎️ الأرضي والهوم 4G — مقفولين، بيتفتحوا لما تطلبهم ──
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 14 : 10, 0, wide ? 14 : 10, 8),
          child: _SideNumbersStrip(
            prov: prov,
            head: head,
            sides: sides,
            open: _showSides,
            onToggle: () => setState(() => _showSides = !_showSides),
          ),
        ),

        // ── مطالبة مفتوحة على الشركة ─────────────────────────────
        if (bill != null && bill.hasOpenDispute)
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(wide ? 14 : 10, 0, wide ? 14 : 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🧾 لك عند الشركة ${bill.disputeAmount.toStringAsFixed(0)} ج'
              '${bill.disputeNote?.isNotEmpty == true ? ' — ${bill.disputeNote}' : ''}',
              style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.red2),
            ),
          ),
      ]),
    );
  }
}

/// ☎️ شريط الأرقام الجانبية (أرضي / هوم 4G) — مقفول افتراضياً.
///
/// الحساب ممكن يكون فيه ٢ أو ٣ خطوط ٤G وكل واحد وراه أرضي وهوم 4G، فلو
/// عرضناهم على طول الهيدر هيزحم ومايبقاش مقروء. فبيفضلوا مقفولين، وتفتحهم
/// وقت المراجعة مع الشركة بس.
class _SideNumbersStrip extends StatelessWidget {
  const _SideNumbersStrip({
    required this.prov,
    required this.head,
    required this.sides,
    required this.open,
    required this.onToggle,
  });

  final AppProvider prov;
  final Group head;
  final List<Member> sides;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // زرار الإظهار — سطر واحد رفيع، ما بياخدش مساحة وهو مقفول
      InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                open
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 13,
                color: AppColors.muted),
            const SizedBox(width: 5),
            Text(
              open
                  ? 'اخفي الأرضي والهوم 4G'
                  : (sides.isEmpty
                      ? 'اربط أرقام الأرضي والهوم 4G'
                      : 'ورّيني الأرضي والهوم 4G (${sides.length})'),
              style: GoogleFonts.cairo(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted),
            ),
          ]),
        ),
      ),
      if (open)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sides.isEmpty)
                Text('مفيش أرقام مربوطة بالحساب ده لسه',
                    style: GoogleFonts.cairo(
                        fontSize: 9.5, color: AppColors.muted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  children: [
                    for (final m in sides)
                      Text(
                        '${_Cycle.sideLabel(m)} ${m.phone}'
                        '${m.name.isNotEmpty ? ' — ${m.name}' : ''}',
                        style: GoogleFonts.cairo(
                            fontSize: 9.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _CycleSheets.pickSideNumbers(context, prov, head),
                child: Text(
                  sides.isEmpty ? '+ اختار الأرقام' : 'عدّل الأرقام',
                  style: GoogleFonts.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
    ]);
  }
}

/// سطر خط واحد جوّه الحساب: سعره، دوره الشهر ده ولا لأ، وزرار التعليم.
class _AccountLineRow extends StatelessWidget {
  const _AccountLineRow({
    required this.prov,
    required this.line,
    required this.month,
    required this.wide,
  });

  final AppProvider prov;
  final Group line;
  final String month;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final due = prov.isLineDueIn(line, month);
    final overridden = line.isOverriddenIn(month);
    final fixed = !line.isBimonthly;
    final color =
        fixed ? AppColors.blue : (due ? AppColors.green2 : AppColors.muted);

    return InkWell(
      onTap: () => _CycleSheets.openLine(context, prov, line, month),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.phone,
              style: GoogleFonts.cairo(
                  fontSize: wide ? 13 : 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text),
            ),
          ),
          if (overridden)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text('معدّل بإيدك',
                  style: GoogleFonts.cairo(
                      fontSize: 8.5,
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800)),
            ),
          Text(
            fixed
                ? 'ثابت ${line.fixedBillAmount.toStringAsFixed(0)}'
                : (due
                    ? 'عليه ${line.fixedBillAmount.toStringAsFixed(0)} ج'
                    : 'ببلاش الشهر ده'),
            style: GoogleFonts.cairo(
                fontSize: wide ? 12 : 10.5,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_left, size: 15, color: AppColors.muted),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🗓 عرض الجدول — صفوف خطوط × أعمدة شهور
// ══════════════════════════════════════════════════════════════════════════

/// مقياس نص بيتضرب في المقياس الموجود بدل ما يستبدله.
///
/// لازمته: البرنامج عنده مقياس خط خاص بيه (`bpTextScale`) والمستخدم عنده
/// مقياس من إعدادات الموبايل. لو حطينا `TextScaler.linear(z)` على طول،
/// الاتنين دول بيتلغوا — يعني اللي مكبّر الخط من إعدادات تليفونه عشان
/// نظره، أول ما يفتح الجدول يلاقيه رجع صغير. الضرب بيحافظ عليهم.
class _ZoomTextScaler extends TextScaler {
  const _ZoomTextScaler(this.inner, this.factor);

  final TextScaler inner;
  final double factor;

  @override
  double scale(double fontSize) => inner.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => inner.textScaleFactor * factor;
}

/// زرار تكبير/تصغير صغير. `onTap = null` يعني وصلنا الحد.
class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        color: AppColors.blue2,
        disabledColor: AppColors.border,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        visualDensity: VisualDensity.compact,
      );
}

class _GridView extends StatelessWidget {
  const _GridView({
    required this.prov,
    required this.month,
    required this.provFilter,
    required this.search,
    this.zoom = 1.0,
    this.onZoom,
    this.monthCount,
    this.onMonthCount,
  });

  /// 🗓 عدد الشهور المعروضة. null = يتحسب من مقاس الشاشة.
  ///
  /// ⚠️ عمداً مفيش «سحب لترتيب الأعمدة» هنا: الشهور ليها ترتيب طبيعي،
  /// ولو سحبت أغسطس قبل يوليو مابقاش ينفع تعرف الزمن ماشي ناحية فين —
  /// والجدول ده كله فايدته إنك تشوف الغلط في التتابع. اللي بيفيد فعلاً
  /// هو **كام شهر تشوف** ومن أنهي ناحية، ودول محفوظين.
  final int? monthCount;
  final ValueChanged<int>? onMonthCount;

  final AppProvider prov;
  final String month;
  final String provFilter;
  final String search;

  /// 🔍 معامل التكبير — بيضرب في عرض الخانات وارتفاع الصفوف والخط.
  final double zoom;
  final ValueChanged<double>? onZoom;

  @override
  Widget build(BuildContext context) {
    final db = prov.db;
    final heads =
        _Cycle.accountHeads(db, provFilter: provFilter, search: search);
    if (heads.isEmpty) return const _CycleEmpty();

    final wide = context.isWide;
    // 🗓 عدد الشهور المعروضة حسب المقاس — الشاشة الكبيرة تشيل سنة ونص
    // من تاريخ الفواتير في نظرة واحدة، والموبايل ٧ شهور عشان يفضل مقروء.
    // لو المستخدم اختار عدد، بنمشي عليه؛ وإلا بيتحسب من مقاس الشاشة.
    final autoCount = switch (context.bp) {
      Bp.phone => 7,
      Bp.phoneWide => 9,
      Bp.tablet => 13,
      Bp.desktop => 18,
    };
    final count = (monthCount ?? autoCount).clamp(4, 24);
    final months = _Cycle.months(_nextMonthOf(month), count);
    // 🔍 كل المقاسات بتتضرب في التكبير مع بعض — لو كبّرنا العرض بس
    // والارتفاع لأ، الخانات بتبقى مستطيلات مفلطحة والجدول يوحش.
    final z = zoom.clamp(0.7, 1.6);
    final nameW = (wide ? 160.0 : 112.0) * z;
    final cellW = (wide ? 74.0 : 58.0) * z;

    // 📌 ارتفاعات ثابتة لكل نوع صف — لازمة عشان عمود الأسماء (اللي بره
    // التمرير) وخانات الشهور (اللي جواه) يفضلوا متحاذيين سطر بسطر.
    final headH = (wide ? 36.0 : 32.0) * z;
    final accH = (wide ? 56.0 : 48.0) * z;
    final lineH = (wide ? 28.0 : 24.0) * z;

    // كل صفوف الجدول بالترتيب: حساب، وتحته خطوطه لو أكتر من واحد.
    final rows = <({Group group, bool isAccount, double height})>[];
    for (final h in heads) {
      rows.add((group: h, isAccount: true, height: accH));
      final lines = prov.accountLines(h.id);
      if (lines.length > 1) {
        for (final l in lines) {
          rows.add((group: l, isAccount: false, height: lineH));
        }
      }
    }

    final mq = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      // 🔍 التكبير بيلفّ الجدول كله — الخانات كبرت بالحساب فوق، والخطوط
      // بتكبر معاها من هنا. بدون ده الخانة تكبر والرقم جواها يفضل زي
      // ما هو وسط فراغ، وهو عكس المطلوب بالظبط.
      child: MediaQuery(
        data: mq.copyWith(
            textScaler: _ZoomTextScaler(mq.textScaler, z.toDouble())),
        child: Column(children: [
          Row(children: [
            Expanded(child: _CycleLegend(wide: wide)),
            // 🔍 تكبير/تصغير — بيتحفظ ويرجع زي ما سبته
            if (onZoom != null) ...[
              _ZoomBtn(
                icon: Icons.remove,
                // بنوقف عند الحد بدل ما نخلي الزرار يدوس من غير ما يحصل
                // حاجة — الزرار المطفي بيقول «وصلت الآخر» لوحده.
                onTap:
                    z <= 0.7 ? null : () => onZoom!((z - 0.15).clamp(0.7, 1.6)),
              ),
              Text('${(z * 100).round()}%',
                  style: GoogleFonts.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted)),
              _ZoomBtn(
                icon: Icons.add,
                onTap:
                    z >= 1.6 ? null : () => onZoom!((z + 0.15).clamp(0.7, 1.6)),
              ),
            ],
            // 🗓 كام شهر تشوف — بيتحفظ. الشهور مالهاش «ترتيب» تسحبه،
            // بس ليها **مدى** وده اللي بيفرق فعلاً.
            if (onMonthCount != null) ...[
              _ZoomBtn(
                icon: Icons.unfold_less,
                onTap: count <= 4 ? null : () => onMonthCount!(count - 3),
              ),
              Text('$count شهر',
                  style: GoogleFonts.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted)),
              _ZoomBtn(
                icon: Icons.unfold_more,
                onTap: count >= 24 ? null : () => onMonthCount!(count + 3),
              ),
            ],
            // 🖨 طباعة — نفس أرقام الشاشة بالظبط على ورق
            IconButton(
              tooltip: 'اطبع الجدول',
              onPressed: () => ExportService.printCycleGrid(
                context,
                months: [
                  for (final m in months.reversed) _Cycle.shortLabel(m),
                ],
                rows: _Cycle.gridRows(prov, heads, months.reversed.toList()),
                title: 'جدول الفواتير — ${_monthLabel(month)}',
              ),
              icon:
                  Icon(Icons.print_outlined, size: 16, color: AppColors.blue2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            // 📋 نسخ الجدول — أسرع طريقة توصّل الأرقام لإكسل
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(
                    text: _Cycle.gridAsTsv(
                        prov, heads, months.reversed.toList())));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'اتنسخ ${heads.length} حساب × ${months.length} شهر — '
                      'الزقهم في إكسل',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ));
              },
              icon: Icon(Icons.copy_all, size: 15, color: AppColors.blue2),
              label: Text('نسخ لإكسل',
                  style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue2)),
            ),
          ]),
          // 📌 عمود الحساب ثابت والشهور بتتزحلق تحته.
          //
          // من غير كده، وانت بتزحلق لشهر ٦ الاسم بيخرج من الشاشة وتفضل
          // بتبص على أرقام من غير ما تعرف هي بتاعة مين — والمشكلة بتكبر
          // كل ما الشهور تزيد (١٨ شهر على الكمبيوتر).
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── العمود الثابت: أسماء الحسابات ──────────────────
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: nameW,
                height: headH,
                color: AppColors.surfaceAlt,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: AlignmentDirectional.centerStart,
                child: Text('الحساب / الخط',
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 12 : 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.muted)),
              ),
              for (final r in rows)
                _GridNameCell(
                  prov: prov,
                  group: r.group,
                  isAccount: r.isAccount,
                  width: nameW,
                  height: r.height,
                  wide: wide,
                ),
            ]),
            // خط فاصل بيوضّح إن العمود ده ثابت
            Container(
                width: 1,
                color: AppColors.border,
                height: headH + rows.fold<double>(0, (s, r) => s + r.height)),
            // ── الجزء اللي بيتزحلق: الشهور ─────────────────────
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صف الشهور
                    Container(
                      height: headH,
                      color: AppColors.surfaceAlt,
                      child: Row(children: [
                        for (final m in months)
                          Container(
                            width: cellW,
                            alignment: Alignment.center,
                            color: m == month
                                ? AppColors.blueLight
                                : Colors.transparent,
                            child: Text(
                              _Cycle.shortLabel(m),
                              style: GoogleFonts.cairo(
                                  fontSize: wide ? 11 : 9,
                                  fontWeight: FontWeight.w900,
                                  color: m == month
                                      ? AppColors.blue2
                                      : AppColors.muted),
                            ),
                          ),
                      ]),
                    ),
                    // صفوف الخانات
                    for (final r in rows)
                      SizedBox(
                        height: r.height,
                        child: r.isAccount
                            ? Row(children: [
                                for (final m in months)
                                  _GridCell(
                                    prov: prov,
                                    db: db,
                                    head: r.group,
                                    month: m,
                                    width: cellW,
                                    isCurrent: m == month,
                                    wide: wide,
                                  ),
                              ])
                            : Row(children: [
                                for (final m in months)
                                  _GridLineCell(
                                    prov: prov,
                                    line: r.group,
                                    month: m,
                                    width: cellW,
                                    wide: wide,
                                  ),
                              ]),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// خانة الاسم في العمود الثابت — حساب أو خط تحته.
class _GridNameCell extends StatelessWidget {
  const _GridNameCell({
    required this.prov,
    required this.group,
    required this.isAccount,
    required this.width,
    required this.height,
    required this.wide,
  });

  final AppProvider prov;
  final Group group;
  final bool isAccount;
  final double width;
  final double height;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (!isAccount) {
      return Container(
        width: width,
        height: height,
        color: AppColors.surfaceAlt.withValues(alpha: 0.4),
        padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          '↳ ${group.phone}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
              fontSize: wide ? 11 : 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted),
        ),
      );
    }
    final count = prov.accountLines(group.id).length;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.groupInvoiceName?.trim().isNotEmpty == true
                ? group.groupInvoiceName!
                : group.phone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
                fontSize: wide ? 12.5 : 10.5,
                fontWeight: FontWeight.w900,
                color: AppColors.text),
          ),
          if (count > 1)
            Text('$count خطوط مع بعض',
                style:
                    GoogleFonts.cairo(fontSize: 8.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// خانة الحساب في شهر: المتوقع + لون الحالة + علامة الصح/الغلط.
class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.prov,
    required this.db,
    required this.head,
    required this.month,
    required this.width,
    required this.isCurrent,
    required this.wide,
  });

  final AppProvider prov;
  final AppDB db;
  final Group head;
  final String month;
  final double width;
  final bool isCurrent;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final state = _Cycle.stateOf(prov, db, head, month);
    final expected = prov.expectedAccountAmount(head.id, month);
    final bill = _Cycle.billOf(db, head.id, month);

    return GestureDetector(
      onTap: () => _CycleSheets.explainCell(
          context, prov, head, month, state, expected, bill),
      child: Container(
        width: width,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: state.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isCurrent ? AppColors.blue : state.fg.withValues(alpha: 0.25),
            width: isCurrent ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expected > 0 ? expected.toStringAsFixed(0) : '',
              style: GoogleFonts.cairo(
                  fontSize: wide ? 13 : 11,
                  fontWeight: FontWeight.w900,
                  color: state.fg),
            ),
            if (state.mark.isNotEmpty)
              Text(state.mark,
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 11 : 9,
                      fontWeight: FontWeight.w900,
                      color: state.fg)),
          ],
        ),
      ),
    );
  }
}

/// خانة خط واحد جوّه الحساب — بتوضّح مين اللي دوره في الشهر ده.
class _GridLineCell extends StatelessWidget {
  const _GridLineCell({
    required this.prov,
    required this.line,
    required this.month,
    required this.width,
    required this.wide,
  });

  final AppProvider prov;
  final Group line;
  final String month;
  final double width;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final due = prov.isLineDueIn(line, month);
    return GestureDetector(
      onTap: () => _CycleSheets.openLine(context, prov, line, month),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: due ? AppColors.blueLight : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          due ? line.fixedBillAmount.toStringAsFixed(0) : '—',
          style: GoogleFonts.cairo(
              fontSize: wide ? 10 : 8.5,
              fontWeight: FontWeight.w700,
              color: due ? AppColors.blue2 : AppColors.muted),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 📊 عرض الأعمدة — سجل كل حساب في سطر
// ══════════════════════════════════════════════════════════════════════════

class _BarsView extends StatelessWidget {
  const _BarsView({
    required this.prov,
    required this.month,
    required this.provFilter,
    required this.search,
  });

  final AppProvider prov;
  final String month;
  final String provFilter;
  final String search;

  @override
  Widget build(BuildContext context) {
    final db = prov.db;
    final heads =
        _Cycle.accountHeads(db, provFilter: provFilter, search: search);
    if (heads.isEmpty) return const _CycleEmpty();

    final wide = context.isWide;
    // الأعمدة أرفع من خانات الجدول، فبتشيل شهور أكتر في نفس العرض
    final months = _Cycle.months(
        _nextMonthOf(month),
        switch (context.bp) {
          Bp.phone => 10,
          Bp.phoneWide => 12,
          Bp.tablet => 16,
          Bp.desktop => 24,
        });

    // أعلى مبلغ في الشاشة كلها — عشان الأعمدة تتقارن ببعض بنفس المسطرة
    var peak = 0.0;
    for (final h in heads) {
      for (final m in months) {
        final v = prov.expectedAccountAmount(h.id, m);
        if (v > peak) peak = v;
      }
    }
    if (peak <= 0) peak = 1;

    return Column(children: [
      _CycleLegend(wide: wide),
      const SizedBox(height: 6),
      _CycleColumns(children: [
        for (final h in heads)
          _BarsRow(
            prov: prov,
            head: h,
            months: months,
            current: month,
            peak: peak,
            wide: wide,
          ),
      ]),
    ]);
  }
}

class _BarsRow extends StatelessWidget {
  const _BarsRow({
    required this.prov,
    required this.head,
    required this.months,
    required this.current,
    required this.peak,
    required this.wide,
  });

  final AppProvider prov;
  final Group head;
  final List<String> months;
  final String current;
  final double peak;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final db = prov.db;
    final barH = wide ? 54.0 : 40.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(wide ? 12 : 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                head.groupInvoiceName?.trim().isNotEmpty == true
                    ? head.groupInvoiceName!
                    : head.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: wide ? 13.5 : 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text),
              ),
            ),
            Text(
              '${prov.accountLines(head.id).length} خط',
              style: GoogleFonts.cairo(fontSize: 9.5, color: AppColors.muted),
            ),
          ]),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in months)
                Expanded(
                  child: _Bar(
                    prov: prov,
                    db: db,
                    head: head,
                    month: m,
                    peak: peak,
                    maxHeight: barH,
                    isCurrent: m == current,
                    wide: wide,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.prov,
    required this.db,
    required this.head,
    required this.month,
    required this.peak,
    required this.maxHeight,
    required this.isCurrent,
    required this.wide,
  });

  final AppProvider prov;
  final AppDB db;
  final Group head;
  final String month;
  final double peak;
  final double maxHeight;
  final bool isCurrent;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final expected = prov.expectedAccountAmount(head.id, month);
    final state = _Cycle.stateOf(prov, db, head, month);
    final bill = _Cycle.billOf(db, head.id, month);
    final h = expected <= 0
        ? 3.0
        : (expected / peak * maxHeight).clamp(6.0, maxHeight);

    return GestureDetector(
      onTap: () => _CycleSheets.explainCell(
          context, prov, head, month, state, expected, bill),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (expected > 0)
              Text(
                expected.toStringAsFixed(0),
                maxLines: 1,
                style: GoogleFonts.cairo(
                    fontSize: wide ? 9 : 7,
                    fontWeight: FontWeight.w800,
                    color: state.fg),
              ),
            const SizedBox(height: 2),
            Container(
              height: h,
              decoration: BoxDecoration(
                color: expected <= 0
                    ? AppColors.border
                    : state.fg.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _Cycle.shortLabel(month).characters.take(3).toString(),
              maxLines: 1,
              style: GoogleFonts.cairo(
                  fontSize: wide ? 9 : 7.5,
                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                  color: isCurrent ? AppColors.blue2 : AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ عرض «الشهر ده» — مين عليه فاتورة ومين ببلاش، وخلاص
// ══════════════════════════════════════════════════════════════════════════

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.prov,
    required this.month,
    required this.provFilter,
    required this.search,
  });

  final AppProvider prov;
  final String month;
  final String provFilter;
  final String search;

  @override
  Widget build(BuildContext context) {
    final db = prov.db;
    final heads =
        _Cycle.accountHeads(db, provFilter: provFilter, search: search);
    if (heads.isEmpty) return const _CycleEmpty();

    final wide = context.isWide;
    final due = <Group>[], free = <Group>[], wrong = <Group>[];
    for (final h in heads) {
      final st = _Cycle.stateOf(prov, db, h, month);
      if (st == _CellState.unexpected) {
        wrong.add(h);
      } else if (prov.expectedAccountAmount(h.id, month) > 0) {
        due.add(h);
      } else {
        free.add(h);
      }
    }
    final dueTotal = due.fold<double>(
        0, (s, h) => s + prov.expectedAccountAmount(h.id, month));

    return Column(children: [
      // الرقم الكبير: إجمالي الشهر
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(wide ? 18 : 14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blueMid),
        ),
        child: Column(children: [
          Text('إجمالي فواتير ${_monthLabel(month)}',
              style: GoogleFonts.cairo(
                  fontSize: wide ? 13 : 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue2)),
          Text('${dueTotal.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: wide ? 32 : 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue2)),
          Text('على ${due.length} حساب • ${free.length} حساب ببلاش الشهر ده',
              style: GoogleFonts.cairo(
                  fontSize: wide ? 11.5 : 10, color: AppColors.blue3)),
        ]),
      ),

      // ⚠️ الغلط بيفضل بعرض الشاشة كلها حتى على التاب — ده اللي بتدوّر
      // عليه، ماينفعش يتحشر في عمود جنبي.
      if (wrong.isNotEmpty)
        _MonthGroupList(
          prov: prov,
          title: '⚠️ نزلت وهي مش المفروض تنزل',
          subtitle: 'دي الغلطة اللي بتدوّر عليها — راجع الشركة',
          heads: wrong,
          month: month,
          color: AppColors.red2,
          bg: AppColors.redLight,
          wide: wide,
        ),
      // «عليها فاتورة» و«ببلاش» جنب بعض على التاب — المقارنة بينهم
      // هي المقصودة، فلما يبقوا في نظرة واحدة الفرق بيبان أسرع.
      _CycleColumns(children: [
        if (due.isNotEmpty)
          _MonthGroupList(
            prov: prov,
            title: '💰 عليها فاتورة الشهر ده',
            subtitle: 'دول اللي دورهم ينزلوا',
            heads: due,
            month: month,
            color: AppColors.green2,
            bg: AppColors.greenLight,
            wide: wide,
          ),
        if (free.isNotEmpty)
          _MonthGroupList(
            prov: prov,
            title: '⏸ ببلاش الشهر ده',
            subtitle: 'لو لقيت فاتورة نزلت لحد من دول يبقى في غلط',
            heads: free,
            month: month,
            color: AppColors.muted,
            bg: AppColors.surfaceAlt,
            wide: wide,
          ),
      ]),
    ]);
  }
}

class _MonthGroupList extends StatelessWidget {
  const _MonthGroupList({
    required this.prov,
    required this.title,
    required this.subtitle,
    required this.heads,
    required this.month,
    required this.color,
    required this.bg,
    required this.wide,
  });

  final AppProvider prov;
  final String title;
  final String subtitle;
  final List<Group> heads;
  final String month;
  final Color color;
  final Color bg;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final db = prov.db;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          width: double.infinity,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title (${heads.length})',
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 13.5 : 12,
                      fontWeight: FontWeight.w900,
                      color: color)),
              Text(subtitle,
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 11 : 9.5,
                      color: color.withValues(alpha: 0.8))),
            ],
          ),
        ),
        for (final h in heads)
          InkWell(
            onTap: () => _CycleSheets.explainCell(
              context,
              prov,
              h,
              month,
              _Cycle.stateOf(prov, db, h, month),
              prov.expectedAccountAmount(h.id, month),
              _Cycle.billOf(db, h.id, month),
            ),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: wide ? 10 : 8),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.groupInvoiceName?.trim().isNotEmpty == true
                            ? h.groupInvoiceName!
                            : h.phone,
                        style: GoogleFonts.cairo(
                            fontSize: wide ? 13 : 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text),
                      ),
                      Builder(builder: (_) {
                        final dueLines = prov.dueLinesOfAccount(h.id, month);
                        if (dueLines.isEmpty) {
                          return Text('كل خطوط الحساب ببلاش الشهر ده',
                              style: GoogleFonts.cairo(
                                  fontSize: 9.5, color: AppColors.muted));
                        }
                        return Text(
                          'الدور على: ${dueLines.map((l) => l.phone).join(' • ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                              fontSize: 9.5, color: AppColors.muted),
                        );
                      }),
                    ],
                  ),
                ),
                Text(
                  () {
                    final v = prov.expectedAccountAmount(h.id, month);
                    return v > 0 ? '${v.toStringAsFixed(0)} ج' : '٠';
                  }(),
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 15 : 13,
                      fontWeight: FontWeight.w900,
                      color: color),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🔖 مفتاح الألوان + حالة فاضية
// ══════════════════════════════════════════════════════════════════════════

class _CycleLegend extends StatelessWidget {
  const _CycleLegend({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    Widget dot(_CellState s, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: s.bg,
                  border: Border.all(color: s.fg, width: 1.2),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 3),
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: wide ? 10 : 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Wrap(spacing: 10, runSpacing: 5, children: [
        dot(_CellState.billed, 'نزلت صح'),
        dot(_CellState.free, 'ببلاش — صح'),
        dot(_CellState.missing, 'ناقصة'),
        dot(_CellState.unexpected, 'غلط من الشركة'),
        // ❓ الأرقام اللي في الجدول دي «فاتورة الشركة» مش الربح — والفرق
        // ده هو أكتر حاجة بتلخبط. الجواب في نفس الشاشة.
        const MoneyWordsHelp(),
      ]),
    );
  }
}

class _CycleEmpty extends StatelessWidget {
  const _CycleEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(children: [
        Icon(Icons.repeat, size: 40, color: AppColors.border),
        const SizedBox(height: 10),
        Text('مفيش خطوط «شهر وشهر» هنا',
            style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          'العروض دي للخطوط اللي فاتورتها بتنزل شهر وتسيب شهر.\n'
          'الخطوط الثابتة مالهاش لازمة هنا — انت عارف رقمها كل شهر.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
        ),
      ]),
    );
  }
}
