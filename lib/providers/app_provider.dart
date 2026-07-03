// lib/providers/app_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/telegram_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/demo_data.dart';

class AppProvider extends ChangeNotifier {
  /// 🎭 وضع الديمو: بيانات وهمية للعرض/التصوير — لا قراءة ولا كتابة لبيانات حقيقية.
  /// يتفعّل وقت البناء فقط: flutter build apk --dart-define=DEMO=true
  static const bool kDemo = bool.fromEnvironment('DEMO');

  AppDB db = AppDB();
  bool _loading = true;

  // ── حالة الاتصال (قراءة-فقط أوفلاين) + Realtime ──────────────────
  bool _isOnline = true;
  RealtimeChannel? _dataChannel;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// متصل بالنت؟ (لو لأ → التطبيق قراءة فقط، ممنوع أي تعديل)
  bool get isOnline => _isOnline;

  /// مسموح بالتعديل؟ = متصل بالنت. أي عملية كتابة بتتحقق منه.
  bool get canEdit => _isOnline;

  /// مجموعات الموظف الموكلة له (null = مالك/بدون قيد). للموظف: يشوف دول بس.
  Set<String>? _assignedGroupIds;
  Set<String>? get assignedGroupIds => _assignedGroupIds;

  /// المجموعات الظاهرة للمستخدم الحالي — الموظف يشوف الموكلة له فقط.
  List<Group> get visibleGroups {
    if (!SupabaseService.isEmployee) return db.groups;
    final ids = _assignedGroupIds;
    if (ids == null) return const []; // لسه ماتحمّلتش — منعرضش (سرية)
    return db.groups.where((g) => ids.contains(g.id)).toList();
  }

  /// هل المستخدم الحالي مسموح له يشوف المجموعة دي؟
  bool canSeeGroup(String gid) =>
      !SupabaseService.isEmployee || (_assignedGroupIds?.contains(gid) ?? false);

  /// هل مسموح للمستخدم الحالي يعدّل في المجموعة دي؟
  /// المالك: دايماً. الموظف: بس لو موكلة له (أو بيغطّي عليها — [coveringGroupIds]).
  bool canEditGroup(String gid) {
    if (!SupabaseService.isEmployee) return true;
    if (_assignedGroupIds?.contains(gid) ?? false) return true;
    return _coveringGroupIds.contains(gid);
  }

  /// مجموعات بيغطّي عليها الموظف مؤقتاً (تغطية زميل غايب) — تتفعّل من المالك.
  final Set<String> _coveringGroupIds = {};
  Set<String> get coveringGroupIds => _coveringGroupIds;

  /// خريطة (group_id → اسم الموظف المسؤول) — للمالك، لعرض مؤشر المسؤول.
  Map<String, String> _groupAssignee = {};
  String? assigneeOf(String gid) => _groupAssignee[gid];
  Iterable<String> get assigneeOfValues => _groupAssignee.values;

  /// تحميل نظرة عامة على التعيينات (للمالك): مين مسؤول عن كل مجموعة.
  Future<void> loadAssignmentsOverview() async {
    if (SupabaseService.isEmployee) return;
    try {
      final emps = await SupabaseService.fetchEmployees();
      final nameById = <String, String>{
        for (final e in emps) e['id'].toString(): (e['name'] ?? '').toString()
      };
      final rows = await SupabaseService.fetchAssignments();
      final map = <String, String>{};
      for (final r in rows) {
        final gid = r['group_id']?.toString();
        final eid = r['employee_id']?.toString();
        if (gid != null && eid != null && nameById[eid] != null) {
          map[gid] = nameById[eid]!;
        }
      }
      _groupAssignee = map;
      notifyListeners();
    } catch (_) {/* تجاهل — مؤشر تجميلي */}
  }

  /// إسناد مجموعات كتير لموظف واحد دفعة (للتوزيع الجماعي/بالشركة). بيرجّع عدد اللي نجح.
  Future<int> bulkAssign(List<String> gids, String employeeId) async {
    var ok = 0;
    for (final g in gids) {
      if (await SupabaseService.setAssignment(g, employeeId)) ok++;
    }
    await loadAssignmentsOverview();
    return ok;
  }

  /// تغطية: نقل كل مجموعات موظف (غايب) لموظف تاني. بيرجّع عدد المنقول.
  Future<int> transferAssignments(String fromEmpId, String toEmpId) async {
    final rows = await SupabaseService.fetchAssignments();
    final gids = rows
        .where((r) => r['employee_id']?.toString() == fromEmpId)
        .map((r) => r['group_id'].toString())
        .toList();
    if (gids.isEmpty) return 0;
    return bulkAssign(gids, toEmpId);
  }

  /// توزيع تلقائي بالتساوي (round-robin) لكل المجموعات على الموظفين. بيرجّع العدد.
  Future<int> autoDistribute(List<String> employeeIds) async {
    if (employeeIds.isEmpty) return 0;
    var i = 0, ok = 0;
    for (final g in db.groups) {
      final eid = employeeIds[i % employeeIds.length];
      if (await SupabaseService.setAssignment(g.id, eid)) ok++;
      i++;
    }
    await loadAssignmentsOverview();
    return ok;
  }

  /// تحميل تعيينات الموظف الحالي من السيرفر (المجموعات الموكلة له).
  Future<void> loadMyAssignments() async {
    if (!SupabaseService.isEmployee) {
      _assignedGroupIds = null;
      return;
    }
    _assignedGroupIds = await SupabaseService.fetchMyAssignedGroupIds();
    notifyListeners();
  }

  /// يُستدعى لما تتمنع كتابة بسبب عدم وجود نت (عشان نعرض رسالة حمرا للمستخدم).
  /// بيتربط من الجذر (main.dart) عشان يعرض SnackBar أحمر فوق أي شاشة.
  void Function()? onOfflineWriteBlocked;

  /// لقطة آخر حالة سليمة (مُتزامنة) — تُستخدم للرجوع لو حصلت محاولة كتابة أوفلاين.
  String? _lastGoodJson;

  /// رقم إصدار البيانات على السيرفر (Optimistic Concurrency). الجهاز بيبعته
  /// مع كل كتابة؛ لو السيرفر بقى أحدث، الكتابة تترفض ونسحب بدل ما نمسح.
  int _dataVersion = 0;

  /// طابور حركات السجل المستقل (الصندوق الأسود) المنتظرة الترحيل للسيرفر.
  /// بيتحفظ محلياً عشان حتى لو قفل النت/التطبيق، الحركات تترحّل أول ما يرجع النت.
  final List<Map<String, dynamic>> _pendingAudit = [];
  bool _flushingAudit = false;
  String _pin = '123456';
  String _fontSize = 'medium'; // small, medium, large
  bool _darkMode = false;
  String _themeStyle = 'classic'; // classic, emerald, purple
  bool _autoBackup = false;
  String? _lastBackup;
  double _debtThreshold = 500;
  String _apiKey = '';
  String _instapayPhone = '';
  String _instapayPhone2 = '';
  String _vodafoneCash  = '';
  String _vodafoneCash2  = '';
  String _bankInfo      = '';
  String _ownerName     = 'ابو عمر';
  String _ownerPhone    = '01001005891';
  // يوم استحقاق سداد فاتورة الشركة (ثابت في الشهر) — مختلف لكل سيكل
  int _cycle1DueDay     = 20;
  int _cycle2DueDay     = 5;
  // فترة سماح الشركة (أيام من نزول الفاتورة) — مختلفة لكل شركة، قابلة للتعديل
  Map<String, int> _companyGrace = {
    'etisalat': 20,
    'vodafone': 15,
    'orange': 20,
    'we': 20,
  };

  // ── لقطات الجرد الشهري (snapshots للأرباح) ──────────────────────
  List<Map<String, dynamic>> _profitSnapshots = [];
  List<Map<String, dynamic>> get profitSnapshots =>
      List.unmodifiable(_profitSnapshots);

  // ── تنويه زيادة الباقة في رسالة المديونية ──────────────────────
  bool   _debtNoteEnabled = false;
  String _debtNoteText    = 'تنويه: تم رفع قيمة الاشتراك بسبب زيادة أسعار الشركة. شكراً لتفهمكم 🙏';

  // ── عرض العملاء: مضغوط (3 في الصف) أو تفصيلي ──────────────────
  bool   _compactMembers  = true;

  // ── إعدادات مخزون أرقام العمل ─────────────────────────────────
  int _worknumDeactivationDays = 90; // الشركة بتقفل الخط بعد كام يوم بدون اتصال
  int _worknumReminderDays     = 15; // تذكير يومي قبل التقفيل بكام يوم

  // ── إعدادات الإشعارات ──────────────────────────────────────────
  bool   _notifDailyDebt     = false;
  String _notifDailyDebtTime = '09:00';
  bool   _notifExpiry        = true;
  int    _notifExpiryDays    = 7;
  bool   _notifVoucher       = true;
  int    _notifVoucherDays   = 1;
  bool   _notifOffer         = true;
  int    _notifOfferDays     = 60;
  bool   _notifWeekly        = false;
  bool   _notifMonthly       = false;
  int    _notifMonthlyDay    = 1;
  bool   _notifBillDue       = true; // تذكير قبل آخر موعد دفع فاتورة الشركة
  int    _notifBillDueDays   = 3;

  // ── إعدادات تليجرام ────────────────────────────────────────────
  String _telegramToken    = '8832497646:AAHltc6_2pazsuocddFd1tqLXRs2RyEW7CI';
  String _telegramChatId   = '974113917';
  bool   _telegramEnabled  = false;
  int    _telegramOffset   = 0;
  Timer? _telegramTimer;

  bool   get loading        => _loading;
  String get pin            => _pin;
  String get fontSize       => _fontSize;
  bool   get darkMode       => _darkMode;
  String get themeStyle     => _themeStyle;
  bool   get autoBackup     => _autoBackup;
  String? get lastBackup    => _lastBackup;
  double get debtThreshold  => _debtThreshold;
  String get apiKey         => _apiKey;
  String get instapayPhone   => _instapayPhone;
  String get instapayPhone2  => _instapayPhone2;
  String get vodafoneCash    => _vodafoneCash;
  String get vodafoneCash2   => _vodafoneCash2;
  String get bankInfo        => _bankInfo;
  int    get cycle1DueDay    => _cycle1DueDay;
  int    get cycle2DueDay    => _cycle2DueDay;
  String get ownerName      => _ownerName;
  String get ownerPhone     => _ownerPhone;

  /// يوم الاستحقاق حسب سيكل المجموعة (1 أو 2)
  int dueDayForGroup(Group g) {
    final isCycle2 = g.billingCycle == 'cycle2' || g.cycle == '2';
    return isCycle2 ? _cycle2DueDay : _cycle1DueDay;
  }

  void setCycleDueDay(int cycle, int day) {
    final d = day.clamp(1, 28);
    if (cycle == 2) { _cycle2DueDay = d; } else { _cycle1DueDay = d; }
    saveSettings();
    notifyListeners();
  }

  // سماح خاص بسيكل 2 لكل شركة (لو مش موجود نستخدم السماح العام للشركة)
  Map<String, int> _companyGraceCycle2 = {};

  /// فترة سماح الشركة (أيام) — افتراضي 20 لو الشركة مش متعرّفة
  int graceForProvider(String? provider) =>
      _companyGrace[provider] ?? 20;

  /// سماح حسب الخط: لو الخط سيكل 2 وفيه سماح خاص للسيكل ده نستخدمه،
  /// غير كده نستخدم السماح العام للشركة.
  int graceForGroup(Group g) {
    final isCycle2 = g.billingCycle == 'cycle2' || g.cycle == '2';
    if (isCycle2 && _companyGraceCycle2.containsKey(g.provider)) {
      return _companyGraceCycle2[g.provider]!;
    }
    return graceForProvider(g.provider);
  }

  Map<String, int> get companyGrace => Map.unmodifiable(_companyGrace);
  Map<String, int> get companyGraceCycle2 => Map.unmodifiable(_companyGraceCycle2);
  void setCompanyGraceCycle2(String provider, int? days) {
    if (days == null) {
      _companyGraceCycle2.remove(provider);
    } else {
      _companyGraceCycle2[provider] = days.clamp(0, 120);
    }
    saveSettings();
    notifyListeners();
  }
  void setCompanyGrace(String provider, int days) {
    // سماح ممكن يبقى لحد 120 يوم (شهر و20 يوم وأكتر) حسب طلب المستخدم
    _companyGrace[provider] = days.clamp(0, 120);
    saveSettings();
    notifyListeners();
  }

