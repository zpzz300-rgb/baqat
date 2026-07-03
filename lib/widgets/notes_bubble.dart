// lib/widgets/notes_bubble.dart
// 📝 فقاعة الملاحظات العائمة:
//  - قابلة للسحب لأي مكان (والمكان بيتحفظ) + التصاق بأقرب جنب
//  - عداد بعدد الملاحظات النشطة (أحمر لو فيه تذكير فات معاده)
//  - 📅 نبض للفقاعة لو فيه تذكير النهارده
//  - دوسة: قائمة منبثقة (تعديل ✏️ / إكمال ✅ / حذف 🗑 → أرشيف / 📌 تثبيت /
//    🎨 ألوان / 👤 ربط بعميل / 🔁 تكرار / 💬 مشاركة)
//  - دوسة مطوّلة: إضافة ملاحظة سريعة
//  - 🧹 المكتملة من أكتر من أسبوع بتتأرشف لوحدها (في AppProvider.init)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import 'member_card.dart';

/// ألوان الملاحظات: مفتاح → (خلفية، حدود، اسم)
const _noteColors = {
  'yellow': (Color(0xFFFFFDF5), Color(0xFFFFE082), '🟡 عادي'),
  'red':    (Color(0xFFFDECEA), Color(0xFFEF9A9A), '🔴 عاجل'),
  'green':  (Color(0xFFE8F5E9), Color(0xFFA5D6A7), '🟢 شغل'),
};

const _repeatLabels = {
  'none': 'مرة واحدة',
  'daily': '🔁 يومي',
  'weekly': '🔁 أسبوعي',
  'monthly': '🔁 شهري',
};

class NotesBubble extends StatefulWidget {
  const NotesBubble({super.key});
  @override
  State<NotesBubble> createState() => _NotesBubbleState();
}

class _NotesBubbleState extends State<NotesBubble>
    with SingleTickerProviderStateMixin {
  double _fx = 0.02, _fy = 0.62;
  bool _loaded = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        lowerBound: 0.92,
        upperBound: 1.08);
    _loadPos();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadPos() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _fx = p.getDouble('tcm_bubble_fx') ?? 0.02;
      _fy = p.getDouble('tcm_bubble_fy') ?? 0.62;
      _loaded = true;
    });
  }

  Future<void> _savePos() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('tcm_bubble_fx', _fx);
    await p.setDouble('tcm_bubble_fy', _fy);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final prov = context.watch<AppProvider>();
    final count = prov.activeNotes.length;
    final overdue = prov.overdueNotesCount;
    final dueToday = prov.hasNoteDueToday;
    final size = MediaQuery.of(context).size;
    const bubble = 54.0;

    // 📅 نبض لو فيه تذكير النهارده
    if (dueToday && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!dueToday && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1.0;
    }

    final left = (_fx * size.width).clamp(4.0, size.width - bubble - 18);
    final top = (_fy * size.height).clamp(60.0, size.height - bubble - 100);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          _fx = ((left + d.delta.dx) / size.width).clamp(0.0, 1.0);
          _fy = ((top + d.delta.dy) / size.height).clamp(0.0, 1.0);
        }),
        onPanEnd: (_) {
          setState(() => _fx = _fx < 0.5 ? 0.02 : 1.0);
          _savePos();
        },
        onTap: () => _openSheet(context),
        onLongPress: () => _quickAdd(context, prov),
        child: ScaleTransition(
          scale: _pulse,
          child: SizedBox(
            width: bubble + 14,
            height: bubble + 10,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: bubble,
                  height: bubble,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dueToday
                          ? [const Color(0xFFFF7043), const Color(0xFFE64A19)]
                          : [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Center(
                      child: Text('📝', style: TextStyle(fontSize: 24))),
                ),
                if (count > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: overdue > 0 ? AppColors.red : AppColors.blue2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text('$count',
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _quickAdd(BuildContext context, AppProvider prov) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('📝 ملاحظة سريعة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: GoogleFonts.cairo(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'اكتب الملاحظة...',
            hintStyle: GoogleFonts.cairo(color: AppColors.muted),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00)),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              prov.addGeneralNote(content: ctrl.text);
              Navigator.pop(dctx);
            },
            child: Text('حفظ',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotesSheet(),
    );
  }
}

