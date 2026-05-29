// lib/screens/company_invoices_screen.dart
// شاشة مراجعة فواتير شركات الاتصالات — مركزية وتفصيلية

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/app_theme.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────
enum _Period { last, current, next }

enum _Anomaly { none, doubled, repeated }

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

String _prevMonthOf(String month) {
  final p = month.split('-');
  final d = DateTime(int.parse(p[0]), int.parse(p[1]) - 1);
  return _monthKey(d);
}

String _monthLabel(String key) {
  final months = [
    '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];
  final p = key.split('-');
  if (p.length < 2) return key;
  final m = int.tryParse(p[1]) ?? 0;
  return '${months[m]} ${p[0]}';
}

// ══════════════════════════════════════════════════════════════════════════════
class CompanyInvoicesScreen extends StatefulWidget {
  const CompanyInvoicesScreen({super.key});

  @override
  State<CompanyInvoicesScreen> createState() => _CompanyInvoicesScreenState();
}

class _CompanyInvoicesScreenState extends State<CompanyInvoicesScreen> {
  _Period _period = _Period.current;
  String _provFilter = 'all';
  String _typeFilter = 'all'; // all | estimated | actual | paid

  // ── Period helpers ──────────────────────────────────────────────
  String get _targetMonth {
    final n = DateTime.now();
    switch (_period) {
      case _Period.last:
        return _monthKey(DateTime(n.year, n.month - 1));
      case _Period.current:
        return _monthKey(n);
      case _Period.next:
        return _monthKey(DateTime(n.year, n.month + 1));
    }
  }

  // ── Anomaly detection ────────────────────────────────────────────
  _Anomaly _anomalyOf(CompanyBill bill, List<CompanyBill> allBills) {
    if (bill.actualAmount <= 0) return _Anomaly.none;
    final prevM = _prevMonthOf(bill.month);
    final CompanyBill? prev = allBills.cast<CompanyBill?>().firstWhere(
        (b) => b!.groupId == bill.groupId && b.month == prevM,
        orElse: () => null);
    if (prev == null || prev.actualAmount <= 0) return _Anomaly.none;
    // مضاعفة: الفاتورة الحالية أكبر بـ 75% أو أكثر من الشهر الماضي
    if (bill.actualAmount >= prev.actualAmount * 1.75) return _Anomaly.doubled;
    // تكرار: نفس المبلغ شهرين متتاليين (كلاهما فعليتان)
    if (bill.isActual &&
        prev.isActual &&
        (bill.actualAmount - prev.actualAmount).abs() < 0.5) {
      return _Anomaly.repeated;
    }
    return _Anomaly.none;
  }

  // ── Filtered bills ────────────────────────────────────────────────
  List<CompanyBill> _filteredBills(AppDB db) {
    final m = _targetMonth;
    final result = db.companyBills.where((b) {
      if (b.month != m) return false;
      final g = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: ''));
      // إخفاء فواتير الخطوط الفرعية — هتظهر داخل كرت الخط الرئيسي
      if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) {
        final parentHasBill = db.companyBills.any((x) =>
            x.groupId == g.parentGroupId && x.month == m);
        if (parentHasBill) return false;
      }
      if (_provFilter != 'all' && g.provider != _provFilter) return false;
      switch (_typeFilter) {
        case 'estimated':
          if (b.isActual) return false;
          break;
        case 'actual':
          if (!b.isActual || b.isPaid) return false;
          break;
        case 'paid':
          if (!b.isPaid) return false;
          break;
      }
      return true;
    }).toList();
    result.sort((a, b) {
      final ga = db.groups.firstWhere((x) => x.id == a.groupId,
          orElse: () => Group(id: '', phone: ''));
      final gb = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: ''));
      return (ga.provider ?? '').compareTo(gb.provider ?? '');
    });
    return result;
  }

  // ── Expected groups for next month ────────────────────────────────
  List<Group> _expectedGroups(AppDB db) {
    if (_period != _Period.next) return [];
    if (_typeFilter == 'actual' || _typeFilter == 'paid') return [];
    final m = _targetMonth;
    final addedGids = db.companyBills
        .where((b) => b.month == m)
        .map((b) => b.groupId)
        .toSet();
    return db.groups.where((g) {
      if (g.fixedBillAmount <= 0) return false;
      if (addedGids.contains(g.id)) return false;
      // إخفاء الخطوط الفرعية — هتنزل تلقائياً مع الخط الرئيسي
      if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) return false;
      if (_provFilter != 'all' && g.provider != _provFilter) return false;
      return true;
    }).toList();
  }

  // ── Group bills by provider ──────────────────────────────────────
  Map<String, List<CompanyBill>> _groupByProvider(
      List<CompanyBill> bills, AppDB db) {
    const provOrder = ['etisalat', 'orange', 'vodafone', 'we'];
    final raw = <String, List<CompanyBill>>{};
    for (final b in bills) {
      final g = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: ''));
      final p = g.provider ?? 'unknown';
      raw.putIfAbsent(p, () => []).add(b);
    }
    final sorted = <String, List<CompanyBill>>{};
    for (final k in provOrder) {
      if (raw.containsKey(k)) sorted[k] = raw[k]!;
    }
    for (final k in raw.keys) {
      if (!sorted.containsKey(k)) sorted[k] = raw[k]!;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;
    final bills = _filteredBills(db);
    final expected = _expectedGroups(db);
    final grouped = _groupByProvider(bills, db);

    final anomalyCount =
        bills.where((b) => _anomalyOf(b, db.companyBills) != _Anomaly.none).length;
    final totalActual =
        bills.where((b) => b.isActual).fold(0.0, (s, b) => s + b.actualAmount);
    final totalUnpaid = bills.fold(0.0, (s, b) => s + b.remaining);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        _buildHeader(context, prov, db, bills.length, expected.length,
            totalActual, totalUnpaid, anomalyCount),
        _buildPeriodSelector(),
        _buildProviderChips(),
        _buildTypeChips(),
        Expanded(
          child: (bills.isEmpty && expected.isEmpty)
              ? _emptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  children: [
                    _helpBanner(),
                    if (anomalyCount > 0) _anomalyBanner(anomalyCount),
                    // Expected section (next month only)
                    if (expected.isNotEmpty) ...[
                      _sectionHeader(
                        '📅 متوقعة — ${_monthLabel(_targetMonth)}',
                        expected.length,
                        const Color(0xFF6a1b9a),
                        const Color(0xFFF3E5F5),
                      ),
                      for (final g in expected)
                        _ExpectedCard(group: g, month: _targetMonth, prov: prov),
                      const SizedBox(height: 6),
                    ],
                    // Bills grouped by provider
                    for (final entry in grouped.entries) ...[
                      if (grouped.length > 1 || expected.isNotEmpty)
                        _provSectionHeader(entry.key, entry.value, db),
                      for (final b in entry.value)
                        _AuditCard(
                          bill: b,
                          db: db,
                          prov: prov,
                          anomaly: _anomalyOf(b, db.companyBills),
                        ),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext ctx,
    AppProvider prov,
    AppDB db,
    int count,
    int expectedCount,
    double totalActual,
    double totalUnpaid,
    int anomalyCount,
  ) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(children: [
        Row(children: [
          const Text('🧾', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'مراجعة فواتير الشركات',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900),
            ),
          ),
          _addBillBtn(ctx, prov, db),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _summChip('${count + expectedCount}', 'فواتير', Colors.white24),
          const SizedBox(width: 6),
          _summChip(
            '${totalActual.toStringAsFixed(0)} ج',
            'فعلية',
            const Color(0xFF2e7d32).withValues(alpha: 0.55),
          ),
          const SizedBox(width: 6),
          _summChip(
            '${totalUnpaid.toStringAsFixed(0)} ج',
            'متبقي',
            totalUnpaid > 0
                ? const Color(0xFFc62828).withValues(alpha: 0.6)
                : Colors.white24,
          ),
          if (anomalyCount > 0) ...[
            const SizedBox(width: 6),
            _summChip(
              '$anomalyCount ⚠️',
              'تنبيه',
              const Color(0xFFe65100).withValues(alpha: 0.7),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _summChip(String val, String lbl, Color bg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(val,
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
            Text(lbl,
                style: GoogleFonts.cairo(
                    color: Colors.white70, fontSize: 9)),
          ]),
        ),
      );

  Widget _addBillBtn(BuildContext ctx, AppProvider prov, AppDB db) {
    return GestureDetector(
      onTap: () => _showAddDialog(ctx, prov, db),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text('إضافة',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── Period selector ────────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    const labels = {
      _Period.last: 'الشهر الماضي',
      _Period.current: 'الشهر الحالي',
      _Period.next: 'الشهر القادم',
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(children: [
        for (final p in _Period.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: _period == p
                      ? AppColors.blue
                      : const Color(0xFFf0f4f8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _period == p
                          ? AppColors.blue
                          : AppColors.border),
                ),
                child: Text(
                  labels[p]!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        _period == p ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
          if (p != _Period.next) const SizedBox(width: 6),
        ],
      ]),
    );
  }

  // ── Provider chips ─────────────────────────────────────────────────
  Widget _buildProviderChips() {
    final items = [
      {'key': 'all', 'label': 'الكل', 'color': AppColors.blue},
      {
        'key': 'etisalat',
        'label': '🟢 اتصالات',
        'color': const Color(0xFF00A651)
      },
      {
        'key': 'orange',
        'label': '🟠 أورانج',
        'color': const Color(0xFFFF6600)
      },
      {
        'key': 'vodafone',
        'label': '🔴 فودافون',
        'color': const Color(0xFFE60000)
      },
      {'key': 'we', 'label': '🟣 WE', 'color': const Color(0xFF7B2D8B)},
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        children: items.map((item) {
          final active = _provFilter == item['key'];
          final color = item['color'] as Color;
          return GestureDetector(
            onTap: () =>
                setState(() => _provFilter = item['key'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? color : const Color(0xFFf0f4f8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: active ? color : AppColors.border),
              ),
              child: Text(
                item['label'] as String,
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        active ? Colors.white : AppColors.text),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Type chips ─────────────────────────────────────────────────────
  Widget _buildTypeChips() {
    final items = [
      {'key': 'all', 'label': 'الكل', 'color': AppColors.blue},
      {
        'key': 'estimated',
        'label': '📊 تقديرية',
        'color': const Color(0xFF6a1b9a)
      },
      {
        'key': 'actual',
        'label': '✅ فعلية',
        'color': const Color(0xFF2e7d32)
      },
      {
        'key': 'paid',
        'label': '💰 مسددة',
        'color': const Color(0xFF1565c0)
      },
    ];
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        children: items.map((item) {
          final active = _typeFilter == item['key'];
          final color = item['color'] as Color;
          return GestureDetector(
            onTap: () =>
                setState(() => _typeFilter = item['key'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? color : const Color(0xFFf0f4f8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                item['label'] as String,
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        active ? Colors.white : AppColors.text),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Help banner (collapsible) ──────────────────────────────────────
  bool _helpOpen = false;
  Widget _helpBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _helpOpen = !_helpOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 9),
            child: Row(children: [
              const Text('❓', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('إزاي أستخدم شاشة الفواتير؟',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1565C0))),
              ),
              Icon(
                  _helpOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: const Color(0xFF1565C0)),
            ]),
          ),
        ),
        if (_helpOpen)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              '• كل شهر اضغط "➕ إضافة" واختار الخط واكتب مبلغ الفاتورة الفعلية اللي نزلت من الشركة.\n'
              '• "📊 تقديرية" = مبلغ متوقع (مالوش تأثير على الربح). "✅ فعلية" = الفاتورة الحقيقية اللي بتتحكم في الربح.\n'
              '• لو نزلت فاتورة تقديرية، اضغط "✅ تأكيد الفاتورة الفعلية" واكتب المبلغ الحقيقي.\n'
              '• فاتورة واحدة لكذا خط؟ افتح الكرت واضغط زرار 🔗 لضمّ الخطوط التانية — الفاتورة هتنزل عليهم كلهم مرة واحدة.\n'
              '• استخدم الفلاتر فوق (الكل / تقديرية / فعلية / مسددة) عشان تشوف اللي محتاجه بس.',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  height: 1.7,
                  color: const Color(0xFF1565C0)),
            ),
          ),
      ]),
    );
  }

  // ── Section widgets ────────────────────────────────────────────────
  Widget _anomalyBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe65100)),
      ),
      child: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'يوجد $count فاتورة تحتاج مراجعة — مضاعفة أو متكررة',
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFbf360c)),
          ),
        ),
      ]),
    );
  }

  Widget _sectionHeader(
      String title, int count, Color color, Color bg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _provSectionHeader(
      String provider, List<CompanyBill> bills, AppDB db) {
    final name =
        MainLine.providerNames[provider] ?? provider;
    final emoji =
        MainLine.providerEmojis[provider] ?? '📡';
    final color =
        MainLine.providerColors[provider] ?? AppColors.blue;
    final bg =
        MainLine.providerBg[provider] ?? AppColors.blueLight;
    final unpaid = bills.fold(0.0, (s, b) => s + b.remaining);
    final estimated = bills.where((b) => !b.isActual).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text('$emoji $name',
            style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color)),
        const SizedBox(width: 8),
        Text(
          '${bills.length} فاتورة'
          '${estimated > 0 ? " ($estimated تقديرية)" : ""}',
          style: GoogleFonts.cairo(
              fontSize: 11,
              color: color.withValues(alpha: 0.7)),
        ),
        const Spacer(),
        if (unpaid > 0)
          Text(
            'متبقي: ${unpaid.toStringAsFixed(0)} ج',
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color),
          ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🧾', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text('لا توجد فواتير لهذه الفترة',
                style: GoogleFonts.cairo(
                    color: AppColors.muted, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              'جرّب تغيير الفترة الزمنية أو الفلتر\nأو اضغط "إضافة" لتسجيل فاتورة جديدة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  color: AppColors.muted, fontSize: 12),
            ),
          ]),
    );
  }

  // ── Add bill dialog ────────────────────────────────────────────────
  void _showAddDialog(
      BuildContext ctx, AppProvider prov, AppDB db) {
    String? selectedGid;
    bool isEstimated = false;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final selectedMonth = _targetMonth;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) {
          final groups = db.groups
              .where((g) =>
                  g.fixedBillAmount > 0 || g.provider != null)
              .toList();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(ctx2).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius:
                                  BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'إضافة فاتورة — ${_monthLabel(selectedMonth)}',
                        style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.blue2),
                      ),
                      const SizedBox(height: 14),
                      // Type toggle
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setS(() => isEstimated = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: !isEstimated
                                    ? AppColors.green
                                    : const Color(0xFFf0f4f8),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Text(
                                '✅ فاتورة فعلية',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: !isEstimated
                                        ? Colors.white
                                        : AppColors.muted),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setS(() => isEstimated = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: isEstimated
                                    ? const Color(0xFF6a1b9a)
                                    : const Color(0xFFf0f4f8),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Text(
                                '📊 فاتورة تقديرية',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isEstimated
                                        ? Colors.white
                                        : AppColors.muted),
                              ),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      // Group picker
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'اختر الخط / المجموعة',
                          labelStyle:
                              GoogleFonts.cairo(fontSize: 13),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                        ),
                        isExpanded: true,
                        initialValue: selectedGid,
                        items: groups.map((g) {
                          final pName =
                              MainLine.providerNames[g.provider] ??
                                  (g.provider ?? '');
                          final emoji =
                              MainLine.providerEmojis[g.provider] ??
                                  '📡';
                          final childCount = db.groups
                              .where((x) =>
                                  x.parentGroupId == g.id)
                              .length;
                          return DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              '$emoji ${g.phone}'
                              '${g.ownerName != null ? " — ${g.ownerName}" : ""}'
                              '${pName.isNotEmpty ? " ($pName)" : ""}'
                              '${childCount > 0 ? " 🔗+$childCount" : ""}',
                              style: GoogleFonts.cairo(
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setS(() {
                            selectedGid = v;
                            if (v != null && isEstimated) {
                              final g = db.groups
                                  .firstWhere((x) => x.id == v);
                              if (g.fixedBillAmount > 0) {
                                amountCtrl.text = g.fixedBillAmount
                                    .toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Fixed amount hint
                      if (selectedGid != null)
                        Builder(builder: (_) {
                          final g = db.groups.firstWhere(
                              (x) => x.id == selectedGid,
                              orElse: () =>
                                  Group(id: '', phone: ''));
                          if (g.fixedBillAmount <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                                color: AppColors.blueLight,
                                borderRadius:
                                    BorderRadius.circular(8)),
                            child: Row(children: [
                              const Icon(Icons.info_outline,
                                  size: 14,
                                  color: AppColors.blue2),
                              const SizedBox(width: 6),
                              Text(
                                'المبلغ الثابت: ${g.fixedBillAmount.toStringAsFixed(0)} ج',
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.blue2,
                                    fontWeight:
                                        FontWeight.w700),
                              ),
                            ]),
                          );
                        }),
                      // Linked sub-lines hint
                      if (selectedGid != null)
                        Builder(builder: (_) {
                          final children = db.groups
                              .where((x) =>
                                  x.parentGroupId == selectedGid)
                              .toList();
                          if (children.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF3E5F5),
                                borderRadius:
                                    BorderRadius.circular(8)),
                            child: Row(children: [
                              const Icon(Icons.link,
                                  size: 14,
                                  color: Color(0xFF6A1B9A)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'هتنزل تلقائياً على ${children.length} خط مضموم: '
                                  '${children.map((c) => c.phone).join(' • ')}',
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color:
                                          const Color(0xFF6A1B9A),
                                      fontWeight:
                                          FontWeight.w700),
                                ),
                              ),
                            ]),
                          );
                        }),
                      const SizedBox(height: 10),
                      // Amount field (actual bills only)
                      if (!isEstimated)
                        TextField(
                          controller: amountCtrl,
                          keyboardType:
                              TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText:
                                'مبلغ الفاتورة الفعلية (ج)',
                            labelStyle: GoogleFonts.cairo(
                                fontSize: 13),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10),
                          ),
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          labelStyle:
                              GoogleFonts.cairo(fontSize: 13),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: isEstimated
                                  ? const Color(0xFF6a1b9a)
                                  : AppColors.green,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 13)),
                          onPressed: () {
                            if (selectedGid == null) return;
                            final note = noteCtrl.text
                                    .trim()
                                    .isEmpty
                                ? null
                                : noteCtrl.text.trim();
                            if (isEstimated) {
                              prov.addEstimatedBill(
                                  selectedGid!,
                                  forMonth: selectedMonth,
                                  note: note);
                            } else {
                              final amount = double.tryParse(
                                      amountCtrl.text.trim()) ??
                                  0;
                              if (amount <= 0) return;
                              prov.addGroupBill(selectedGid!,
                                  amount, note: note);
                            }
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            isEstimated
                                ? 'إضافة فاتورة تقديرية'
                                : 'إضافة فاتورة فعلية',
                            style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bill Audit Card
// ══════════════════════════════════════════════════════════════════════════════
class _AuditCard extends StatefulWidget {
  final CompanyBill bill;
  final AppDB db;
  final AppProvider prov;
  final _Anomaly anomaly;

  const _AuditCard({
    required this.bill,
    required this.db,
    required this.prov,
    required this.anomaly,
  });

  @override
  State<_AuditCard> createState() => _AuditCardState();
}

class _AuditCardState extends State<_AuditCard> {
  bool _expanded = false;

  CompanyBill get b => widget.bill;
  AppDB get db => widget.db;
  AppProvider get prov => widget.prov;

  Color get _typeColor {
    if (b.isPaid) return AppColors.green;
    if (b.isActual) return const Color(0xFF2e7d32);
    return const Color(0xFF6a1b9a);
  }

  Color get _typeBg {
    if (b.isPaid) return AppColors.greenLight;
    if (b.isActual) return const Color(0xFFE8F5E9);
    return const Color(0xFFF3E5F5);
  }

  String get _typeLabel {
    if (b.isPaid) return '💰 مسددة';
    if (b.isActual) return '✅ فعلية';
    return '📊 تقديرية';
  }

  @override
  Widget build(BuildContext context) {
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: '—'));
    final provColor =
        MainLine.providerColors[g.provider] ?? AppColors.blue;
    final provEmoji =
        MainLine.providerEmojis[g.provider] ?? '📡';
    final percent = b.actualAmount > 0
        ? (b.paidAmount / b.actualAmount).clamp(0.0, 1.0)
        : 0.0;

    // Comparison with prev month
    final prevM = _prevMonthOf(b.month);
    final CompanyBill? prev = db.companyBills
        .cast<CompanyBill?>()
        .firstWhere(
            (x) => x!.groupId == b.groupId && x.month == prevM,
            orElse: () => null);
    final delta = (prev != null && prev.actualAmount > 0)
        ? (b.actualAmount - prev.actualAmount) /
            prev.actualAmount *
            100
        : null;

    final hasAnomaly = widget.anomaly != _Anomaly.none;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasAnomaly
                ? const Color(0xFFe65100).withValues(alpha: 0.5)
                : AppColors.border,
            width: hasAnomaly ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.05),
              blurRadius: 8)
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main content ──────────────────────────────────
            GestureDetector(
              onTap: () =>
                  setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Top row: badges
                      Row(children: [
                        _badge(
                          '$provEmoji ${MainLine.providerNames[g.provider] ?? (g.provider ?? '?')}',
                          provColor.withValues(alpha: 0.12),
                          provColor,
                        ),
                        const SizedBox(width: 6),
                        _badge(
                            _typeLabel, _typeBg, _typeColor),
                        const Spacer(),
                        if (hasAnomaly)
                          _anomalyBadge(widget.anomaly),
                        Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.muted),
                      ]),
                      const SizedBox(height: 6),
                      // Phone + owner + month
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.phone,
                                  style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w900,
                                      color: AppColors.blue2),
                                ),
                                if (g.ownerName != null)
                                  Text(g.ownerName!,
                                      style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          color:
                                              AppColors.muted)),
                              ]),
                        ),
                        _badge(
                          '📅 ${b.month}',
                          AppColors.blueLight,
                          AppColors.blue2,
                        ),
                      ]),
                      // ── Linked sub-lines (this bill covers them too) ──
                      Builder(builder: (_) {
                        final children = db.groups
                            .where((x) => x.parentGroupId == g.id)
                            .toList();
                        if (children.isEmpty) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFCE93D8)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.link,
                                size: 13,
                                color: Color(0xFF6A1B9A)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'ضُمّ معاه ${children.length} خط: '
                                '${children.map((c) => c.phone).join(' • ')}',
                                style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    color:
                                        const Color(0xFF6A1B9A),
                                    fontWeight:
                                        FontWeight.w700),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  _showUnlinkDialog(context, children),
                              child: const Padding(
                                padding:
                                    EdgeInsets.only(right: 4),
                                child: Icon(
                                    Icons.settings_outlined,
                                    size: 14,
                                    color:
                                        Color(0xFF6A1B9A)),
                              ),
                            ),
                          ]),
                        );
                      }),
                      const SizedBox(height: 6),
                      // Amounts row
                      Row(children: [
                        if (b.fixedAmount > 0) ...[
                          _infoChip(
                            'ثابت: ${b.fixedAmount.toStringAsFixed(0)} ج',
                            const Color(0xFFE8F5E9),
                            AppColors.green,
                          ),
                          const SizedBox(width: 6),
                        ],
                        _infoChip(
                          '${b.isActual ? 'فعلي' : 'تقدير'}: ${b.actualAmount.toStringAsFixed(0)} ج',
                          AppColors.blueLight,
                          AppColors.blue2,
                        ),
                        if (delta != null) ...[
                          const SizedBox(width: 6),
                          _deltaChip(delta),
                        ],
                      ]),
                      // Payment progress
                      if (!b.isPaid) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'مدفوع: ${b.paidAmount.toStringAsFixed(0)} ج',
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.green),
                            ),
                            Text(
                              'متبقي: ${b.remaining.toStringAsFixed(0)} ج',
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: AppColors.redLight,
                            valueColor:
                                const AlwaysStoppedAnimation<
                                    Color>(AppColors.green),
                            minHeight: 5,
                          ),
                        ),
                      ],
                      if (b.isPaid)
                        Text(
                          '✅ تم السداد الكامل',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.green,
                              fontWeight: FontWeight.w700),
                        ),
                      if (b.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📝 ${b.note}',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.muted),
                        ),
                      ],
                    ]),
              ),
            ),
            // ── Anomaly details (expanded) ─────────────────────
            if (hasAnomaly && _expanded)
              _anomalyDetails(widget.anomaly, prev),
            // ── Actions ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                if (!b.isActual) ...[
                  Expanded(
                    flex: 4,
                    child: _actionBtn(
                      '✅ تأكيد الفاتورة الفعلية',
                      const Color(0xFF2e7d32),
                      const Color(0xFFE8F5E9),
                      () => _showConfirmDialog(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (b.isActual && !b.isPaid) ...[
                  Expanded(
                    flex: 3,
                    child: _actionBtn(
                      '💳 جزئي',
                      const Color(0xFFe65100),
                      const Color(0xFFFFF3E0),
                      () => _showPayDialog(context,
                          full: false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: _actionBtn(
                      '✅ كامل',
                      AppColors.green,
                      AppColors.greenLight,
                      () => _showPayDialog(context,
                          full: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                _linkBtn(context),
                const SizedBox(width: 6),
                _deleteBtn(context),
              ]),
            ),
            // ── Payment history (expanded) ─────────────────────
            if (_expanded && b.payments.isNotEmpty) ...[
              const Divider(
                  height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سجل الدفعات',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blue2),
                      ),
                      const SizedBox(height: 4),
                      ...b.payments.map((p) => Padding(
                            padding: const EdgeInsets.only(
                                top: 3),
                            child: Row(children: [
                              const Icon(
                                  Icons.check_circle_outline,
                                  size: 12,
                                  color: AppColors.green),
                              const SizedBox(width: 6),
                              if (p.note != null)
                                Expanded(
                                  child: Text(
                                    p.note!,
                                    style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        color: AppColors.muted),
                                  ),
                                ),
                              Text(
                                p.date,
                                style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    color: AppColors.muted),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${p.amount.toStringAsFixed(0)} ج',
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.green),
                              ),
                            ]),
                          )),
                    ]),
              ),
            ],
          ]),
    );
  }

  Widget _badge(String txt, Color bg, Color textColor) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10,
                color: textColor,
                fontWeight: FontWeight.w800)),
      );

  Widget _infoChip(
          String txt, Color bg, Color textColor) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor)),
      );

  Widget _deltaChip(double delta) {
    final isUp = delta > 0;
    final color = isUp ? AppColors.red : AppColors.green;
    final bg =
        isUp ? AppColors.redLight : AppColors.greenLight;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            isUp
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 10,
            color: color),
        Text(
          '${delta.abs().toStringAsFixed(0)}%',
          style: GoogleFonts.cairo(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  Widget _anomalyBadge(_Anomaly a) {
    final isDoubled = a == _Anomaly.doubled;
    final color = isDoubled
        ? const Color(0xFFc62828)
        : const Color(0xFFe65100);
    final txt = isDoubled ? '⚠️ مضاعفة' : '⚠️ تكرار';
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: color.withValues(alpha: 0.4))),
      child: Text(txt,
          style: GoogleFonts.cairo(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _anomalyDetails(_Anomaly a, CompanyBill? prev) {
    String msg;
    Color color;
    if (a == _Anomaly.doubled) {
      color = const Color(0xFFc62828);
      msg = 'تنبيه: الفاتورة (${b.actualAmount.toStringAsFixed(0)} ج) أكبر بكثير من '
          'الشهر الماضي${prev != null ? " (${prev.actualAmount.toStringAsFixed(0)} ج)" : ""}.'
          ' احتمال وجود خطأ أو تراكم فواتير من الشركة.';
    } else {
      color = const Color(0xFFe65100);
      msg = 'تنبيه: نفس المبلغ (${b.actualAmount.toStringAsFixed(0)} ج) تكرر شهرين متتاليين.'
          ' تحقق من احتمال وجود فاتورة مكررة بالخطأ.';
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color.withValues(alpha: 0.3))),
      child: Text(msg,
          style: GoogleFonts.cairo(
              fontSize: 11,
              color: color.withValues(alpha: 0.9))),
    );
  }

  Widget _actionBtn(String label, Color color, Color bg,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: color.withValues(alpha: 0.5))),
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      );

  Widget _deleteBtn(BuildContext context) => GestureDetector(
        onTap: () => _confirmDelete(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.delete_outline,
              size: 14, color: AppColors.red),
        ),
      );

  Widget _linkBtn(BuildContext context) => GestureDetector(
        onTap: () => _showLinkDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFCE93D8))),
          child: const Icon(Icons.add_link,
              size: 14, color: Color(0xFF6A1B9A)),
        ),
      );

  // ضمّ خط فرعي لهذا الخط الرئيسي — الفاتورة تنزل عليه تلقائياً
  void _showLinkDialog(BuildContext context) {
    final parent = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: '—'));
    // مرشحون: خطوط من غير خط رئيسي + مش الخط ده نفسه + مش مربوطين بحد تاني
    final candidates = db.groups
        .where((g) =>
            g.id != parent.id &&
            (g.parentGroupId == null || g.parentGroupId!.isEmpty))
        .toList();
    String? selected;
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Text('🔗 ضمّ خط لـ ${parent.phone}',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 15),
                textDirection: TextDirection.rtl),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'الخط اللي تختاره هيتحسب فاتورته مع الخط الرئيسي ده. '
                      'لما تنزّل فاتورة على الخط الرئيسي هتنزل عليه تلقائياً.',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: const Color(0xFF6A1B9A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (candidates.isEmpty)
                    Text('مفيش خطوط متاحة للضمّ',
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: AppColors.muted))
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'اختر الخط الفرعي',
                        labelStyle:
                            GoogleFonts.cairo(fontSize: 13),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                      ),
                      items: candidates
                          .map((g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  '${g.phone}${g.ownerName != null ? " — ${g.ownerName}" : ""}',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12),
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setS(() => selected = v),
                    ),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء',
                      style: GoogleFonts.cairo())),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                onPressed: candidates.isEmpty || selected == null
                    ? null
                    : () {
                        prov.setGroupParent(selected!, parent.id);
                        Navigator.pop(context);
                      },
                child: Text('ضمّ الخط',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // فصل خط فرعي من الخط الرئيسي
  void _showUnlinkDialog(
      BuildContext context, List<Group> children) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text('🔗 الخطوط المضمومة',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${c.phone}${c.ownerName != null ? " — ${c.ownerName}" : ""}',
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          prov.setGroupParent(c.id, null);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: AppColors.redLight,
                              borderRadius:
                                  BorderRadius.circular(8)),
                          child: Text('فصل',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.red,
                                  fontWeight:
                                      FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    Text('تمام', style: GoogleFonts.cairo())),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────
  void _showConfirmDialog(BuildContext context) {
    final ctrl = TextEditingController(
        text: b.actualAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text('✅ تأكيد الفاتورة الفعلية',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius:
                          BorderRadius.circular(10)),
                  child: Text(
                    'الفاتورة التقديرية: ${b.actualAmount.toStringAsFixed(0)} ج\n'
                    'أدخل المبلغ الفعلي الوارد من الشركة',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF6a1b9a)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'المبلغ الفعلي (ج)',
                    labelStyle:
                        GoogleFonts.cairo(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                  ),
                ),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10))),
              onPressed: () {
                final amount =
                    double.tryParse(ctrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                prov.confirmActualBill(b.id, amount);
                Navigator.pop(context);
              },
              child: Text('تأكيد',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayDialog(BuildContext context,
      {required bool full}) {
    final ctrl = TextEditingController(
        text: full ? b.remaining.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text(full ? '✅ سداد كامل' : '💳 سداد جزئي',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius:
                          BorderRadius.circular(10)),
                  child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المتبقي:',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.blue2)),
                        Text(
                          '${b.remaining.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.blue2),
                        ),
                      ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  readOnly: full,
                  decoration: InputDecoration(
                    labelText: 'المبلغ (ج)',
                    labelStyle:
                        GoogleFonts.cairo(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                    filled: full,
                    fillColor: full
                        ? const Color(0xFFf0f4f8)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'ملاحظة (رقم إيصال...)',
                    labelStyle:
                        GoogleFonts.cairo(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                  ),
                ),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: full
                      ? AppColors.green
                      : const Color(0xFFe65100),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10))),
              onPressed: () {
                final amount =
                    double.tryParse(ctrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                prov.payCompanyBill(
                  b.id,
                  amount,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );
                Navigator.pop(context);
              },
              child: Text('تأكيد',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('حذف الفاتورة',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900)),
          content: Text(
              'سيتم حذف الفاتورة وعكس تأثيرها على المديونية.',
              style: GoogleFonts.cairo()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red),
              onPressed: () {
                prov.deleteCompanyBill(b.id);
                Navigator.pop(context);
              },
              child: Text('حذف',
                  style: GoogleFonts.cairo(
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Expected Bill Card (next month preview)
// ══════════════════════════════════════════════════════════════════════════════
class _ExpectedCard extends StatelessWidget {
  final Group group;
  final String month;
  final AppProvider prov;

  const _ExpectedCard({
    required this.group,
    required this.month,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final g = group;
    final provColor =
        MainLine.providerColors[g.provider] ?? AppColors.blue;
    final provEmoji =
        MainLine.providerEmojis[g.provider] ?? '📡';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                const Color(0xFF6a1b9a).withValues(alpha: 0.25),
            width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.purple.withValues(alpha: 0.04),
              blurRadius: 8)
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: provColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      '$provEmoji ${MainLine.providerNames[g.provider] ?? (g.provider ?? '?')}',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: provColor,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      '📅 $month',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: const Color(0xFF6a1b9a),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
                const SizedBox(height: 5),
                Text(
                  g.phone,
                  style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue2),
                ),
                if (g.ownerName != null)
                  Text(g.ownerName!,
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  'تقدير: ${g.fixedBillAmount.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF6a1b9a),
                      fontWeight: FontWeight.w700),
                ),
              ]),
        ),
        Column(children: [
          GestureDetector(
            onTap: () =>
                prov.addEstimatedBill(g.id, forMonth: month),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF6a1b9a)
                          .withValues(alpha: 0.4))),
              child: Text(
                '+ تقديرية',
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: const Color(0xFF6a1b9a),
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showAddActualDialog(context, g),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.green
                          .withValues(alpha: 0.5))),
              child: Text(
                '+ فعلية',
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.green,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showAddActualDialog(BuildContext context, Group g) {
    final ctrl = TextEditingController(
        text: g.fixedBillAmount > 0
            ? g.fixedBillAmount.toStringAsFixed(0)
            : '');
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text(
            'إضافة فاتورة فعلية — $month',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900, fontSize: 14),
          ),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g.phone,
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue2)),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'مبلغ الفاتورة (ج)',
                    labelStyle:
                        GoogleFonts.cairo(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                  ),
                ),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10))),
              onPressed: () {
                final amount =
                    double.tryParse(ctrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                prov.addGroupBill(g.id, amount);
                Navigator.pop(context);
              },
              child: Text('إضافة',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