  /// تاريخ آخر موعد دفع لفاتورة = تاريخ نزولها + سماح الشركة.
  /// بيرجّع null لو التاريخ غير صالح.
  DateTime? billDeadlineDate(CompanyBill b) {
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: ''));
    final grace = graceForGroup(g);
    final parts = b.date.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day).add(Duration(days: grace));
  }

  /// الأيام المتبقية في سماح الشركة لفاتورة = (تاريخ نزولها + سماح الشركة) − النهارده.
  /// بيرجّع null لو الفاتورة مسددة أو التاريخ غير صالح.
  int? billGraceDaysLeft(CompanyBill b) {
    if (b.isPaid) return null;
    final deadline = billDeadlineDate(b);
    if (deadline == null) return null;
    final now = DateTime.now();
    return deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// أقرب فاتورة غير مسددة لمجموعة (للعرض على كارت المجموعة بره).
  /// بترجّع (الفاتورة, الأيام المتبقية) أو null.
  (CompanyBill, int)? nearestUnpaidBill(String gid) {
    (CompanyBill, int)? best;
    for (final b in db.companyBills) {
      if (b.groupId != gid || b.isPaid) continue;
      final d = billGraceDaysLeft(b);
      if (d == null) continue;
      if (best == null || d < best.$2) best = (b, d);
    }
    return best;
  }
  bool   get debtNoteEnabled => _debtNoteEnabled;
  String get debtNoteText    => _debtNoteText;
  bool   get compactMembers  => _compactMembers;
  int    get worknumDeactivationDays => _worknumDeactivationDays;
  int    get worknumReminderDays     => _worknumReminderDays;

  /// الأيام المتبقية قبل الإغلاق الجبري لرقم — null لو مفيش تاريخ اتصال
  int? worknumDaysUntilDeactivation(WorkNum w) {
    final d = w.daysSinceContact;
    if (d == null) return null;
    return _worknumDeactivationDays - d;
  }

  /// هل الرقم داخل نافذة التذكير (قرّب يتقفل)؟
  bool worknumNeedsReminder(WorkNum w) {
    final remaining = worknumDaysUntilDeactivation(w);
    if (remaining == null) return false;
    final reminderDays = w.reminderDaysOverride ?? _worknumReminderDays;
    return remaining <= reminderDays;
  }

  bool   get notifDailyDebt     => _notifDailyDebt;
  String get notifDailyDebtTime => _notifDailyDebtTime;
  bool   get notifExpiry        => _notifExpiry;
  int    get notifExpiryDays    => _notifExpiryDays;
  bool   get notifVoucher       => _notifVoucher;
  int    get notifVoucherDays   => _notifVoucherDays;
  bool   get notifOffer         => _notifOffer;
  int    get notifOfferDays     => _notifOfferDays;
  bool   get notifWeekly        => _notifWeekly;
  bool   get notifMonthly       => _notifMonthly;
  int    get notifMonthlyDay    => _notifMonthlyDay;
  bool   get notifBillDue       => _notifBillDue;
  int    get notifBillDueDays   => _notifBillDueDays;

  String get telegramToken   => _telegramToken;
  String get telegramChatId  => _telegramChatId;
  bool   get telegramEnabled => _telegramEnabled;

  // ─── INIT ────────────────────────────────────────────────────
  Future<void> init() async {
    // 🎭 وضع الديمو: بيانات وهمية في الذاكرة فقط — من غير قراءة محلية
    // ولا مزامنة سحابية ولا إشعارات، عشان بيانات المستخدم الحقيقية ما تتلمسش.
    if (kDemo) {
      db = buildDemoDb();
      _ownerName = 'أبو أحمد';
      _ownerPhone = '01000000000';
      _isOnline = true;
      _lastGoodJson = jsonEncode(db.toJson());
      _loading = false;
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    // وضع الموظف: ممنوع قراءة نسخة محلية من بيانات المحل — يبدأ فاضي
    // ويحمّل من السيرفر لايف فقط (منع تسريب البيانات).
    final raw = SupabaseService.isEmployee ? null : prefs.getString('tcm_v3');
    if (raw != null) {
      try {
        db = AppDB.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    _pin            = prefs.getString('tcm_pin')      ?? '123456';
    _fontSize       = prefs.getString('tcm_fontsize') ?? 'medium';
    _darkMode       = prefs.getBool('tcm_dark')       ?? false;
    _themeStyle     = prefs.getString('tcm_theme')    ?? 'classic';
    _autoBackup     = prefs.getBool('tcm_autobackup') ?? false;
    _lastBackup     = prefs.getString('tcm_lastbackup');
    _debtThreshold  = (prefs.getDouble('tcm_debt_threshold') ?? 500);
    _apiKey         = prefs.getString('tcm_api_key')      ?? '';
    _instapayPhone  = prefs.getString('tcm_instapay')      ?? '';
    _instapayPhone2 = prefs.getString('tcm_instapay2')     ?? '';
    _vodafoneCash   = prefs.getString('tcm_vodafone_cash') ?? '';
    _vodafoneCash2  = prefs.getString('tcm_vodafone_cash2') ?? '';
    _bankInfo       = prefs.getString('tcm_bank_info')    ?? '';
    _cycle1DueDay   = prefs.getInt('tcm_cycle1_due')      ?? 20;
    _cycle2DueDay   = prefs.getInt('tcm_cycle2_due')      ?? 5;
    final graceRaw = prefs.getString('tcm_company_grace');
    if (graceRaw != null && graceRaw.isNotEmpty) {
      try {
        final m = jsonDecode(graceRaw) as Map<String, dynamic>;
        _companyGrace = m.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
    final grace2Raw = prefs.getString('tcm_company_grace_c2');
    if (grace2Raw != null && grace2Raw.isNotEmpty) {
      try {
        final m = jsonDecode(grace2Raw) as Map<String, dynamic>;
        _companyGraceCycle2 = m.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
    _ownerName      = prefs.getString('tcm_owner_name')   ?? 'ابو عمر';
    _ownerPhone     = prefs.getString('tcm_owner_phone')  ?? '01001005891';
    final snapRaw = prefs.getString('tcm_profit_snapshots');
    if (snapRaw != null) {
      try {
        _profitSnapshots = (jsonDecode(snapRaw) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }
    _debtNoteEnabled = prefs.getBool('tcm_debt_note_on')  ?? false;
    _debtNoteText    = prefs.getString('tcm_debt_note_txt') ?? _debtNoteText;
    _compactMembers  = prefs.getBool('tcm_compact_members') ?? true;
    _worknumDeactivationDays = prefs.getInt('tcm_wn_deactivation_days') ?? 90;
    _worknumReminderDays     = prefs.getInt('tcm_wn_reminder_days') ?? 15;
    _notifDailyDebt     = prefs.getBool('tcm_notif_daily')       ?? false;
    _notifDailyDebtTime = prefs.getString('tcm_notif_daily_time') ?? '09:00';
    _notifExpiry        = prefs.getBool('tcm_notif_expiry')      ?? true;
    _notifExpiryDays    = prefs.getInt('tcm_notif_expiry_days')  ?? 7;
    _notifVoucher       = prefs.getBool('tcm_notif_voucher')     ?? true;
    _notifVoucherDays   = prefs.getInt('tcm_notif_voucher_days') ?? 1;
    _notifOffer         = prefs.getBool('tcm_notif_offer')       ?? true;
    _notifOfferDays     = prefs.getInt('tcm_notif_offer_days')   ?? 60;
    _notifWeekly        = prefs.getBool('tcm_notif_weekly')      ?? false;
    _notifMonthly       = prefs.getBool('tcm_notif_monthly')     ?? false;
    _notifMonthlyDay    = prefs.getInt('tcm_notif_monthly_day')  ?? 1;
    _notifBillDue       = prefs.getBool('tcm_notif_billdue')     ?? true;
    _notifBillDueDays   = prefs.getInt('tcm_notif_billdue_days') ?? 3;
    _telegramToken      = prefs.getString('tcm_tg_token')  ?? '8832497646:AAHltc6_2pazsuocddFd1tqLXRs2RyEW7CI';
    _telegramChatId     = prefs.getString('tcm_tg_chatid') ?? '974113917';
    _telegramEnabled    = prefs.getBool('tcm_tg_enabled')  ?? false;
    _telegramOffset     = prefs.getInt('tcm_tg_offset')    ?? 0;
    _dataVersion        = prefs.getInt('tcm_data_version')  ?? 0;
    // استرجاع طابور السجل المعلّق (الصندوق الأسود) — لو فيه حركات لسه ماترحّلتش
    final pendRaw = prefs.getString('tcm_pending_audit');
    if (pendRaw != null) {
      try {
        _pendingAudit.addAll((jsonDecode(pendRaw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    _lastGoodJson = jsonEncode(db.toJson());
    _loading = false;
    _initConnectivity();
    _flushAudit(); // حاول ترحّل أي حركات معلّقة من جلسة سابقة
    if (SupabaseService.isEmployee) {
      loadMyAssignments(); // مجموعات الموظف الموكلة له
    } else {
      loadAssignmentsOverview(); // المالك: مين مسؤول عن كل مجموعة
    }
    _autoMonthlyBilling();
    _addMonthlyPoints();
    _autoGroupNotes();
    _autoGiftReset();
    autoArchiveOldNotes(); // 🧹 أرشفة الملاحظات المكتملة من أكتر من أسبوع
    if (_autoBackup) _checkAutoBackup();
    applyAllNotifications();
    notifyListeners();
  }

  void _scheduleVoucherNotifications() {
    for (var i = 0; i < db.groups.length; i++) {
      final g = db.groups[i];
      if (g.voucherValue <= 0) continue;
      final next = NotificationService.nextVoucherDate(g.voucherStartDate, g.voucherPeriod);
      if (next == null) continue;
      NotificationService.scheduleVoucherAlert(
        id: 2000 + i,
        title: '🎫 موعد قسيمة ${g.groupInvoiceName ?? g.phone}',
        body: 'القسيمة قيمتها ${g.voucherValue.toStringAsFixed(0)} ج — الإجمالي هذا الشهر: ${(g.fixedBillAmount - g.voucherValue).toStringAsFixed(0)} ج',
        when: next,
      );
    }
  }

  // ─── SAVE ────────────────────────────────────────────────────
  Future<void> save() async {
    // 🎭 الديمو: التعديلات في الذاكرة فقط — ممنوع الكتابة على القرص أو السحابة.
    if (kDemo) {
      notifyListeners();
      return;
    }
    // حاجز الأوفلاين: ممنوع أي كتابة وانت مش متصل. نرجّع آخر نسخة سليمة
    // عشان أي تعديل اتسرّب لا يُحفظ ولا يُرفع (منع تضارب نهائياً).
    if (!_isOnline) {
      if (_lastGoodJson != null) {
        try { db = AppDB.fromJson(jsonDecode(_lastGoodJson!)); } catch (_) {}
      }
      onOfflineWriteBlocked?.call(); // رسالة حمرا: التعديل مش هيتحفظ من غير نت
      notifyListeners();
      return;
    }
    // ختم وقت التعديل قبل الحفظ — عشان المزامنة تحسم بالأحدث زمنياً
    db.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final json = db.toJson();
    // وضع الموظف: ممنوع حفظ نسخة على الذاكرة الداخلية — السيرفر فقط
    if (!SupabaseService.isEmployee) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tcm_v3', jsonEncode(json));
    }
    _saveToCloud(json); // fire & forget
    _lastGoodJson = jsonEncode(json);
    notifyListeners();
  }

  void _saveToCloud(Map<String, dynamic> json) {
    // 🎭 الديمو: ممنوع رفع أي حاجة للسحابة نهائياً.
    if (kDemo) return;
    // Attach telegram config so the Edge Function can match this user
    final withConfig = Map<String, dynamic>.from(json);
    withConfig['_telegramConfig'] = {
      'token': _telegramToken,
      'chatId': _telegramChatId,
      'ownerName': _ownerName,
      'enabled': _telegramEnabled,
    };
    // حفظ محمي ضد التضارب: لو السيرفر بقى أحدث، السيرفر بيرفض الكتابة
    // وبنسحب نسخته بدل ما نمسح بيانات الأجهزة التانية.
    SupabaseService.saveUserDataGuarded(withConfig, _dataVersion).then((res) {
      if (!res.ok) return; // فشل اتصال — هنحاول تاني في المزامنة الجاية
      if (res.accepted) {
        _dataVersion = res.version;
        _persistDataVersion();
      } else if (res.stale && res.serverData != null) {
        // 🔒 الجهاز ده كان قديم — منع الكتابة فوق الأحدث. اسحب نسخة السيرفر.
        _applyServerData(res.serverData!, res.version);
      }
    });
    // برضه نحاول نرحّل أي حركات سجل معلّقة
    _flushAudit();
  }

  /// تطبيق نسخة السيرفر على الجهاز (بعد رفض كتابة قديمة، أو سحب عادي).
  Future<void> _applyServerData(Map<String, dynamic> data, int version) async {
    try {
      db = AppDB.fromJson(data);
      _dataVersion = version;
      _lastGoodJson = jsonEncode(db.toJson());
      if (!SupabaseService.isEmployee) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tcm_v3', jsonEncode(data));
      }
      await _persistDataVersion();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistDataVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tcm_data_version', _dataVersion);
  }

  // ─── AUDIT QUEUE (الصندوق الأسود — ترحيل مستقل عن الـ Blob) ────
  /// يضيف حركة لطابور الترحيل المستقل ويحاول يرفعها فوراً لو في نت.
  /// ده بيخلّي السجل ينجو حتى لو المزامنة رجعت لورا أو الـ Blob اتمسح.
  void _enqueueAudit(Map<String, dynamic> entry) {
    _pendingAudit.add(entry);
    _persistPendingAudit();
    _flushAudit();
  }

  Future<void> _persistPendingAudit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tcm_pending_audit', jsonEncode(_pendingAudit));
  }

  /// يرحّل الطابور للسيرفر دفعة واحدة. آمن للاستدعاء المتكرر.
  Future<void> _flushAudit() async {
    if (_flushingAudit || !_isOnline || _pendingAudit.isEmpty) return;
    if (!SupabaseService.isLoggedIn) return;
    _flushingAudit = true;
    try {
      // لقطة من الموجود حالياً (ممكن يتضاف غيره أثناء الرفع)
      final batch = List<Map<String, dynamic>>.from(_pendingAudit);
      final ok = await SupabaseService.pushAuditLogs(batch);
      if (ok) {
        _pendingAudit.removeRange(0, batch.length);
        await _persistPendingAudit();
      }
    } finally {
      _flushingAudit = false;
    }
    // لو اتضاف حركات جديدة أثناء الرفع، كمّل
    if (_isOnline && _pendingAudit.isNotEmpty) _flushAudit();
  }

  /// تحميل السجل الرسمي من السيرفر (للعرض في شاشة النشاط).
  Future<List<Map<String, dynamic>>> fetchServerAudit({int limit = 500}) =>
      SupabaseService.fetchAuditLogs(limit: limit);

  /// أرشفة تدقيق فاتورة خط في الجدول الدائم (غير قابل للحذف) + قيد في النشاط.
  Future<void> recordLineInvoiceAudit({
    required String groupId,
    required String month,
    required double expected,
    required double actual,
    required bool hasOverage,
    String? note,
  }) async {
    await SupabaseService.addLineInvoiceHistory(
      groupId: groupId,
      month: month,
      expected: expected,
      actual: actual,
      hasOverage: hasOverage,
      note: note,
    );
    final g = db.groups.firstWhere((x) => x.id == groupId,
        orElse: () => Group(id: '', phone: ''));
    final tag = hasOverage ? ' ⚠️ زيادة عن المتوقع' : '';
    final noteTxt = (note != null && note.isNotEmpty) ? ' — $note' : '';
    _addLog(null, 'bill',
        'تدقيق فاتورة ${g.phone} ($month): متوقع ${expected.toStringAsFixed(0)} / فعلي ${actual.toStringAsFixed(0)}$tag$noteTxt',
        targetId: groupId, targetType: 'group');
    save();
  }

  /// أرشيف فواتير خط معيّن (من السيرفر).
  Future<List<Map<String, dynamic>>> fetchLineInvoiceHistory(String groupId) =>
      SupabaseService.fetchLineInvoiceHistory(groupId);

  // ─── LOAD FROM CLOUD (بعد Login / عند رجوع التطبيق) ───────────
  /// بيرجّع: pulled = نزّل من السيرفر | pushed = رفع المحلي | noop = مفيش تغيير
  Future<String> loadFromCloud() async {
    // 🎭 الديمو: ممنوع أي مزامنة سحابية — البيانات الوهمية تفضل زي ما هي.
    if (kDemo) return 'noop';
    final r = await _loadFromCloudInner();
    // حدّث لقطة الحالة السليمة (للرجوع وقت محاولة كتابة أوفلاين)
    _lastGoodJson = jsonEncode(db.toJson());
    return r;
  }

  Future<String> _loadFromCloudInner() async {
    final res = await SupabaseService.loadUserData();
    final cloudData = res.data;
    if (cloudData == null) {
      // مفيش بيانات على السيرفر — ارفع المحلي
      _saveToCloud(db.toJson());
      return 'pushed';
    }
    try {
      final cloudDb = AppDB.fromJson(cloudData);
      final cloudVersion = res.version;
      final localTs = db.updatedAt;
      final cloudTs = cloudDb.updatedAt;

      // الحسم بالوقت: أحدث نسخة زمنياً تكسب.
      if (cloudTs > localTs) {
        // السيرفر أحدث → نزّله واعتمد إصداره
        db = cloudDb;
        _dataVersion = cloudVersion;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tcm_v3', jsonEncode(cloudData));
        await _persistDataVersion();
        notifyListeners();
        return 'pulled';
      } else if (localTs > cloudTs) {
        // المحلي أحدث → ارفعه (بإصدار السيرفر الحالي كأساس، والكتابة محمية)
        _dataVersion = cloudVersion;
        _saveToCloud(db.toJson());
        return 'pushed';
      }

      // الوقت متساوي (غالباً داتا قديمة من غير ختم وقت) → احسم بالعدد
      // عشان منمسحش بيانات بالغلط.
      final localCount = db.groups.length + db.members.length;
      final cloudCount = cloudDb.groups.length + cloudDb.members.length;
      if (cloudCount > localCount) {
        db = cloudDb;
        _dataVersion = cloudVersion;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tcm_v3', jsonEncode(cloudData));
        await _persistDataVersion();
        notifyListeners();
        return 'pulled';
      } else if (localCount > cloudCount) {
        _dataVersion = cloudVersion;
        _saveToCloud(db.toJson());
        return 'pushed';
      }
      // متطابقين — اعتمد إصدار السيرفر كأساس لأي كتابة لاحقة
      _dataVersion = cloudVersion;
      await _persistDataVersion();
      return 'noop';
    } catch (_) {
      return 'noop';
    }
  }

  // ─── CONNECTIVITY (read-only when offline) ───────────────────
  Future<void> _initConnectivity() async {
    final conn = Connectivity();
    try {
      final initial = await conn.checkConnectivity();
      _isOnline = !initial.contains(ConnectivityResult.none);
    } catch (_) {}
    _connSub = conn.onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online == _isOnline) return;
      _isOnline = online;
      if (online) {
        // رجع النت → اسحب أحدث نسخة، رحّل السجل المعلّق، وفعّل الـ realtime
        loadFromCloud();
        _flushAudit();
        startRealtime();
      } else {
        stopRealtime();
      }
      notifyListeners();
    });
  }

  // ─── REALTIME (live sync بين الأجهزة) ────────────────────────
  /// اشتراك لحظي على صف بيانات المالك — أي تعديل من جهاز تاني ينزل فوراً.
  void startRealtime() {
    // 🎭 الديمو: مفيش مزامنة لحظية — البيانات وهمية ومحلية.
    if (kDemo) return;
    stopRealtime();
    final uid = SupabaseService.dataUserId;
    if (uid == null) return;
    _dataChannel = SupabaseService.client
        .channel('user_data_rt_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_data',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          // الحدث مجرد إشارة «في تغيير» — نسحب ونطبّق بمنطق الوقت (echo-safe)
          callback: (_) => loadFromCloud(),
        )
        .subscribe();
  }

  void stopRealtime() {
    final ch = _dataChannel;
    _dataChannel = null;
    if (ch != null) SupabaseService.client.removeChannel(ch);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    stopRealtime();
    _telegramTimer?.cancel();
    super.dispose();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tcm_pin', _pin);
    await prefs.setString('tcm_fontsize', _fontSize);
    await prefs.setBool('tcm_dark', _darkMode);
    await prefs.setString('tcm_theme', _themeStyle);
    await prefs.setBool('tcm_autobackup', _autoBackup);
    await prefs.setDouble('tcm_debt_threshold', _debtThreshold);
    await prefs.setString('tcm_api_key', _apiKey);
    await prefs.setString('tcm_instapay',       _instapayPhone);
    await prefs.setString('tcm_instapay2',      _instapayPhone2);
    await prefs.setString('tcm_vodafone_cash',  _vodafoneCash);
    await prefs.setString('tcm_vodafone_cash2', _vodafoneCash2);
    await prefs.setString('tcm_bank_info',     _bankInfo);
    await prefs.setInt('tcm_cycle1_due',       _cycle1DueDay);
    await prefs.setInt('tcm_cycle2_due',       _cycle2DueDay);
    await prefs.setString('tcm_company_grace', jsonEncode(_companyGrace));
    await prefs.setString('tcm_company_grace_c2', jsonEncode(_companyGraceCycle2));
    await prefs.setString('tcm_owner_name',    _ownerName);
    await prefs.setString('tcm_owner_phone',   _ownerPhone);
    await prefs.setString('tcm_profit_snapshots', jsonEncode(_profitSnapshots));
    await prefs.setBool('tcm_debt_note_on',    _debtNoteEnabled);
    await prefs.setString('tcm_debt_note_txt', _debtNoteText);
    await prefs.setBool('tcm_compact_members', _compactMembers);
    await prefs.setInt('tcm_wn_deactivation_days', _worknumDeactivationDays);
    await prefs.setInt('tcm_wn_reminder_days', _worknumReminderDays);
    await prefs.setBool('tcm_notif_daily',        _notifDailyDebt);
    await prefs.setString('tcm_notif_daily_time', _notifDailyDebtTime);
    await prefs.setBool('tcm_notif_expiry',       _notifExpiry);
    await prefs.setInt('tcm_notif_expiry_days',   _notifExpiryDays);
    await prefs.setBool('tcm_notif_voucher',      _notifVoucher);
    await prefs.setInt('tcm_notif_voucher_days',  _notifVoucherDays);
    await prefs.setBool('tcm_notif_offer',        _notifOffer);
    await prefs.setInt('tcm_notif_offer_days',    _notifOfferDays);
    await prefs.setBool('tcm_notif_weekly',       _notifWeekly);
    await prefs.setBool('tcm_notif_monthly',      _notifMonthly);
    await prefs.setInt('tcm_notif_monthly_day',   _notifMonthlyDay);
    await prefs.setBool('tcm_notif_billdue',      _notifBillDue);
    await prefs.setInt('tcm_notif_billdue_days',  _notifBillDueDays);
    await prefs.setString('tcm_tg_token',  _telegramToken);
    await prefs.setString('tcm_tg_chatid', _telegramChatId);
    await prefs.setBool('tcm_tg_enabled',  _telegramEnabled);
    await prefs.setInt('tcm_tg_offset',    _telegramOffset);
    if (_lastBackup != null) await prefs.setString('tcm_lastbackup', _lastBackup!);
    notifyListeners();
  }

  // ─── TELEGRAM (24/7 server bot via Supabase Edge Function) ─────
  void setTelegram(String token, String chatId) {
    _telegramToken  = token.trim();
    _telegramChatId = chatId.trim();
    saveSettings();
    _saveToCloud(db.toJson()); // upload data so the bot has something to report
  }

  /// Enables/disables the 24/7 server bot. Registers the customer's own bot
  /// with the shared Supabase Edge Function (webhook) and saves their config,
  /// so it answers commands even when the app is closed.
  Future<({bool ok, String msg})> setTelegramEnabled(bool v) async {
    _telegramToken = _telegramToken.trim();

    if (v) {
      if (_telegramToken.isEmpty) {
        return (ok: false, msg: 'اكتب توكن البوت أولاً (من BotFather)');
      }
      final check = await TelegramService.verifyToken(_telegramToken);
      if (!check.ok) return (ok: false, msg: 'التوكن غير صحيح — تأكد منه');

      // upload latest data so the bot has data to report
      _saveToCloud(db.toJson());

      // save per-customer config and get this customer's webhook URL
      final saved = await SupabaseService.saveTelegramConfig(
        botToken: _telegramToken,
        ownerName: _ownerName,
        enabled: true,
        chatId: _telegramChatId,
      );
      if (saved.url == null) {
        return (ok: false, msg: saved.error ?? 'فشل غير معروف');
      }

      // register the webhook → bot now runs 24/7 on the server
      final res = await TelegramService.setWebhook(_telegramToken, saved.url!);
      if (!res.ok) return (ok: false, msg: res.msg);

      _telegramEnabled = true;
      saveSettings();
      notifyListeners();
      return (ok: true, msg: 'تم تفعيل البوت — يعمل الآن 24 ساعة حتى لو التطبيق مقفول ✅');
    } else {
      await TelegramService.deleteWebhook(_telegramToken);
      await SupabaseService.setTelegramConfigEnabled(false);
      _telegramEnabled = false;
      saveSettings();
      notifyListeners();
      return (ok: true, msg: 'تم إيقاف البوت');
    }
  }

  Future<bool> sendTelegram(String message) =>
      TelegramService.sendMessage(_telegramToken, _telegramChatId, message);

  // ─── SETTINGS ────────────────────────────────────────────────
  void setFontSize(String s) { _fontSize = s; saveSettings(); }
  void setDarkMode(bool v)   { _darkMode = v; saveSettings(); }
  void setThemeStyle(String v) { _themeStyle = v; saveSettings(); }
  void setAutoBackup(bool v) { _autoBackup = v; saveSettings(); }
  void setDebtThreshold(double v) { _debtThreshold = v; saveSettings(); }
  void setApiKey(String v) { _apiKey = v; saveSettings(); notifyListeners(); }
  void setInstapay(String v)       { _instapayPhone  = v; saveSettings(); }
  void setInstapay2(String v)      { _instapayPhone2 = v; saveSettings(); }
  void setVodafoneCash(String v)   { _vodafoneCash   = v; saveSettings(); }
  void setVodafoneCash2(String v)  { _vodafoneCash2  = v; saveSettings(); }
  void setBankInfo(String v)      { _bankInfo      = v; saveSettings(); }
  void setOwnerName(String v)     { _ownerName     = v; saveSettings(); notifyListeners(); }
  void setOwnerPhone(String v)    { _ownerPhone    = v; saveSettings(); notifyListeners(); }
  void setDebtNoteEnabled(bool v) { _debtNoteEnabled = v; saveSettings(); notifyListeners(); }
  void setDebtNoteText(String v)  { _debtNoteText  = v; saveSettings(); notifyListeners(); }
  void setCompactMembers(bool v)  { _compactMembers = v; saveSettings(); notifyListeners(); }
  void setWorknumDeactivationDays(int v) { _worknumDeactivationDays = v; saveSettings(); notifyListeners(); }
  void setWorknumReminderDays(int v)     { _worknumReminderDays = v; saveSettings(); notifyListeners(); }

  /// تسجيل اتصال على رقم — يحدّث lastContactDate لاليوم (ISO)
  void recordWorkNumContact(String id) {
    final i = db.workNums.indexWhere((w) => w.id == id);
    if (i < 0) return;
    final now = DateTime.now();
    db.workNums[i].lastContactDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _addLog(null, 'service', 'تسجيل اتصال على رقم العمل ${db.workNums[i].phone}',
        targetId: id, targetType: 'worknum');
    save(); notifyListeners();
  }

  /// تسجيل اتصال اليوم لكل الأرقام المحتاجة اتصال/المتأخرة دفعة واحدة. بيرجّع العدد.
  int recordAllPendingWorkNumContacts() {
    final today =
        () { final n = DateTime.now(); return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}'; }();
    var n = 0;
    for (final w in db.workNums) {
      final rem = worknumDaysUntilDeactivation(w);
      final pending = worknumNeedsReminder(w) || (rem != null && rem <= 0);
      if (pending) {
        w.lastContactDate = today;
        n++;
      }
    }
    if (n > 0) {
      _addLog(null, 'service', 'تسجيل اتصال جماعي على $n رقم عمل');
      save();
      notifyListeners();
    }
    return n;
  }

  /// التقاط لقطة جرد للأرباح للشهر الحالي (تُستبدل لو الشهر اتسجّل قبل كده).
  void captureProfitSnapshot() {
    final n = DateTime.now();
    final month = '${n.year}-${n.month.toString().padLeft(2, '0')}';
    final income = db.members.fold<double>(0, (s, m) => s + m.price);
    final billing = db.totalBillingProfit;
    final gift = db.groups.fold<double>(0, (s, g) => s + g.giftProfit);
    final rental = db.rentals
        .where((r) => r.status == 'active')
        .fold<double>(0, (s, r) => s + r.rent);
    final guest = db.guestUsers.fold<double>(0, (s, g) => s + g.profit);
    final points = db.groups.fold<double>(0, (s, g) => s + g.pendingPointsProfit);
    final debt = db.totalDebt;
    final net = billing + gift + rental + guest + points;
    final snap = {
      'month': month,
      'date': _today(),
      'income': income,
      'billing': billing,
      'gift': gift,
      'rental': rental,
      'guest': guest,
      'points': points,
      'debt': debt,
      'net': net,
    };
    _profitSnapshots.removeWhere((s) => s['month'] == month);
    _profitSnapshots.add(snap);
    _profitSnapshots.sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
    saveSettings();
    notifyListeners();
  }

  // ── Notification setters ────────────────────────────────────────
  void setNotifDailyDebt(bool v, {String? time}) {
    _notifDailyDebt = v;
    if (time != null) _notifDailyDebtTime = time;
    saveSettings();
    applyAllNotifications();
  }
  void setNotifDailyDebtTime(String v) { _notifDailyDebtTime = v; saveSettings(); applyAllNotifications(); }
  void setNotifExpiry(bool v, {int? days}) { _notifExpiry = v; if (days != null) _notifExpiryDays = days; saveSettings(); applyAllNotifications(); }
  void setNotifExpiryDays(int v)  { _notifExpiryDays = v; saveSettings(); applyAllNotifications(); }
  void setNotifVoucher(bool v)    { _notifVoucher = v; saveSettings(); applyAllNotifications(); }
  void setNotifVoucherDays(int v) { _notifVoucherDays = v; saveSettings(); applyAllNotifications(); }
  void setNotifOffer(bool v, {int? days}) { _notifOffer = v; if (days != null) _notifOfferDays = days; saveSettings(); applyAllNotifications(); }
  void setNotifOfferDays(int v)   { _notifOfferDays = v; saveSettings(); applyAllNotifications(); }
  void setNotifWeekly(bool v)     { _notifWeekly = v; saveSettings(); applyAllNotifications(); }
  void setNotifMonthly(bool v, {int? day}) { _notifMonthly = v; if (day != null) _notifMonthlyDay = day; saveSettings(); applyAllNotifications(); }
  void setNotifMonthlyDay(int v)  { _notifMonthlyDay = v; saveSettings(); applyAllNotifications(); }
  void setNotifBillDue(bool v, {int? days}) { _notifBillDue = v; if (days != null) _notifBillDueDays = days; saveSettings(); applyAllNotifications(); }
  void setNotifBillDueDays(int v) { _notifBillDueDays = v.clamp(0, 30); saveSettings(); applyAllNotifications(); }

  void applyAllNotifications() {
    _scheduleVoucherNotifications();
    if (_notifDailyDebt) {
      final parts = _notifDailyDebtTime.split(':');
      final h = int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final debtors = db.members.where((x) => x.balance < 0).length;
      NotificationService.scheduleDailyDebtReminder(
        hour: h, minute: m,
        title: '🔔 تذكير المديونيات',
        body: debtors > 0 ? '$debtors عميل عليهم ديون — تابع التحصيل 💰' : 'لا توجد مديونيات حالياً ✅',
      );
    } else {
      NotificationService.cancelDebtReminder();
    }
    if (_notifExpiry) NotificationService.scheduleExpiryAlerts(groups: db.groups, daysBefore: _notifExpiryDays);
    if (_notifOffer)  NotificationService.scheduleOfferAlerts(groups: db.groups, daysBefore: _notifOfferDays);
    if (_notifWeekly) NotificationService.scheduleWeeklySummary(db: db);
    if (_notifMonthly) NotificationService.scheduleMonthlyCollection(dayOfMonth: _notifMonthlyDay, db: db);
    if (_notifBillDue) {
      // تذكير قبل آخر موعد دفع كل فاتورة شركة غير مدفوعة (التاريخ + سماح الشركة)
      final items = <({String phone, DateTime deadline, double remaining})>[];
      for (final bl in db.companyBills) {
        if (bl.isPaid) continue;
        final dl = billDeadlineDate(bl);
        if (dl == null) continue;
        final g = db.groups.firstWhere((x) => x.id == bl.groupId,
            orElse: () => Group(id: '', phone: ''));
        items.add((phone: g.phone, deadline: dl, remaining: bl.remaining));
      }
      NotificationService.scheduleBillDueAlerts(
          bills: items, daysBefore: _notifBillDueDays);
    } else {
      NotificationService.cancelBillDueAlerts();
    }
  }

  // ─── AUTO BACKUP ─────────────────────────────────────────────
  Future<String?> performBackup() async {
    // الموظف ممنوع ياخد نسخة من البيانات
    if (SupabaseService.isEmployee) return null;
    try {
      final now    = DateTime.now();
      final stamp  = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
      Directory dir;
      if (Platform.isAndroid) {
        // Try Downloads folder first, fallback to app documents
        final dl = Directory('/storage/emulated/0/Download/TelecomBackups');
        if (!await dl.exists()) await dl.create(recursive: true);
        dir = dl;
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final file = File('${dir.path}/telecom_backup_$stamp.json');
      await file.writeAsString(jsonEncode(db.toJson()));
      _lastBackup = stamp;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tcm_lastbackup', stamp);
      notifyListeners();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkAutoBackup() async {
    if (!_autoBackup) return;
    final today = DateTime.now();
    final stamp = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    if (_lastBackup == stamp) return; // already backed up today
    await performBackup();
  }
  bool changePin(String oldPin, String newPin) {
    if (oldPin != _pin) return false;
    _pin = newPin;
    saveSettings();
    return true;
  }

  // ─── GROUPS ─────────────────────────────────────────────────
  void addGroup(Group g) {
    db.groups.add(g);
    db.gid++;
    _addLog(null, 'add', 'تمت إضافة مجموعة ${g.phone}');
    save();
  }

  /// استيراد عملاء من صفوف قالب Excel (دمج — يضيف للموجود، مايستبدلش).
  /// بيرجّع: عدد المجموعات الجديدة، العملاء الجدد، المتخطّى (مكرر/فاضي).
  ({int groups, int members, int skipped}) importMembersMerge(
      List<Map<String, dynamic>> rows) {
    var newGroups = 0, newMembers = 0, skipped = 0;
    final base = DateTime.now().millisecondsSinceEpoch;
    var seq = 0;
    String newId() => '${base}_${seq++}';

    for (final row in rows) {
      final name = (row['name'] ?? '').toString().trim();
      final phone = (row['phone'] ?? '').toString().trim();
      final gp = (row['groupPhone'] ?? '').toString().trim();
      if (name.isEmpty && phone.isEmpty) {
        skipped++;
        continue;
      }
      // إيجاد/إنشاء المجموعة برقم الخط
      Group? g;
      if (gp.isNotEmpty) {
        final idx = db.groups.indexWhere((x) => x.phone == gp);
        if (idx >= 0) {
          g = db.groups[idx];
        } else {
          final prov = (row['provider'] ?? '').toString().trim();
          g = Group(
            id: newId(),
            phone: gp,
            type: 'manual',
            // الافتراضي اتصالات (كل الشغل اتصالات إلا لو حُدِّد غيرها)
            provider: prov.isNotEmpty ? prov : 'etisalat',
          );
          db.groups.add(g);
          db.gid++;
          newGroups++;
        }
      }
      // تخطّي العميل المكرر (نفس الرقم موجود)
      if (phone.isNotEmpty && db.members.any((m) => m.phone == phone)) {
        skipped++;
        continue;
      }
      final debt = (row['debt'] as num?)?.toDouble() ?? 0;
      final price = (row['price'] as num?)?.toDouble() ?? 0;
      db.members.add(Member(
        id: newId(),
        gid: g?.id ?? '',
        name: name,
        phone: phone,
        package: (row['package'] ?? '').toString().trim(),
        price: price,
        balance: debt > 0 ? -debt : 0, // مديونية قديمة = رصيد سالب
        notes: (row['notes'] ?? '').toString().trim().isEmpty
            ? null
            : (row['notes']).toString().trim(),
      ));
      db.mid++;
      newMembers++;
    }
    _addLog(null, 'import',
        'استيراد Excel: $newMembers عميل + $newGroups مجموعة جديدة');
    save();
    notifyListeners();
    return (groups: newGroups, members: newMembers, skipped: skipped);
  }

  void editGroup(Group g) {
    final i = db.groups.indexWhere((x) => x.id == g.id);
    if (i >= 0) db.groups[i] = g;
    _scheduleVoucherNotifications();
    _addLog(null, 'edit', 'تعديل المجموعة ${g.phone}',
        targetId: g.id, targetType: 'group');
    save();
  }

  /// ربط/فصل خط فرعي بخط رئيسي (للفواتير المُجمَّعة من الشركة)
  void setGroupParent(String childGid, String? parentGid) {
    final i = db.groups.indexWhere((g) => g.id == childGid);
    if (i < 0) return;
    db.groups[i].parentGroupId = (parentGid == null || parentGid.isEmpty) ? null : parentGid;
    save(); notifyListeners();
  }

  /// عدد العملاء اللي هيتأثروا برفع الأسعار (للمعاينة قبل التأكيد)
  int previewBulkPriceCount({String? gid, bool skipZero = true}) {
    return db.members.where((m) {
      if (gid != null && m.gid != gid) return false;
      if (skipZero && m.price <= 0) return false;
      return true;
    }).length;
  }

  /// رفع/تعديل أسعار اشتراكات العملاء دفعة واحدة.
  /// [value] المقدار: لو [isPercent] نسبة مئوية، غير كده مبلغ ثابت يُضاف.
  /// [gid] لو null يطبّق على كل العملاء، غير كده على مجموعة واحدة.
  /// [skipZero] يتجاهل العملاء اللي سعرهم صفر (هدايا/مجاني).
  /// بيرجّع عدد العملاء اللي اتعدّلوا.
  int bulkAdjustPrices({
    required double value,
    required bool isPercent,
    String? gid,
    bool skipZero = true,
  }) {
    if (value == 0) return 0;
    int affected = 0;
    for (var i = 0; i < db.members.length; i++) {
      final m = db.members[i];
      if (gid != null && m.gid != gid) continue;
      if (skipZero && m.price <= 0) continue;
      final raw = isPercent ? m.price * (1 + value / 100) : m.price + value;
      final newPrice = raw < 0 ? 0.0 : raw.roundToDouble();
      db.members[i].price = newPrice;
      affected++;
    }
    if (affected > 0) {
      final scope = gid != null
          ? (db.groups.firstWhere((g) => g.id == gid,
                  orElse: () => Group(id: '', phone: 'مجموعة')).phone)
          : 'كل العملاء';
      _addLog(
        null,
        'price_bulk',
        isPercent
            ? 'رفع أسعار $affected عميل ($scope) بنسبة ${value.toStringAsFixed(0)}%'
            : 'تعديل أسعار $affected عميل ($scope) بمقدار ${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)} ج',
      );
      save();
      notifyListeners();
    }
    return affected;
  }

  void reorderGroups(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final g = db.groups.removeAt(oldIndex);
    db.groups.insert(newIndex, g);
    for (var i = 0; i < db.groups.length; i++) {
      db.groups[i].orderIndex = i;
    }
    save();
  }

  void reorderMembers(String gid, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final members = db.members.where((m) => m.gid == gid).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final m = members.removeAt(oldIndex);
    members.insert(newIndex, m);
    for (var i = 0; i < members.length; i++) {
      final idx = db.members.indexWhere((x) => x.id == members[i].id);
      if (idx >= 0) db.members[idx].orderIndex = i;
    }
    save();
  }

  void deleteGroup(String gid) {
    final g = db.groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: gid, phone: '—'));
    // فك أي خطوط تابعة لهذا الخط (لو كان خط أب) عشان مايفضلش رابط بايظ
    var unlinked = 0;
    for (final child in db.groups) {
      if (child.parentGroupId == gid) {
        child.parentGroupId = null;
        unlinked++;
      }
    }
    db.groups.removeWhere((g) => g.id == gid);
    // archive members
    final mems = db.members.where((m) => m.gid == gid).toList();
    db.deleted.addAll(mems);
    db.members.removeWhere((m) => m.gid == gid);
    final extra = unlinked > 0 ? ' + فك $unlinked خط تابع' : '';
    _addLog(null, 'delete', 'حذف المجموعة ${g.phone} (${mems.length} عميل)$extra',
        targetId: gid, targetType: 'group');
    save();
  }

  // ─── MEMBERS ─────────────────────────────────────────────────
  void addMember(Member m) {
    db.members.add(m);
    db.mid++;
    _ensureGuarantorEntity(m.guarantorName, m.guarantorPhone);
    _addLog(m, 'add', 'تمت إضافة العميل ${m.name}');
    save();
  }

  void setGroupPoints(String gid, int points) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].rewardPoints = points;
    save(); notifyListeners();
  }

  void toggleWaPhone2(String memberId) {
    final i = db.members.indexWhere((x) => x.id == memberId);
    if (i < 0) return;
    db.members[i].waPhone2 = !db.members[i].waPhone2;
    save(); notifyListeners();
  }

  void editMember(Member m) {
    final i = db.members.indexWhere((x) => x.id == m.id);
    if (i >= 0) db.members[i] = m;
    _ensureGuarantorEntity(m.guarantorName, m.guarantorPhone);
    _addLog(m, 'edit', 'تم تعديل بيانات ${m.name}');
    save();
  }

  /// يضمن وجود كيان كفيل رسمي في db.guarantors لأي كفيل اتكتب من جوه عميل —
  /// عشان الكفيل يبقى واحد في كل مكان (قائمة الكفلاء + العميل + البحث + التعديل).
  void _ensureGuarantorEntity(String? name, String? phone) {
    final p = (phone ?? '').trim();
    if (p.isEmpty) return;
    final idx = db.guarantors.indexWhere((g) => g.phone == p);
    if (idx >= 0) {
      // موجود بالفعل — لو الاسم فاضي عنده وجه اسم جديد، حدّثه
      if ((db.guarantors[idx].name.trim().isEmpty) &&
          (name ?? '').trim().isNotEmpty) {
        db.guarantors[idx].name = name!.trim();
      }
    } else {
      db.guarantors.add(Guarantor(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: (name ?? '').trim().isEmpty ? 'كفيل' : name!.trim(),
        phone: p,
      ));
    }
    // مفيش save() هنا — بيتنادى من addMember/editMember اللي بيحفظوا بعده.
  }

  void deleteMember(String mid) {
    final m = db.members.firstWhere((x) => x.id == mid);
    final grp = db.groups.firstWhere((g) => g.id == m.gid,
        orElse: () => Group(id: '', phone: '—'));
    // نختم تاريخ الحذف + المجموعة اللي كان فيها في سجل العميل نفسه للمتابعة بعد الحذف.
    m.log.insert(0, {
      'date': _today(),
      'desc': '🗑 تم حذف العميل (كان في مجموعة ${grp.phone})',
      'amount': 0,
      'type': 'deleted',
    });
    db.deleted.add(m);
    db.members.removeWhere((x) => x.id == mid);
    _addLog(m, 'delete', 'تم حذف العميل ${m.name}');
    save();
  }

  /// تسجيل دفعة/خصم لعميل محذوف (تحصيل مديونية بعد الحذف). موجب=دفعة، سالب=خصم.
  void addDeletedPayment(String mid, double amount, String note) {
    final i = db.deleted.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.deleted[i].balance += amount;
    db.deleted[i].log.insert(0, {
      'date': _today(),
      'desc': note.trim().isNotEmpty ? note.trim() : (amount >= 0 ? 'دفعة بعد الحذف' : 'خصم بعد الحذف'),
      'amount': amount,
    });
    _addLog(db.deleted[i], 'pay',
        'تحصيل ${amount.toStringAsFixed(0)} ج من عميل محذوف - ${db.deleted[i].name}',
        targetId: mid, targetType: 'member');
    save();
    notifyListeners();
  }

  /// تاريخ حذف العميل (من سجله)، أو null.
  String? deletedDateOf(Member m) {
    final e = m.log.cast<Map<String, dynamic>?>().firstWhere(
        (x) => x?['type'] == 'deleted', orElse: () => null);
    return e?['date']?.toString();
  }

  void restoreMember(String mid) {
    final m = db.deleted.firstWhere((x) => x.id == mid);
    db.members.add(m);
    db.deleted.removeWhere((x) => x.id == mid);
    _addLog(m, 'add', 'استرجاع العميل ${m.name}');
    save();
  }

  // ─── PAYMENTS ────────────────────────────────────────────────
  void addPayment(String mid, double amount, String note) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].balance += amount;
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': note.isNotEmpty ? note : 'دفعة',
      'amount': amount,
    });
    _addLog(db.members[i], 'pay', 'دفع ${amount.toStringAsFixed(0)} ج - ${db.members[i].name}');
    save();
  }

  void addCharge(String mid, double amount, String note) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].balance -= amount;
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': note.isNotEmpty ? note : 'خصم',
      'amount': -amount,
    });
    _addLog(db.members[i], 'charge',
        'تحميل ${amount.toStringAsFixed(0)} ج على ${db.members[i].name}${note.isNotEmpty ? ' ($note)' : ''}');
    save();
  }

  void saveMemberNotes(String mid, String notes) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].notes = notes.trim().isEmpty ? null : notes.trim();
    save();
    notifyListeners();
  }

  void deleteMemberLogEntry(String mid, int index) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0 || index >= db.members[i].log.length) return;
    final entry = db.members[i].log[index];
    final amount = (entry['amount'] ?? 0).toDouble();
    db.members[i].balance -= amount;
    db.members[i].log.removeAt(index);
    _addLog(db.members[i], 'edit',
        'حذف حركة من كشف ${db.members[i].name} (${amount.toStringAsFixed(0)} ج: ${entry['desc'] ?? ''})');
    save();
    notifyListeners();
  }

  /// تعديل حركة في كشف العميل: البيان + المبلغ (موجب=دفعة، سالب=مديونية) + التاريخ والوقت.
  /// الرصيد بيتظبط بفرق المبلغ (الجديد − القديم) عشان يفضل متسق.
  void editMemberLogEntry(String mid, int index,
      {required String desc, required double amount, String? date, String? time}) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0 || index < 0 || index >= db.members[i].log.length) return;
    final entry = db.members[i].log[index];
    final oldAmount = (entry['amount'] ?? 0).toDouble();
    db.members[i].balance += (amount - oldAmount); // فرق التعديل
    entry['desc'] = desc.trim().isNotEmpty ? desc.trim() : (entry['desc'] ?? 'حركة');
    entry['amount'] = amount;
    final dateChanged = date != null && date.trim().isNotEmpty;
    if (dateChanged) entry['date'] = date.trim();
    if (time != null) {
      if (time.trim().isEmpty) {
        entry.remove('time');
      } else {
        entry['time'] = time.trim();
      }
    }
    // لو التاريخ اتغيّر → رتّب السجل زمنياً (الأحدث فوق) فينزل في مكانه الصح
    if (dateChanged) sortMemberLogByDate(mid);
    _addLog(db.members[i], 'edit',
        'تعديل حركة في كشف ${db.members[i].name} (${oldAmount.toStringAsFixed(0)} ← ${amount.toStringAsFixed(0)} ج)');
    save();
    notifyListeners();
  }

  /// ترتيب سجل العميل زمنياً (الأحدث فوق) بثبات — بيستخدم بعد تعديل تاريخ حركة.
  void sortMemberLogByDate(String mid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    int key(Map e) {
      final d = (e['date'] ?? '').toString().split('/');
      if (d.length != 3) return 0;
      final day = int.tryParse(d[0]) ?? 1;
      final mon = int.tryParse(d[1]) ?? 1;
      final yr = int.tryParse(d[2]) ?? 2000;
      var ms = DateTime(yr, mon, day).millisecondsSinceEpoch;
      final t = (e['time'] ?? '').toString().split(':');
      if (t.length == 2) {
        ms += ((int.tryParse(t[0]) ?? 0) * 3600 + (int.tryParse(t[1]) ?? 0) * 60) * 1000;
      }
      return ms;
    }
    final indexed = db.members[i].log.asMap().entries.toList();
    indexed.sort((a, b) {
      final c = key(b.value).compareTo(key(a.value)); // تنازلي
      return c != 0 ? c : a.key.compareTo(b.key);      // ثبات
    });
    db.members[i].log = indexed.map((e) => e.value).toList();
  }

  void addService(String mid, String desc, double amount, bool isPaid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    final logDesc = desc.trim().isNotEmpty ? desc.trim() : (isPaid ? 'خدمة مدفوعة' : 'خدمة مجانية');
    if (isPaid && amount > 0) db.members[i].balance -= amount;
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': logDesc,
      'amount': isPaid ? -amount : 0,
    });
    _addLog(
        db.members[i],
        'service',
        isPaid && amount > 0
            ? 'خدمة "$logDesc" بـ ${amount.toStringAsFixed(0)} ج للعميل ${db.members[i].name}'
            : 'خدمة "$logDesc" (مجانية) للعميل ${db.members[i].name}');
    save();
    notifyListeners();
  }

  /// إضافة هدية/خدمة منظَّمة (جيجا + دقائق + خدمة) — تُسجَّل في كشف العميل
  /// مع وسوم (kind/gb/minutes) عشان نقدر نجمّعها في كشف شهري ويتصفّر كل شهر.
  /// amount=0 أو isPaid=false ⇒ هدية مجانية (لا تمسّ الرصيد).
  void addGiftService(String mid,
      {double gb = 0,
      double minutes = 0,
      String desc = '',
      double amount = 0,
      bool isPaid = false}) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    final parts = <String>[];
    if (gb > 0) parts.add('${_numFmt(gb)} جيجا');
    if (minutes > 0) parts.add('${_numFmt(minutes)} دقيقة');
    if (desc.trim().isNotEmpty) parts.add(desc.trim());
    final label = parts.isEmpty ? (isPaid ? 'خدمة' : 'هدية') : parts.join(' + ');
    final paid = isPaid && amount > 0;
    if (paid) db.members[i].balance -= amount;
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': label,
      'amount': paid ? -amount : 0,
      'kind': 'gift',
      'gb': gb,
      'minutes': minutes,
      'paid': paid,
    });
    _addLog(
        db.members[i],
        'service',
        paid
            ? 'خدمة "$label" بـ ${amount.toStringAsFixed(0)} ج للعميل ${db.members[i].name}'
            : 'هدية "$label" (مجانية) للعميل ${db.members[i].name}');
    save();
    notifyListeners();
  }

  String _numFmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// ملخّص هدايا الشهر الحالي لعميل: مجموع الجيجا/الدقائق + قائمة البنود.
  /// التصفير شهري تلقائي لأننا بنفلتر بشهر/سنة النهارده.
  Map<String, dynamic> monthlyGiftSummary(String mid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    final res = {'gb': 0.0, 'minutes': 0.0, 'items': <String>[], 'count': 0};
    if (i < 0) return res;
    final now = DateTime.now();
    double gb = 0, minutes = 0;
    final items = <String>[];
    for (final e in db.members[i].log) {
      if (e['kind'] != 'gift') continue;
      final d = (e['date'] ?? '').toString().split('/');
      if (d.length == 3 &&
          int.tryParse(d[1]) == now.month &&
          int.tryParse(d[2]) == now.year) {
        gb += (e['gb'] ?? 0).toDouble();
        minutes += (e['minutes'] ?? 0).toDouble();
        items.add((e['desc'] ?? '').toString());
      }
    }
    return {'gb': gb, 'minutes': minutes, 'items': items, 'count': items.length};
  }

  // ─── قسائم/منح دورية على الخط الرئيسي ─────────────────────────
  /// إضافة قسيمة: اسم + قيمة + ميعاد النزول + التكرار ('6m'|'1y'|'once').
  void addCoupon(String gid, String name, double value, String dueDate,
      String every) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].coupons.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name.trim().isEmpty ? 'قسيمة' : name.trim(),
      'value': value,
      'dueDate': dueDate,
      'every': every,
      'log': <Map<String, dynamic>>[],
    });
    _addLog(null, 'coupon',
        'إضافة قسيمة "$name" بقيمة ${value.toStringAsFixed(0)} ج على الخط ${db.groups[i].phone}',
        targetId: gid, targetType: 'group');
    save();
    notifyListeners();
  }

  void deleteCoupon(String gid, String couponId) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].coupons.removeWhere((c) => c['id'] == couponId);
    save();
    notifyListeners();
  }

  /// تسجيل استلام القسيمة: يضيف للسجل ويقدّم ميعاد النزول الجاي حسب التكرار.
  void markCouponReceived(String gid, String couponId,
      {double? amount, String? note}) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final ci = db.groups[i].coupons.indexWhere((c) => c['id'] == couponId);
    if (ci < 0) return;
    final c = db.groups[i].coupons[ci];
    final amt = amount ?? (c['value'] as num?)?.toDouble() ?? 0;
    (c['log'] as List).insert(0, {
      'date': _today(),
      'amount': amt,
      'note': note ?? '',
    });
    // تقديم ميعاد النزول الجاي حسب التكرار
    final every = (c['every'] ?? 'once').toString();
    final cur = DateTime.tryParse((c['dueDate'] ?? '').toString());
    if (cur != null && every != 'once') {
      final months = every == '1y' ? 12 : 6;
      final next = DateTime(cur.year, cur.month + months, cur.day);
      c['dueDate'] =
          '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    }
    _addLog(null, 'coupon',
        'استلام قسيمة "${c['name']}" بقيمة ${amt.toStringAsFixed(0)} ج',
        targetId: gid, targetType: 'group');
    save();
    notifyListeners();
  }

  void moveMember(String mid, String newGid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    final oldG = db.groups.firstWhere((g) => g.id == db.members[i].gid,
        orElse: () => Group(id: '', phone: '—'));
    final newG = db.groups.firstWhere((g) => g.id == newGid,
        orElse: () => Group(id: '', phone: '—'));
    db.members[i].gid = newGid;
    // نسجّل النقل في سجل العميل نفسه (بالتاريخ) عشان يفضل في ملفه حتى بعد الحذف.
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': '🔀 نقل من ${oldG.phone} إلى ${newG.phone}',
      'amount': 0,
      'type': 'move',
    });
    _addLog(db.members[i], 'move',
        'نقل العميل ${db.members[i].name} من ${oldG.phone} إلى ${newG.phone}');
    save();
    notifyListeners();
  }

  void clearMemberLog(String mid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    _addLog(db.members[i], 'delete', 'مسح كشف حساب العميل ${db.members[i].name}');
    db.members[i].log.clear();
    save();
    notifyListeners();
  }

  // ─── MONTHLY BILLING ─────────────────────────────────────────
  void addMonthBilling() {
    final now = DateTime.now();
    final monthLabel = '${_monthName(now.month)} ${now.year}';
    for (final g in db.groups) {
      final mems = db.membersOf(g.id);
      for (final m in mems) {
        // حارس: مايتحاسبش العميل مرتين في نفس الشهر
        if (m.price > 0 && !_memberBilledThisMonth(m)) {
          final i = db.members.indexWhere((x) => x.id == m.id);
          if (i >= 0) {
            db.members[i].balance -= m.price;
            db.members[i].log.insert(0, {
              'date': _today(),
              'desc': 'اشتراك $monthLabel${g.payer == "company" ? " 🏢" : ""}',
              'amount': -m.price,
            });
          }
        }
      }
      g.payer = g.payer == 'me' ? 'company' : 'me';
    }
    _addLog(null, 'bill', 'تمت إضافة اشتراك $monthLabel لكل العملاء');
    save();
  }

  /// Returns current 'YYYY-MM' string for lock comparisons
  String get _currentYearMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  bool isCycleLocked(String cycleKey) =>
      db.billingLocks[cycleKey] == _currentYearMonth;

  /// Bills only groups matching cycleKey and sets a monthly lock.
  /// cycleKey: 'cycle1' | 'cycle2' | 'cycle4' | 'all'
  void addMonthBillingForCycle(String cycleKey) {
    if (isCycleLocked(cycleKey)) return;
    final now = DateTime.now();
    final monthLabel = '${_monthName(now.month)} ${now.year}';
    final cycleLabel = switch (cycleKey) {
      'cycle1' => 'سيكل 1',
      'cycle2' => 'سيكل 2',
      'cycle4' => 'سيكل 4',
      _        => 'الكل',
    };

    bool matches(Group g) => switch (cycleKey) {
      'cycle1' => g.billingCycle == 'cycle1' || g.cycle == '1',
      'cycle2' => g.billingCycle == 'cycle2' || g.cycle == '2',
      'cycle4' => g.billingCycle == 'day4',
      _        => true,
    };

    for (final g in db.groups) {
      if (!matches(g)) continue;
      final mems = db.membersOf(g.id);
      for (final m in mems) {
        // حارس مهم: مايتحاسبش العميل مرتين في نفس الشهر (يا إما سيكل 1 يا سيكل 2)
        if (m.price > 0 && !_memberBilledThisMonth(m)) {
          final i = db.members.indexWhere((x) => x.id == m.id);
          if (i >= 0) {
            db.members[i].balance -= m.price;
            db.members[i].log.insert(0, {
              'date': _today(),
              'desc': 'اشتراك $monthLabel ($cycleLabel)${g.payer == "company" ? " 🏢" : ""}',
              'amount': -m.price,
            });
          }
        }
      }
      g.payer = g.payer == 'me' ? 'company' : 'me';
    }
    db.billingLocks[cycleKey] = _currentYearMonth;
    _addLog(null, 'bill', 'اشتراك $monthLabel — $cycleLabel');
    save();
  }

  /// هل العميل اتحاسب اشتراك في الشهر الحالي بالفعل؟ (يمنع الفاتورتين في شهر واحد)
  bool _memberBilledThisMonth(Member m) {
    final now = DateTime.now();
    for (final e in m.log) {
      final desc = (e['desc'] ?? '').toString();
      if (!desc.startsWith('اشتراك')) continue;
      final d = (e['date'] ?? '').toString().split('/');
      if (d.length == 3 &&
          int.tryParse(d[1]) == now.month &&
          int.tryParse(d[2]) == now.year) {
        return true;
      }
    }
    return false;
  }

  /// حذف/تراجع عن اشتراك سيكل معيّن لهذا الشهر عن جميع العملاء (لو اتضاف بالغلط).
  /// بيعكس الرصيد ويمسح القفل عشان تقدر تعيد لو حبيت. بيرجّع (عدد الحركات، الإجمالي).
  (int, double) undoCycleBillingThisMonth(String cycleKey) {
    final now = DateTime.now();
    final tag = switch (cycleKey) {
      'cycle1' => 'سيكل 1',
      'cycle2' => 'سيكل 2',
      'cycle4' => 'سيكل 4',
      _ => '', // 'all' → كل الاشتراكات
    };
    int count = 0;
    double total = 0;
    for (final m in db.members) {
      m.log.removeWhere((e) {
        final desc = (e['desc'] ?? '').toString();
        if (!desc.startsWith('اشتراك')) return false;
        if (tag.isNotEmpty && !desc.contains(tag)) return false;
        final d = (e['date'] ?? '').toString().split('/');
        final inMonth = d.length == 3 &&
            int.tryParse(d[1]) == now.month &&
            int.tryParse(d[2]) == now.year;
        if (!inMonth) return false;
        final amt = (e['amount'] ?? 0).toDouble(); // سالب
        m.balance -= amt; // عكس: amt سالب → يرجّع الرصيد
        total += -amt;
        count++;
        return true;
      });
    }
    db.billingLocks.remove(cycleKey);
    _addLog(null, 'bill',
        'حذف اشتراك ${tag.isEmpty ? "كل السيكلات" : tag} لهذا الشهر ($count حركة، ${total.toStringAsFixed(0)} ج)');
    save();
    notifyListeners();
    return (count, total);
  }

  void _autoMonthlyBilling() {
    final now = DateTime.now();
    final day = now.day;
    // سيكل 1: يوم 1 فقط | سيكل 2: يوم 15 فقط | باقي الأنواع: يوم 1-3
    final isCycle1Day = day == 1;
    final isCycle2Day = day == 15;
    final isGenericDay = day <= 3;
    if (!isCycle1Day && !isCycle2Day && !isGenericDay) return;

    final currentYM = '${now.year}-${now.month}';
    bool addedAny = false;

    for (final g in db.groups) {
      if (g.type == 'manual') continue; // المجموعات اليدوية لا تخضع لدورة الفواتير
      final isCycle1 = g.billingCycle == 'cycle1';
      final isCycle2 = g.billingCycle == 'cycle2';
      final billedKey = isCycle2 ? '$currentYM-sub15' : '$currentYM-sub1';

      // تحديد أي يوم ينطبق على هذا الخط
      final shouldBill = isCycle2 ? isCycle2Day : (isCycle1 ? isCycle1Day : isGenericDay);
      if (!shouldBill) continue;
      if (g.lastBilledMonth == billedKey) continue;

      final mems = db.membersOf(g.id);
      final monthLabel = '${_monthName(now.month)} ${now.year}';
      for (final m in mems) {
        // حارس: مايتحاسبش مرتين في نفس الشهر (أوتو + يدوي أو سيكل مكرر)
        if (m.price > 0 && !_memberBilledThisMonth(m)) {
          final i = db.members.indexWhere((x) => x.id == m.id);
          if (i >= 0) {
            db.members[i].balance -= m.price;
            db.members[i].log.insert(0, {
              'date': _today(),
              'desc': 'اشتراك $monthLabel${isCycle2 ? " (سيكل 2)" : ""}${g.payer == "company" ? " 🏢" : ""}',
              'amount': -m.price,
            });
          }
        }
      }
      g.lastBilledMonth = billedKey;
      g.lastBillDate = currentYM;
      g.payer = g.payer == 'me' ? 'company' : 'me';
      addedAny = true;
    }

    // Phase 6: فوترة آلية للإيجار — كل rental نشط يتخصم منه packagePrice
    final monthLabel = '${_monthName(now.month)} ${now.year}';
    for (var i = 0; i < db.rentals.length; i++) {
      final r = db.rentals[i];
      if (r.status != 'active') continue;
      final g = db.groups.firstWhere((x) => x.id == r.gid,
          orElse: () => Group(id: '', phone: ''));
      // حدد دورة الخط
      final isCycle2 = g.billingCycle == 'cycle2';
      final shouldBill = isCycle2 ? isCycle2Day : isCycle1Day;
      if (!shouldBill) continue;
      final rentalKey = '$currentYM-r${isCycle2 ? "15" : "1"}';
      if (r.lastBilledMonth == rentalKey) continue;
      final price = r.effectivePrice;
      if (price <= 0) continue;
      db.rentals[i].balance -= price;
      db.rentals[i].log.insert(0, {
        'date': DateTime.now().toIso8601String(),
        'desc': 'إيجار $monthLabel (آلي)',
        'amount': -price,
      });
      db.rentals[i].lastBilledMonth = rentalKey;
      addedAny = true;
    }

    if (addedAny) save();
  }

  // ─── GUARANTOR BULK PAY ──────────────────────────────────────
  void guarantorBulkPay(String guarantorPhone, double totalAmount, String mode, String note) {
    final members = db.members.where((m) => m.guarantorPhone == guarantorPhone).toList();
    if (members.isEmpty) return;

    Map<String, double> dist = {};
    if (mode == 'equal') {
      final share = totalAmount / members.length;
      for (final m in members) {
        dist[m.id] = share;
      }
    } else if (mode == 'debt') {
      final debtors = members.where((m) => m.balance < 0).toList();
      if (debtors.isEmpty) return;
      final share = totalAmount / debtors.length;
      for (final m in debtors) {
        dist[m.id] = share;
      }
    } else if (mode == 'price') {
      final total = members.fold(0.0, (s, m) => s + m.price);
      for (final m in members) {
        dist[m.id] = total > 0 ? (m.price / total) * totalAmount : 0;
      }
    } else if (mode == 'full') {
      for (final m in members) {
        dist[m.id] = -m.balance > 0 ? -m.balance : 0;
      }
    }

    for (final entry in dist.entries) {
      if (entry.value > 0) {
        addPayment(entry.key, entry.value, note.isNotEmpty ? note : 'دفع كفيل');
      }
    }
  }

  // ─── RENTALS ─────────────────────────────────────────────────
  void addRental(Rental r) { db.rentals.add(r); save(); notifyListeners(); }
  void editRental(Rental r) {
    final i = db.rentals.indexWhere((x) => x.id == r.id);
    if (i >= 0) db.rentals[i] = r;
    save(); notifyListeners();
  }
  void deleteRental(String rid) {
    db.rentals.removeWhere((r) => r.id == rid);
    save(); notifyListeners();
  }
  void addRentalPayment(String rid, double amount, String note) {
    final i = db.rentals.indexWhere((x) => x.id == rid);
    if (i < 0) return;
    db.rentals[i].balance += amount;
    db.rentals[i].log.insert(0, {
      'date': _today(),
      'desc': note.isNotEmpty ? note : 'دفعة إيجار',
      'amount': amount,
    });
    _addLog(null, 'pay',
        'دفعة إيجار ${amount.toStringAsFixed(0)} ج - ${db.rentals[i].name}',
        targetId: rid, targetType: 'rental');
    save(); notifyListeners();
  }
  void addRentalCharge(String rid, double amount, String note) {
    final i = db.rentals.indexWhere((x) => x.id == rid);
    if (i < 0) return;
    db.rentals[i].balance -= amount;
    db.rentals[i].log.insert(0, {
      'date': _today(),
      'desc': note.isNotEmpty ? note : 'خصم إيجار',
      'amount': -amount,
    });
    _addLog(null, 'charge',
        'خصم إيجار ${amount.toStringAsFixed(0)} ج - ${db.rentals[i].name}',
        targetId: rid, targetType: 'rental');
    save(); notifyListeners();
  }
  /// تأجيل دفع الإيجار حتى تاريخ معيّن (أو إلغاء التأجيل بتمرير null).
  void setRentalDeferral(String rid, String? date, String? note) {
    final i = db.rentals.indexWhere((x) => x.id == rid);
    if (i < 0) return;
    db.rentals[i].deferralDate = date;
    db.rentals[i].deferralNote = (note?.trim().isNotEmpty == true) ? note!.trim() : null;
    db.rentals[i].log.insert(0, {
      'date': _today(),
      'desc': date == null ? '⏰ إلغاء تأجيل الدفع' : '⏰ تأجيل الدفع حتى $date',
      'amount': 0,
      'type': 'deferral',
    });
    save(); notifyListeners();
  }

  /// حذف حركة من سجل الإيجار (ويرجّع تأثيرها على الرصيد).
  void deleteRentalLogEntry(String rid, int index) {
    final i = db.rentals.indexWhere((x) => x.id == rid);
    if (i < 0 || index < 0 || index >= db.rentals[i].log.length) return;
    final amount = (db.rentals[i].log[index]['amount'] ?? 0).toDouble();
    db.rentals[i].balance -= amount;
    db.rentals[i].log.removeAt(index);
    save(); notifyListeners();
  }

  void toggleRentalStatus(String rid) {
    final i = db.rentals.indexWhere((x) => x.id == rid);
    if (i < 0) return;
    final wasActive = db.rentals[i].status == 'active';
    db.rentals[i].status = wasActive ? 'paused' : 'active';
    db.rentals[i].log.insert(0, {
      'date': _today(),
      'desc': wasActive ? '⏸ تم إيقاف الإيجار' : '▶️ تم تفعيل الإيجار',
      'amount': 0,
    });
    save(); notifyListeners();
  }
  void changeRenter(String rid, String newName, String? newWa) {
    final i = db.rentals.indexWhere((x) => x.id == rid);
    if (i < 0) return;
    final oldName = db.rentals[i].name;
    db.rentals[i].log.insert(0, {
      'date': _today(),
      'desc': 'تغيير المستأجر: $oldName ← $newName',
      'amount': 0,
      'type': 'renter_change',
    });
    db.rentals[i].name = newName;
    if (newWa != null) db.rentals[i].wa = newWa;
    // Reset balance on renter change (log preserves old history)
    save(); notifyListeners();
  }

  // ─── WORK NUMS ───────────────────────────────────────────────
  void addWorkNum(WorkNum w) { db.workNums.add(w); save(); }
  void editWorkNum(WorkNum w) {
    final i = db.workNums.indexWhere((x) => x.id == w.id);
    if (i >= 0) db.workNums[i] = w;
    save();
  }
  void deleteWorkNum(String wid) {
    db.workNums.removeWhere((w) => w.id == wid);
    save();
  }

  // ─── WAITLIST ────────────────────────────────────────────────
  void addWaitlist(WaitlistEntry e) {
    e.id = DateTime.now().millisecondsSinceEpoch;
    db.waitlist.insert(0, e);
    save();
  }
  void editWaitlist(WaitlistEntry e) {
    final i = db.waitlist.indexWhere((x) => x.id == e.id);
    if (i >= 0) db.waitlist[i] = e;
    save();
  }
  void deleteWaitlist(int id) {
    db.waitlist.removeWhere((e) => e.id == id);
    save();
  }
  void setWaitlistStatus(int id, String status) {
    final i = db.waitlist.indexWhere((e) => e.id == id);
    if (i >= 0) { db.waitlist[i].status = status; save(); }
  }

  // ─── ACTIVITY LOG / AUDIT (الصندوق الأسود) ───────────────────
  /// يسجّل حركة في النسخة المحلية (للعرض السريع/الأوفلاين) وفي نفس الوقت
  /// يضيفها لطابور الترحيل المستقل اللي بيوصل لجدول shop_audit_logs.
  /// [targetId]/[targetType] للربط النشط: الضغط على السطر يفتح العنصر.
  void _addLog(Member? m, String type, String desc,
      {String? targetId, String? targetType}) {
    final now = DateTime.now();
    final tid = targetId ?? m?.id;
    final ttype = targetType ?? (m != null ? 'member' : null);
    db.activityLog.insert(0, {
      'date': _today(),
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'ts': now.toIso8601String(),
      'type': type,
      'desc': desc,
      'member': m?.name,
      'targetId': tid,
      'targetType': ttype,
      'by': SupabaseService.isEmployee
          ? 'موظف: ${SupabaseService.employeeName ?? '—'}'
          : 'المالك',
      'isEmployee': SupabaseService.isEmployee,
    });
    if (db.activityLog.length > 500) db.activityLog.removeLast();
    // الصندوق الأسود: قيد مستقل لا يتأثر بتراجع المزامنة
    _enqueueAudit({
      'type': type,
      'desc': desc,
      'member': m?.name,
      'targetId': tid,
      'targetType': ttype,
      'ts': now.toIso8601String(),
    });
  }

  /// تسجيل حركة عامة من الشاشات (إرسال رسالة، إلخ) — واجهة عامة للـ UI.
  void logAction(String type, String desc,
      {String? targetId, String? targetType, Member? member}) {
    _addLog(member, type, desc, targetId: targetId, targetType: targetType);
    save();
  }

  /// تحقق من الرقم السري للمالك. الموظف دائماً مرفوض.
  bool verifyOwnerPin(String pin) {
    if (SupabaseService.isEmployee) return false;
    return pin == _pin;
  }

  /// مسح النسخة المحلية فقط من السجل — محمي بالرقم السري للمالك.
  /// ⚠️ السجل الرسمي على السيرفر (shop_audit_logs) Append-Only ومستحيل يتمسح.
  bool clearActivityLog(String pin) {
    if (!verifyOwnerPin(pin)) return false;
    db.activityLog.clear();
    save();
    return true;
  }

  // ─── DELETE ALL ──────────────────────────────────────────────
  void deleteAllData() {
    db = AppDB();
    save();
  }

  /// مسح بيانات المحل من الذاكرة فقط (بدون رفع للسيرفر) —
  /// يُستخدم لطرد الموظف فوراً عند إيقافه/حذفه.
  void wipeInMemoryData() {
    db = AppDB();
    notifyListeners();
  }

  void deleteAllMembers() {
    db.deleted.addAll(db.members);
    db.members.clear();
    db.mid = 1;
    save();
  }

  // ─── IMPORT / EXPORT ─────────────────────────────────────────
  String exportJson() => jsonEncode(db.toJson());

  bool importJson(String raw) {
    try {
      db = AppDB.fromJson(jsonDecode(raw));
      save();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── SEARCH ──────────────────────────────────────────────────

  /// تحويل الأرقام الهندية → لاتينية وتطبيع أحرف الألف وتاء مربوطة
  static String _normalizeQuery(String q) {
    const indic = '٠١٢٣٤٥٦٧٨٩';
    var r = q;
    for (var i = 0; i < indic.length; i++) {
      r = r.replaceAll(indic[i], '$i');
    }
    return r
        .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه').replaceAll('ى', 'ي')
        .toLowerCase();
  }

  /// تحويل الأحرف العربية إلى مكافئ لاتيني صوتي
  static String _latinize(String q) {
    const m = {
      0x627: 'a',  0x623: 'a',  0x625: 'i',  0x622: 'aa',
      0x628: 'b',  0x62a: 't',  0x62b: 'th',
      0x62c: 'j',  0x62d: 'h',  0x62e: 'kh',
      0x62f: 'd',  0x630: 'dh', 0x631: 'r',  0x632: 'z',
      0x633: 's',  0x634: 'sh', 0x635: 's',  0x636: 'd',
      0x637: 't',  0x638: 'z',  0x639: 'a',  0x63a: 'gh',
      0x641: 'f',  0x642: 'q',  0x643: 'k',  0x644: 'l',
      0x645: 'm',  0x646: 'n',  0x647: 'h',  0x648: 'w',
      0x64a: 'y',  0x649: 'a',  0x629: 'h',
      0x621: '',   0x626: 'y',  0x624: 'w',
    };
    final buf = StringBuffer();
    for (final r in q.runes) {
      buf.write(m[r] ?? String.fromCharCode(r));
    }
    return buf.toString();
  }

  bool _matchesQuery(String field, String ql, String qlLatin) {
    final fl = _normalizeQuery(field);
    return fl.contains(ql) || fl.contains(qlLatin);
  }

  List<Member> search(String q) {
    if (q.isEmpty) return [];
    final ql = _normalizeQuery(q);
    final qlLatin = _latinize(ql);
    return db.members.where((m) =>
      _matchesQuery(m.name, ql, qlLatin) ||
      _normalizeQuery(m.phone).contains(ql) ||
      _matchesQuery(m.package, ql, qlLatin) ||
      m.balance.toString().contains(ql)
    ).toList();
  }

  /// Returns unified search results across all entity types.
  /// Each result map: {type, id, label, subtitle, tab, extra}
  List<Map<String, dynamic>> searchAll(String q, {String filter = 'all'}) {
    if (q.isEmpty) return [];
    final ql = _normalizeQuery(q);
    final qlLatin = _latinize(ql);
    final results = <Map<String, dynamic>>[];

    // Members (all, members, debt, clear)
    if (filter == 'all' || filter == 'members' ||
        filter == 'debt' || filter == 'clear') {
      for (final m in db.members) {
        if (filter == 'debt' && m.balance >= 0) continue;
        if (filter == 'clear' && m.balance < 0) continue;
        if (_matchesQuery(m.name, ql, qlLatin) ||
            _normalizeQuery(m.phone).contains(ql) ||
            _matchesQuery(m.package, ql, qlLatin) ||
            _normalizeQuery(m.natId ?? '').contains(ql)) {
          final g = db.groups.firstWhere((x) => x.id == m.gid,
              orElse: () => Group(id: '', phone: '—'));
          results.add({
            'type': 'member',
            'id': m.id,
            'label': m.name,
            'subtitle': '${m.phone}  •  ${g.phone}',
            'extra': '${m.balance.toStringAsFixed(0)} ج',
            'positive': m.balance >= 0,
            'tab': 0,
            'gid': m.gid,
          });
        }
      }
    }

    // Groups
    if (filter == 'all' || filter == 'groups') {
      for (final g in db.groups) {
        if (_normalizeQuery(g.phone).contains(ql) ||
            _matchesQuery(g.ownerName ?? '', ql, qlLatin) ||
            _normalizeQuery(g.ownerNatId ?? '').contains(ql)) {
          results.add({
            'type': 'group',
            'id': g.id,
            'label': g.phone,
            'subtitle': g.ownerName ?? 'بدون صاحب',
            'extra': '${db.members.where((m) => m.gid == g.id).length} عميل',
            'positive': true,
            'tab': 0,
            'gid': g.id,
          });
        }
      }
    }

    // Waitlist
    if (filter == 'all' || filter == 'waitlist') {
      for (final w in db.waitlist) {
        if (_matchesQuery(w.name, ql, qlLatin) ||
            w.phone.contains(ql) ||
            (w.phone2 ?? '').contains(ql) ||
            _matchesQuery(w.package ?? '', ql, qlLatin)) {
          results.add({
            'type': 'waitlist',
            'id': w.id.toString(),
            'label': w.name,
            'subtitle': w.phone,
            'extra': w.status == 'waiting' ? '⏳ منتظر' : w.status == 'contacted' ? '📞 تم التواصل' : '✅ تم التخصيص',
            'positive': true,
            'tab': 11,
          });
        }
      }
    }

    // Work numbers
    if (filter == 'all' || filter == 'worknums') {
      for (final w in db.workNums) {
        if (w.phone.contains(ql) ||
            w.label.toLowerCase().contains(ql)) {
          results.add({
            'type': 'worknum',
            'id': w.id,
            'label': w.phone,
            'subtitle': w.label.isNotEmpty ? w.label : 'رقم عمل',
            'extra': '',
            'positive': true,
            'tab': 3,
          });
        }
      }
    }

    // Guest Users
    if (filter == 'all' || filter == 'guests') {
      for (final g in db.guestUsers) {
        if (_matchesQuery(g.clientName, ql, qlLatin) ||
            g.clientPhone.contains(ql) ||
            _matchesQuery(g.dealerName ?? '', ql, qlLatin) ||
            (g.dealerPhone ?? '').contains(ql)) {
          results.add({
            'type': 'guest',
            'id': g.id,
            'label': g.clientName,
            'subtitle': '${g.clientPhone}  •  ${g.dealerName ?? 'بدون تاجر'}',
            'extra': '${g.clientAmount.toStringAsFixed(0)} ج',
            'positive': true,
            'tab': 12,
          });
        }
      }
    }

    // Guarantors (from member data)
    if (filter == 'all' || filter == 'guarantors') {
      final seen = <String>{};
      for (final m in db.members) {
        if (m.guarantorPhone == null) continue;
        final key = m.guarantorPhone!;
        if (seen.contains(key)) continue;
        if (_matchesQuery(m.guarantorName ?? '', ql, qlLatin) ||
            m.guarantorPhone!.contains(ql)) {
          seen.add(key);
          results.add({
            'type': 'guarantor',
            'id': key,
            'label': m.guarantorName ?? key,
            'subtitle': m.guarantorPhone!,
            'extra': 'كفيل',
            'positive': true,
            'tab': 2,
          });
        }
      }
    }

    return results;
  }

  // ─── GIFTS ───────────────────────────────────────────────────
  // ─── GUARANTORS ──────────────────────────────────────────────
  void addGuarantor(Guarantor g) {
    // منع التكرار: لو فيه كفيل بنفس الرقم، حدّثه بدل ما نضيف واحد جديد
    final existing = db.guarantors.indexWhere((x) => x.phone == g.phone);
    if (existing >= 0) {
      saveGuarantor(g, oldPhone: db.guarantors[existing].phone,
          keepId: db.guarantors[existing].id);
      return;
    }
    db.guarantors.add(g);
    _syncMembersToGuarantor(g.phone, g);
    save(); notifyListeners();
  }

  void editGuarantor(Guarantor g, {String? oldPhone}) {
    saveGuarantor(g, oldPhone: oldPhone);
  }

  /// الحفظ الموحّد للكفيل: upsert + مزامنة العملاء المرتبطين (الاسم/الرقم).
  void saveGuarantor(Guarantor g, {String? oldPhone, String? keepId}) {
    final searchPhone = oldPhone ?? g.phone;
    int idx = db.guarantors.indexWhere((x) => x.id == (keepId ?? g.id));
    idx = idx >= 0 ? idx : db.guarantors.indexWhere((x) => x.phone == searchPhone);
    if (idx >= 0) {
      final ex = db.guarantors[idx];
      ex.name = g.name;
      ex.phone = g.phone;
      ex.phone2 = g.phone2;
      ex.type = g.type;
      ex.natId = g.natId;
      ex.notes = g.notes;
      ex.maxDebt = g.maxDebt;
    } else {
      db.guarantors.add(g);
    }
    _syncMembersToGuarantor(searchPhone, g);
    save(); notifyListeners();
  }

  /// يحدّث اسم/رقم الكفيل عند كل العملاء المرتبطين بيه (بالرقم القديم أو الجديد).
  void _syncMembersToGuarantor(String oldPhone, Guarantor g) {
    for (final m in db.members) {
      if (m.guarantorPhone == oldPhone || m.guarantorPhone == g.phone) {
        m.guarantorName = g.name;
        m.guarantorPhone = g.phone;
      }
    }
  }
  void deleteGuarantor(String id) {
    db.guarantors.removeWhere((g) => g.id == id);
    save(); notifyListeners();
  }

  /// تسجيل أن الكفيل اتذكّر دلوقتي (للكفلاء الرسميين اللي ليهم سجل).
  void markGuarantorReminded(String id) {
    final i = db.guarantors.indexWhere((g) => g.id == id);
    if (i < 0) return;
    db.guarantors[i].lastRemindedAt = DateTime.now().toIso8601String();
    _logGuarantor(id, desc: '📤 تم إرسال تذكير للكفيل', type: 'reminder');
    save(); notifyListeners();
  }

  /// يرجّع الكفيل الرسمي بالرقم (لو موجود) — للربط بين العميل والكفيل.
  Guarantor? guarantorByPhone(String phone) {
    final i = db.guarantors.indexWhere((g) => g.phone == phone);
    return i >= 0 ? db.guarantors[i] : null;
  }

  Guarantor? guarantorById(String id) {
    final i = db.guarantors.indexWhere((g) => g.id == id);
    return i >= 0 ? db.guarantors[i] : null;
  }

  /// يضيف قيد لسجل الكفيل (بيبني كيان رسمي لو مش موجود بالرقم).
  void _logGuarantor(String id,
      {required String desc, double amount = 0, String type = 'note', String? phone}) {
    int i = db.guarantors.indexWhere((g) => g.id == id);
    if (i < 0 && phone != null) i = db.guarantors.indexWhere((g) => g.phone == phone);
    if (i < 0) return;
    db.guarantors[i].log.insert(0, {
      'date': _today(),
      'ts': DateTime.now().toIso8601String(),
      'desc': desc,
      'amount': amount,
      'type': type,
    });
  }

  /// تسجيل دفعة على الكفيل (سداد نيابة عن عميل أو سداد مباشر).
  /// [memberId] اختياري — لو اترصد يتخصم من رصيد العميل كمان.
  void recordGuarantorPayment(String guarantorId, double amount,
      {String note = '', String? memberId}) {
    final gi = db.guarantors.indexWhere((g) => g.id == guarantorId);
    if (gi < 0 || amount <= 0) return;
    String memberName = '';
    if (memberId != null) {
      final mi = db.members.indexWhere((m) => m.id == memberId);
      if (mi >= 0) {
        memberName = db.members[mi].name;
        db.members[mi].balance += amount; // سداد يقلّل المديونية
        db.members[mi].log.insert(0, {
          'date': _today(),
          'desc': '🤝 سداد عن طريق الكفيل ${db.guarantors[gi].name}'
              '${note.isNotEmpty ? ' · $note' : ''}',
          'amount': amount,
          'type': 'guarantor_pay',
        });
      }
    }
    final forWho = memberName.isNotEmpty ? ' عن $memberName' : '';
    db.guarantors[gi].log.insert(0, {
      'date': _today(),
      'ts': DateTime.now().toIso8601String(),
      'desc': '💰 دفعة$forWho${note.isNotEmpty ? ' · $note' : ''}',
      'amount': amount,
      'type': 'payment',
      if (memberId != null) 'memberId': memberId,
    });
    save(); notifyListeners();
  }

  /// حذف قيد من سجل الكفيل (بالـ ts أو الفهرس).
  void deleteGuarantorLog(String guarantorId, int index) {
    final gi = db.guarantors.indexWhere((g) => g.id == guarantorId);
    if (gi < 0 || index < 0 || index >= db.guarantors[gi].log.length) return;
    db.guarantors[gi].log.removeAt(index);
    save(); notifyListeners();
  }

  // ─── SEND GB TO MEMBER ────────────────────────────────────────
  void sendGbToMember(String memberId, double gb, {bool paid = false, double price = 0, String note = ''}) {
    final i = db.members.indexWhere((m) => m.id == memberId);
    if (i < 0) return;
    if (paid && price > 0) db.members[i].balance -= price;
    final noteStr = note.isNotEmpty ? ' · $note' : '';
    final gbLabel = gb == gb.toInt() ? '${gb.toInt()}' : '$gb';
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': paid
          ? '📶 إرسال $gbLabel جيجا (بفلوس ${price.toStringAsFixed(0)} ج)$noteStr'
          : '🎁 إرسال $gbLabel جيجا (هدية)$noteStr',
      'amount': paid ? -price : 0,
      'type': 'gb',
    });
    save(); notifyListeners();
  }

  void sendMinutesToMember(String memberId, int minutes, {String type = 'local', bool paid = false, double price = 0, String note = ''}) {
    final i = db.members.indexWhere((m) => m.id == memberId);
    if (i < 0) return;
    if (paid && price > 0) db.members[i].balance -= price;
    final noteStr = note.isNotEmpty ? ' · $note' : '';
    final typeLabel = type == 'intl' ? 'دولي' : 'محلي';
    final emoji = type == 'intl' ? '🌍' : '📞';
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': paid
          ? '$emoji $minutes دقيقة $typeLabel (بفلوس ${price.toStringAsFixed(0)} ج)$noteStr'
          : '$emoji $minutes دقيقة $typeLabel (هدية)$noteStr',
      'amount': paid ? -price : 0,
      'type': 'minutes',
    });
    save(); notifyListeners();
  }

  // ─── LINE TAXES / FEES ────────────────────────────────────────
  void addLineTax(String memberId, double amount, String note) {
    final i = db.members.indexWhere((m) => m.id == memberId);
    if (i < 0) return;
    db.members[i].balance -= amount;
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': '🏦 ضرائب/رسوم خط${note.isNotEmpty ? ': $note' : ''}',
      'amount': -amount,
      'type': 'tax',
    });
    save(); notifyListeners();
  }

  // ─── DEBT REMINDER COUNTER ───────────────────────────────────
  /// تسجيل إرسال تذكير مديونية — channel: 'wa_debt' | 'wa_statement' | 'sms' | 'manual'
  void recordReminderSent(String memberId, String channel) {
    final i = db.members.indexWhere((m) => m.id == memberId);
    if (i < 0) return;
    db.members[i].reminderLog.insert(0, {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'ch': channel,
    });
    const chLabel = {
      'sms': 'SMS',
      'wa': 'واتساب',
      'whatsapp': 'واتساب',
      'manual': 'يدوي',
    };
    _addLog(db.members[i], 'message',
        'إرسال رسالة (${chLabel[channel] ?? channel}) للعميل ${db.members[i].name}');
    save();
    notifyListeners();
  }

  /// تنقيص العداد يدوياً (لو فشل الإرسال) — يمسح أحدث حركة في الشهر الحالي
  void decrementReminder(String memberId) {
    final i = db.members.indexWhere((m) => m.id == memberId);
    if (i < 0) return;
    final now = DateTime.now();
    final idx = db.members[i].reminderLog.indexWhere((e) {
      final ts = (e['ts'] ?? 0) as int;
      if (ts == 0) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return d.year == now.year && d.month == now.month;
    });
    if (idx < 0) return; // مفيش حركات الشهر ده
    db.members[i].reminderLog.removeAt(idx);
    save();
    notifyListeners();
  }

  /// زيادة العداد يدوياً (حركة يدوية بتاريخ النهاردة)
  void incrementReminderManual(String memberId) =>
      recordReminderSent(memberId, 'manual');

  /// حذف حركة محددة من سجل التذكيرات (بالـ timestamp)
  void deleteReminderEntry(String memberId, int ts) {
    final i = db.members.indexWhere((m) => m.id == memberId);
    if (i < 0) return;
    db.members[i].reminderLog.removeWhere((e) => (e['ts'] ?? 0) == ts);
    save();
    notifyListeners();
  }

  // ─── MEMBER NOTES ─────────────────────────────────────────────
  void addMemberNote(String memberId, String note) {
    final i = db.members.indexWhere((m) => m.id == memberId);
    if (i < 0) return;
    db.members[i].log.insert(0, {
      'date': _today(),
      'desc': '📝 ملاحظة: $note',
      'amount': 0,
      'type': 'note',
    });
    save(); notifyListeners();
  }

  // ─── COMPLAINTS ──────────────────────────────────────────────
  void addComplaint(String gid, Map<String, dynamic> complaint) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].complaints.add(complaint);
    save();
    notifyListeners();
  }

  void deleteComplaint(String gid, String complaintId) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].complaints.removeWhere((c) => c['id'] == complaintId);
    save();
    notifyListeners();
  }

  void resolveComplaint(String gid, String complaintId) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final ci = db.groups[i].complaints.indexWhere((c) => c['id'] == complaintId);
    if (ci < 0) return;
    db.groups[i].complaints[ci] = {...db.groups[i].complaints[ci], 'resolved': true};
    save();
    notifyListeners();
  }

  void updateComplaint(String gid, String complaintId, Map<String, dynamic> updated) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final ci = db.groups[i].complaints.indexWhere((c) => c['id'] == complaintId);
    if (ci < 0) return;
    db.groups[i].complaints[ci] = {...db.groups[i].complaints[ci], ...updated};
    save();
    notifyListeners();
  }

  // ─── الشكاوى الموحّدة (كل الخطوط في مكان واحد) ────────────────
  /// حالة الشكوى: 'pending' (لسه) / 'inProgress' (شغالة) / 'resolved' (تمت)
  String complaintStatus(Map<String, dynamic> c) {
    if (c['resolved'] == true) return 'resolved';
    final s = (c['status'] ?? '').toString();
    if (s == 'inProgress' || s == 'resolved' || s == 'pending') return s;
    return 'pending';
  }

  /// كل الشكاوى من كل الخطوط، مع بيانات الخط، مرتّبة بالأحدث
  List<Map<String, dynamic>> allComplaints() {
    final out = <Map<String, dynamic>>[];
    for (final g in db.groups) {
      for (final c in g.complaints) {
        out.add({
          ...c,
          '_gid': g.id,
          '_groupPhone': g.phone,
          '_groupOwner': g.ownerName ?? '',
          '_status': complaintStatus(c),
        });
      }
    }
    out.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    return out;
  }

  /// تغيير حالة الشكوى مباشرة (للفلاتر: لسه/شغالة/تمت)
  void setComplaintStatus(String gid, String complaintId, String status) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final ci = db.groups[i].complaints.indexWhere((c) => c['id'] == complaintId);
    if (ci < 0) return;
    db.groups[i].complaints[ci] = {
      ...db.groups[i].complaints[ci],
      'status': status,
      'resolved': status == 'resolved',
    };
    save();
    notifyListeners();
  }

  // ─── GIFTS (new warehouse system) ────────────────────────────
  void addGiftType(Map<String, dynamic> giftType) {
    db.giftTypes.add(giftType);
    save();
    notifyListeners();
  }

  void deleteGiftType(String id) {
    db.giftTypes.removeWhere((g) => g['id'] == id);
    save();
    notifyListeners();
  }

  void assignGiftToGroup(String gid, Map<String, dynamic> giftType) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    if (db.groups[i].gifts.length >= 2) return;
    db.groups[i].gifts.add({
      'giftTypeId': giftType['id'],
      'name': giftType['name'],
      'price': giftType['price'],
      'date': _today(),
      'step': 'branch', // 'branch' | 'renter' | 'used'
    });
    save();
    notifyListeners();
  }

  void removeGiftFromGroup(String gid, int index, {bool addProfit = false}) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0 || index >= db.groups[i].gifts.length) return;
    // ربح يُضاف فقط لو الخطوة الحالية "تم الاستخدام"
    final currentStep = db.groups[i].gifts[index]['step'] ?? 'branch';
    if (addProfit && currentStep == 'used') {
      final price = (db.groups[i].gifts[index]['price'] ?? 0).toDouble();
      db.groups[i].giftProfit += price;
    }
    db.groups[i].gifts.removeAt(index);
    save();
    notifyListeners();
  }

  void updateGiftStep(String gid, int index, String step) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0 || index >= db.groups[i].gifts.length) return;
    final oldStep = db.groups[i].gifts[index]['step'] ?? 'branch';
    // أضف ربح عند الانتقال إلى "used"، واخصمه لو رجع
    final price = (db.groups[i].gifts[index]['price'] ?? 0).toDouble();
    if (step == 'used' && oldStep != 'used') {
      db.groups[i].giftProfit += price;
    } else if (step != 'used' && oldStep == 'used') {
      db.groups[i].giftProfit -= price;
    }
    db.groups[i].gifts[index]['step'] = step;
    save(); notifyListeners();
  }

  void setGroupGiftProfit(String gid, double amount) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].giftProfit = amount;
    save(); notifyListeners();
  }

  void updateGiftInGroup(String gid, int index, Map<String, dynamic> giftType) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0 || index >= db.groups[i].gifts.length) return;
    db.groups[i].gifts[index] = {
      'giftTypeId': giftType['id'],
      'name': giftType['name'],
      'price': giftType['price'],
      'date': _today(),
    };
    save();
    notifyListeners();
  }

  void archiveAndClearGroupGifts(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0 || db.groups[i].gifts.isEmpty) return;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    db.giftLog.add({
      'month': month,
      'archivedAt': _today(),
      'gid': gid,
      'phone': db.groups[i].phone,
      'gifts': List<Map<String, dynamic>>.from(db.groups[i].gifts),
    });
    db.groups[i].gifts.clear();
    save();
    notifyListeners();
  }

  void clearGiftsMonth(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i >= 0) db.groups[i].gifts.clear();
    save();
    notifyListeners();
  }

  // ─── GIFTS DASHBOARD (نموذج الهديتين الثابتتين) ───────────────
  /// id ثابت للهدية العامة في المخزن (slot = 0 أو 1)
  String giftGlobalId(int slot) => 'gift_global_$slot';

  /// الهدية العامة المخزّنة في المخزن (null لو مش متعرّفة)
  Map<String, dynamic>? globalGift(int slot) {
    final id = giftGlobalId(slot);
    final idx = db.giftTypes.indexWhere((g) => g['id'] == id);
    return idx >= 0 ? db.giftTypes[idx] : null;
  }

  /// تعريف/تعديل هدية المخزن (الاسم والسعر) — slot = 0 أو 1
  void setGlobalGift(int slot, String name, double price) {
    final id = giftGlobalId(slot);
    final entry = {'id': id, 'name': name, 'price': price};
    final idx = db.giftTypes.indexWhere((g) => g['id'] == id);
    if (idx >= 0) {
      db.giftTypes[idx] = entry;
    } else {
      db.giftTypes.add(entry);
    }
    // حدّث الاسم/السعر في الخطوط اللي معلّمة الهدية دي ولسه ماتباعتش
    for (final g in db.groups) {
      for (final e in g.gifts) {
        if (e['giftTypeId'] == id && e['sold'] != true) {
          e['name'] = name;
          e['price'] = price;
        }
      }
    }
    save();
    notifyListeners();
  }

  /// هل الخط معلّم إنه استلم هدية المخزن رقم slot؟
  bool giftReceived(String gid, int slot) {
    final g = db.groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    return g.gifts.any((e) => e['giftTypeId'] == giftGlobalId(slot));
  }

  /// هل تم بيع هدايا الخط (نزل الكاش)؟
  bool giftSold(String gid) {
    final g = db.groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final received = g.gifts
        .where((e) =>
            e['giftTypeId'] == giftGlobalId(0) ||
            e['giftTypeId'] == giftGlobalId(1))
        .toList();
    return received.isNotEmpty && received.every((e) => e['sold'] == true);
  }

  /// تبديل علامة استلام هدية المخزن (slot) لخط — مع تصحيح الربح لو كانت مباعة
  void toggleGiftReceived(String gid, int slot) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final gt = globalGift(slot);
    if (gt == null) return;
    final id = gt['id'] as String;
    final eIdx = g.gifts.indexWhere((e) => e['giftTypeId'] == id);
    if (eIdx >= 0) {
      // إزالة العلامة — لو كانت مباعة، اخصم ربحها
      if (g.gifts[eIdx]['sold'] == true) {
        g.giftProfit -= (g.gifts[eIdx]['price'] ?? 0).toDouble();
        if (g.giftProfit < 0) g.giftProfit = 0;
      }
      g.gifts.removeAt(eIdx);
    } else {
      g.gifts.add({
        'giftTypeId': id,
        'name': gt['name'],
        'price': gt['price'],
        'date': _today(),
        'sold': false,
      });
    }
    save();
    notifyListeners();
  }

  /// تبديل حالة "تم البيع" لكل هدايا الخط — يضيف/يخصم الربح أوتوماتيك
  void toggleGiftSold(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final received = g.gifts
        .where((e) =>
            e['giftTypeId'] == giftGlobalId(0) ||
            e['giftTypeId'] == giftGlobalId(1))
        .toList();
    if (received.isEmpty) return;
    final currentlySold = received.every((e) => e['sold'] == true);
    if (currentlySold) {
      // إلغاء البيع — اخصم
      for (final e in received) {
        if (e['sold'] == true) {
          g.giftProfit -= (e['price'] ?? 0).toDouble();
          e['sold'] = false;
        }
      }
      if (g.giftProfit < 0) g.giftProfit = 0;
    } else {
      // تأكيد البيع — أضف ربح اللي لسه ماتباعش
      for (final e in received) {
        if (e['sold'] != true) {
          g.giftProfit += (e['price'] ?? 0).toDouble();
          e['sold'] = true;
        }
      }
    }
    save();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  //  GIFTS V2 — مخزن أنواع متعددة + 3 مراحل لكل خط
  //  المرحلة: chosen (أحمر) → received (أصفر) → sold (أخضر = ربح)
  //  البيانات تُخزّن في group.gifts كـ:
  //    { giftTypeId, name, price, date, stage: 'chosen'|'received'|'sold' }
  // ═══════════════════════════════════════════════════════════════

  /// كل أنواع الهدايا المعرّفة في المخزن (تتجاهل أي بيانات قديمة بدون اسم)
  List<Map<String, dynamic>> get giftCatalog =>
      db.giftTypes.where((g) => (g['name'] ?? '').toString().trim().isNotEmpty).toList();

  /// إضافة نوع هدية جديد للمخزن
  void addGiftTypeV2(String name, double price) {
    final id = 'gift_${DateTime.now().millisecondsSinceEpoch}';
    db.giftTypes.add({'id': id, 'name': name.trim(), 'price': price});
    save(); notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════
  //  نظام المربعين (هديتين لكل خط) — تصميم أبو عمر
  //  كل خط له خانتين (slot 0 و 1). كل خانة تختار منها نوع هدية من المخزن.
  //  لونين بس:  🔴 أحمر = اتخصصت (لسه ما اتباعتش)  |  🟢 أخضر = اتباعت (تضيف ربح).
  //  تُخزّن في group.gifts كـ: { slot, giftTypeId, name, price, sold, date }
  // ════════════════════════════════════════════════════════════════
  // ── نظام فوترة الخط (شهر وشهر) — لمراجعة الفواتير فقط ──────────
  void setGroupBillingSystem(String gid, String system) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].billingSystem = system; // 'fixed' | 'bimonthly'
    save();
    notifyListeners();
  }

  /// ضبط المبلغ الثابت (التقديري) لخط — يُستخدم في شاشة تقسيم فاتورة الحساب المدموج.
  void setGroupFixedBill(String gid, double amount) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].fixedBillAmount = amount < 0 ? 0 : amount;
    save();
    notifyListeners();
  }

  Map<String, dynamic>? lineGiftSlot(String gid, int slot) {
    final g = db.groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final idx = g.gifts.indexWhere((e) => (e['slot'] ?? -1) == slot);
    return idx >= 0 ? g.gifts[idx] : null;
  }

  void setLineGiftSlot(String gid, int slot, Map<String, dynamic> giftType) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final idx = g.gifts.indexWhere((e) => (e['slot'] ?? -1) == slot);
    // لو الخانة فيها هدية مباعة، اخصم ربحها قبل الاستبدال
    if (idx >= 0 && g.gifts[idx]['sold'] == true) {
      g.giftProfit -= (g.gifts[idx]['price'] ?? 0).toDouble();
      if (g.giftProfit < 0) g.giftProfit = 0;
    }
    final entry = {
      'slot': slot,
      'giftTypeId': giftType['id'],
      'name': giftType['name'],
      'price': giftType['price'],
      'sold': false,
      'date': _today(),
    };
    if (idx >= 0) {
      g.gifts[idx] = entry;
    } else {
      g.gifts.add(entry);
    }
    save();
    notifyListeners();
  }

  void clearLineGiftSlot(String gid, int slot) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final idx = g.gifts.indexWhere((e) => (e['slot'] ?? -1) == slot);
    if (idx < 0) return;
    if (g.gifts[idx]['sold'] == true) {
      g.giftProfit -= (g.gifts[idx]['price'] ?? 0).toDouble();
      if (g.giftProfit < 0) g.giftProfit = 0;
    }
    g.gifts.removeAt(idx);
    save();
    notifyListeners();
  }

  void toggleLineGiftSold(String gid, int slot) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final idx = g.gifts.indexWhere((e) => (e['slot'] ?? -1) == slot);
    if (idx < 0) return;
    final wasSold = g.gifts[idx]['sold'] == true;
    final price = (g.gifts[idx]['price'] ?? 0).toDouble();
    if (wasSold) {
      g.gifts[idx]['sold'] = false;
      g.giftProfit -= price;
      if (g.giftProfit < 0) g.giftProfit = 0;
    } else {
      g.gifts[idx]['sold'] = true;
      g.giftProfit += price;
    }
    save();
    notifyListeners();
  }

  /// تعديل نوع هدية (الاسم/السعر) — يحدّث الخطوط اللي لسه ما نزّلتش ربحها
  void updateGiftType(String id, String name, double price) {
    final idx = db.giftTypes.indexWhere((g) => g['id'] == id);
    if (idx < 0) return;
    db.giftTypes[idx] = {'id': id, 'name': name.trim(), 'price': price};
    for (final g in db.groups) {
      for (final e in g.gifts) {
        if (e['giftTypeId'] == id && e['stage'] != 'sold') {
          e['name'] = name.trim();
          e['price'] = price;
        }
      }
    }
    save(); notifyListeners();
  }

  /// حذف نوع هدية من المخزن — يشيل اختياراته من الخطوط (ويخصم ربح المباع منها)
  void deleteGiftTypeV2(String id) {
    for (final g in db.groups) {
      final eIdx = g.gifts.indexWhere((e) => e['giftTypeId'] == id);
      if (eIdx >= 0) {
        if (g.gifts[eIdx]['stage'] == 'sold') {
          g.giftProfit -= (g.gifts[eIdx]['price'] ?? 0).toDouble();
          if (g.giftProfit < 0) g.giftProfit = 0;
        }
        g.gifts.removeAt(eIdx);
      }
    }
    db.giftTypes.removeWhere((g) => g['id'] == id);
    save(); notifyListeners();
  }

  /// النوع المختار لخط معيّن (أول هدية مسجّلة) — null لو مفيش اختيار
  Map<String, dynamic>? chosenGiftForGroup(String gid) {
    final g = db.groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    if (g.gifts.isEmpty) return null;
    // أول هدية ليها giftTypeId موجود في الكتالوج الحالي
    for (final e in g.gifts) {
      if (db.giftTypes.any((t) => t['id'] == e['giftTypeId'])) return e;
    }
    return g.gifts.first;
  }

  /// مرحلة هدية الخط: 'none' | 'chosen' | 'received' | 'sold'
  String giftStage(String gid) {
    final e = chosenGiftForGroup(gid);
    if (e == null) return 'none';
    final s = (e['stage'] ?? 'chosen').toString();
    // توافق مع البيانات القديمة: لو فيه sold==true اعتبرها أخضر
    if (e['sold'] == true && s != 'sold') return 'sold';
    return s;
  }

  /// اختيار نوع هدية لخط (يستبدل أي اختيار سابق) — يبدأ بمرحلة chosen (أحمر)
  void setGroupGiftChoice(String gid, String giftTypeId) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final t = db.giftTypes.firstWhere((x) => x['id'] == giftTypeId,
        orElse: () => {});
    if (t.isEmpty) return;
    // لو كان فيه اختيار قديم مباع، اخصم ربحه قبل الاستبدال
    for (final e in g.gifts) {
      if (e['stage'] == 'sold' || e['sold'] == true) {
        g.giftProfit -= (e['price'] ?? 0).toDouble();
      }
    }
    if (g.giftProfit < 0) g.giftProfit = 0;
    g.gifts
      ..clear()
      ..add({
        'giftTypeId': giftTypeId,
        'name': t['name'],
        'price': t['price'],
        'date': _today(),
        'stage': 'chosen',
      });
    save(); notifyListeners();
  }

  /// إلغاء اختيار الهدية لخط تماماً
  void clearGroupGiftChoice(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    for (final e in g.gifts) {
      if (e['stage'] == 'sold' || e['sold'] == true) {
        g.giftProfit -= (e['price'] ?? 0).toDouble();
      }
    }
    if (g.giftProfit < 0) g.giftProfit = 0;
    g.gifts.clear();
    save(); notifyListeners();
  }

  /// تقديم مرحلة الهدية للأمام: chosen→received→sold ثم يلفّ لـ chosen
  /// sold يضيف السعر للربح، والرجوع منه يخصمه.
  void cycleGiftStage(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final e = chosenGiftForGroup(gid);
    if (e == null) return;
    final cur = giftStage(gid);
    final price = (e['price'] ?? 0).toDouble();
    if (cur == 'chosen') {
      e['stage'] = 'received';
    } else if (cur == 'received') {
      e['stage'] = 'sold';
      e['sold'] = true;
      g.giftProfit += price; // نزّل الكاش/الربح
    } else {
      // من sold → نرجع لـ chosen ونخصم الربح
      e['stage'] = 'chosen';
      e['sold'] = false;
      g.giftProfit -= price;
      if (g.giftProfit < 0) g.giftProfit = 0;
    }
    save(); notifyListeners();
  }

  // ─── GUEST USERS ─────────────────────────────────────────────
  void addGuestUser(GuestUser g) {
    db.guestUsers.add(g);
    save(); notifyListeners();
  }

  void editGuestUser(GuestUser g) {
    final i = db.guestUsers.indexWhere((x) => x.id == g.id);
    if (i >= 0) { db.guestUsers[i] = g; save(); notifyListeners(); }
  }

  void deleteGuestUser(String id) {
    db.guestUsers.removeWhere((g) => g.id == id);
    save(); notifyListeners();
  }

  void toggleGuestPaid(String id) {
    final i = db.guestUsers.indexWhere((g) => g.id == id);
    if (i < 0) return;
    db.guestUsers[i].isPaid = !db.guestUsers[i].isPaid;
    save(); notifyListeners();
  }

  void toggleGuestCollected(String id) {
    final i = db.guestUsers.indexWhere((g) => g.id == id);
    if (i < 0) return;
    db.guestUsers[i].isCollected = !db.guestUsers[i].isCollected;
    save(); notifyListeners();
  }

  /// تحويل الضيف إلى عميل دائم في إحدى المجموعات
  void transferGuestToPermanent(String guestId, String targetGid, {double? price}) {
    final gi = db.guestUsers.indexWhere((g) => g.id == guestId);
    if (gi < 0) return;
    final guest = db.guestUsers[gi];
    final newMember = Member(
      id: db.mid.toString(),
      gid: targetGid,
      name: guest.clientName,
      phone: guest.clientPhone,
      price: price ?? guest.clientAmount,
      date: guest.startDate,
      notes: guest.notes,
    );
    db.members.add(newMember);
    db.mid++;
    db.guestUsers.removeAt(gi);
    _addLog(newMember, 'add', 'تحويل ضيف إلى عميل دائم: ${guest.clientName}');
    save(); notifyListeners();
  }

  // ─── REWARD POINTS ────────────────────────────────────────────
  void redeemPoints(String gid, {int? ptsToRedeem, String notes = '', String? date}) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0 || db.groups[i].rewardPoints <= 0) return;
    final available = db.groups[i].rewardPoints;
    final pts = (ptsToRedeem ?? available).clamp(1, available);
    final value = pts * db.groups[i].pointsValue;
    final redemptionDate = date ?? _today();
    db.groups[i].pointsRedemptions.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': redemptionDate,
      'pts': pts,
      'value': value,
      'notes': notes,
    });
    // النقاط المستردة تُخصم من الوعاء التراكمي — لا تُضاف لربح الهدايا لتجنب ضياعها بالتصفير الشهري
    db.groups[i].pendingPointsProfit =
        (db.groups[i].pendingPointsProfit - value).clamp(0, double.infinity);
    db.groups[i].rewardPoints -= pts;
    _addLog(null, 'points', 'استرداد $pts نقطة = ${value.toStringAsFixed(0)} ج — ${db.groups[i].phone}');
    save(); notifyListeners();
  }

  void setPointsValueRate(String gid, double rate) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].pointsValue = rate;
    save(); notifyListeners();
  }

  // ─── STICKY NOTE ──────────────────────────────────────────────
  void updateGroupStickyNote(String gid, String? note) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].stickyNote = note?.trim().isEmpty == true ? null : note?.trim();
    save(); notifyListeners();
  }

  // ─── INVOICE LOG ──────────────────────────────────────────────
  void addMemberInvoice(String mid, {required double amount, String notes = '', required String dueDate}) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].invoiceLog.insert(0, {
      'amount': amount,
      'notes': notes,
      'dueDate': dueDate,
      'isPaid': false,
      'paidDate': null,
      'addedDate': _today(),
    });
    save(); notifyListeners();
  }

  void markInvoicePaid(String mid, int invoiceIndex) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0 || invoiceIndex >= db.members[i].invoiceLog.length) return;
    db.members[i].invoiceLog[invoiceIndex]['isPaid'] = true;
    db.members[i].invoiceLog[invoiceIndex]['paidDate'] = _today();
    save(); notifyListeners();
  }

  void deleteInvoice(String mid, int invoiceIndex) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0 || invoiceIndex >= db.members[i].invoiceLog.length) return;
    db.members[i].invoiceLog.removeAt(invoiceIndex);
    save(); notifyListeners();
  }

  // ─── NAT-ID PHOTO ─────────────────────────────────────────────
  void setMemberNatIdPhoto(String mid, String path) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].natIdPhotoPath = path;
    save(); notifyListeners();
  }

  void setGroupOwnerPhoto(String gid, String path) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].ownerPhoto = path;
    save(); notifyListeners();
  }

  // ─── DEFERRAL ─────────────────────────────────────────────────
  void setMemberDeferral(String mid, String date, String note) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].deferralDate = date;
    db.members[i].deferralNote = note.trim().isEmpty ? null : note.trim();
    _addLog(db.members[i], 'deferral', 'تأجيل دفع ${db.members[i].name} حتى $date');
    save(); notifyListeners();
  }

  void clearMemberDeferral(String mid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].deferralDate = null;
    db.members[i].deferralNote = null;
    save(); notifyListeners();
  }

  // ─── MAIN LINES ──────────────────────────────────────────────
  void addMainLine(MainLine line) {
    db.mainLines.insert(0, line);
    save(); notifyListeners();
    SupabaseService.upsertMainLine(line); // fire & forget
  }

  void editMainLine(MainLine line) {
    final i = db.mainLines.indexWhere((l) => l.id == line.id);
    if (i < 0) return;
    db.mainLines[i] = line;
    save(); notifyListeners();
    SupabaseService.upsertMainLine(line);
  }

  void deleteMainLine(String id) {
    db.mainLines.removeWhere((l) => l.id == id);
    save(); notifyListeners();
    SupabaseService.deleteMainLine(id);
  }

  void _addMonthlyPoints() {
    final now = DateTime.now();
    if (now.day != 7) return;
    final key = '${now.year}-${now.month}-points';
    bool changed = false;
    for (var i = 0; i < db.groups.length; i++) {
      final g = db.groups[i];
      if (g.lastBillActualMonth == key) continue;
      final pts = g.pointsMonthly ?? (g.type == '3800' ? 1000 : 2000);
      if (pts <= 0) continue;
      db.groups[i].rewardPoints += pts;
      // قيمة النقاط الجديدة تضاف للربح المعلق (لا للنقاط المتراكمة)
      db.groups[i].pendingPointsProfit += pts * g.pointsValue;
      db.groups[i].lastBillActualMonth = key;
      changed = true;
    }
    if (changed) save();
  }

  /// تصفير ربح النقاط الشهري المعلق بعد تسجيله في التقرير
  void resetPendingPointsProfit(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].pendingPointsProfit = 0;
    save(); notifyListeners();
  }

  void _autoGiftReset() {
    final now = DateTime.now();
    if (now.day != 1) return;
    final monthKey = '${now.year}-${now.month}';
    bool changed = false;
    for (var i = 0; i < db.groups.length; i++) {
      if (db.groups[i].lastGiftResetMonth == monthKey) continue;
      db.groups[i].giftProfit = 0;
      db.groups[i].lastGiftResetMonth = monthKey;
      changed = true;
    }
    if (changed) save();
  }

  // ─── AUTO GROUP NOTES ─────────────────────────────────────────
  void _autoGroupNotes() {
    final now = DateTime.now();
    final day = now.day;
    if (day != 1 && day != 15) return;
    final key = '${now.year}-${now.month}-notes-$day';
    bool changed = false;
    for (var i = 0; i < db.groups.length; i++) {
      final g = db.groups[i];
      if (g.lastNotesMonth == key) continue;
      final isCycle2 = g.billingCycle == 'cycle2';
      if (day == 1 && !isCycle2) {
        db.groups[i].groupNotes.insert(0, {
          'text': '📅 تجديد سيكل 1 — أول الشهر ${_monthName(now.month)} ${now.year}',
          'date': _today(),
          'type': 'auto',
        });
        db.groups[i].lastNotesMonth = key;
        changed = true;
      } else if (day == 15 && isCycle2) {
        db.groups[i].groupNotes.insert(0, {
          'text': '📅 تجديد سيكل 2 — منتصف الشهر ${_monthName(now.month)} ${now.year}',
          'date': _today(),
          'type': 'auto',
        });
        db.groups[i].lastNotesMonth = key;
        changed = true;
      }
    }
    if (changed) save();
  }

  // ─── LAST BILL AMOUNT ──────────────────────────────────────────
  void setLastBillAmount(String gid, double amount) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].lastBillAmount = amount;
    save(); notifyListeners();
  }

  /// إضافة فاتورة جديدة — تُسجَّل في CompanyBills وتُحدَّث المديونية.
  /// المبلغ هو الإجمالي المُجمَّع للخط الرئيسي + خطوطه المضمومة (فاتورة واحدة).
  void addGroupBill(String gid, double amount, {String? note, String? issueDate}) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final children = db.groups.where((g) => g.parentGroupId == gid).toList();
    // الفاتورة الثابتة المرجعية = الثابت للخط الرئيسي + الخطوط المضمومة
    final combinedFixed = db.groups[i].fixedBillAmount +
        children.fold<double>(0, (s, c) => s + c.fixedBillAmount);
    final childNote = children.isEmpty
        ? null
        : 'تشمل ${children.length} خط: ${children.map((c) => c.phone).join(' • ')}';
    final fullNote = [note, childNote].where((x) => x != null).join(' | ');
    final bill = CompanyBill(
      id: now.millisecondsSinceEpoch.toString(),
      groupId: gid,
      month: month,
      fixedAmount: combinedFixed,
      actualAmount: amount,
      isActual: true,
      note: fullNote.isEmpty ? null : fullNote,
      date: (issueDate != null && issueDate.trim().isNotEmpty)
          ? issueDate.trim()
          : _today(),
    );
    db.companyBills.insert(0, bill);
    db.groups[i].lastBillAmount = amount;
    db.groups[i].billDebt += amount;
    db.groups[i].actualBillAmount = amount;
    db.groups[i].groupNotes.insert(0, {
      'text': '📋 فاتورة $month — ${amount.toStringAsFixed(0)} ج${children.isNotEmpty ? ' (مجمّعة لـ ${children.length + 1} خط)' : ''}${note != null ? ' | $note' : ''}',
      'date': _today(),
      'type': 'bill',
    });
    _addLog(null, 'bill_add', 'فاتورة جديدة ${db.groups[i].phone}: ${amount.toStringAsFixed(0)} ج');

    save(); notifyListeners();
  }

  /// تعديل تاريخ نزول فاتورة (يأثّر على عدّاد آخر موعد دفع = التاريخ + سماح الشركة)
  void setBillIssueDate(String billId, String dmy) {
    final bi = db.companyBills.indexWhere((b) => b.id == billId);
    if (bi < 0) return;
    db.companyBills[bi].date = dmy.trim();
    _addLog(null, 'bill_edit', 'تعديل تاريخ فاتورة → $dmy');
    save(); notifyListeners();
  }

  /// تعديل مبلغ فاتورة فعلية (تحكّم كامل + تصحيح الأخطاء مع الشركة)
  void editBillAmount(String billId, double newAmount) {
    final bi = db.companyBills.indexWhere((b) => b.id == billId);
    if (bi < 0 || newAmount < 0) return;
    final bill = db.companyBills[bi];
    final old = bill.actualAmount;
    final diff = newAmount - old;
    bill.actualAmount = newAmount;
    bill.isActual = true;
    final gi = db.groups.indexWhere((g) => g.id == bill.groupId);
    if (gi >= 0) {
      db.groups[gi].billDebt = (db.groups[gi].billDebt + diff).clamp(0, double.infinity);
      db.groups[gi].actualBillAmount = newAmount;
    }
    _addLog(null, 'bill_edit',
        'تعديل مبلغ فاتورة ${old.toStringAsFixed(0)} → ${newAmount.toStringAsFixed(0)} ج');
    save(); notifyListeners();
  }

  /// معاينة الفواتير غير المسددة لشركة في شهر (عدد + إجمالي المتبقّي)
  (int, double) previewProviderUnpaid(String provider, String month) {
    int count = 0;
    double total = 0;
    for (final b in db.companyBills) {
      if (b.isPaid || b.month != month) continue;
      final g = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: ''));
      if (g.provider != provider) continue;
      final rem = b.remaining;
      if (rem > 0) { count++; total += rem; }
    }
    return (count, total);
  }

  /// سداد كل الفواتير غير المسددة لشركة معيّنة في شهر (دفعة جماعية)
  (int, double) payProviderBills(String provider, String month) {
    final targets = db.companyBills.where((b) {
      if (b.isPaid || b.month != month) return false;
      final g = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: ''));
      return g.provider == provider && b.remaining > 0;
    }).toList();
    int count = 0;
    double total = 0;
    for (final b in targets) {
      final rem = b.remaining;
      payCompanyBill(b.id, rem, note: 'دفعة جماعية');
      count++;
      total += rem;
    }
    return (count, total);
  }

  /// مقارنة شهرية لإجمالي فواتير كل شركة عبر آخر N شهور (للمراجعة مع الشركات).
  /// بترجّع: { provider: { 'yyyy-mm': total, ... } }
  Map<String, Map<String, double>> providerMonthlySpend({int months = 6}) {
    final now = DateTime.now();
    final keys = <String>[];
    for (int i = months - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      keys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    final result = <String, Map<String, double>>{};
    for (final b in db.companyBills) {
      if (!keys.contains(b.month)) continue;
      final g = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: ''));
      final p = g.provider ?? 'unknown';
      result.putIfAbsent(p, () => {for (final k in keys) k: 0.0});
      result[p]![b.month] = (result[p]![b.month] ?? 0) + b.actualAmount;
    }
    return result;
  }

  /// سداد جزئي أو كلي على فاتورة محددة
  void payCompanyBill(String billId, double amount, {String? note, String? payDate}) {
    final bi = db.companyBills.indexWhere((b) => b.id == billId);
    if (bi < 0) return;
    final maxPay = db.companyBills[bi].remaining;
    if (amount <= 0) return;
    final paid = amount > maxPay ? maxPay : amount;
    final overpay = amount > maxPay ? amount - maxPay : 0.0; // دفع زيادة
    if (paid > 0) {
      final now = DateTime.now();
      db.companyBills[bi].payments.add(BillPayment(
        id: now.millisecondsSinceEpoch.toString(),
        amount: paid,
        date: (payDate != null && payDate.trim().isNotEmpty) ? payDate.trim() : _today(),
        time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        note: note,
      ));
    }
    final gid = db.companyBills[bi].groupId;
    final gi = db.groups.indexWhere((g) => g.id == gid);
    if (gi >= 0) {
      db.groups[gi].billDebt = (db.groups[gi].billDebt - paid).clamp(0, double.infinity);
      db.groups[gi].groupNotes.insert(0, {
        'text': '💳 سداد ${paid.toStringAsFixed(0)} ج على فاتورة ${db.companyBills[bi].month} — متبقي: ${db.companyBills[bi].remaining.toStringAsFixed(0)} ج',
        'date': _today(),
        'type': 'bill',
      });
      if (overpay > 0) {
        db.groups[gi].billCredit += overpay;
        db.groups[gi].groupNotes.insert(0, {
          'text': '💰 دفع زيادة ${overpay.toStringAsFixed(0)} ج — اتسجّل رصيد دائن (الإجمالي: ${db.groups[gi].billCredit.toStringAsFixed(0)} ج)',
          'date': _today(),
          'type': 'bill',
        });
      }
    }
    _addLog(null, 'bill_pay',
        'سداد فاتورة: ${paid.toStringAsFixed(0)} ج${overpay > 0 ? ' + رصيد دائن ${overpay.toStringAsFixed(0)} ج' : ''}');
    save(); notifyListeners();
  }

  /// إجمالي المتبقي على حساب (الخط الأب + توابعه) عبر كل الشهور.
  double accountRemaining(String gid) {
    final ids = <String>{gid};
    for (final c in db.groups) {
      if (c.parentGroupId == gid) ids.add(c.id);
    }
    return db.companyBills
        .where((b) => ids.contains(b.groupId))
        .fold(0.0, (s, b) => s + b.remaining);
  }

  /// سداد كل فواتير الحساب (الأب + توابعه) المتبقية دفعة واحدة.
  /// بيرجّع [إجمالي اللي اتدفع, عدد الفواتير].
  (double, int) payAccountBills(String gid, {String? note}) {
    final ids = <String>{gid};
    for (final c in db.groups) {
      if (c.parentGroupId == gid) ids.add(c.id);
    }
    final unpaid = db.companyBills
        .where((b) => ids.contains(b.groupId) && !b.isPaid)
        .toList();
    if (unpaid.isEmpty) return (0.0, 0);
    var total = 0.0;
    for (final b in unpaid) {
      final rem = b.remaining;
      if (rem <= 0) continue;
      total += rem;
      payCompanyBill(b.id, rem, note: note ?? 'سداد جماعي للحساب');
    }
    _addLog(null, 'bill_pay',
        'سداد جماعي لحساب: ${total.toStringAsFixed(0)} ج (${unpaid.length} فاتورة)',
        targetId: gid, targetType: 'group');
    return (total, unpaid.length);
  }

  /// حذف فاتورة وعكس تأثيرها على المديونية
  void deleteCompanyBill(String billId) {
    final bi = db.companyBills.indexWhere((b) => b.id == billId);
    if (bi < 0) return;
    final remaining = db.companyBills[bi].remaining;
    final gid = db.companyBills[bi].groupId;
    final gi = db.groups.indexWhere((g) => g.id == gid);
    if (gi >= 0) {
      db.groups[gi].billDebt = (db.groups[gi].billDebt - remaining).clamp(0, double.infinity);
    }
    db.companyBills.removeAt(bi);
    save(); notifyListeners();
  }

  /// إضافة فاتورة تقديرية بناءً على fixedBillAmount — لا تتطلب فاتورة فعلية بعد.
  /// لو الخط رئيسي بخطوط مضمومة، المبلغ التقديري = مجموع الثابت لكلهم (فاتورة واحدة).
  void addEstimatedBill(String gid, {String? forMonth, String? note}) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final children = db.groups.where((g) => g.parentGroupId == gid).toList();
    final amount = db.groups[i].fixedBillAmount +
        children.fold<double>(0, (s, c) => s + c.fixedBillAmount);
    if (amount <= 0) return;
    final now = DateTime.now();
    final month = forMonth ?? '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final childNote = children.isEmpty
        ? null
        : 'تشمل ${children.length} خط: ${children.map((c) => c.phone).join(' • ')}';
    final fullNote = [note, childNote].where((x) => x != null).join(' | ');
    final bill = CompanyBill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      groupId: gid,
      month: month,
      fixedAmount: amount,
      actualAmount: amount,
      isActual: false,
      note: fullNote.isEmpty ? null : fullNote,
      date: _today(),
    );
    db.companyBills.insert(0, bill);
    db.groups[i].billDebt += amount;
    db.groups[i].actualBillAmount = amount;
    db.groups[i].groupNotes.insert(0, {
      'text': '📊 فاتورة تقديرية $month — ${amount.toStringAsFixed(0)} ج${children.isNotEmpty ? ' (مجمّعة لـ ${children.length + 1} خط)' : ''}${note != null ? ' | $note' : ''}',
      'date': _today(),
      'type': 'bill',
    });
    // خصم الرصيد الدائن (دفع زيادة سابق) تلقائياً من الفاتورة الجديدة
    final credit = db.groups[i].billCredit;
    if (credit > 0) {
      final apply = credit > amount ? amount : credit;
      db.groups[i].billCredit -= apply;
      bill.payments.add(BillPayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: apply,
        date: _today(),
        note: 'خصم رصيد دائن',
      ));
      db.groups[i].billDebt = (db.groups[i].billDebt - apply).clamp(0, double.infinity);
      db.groups[i].groupNotes.insert(0, {
        'text': '💰 خصم رصيد دائن ${apply.toStringAsFixed(0)} ج من فاتورة $month — متبقي رصيد: ${db.groups[i].billCredit.toStringAsFixed(0)} ج',
        'date': _today(),
        'type': 'bill',
      });
    }
    save(); notifyListeners();
  }

  /// كم خط مؤهَّل لتوليد فاتورة تقديرية للشهر [month] (للمعاينة قبل التأكيد).
  int previewMonthlyBillsCount(String month) =>
      _eligibleForMonthlyBill(month).length;

  /// الخطوط المؤهَّلة لتوليد فاتورة تقديرية لشهر معيّن:
  /// لها مبلغ ثابت، مش متسجّلة فاتورة الشهر ده، مش خط فرعي،
  /// ولو نظامها «شهر وشهر» تتجاهل الشهر اللي قبله نزلت فيه فاتورة (المفروض فاضي).
  List<Group> _eligibleForMonthlyBill(String month) {
    final p = month.split('-');
    final prevDt = DateTime(int.parse(p[0]), int.parse(p[1]) - 1);
    final prevM = '${prevDt.year}-${prevDt.month.toString().padLeft(2, '0')}';
    final added = db.companyBills
        .where((b) => b.month == month)
        .map((b) => b.groupId)
        .toSet();
    return db.groups.where((g) {
      if (g.fixedBillAmount <= 0) return false;
      if (added.contains(g.id)) return false;
      if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) return false;
      if (g.billingSystem == 'bimonthly') {
        final hadPrev = db.companyBills.any(
            (b) => b.groupId == g.id && b.month == prevM && b.actualAmount > 0);
        if (hadPrev) return false;
      }
      return true;
    }).toList();
  }

  /// معاينة تدوير «شهر وشهر» لشهر معيّن (قراءة فقط — مايغيّرش أي مبلغ).
  /// بيرجّع: [خطوط دورها فاتورة الشهر ده], [خطوط فاضية ببلاش الشهر ده].
  (List<Group>, List<Group>) bimonthlyRotation(String month) {
    final p = month.split('-');
    final prevDt = DateTime(int.parse(p[0]), int.parse(p[1]) - 1);
    final prevM = '${prevDt.year}-${prevDt.month.toString().padLeft(2, '0')}';
    final billing = <Group>[];
    final free = <Group>[];
    for (final g in db.groups) {
      if (g.billingSystem != 'bimonthly') continue;
      if (g.parentGroupId != null && g.parentGroupId!.isNotEmpty) continue;
      final hadPrev = db.companyBills.any(
          (b) => b.groupId == g.id && b.month == prevM && b.actualAmount > 0);
      // لو نزلت الشهر اللي فات → الشهر ده فاضي؛ والعكس → دوره فاتورة
      (hadPrev ? free : billing).add(g);
    }
    return (billing, free);
  }

  /// توليد فواتير تقديرية لكل الخطوط المؤهَّلة دفعة واحدة. بيرجّع عدد اللي اتعمل.
  int generateMonthlyBills(String month) {
    final eligible = _eligibleForMonthlyBill(month);
    if (eligible.isEmpty) return 0;
    for (final g in eligible) {
      addEstimatedBill(g.id, forMonth: month);
    }
    _addLog(null, 'bill_bulk',
        'توليد ${eligible.length} فاتورة تقديرية لشهر $month');
    save(); notifyListeners();
    return eligible.length;
  }

  /// تأكيد الفاتورة الفعلية — تحويل فاتورة تقديرية إلى فعلية مع تصحيح المبلغ والمديونية
  void confirmActualBill(String billId, double newAmount) {
    final bi = db.companyBills.indexWhere((b) => b.id == billId);
    if (bi < 0) return;
    final oldAmount = db.companyBills[bi].actualAmount;
    final gid = db.companyBills[bi].groupId;
    final month = db.companyBills[bi].month;
    db.companyBills[bi].actualAmount = newAmount;
    db.companyBills[bi].isActual = true;
    final diff = newAmount - oldAmount;
    final gi = db.groups.indexWhere((g) => g.id == gid);
    if (gi >= 0) {
      db.groups[gi].billDebt = (db.groups[gi].billDebt + diff).clamp(0, double.infinity);
      db.groups[gi].actualBillAmount = newAmount;
      db.groups[gi].groupNotes.insert(0, {
        'text': '✅ تأكيد فاتورة فعلية $month — ${newAmount.toStringAsFixed(0)} ج (كانت تقديرية: ${oldAmount.toStringAsFixed(0)} ج)',
        'date': _today(),
        'type': 'bill',
      });
    }
    save(); notifyListeners();
  }

  /// تأجيل فاتورة لميعاد سماح من الشركة (أو إلغاء التأجيل بتمرير date=null)
  void deferCompanyBill(String billId, String? date, {String? note}) {
    final bi = db.companyBills.indexWhere((b) => b.id == billId);
    if (bi < 0) return;
    final b = db.companyBills[bi];
    b.deferDate = (date == null || date.isEmpty) ? null : date;
    b.deferNote = (note == null || note.trim().isEmpty) ? null : note.trim();
    final gid = b.groupId;
    final gi = db.groups.indexWhere((g) => g.id == gid);
    if (gi >= 0) {
      final txt = b.deferDate != null
          ? '⏸ تأجيل فاتورة ${b.month} لـ ${b.deferDate}${b.deferNote != null ? ' — ${b.deferNote}' : ''}'
          : '▶️ إلغاء تأجيل فاتورة ${b.month}';
      db.groups[gi].groupNotes.insert(0, {
        'text': txt,
        'date': _today(),
        'type': 'bill',
      });
    }
    _addLog(null, 'bill_defer',
        b.deferDate != null
            ? 'تأجيل فاتورة لـ ${b.deferDate}'
            : 'إلغاء تأجيل فاتورة',
        targetId: gid, targetType: 'group');
    save(); notifyListeners();
  }

  /// أقرب فاتورة مؤجَّلة وغير مسددة لمجموعة (للبادچ على الهيدر)
  CompanyBill? activeDeferredBill(String gid) {
    final list = db.companyBills
        .where((b) => b.groupId == gid && b.isDeferred)
        .toList()
      ..sort((a, c) => (a.deferDate ?? '').compareTo(c.deferDate ?? ''));
    return list.isEmpty ? null : list.first;
  }

  /// سداد جزئي أو كلي من مديونية المجموعة (legacy — للتوافق)
  void payGroupBillDebt(String gid, double amount) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final paid = amount > g.billDebt ? g.billDebt : amount;
    db.groups[i].billDebt = (g.billDebt - paid).clamp(0, double.infinity);
    db.groups[i].groupNotes.insert(0, {
      'text': '💳 سداد ${paid.toStringAsFixed(0)} ج — المتبقي: ${db.groups[i].billDebt.toStringAsFixed(0)} ج',
      'date': _today(),
      'type': 'bill',
    });
    _addLog(null, 'bill_pay', 'سداد فاتورة ${g.phone}: ${paid.toStringAsFixed(0)} ج');
    save(); notifyListeners();
  }

  void payGroupBill(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    if (g.lastBillAmount <= 0) return;
    db.groups[i].groupNotes.insert(0, {
      'text': '💳 تم سداد الفاتورة ${g.lastBillAmount.toStringAsFixed(0)} ج',
      'date': _today(),
      'type': 'bill',
    });
    _addLog(null, 'bill_pay', 'سداد فاتورة ${g.phone}: ${g.lastBillAmount.toStringAsFixed(0)} ج');
    save(); notifyListeners();
  }

  // ─── GROUP NOTES ──────────────────────────────────────────────
  void addGroupNote(String gid, String text) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    db.groups[i].groupNotes.insert(0, {
      'text': text.trim(),
      'date': _today(),
      'type': 'manual',
    });
    save(); notifyListeners();
  }

  void deleteGroupNote(String gid, int index) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    if (index < 0 || index >= db.groups[i].groupNotes.length) return;
    db.groups[i].groupNotes.removeAt(index);
    save(); notifyListeners();
  }

  /// تشغيل يدوي لإضافة نقاط الشهر الحالي لمجموعة واحدة
  void addMonthlyPointsToGroup(String gid) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    final g = db.groups[i];
    final pts = g.pointsMonthly ?? (g.type == '3800' ? 1000 : 2000);
    if (pts <= 0) return;
    db.groups[i].rewardPoints += pts;
    db.groups[i].pendingPointsProfit += pts * g.pointsValue;
    _addLog(null, 'points', 'تمت إضافة $pts نقطة لمجموعة ${g.phone}');
    save(); notifyListeners();
  }

  /// Returns days until expiry; null if no expiry set; negative if expired
  int? daysToExpiry(String gid) {
    final g = db.groups.firstWhere((x) => x.id == gid, orElse: () => Group(id: '', phone: ''));
    if (g.expiryDate == null || g.expiryDate!.isEmpty) return null;
    try {
      final exp = DateTime.parse(g.expiryDate!);
      return exp.difference(DateTime.now()).inDays;
    } catch (_) {
      return null;
    }
  }

  // ─── GENERAL NOTES (Phase 5) ──────────────────────────────────
  /// إضافة ملاحظة عامة للشغل (مستقلة عن أي خط)
  Future<void> addGeneralNote({
    required String content,
    DateTime? reminderTime,
    String color = 'yellow',
    String? memberId,
    String? memberName,
    String repeat = 'none',
  }) async {
    final note = GeneralNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      createdAt: DateTime.now(),
      reminderTime: reminderTime,
      isCompleted: false,
      color: color,
      memberId: memberId,
      memberName: memberName,
      repeat: repeat,
    );
    db.generalNotes.insert(0, note);
    save();
    notifyListeners();
    // جدولة التنبيه لو محدد وقت (المتكرر بيتجدول حتى لو الوقت الأساسي فات)
    if (reminderTime != null &&
        (repeat != 'none' || reminderTime.isAfter(DateTime.now()))) {
      await NotificationService.scheduleGeneralNoteReminder(
        noteId: note.id,
        content: note.content,
        when: reminderTime,
        repeat: repeat,
      );
    }
  }

  /// تبديل حالة الملاحظة (مكتملة / غير مكتملة)
  void toggleGeneralNoteCompleted(String noteId) {
    final i = db.generalNotes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    db.generalNotes[i].isCompleted = !db.generalNotes[i].isCompleted;
    if (db.generalNotes[i].isCompleted) {
      db.generalNotes[i].completedAt = DateTime.now();
      // الغي التنبيه لو الملاحظة اتعملت
      NotificationService.cancelGeneralNoteReminder(noteId);
    } else {
      db.generalNotes[i].completedAt = null;
      // رجّع التنبيه لو لسه ليه معاد
      final n = db.generalNotes[i];
      if (n.reminderTime != null &&
          (n.repeat != 'none' || n.reminderTime!.isAfter(DateTime.now()))) {
        NotificationService.scheduleGeneralNoteReminder(
            noteId: n.id, content: n.content, when: n.reminderTime!, repeat: n.repeat);
      }
    }
    save();
    notifyListeners();
  }

  /// 📌 تثبيت/فك تثبيت ملاحظة — المثبتة بتظهر أول القائمة
  void togglePinGeneralNote(String noteId) {
    final i = db.generalNotes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    db.generalNotes[i].pinned = !db.generalNotes[i].pinned;
    save();
    notifyListeners();
  }

  /// 🎨 تغيير لون الملاحظة
  void setGeneralNoteColor(String noteId, String color) {
    final i = db.generalNotes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    db.generalNotes[i].color = color;
    save();
    notifyListeners();
  }

  /// 🧹 أرشفة تلقائية للمكتملة من أكتر من أسبوع — بتتنادى عند فتح البرنامج
  void autoArchiveOldNotes() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    var changed = false;
    for (final n in db.generalNotes) {
      if (!n.archived &&
          n.isCompleted &&
          n.completedAt != null &&
          n.completedAt!.isBefore(cutoff)) {
        n.archived = true;
        n.archivedAt = DateTime.now();
        changed = true;
      }
    }
    if (changed) { save(); notifyListeners(); }
  }

  /// حذف ملاحظة عامة (نهائي — يُستخدم من الأرشيف فقط)
  void deleteGeneralNote(String noteId) {
    db.generalNotes.removeWhere((n) => n.id == noteId);
    NotificationService.cancelGeneralNoteReminder(noteId);
    save();
    notifyListeners();
  }

  /// أرشفة ملاحظة (الحذف من الفقاعة العائمة) — بترجع من الأرشيف في أي وقت
  void archiveGeneralNote(String noteId) {
    final i = db.generalNotes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    db.generalNotes[i].archived = true;
    db.generalNotes[i].archivedAt = DateTime.now();
    NotificationService.cancelGeneralNoteReminder(noteId);
    save();
    notifyListeners();
  }

  /// استرجاع ملاحظة من الأرشيف
  void restoreGeneralNote(String noteId) {
    final i = db.generalNotes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    db.generalNotes[i].archived = false;
    db.generalNotes[i].archivedAt = null;
    // أعد جدولة التنبيه لو ميعاده لسه جاي (أو متكرر)
    final n = db.generalNotes[i];
    if (n.reminderTime != null &&
        (n.repeat != 'none' || n.reminderTime!.isAfter(DateTime.now()))) {
      NotificationService.scheduleGeneralNoteReminder(
          noteId: n.id, content: n.content, when: n.reminderTime!, repeat: n.repeat);
    }
    save();
    notifyListeners();
  }

  /// تعديل ملاحظة (النص / التذكير / التكرار / اللون / العميل المرتبط)
  Future<void> editGeneralNote(String noteId,
      {String? content,
      DateTime? reminderTime,
      bool clearReminder = false,
      String? repeat,
      String? color,
      String? memberId,
      String? memberName,
      bool clearMember = false}) async {
    final i = db.generalNotes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    final n = db.generalNotes[i];
    if (content != null && content.trim().isNotEmpty) n.content = content.trim();
    if (color != null) n.color = color;
    if (clearMember) { n.memberId = null; n.memberName = null; }
    else if (memberId != null) { n.memberId = memberId; n.memberName = memberName; }
    if (repeat != null) n.repeat = repeat;
    if (clearReminder) {
      n.reminderTime = null;
      n.repeat = 'none';
      await NotificationService.cancelGeneralNoteReminder(noteId);
    } else if (reminderTime != null) {
      n.reminderTime = reminderTime;
      await NotificationService.cancelGeneralNoteReminder(noteId);
      if (n.repeat != 'none' || reminderTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleGeneralNoteReminder(
            noteId: n.id, content: n.content, when: reminderTime, repeat: n.repeat);
      }
    } else if (repeat != null && n.reminderTime != null) {
      // اتغير التكرار بس — أعد الجدولة بنفس الميعاد
      await NotificationService.cancelGeneralNoteReminder(noteId);
      if (n.repeat != 'none' || n.reminderTime!.isAfter(DateTime.now())) {
        await NotificationService.scheduleGeneralNoteReminder(
            noteId: n.id, content: n.content, when: n.reminderTime!, repeat: n.repeat);
      }
    }
    save();
    notifyListeners();
  }

  /// الملاحظات النشطة (غير مؤرشفة وغير مكتملة) — عداد الفقاعة العائمة
  List<GeneralNote> get activeNotes =>
      db.generalNotes.where((n) => !n.archived && !n.isCompleted).toList();

  /// عدد التذكيرات اللي فات معادها — يلوّن العداد أحمر
  int get overdueNotesCount =>
      db.generalNotes.where((n) => n.isOverdue).length;

  /// فيه تذكير النهارده؟ — يشغّل نبض الفقاعة 📅
  bool get hasNoteDueToday => db.generalNotes.any((n) => n.isDueToday);

  // ─── EXTRA BUNDLES (Phase 3) ──────────────────────────────────
  /// شحن باقة إضافية مؤقتة لخط — تضاف للسعة هذا الشهر فقط
  /// والتكلفة تُخصم من صافي ربح المجموعة.
  void addExtraBundle(String gid, int gb, double cost) {
    final idx = db.groups.indexWhere((g) => g.id == gid);
    if (idx < 0) return;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    db.groups[idx].extraBundles.add({
      'month': month,
      'gb': gb,
      'cost': cost,
      'date': now.toIso8601String(),
    });
    save();
    notifyListeners();
  }

  // ─── CUSTOM PACKAGES ─────────────────────────────────────────
  void addCustomPackage(Map<String, dynamic> pkg) {
    // If same name already exists in custom, update it
    final idx = db.customPackages.indexWhere((p) => p['name'] == pkg['name']);
    if (idx >= 0) {
      db.customPackages[idx] = pkg;
    } else {
      db.customPackages.add(pkg);
    }
    save();
    notifyListeners();
  }

  void editCustomPackage(String oldName, int gb, double price) {
    final newName = '$gb جيجا';
    final newPkg = {'name': newName, 'gb': gb, 'price': price};
    final idx = db.customPackages.indexWhere((p) => p['name'] == oldName);
    if (idx >= 0) {
      db.customPackages[idx] = newPkg;
    } else {
      db.customPackages.add(newPkg);
    }
    save();
    notifyListeners();
  }

  void deleteCustomPackage(int index) {
    if (index < db.customPackages.length) {
      db.customPackages.removeAt(index);
      save();
      notifyListeners();
    }
  }

  void deleteCustomPackageByName(String name) {
    db.customPackages.removeWhere((p) => p['name'] == name);
    save();
    notifyListeners();
  }

  // Legacy - keep for backward compat
  void addGift(String gid, String memberId, String memberName) {
    final i = db.groups.indexWhere((g) => g.id == gid);
    if (i < 0) return;
    if (db.groups[i].gifts.length >= 2) return;
    db.groups[i].gifts.add({
      'memberId': memberId,
      'memberName': memberName,
      'date': _today(),
    });
    save();
    notifyListeners();
  }

  // ─── HELPERS ─────────────────────────────────────────────────
  String _today() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  String _monthName(int m) {
    const names = ['', 'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return names[m];
  }

  String newGroupId() => db.gid.toString();
  String newMemberId() => db.mid.toString();
}
