// lib/screens/company_invoices_screen.dart
// شاشة مراجعة فواتير شركات الاتصالات — مركزية وتفصيلية

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard — نسخ الجدول لإكسل
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/app_theme.dart';
import '../services/responsive.dart';
import '../services/app_search.dart';
import '../services/breakpoints.dart';
import '../services/view_prefs.dart';
import '../services/export_service.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/common.dart';
import '../widgets/linked_lines_strip.dart';
import '../widgets/money_words.dart';
import '../widgets/expected_actual_chart.dart';

part 'company_invoices_audit_card.dart';
part 'company_invoices_expected_card.dart';
part 'company_invoices_split_sheet.dart';
part 'company_invoices_cycle_views.dart';
part 'company_invoices_cycle_sheets.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────
enum _Period { last, current, next }

/// ⌨️ نيّة التنقّل للشهر اللي قبله (سهم اليمين في الشاشة العربية).
class _PrevMonthIntent extends Intent {
  const _PrevMonthIntent();
}

/// ⌨️ نيّة التنقّل للشهر اللي بعده (سهم الشمال في الشاشة العربية).
class _NextMonthIntent extends Intent {
  const _NextMonthIntent();
}

/// سهم تنقّل بين الشهور. `onTap = null` يعني وصلنا الآخر.
class _MonthArrow extends StatelessWidget {
  const _MonthArrow(
      {required this.icon, required this.tip, required this.onTap});

  final IconData icon;
  final String tip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        color: AppColors.blue2,
        disabledColor: AppColors.border,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
      );
}

enum _Anomaly { none, doubled, repeated, unexpectedBimonthly, sameMonthDuplicate }

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

String _prevMonthOf(String month) {
  final p = month.split('-');
  final d = DateTime(int.parse(p[0]), int.parse(p[1]) - 1);
  return _monthKey(d);
}

