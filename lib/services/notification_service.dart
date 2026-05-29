// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/models.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // ── Channel IDs ────────────────────────────────────────────────
  static const _chDebt    = 'debt_reminders';
  static const _chVoucher = 'voucher_alerts';
  static const _chExpiry  = 'expiry_alerts';
  static const _chOffer   = 'offer_alerts';
  static const _chWeekly  = 'weekly_summary';
  static const _chMonthly = 'monthly_collection';
  static const _chInstant = 'instant';

  // ── Notification ID ranges ─────────────────────────────────────
  static const int _debtId      = 1001;
  static const int _weeklyId    = 1002;
  static const int _monthlyId   = 1003;
  static const int _voucherBase  = 2000; // ignore: unused_field
  static const int _expiryBase   = 3000; // 3000–3099
  static const int _offerBase    = 4000; // 4000–4099
  static const int _deferralBase = 5000; // 5000–5499

  static const _chDeferral = 'deferral_reminders';
  static const _chGeneralNote = 'general_notes_alerts';
  static const int _generalNoteBase = 6000; // 6000–6999

  // ── Shared helper ─────────────────────────────────────────────
  // Phase 4: Importance.max + Priority.high + exactAllowWhileIdle + vibration/sound
  static Future<void> _scheduleOnce({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required tz.TZDateTime when,
    DateTimeComponents? repeat,
    bool critical = true,
  }) async {
    await _plugin.cancel(id);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      ticker: title,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: critical
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeat,
      );
    } catch (_) {
      // لو إذن exact alarm مرفوض، نسقط على inexact (تنبيه قد يتأخر دقيقتين)
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          NotificationDetails(
            android: androidDetails,
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat,
        );
      } catch (_) {}
    }
  }

  /// طلب إذن exact alarm من المستخدم (Android 12+).
  /// يحاول طلب الإذن بأمان دون رمي exceptions.
  static Future<bool> requestPermissions() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      // POST_NOTIFICATIONS (Android 13+)
      try {
        await android.requestNotificationsPermission();
      } catch (_) {}
      // SCHEDULE_EXACT_ALARM (Android 12+)
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── 1. Daily debt reminder ─────────────────────────────────────
  static Future<void> scheduleDailyDebtReminder({
    required int hour, required int minute,
    required String title, required String body,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    await _scheduleOnce(
      id: _debtId, channelId: _chDebt, channelName: 'تذكيرات المديونيات',
      title: title, body: body, when: t,
      repeat: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDebtReminder() async {
    await init();
    await _plugin.cancel(_debtId);
  }

  // ── 2. Voucher / Bill date ─────────────────────────────────────
  static Future<void> scheduleVoucherAlert({
    required int id, required String title, required String body, required DateTime when,
  }) async {
    await init();
    final t = tz.TZDateTime.from(when, tz.local);
    await _scheduleOnce(id: id, channelId: _chVoucher, channelName: 'تنبيهات القسائم', title: title, body: body, when: t);
  }

  static Future<void> cancelVoucherAlert(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  // ── 3. Line expiry alerts ─────────────────────────────────────
  static Future<void> scheduleExpiryAlerts({
    required List<Group> groups, required int daysBefore,
  }) async {
    await init();
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(_expiryBase + i);
    }
    final now = DateTime.now();
    int count = 0;
    for (final g in groups) {
      if (g.expiryDate == null || count >= 100) continue;
      final d = _parseDate(g.expiryDate!);
      if (d == null) continue;
      final alertDate = d.subtract(Duration(days: daysBefore));
      if (alertDate.isBefore(now)) continue;
      final t = tz.TZDateTime.from(alertDate, tz.local);
      await _scheduleOnce(
        id: _expiryBase + count,
        channelId: _chExpiry, channelName: 'تنبيهات انتهاء الخطوط',
        title: '⚠️ انتهاء خط قريب!',
        body: 'خط ${g.phone} ينتهي في ${g.expiryDate} (بعد $daysBefore يوم)',
        when: t,
      );
      count++;
    }
  }

  // ── 4. Offer end alerts ────────────────────────────────────────
  static Future<void> scheduleOfferAlerts({
    required List<Group> groups, required int daysBefore,
  }) async {
    await init();
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(_offerBase + i);
    }
    final now = DateTime.now();
    int count = 0;
    for (final g in groups) {
      if (g.offerEndDate == null || count >= 100) continue;
      final d = _parseDate(g.offerEndDate!);
      if (d == null) continue;
      final alertDate = d.subtract(Duration(days: daysBefore));
      if (alertDate.isBefore(now)) continue;
      final t = tz.TZDateTime.from(alertDate, tz.local);
      await _scheduleOnce(
        id: _offerBase + count,
        channelId: _chOffer, channelName: 'تنبيهات انتهاء العروض',
        title: '🎁 انتهاء عرض قريب!',
        body: 'عرض خط ${g.phone} ينتهي في ${g.offerEndDate} (بعد $daysBefore يوم)',
        when: t,
      );
      count++;
    }
  }

  // ── 5. Weekly summary ─────────────────────────────────────────
  static Future<void> scheduleWeeklySummary({required AppDB db}) async {
    await init();
    final debtors = db.members.where((m) => m.balance < 0).length;
    final total = db.totalDebt;
    final now = tz.TZDateTime.now(tz.local);
    // Next Sunday at 9:00
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    final daysUntilSunday = (7 - t.weekday) % 7;
    t = t.add(Duration(days: daysUntilSunday == 0 ? 7 : daysUntilSunday));
    await _scheduleOnce(
      id: _weeklyId,
      channelId: _chWeekly, channelName: 'الملخص الأسبوعي',
      title: '📊 الملخص الأسبوعي',
      body: '$debtors عميل مدين — إجمالي: ${total.toStringAsFixed(0)} ج',
      when: t,
      repeat: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ── 6. Monthly collection reminder ────────────────────────────
  static Future<void> scheduleMonthlyCollection({required int dayOfMonth, required AppDB db}) async {
    await init();
    final income = db.totalMonthlyIncome;
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, dayOfMonth, 9, 0);
    if (t.isBefore(now)) {
      t = tz.TZDateTime(tz.local, now.year, now.month + 1, dayOfMonth, 9, 0);
    }
    await _scheduleOnce(
      id: _monthlyId,
      channelId: _chMonthly, channelName: 'تذكير التحصيل الشهري',
      title: '💰 موعد التحصيل الشهري',
      body: 'إجمالي الاشتراكات المتوقعة: ${income.toStringAsFixed(0)} ج — ابدأ التحصيل',
      when: t,
      repeat: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  // ── 7. Deferral reminders ─────────────────────────────────────
  static int _deferralId(String memberId) {
    return _deferralBase + (memberId.hashCode.abs() % 500);
  }

  static Future<void> scheduleDeferralReminder({
    required String memberId,
    required String memberName,
    required String deferralDate,
    String? note,
  }) async {
    await init();
    final d = _parseDate(deferralDate);
    if (d == null) return;
    final t = tz.TZDateTime.from(d, tz.local).add(const Duration(hours: 9)); // 9AM on deferral day
    await _scheduleOnce(
      id: _deferralId(memberId),
      channelId: _chDeferral,
      channelName: 'تذكيرات التأجيل',
      title: '⏰ موعد تأجيل الدفع — $memberName',
      body: note != null && note.isNotEmpty ? note : 'حل موعد التأجيل المتفق عليه مع $memberName',
      when: t,
    );
  }

  static Future<void> cancelDeferralReminder(String memberId) async {
    await init();
    await _plugin.cancel(_deferralId(memberId));
  }

  // ── 8. General Notes (Phase 5) ─────────────────────────────────
  static int _generalNoteIdOf(String noteId) =>
      _generalNoteBase + (noteId.hashCode.abs() % 1000);

  static Future<void> scheduleGeneralNoteReminder({
    required String noteId,
    required String content,
    required DateTime when,
  }) async {
    await init();
    final t = tz.TZDateTime.from(when, tz.local);
    await _scheduleOnce(
      id: _generalNoteIdOf(noteId),
      channelId: _chGeneralNote,
      channelName: 'تذكيرات الملاحظات العامة',
      title: '📝 ملاحظة شغل',
      body: content.length > 100 ? '${content.substring(0, 100)}…' : content,
      when: t,
    );
  }

  static Future<void> cancelGeneralNoteReminder(String noteId) async {
    await init();
    await _plugin.cancel(_generalNoteIdOf(noteId));
  }

  // ── Instant notification ──────────────────────────────────────
  static Future<void> showInstant({required String title, required String body}) async {
    await init();
    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _chInstant,
          'إشعارات فورية',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Cancel all scheduled ──────────────────────────────────────
  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  // ── Count pending notifications ───────────────────────────────
  static Future<List<PendingNotificationRequest>> listPending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  // ── Calculate next voucher date ───────────────────────────────
  static DateTime? nextVoucherDate(String? startDate, String period) {
    if (startDate == null || startDate.isEmpty) return null;
    final d = _parseDate(startDate);
    if (d == null) return null;
    final months = period == '1y' ? 12 : 6;
    DateTime candidate = d;
    final now = DateTime.now();
    while (!candidate.isAfter(now)) {
      final nm = candidate.month + months;
      candidate = DateTime(candidate.year + (nm - 1) ~/ 12, ((nm - 1) % 12) + 1, candidate.day);
    }
    return candidate;
  }

  // ── Helpers ───────────────────────────────────────────────────
  static DateTime? _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length < 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 1) : 1;
    if (year == null || month == null) return null;
    return DateTime(year, month, day);
  }
}
