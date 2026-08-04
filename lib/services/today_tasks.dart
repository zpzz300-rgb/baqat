// lib/services/today_tasks.dart
// 📌 لوحة النهاردة — بتجمع كل حاجة محتاجة منك حركة النهاردة في مكان واحد.
//
// الفكرة: بدل ما تفتح ٦ شاشات عشان تعرف فيه إيه، البرنامج هو اللي
// يقولك. الملف ده بيقرا بس — **مابيغيّرش أي بيانات خالص**.

import '../models/models.dart';
import '../providers/app_provider.dart';

/// نوع المهمة — بيحدّد لونها وترتيب أهميتها.
enum TaskUrgency {
  /// 🔴 فات ميعاده — لازم دلوقتي
  overdue,

  /// ⚠️ قرّب — عندك كام يوم
  soon,

  /// 🔵 للعلم
  info,
}

/// بند واحد في اللوحة.
typedef TodayTask = ({
  String group,      // اسم المجموعة (📞 اتصالات الخطوط / 💰 فلوس …)
  String emoji,
  String title,
  String subtitle,
  TaskUrgency urgency,
  String screen,     // مفتاح الشاشة اللي بتفتحها الدوسة
  int? days,         // باقي/فات كام يوم (لو ينفع)
});

/// بتحسب كل مهام النهاردة مرتّبة: المتأخر الأول.
List<TodayTask> todayTasks(AppProvider prov) {
  final out = <TodayTask>[];
  final db = prov.db;

  // ── 📞 أرقام العمل: لازم مكالمة كل فترة وإلا الخط يتقفل ──────
  for (final w in db.workNums) {
    final left = prov.worknumDaysUntilDeactivation(w);
    if (left == null) continue;
    final overdue = left <= 0;
    if (!overdue && !prov.worknumNeedsReminder(w)) continue;
    out.add((
      group: '📞 اتصالات الخطوط',
      emoji: overdue ? '🔴' : '⚠️',
      title: w.phone,
      subtitle: overdue
          ? 'فات ميعاد الاتصال بـ ${-left} يوم — الخط ممكن يتقفل'
          : 'اتصل خلال $left يوم',
      urgency: overdue ? TaskUrgency.overdue : TaskUrgency.soon,
      screen: 'worknums',
      days: left,
    ));
  }

  // ── 🧾 فواتير الشركات اللي قرب ميعادها أو فات ──────────────
  for (final b in db.companyBills) {
    final left = prov.billGraceDaysLeft(b);
    if (left == null || left > 5) continue;
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: '؟'));
    out.add((
      group: '🧾 فواتير الشركات',
      emoji: left < 0 ? '🔴' : '⚠️',
      title: '${g.phone} — ${b.month}',
      subtitle: left < 0
          ? 'فات ميعاد السداد بـ ${-left} يوم'
          : (left == 0 ? 'آخر يوم للسداد النهاردة' : 'باقي $left يوم للسداد'),
      urgency: left < 0 ? TaskUrgency.overdue : TaskUrgency.soon,
      screen: 'invoices',
      days: left,
    ));
  }

  // ── 🔔 التذكيرات اللي فات ميعادها أو النهاردة ────────────────
  for (final n in db.generalNotes) {
    if (n.archived || n.isCompleted) continue;
    if (!n.isOverdue && !n.isDueToday) continue;
    final t = n.content;
    out.add((
      group: '🔔 التذكيرات',
      emoji: n.isOverdue ? '🔴' : '📅',
      title: t.length > 50 ? '${t.substring(0, 50)}…' : t,
      subtitle: n.isOverdue
          ? 'فات ميعاده${n.memberName != null ? ' — ${n.memberName}' : ''}'
          : 'موعده النهاردة${n.memberName != null ? ' — ${n.memberName}' : ''}',
      urgency: n.isOverdue ? TaskUrgency.overdue : TaskUrgency.soon,
      screen: 'notes',
      days: null,
    ));
  }

  // ── 💰 عملاء دينهم عدّى الحد اللي انت حاططه ─────────────────
  final limit = prov.debtThreshold;
  final heavy = db.members.where((m) => m.balance < -limit).toList()
    ..sort((a, b) => a.balance.compareTo(b.balance));
  for (final m in heavy.take(10)) {
    out.add((
      group: '💰 مديونيات كبيرة',
      emoji: '🔴',
      title: m.name.isEmpty ? m.phone : m.name,
      subtitle: 'عليه ${(-m.balance).toStringAsFixed(0)} ج '
          '(الحد ${limit.toStringAsFixed(0)})',
      urgency: TaskUrgency.overdue,
      screen: 'consolidated',
      days: null,
    ));
  }

  // ── 📢 شكاوى لسه مفتوحة ────────────────────────────────────
  for (final c in prov.allComplaints()) {
    if (c['_status'] != 'pending') continue;
    final title = (c['title'] ?? '').toString();
    final text = (c['text'] ?? '').toString();
    out.add((
      group: '📢 شكاوى مفتوحة',
      emoji: '📢',
      title: title.isNotEmpty ? title : text,
      subtitle: 'على الخط ${c['_groupPhone'] ?? ''}',
      urgency: TaskUrgency.info,
      screen: 'complaints',
      days: null,
    ));
  }

  // ── 🗓 عروض خطوط رئيسية قربت تخلص ──────────────────────────
  for (final l in db.mainLines) {
    final left = l.daysToEnd;
    if (left == null || left > 30) continue;
    out.add((
      group: '🗓 عروض قربت تخلص',
      emoji: left < 0 ? '🔴' : '⚠️',
      title: '${l.emoji} ${l.phone}',
      subtitle: left < 0
          ? 'العرض خلص من ${-left} يوم'
          : 'العرض بيخلص خلال $left يوم',
      urgency: left < 0 ? TaskUrgency.overdue : TaskUrgency.soon,
      screen: 'groups',
      days: left,
    ));
  }

  // الترتيب: المتأخر الأول، وجوه كل درجة الأقرب ميعاداً الأول
  const rank = {TaskUrgency.overdue: 0, TaskUrgency.soon: 1, TaskUrgency.info: 2};
  final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])];
  indexed.sort((a, b) {
    final c = rank[a.$2.urgency]!.compareTo(rank[b.$2.urgency]!);
    if (c != 0) return c;
    final d = (a.$2.days ?? 9999).compareTo(b.$2.days ?? 9999);
    return d != 0 ? d : a.$1.compareTo(b.$1); // sort في دارت مش stable
  });
  return [for (final e in indexed) e.$2];
}

/// عدد المهام المتأخرة بس — للرقم الأحمر على الزرار.
int todayOverdueCount(AppProvider prov) =>
    todayTasks(prov).where((t) => t.urgency == TaskUrgency.overdue).length;
