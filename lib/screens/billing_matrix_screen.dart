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
import '../services/responsive.dart';
import '../services/app_search.dart';
import '../services/view_prefs.dart';
import '../widgets/app_search_bar.dart';

class BillingMatrixScreen extends StatefulWidget {
  const BillingMatrixScreen({super.key});
  @override
  State<BillingMatrixScreen> createState() => _BillingMatrixScreenState();
}

class _BillingMatrixScreenState extends State<BillingMatrixScreen> {
  String _search = '';
  String _provFilter = 'all'; // all | vodafone | etisalat | orange | we
  bool _onlyDebt = false;     // اللي عليه فلوس بس
  bool _sortByDebt = false;   // ترتيب بالأعلى مديونية
  final _searchCtrl = TextEditingController();

  // 💾 بيفتكر الفلاتر
  final _viewPrefs = ViewPrefs('billing_matrix');

  @override
  void initState() {
    super.initState();
    _viewPrefs.load().then((m) {
      if (!mounted || m.isEmpty) return;
      setState(() {
        _provFilter = m['prov'] ?? 'all';
        _onlyDebt = m['onlyDebt'] ?? false;
        _sortByDebt = m['sortByDebt'] ?? false;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _set(VoidCallback change) {
    setState(change);
    _viewPrefs.save({
      'prov': _provFilter,
      'onlyDebt': _onlyDebt,
      'sortByDebt': _sortByDebt,
    });
  }

  static const _provLabels = {
    'all': 'الكل',
    'vodafone': '🔴 فودافون',
    'etisalat': '🟢 اتصالات',
    'orange': '🟠 أورانج',
    'we': '🟣 وي',
  };

  static const double _nameW = 130; // عرض عمود الخط
  static const double _cellW = 84;  // عرض خانة الشهر

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;

    // كل الشهور اللي فيها فواتير، مرتبة تصاعدي
    final months = db.companyBills.map((b) => b.month).toSet().toList()..sort();

    // متبقي كل خط (عبر كل الشهور) — للفلترة والترتيب
    double remOf(Group g) => db.companyBills
        .where((b) => b.groupId == g.id)
        .fold(0.0, (s, b) => s + b.remaining);

    // الخطوط اللي عليها أي فاتورة + الفلاتر
    final groupsWithBills = db.groups.where((g) {
      final hasBill = db.companyBills.any((b) => b.groupId == g.id);
      if (!hasBill) return false;
      if (_provFilter != 'all' && g.provider != _provFilter) return false;
      if (_onlyDebt && remOf(g) <= 0) return false;
      // 🔍 محرّك البحث الموحّد
      final terms = searchTerms(_search);
      if (terms.isNotEmpty &&
          searchHitsOf(terms, [
                g.phone, g.ownerName ?? '', g.groupInvoiceName ?? '',
              ]) == null) {
        return false;
      }
      return true;
    }).toList();
    if (_sortByDebt) {
      groupsWithBills.sort((a, b) => remOf(b).compareTo(remOf(a)));
    } else {
      groupsWithBills.sort((a, b) => a.phone.compareTo(b.phone));
    }

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
        decoration: BoxDecoration(gradient: AppColors.headerGradient),
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
            GestureDetector(
              onTap: () => _openSpendChart(context, db),
              child: Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.bar_chart, color: Colors.white, size: 20),
              ),
            ),
            _chip('${groupsWithBills.length} خط', Colors.white24),
            const SizedBox(width: 6),
            _chip('متبقي: ${totalDue.toStringAsFixed(0)} ج',
                const Color(0x33ff5252)),
          ]),
          const SizedBox(height: 10),
          // بحث
          AppSearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            hint: '🔍 رقم · صاحب الخط · اسم الفاتورة',
            padding: EdgeInsets.zero,
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
      // ── Filters ─────────────────────────────────────────────────
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final e in _provLabels.entries)
              _filterChip(e.value, _provFilter == e.key,
                  () => _set(() => _provFilter = e.key)),
            Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 6), color: AppColors.border),
            _filterChip('💰 عليه فلوس', _onlyDebt,
                () => _set(() => _onlyDebt = !_onlyDebt)),
            _filterChip('⬇️ الأعلى مديونية', _sortByDebt,
                () => _set(() => _sortByDebt = !_sortByDebt)),
          ],
        ),
      ),
      const SizedBox(height: 4),
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
                        _headerCell('الإجمالي', _cellW),
                      ]),
                      // صفوف الخطوط
                      for (final g in groupsWithBills)
                        GestureDetector(
                          onTap: () => _openLineHistory(context, db, g),
                          child: Row(children: [
                            _nameCell(g),
                            for (final m in months)
                              _dataCell(billIndex['${g.id}|$m']),
                            _totalCell(g, remOf, db),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    ]);
  }

  // ── رسم بياني: إجمالي مصروف الشركة (الفعلي) لكل شهر ──────────
  void _openSpendChart(BuildContext context, AppDB db) {
    // إجمالي الفعلي لكل شهر
    final byMonth = <String, double>{};
    for (final b in db.companyBills) {
      byMonth[b.month] = (byMonth[b.month] ?? 0) + b.actualAmount;
    }
    final months = byMonth.keys.toList()..sort();
    final maxVal =
        byMonth.values.isEmpty ? 1.0 : byMonth.values.reduce((a, b) => a > b ? a : b);

    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(children: [
                const Text('📈', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('مصروف الشركات شهرياً',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
            Expanded(
              child: months.isEmpty
                  ? Center(
                      child: Text('لا توجد بيانات',
                          style: GoogleFonts.cairo(color: AppColors.muted)))
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final m in months.reversed)
                          _spendBar(m, byMonth[m]!, maxVal),
                      ],
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _spendBar(String month, double value, double maxVal) {
    final ratio = (value / maxVal).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmtMonth(month),
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue2)),
          Text('${value.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            Container(height: 18, color: const Color(0xFFEFEFEF)),
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                height: 18,
                decoration: BoxDecoration(gradient: AppColors.headerGradient),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── سجل الخط: كل شهر بمربعين (فاتورة الشركة + الزيادة) + ميعاد الدفع ──
  void _openLineHistory(BuildContext context, AppDB db, Group g) {
    final bills = db.companyBills.where((b) => b.groupId == g.id).toList()
      ..sort((a, b) => b.month.compareTo(a.month)); // الأحدث فوق
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            // مقبض + عنوان
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(children: [
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.circular(4))),
                Row(children: [
                  const Text('🧾', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('سجل فواتير ${g.phone}',
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                          if (g.ownerName != null && g.ownerName!.isNotEmpty)
                            Text(g.ownerName!,
                                style: GoogleFonts.cairo(
                                    color: Colors.white70, fontSize: 11)),
                        ]),
                  ),
                ]),
              ]),
            ),
            // ── توقّع «شهر وشهر»: الخط ده الشهر الجاي فاضي ولا عليه فاتورة ──
            if (g.billingSystem == 'bimonthly') _bimonthlyForecast(db, g),
            Expanded(
              child: bills.isEmpty
                  ? Center(
                      child: Text('لا توجد فواتير',
                          style: GoogleFonts.cairo(color: AppColors.muted)))
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: bills.length,
                      itemBuilder: (_, i) => _historyRow(bills[i]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // توقّع الشهر الجاي لخط «شهر وشهر» (قراءة فقط — مايغيّرش أي مبلغ)
  Widget _bimonthlyForecast(AppDB db, Group g) {
    final now = DateTime.now();
    final curMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final nextDt = DateTime(now.year, now.month + 1);
    final nextMonth =
        '${nextDt.year}-${nextDt.month.toString().padLeft(2, '0')}';
    final billedThisMonth = db.companyBills.any(
        (b) => b.groupId == g.id && b.month == curMonth && b.actualAmount > 0);
    // شهر وشهر: لو نزلت الشهر ده → الجاي فاضي، والعكس
    final nextFree = billedThisMonth;
    final bg = nextFree ? AppColors.greenLight : const Color(0xFFFFF3E0);
    final fg = nextFree ? const Color(0xFF00695c) : const Color(0xFFE65100);
    final label = nextFree
        ? '🔄 شهر وشهر: الشهر ده عليه فاتورة → الشهر الجاي ($nextMonth) المفروض فاضي ببلاش'
        : '🔄 شهر وشهر: الشهر ده فاضي → الشهر الجاي ($nextMonth) هيتقلب وعليه فاتورة';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: GoogleFonts.cairo(
              fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _historyRow(CompanyBill b) {
    final company = b.fixedAmount; // فاتورة الشركة المتوقعة
    final excess = (b.actualAmount - b.fixedAmount); // الزيادة (ممكن تبقى سالبة)
    final payDate = b.payments.isNotEmpty ? b.payments.last.date : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _box('📅 ${_fmtMonth(b.month)}', AppColors.blueLight, AppColors.blue2),
          const Spacer(),
          if (b.isDeferred)
            _box('⏸ مؤجل لـ ${b.deferDate}', const Color(0xFFFFF3E0),
                const Color(0xFFE65100))
          else if (b.isPaid)
            _box('✅ مسدد', AppColors.greenLight, const Color(0xFF00695c))
          else
            _box('متبقي ${b.remaining.toStringAsFixed(0)} ج', AppColors.redLight,
                AppColors.red2),
        ]),
        const SizedBox(height: 10),
        // ── المربعين: فاتورة الشركة + الزيادة ──
        Row(children: [
          Expanded(
            child: _twoBox('فاتورة الشركة', '${company.toStringAsFixed(0)} ج',
                const Color(0xFFE8F5E9), const Color(0xFF00695c)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _twoBox(
                excess > 0 ? 'الزيادة' : (excess < 0 ? 'أقل من المتوقع' : 'لا زيادة'),
                '${excess.toStringAsFixed(0)} ج',
                excess > 0 ? AppColors.redLight : const Color(0xFFF5F5F5),
                excess > 0 ? AppColors.red2 : AppColors.muted),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('الفعلي: ${b.actualAmount.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const Spacer(),
          if (payDate != null)
            Text('💳 دُفع: $payDate',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.green))
          else
            Text('لسه متدفعش',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        ]),
        if (b.note != null && b.note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('📝 ${b.note}',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        ],
      ]),
    );
  }

  Widget _twoBox(String label, String value, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: 15, fontWeight: FontWeight.w900, color: fg)),
        ]),
      );

  Widget _box(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: GoogleFonts.cairo(
                fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      );

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

  // عمود الإجمالي: متبقي الخط عبر كل الشهور؛ وللأب = إجمالي الحساب (هو + توابعه)
  Widget _totalCell(Group g, double Function(Group) remOf, AppDB db) {
    final children = db.groups.where((x) => x.parentGroupId == g.id).toList();
    var total = remOf(g);
    for (final c in children) {
      total += remOf(c);
    }
    final isAccount = children.isNotEmpty;
    final due = total > 0.5;
    return Container(
      width: _cellW,
      height: 44,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: due ? const Color(0xFFFCE4EC) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: due ? const Color(0xFFE57373) : const Color(0xFFA5D6A7)),
      ),
      child: Text(
          '${isAccount ? "🔗 " : ""}${total.toStringAsFixed(0)}',
          style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: due ? AppColors.red2 : const Color(0xFF00695c))),
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

  Widget _filterChip(String label, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.blue2 : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: sel ? AppColors.blue2 : AppColors.border, width: 1.5),
          ),
          child: Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : AppColors.text)),
        ),
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