// ── القائمة المنبثقة ─────────────────────────────────────────────
class _NotesSheet extends StatefulWidget {
  const _NotesSheet();
  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  final _addCtrl = TextEditingController();
  DateTime? _addReminder;
  String _addColor = 'yellow';
  String _addRepeat = 'none';
  String? _addMemberId;
  String? _addMemberName;
  bool _archiveOpen = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  String _fmtDT(DateTime d) =>
      '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<DateTime?> _pickDateTime(BuildContext ctx, {DateTime? initial}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !ctx.mounted) return null;
    final time = await showTimePicker(
      context: ctx,
      initialTime:
          TimeOfDay.fromDateTime(initial ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// 👤 اختيار عميل للربط — بحث سريع بالاسم/الرقم
  Future<(String, String)?> _pickMember(BuildContext ctx, AppProvider prov) {
    return showModalBottomSheet<(String, String)?>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberPicker(prov: prov),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // 📌 المثبتة الأول، وبعدين الباقي بترتيب الإضافة
    final active = prov.db.generalNotes.where((n) => !n.archived).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return 0; // ترتيب الإضافة محفوظ (insert 0)
      });
    final archivedList =
        prov.db.generalNotes.where((n) => n.archived).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text('📝 الملاحظات والتذكيرات',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: const Color(0xFFE65100))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${prov.activeNotes.length} نشطة',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE65100))),
            ),
          ]),
          const SizedBox(height: 10),

          // ── إضافة جديدة ──
          Row(children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                style: GoogleFonts.cairo(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'ملاحظة جديدة...',
                  hintStyle:
                      GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                if (_addCtrl.text.trim().isEmpty) return;
                prov.addGeneralNote(
                  content: _addCtrl.text,
                  reminderTime: _addReminder,
                  color: _addColor,
                  repeat: _addReminder != null ? _addRepeat : 'none',
                  memberId: _addMemberId,
                  memberName: _addMemberName,
                );
                _addCtrl.clear();
                setState(() {
                  _addReminder = null;
                  _addRepeat = 'none';
                  _addColor = 'yellow';
                  _addMemberId = null;
                  _addMemberName = null;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(0xFFFF8F00),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // ── خيارات الإضافة: ⏰ تذكير + 🔁 تكرار + 🎨 لون + 👤 عميل ──
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _optChip(
                _addReminder == null ? '⏰ تذكير' : '⏰ ${_fmtDT(_addReminder!)}',
                _addReminder != null,
                () async {
                  final dt =
                      await _pickDateTime(context, initial: _addReminder);
                  if (dt != null) setState(() => _addReminder = dt);
                },
                onClear: _addReminder != null
                    ? () => setState(() { _addReminder = null; _addRepeat = 'none'; })
                    : null,
              ),
              if (_addReminder != null)
                _optChip(_repeatLabels[_addRepeat]!, _addRepeat != 'none', () {
                  const order = ['none', 'daily', 'weekly', 'monthly'];
                  setState(() => _addRepeat = order[
                      (order.indexOf(_addRepeat) + 1) % order.length]);
                }),
              _optChip(_noteColors[_addColor]!.$3, _addColor != 'yellow', () {
                const order = ['yellow', 'red', 'green'];
                setState(() => _addColor =
                    order[(order.indexOf(_addColor) + 1) % order.length]);
              }),
              _optChip(
                _addMemberName == null ? '👤 عميل' : '👤 $_addMemberName',
                _addMemberName != null,
                () async {
                  final picked = await _pickMember(context, prov);
                  if (picked != null) {
                    setState(() {
                      _addMemberId = picked.$1;
                      _addMemberName = picked.$2;
                    });
                  }
                },
                onClear: _addMemberName != null
                    ? () => setState(() { _addMemberId = null; _addMemberName = null; })
                    : null,
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // ── القائمة ──
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('لا توجد ملاحظات — اكتب فوق وأضِف ✍️',
                            style: GoogleFonts.cairo(
                                color: AppColors.muted, fontSize: 13))),
                  ),
                for (final n in active) _noteCard(prov, n),
                if (archivedList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _archiveOpen = !_archiveOpen),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Text('📦 الأرشيف (${archivedList.length})',
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.muted)),
                        const Spacer(),
                        Icon(
                            _archiveOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppColors.muted),
                      ]),
                    ),
                  ),
                  if (_archiveOpen)
                    for (final n in archivedList) _archivedCard(prov, n),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optChip(String label, bool active, VoidCallback onTap,
      {VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF3E0) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: active ? const Color(0xFFFFB300) : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 11.5, fontWeight: FontWeight.w700)),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child:
                    const Icon(Icons.close, size: 13, color: AppColors.muted),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── كارت ملاحظة نشطة ──
  Widget _noteCard(AppProvider prov, GeneralNote n) {
    final overdue = n.isOverdue;
    final scheme = _noteColors[n.color] ?? _noteColors['yellow']!;
    final bg = n.isCompleted
        ? const Color(0xFFF3F5F8)
        : (overdue ? const Color(0xFFFDECEA) : scheme.$1);
    final border = overdue
        ? AppColors.red
        : (n.isCompleted ? AppColors.border : scheme.$2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: n.pinned ? 1.6 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => prov.toggleGeneralNoteCompleted(n.id),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                  n.isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: n.isCompleted ? AppColors.green : AppColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (n.pinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('📌', style: TextStyle(fontSize: 12)),
                      ),
                    Expanded(
                      child: Text(n.content,
                          style: GoogleFonts.cairo(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              decoration: n.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: n.isCompleted
                                  ? AppColors.muted
                                  : AppColors.text)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Wrap(spacing: 8, runSpacing: 2, children: [
                    Text('🗓 ${n.createdAt.day}/${n.createdAt.month}',
                        style: GoogleFonts.cairo(
                            fontSize: 10.5, color: AppColors.muted)),
                    if (n.reminderTime != null)
                      Text(
                          overdue
                              ? '🔴 فات معاده ${_fmtDT(n.reminderTime!)}'
                              : '⏰ ${_fmtDT(n.reminderTime!)}'
                                  '${n.repeat != 'none' ? ' ${_repeatLabels[n.repeat]}' : ''}',
                          style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: overdue
                                  ? AppColors.red2
                                  : const Color(0xFFE65100))),
                    // 👤 شارة العميل المرتبط — دوسة تفتح ملفه
                    if (n.memberId != null)
                      GestureDetector(
                        onTap: () => _openMember(prov, n.memberId!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppColors.blueLight,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('👤 ${n.memberName ?? 'عميل'}',
                              style: GoogleFonts.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blue2)),
                        ),
                      ),
                  ]),
                ]),
          ),
          // 📌 تثبيت
          GestureDetector(
            onTap: () => prov.togglePinGeneralNote(n.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                  n.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                  color: n.pinned ? const Color(0xFFE65100) : AppColors.muted),
            ),
          ),
          // 💬 مشاركة
          GestureDetector(
            onTap: () => Share.share(n.content),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.share, size: 17, color: AppColors.waGreen),
            ),
          ),
          // ✏️ تعديل
          GestureDetector(
            onTap: () => _editNote(prov, n),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.edit, size: 18, color: AppColors.blue2),
            ),
          ),
          // 🗑 → أرشيف
          GestureDetector(
            onTap: () {
              prov.archiveGeneralNote(n.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('📦 اتنقلت للأرشيف',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                duration: const Duration(seconds: 2),
                action: SnackBarAction(
                    label: 'استرجاع',
                    onPressed: () => prov.restoreGeneralNote(n.id)),
              ));
            },
            child: const Icon(Icons.delete_outline,
                size: 19, color: AppColors.red),
          ),
        ]),
      ]),
    );
  }

  void _openMember(AppProvider prov, String memberId) {
    final mi = prov.db.members.indexWhere((m) => m.id == memberId);
    if (mi < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('العميل مش موجود (اتحذف؟)',
              style: GoogleFonts.cairo())));
      return;
    }
    final m = prov.db.members[mi];
    final g = prov.db.groups.cast<Group?>()
        .firstWhere((x) => x!.id == m.gid, orElse: () => null);
    if (g == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => MemberDrawer(member: m, group: g),
    );
  }

  // ── كارت ملاحظة مؤرشفة ──
  Widget _archivedCard(AppProvider prov, GeneralNote n) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.content,
                style:
                    GoogleFonts.cairo(fontSize: 12.5, color: AppColors.muted)),
            if (n.archivedAt != null)
              Text('📦 ${n.archivedAt!.day}/${n.archivedAt!.month}',
                  style:
                      GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
          ]),
        ),
        GestureDetector(
          onTap: () => prov.restoreGeneralNote(n.id),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.restore, size: 19, color: AppColors.green),
          ),
        ),
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (dctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('حذف نهائي',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
              content: Text('حذف الملاحظة نهائياً؟ مش هتقدر ترجّعها.',
                  style: GoogleFonts.cairo()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dctx),
                    child: Text('إلغاء', style: GoogleFonts.cairo())),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: () {
                    Navigator.pop(dctx);
                    prov.deleteGeneralNote(n.id);
                  },
                  child: Text('حذف',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          child:
              const Icon(Icons.delete_forever, size: 19, color: AppColors.red),
        ),
      ]),
    );
  }

  // ── تعديل ملاحظة (نص + تذكير + تكرار + لون + عميل) ──
  void _editNote(AppProvider prov, GeneralNote n) {
    final ctrl = TextEditingController(text: n.content);
    DateTime? reminder = n.reminderTime;
    String repeat = n.repeat;
    String color = n.color;
    String? memberId = n.memberId;
    String? memberName = n.memberName;
    bool cleared = false;
    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('✏️ تعديل الملاحظة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 10),
              // ⏰ التذكير
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final dt = await _pickDateTime(dctx, initial: reminder);
                      if (dt != null) {
                        setD(() { reminder = dt; cleared = false; });
                      }
                    },
                    child: Text(
                        (cleared || reminder == null)
                            ? '⏰ إضافة تذكير'
                            : '⏰ ${_fmtDT(reminder!)}',
                        style: GoogleFonts.cairo(fontSize: 12)),
                  ),
                ),
                if (reminder != null && !cleared)
                  IconButton(
                    tooltip: 'إلغاء التذكير',
                    onPressed: () => setD(() => cleared = true),
                    icon: const Icon(Icons.alarm_off, color: AppColors.red),
                  ),
              ]),
              // 🔁 التكرار
              if (reminder != null && !cleared)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(spacing: 6, children: [
                    for (final r in _repeatLabels.keys)
                      GestureDetector(
                        onTap: () => setD(() => repeat = r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: repeat == r
                                ? const Color(0xFFFFF3E0)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: repeat == r
                                    ? const Color(0xFFFFB300)
                                    : AppColors.border),
                          ),
                          child: Text(_repeatLabels[r]!,
                              style: GoogleFonts.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 8),
              // 🎨 اللون
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 6, children: [
                  for (final c in _noteColors.keys)
                    GestureDetector(
                      onTap: () => setD(() => color = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _noteColors[c]!.$1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: color == c
                                  ? _noteColors[c]!.$2
                                  : AppColors.border,
                              width: color == c ? 2 : 1),
                        ),
                        child: Text(_noteColors[c]!.$3,
                            style: GoogleFonts.cairo(
                                fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              // 👤 العميل المرتبط
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await _pickMember(dctx, prov);
                      if (picked != null) {
                        setD(() {
                          memberId = picked.$1;
                          memberName = picked.$2;
                        });
                      }
                    },
                    child: Text(
                        memberName == null ? '👤 ربط بعميل' : '👤 $memberName',
                        style: GoogleFonts.cairo(fontSize: 12)),
                  ),
                ),
                if (memberId != null)
                  IconButton(
                    tooltip: 'فك الربط',
                    onPressed: () =>
                        setD(() { memberId = null; memberName = null; }),
                    icon: const Icon(Icons.link_off, color: AppColors.red),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.blue2),
              onPressed: () {
                prov.editGeneralNote(n.id,
                    content: ctrl.text,
                    reminderTime: cleared ? null : reminder,
                    clearReminder: cleared,
                    repeat: cleared ? 'none' : repeat,
                    color: color,
                    memberId: memberId,
                    memberName: memberName,
                    clearMember: memberId == null && n.memberId != null);
                Navigator.pop(dctx);
              },
              child: Text('حفظ',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── منتقي العميل (بحث بالاسم/الرقم) ──────────────────────────────
class _MemberPicker extends StatefulWidget {
  final AppProvider prov;
  const _MemberPicker({required this.prov});
  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final gids = widget.prov.visibleGroups.map((g) => g.id).toSet();
    final members = widget.prov.db.members
        .where((m) => gids.contains(m.gid))
        .where((m) =>
            _q.isEmpty ||
            m.name.toLowerCase().contains(_q.toLowerCase()) ||
            m.phone.contains(_q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text('👤 اختار العميل',
            style:
                GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 10),
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v.trim()),
          style: GoogleFonts.cairo(fontSize: 13),
          decoration: InputDecoration(
            hintText: '🔍 بحث بالاسم أو الرقم...',
            hintStyle: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.muted),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: members.length > 50 ? 50 : members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = members[i];
              return ListTile(
                dense: true,
                title: Text(m.name,
                    style: GoogleFonts.cairo(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: Text(m.phone,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.muted)),
                trailing: m.balance < 0
                    ? Text('🔻 ${(-m.balance).toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.red2))
                    : null,
                onTap: () => Navigator.pop(context, (m.id, m.name)),
              );
            },
          ),
        ),
      ]),
    );
  }
}
