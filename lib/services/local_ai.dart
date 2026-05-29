// lib/services/local_ai.dart
// Built-in analytics engine — no external API needed
import '../models/models.dart';

class LocalAI {
  // ── Entry point ──────────────────────────────────────────────
  static String respond(String question, AppDB db) {
    final q = _norm(question);

    if (_has(q, ['مدين', 'ديون', 'دين', 'مديون', 'مديونين'])) return _debtors(db);
    if (_has(q, ['ربح', 'ارباح', 'دخل', 'ايراد', 'توقع', 'شهر قادم'])) return _profits(db);
    if (_has(q, ['واتس', 'رسالة', 'تذكير', 'تحصيل'])) return _collectionMsg(db);
    if (_has(q, ['ملخص', 'احصاء', 'احصائيات', 'نظرة', 'حلل', 'عامة'])) return _summary(db);
    if (_has(q, ['اقتراح', 'نصيحة', 'تحسين', 'توصية'])) return _suggestions(db);
    if (_has(q, ['مجموعة', 'خط', 'باقة', 'اكثر'])) return _groupStats(db);
    if (_has(q, ['ضيف', 'ضيوف', 'تاجر'])) return _guests(db);
    if (_has(q, ['نقطة', 'نقاط', 'مكافأة'])) return _points(db);

    return _summary(db); // default to general summary
  }

  static String _norm(String s) => s
      .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه').replaceAll('ى', 'ي').toLowerCase();

  static bool _has(String q, List<String> keys) => keys.any((k) => q.contains(k));

  // ── General Summary ──────────────────────────────────────────
  static String _summary(AppDB db) {
    final totalDebt    = db.totalDebt;
    final totalProfit  = db.totalProfit;
    final debtors      = db.members.where((m) => m.balance < 0).length;
    final fin          = db.financialSummary;

    return '''📊 **ملخص شامل لبياناتك**

👥 **العملاء والمجموعات**
• إجمالي المجموعات: ${db.groups.length}
• إجمالي العملاء: ${db.members.length}
• العملاء المدينون: $debtors من أصل ${db.members.length}

💰 **الوضع المالي**
• إجمالي المديونية: ${totalDebt.toStringAsFixed(0)} ج
• إجمالي الرصيد الإيجابي: ${totalProfit.toStringAsFixed(0)} ج
• ليا كام (تحصيل): ${fin['receivables']!.toStringAsFixed(0)} ج
• عليا كام (مستحق للتجار): ${fin['payables']!.toStringAsFixed(0)} ج
• صافي الربح المحسوب: ${fin['netProfit']!.toStringAsFixed(0)} ج

🏠 **الإيجارات**
• إجمالي الإيجارات: ${db.rentals.length}
• الإيجارات النشطة: ${db.rentals.where((r) => r.status == 'active').length}

👥 **الضيوف**
• إجمالي الضيوف: ${db.guestUsers.length}
• غير محصل منهم: ${db.guestUsers.where((g) => !g.isCollected).length}
• غير مدفوع للتجار: ${db.guestUsers.where((g) => !g.isPaid).length}''';
  }

  // ── Top Debtors ──────────────────────────────────────────────
  static String _debtors(AppDB db) {
    final debtors = db.members
        .where((m) => m.balance < 0)
        .toList()
      ..sort((a, b) => a.balance.compareTo(b.balance)); // most negative first

    if (debtors.isEmpty) return '✅ لا يوجد عملاء مدينون حالياً! عمل رائع 🎉';

    final top = debtors.take(10).toList();
    final total = debtors.fold<double>(0, (s, m) => s - m.balance);

    final list = top.asMap().entries.map((e) {
      final rank = e.key + 1;
      final m = e.value;
      final debt = (-m.balance).toStringAsFixed(0);
      final g = db.groups.firstWhere((g) => g.id == m.gid, orElse: () => db.groups.first);
      return '$rank. ${m.name} — $debt ج  📞 ${m.phone}  (${g.phone})';
    }).join('\n');

    return '''💸 **أكبر ${top.length} مدينين**

$list

📌 **الإجمالي:** ${total.toStringAsFixed(0)} ج من ${debtors.length} عميل
💡 **نصيحة:** ابدأ بالتواصل مع أعلى المديونين أولاً.''';
  }

