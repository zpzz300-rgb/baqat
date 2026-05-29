// lib/providers/app_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/telegram_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AppProvider extends ChangeNotifier {
  AppDB db = AppDB();
  bool _loading = true;
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
  String get ownerName      => _ownerName;
  String get ownerPhone     => _ownerPhone;
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

  String get telegramToken   => _telegramToken;
  String get telegramChatId  => _telegramChatId;
  bool   get telegramEnabled => _telegramEnabled;

  // ─── INIT ────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tcm_v3');
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
    _ownerName      = prefs.getString('tcm_owner_name')   ?? 'ابو عمر';
    _ownerPhone     = prefs.getString('tcm_owner_phone')  ?? '01001005891';
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
    _telegramToken      = prefs.getString('tcm_tg_token')  ?? '8832497646:AAHltc6_2pazsuocddFd1tqLXRs2RyEW7CI';
    _telegramChatId     = prefs.getString('tcm_tg_chatid') ?? '974113917';
    _telegramEnabled    = prefs.getBool('tcm_tg_enabled')  ?? false;
    _telegramOffset     = prefs.getInt('tcm_tg_offset')    ?? 0;
    _loading = false;
    _autoMonthlyBilling();
    _addMonthlyPoints();
    _autoGroupNotes();
    _autoGiftReset();
    if (_autoBackup) _checkAutoBackup();
    applyAllNotifications();
    notifyListeners();
  }

  @override
  void dispose() {
    _telegramTimer?.cancel();
    super.dispose();
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
    final json = db.toJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tcm_v3', jsonEncode(json));
    _saveToCloud(json); // fire & forget
    notifyListeners();
  }

  void _saveToCloud(Map<String, dynamic> json) {
    // Attach telegram config so the Edge Function can match this user
    final withConfig = Map<String, dynamic>.from(json);
    withConfig['_telegramConfig'] = {
      'token': _telegramToken,
      'chatId': _telegramChatId,
      'ownerName': _ownerName,
      'enabled': _telegramEnabled,
    };
    SupabaseService.saveUserData(withConfig);
  }

  // ─── LOAD FROM CLOUD (بعد Login) ─────────────────────────────
  Future<void> loadFromCloud() async {
    final cloudData = await SupabaseService.loadUserData();
    if (cloudData == null) {
      // مفيش بيانات على السيرفر — ارفع المحلي
      _saveToCloud(db.toJson());
      return;
    }
    try {
      final cloudDb = AppDB.fromJson(cloudData);
      // لو السيرفر عنده بيانات أكتر → استخدم السيرفر
      final localCount  = db.groups.length + db.members.length;
      final cloudCount  = cloudDb.groups.length + cloudDb.members.length;
      if (cloudCount >= localCount) {
        db = cloudDb;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tcm_v3', jsonEncode(cloudData));
      } else {
        // المحلي أحدث → ارفعه
        _saveToCloud(db.toJson());
      }
      notifyListeners();
    } catch (_) {}
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
    await prefs.setString('tcm_owner_name',    _ownerName);
    await prefs.setString('tcm_owner_phone',   _ownerPhone);
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
    save(); notifyListeners();
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
  }

  // ─── AUTO BACKUP ─────────────────────────────────────────────
  Future<String?> performBackup() async {
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

  void editGroup(Group g) {
    final i = db.groups.indexWhere((x) => x.id == g.id);
    if (i >= 0) db.groups[i] = g;
    _scheduleVoucherNotifications();
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
    db.groups.removeWhere((g) => g.id == gid);
    // archive members
    final mems = db.members.where((m) => m.gid == gid).toList();
    db.deleted.addAll(mems);
    db.members.removeWhere((m) => m.gid == gid);
    save();
  }

  // ─── MEMBERS ─────────────────────────────────────────────────
  void addMember(Member m) {
    db.members.add(m);
    db.mid++;
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
    _addLog(m, 'edit', 'تم تعديل بيانات ${m.name}');
    save();
  }

  void deleteMember(String mid) {
    final m = db.members.firstWhere((x) => x.id == mid);
    db.deleted.add(m);
    db.members.removeWhere((x) => x.id == mid);
    _addLog(m, 'delete', 'تم حذف العميل ${m.name}');
    save();
  }

  void restoreMember(String mid) {
    final m = db.deleted.firstWhere((x) => x.id == mid);
    db.members.add(m);
    db.deleted.removeWhere((x) => x.id == mid);
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
    save();
    notifyListeners();
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
    save();
    notifyListeners();
  }

  void moveMember(String mid, String newGid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
    db.members[i].gid = newGid;
    save();
    notifyListeners();
  }

  void clearMemberLog(String mid) {
    final i = db.members.indexWhere((x) => x.id == mid);
    if (i < 0) return;
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
        if (m.price > 0) {
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
        if (m.price > 0) {
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
        if (m.price > 0) {
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

  // ─── ACTIVITY LOG ────────────────────────────────────────────
  void _addLog(Member? m, String type, String desc) {
    db.activityLog.insert(0, {
      'date': _today(),
      'type': type,
      'desc': desc,
      'member': m?.name,
    });
    if (db.activityLog.length > 500) db.activityLog.removeLast();
  }

  void clearActivityLog() { db.activityLog.clear(); save(); }

  // ─── DELETE ALL ──────────────────────────────────────────────
  void deleteAllData() {
    db = AppDB();
    save();
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
  void addGuarantor(Guarantor g) { db.guarantors.add(g); save(); notifyListeners(); }
  void editGuarantor(Guarantor g) {
    final i = db.guarantors.indexWhere((x) => x.id == g.id);
    if (i >= 0) { db.guarantors[i] = g; save(); notifyListeners(); }
  }
  void deleteGuarantor(String id) {
    db.guarantors.removeWhere((g) => g.id == id);
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
  void addGroupBill(String gid, double amount, {String? note}) {
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
      date: _today(),
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

  /// سداد جزئي أو كلي على فاتورة محددة
  void payCompanyBill(String billId, double amount, {String? note}) {
    final bi = db.companyBills.indexWhere((b) => b.id == billId);
    if (bi < 0) return;
    final maxPay = db.companyBills[bi].remaining;
    final paid = amount > maxPay ? maxPay : amount;
    if (paid <= 0) return;
    db.companyBills[bi].payments.add(BillPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: paid,
      date: _today(),
      note: note,
    ));
    final gid = db.companyBills[bi].groupId;
    final gi = db.groups.indexWhere((g) => g.id == gid);
    if (gi >= 0) {
      db.groups[gi].billDebt = (db.groups[gi].billDebt - paid).clamp(0, double.infinity);
      db.groups[gi].groupNotes.insert(0, {
        'text': '💳 سداد ${paid.toStringAsFixed(0)} ج على فاتورة ${db.companyBills[bi].month} — متبقي: ${db.companyBills[bi].remaining.toStringAsFixed(0)} ج',
        'date': _today(),
        'type': 'bill',
      });
    }
    _addLog(null, 'bill_pay', 'سداد فاتورة: ${paid.toStringAsFixed(0)} ج');
    save(); notifyListeners();
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
    save(); notifyListeners();
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
  }) async {
    final note = GeneralNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      createdAt: DateTime.now(),
      reminderTime: reminderTime,
      isCompleted: false,
    );
    db.generalNotes.insert(0, note);
    save();
    notifyListeners();
    // جدولة التنبيه لو محدد وقت
    if (reminderTime != null && reminderTime.isAfter(DateTime.now())) {
      await NotificationService.scheduleGeneralNoteReminder(
        noteId: note.id,
        content: note.content,
        when: reminderTime,
      );
    }
  }

  /// تبديل حالة الملاحظة (مكتملة / غير مكتملة)
  void toggleGeneralNoteCompleted(String noteId) {
    final i = db.generalNotes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    db.generalNotes[i].isCompleted = !db.generalNotes[i].isCompleted;
    if (db.generalNotes[i].isCompleted) {
      // الغي التنبيه لو الملاحظة اتعملت
      NotificationService.cancelGeneralNoteReminder(noteId);
    }
    save();
    notifyListeners();
  }

  /// حذف ملاحظة عامة
  void deleteGeneralNote(String noteId) {
    db.generalNotes.removeWhere((n) => n.id == noteId);
    NotificationService.cancelGeneralNoteReminder(noteId);
    save();
    notifyListeners();
  }

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
