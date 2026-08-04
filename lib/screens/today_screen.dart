// lib/screens/today_screen.dart
// 📌 لوحة النهاردة — تفتح البرنامج تعرف تعمل إيه.
//
// بتعرض كل حاجة محتاجة حركة، مرتّبة: المتأخر الأول. كل بند دوسة عليه
// بتوديك للشاشة بتاعته. شاشة عرض بس — مابتعدّلش أي بيانات.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/today_tasks.dart';
import '../services/menu_catalog.dart';
import '../services/view_prefs.dart';
import '../widgets/app_search_bar.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  /// أقسام مقفولة (بيتفتكروا)
  final Set<String> _collapsed = {};
  bool _onlyOverdue = false;

  final _viewPrefs = ViewPrefs('today');

  @override
  void initState() {
    super.initState();
    _viewPrefs.load().then((m) {
      if (!mounted || m.isEmpty) return;
      setState(() {
        _onlyOverdue = m['onlyOverdue'] ?? false;
        _collapsed
          ..clear()
          ..addAll(List<String>.from(m['collapsed'] ?? const []));
      });
    });
  }

  void _save() => _viewPrefs.save({
        'onlyOverdue': _onlyOverdue,
        'collapsed': _collapsed.toList(),
      });

  void _set(VoidCallback change) {
    setState(change);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    var tasks = todayTasks(prov);
    final total = tasks.length;
    final overdue =
        tasks.where((t) => t.urgency == TaskUrgency.overdue).length;
    final soon = tasks.where((t) => t.urgency == TaskUrgency.soon).length;

    if (_onlyOverdue) {
      tasks = tasks.where((t) => t.urgency == TaskUrgency.overdue).toList();
    }

    // اتجمّع حسب القسم مع الحفاظ على ترتيب الأهمية
    final groups = <String, List<TodayTask>>{};
    for (final t in tasks) {
      groups.putIfAbsent(t.group, () => []).add(t);
    }

    return Column(children: [
      // ── الهيدر ──────────────────────────────────────────────
      Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.headerGradient),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('📌', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('لوحة النهاردة',
                  style: GoogleFonts.cairo(
                      color: AppColors.onAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ),
            Text(_greeting(),
                style: GoogleFonts.cairo(
                    color: AppColors.onAccent.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _headStat('🔴 متأخر', overdue,
                active: _onlyOverdue,
                onTap: () => _set(() => _onlyOverdue = !_onlyOverdue)),
            const SizedBox(width: 8),
            _headStat('⚠️ قرّب', soon),
            const SizedBox(width: 8),
            _headStat('📋 الكل', total,
                active: !_onlyOverdue,
                onTap: () => _set(() => _onlyOverdue = false)),
          ]),
        ]),
      ),

      // ── القايمة ─────────────────────────────────────────────
      Expanded(
        child: total == 0
            ? _allClear()
            : (tasks.isEmpty
                ? AppEmptyResult(
                    message: '🎉 مفيش حاجة متأخرة',
                    onClear: () => _set(() => _onlyOverdue = false),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      for (final e in groups.entries)
                        _section(prov, e.key, e.value),
                    ],
                  )),
      ),
    ]);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 18) return 'مساء الخير';
    return 'مساء الخير';
  }

  Widget _allClear() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✅', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 12),
          Text('مفيش حاجة مستعجلة النهاردة',
              style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.green2)),
          const SizedBox(height: 4),
          Text('كل الخطوط والفواتير والتذكيرات في وقتها',
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
        ]),
      );

  Widget _headStat(String label, int n,
      {bool active = false, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.onAccent.withValues(alpha: active ? 0.28 : 0.13),
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: AppColors.onAccent.withValues(alpha: 0.7))
                : null,
          ),
          child: Column(children: [
            Text('$n',
                style: GoogleFonts.cairo(
                    color: AppColors.onAccent,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: GoogleFonts.cairo(
                    color: AppColors.onAccent.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _section(AppProvider prov, String title, List<TodayTask> items) {
    final open = !_collapsed.contains(title);
    final worst = items.first.urgency;
    final color = _colorOf(worst);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => _set(() {
            if (!_collapsed.remove(title)) _collapsed.add(title);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: color.withValues(alpha: 0.09),
            child: Row(children: [
              Container(width: 4, height: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.cairo(
                        fontSize: 13, fontWeight: FontWeight.w900, color: color)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(9)),
                child: Text('${items.length}',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onAccent)),
              ),
              const SizedBox(width: 4),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  size: 20, color: color),
            ]),
          ),
        ),
        if (open)
          for (final t in items) _row(prov, t),
      ]),
    );
  }

  Widget _row(AppProvider prov, TodayTask t) {
    final color = _colorOf(t.urgency);
    return InkWell(
      onTap: () => _open(prov, t.screen),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Text(t.emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                  Text(t.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                ]),
          ),
          Icon(Icons.chevron_left, size: 18, color: AppColors.muted),
        ]),
      ),
    );
  }

  /// بيفتح الشاشة بتاعة البند في تاب.
  void _open(AppProvider prov, String key) {
    final d = menuItemDef(key);
    prov.openWorkspaceTab(key,
        title: d?.title ?? key, emoji: d?.emoji ?? '📄');
  }

  Color _colorOf(TaskUrgency u) => switch (u) {
        TaskUrgency.overdue => AppColors.red2,
        TaskUrgency.soon => AppColors.orange,
        TaskUrgency.info => AppColors.blue2,
      };
}