  // ── Profit Analysis ──────────────────────────────────────────
  static String _profits(AppDB db) {
    final monthly   = db.members.fold<double>(0, (s, m) => s + m.price);
    final rental    = db.rentals.where((r) => r.status == 'active').fold<double>(0, (s, r) => s + r.rent);
    final gifts     = db.groups.fold<double>(0, (s, g) => s + g.giftProfit);
    final guests    = db.guestUsers.fold<double>(0, (s, g) => s + g.profit);
    final total     = monthly + rental + gifts + guests;

    return '''📈 **تحليل الإيرادات**

💳 **الاشتراكات الشهرية:** ${monthly.toStringAsFixed(0)} ج
   (${db.members.length} عميل × متوسط ${db.members.isEmpty ? 0 : (monthly / db.members.length).toStringAsFixed(0)} ج)

🏠 **إيجارات نشطة:** ${rental.toStringAsFixed(0)} ج
   (${db.rentals.where((r) => r.status == 'active').length} إيجار نشط)

🎁 **أرباح الهدايا والنقاط:** ${gifts.toStringAsFixed(0)} ج

👥 **أرباح الضيوف:** ${guests.toStringAsFixed(0)} ج

━━━━━━━━━━━━━━━━━━━
💰 **الإجمالي التقديري:** ${total.toStringAsFixed(0)} ج/شهر

💡 متوسط الإيراد لكل مجموعة: ${db.groups.isEmpty ? 0 : (total / db.groups.length).toStringAsFixed(0)} ج''';
  }

  // ── Collection Message ───────────────────────────────────────
  static String _collectionMsg(AppDB db) {
    final debtors = db.members.where((m) => m.balance < 0).take(3).toList();
    if (debtors.isEmpty) return '✅ لا يوجد مديونون — لا داعي لرسائل التحصيل الآن!';

    final examples = debtors.map((m) {
      return '📱 ${m.name}: ${(-m.balance).toStringAsFixed(0)} ج';
    }).join('\n');

    return '''💬 **نموذج رسالة واتساب للتحصيل**

السلام عليكم ورحمة الله وبركاته،
نرجو التكرم بسداد المبلغ المستحق عليك في أقرب وقت ممكن.
جزاكم الله خيراً 🙏

━━━━━━━━━━━━━━━━━━━
**أعلى 3 مدينين حالياً:**
$examples

💡 **تلميح:** في شاشة التنبيهات يمكنك إرسال الرسائل مباشرة لكل عميل بضغطة واحدة.''';
  }

  // ── Suggestions ──────────────────────────────────────────────
  static String _suggestions(AppDB db) {
    final tips = <String>[];

    // High debt clients
    final highDebt = db.members.where((m) => m.balance < -500).length;
    if (highDebt > 0) tips.add('💸 لديك $highDebt عميل بمديونية تجاوزت 500 ج — تواصل معهم بأسرع وقت');

    // Expiring lines
    final expiring = db.groups.where((g) {
      if (g.expiryDate == null) return false;
      final d = DateTime.tryParse(g.expiryDate!);
      if (d == null) return false;
      return d.difference(DateTime.now()).inDays <= 90;
    }).length;
    if (expiring > 0) tips.add('⚠️ $expiring خط ينتهي خلال 90 يوم — جدد قبل انتهاء العرض');

    // Uncollected guests
    final uncollected = db.guestUsers.where((g) => !g.isCollected).length;
    if (uncollected > 0) tips.add('👥 لديك $uncollected ضيف لم تحصّل منه بعد');

    // Unpaid dealers
    final unpaid = db.guestUsers.where((g) => !g.isPaid).length;
    if (unpaid > 0) tips.add('🏪 لديك $unpaid ضيف لم تدفع للتاجر عنه بعد');

    // Points
    final withPoints = db.groups.where((g) => g.rewardPoints > 0).toList();
    if (withPoints.isNotEmpty) {
      final totalPts = withPoints.fold<int>(0, (s, g) => s + g.rewardPoints);
      tips.add('🏆 لديك $totalPts نقطة مكافآت يمكن استردادها — استرد لزيادة الأرباح');
    }

    // Low GB groups
    final lowGb = db.groups.where((g) {
      final total = db.groupTotalGb(g.id);
      final used  = db.groupUsedGb(g.id);
      return total > 0 && used / total > 0.85;
    }).length;
    if (lowGb > 0) tips.add('📶 $lowGb مجموعة استهلكت أكثر من 85% من إنترنتها — راجع توزيع الجيجا');

    if (tips.isEmpty) return '✅ **ممتاز!** لا توجد مشكلات ملحوظة في بياناتك حالياً. استمر!';

    return '''💡 **اقتراحات لتحسين عملك**\n\n${tips.map((t) => '• $t').join('\n\n')}''';
  }

