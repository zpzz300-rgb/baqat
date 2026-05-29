// lib/services/telegram_service.dart
// خدمة تليجرام — إرسال واستقبال الرسائل والأوامر

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class TelegramService {
  static const _api = 'https://api.telegram.org/bot';

  // ── Core API ──────────────────────────────────────────────────────

  static Future<bool> sendMessage(
    String token,
    String chatId,
    String text, {
    String parseMode = 'HTML',
  }) async {
    if (token.isEmpty || chatId.isEmpty || text.isEmpty) return false;
    try {
      final uri = Uri.parse('$_api$token/sendMessage');
      final resp = await http
          .post(uri, body: {
            'chat_id': chatId,
            'text': text,
            'parse_mode': parseMode,
          })
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteWebhook(String token) async {
    if (token.isEmpty) return;
    try {
      await http
          .post(Uri.parse('$_api$token/deleteWebhook'), body: {'drop_pending_updates': 'false'})
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// Registers the bot's webhook to the shared Supabase Edge Function so it
  /// runs 24/7 on the server (even when the app is closed).
  static Future<({bool ok, String msg})> setWebhook(String token, String url) async {
    if (token.isEmpty) return (ok: false, msg: 'التوكن فارغ');
    if (url.isEmpty) return (ok: false, msg: 'رابط السيرفر فارغ');
    try {
      final resp = await http.post(
        Uri.parse('$_api$token/setWebhook'),
        body: {'url': url, 'drop_pending_updates': 'true'},
      ).timeout(const Duration(seconds: 12));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['ok'] == true) return (ok: true, msg: 'تم الربط بنجاح');
      return (ok: false, msg: (data['description'] ?? 'فشل الربط').toString());
    } catch (e) {
      return (ok: false, msg: 'تعذّر الاتصال بتليجرام');
    }
  }

  /// Verifies a bot token is valid by calling getMe.
  static Future<({bool ok, String name})> verifyToken(String token) async {
    if (token.isEmpty) return (ok: false, name: '');
    try {
      final resp = await http.get(Uri.parse('$_api$token/getMe')).timeout(const Duration(seconds: 10));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        return (ok: true, name: (data['result']?['username'] ?? '').toString());
      }
      return (ok: false, name: '');
    } catch (_) {
      return (ok: false, name: '');
    }
  }

  static Future<List<Map<String, dynamic>>> getUpdates(
    String token,
    int offset,
  ) async {
    if (token.isEmpty) return [];
    try {
      final uri = Uri.parse(
          '$_api$token/getUpdates?offset=$offset&limit=20&timeout=1');
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['ok'] != true) return [];
      return List<Map<String, dynamic>>.from(
          data['result'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  // ── Command Router ────────────────────────────────────────────────

  static String? route(String text, AppDB db, String ownerName) {
    final raw = text.trim();
    // accept commands with or without leading /
    final withSlash = raw.startsWith('/') ? raw : '/$raw';
    final cmd = withSlash.split(' ').first.replaceAll(RegExp(r'@\w+'), '').toLowerCase();
    switch (cmd) {
      case '/start':
      case '/help':
      case '/مساعدة':
        return welcome(ownerName);
      case '/تقرير':
      case '/report':
        return fullReport(db, ownerName);
      case '/ربح':
      case '/profit':
        return profitReport(db);
      case '/ديون':
      case '/debts':
        return debtsReport(db);
      case '/فواتير':
      case '/bills':
        return billsReport(db);
      case '/مجموعات':
      case '/groups':
        return groupsReport(db);
      case '/عملاء':
      case '/members':
        return membersReport(db);
      case '/تنبيهات':
      case '/alerts':
        return alertsReport(db);
      case '/انتهاء':
      case '/expiry':
        return expiryReport(db);
      case '/انتظار':
      case '/waitlist':
        return waitlistReport(db);
      case '/ضيوف':
      case '/guests':
        return guestsReport(db);
      case '/ايجارات':
      case '/rentals':
        return rentalsReport(db);
      case '/اليوم':
      case '/today':
        return todaySummary(db);
      case '/جرد':
      case '/inventory':
        return fullReport(db, ownerName);
      case '/تاجيل':
      case '/deferred':
        return debtsReport(db);
      case '/ارباح':
      case '/profits':
        return profitReport(db);
      default:
        return '❓ أمر غير معروف.\nأرسل /مساعدة لعرض الأوامر المتاحة.';
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // Message Builders
  // ══════════════════════════════════════════════════════════════════

  static String welcome(String ownerName) => '''
✈️ <b>بوت إدارة الاتصالات</b>
👤 <i>$ownerName</i>

📋 <b>الأوامر المتاحة:</b>

📊 <b>التقارير المالية:</b>
/تقرير — تقرير مالي شامل
/ربح — تفاصيل الأرباح حسب المجموعة
/اليوم — ملخص نشاط اليوم

💰 <b>المديونيات والفواتير:</b>
/ديون — قائمة المدينين (مرتبة من الأكبر)
/فواتير — فواتير الشركات غير المسددة
/ايجارات — الإيجارات النشطة

📱 <b>إحصائيات:</b>
/مجموعات — تقرير جميع المجموعات
/عملاء — إحصائيات العملاء التفصيلية
/ضيوف — العملاء الضيوف عند التجار

⚠️ <b>التنبيهات:</b>
/تنبيهات — فواتير شاذة + خطوط تنتهي + ديون مرتفعة
/انتهاء — خطوط تنتهي خلال 30 يوم

📋 <b>أخرى:</b>
/انتظار — قائمة الانتظار
/مساعدة — عرض هذه القائمة

⚡ <b>اختصارات:</b>
جرد — تقرير شامل
تاجيل — المدينين
ارباح — الأرباح
(تعمل بدون / أيضاً)
''';

  // ── Full financial report ────────────────────────────────────────
  static String fullReport(AppDB db, String ownerName) {
    final now = DateTime.now();
    final s = db.financialSummary;
    final giftP =
        db.groups.fold(0.0, (a, g) => a + g.giftProfit);
    final pointsP =
        db.groups.fold(0.0, (a, g) => a + g.pendingPointsProfit);
    final rentalI = db.rentals
        .where((r) => r.status == 'active')
        .fold(0.0, (a, r) => a + r.rent);
    final netProfit = s['netProfit'] ?? 0.0;
    final receivables = s['receivables'] ?? 0.0;

    return '''
📊 <b>التقرير المالي الشامل</b>
👤 <i>$ownerName</i>
📅 <i>${now.day}/${now.month}/${now.year}</i>
━━━━━━━━━━━━━━━━━━

👥 <b>الإحصائيات العامة:</b>
• المجموعات: <b>${db.groups.length}</b>
• العملاء: <b>${db.members.length}</b>
• المدينون: <b>${db.debtorCount}</b>
• قائمة الانتظار: <b>${db.waitlist.length}</b>

💵 <b>الإيرادات الشهرية:</b>
• من العملاء: <b>${db.totalMonthlyIncome.toStringAsFixed(0)} ج</b>
• إيجارات: <b>${rentalI.toStringAsFixed(0)} ج</b>
• هدايا: <b>${giftP.toStringAsFixed(0)} ج</b>
• نقاط: <b>${pointsP.toStringAsFixed(0)} ج</b>

📋 <b>فواتير الشركات:</b>
• مستحق: <b>${db.totalBillsOwed.toStringAsFixed(0)} ج</b>
• معلقة: <b>${db.companyBills.where((b) => !b.isPaid).length}</b>
• مسددة: <b>${db.companyBills.where((b) => b.isPaid).length}</b>

💸 <b>مديونية العملاء:</b>
<code>${receivables.toStringAsFixed(0)} ج</code>

📈 <b>صافي الربح:</b>
<code>${netProfit.toStringAsFixed(0)} ج</code>
''';
  }

  // ── Profit breakdown ─────────────────────────────────────────────
  static String profitReport(AppDB db) {
    final billing = db.totalBillingProfit;
    final gifts =
        db.groups.fold(0.0, (a, g) => a + g.giftProfit);
    final points =
        db.groups.fold(0.0, (a, g) => a + g.pendingPointsProfit);
    final rentals = db.rentals
        .where((r) => r.status == 'active')
        .fold(0.0, (a, r) => a + r.rent);
    final total = billing + gifts + points + rentals;

    final buf = StringBuffer(
        '💹 <b>تقرير الأرباح التفصيلي</b>\n━━━━━━━━━━━━━━━━━━\n\n');
    buf.writeln(
        '📱 ربح الفواتير: <b>${billing.toStringAsFixed(0)} ج</b>');
    buf.writeln(
        '🎁 ربح الهدايا:  <b>${gifts.toStringAsFixed(0)} ج</b>');
    buf.writeln(
        '🪙 ربح النقاط:   <b>${points.toStringAsFixed(0)} ج</b>');
    buf.writeln(
        '🏠 دخل الإيجارات:<b>${rentals.toStringAsFixed(0)} ج</b>');
    buf.writeln('━━━━━━━━━━━━━━');
    buf.writeln(
        '✅ <b>الإجمالي: <code>${total.toStringAsFixed(0)} ج</code></b>\n');
    buf.writeln('📋 <b>ربح كل مجموعة:</b>');

    for (final g in db.groups) {
      final p = db.groupProfit(g.id);
      if (p == 0) continue;
      buf.writeln(
          '${p > 0 ? "🟢" : "🔴"} ${g.phone}: <b>${p.toStringAsFixed(0)} ج</b>');
    }
    return buf.toString();
  }

  // ── Debts list ───────────────────────────────────────────────────
  static String debtsReport(AppDB db) {
    final debtors = db.members
        .where((m) => m.balance < 0)
        .toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));
    if (debtors.isEmpty) {
      return '✅ <b>لا توجد مديونيات حالياً 🎉</b>';
    }

    final buf = StringBuffer('💸 <b>قائمة المديونيات</b>\n');
    buf.writeln(
        'الإجمالي: <code>${db.totalDebt.toStringAsFixed(0)} ج</code> — ${debtors.length} مدين\n');

    for (final m in debtors.take(25)) {
      final debt = (-m.balance).toStringAsFixed(0);
      final flag = m.paymentFlag == 'red'
          ? '🔴'
          : m.paymentFlag == 'yellow'
              ? '🟡'
              : '⚪';
      buf.writeln('$flag <b>${m.name}</b> — <code>$debt ج</code>');
      buf.writeln('   📞 ${m.phone}');
    }
    if (debtors.length > 25) {
      buf.writeln('\n... و ${debtors.length - 25} آخرين');
    }
    return buf.toString();
  }

  // ── Company bills ────────────────────────────────────────────────
  static String billsReport(AppDB db) {
    final unpaid =
        db.companyBills.where((b) => !b.isPaid).toList();
    if (unpaid.isEmpty) {
      return '✅ <b>لا توجد فواتير معلقة 🎉</b>';
    }

    const emojis = {
      'etisalat': '🟢',
      'orange': '🟠',
      'vodafone': '🔴',
      'we': '🟣'
    };
    const names = {
      'etisalat': 'اتصالات',
      'orange': 'أورانج',
      'vodafone': 'فودافون',
      'we': 'WE'
    };

    final Map<String, List<Map>> byProv = {};
    for (final b in unpaid) {
      final g = db.groups.firstWhere((x) => x.id == b.groupId,
          orElse: () => Group(id: '', phone: '?'));
      byProv
          .putIfAbsent(g.provider ?? 'other', () => [])
          .add({'b': b, 'g': g});
    }

    final total = unpaid.fold(0.0, (s, b) => s + b.remaining);
    final buf = StringBuffer(
        '📋 <b>فواتير الشركات غير المسددة</b>\n');
    buf.writeln(
        'الإجمالي: <code>${total.toStringAsFixed(0)} ج</code>\n');

    for (final e in byProv.entries) {
      final provTotal = e.value.fold(
          0.0, (s, x) => s + (x['b'] as CompanyBill).remaining);
      buf.writeln(
          '${emojis[e.key] ?? "📡"} <b>${names[e.key] ?? e.key} — ${provTotal.toStringAsFixed(0)} ج</b>');
      for (final x in e.value) {
        final b = x['b'] as CompanyBill;
        final g = x['g'] as Group;
        buf.writeln(
            '  ${b.isPartial ? "🟡" : "🔴"} ${g.phone}: <code>${b.remaining.toStringAsFixed(0)} ج</code> (${b.month})');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  // ── Groups summary ───────────────────────────────────────────────
  static String groupsReport(AppDB db) {
    const emojis = {
      'etisalat': '🟢',
      'orange': '🟠',
      'vodafone': '🔴',
      'we': '🟣'
    };
    final buf = StringBuffer(
        '📡 <b>تقرير المجموعات</b>\n━━━━━━━━━━━━━━━━━━\n\n');
    for (final g in db.groups) {
      final members = db.membersOf(g.id);
      final debt = db.groupDebt(g.id);
      final profit = db.groupProfit(g.id);
      buf.writeln(
          '${emojis[g.provider] ?? "📡"} <b>${g.phone}</b>'
          '${g.ownerName != null ? " — ${g.ownerName}" : ""}');
      buf.writeln(
          '   👥 ${members.length} عميل | ربح: <b>${profit.toStringAsFixed(0)} ج</b>');
      if (debt > 0) {
        buf.writeln(
            '   💸 ديون عملاء: <code>${debt.toStringAsFixed(0)} ج</code>');
      }
    }
    return buf.toString();
  }

  // ── Members stats ────────────────────────────────────────────────
  static String membersReport(AppDB db) {
    final total = db.members.length;
    final debtors = db.members.where((m) => m.balance < 0).length;
    final clear = db.members
        .where((m) => m.balance >= 0 && m.price > 0)
        .length;
    final zero = db.members.where((m) => m.price == 0).length;
    final deferred =
        db.members.where((m) => m.deferralDate != null).length;
    return '''
👥 <b>تقرير العملاء</b>
━━━━━━━━━━━━━━━━━━

الإجمالي: <b>$total عميل</b>
✅ مسددون: <b>$clear</b>
🔴 عليهم ديون: <b>$debtors</b>
⚪ سعر صفر: <b>$zero</b>
⏳ مؤجلو الدفع: <b>$deferred</b>

💰 الدخل الشهري: <code>${db.totalMonthlyIncome.toStringAsFixed(0)} ج</code>
💸 إجمالي المديونية: <code>${db.totalDebt.toStringAsFixed(0)} ج</code>
''';
  }

  // ── Alerts ───────────────────────────────────────────────────────
  static String alertsReport(AppDB db) {
    final now = DateTime.now();
    final curM =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prevM = _prevMonth(curM);

    final buf = StringBuffer(
        '⚠️ <b>تنبيهات تحتاج مراجعة</b>\n━━━━━━━━━━━━━━━━━━\n\n');
    bool any = false;

    // Doubled bills
    for (final b
        in db.companyBills.where((b) => b.month == curM)) {
      final prev = db.companyBills
          .cast<CompanyBill?>()
          .firstWhere(
              (x) => x!.groupId == b.groupId && x.month == prevM,
              orElse: () => null);
      if (prev != null &&
          prev.actualAmount > 0 &&
          b.actualAmount >= prev.actualAmount * 1.75) {
        final g = db.groups.firstWhere((x) => x.id == b.groupId,
            orElse: () => Group(id: '', phone: '?'));
        buf.writeln('🔴 <b>فاتورة مضاعفة:</b> ${g.phone}');
        buf.writeln(
            '   الشهر الماضي: ${prev.actualAmount.toStringAsFixed(0)} ج → هذا الشهر: <b>${b.actualAmount.toStringAsFixed(0)} ج</b>\n');
        any = true;
      }
    }

    // Expiring ≤14 days
    for (final g in db.groups) {
      if (g.expiryDate == null) continue;
      final exp = DateTime.tryParse(g.expiryDate!);
      if (exp == null) continue;
      final days = exp.difference(now).inDays;
      if (days >= 0 && days <= 14) {
        buf.writeln('⏰ <b>خط ينتهي بعد $days يوم:</b> ${g.phone}');
        if (g.ownerName != null) buf.writeln('   👤 ${g.ownerName}');
        buf.writeln('   📅 ${g.expiryDate}\n');
        any = true;
      }
    }

    // High debt members (>500 by default)
    for (final m in db.members.where((m) => m.balance < -500)) {
      buf.writeln('💸 <b>دين مرتفع:</b> ${m.name} (${m.phone})');
      buf.writeln(
          '   المبلغ: <code>${(-m.balance).toStringAsFixed(0)} ج</code>\n');
      any = true;
    }

    if (!any) {
      return '✅ <b>لا توجد تنبيهات حالياً — كل شيء بخير 🎉</b>';
    }
    return buf.toString();
  }

  // ── Expiry report ────────────────────────────────────────────────
  static String expiryReport(AppDB db) {
    final now = DateTime.now();
    final list = db.groups
        .where((g) => g.expiryDate != null)
        .map((g) => {
              'g': g,
              'd': DateTime.tryParse(g.expiryDate!)
                  ?.difference(now)
                  .inDays
            })
        .where((e) =>
            e['d'] != null &&
            (e['d'] as int) >= -5 &&
            (e['d'] as int) <= 30)
        .toList()
      ..sort((a, b) => (a['d'] as int).compareTo(b['d'] as int));

    if (list.isEmpty) {
      return '✅ لا توجد خطوط تنتهي في الـ 30 يوم القادمة';
    }

    final buf = StringBuffer(
        '⏰ <b>خطوط تنتهي قريباً</b>\n━━━━━━━━━━━━━━━━━━\n\n');
    for (final e in list) {
      final g = e['g'] as Group;
      final days = e['d'] as int;
      final em = days < 0 ? '🔴' : days <= 7 ? '🟠' : '🟡';
      final txt = days < 0
          ? 'انتهت منذ ${-days} يوم'
          : 'بعد $days يوم';
      buf.writeln('$em <b>${g.phone}</b> — $txt');
      if (g.ownerName != null) buf.writeln('   👤 ${g.ownerName}');
    }
    return buf.toString();
  }

  // ── Waitlist ─────────────────────────────────────────────────────
  static String waitlistReport(AppDB db) {
    if (db.waitlist.isEmpty) {
      return '📋 قائمة الانتظار فارغة حالياً';
    }
    const statusEmoji = {
      'waiting': '⏳',
      'contacted': '📞',
      'assigned': '✅'
    };
    final buf = StringBuffer(
        '⏳ <b>قائمة الانتظار (${db.waitlist.length})</b>\n\n');
    for (final w in db.waitlist) {
      final e = statusEmoji[w.status] ?? '⏳';
      buf.writeln('$e <b>${w.name}</b> — ${w.phone}');
      if (w.packageType != 'any') {
        buf.writeln('   📦 ${w.packageType} MB');
      }
    }
    return buf.toString();
  }

  // ── Guests ───────────────────────────────────────────────────────
  static String guestsReport(AppDB db) {
    if (db.guestUsers.isEmpty) {
      return '🧳 لا يوجد عملاء ضيوف حالياً';
    }
    final totalProfit =
        db.guestUsers.fold(0.0, (s, g) => s + g.profit);
    final buf = StringBuffer(
        '🧳 <b>العملاء الضيوف (${db.guestUsers.length})</b>\n');
    buf.writeln(
        'ربح إجمالي: <code>${totalProfit.toStringAsFixed(0)} ج</code>\n');
    for (final g in db.guestUsers) {
      buf.writeln(
          '${g.isCollected ? "✅" : "⏳"} <b>${g.clientName}</b> (${g.clientPhone})');
      buf.writeln(
          '   💰 ${g.clientAmount.toStringAsFixed(0)} ج — تكلفة: ${g.dealerCost.toStringAsFixed(0)} ج — ربح: <b>${g.profit.toStringAsFixed(0)} ج</b>');
      if (g.dealerName != null) {
        buf.writeln('   🏪 عند: ${g.dealerName}');
      }
    }
    return buf.toString();
  }

  // ── Rentals ──────────────────────────────────────────────────────
  static String rentalsReport(AppDB db) {
    final active =
        db.rentals.where((r) => r.status == 'active').toList();
    if (active.isEmpty) {
      return '🏠 لا توجد إيجارات نشطة حالياً';
    }
    final total = active.fold(0.0, (s, r) => s + r.rent);
    final buf = StringBuffer(
        '🏠 <b>الإيجارات النشطة (${active.length})</b>\n');
    buf.writeln(
        'إجمالي شهري: <code>${total.toStringAsFixed(0)} ج</code>\n');
    for (final r in active) {
      buf.writeln(
          '🟢 <b>${r.name}</b> — ${r.rent.toStringAsFixed(0)} ج/شهر');
      if (r.balance != 0) {
        buf.writeln(
            '   ${r.balance > 0 ? "✅ رصيد" : "🔴 دين"}: ${r.balance.abs().toStringAsFixed(0)} ج');
      }
    }
    return buf.toString();
  }

  // ── Today summary ─────────────────────────────────────────────────
  static String todaySummary(AppDB db) {
    final now = DateTime.now();
    final todayStr = '${now.day}/${now.month}/${now.year}';
    final todayLogs = db.activityLog
        .where((a) => (a['date'] as String? ?? '') == todayStr)
        .take(15)
        .toList();

    final buf = StringBuffer(
        '📅 <b>ملخص اليوم — $todayStr</b>\n━━━━━━━━━━━━━━━━━━\n\n');
    if (todayLogs.isEmpty) {
      buf.writeln('لا يوجد نشاط مسجل اليوم\n');
    } else {
      for (final a in todayLogs) {
        buf.writeln('• ${a['desc'] ?? ''}');
      }
      buf.writeln();
    }
    buf.writeln(
        '💰 الدخل الشهري: <code>${db.totalMonthlyIncome.toStringAsFixed(0)} ج</code>');
    buf.writeln(
        '💸 المديونيات: <code>${db.totalDebt.toStringAsFixed(0)} ج</code>');
    buf.writeln(
        '📋 فواتير معلقة: <code>${db.companyBills.where((b) => !b.isPaid).length}</code>');
    return buf.toString();
  }

  // ── Helper ────────────────────────────────────────────────────────
  static String _prevMonth(String month) {
    final p = month.split('-');
    final d = DateTime(int.parse(p[0]), int.parse(p[1]) - 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }
}