String _nextMonthOf(String month) {
  final p = month.split('-');
  final d = DateTime(int.parse(p[0]), int.parse(p[1]) + 1);
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
  String _search = '';
  String _sort = 'default'; // default | remaining | deadline | recent
  bool _onlyOverdue = false; // فات موعدها بس
  bool _missingOpen = false; // عرض الفواتير الغايبة
  _CycleView _view = _CycleView.cards; // 🎚 طريقة العرض
  /// 🔍 تكبير/تصغير الجدول. ١.٠ = المقاس الطبيعي.
  ///
  /// لازمته: على الكمبيوتر بتحب تصغّر عشان تشوف سنة كاملة في نظرة، وعلى
  /// التاب بتحب تكبّر عشان الأرقام تبقى مقروءة. نفس الجدول، احتياجين.
  double _zoom = 1.0;

  /// 🗓 كام شهر يبان في الجدول. null = يتحسب من مقاس الشاشة.
  int? _monthCount;
  final _searchCtrl = TextEditingController();

  // 💾 بيفتكر الفلاتر والترتيب
  final _viewPrefs = ViewPrefs('company_invoices');

  @override
  void initState() {
    super.initState();
    _viewPrefs.load().then((m) {
      if (!mounted || m.isEmpty) return;
      setState(() {
        _provFilter = m['prov'] ?? 'all';
        _typeFilter = m['type'] ?? 'all';
        _sort = m['sort'] ?? 'default';
        _onlyOverdue = m['onlyOverdue'] ?? false;
        final vi = m['view'];
        if (vi is int && vi >= 0 && vi < _CycleView.values.length) {
          _view = _CycleView.values[vi];
        }
        // الحد مقصود: أقل من ٠.٧ الأرقام مابتتقراش، وأكتر من ١.٦ بيبقى
        // عمودين في الشاشة. ولو القيمة المحفوظة بايظة بنرجع للطبيعي.
        final z = m['zoom'];
        if (z is num && z >= 0.7 && z <= 1.6) _zoom = z.toDouble();
        final mc = m['monthCount'];
        if (mc is int && mc >= 4 && mc <= 24) _monthCount = mc;
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
      'type': _typeFilter,
      'sort': _sort,
      'onlyOverdue': _onlyOverdue,
      'view': _view.index,
      'zoom': _zoom,
      if (_monthCount != null) 'monthCount': _monthCount,
    });
  }

  // التطبيع بقى في محرّك البحث الموحّد (app_search.dart)
  static String _normSearch(String s) => normalizeArabic(s);

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

  // مجموعة بالـ id (من المزوّد) — للاستخدام داخل كشف الشذوذ
  Group? _grpOf(String gid) {
    final groups = context.read<AppProvider>().db.groups;
    final idx = groups.indexWhere((x) => x.id == gid);
    return idx >= 0 ? groups[idx] : null;
  }

  // ── Anomaly detection ────────────────────────────────────────────
  _Anomaly _anomalyOf(CompanyBill bill, List<CompanyBill> allBills) {
    if (bill.actualAmount <= 0) return _Anomaly.none;
    // فاتورة مكررة نفس الشهر لنفس الخط (أولوية عليا — غلط شائع مع الشركات)
    final sameMonth = allBills
        .where((x) => x.groupId == bill.groupId &&
            x.month == bill.month &&
            x.actualAmount > 0)
        .length;
    if (sameMonth > 1) return _Anomaly.sameMonthDuplicate;
    final prevM = _prevMonthOf(bill.month);
    final CompanyBill? prev = allBills.cast<CompanyBill?>().firstWhere(
        (b) => b!.groupId == bill.groupId && b.month == prevM,
        orElse: () => null);
    // إنذار "شهر وشهر": لو الخط نظامه شهر وشهر ونزلت فاتورة في شهر
    // المفروض يكون فاضي (لأن الشهر اللي قبله نزلت فيه فاتورة) → ضرب إنذار.
    final g = _grpOf(bill.groupId);
    if (g != null &&
        g.billingSystem == 'bimonthly' &&
        prev != null &&
        prev.actualAmount > 0) {
      return _Anomaly.unexpectedBimonthly;
    }
    if (prev == null || prev.actualAmount <= 0) return _Anomaly.none;
    // فودافون «سعر متغير»: طبيعي يتغيّر شهرياً → مانضربش إنذار مضاعفة/تكرار
    if (g != null && g.provider == 'vodafone' && g.vodafoneRateType == 'variable') {
      return _Anomaly.none;
    }
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
    final prov = context.read<AppProvider>();
    final m = _targetMonth;
    final q = _normSearch(_search);
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
      // فلتر «فات موعدها بس»
      if (_onlyOverdue) {
        final d = prov.billGraceDaysLeft(b);
        if (d == null || d >= 0) return false;
      }
      // 🔍 محرّك البحث الموحّد — رقم/مالك/اسم الفاتورة/مبلغ/شهر
      if (q.isNotEmpty) {
        if (searchHitsOf(searchTerms(_search), [
              g.phone, g.ownerName ?? '', g.groupInvoiceName ?? '',
              b.actualAmount.toStringAsFixed(0),
              b.paidAmount.toStringAsFixed(0), b.month,
            ]) == null) {
          return false;
        }
      }
      return true;
    }).toList();

    // الترتيب
    int byProv(CompanyBill a, CompanyBill b) {
      final ga = db.groups.firstWhere((x) => x.id == a.groupId,
          orElse: () => Group(id: '', phone: ''));
      final gb = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: ''));
      return (ga.provider ?? '').compareTo(gb.provider ?? '');
    }
    switch (_sort) {
      case 'remaining':
        result.sort((a, b) => b.remaining.compareTo(a.remaining));
        break;
      case 'deadline':
        result.sort((a, b) {
          final da = prov.billGraceDaysLeft(a) ?? 99999;
          final dbb = prov.billGraceDaysLeft(b) ?? 99999;
          return da.compareTo(dbb);
        });
        break;
      case 'recent':
        result.sort((a, b) => b.id.compareTo(a.id));
        break;
      default:
        result.sort(byProv);
    }
    return result;
  }

  // عدّاد الفواتير المتأخرة (فات موعد سماحها) + إجماليها — للعرض في الهيدر
  (int, double) _overdueStats(AppDB db) {
    final prov = context.read<AppProvider>();
    int count = 0;
    double total = 0;
    for (final b in db.companyBills) {
      if (b.month != _targetMonth || b.isPaid) continue;
      final d = prov.billGraceDaysLeft(b);
      if (d != null && d < 0) {
        count++;
        total += b.remaining;
      }
    }
    return (count, total);
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
    final prevM = _prevMonthOf(m);
    return db.groups.where((g) {
      if (g.fixedBillAmount <= 0) return false;
      if (addedGids.contains(g.id)) return false;
      // إخفاء الخطوط الفرعية — هتنزل تلقائياً مع الخط الرئيسي
      if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) return false;
      if (_provFilter != 'all' && g.provider != _provFilter) return false;
      // نظام شهر وشهر: لو الشهر اللي قبله نزلت فيه فاتورة، فالشهر ده
      // المفروض يكون فاضي (ببلاش) — فمنحطّوش في المتوقعة عشان ما نطلعش إنذار غلط.
      if (g.billingSystem == 'bimonthly') {
        final hadPrev = db.companyBills.any(
            (b) => b.groupId == g.id && b.month == prevM && b.actualAmount > 0);
        if (hadPrev) return false;
      }
      return true;
    }).toList();
  }

  // ── فواتير غايبة: خطوط المفروض عليها فاتورة الشهر ده وما نزلتش ──────
  // (للشهر الحالي/الماضي فقط — الشهر القادم بيتعرض في «المتوقعة»)
  List<Group> _missingGroups(AppDB db) {
    if (_period == _Period.next) return [];
    if (_typeFilter == 'actual' || _typeFilter == 'paid') return [];
    final m = _targetMonth;
    final addedGids = db.companyBills
        .where((b) => b.month == m)
        .map((b) => b.groupId)
        .toSet();
    final prevM = _prevMonthOf(m);
    // الشهر الحالي: نوري كل الخطوط (حتى اللي من غير مبلغ ثابت مسجّل مقدّماً)
    // عشان الشاشة تبقى جدول شامل تكتب فيه المبلغ مباشرة، مش بس تذكير.
    final requireFixed = _period != _Period.current;
    return db.groups.where((g) {
      if (requireFixed && g.fixedBillAmount <= 0) return false;
      if (addedGids.contains(g.id)) return false;
      if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) return false;
      if (_provFilter != 'all' && g.provider != _provFilter) return false;
      // نظام شهر وشهر: في الشهر الماضي بنستبعدها لو الشهر ده المفروض فاضي
      // (بلاش تشتيت)؛ في الشهر الحالي بنسيبها تظهر بس معلّمة "مجاني" (بدل الإخفاء).
      if (!requireFixed) return true;
      if (g.billingSystem == 'bimonthly') {
        final hadPrev = db.companyBills.any(
            (b) => b.groupId == g.id && b.month == prevM && b.actualAmount > 0);
        if (hadPrev) return false;
      }
      return true;
    }).toList();
  }

  bool _isBimonthlyFreeThisMonth(Group g, AppDB db) {
    if (g.billingSystem != 'bimonthly') return false;
    final prevM = _prevMonthOf(_targetMonth);
    return db.companyBills.any(
        (b) => b.groupId == g.id && b.month == prevM && b.actualAmount > 0);
  }

  /// مش دور الخط ده الشهر ده.
  ///
  /// لو الخط متعلّم عليه (فيه مرساة دورة) بنمشي بالمرساة وخلاص — دي أدق
  /// حاجة عندنا وانت اللي كاتبها بإيدك. لو لأ بنرجع للاستنتاج القديم من
  /// تاريخ الفواتير وحسابات الشقّين، زي ما كان بالظبط.
  bool _isNotDueThisMonth(Group g, AppDB db, AppProvider prov) {
    final byAnchor = g.isDueIn(_targetMonth);
    if (byAnchor != null) return !byAnchor;
    if (_isBimonthlyFreeThisMonth(g, db)) return true;
    return !prov.isGroupDueForBilling(g.id, _targetMonth);
  }

  double? _lastMonthAmount(Group g, AppDB db) {
    final prevM = _prevMonthOf(_targetMonth);
    final bill = db.companyBills.cast<CompanyBill?>().firstWhere(
        (b) => b!.groupId == g.id && b.month == prevM && b.actualAmount > 0,
        orElse: () => null);
    return bill?.actualAmount;
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

  // ── ملخص الشهر: المتوقع مقابل الفعلي مقابل الناقص ──────────────────
  ({int expectedCount, int billedCount, int missingCount, double expectedTotal, double actualTotal})
      _monthlyStats(AppDB db, AppProvider prov) {
    final m = _targetMonth;
    final billedGids =
        db.companyBills.where((b) => b.month == m).map((b) => b.groupId).toSet();
    var expectedCount = 0, billedCount = 0, missingCount = 0;
    double expectedTotal = 0;
    for (final g in db.groups) {
      if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) continue;
      if (g.fixedBillAmount <= 0) continue;
      // 📌 «متوقع» = مجموع الخطوط اللي دورها الشهر ده بس. كان بيجمع كل
      // خطوط الحساب، فالملخص كان بيقول رقم أعلى من اللي الكارت نفسه
      // بيعرضه — رقمين مختلفين لنفس الحاجة على نفس الشاشة.
      final dueTotal = prov.expectedAccountAmount(g.id, m);
      if (dueTotal <= 0) continue;
      expectedCount++;
      expectedTotal += dueTotal;
      if (billedGids.contains(g.id)) {
        billedCount++;
      } else {
        missingCount++;
      }
    }
    final actualTotal = db.companyBills
        .where((b) => b.month == m && b.isActual)
        .fold(0.0, (s, b) => s + b.actualAmount);
    return (
      expectedCount: expectedCount,
      billedCount: billedCount,
      missingCount: missingCount,
      expectedTotal: expectedTotal,
      actualTotal: actualTotal,
    );
  }

  Widget _monthlySummaryPanel(AppDB db, AppProvider prov) {
    final s = _monthlyStats(db, prov);
    if (s.expectedCount == 0) return const SizedBox.shrink();
    final fullyReconciled = s.missingCount == 0;
    final delta = s.actualTotal - s.expectedTotal;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // الدوسة على العنوان بتفتح تقرير الفروق — «دفعت زيادة كام؟»
        // من غير ما تفتح كل فاتورة وتقارن بإيدك.
        InkWell(
          onTap: () =>
              _CycleSheets.openDiffReport(context, prov, _targetMonth),
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            Text('📊 ملخص ${_monthLabel(_targetMonth)}',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppColors.blue2)),
            const SizedBox(width: 5),
            Text('— شوف الفروق',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                    decoration: TextDecoration.underline)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _statTile('متوقع', '${s.expectedCount} خط', '${s.expectedTotal.toStringAsFixed(0)} ج',
              AppColors.blueLight, AppColors.blue2),
          const SizedBox(width: 6),
          _statTile('نزل فعلي', '${s.billedCount} خط', '${s.actualTotal.toStringAsFixed(0)} ج',
              AppColors.greenLight, AppColors.green2),
          const SizedBox(width: 6),
          _statTile('لسه ناقص', '${s.missingCount} خط', '',
              s.missingCount > 0 ? AppColors.redLight : const Color(0xFFF5F5F5),
              s.missingCount > 0 ? AppColors.red2 : AppColors.muted),
        ]),
        if (fullyReconciled && s.expectedTotal > 0) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: delta.abs() < 1
                  ? AppColors.greenLight
                  : (delta > 0 ? AppColors.redLight : AppColors.blueLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              delta.abs() < 1
                  ? '✅ الفعلي مطابق للمتوقع'
                  : (delta > 0
                      ? '⚠️ دفعت زيادة ${delta.toStringAsFixed(0)} ج عن المتوقع'
                      : 'ℹ️ دفعت أقل بـ ${(-delta).toStringAsFixed(0)} ج عن المتوقع'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: delta.abs() < 1
                      ? AppColors.green2
                      : (delta > 0 ? AppColors.red2 : AppColors.blue2)),
            ),
          ),
        ],

        // ── 🔮 توقّع الربح ──────────────────────────────────────
        // الملخص فوق بيقول «هيتشال منك كام». ده بيقول «هيفضل معاك كام» —
        // وهو الرقم اللي بيهمّك فعلاً.
        _profitForecastRow(db),

        // ── 🧾 الشركة عليها لك كام ───────────────────────────
        _disputesRow(db),

        // ── 📈 الشركة رفعت السعر؟ ────────────────────────────
        _priceIncreaseRow(db, prov),
      ]),
    );
  }

  /// 🔮 ربحك الشهر ده والشهر الجاي.
  ///
  /// الربح بيتحسب على **أساس الربح** (تكلفة الشهر الواحد) فهو مستوي على
  /// طول الشهور ومابيقفزش مع دورة «شهر وشهر». عشان كده لو الشهرين طلعوا
  /// نفس الرقم مابنعرضش الشهر الجاي أصلاً — رقم متكرر مالوش لازمة.
  Widget _profitForecastRow(AppDB db) {
    final next = _nextMonthOf(_targetMonth);
    final now = db.profitForecast(_targetMonth, db.rentals);
    final soon = db.profitForecast(next, db.rentals);
    if (now == 0 && soon == 0) return const SizedBox.shrink();
    final changed = (soon - now).abs() >= 1;
    final reasons = changed
        ? db.profitForecastReasons(_targetMonth, next)
        : const <({String reason, double delta})>[];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: reasons.isEmpty ? null : () => _showForecastReasons(next, reasons),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔮 ربحك في ${_monthLabel(_targetMonth)}',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted)),
                  if (changed)
                    Text(
                      'الشهر الجاي ${soon.toStringAsFixed(0)} ج — '
                      '${soon > now ? 'أحسن' : 'أقل'} بـ '
                      '${(soon - now).abs().toStringAsFixed(0)} ج · دوس تعرف ليه',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: soon > now ? AppColors.green2 : AppColors.orange),
                    )
                  else
                    Text('الشهر الجاي زيه — مفيش حاجة بتتغيّر',
                        style: GoogleFonts.cairo(
                            fontSize: 10, color: AppColors.muted)),
                  // 🎫 القسايم — فلوس حقيقية بس بتنزل كل ٦ شهور أو سنة،
                  // فبتتوزّع على الشهور. رقم زيادة، مش بديل.
                  if (db.voucherMonthlyTotal(_targetMonth) > 0)
                    Text(
                      'ومعاهم ${db.voucherMonthlyTotal(_targetMonth).toStringAsFixed(0)} ج '
                      'قسايم موزّعة → الحقيقي '
                      '${db.realProfitForecast(_targetMonth, db.rentals).toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue2),
                    ),
                ],
              ),
            ),
            Text('${now.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: now >= 0 ? AppColors.green2 : AppColors.red2)),
          ]),
        ),
      ),
    );
  }

  /// 🧾 مجموع اللي انت مطالب بيه الشركة — مفيش غيره بيلمّه في رقم واحد.
  ///
  /// من غير الرقم ده، المطالبات بتفضل متفرّقة على فواتير كتير ومحدش
  /// بيتابعها، فتضيع فلوس انت أصلاً سجّلتها بإيدك.
  Widget _disputesRow(AppDB db) {
    final total = db.totalOpenDisputes;
    if (total <= 0) return const SizedBox.shrink();
    final byLine = db.disputesByLine();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _showDisputesBreakdown(db, byLine, total),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.orangeLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🧾 الشركة عليها لك',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange)),
                  Text(
                      '${db.openDisputeCount} فاتورة في ${byLine.length} خط · '
                      'دوس تشوف التفصيل',
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.orange)),
                ],
              ),
            ),
            Text('${total.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.orange)),
          ]),
        ),
      ),
    );
  }

  void _showDisputesBreakdown(
      AppDB db,
      List<({Group group, double amount, int count})> byLine,
      double total) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('الشركة عليها لك ${total.toStringAsFixed(0)} ج',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ⚖️ مجمّع لكل شركة ─────────────────────────
                // ده الرقم اللي بتقف بيه قدام الشركة. التفصيل بالخط تحته
                // عشان لما يسألوك «فين؟» تلاقي الأرقام جاهزة.
                for (final r in db.disputesByProvider())
                  if (r.open > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '${_providerLabel(r.provider)} · ${r.count} فاتورة'
                            // اللي اتحلّ بيبان عشان تعرف إن المراجعة بتجيب
                            // نتيجة فعلاً — مش بتضيع.
                            '${r.resolved > 0 ? ' · اتحلّ ${r.resolved.toStringAsFixed(0)} ج قبل كده' : ''}',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text),
                          ),
                        ),
                        Text('${r.open.toStringAsFixed(0)} ج',
                            style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.orange)),
                      ]),
                    ),
                const Divider(height: 16),
                Text('التفصيل بالخط:',
                    style: GoogleFonts.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted)),
                for (final e in byLine)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.group.phone,
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text)),
                            Text('${e.count} فاتورة',
                                style: GoogleFonts.cairo(
                                    fontSize: 10, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Text('${e.amount.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange)),
                    ]),
                  ),
                const SizedBox(height: 8),
                Text(
                  'دي الأرقام اللي انت كاتبها بإيدك على الفواتير الغلط. '
                  'أول ما الشركة تعوّضك، افتح الفاتورة وعلّم إن المطالبة اتقفلت.',
                  style:
                      GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted),
                ),
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


  static String _providerLabel(String p) => switch (p) {
        'vodafone' => 'فودافون',
        'etisalat' => 'اتصالات',
        'orange' => 'أورنچ',
        'we' => 'وي',
        _ => p,
      };

  /// 📈 الشركة رفعت سعر خطوط؟
  ///
  /// بيبان بس لما **آخر فاتورتين** على الخط يبقوا أعلى من المسجّل وبنفس
  /// الرقم — فاتورة واحدة عالية غلطة، مش رفع سعر.
  Widget _priceIncreaseRow(AppDB db, AppProvider prov) {
    final ups = db.priceIncreaseSuspects();
    if (ups.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _showPriceIncreases(ups, prov),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.redLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.trending_up, size: 18, color: AppColors.red2),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📈 ${ups.length} خط شكل الشركة رفعت سعرهم',
                      style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.red2)),
                  Text('آخر فاتورتين أعلى من المسجّل · دوس تظبّطهم',
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.red2)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showPriceIncreases(
      List<({Group group, double oldPrice, double newPrice})> ups,
      AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('الشركة رفعت السعر؟',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 14)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الخطوط دي آخر فاتورتين عليها نزلوا أعلى من الرقم اللي '
                    'انت مسجّله — يعني على الأغلب ده بقى السعر الجديد.\n\n'
                    'لو ظبّطت الرقم، التقدير هيبقى صح. الربح هيتأثر لأن '
                    'التكلفة زادت فعلاً.',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  for (final u in ups)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.group.phone,
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text)),
                              Text(
                                  '${u.oldPrice.toStringAsFixed(0)} ← '
                                  '${u.newPrice.toStringAsFixed(0)} ج',
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.cairo(
                                      fontSize: 10.5, color: AppColors.red2)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            prov.setGroupFixedBill(u.group.id, u.newPrice);
                            setLocal(() {});
                          },
                          child: Text('ظبّط',
                              style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.blue2)),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('تمام', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForecastReasons(
      String month, List<({String reason, double delta})> reasons) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('ليه ${_monthLabel(month)} مختلف؟',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text(r.reason,
                            style: GoogleFonts.cairo(
                                fontSize: 12, color: AppColors.text)),
                      ),
                      Text(
                        '${r.delta > 0 ? '+' : ''}${r.delta.toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: r.delta > 0
                                ? AppColors.green2
                                : AppColors.orange),
                      ),
                    ]),
                  ),
                const SizedBox(height: 10),
                Text(
                  'ده لو مافيش عميل جديد ولا خارج. البرنامج مابيتوقعش '
                  'العملاء — بيحسب اللي هو عارفه بس.',
                  style:
                      GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted),
                ),
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

  Widget _statTile(String label, String primary, String secondary, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(primary, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: fg)),
          if (secondary.isNotEmpty)
            Text(secondary, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
          Text(label, style: GoogleFonts.cairo(fontSize: 9, color: fg.withValues(alpha: 0.8))),
        ]),
      ),
    );
  }

  // ── متأخرات من شهور سابقة (مش بس الشهر المعروض دلوقتي) ──────────────
  List<(Group, String)> _overdueAcrossMonths(AppDB db, AppProvider prov) {
    final results = <(Group, String)>[];
    final now = DateTime.now();
    for (var i = 1; i <= 3; i++) {
      final d = DateTime(now.year, now.month - i);
      final m = _monthKey(d);
      final billedGids =
          db.companyBills.where((b) => b.month == m).map((b) => b.groupId).toSet();
      for (final g in db.groups) {
        if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) continue;
        if (g.fixedBillAmount <= 0) continue;
        if (billedGids.contains(g.id)) continue;
        if (!prov.isGroupDueForBilling(g.id, m)) continue;
        results.add((g, m));
      }
    }
    return results;
  }

  Widget _overdueAcrossMonthsBanner(AppDB db, AppProvider prov) {
    final overdue = _overdueAcrossMonths(db, prov);
    if (overdue.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _showOverdueAcrossMonthsSheet(context, prov, overdue),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Text('🔴', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${overdue.length} فاتورة متأخرة من شهور سابقة — دوس للمراجعة',
                style: GoogleFonts.cairo(
                    fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.red2)),
          ),
          Icon(Icons.chevron_left, color: AppColors.red2, size: 18),
        ]),
      ),
    );
  }

  void _showOverdueAcrossMonthsSheet(
      BuildContext context, AppProvider prov, List<(Group, String)> overdue) {
    showAppSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('🔴 متأخرات من شهور سابقة (${overdue.length})',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: overdue.length,
                  itemBuilder: (_, i) {
                    final (g, m) = overdue[i];
                    return _ExpectedCard(
                      group: g,
                      month: m,
                      prov: prov,
                      lastMonthAmount: _lastMonthAmount(g, prov.db),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
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

    final hasContent = bills.isNotEmpty ||
        expected.isNotEmpty ||
        _missingGroups(db).isNotEmpty ||
        _overdueAcrossMonths(db, prov).isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      // ⌨️ سهم يمين/شمال بينقّل بين الشهور من الكيبورد.
      //
      // ⚠️ الشاشة عربية (RTL) — فالسهم اللي **على اليمين** معناه رجوع
      // للشهر اللي قبله، عكس الإنجليزي. لو عكسناهم، كل ضغطة هتوديك
      // ناحية غير اللي شايفها في الشاشة.
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowRight): _PrevMonthIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _NextMonthIntent(),
        },
        child: Actions(
          actions: {
            _PrevMonthIntent: CallbackAction<_PrevMonthIntent>(
              onInvoke: (_) {
                if (_period != _Period.last) {
                  setState(() => _period = _Period.values[_period.index - 1]);
                }
                return null;
              },
            ),
            _NextMonthIntent: CallbackAction<_NextMonthIntent>(
              onInvoke: (_) {
                if (_period != _Period.next) {
                  setState(() => _period = _Period.values[_period.index + 1]);
                }
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            // ListView واحدة للشاشة كلها (هيدر + كل الأقسام) بدل
            // Column+Expanded ثابت عشان لو محتوى الهيدر زاد (ملخص/تنبيهات)
            // الشاشة تتمرجل بدل ما تفيض (overflow).
            child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context, prov, db, bills.length, expected.length,
              totalActual, totalUnpaid, anomalyCount),
          _monthlySummaryPanel(db, prov),
          if (prov.isBillMonthLocked(_targetMonth))
            _lockedMonthBanner()
          else
            _monthDoneRow(prov, db),
          _overdueAcrossMonthsBanner(db, prov),
          _buildPeriodSelector(),
          _ViewSwitcher(
            value: _view,
            onChanged: (v) => _set(() => _view = v),
          ),
          // 🔁 الشركة نزّلت فاتورتين ورا بعض؟ — أخطر غلط وبيبان الأول
          _consecutiveBillsBanner(prov),
          // 🔍 شريط المراجعة — بيظهر بس لما يكون فيه بيانات محتاجة نظرة
          _dataAuditBanner(prov),
          _buildSearchSortRow(),
          _buildProviderChips(),
          // فلاتر النوع (تقديرية/فعلية/مسددة) بتخصّ الكروت بس — العروض
          // التانية بتتفرّج على الدورة نفسها مش على حالة الفاتورة.
          if (_view == _CycleView.cards) _buildTypeChips(),

          // 🔁 العروض الأربعة الجديدة — كلها بتقرا نفس المنطق، بس بشكل تاني
          if (_view != _CycleView.cards)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              child: switch (_view) {
                _CycleView.accounts => _AccountsView(
                    prov: prov,
                    month: _targetMonth,
                    provFilter: _provFilter,
                    search: _search),
                _CycleView.grid => _GridView(
                    prov: prov,
                    month: _targetMonth,
                    provFilter: _provFilter,
                    search: _search,
                    zoom: _zoom,
                    onZoom: (z) => _set(() => _zoom = z),
                    monthCount: _monthCount,
                    onMonthCount: (n) => _set(() => _monthCount = n)),
                _CycleView.bars => _BarsView(
                    prov: prov,
                    month: _targetMonth,
                    provFilter: _provFilter,
                    search: _search),
                _CycleView.month => _MonthView(
                    prov: prov,
                    month: _targetMonth,
                    provFilter: _provFilter,
                    search: _search),
                _CycleView.cards => const SizedBox.shrink(),
              },
            )
          else if (!hasContent)
            SizedBox(height: 300, child: _emptyState())
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              child: Column(children: [
                _overdueBanner(db),
                _missingSection(db, prov),
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
                  ResponsiveRowGroup(children: [
                    for (final g in expected)
                      _ExpectedCard(group: g, month: _targetMonth, prov: prov),
                  ]),
                  const SizedBox(height: 6),
                ],
                // Bills grouped by provider
                for (final entry in grouped.entries) ...[
                  if (grouped.length > 1 || expected.isNotEmpty)
                    _provSectionHeader(entry.key, entry.value, db),
                  // 📐 الكروت جنب بعض على التاب والكمبيوتر. عنوان الشركة
                  // بيفضل بعرض الشاشة كله عشان يفصل بين الأقسام بوضوح،
                  // والكروت اللي تحته بس هي اللي بتتقسم أعمدة.
                  ResponsiveRowGroup(children: [
                    for (final b in entry.value)
                      _AuditCard(
                        bill: b,
                        db: db,
                        prov: prov,
                        anomaly: _anomalyOf(b, db.companyBills),
                      ),
                  ]),
                ],
              ]),
            ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  /// ✅ «الشهر ده خلص» — بيجاوب على سؤال بتسأله كل شهر.
  ///
  /// قفل الشهر كان موجود، بس مدفون في منيو الـ ⋯. فكنت لازم تفتكر إنه
  /// موجود، وتفتكر تدوس عليه، وقبل كده تعرف انت خلّصت ولا لأ — يعني
  /// تعدّ الفواتير الناقصة بعينك.
  ///
  /// السطر ده بيقول لك **انت واقف فين** وبيدّيك الزرار في نفس المكان.
  Widget _monthDoneRow(AppProvider prov, AppDB db) {
    // الشهر الجاي لسه ما نزلش — مالوش معنى نقول «خلص».
    if (_period == _Period.next) return const SizedBox.shrink();
    final missing = _missingGroups(db).length;

    final done = missing == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: done ? AppColors.greenLight : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: done ? AppColors.green2 : AppColors.border),
        ),
        child: Row(children: [
          Icon(done ? Icons.task_alt : Icons.pending_actions,
              size: 17, color: done ? AppColors.green2 : AppColors.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              done
                  ? 'كل فواتير ${_monthLabel(_targetMonth)} اتسجّلت'
                  : 'لسه $missing فاتورة ما اتسجّلتش في '
                      '${_monthLabel(_targetMonth)}',
              style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: done ? AppColors.green2 : AppColors.muted),
            ),
          ),
          // الزرار بيبان في الحالتين — ساعات بتقفل الشهر وانت عارف إن
          // فاتورة مش هتنزل خالص، فما ينفعش نمنعك.
          TextButton(
            onPressed: () => _toggleMonthLock(context, prov),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('الشهر ده خلص',
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: done ? AppColors.green2 : AppColors.blue2)),
          ),
        ]),
      ),
    );
  }

  /// 🔁 تنبيه: خطوط «شهر وشهر» نزلت لها فواتير في شهرين ورا بعض.
  ///
  /// ده بالظبط اللي بتخاف منه — الشركة تنزّل فاتورتين ورا بعض. البرنامج
  /// بيمسكها من تاريخ الفواتير المسجّل، مش محتاج تدوّر انت.
  ///
  /// الشهور اللي علّمتها استثناء بإيدك مابتتحسبش هنا — انت عارفها وموافق.
  Widget _consecutiveBillsBanner(AppProvider prov) {
    final issues = prov.allConsecutiveBillIssues();
    if (issues.isEmpty) return const SizedBox.shrink();
    final total = issues.values.fold<int>(0, (s, v) => s + v.length);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red2),
      ),
      child: Row(children: [
        Icon(Icons.repeat_on_rounded, size: 17, color: AppColors.red2),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🔁 $total فاتورة نزلت في شهرين ورا بعض',
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.red2),
              ),
              Text(
                'على ${issues.length} خط نظامهم شهر وشهر — يا إما الشركة '
                'غلطت يا إما اتسجّلت مرتين. راجعهم.',
                style: GoogleFonts.cairo(
                    fontSize: 9.5, color: AppColors.red2),
              ),
              const SizedBox(height: 3),
              for (final e in issues.entries.take(4))
                Builder(builder: (_) {
                  final g = prov.db.groups
                      .where((x) => x.id == e.key)
                      .firstOrNull;
                  if (g == null) return const SizedBox.shrink();
                  return Text(
                    '• ${g.phone}: ${e.value.map(_monthLabel).join(' • ')}',
                    style: GoogleFonts.cairo(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red2),
                  );
                }),
              if (issues.length > 4)
                Text('… و${issues.length - 4} خط كمان',
                    style: GoogleFonts.cairo(
                        fontSize: 9, color: AppColors.red2)),
            ],
          ),
        ),
      ]),
    );
  }

  /// 🔍 شريط مراجعة البيانات — «الأرقام دي مظبوطة ولا في غلط؟».
  ///
  /// بيظهر بس لما يكون فيه خط بيانته ناقصة أو رقمه شكله نص فاتورة، وبيختفي
  /// لوحده لما تخلّص. عشان ما تقعدش تشك في كل رقم قدامك.
  Widget _dataAuditBanner(AppProvider prov) {
    final bad = prov.linesWithBillIssues();
    if (bad.isEmpty) return const SizedBox.shrink();
    final halved = bad
        .where((g) => prov.billIssuesOf(g).contains(AppProvider.kBillIssueHalved))
        .length;

    return GestureDetector(
      onTap: () => _CycleSheets.openAudit(context, prov, _targetMonth),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: halved > 0 ? AppColors.orangeLight : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: halved > 0 ? AppColors.orange : AppColors.border),
        ),
        child: Row(children: [
          Icon(halved > 0 ? Icons.warning_amber_rounded : Icons.fact_check_outlined,
              size: 17,
              color: halved > 0 ? AppColors.orange : AppColors.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              halved > 0
                  ? '$halved خط رقمهم شكله نص الفاتورة — التوقّع بيطلع ناقص'
                  : '${bad.length} خط بياناتهم ناقصة — اضغط للمراجعة',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: halved > 0 ? AppColors.orange : AppColors.muted),
            ),
          ),
          Icon(Icons.chevron_left,
              size: 17,
              color: halved > 0 ? AppColors.orange : AppColors.muted),
        ]),
      ),
    );
  }

  Widget _lockedMonthBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text('مراجعة ${_monthLabel(_targetMonth)} مقفولة — أي تعديل هيطلب تأكيد',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ),
      ]),
    );
  }

  void _toggleMonthLock(BuildContext ctx, AppProvider prov) {
    final month = _targetMonth;
    final locked = prov.isBillMonthLocked(month);
    if (locked) {
      prov.toggleBillMonthLock(month);
      return;
    }
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🔒 قفل مراجعة ${_monthLabel(month)}؟',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
        content: Text(
            'بعد القفل، أي إضافة أو تعديل لفواتير الشهر ده هيطلب تأكيد إضافي عشان تتجنب تعديل غلط بعد ما تكون خلّصت المراجعة.',
            style: GoogleFonts.cairo(fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              prov.toggleBillMonthLock(month);
              Navigator.pop(context);
            },
            child: Text('قفل المراجعة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showArchives(BuildContext ctx, AppProvider prov) {
    final archives = prov.db.billArchives;
    showDialog(
      context: ctx,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🗄 أرشيف الشهور المقفولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: SizedBox(
            width: double.maxFinite,
            child: archives.isEmpty
                ? Text('لسه مفيش شهور اتقفلت (اقفل مراجعة شهر عشان يتحفظ هنا تلقائي).',
                    style: GoogleFonts.cairo(fontSize: 12))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final a in archives)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_monthLabel(a['month']),
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                'متوقع ${a['expectedCount']} خط (${(a['expectedTotal'] as num).toStringAsFixed(0)} ج) — '
                                'نزل ${a['billedCount']} — ناقص ${a['missingCount']} — '
                                'فعلي: ${(a['actualTotal'] as num).toStringAsFixed(0)} ج',
                                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق', style: GoogleFonts.cairo())),
          ],
        ),
      ),
    );
  }

  void _showMistakesReport(BuildContext ctx, AppProvider prov) {
    final counts = prov.providerAnomalyCounts(prov.db.companyBills);
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    showDialog(
      context: ctx,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('📊 تقرير أخطاء الشركات',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: SizedBox(
            width: double.maxFinite,
            child: entries.isEmpty
                ? Text('مفيش شذوذ متسجل لحد دلوقتي 🎉', style: GoogleFonts.cairo(fontSize: 13))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Text(MainLine.providerEmojis[e.key] ?? '📡'),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(MainLine.providerNames[e.key] ?? e.key,
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppColors.redLight, borderRadius: BorderRadius.circular(8)),
                              child: Text('${e.value} خطأ',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.red2)),
                            ),
                          ]),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق', style: GoogleFonts.cairo())),
          ],
        ),
      ),
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
      decoration: BoxDecoration(gradient: AppColors.headerGradient),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(children: [
        Row(children: [
          const Text('🧾', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'مراجعة فواتير الشركات',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900),
            ),
          ),
          // الإضافة = الزرار الأساسي
          _addBillBtn(ctx, prov, db),
          const SizedBox(width: 6),
          // باقي الأدوات في قائمة ⋮ عشان متزحمش الهيدر
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
            ),
            onSelected: (v) {
              switch (v) {
                case 'generate': _showGenerateDialog(ctx, prov); break;
                case 'rotation': _showRotationDialog(ctx, prov); break;
                case 'export':   ExportService.exportInvoicesExcel(ctx, prov); break;
                case 'statement': ExportService.exportCompanyStatements(ctx, prov); break;
                case 'compare':  _showMonthlyComparison(ctx, prov); break;
                case 'mistakes': _showMistakesReport(ctx, prov); break;
                case 'archive':  _showArchives(ctx, prov); break;
                case 'lock':     _toggleMonthLock(ctx, prov); break;
              }
            },
            itemBuilder: (_) => [
              _menuItem('generate', Icons.autorenew, 'جهّز فواتير الشهر'),
              _menuItem('rotation', Icons.sync, 'تدوير شهر وشهر'),
              _menuItem('export', Icons.table_view, 'تصدير Excel'),
              // ورقة لكل شركة — ده اللي بتروح بيه تراجع معاهم
              _menuItem('statement', Icons.receipt_long, 'كشف حساب الشركات'),
              _menuItem('compare', Icons.bar_chart, 'مقارنة شهرية'),
              _menuItem('mistakes', Icons.report_gmailerrorred, 'تقرير أخطاء الشركات'),
              _menuItem('archive', Icons.archive_outlined, 'أرشيف الشهور المقفولة'),
              _menuItem(
                'lock',
                prov.isBillMonthLocked(_targetMonth) ? Icons.lock_open : Icons.lock_outline,
                prov.isBillMonthLocked(_targetMonth)
                    ? 'فتح قفل مراجعة الشهر'
                    : 'قفل مراجعة الشهر',
              ),
            ],
          ),
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

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.blue2),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );

  void _showRotationDialog(BuildContext ctx, AppProvider prov) {
    final month = _targetMonth;
    final (billing, free) = prov.bimonthlyRotation(month);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🔄 تدوير شهر وشهر — ${_monthLabel(month)}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: (billing.isEmpty && free.isEmpty)
            ? Text('مفيش خطوط على نظام «شهر وشهر».',
                style: GoogleFonts.cairo(fontSize: 13))
            : SizedBox(
                width: double.maxFinite,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('عرض فقط — مايغيّرش أي مبلغ.',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        _rotSection('🧾 دورهم فاتورة الشهر ده', billing,
                            AppColors.redLight, AppColors.red2),
                        const SizedBox(height: 8),
                        _rotSection('🆓 فاضي ببلاش الشهر ده', free,
                            AppColors.greenLight, const Color(0xFF00695c)),
                      ]),
                    ),
                  ),
                ]),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('تمام', style: GoogleFonts.cairo())),
        ],
      ),
    );
  }

  Widget _rotSection(String title, List<Group> groups, Color bg, Color fg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title (${groups.length})',
            style: GoogleFonts.cairo(
                fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
        if (groups.isNotEmpty) const SizedBox(height: 4),
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
                '• ${g.phone}${g.ownerName != null && g.ownerName!.isNotEmpty ? " — ${g.ownerName}" : ""}',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.text)),
          ),
      ]),
    );
  }

  void _showGenerateDialog(BuildContext ctx, AppProvider prov) {
    final month = _targetMonth;
    final n = prov.previewMonthlyBillsCount(month);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🔁 توليد فواتير ${_monthLabel(month)}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(
          n == 0
              ? 'مفيش خطوط محتاجة فاتورة للشهر ده — كله متسجّل أو فاضي (شهر وشهر).'
              : 'هيتعمل $n فاتورة تقديرية (بالمبلغ الثابت) للخطوط اللي لسه ما اتسجّلش لها فاتورة الشهر ده.\n\n'
                  '• الخطوط الفرعية بتتجمّع مع الرئيسي.\n'
                  '• خطوط «شهر وشهر» اللي المفروض فاضية بتتخطّى.\n'
                  '• تقدر تأكّد الفعلي بعدين لكل فاتورة.',
          style: GoogleFonts.cairo(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          if (n > 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue2),
              onPressed: () {
                final created = prov.generateMonthlyBills(month);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  backgroundColor: AppColors.green,
                  content: Text('تم توليد $created فاتورة ✅',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ));
              },
              child: Text('توليد $n فاتورة',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // مقارنة شهرية لإجمالي فواتير كل شركة (آخر 6 شهور) + فرق الشهر الأخير
  void _showMonthlyComparison(BuildContext ctx, AppProvider prov) {
    final data = prov.providerMonthlySpend(months: 6);
    final now = DateTime.now();
    final keys = <String>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      keys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    showAppSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: BoxDecoration(
            // كانت لون ثابت فاتح — يعني في الوضع الليلي شيت أبيض
            // بنص أبيض. بتتغيّر مع الثيم دلوقتي.
            color: AppColors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                Icon(Icons.bar_chart, color: AppColors.blue2),
                const SizedBox(width: 8),
                Text('مقارنة المصروف الشهري لكل شركة',
                    style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900)),
              ]),
            ),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Text('مفيش فواتير كفاية للمقارنة',
                    style: GoogleFonts.cairo(color: AppColors.muted)),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                  children: [
                    // 📊 المتوقع ضد اللي نزل — فوق المقارنة لأنه بيجاوب
                    // على «الشركة غلطت فين؟» وده السؤال الأهم.
                    ExpectedActualChart(db: prov.db, months: 8),
                    const SizedBox(height: 12),
                    for (final entry in data.entries)
                      _comparisonCard(entry.key, entry.value, keys),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _comparisonCard(String provider, Map<String, double> byMonth, List<String> keys) {
    final name = MainLine.providerNames[provider] ?? provider;
    final emoji = MainLine.providerEmojis[provider] ?? '📡';
    final color = MainLine.providerColors[provider] ?? AppColors.blue;
    final maxV = byMonth.values.fold<double>(1, (a, b) => a > b ? a : b);
    final lastK = keys.last;
    final prevK = keys.length > 1 ? keys[keys.length - 2] : keys.last;
    final last = byMonth[lastK] ?? 0;
    final prev = byMonth[prevK] ?? 0;
    final delta = last - prev;
    final up = delta > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$emoji $name',
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          const Spacer(),
          if (prev > 0 || last > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (up ? AppColors.redLight : AppColors.greenLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                delta == 0
                    ? 'ثابت'
                    : '${up ? '🔺 زاد' : '🔻 قلّ'} ${delta.abs().toStringAsFixed(0)} ج عن الشهر اللي فات',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: up ? AppColors.red2 : const Color(0xFF2E7D32)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: keys.map((k) {
              final v = byMonth[k] ?? 0;
              final h = (v / maxV * 64).clamp(2, 64).toDouble();
              final mm = k.split('-');
              return Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(v.toStringAsFixed(0),
                      style: GoogleFonts.cairo(fontSize: 8, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Container(
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 3),
                  Text(mm.length > 1 ? 'ش${mm[1]}' : '',
                      style: GoogleFonts.cairo(fontSize: 8, color: AppColors.muted)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
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
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(children: [
        // ⌨️ سهم يمين/شمال بينقّل بين الشهور — على الكمبيوتر بتفضل
        // بتراجع شهر ورا شهر، والوصول للماوس كل مرة بيبطّأك.
        if (context.isWide) ...[
          _MonthArrow(
            icon: Icons.chevron_right,
            tip: 'الشهر اللي قبله',
            onTap: _period == _Period.last
                ? null
                : () => setState(() => _period =
                    _Period.values[_period.index - 1]),
          ),
          const SizedBox(width: 4),
        ],
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
        if (context.isWide) ...[
          const SizedBox(width: 4),
          _MonthArrow(
            icon: Icons.chevron_left,
            tip: 'الشهر اللي بعده',
            onTap: _period == _Period.next
                ? null
                : () => setState(
                    () => _period = _Period.values[_period.index + 1]),
          ),
        ],
      ]),
    );
  }

  // ── Search + Sort + Overdue filter row ─────────────────────────────
  Widget _buildSearchSortRow() {
    const sortLabels = {
      'default': 'الترتيب: الشركة',
      'remaining': 'الأعلى متبقّي',
      'deadline': 'الأقرب موعداً',
      'recent': 'الأحدث',
    };
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: AppSearchBar(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              hint: '🔍 رقم الخط · الاسم · المبلغ · الشهر',
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFf0f4f8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sort,
                isDense: true,
                icon: const Icon(Icons.sort, size: 18),
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.text, fontWeight: FontWeight.w700),
                items: sortLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: GoogleFonts.cairo(fontSize: 11))))
                    .toList(),
                onChanged: (v) => _set(() => _sort = v ?? 'default'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _set(() => _onlyOverdue = !_onlyOverdue),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _onlyOverdue ? AppColors.red2 : const Color(0xFFf0f4f8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 15, color: _onlyOverdue ? Colors.white : AppColors.red2),
                const SizedBox(width: 4),
                Text('متأخرة',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _onlyOverdue ? Colors.white : AppColors.red2)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  // عدّاد كلي للفواتير المتأخرة (فات موعد سماحها)
  Widget _overdueBanner(AppDB db) {
    final (count, total) = _overdueStats(db);
    if (count == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() {
        _onlyOverdue = true;
        _sort = 'deadline';
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF9A9A)),
        ),
        child: Row(children: [
          const Text('🔴', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count فاتورة فات موعد دفعها — إجمالي ${total.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFC62828)),
            ),
          ),
          const Icon(Icons.chevron_left, color: Color(0xFFC62828), size: 20),
        ]),
      ),
    );
  }

  // ── قسم الفواتير الغايبة (منطوي) — خطوط المفروض عليها فاتورة وما نزلتش ──
  Widget _missingSection(AppDB db, AppProvider prov) {
    final missing = _missingGroups(db);
    if (missing.isEmpty) return const SizedBox.shrink();

    // الشهر الحالي: جدول دائم الظهور (من غير طي) — كل خط وقدامه خانة تكتب
    // فيها المبلغ على طول + مبلغ نفس الشهر اللي فات للمقارنة.
    if (_period == _Period.current) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(children: [
              const Text('📋', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('فواتير الشهر ده (${missing.length} خط)',
                  style: GoogleFonts.cairo(
                      fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.blue2)),
            ]),
          ),
          for (final g in missing)
            _ExpectedCard(
              group: g,
              month: _targetMonth,
              prov: prov,
              lastMonthAmount: _lastMonthAmount(g, db),
              isFreeThisMonth: _isNotDueThisMonth(g, db, prov),
            ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _missingOpen = !_missingOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Text('🕳️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${missing.length} خط لسه ما نزلتش فاتورته الشهر ده',
                    style: GoogleFonts.cairo(
                        fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
              ),
              Icon(_missingOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18, color: const Color(0xFFE65100)),
            ]),
          ),
        ),
        if (_missingOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(children: [
              for (final g in missing)
                _ExpectedCard(group: g, month: _targetMonth, prov: prov),
            ]),
          ),
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
                _set(() => _provFilter = item['key'] as String),
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
                _set(() => _typeFilter = item['key'] as String),
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
        if (unpaid > 0) ...[
          Text(
            'متبقي: ${unpaid.toStringAsFixed(0)} ج',
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmPayProvider(provider, name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.done_all, size: 12, color: Colors.white),
                const SizedBox(width: 3),
                Text('سدّد الكل',
                    style: GoogleFonts.cairo(
                        fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // دفعة جماعية: سداد كل فواتير شركة في الشهر الحالي مرة واحدة
  void _confirmPayProvider(String provider, String name) {
    final prov = context.read<AppProvider>();
    final (count, total) = prov.previewProviderUnpaid(provider, _targetMonth);
    if (count == 0) return;
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('💰 سداد جماعي — $name',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Text(
            'هتسدّد $count فاتورة غير مسددة بإجمالي ${total.toStringAsFixed(0)} ج '
            'لشركة $name في ${_monthLabel(_targetMonth)}.\n\nمتأكد؟',
            style: GoogleFonts.cairo(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () {
                final (n, t) = prov.payProviderBills(provider, _targetMonth);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: AppColors.green,
                  content: Text('✅ تم سداد $n فاتورة (${t.toStringAsFixed(0)} ج)',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ));
              },
              child: Text('سدّد الكل',
                  style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
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

  // تحويل d/m/yyyy → yyyy-mm-dd لاستخدامه في DateTime.parse
  String _isoFromDmy(String dmy) {
    final p = dmy.split('/');
    if (p.length != 3) return '';
    return '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
  }

  // ── Add bill dialog ────────────────────────────────────────────────
  void _showAddDialog(
      BuildContext ctx, AppProvider prov, AppDB db) {
    String? selectedGid;
    bool isEstimated = false;
    String? issueDate; // تاريخ نزول الفاتورة من الشركة (للسماح والعدّاد)
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final selectedMonth = _targetMonth;

    showAppSheet(
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
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
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
                              Icon(Icons.info_outline,
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
                      // 📅 تاريخ نزول الفاتورة (نتيجة) — للفاتورة الفعلية
                      if (!isEstimated) ...[
                        GestureDetector(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: ctx2,
                              initialDate: issueDate != null
                                  ? (DateTime.tryParse(_isoFromDmy(issueDate!)) ??
                                      now)
                                  : now,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              locale: const Locale('ar'),
                            );
                            if (picked != null) {
                              setS(() => issueDate =
                                  '${picked.day}/${picked.month}/${picked.year}');
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(children: [
                              const Icon(Icons.event,
                                  size: 18, color: Color(0xFF6A1B9A)),
                              const SizedBox(width: 8),
                              Text(
                                  issueDate != null
                                      ? '📅 نزلت يوم: $issueDate'
                                      : '📅 تاريخ نزول الفاتورة (اختياري)',
                                  style: GoogleFonts.cairo(fontSize: 13)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Amount field (actual bills only)
                      if (!isEstimated)
                        TextField(
                          controller: amountCtrl,
                          keyboardType:
                              TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText:
                                MoneyWords.actualBillLabel,
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
                              Navigator.pop(ctx);
                              _processActualBill(context, prov, selectedGid!,
                                  amount, note, issueDate, selectedMonth);
                              return;
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

  /// سلسلة تحقق قبل تسجيل فاتورة فعلية: قفل الشهر → تجاوز المبلغ المتفق عليه
  /// → مش دور الخط ده الشهر ده — كل واحدة بتأكيد اختياري قبل ما تكمل للي بعدها.
  void _processActualBill(BuildContext context, AppProvider prov, String gid,
      double amount, String? note, String? issueDate, String forMonth) {
    if (prov.isBillMonthLocked(forMonth)) {
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('🔒 ${_monthLabel(forMonth)} مقفولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
            content: Text('مراجعة الشهر ده اتقفلت. متأكد إنك عايز تسجّل فاتورة فيه برضه؟',
                style: GoogleFonts.cairo(fontSize: 12)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkOverAmount(context, prov, gid, amount, note, issueDate, forMonth);
                },
                child: Text('أكمل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
      return;
    }
    _checkOverAmount(context, prov, gid, amount, note, issueDate, forMonth);
  }

  void _checkOverAmount(BuildContext context, AppProvider prov, String gid,
      double amount, String? note, String? issueDate, String forMonth) {
    final g = prov.db.groups
        .firstWhere((x) => x.id == gid, orElse: () => Group(id: '', phone: ''));
    if (g.fixedBillAmount > 0 && amount > g.fixedBillAmount * 1.15) {
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('⚠️ المبلغ أعلى من المتفق عليه',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
            content: Text(
                'المبلغ (${amount.toStringAsFixed(0)} ج) أعلى من الثابت المسجل لـ ${g.phone} (${g.fixedBillAmount.toStringAsFixed(0)} ج) بفرق ${(amount - g.fixedBillAmount).toStringAsFixed(0)} ج. اتأكد من الشركة قبل ما تسجّل.',
                style: GoogleFonts.cairo(fontSize: 12)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmNotDueThenAdd(context, prov, gid, amount, note, issueDate, forMonth);
                },
                child: Text('صح، سجّل',
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
      return;
    }
    _confirmNotDueThenAdd(context, prov, gid, amount, note, issueDate, forMonth);
  }

  void _confirmNotDueThenAdd(BuildContext context, AppProvider prov, String gid,
      double amount, String? note, String? issueDate, String forMonth) {
    if (!prov.isGroupDueForBilling(gid, forMonth)) {
      final acc = prov.accountOfGroup(gid);
      final g = prov.db.groups
          .firstWhere((x) => x.id == gid, orElse: () => Group(id: '', phone: ''));
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('⚠️ الخط ده مش دوره الشهر ده',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
            content: Text(
              acc != null
                  ? 'الخط ${g.phone} جزء من حساب "${acc.name}"، والمفروض يبقى الدور على شق تاني الشهر ده. متأكد إنك عايز تسجّل الفاتورة برضه؟'
                  : 'نظام الخط ${g.phone} "شهر وشهر" والمفروض يبقى مجاني الشهر ده. متأكد إنك عايز تسجّل فاتورة برضه؟',
              style: GoogleFonts.cairo(fontSize: 12),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  Navigator.pop(context);
                  prov.addGroupBill(gid, amount,
                      note: note, issueDate: issueDate, forMonth: forMonth);
                },
                child: Text('سجّل برضه',
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
      return;
    }
    prov.addGroupBill(gid, amount, note: note, issueDate: issueDate, forMonth: forMonth);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bill Audit Card
// ══════════════════════════════════════════════════════════════════════════════