  // ── Group Stats ───────────────────────────────────────────────
  static String _groupStats(AppDB db) {
    if (db.groups.isEmpty) return 'لا توجد مجموعات بعد.';

    final grouped = db.groups.map((g) {
      final members = db.membersOf(g.id);
      final debt    = db.groupDebt(g.id);
      return (g: g, count: members.length, debt: debt);
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final top = grouped.take(5);
    final lines = top.map((x) =>
        '• ${x.g.phone} — ${x.count} عميل${x.debt > 0 ? ' — مديونية: ${x.debt.toStringAsFixed(0)} ج' : ' ✅'}'
    ).join('\n');

    return '''📡 **إحصائيات المجموعات**

**أكبر 5 مجموعات بعدد العملاء:**
$lines

**إجمالي:**
• ${db.groups.length} مجموعة
• ${db.members.length} عميل
• متوسط ${db.groups.isEmpty ? 0 : (db.members.length / db.groups.length).toStringAsFixed(1)} عميل/مجموعة''';
  }

  // ── Guests ────────────────────────────────────────────────────
  static String _guests(AppDB db) {
    final guests = db.guestUsers;
    if (guests.isEmpty) return 'لا يوجد ضيوف حالياً.';

    final totalIn     = guests.fold<double>(0, (s, g) => s + g.clientAmount);
    final totalOut    = guests.fold<double>(0, (s, g) => s + g.dealerCost);
    final totalProfit = guests.fold<double>(0, (s, g) => s + g.profit);

    return '''👥 **ملخص الضيوف**

• إجمالي الضيوف: ${guests.length}
• إجمالي من العملاء: ${totalIn.toStringAsFixed(0)} ج
• إجمالي للتجار: ${totalOut.toStringAsFixed(0)} ج
• صافي الربح: ${totalProfit.toStringAsFixed(0)} ج

• غير محصل بعد: ${guests.where((g) => !g.isCollected).length}
• غير مدفوع للتاجر: ${guests.where((g) => !g.isPaid).length}''';
  }

  // ── Points ────────────────────────────────────────────────────
  static String _points(AppDB db) {
    final withPts = db.groups.where((g) => g.rewardPoints > 0).toList();
    if (withPts.isEmpty) return 'لا توجد نقاط مكافآت مسجلة حالياً.';

    final total = withPts.fold<int>(0, (s, g) => s + g.rewardPoints);
    final value = withPts.fold<double>(0, (s, g) => s + g.rewardPoints * g.pointsValue);
    final list  = withPts.take(5).map((g) =>
        '• ${g.phone} — ${g.rewardPoints} نقطة = ${(g.rewardPoints * g.pointsValue).toStringAsFixed(0)} ج'
    ).join('\n');

    return '''🏆 **ملخص نقاط المكافآت**

$list

━━━━━━━━━━━━━━━━━━━
• الإجمالي: $total نقطة
• القيمة الكلية: ${value.toStringAsFixed(0)} ج

💡 استرد النقاط من كارت المجموعة لإضافتها للأرباح''';
  }
}
