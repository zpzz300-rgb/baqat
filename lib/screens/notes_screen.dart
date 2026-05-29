// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/app_theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _typeFilter = 'all'; // all | manual | auto | bill | sticky
  String _groupFilter = 'all';
  final _searchCtrl = TextEditingController();
  String _searchQ = '';

  static const _typeFilters = [
    {'key': 'all', 'label': 'الكل', 'emoji': '📋'},
    {'key': 'general', 'label': 'شغل عام', 'emoji': '💼'},
    {'key': 'manual', 'label': 'يدوية', 'emoji': '✍️'},
    {'key': 'auto', 'label': 'تلقائية', 'emoji': '🔄'},
    {'key': 'bill', 'label': 'فواتير', 'emoji': '💳'},
    {'key': 'sticky', 'label': 'ملاحظة ثابتة', 'emoji': '📌'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // جمع كل الملاحظات من كل المجموعات مع معلومات المجموعة + الملاحظات العامة
  List<Map<String, dynamic>> _allNotes(AppDB db) {
    final result = <Map<String, dynamic>>[];

    // Phase 5: General notes (مستقلة عن الخطوط)
    for (final gn in db.generalNotes) {
      result.add({
        'groupId': null,
        'groupPhone': '— شغل عام',
        'ownerName': null,
        'type': 'general',
        'text': gn.content,
        'date': gn.createdAt.toIso8601String().split('T').first,
        'index': -1,
        'noteId': gn.id,
        'isCompleted': gn.isCompleted,
        'reminderTime': gn.reminderTime?.toIso8601String(),
      });
    }

    for (final g in db.groups) {
      // Sticky notes
      if (g.stickyNote != null && g.stickyNote!.isNotEmpty) {
        result.add({
          'groupId': g.id,
          'groupPhone': g.phone,
          'ownerName': g.ownerName,
          'type': 'sticky',
          'text': g.stickyNote!,
          'date': '',
          'index': -1,
        });
      }
      // Group notes
      for (var i = 0; i < g.groupNotes.length; i++) {
        final n = g.groupNotes[i];
        result.add({
          'groupId': g.id,
          'groupPhone': g.phone,
          'ownerName': g.ownerName,
          'type': n['type'] ?? 'manual',
          'text': n['text'] ?? '',
          'date': n['date'] ?? '',
          'index': i,
        });
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _filtered(AppDB db) {
    return _allNotes(db).where((n) {
      if (_typeFilter != 'all' && n['type'] != _typeFilter) return false;
      if (_groupFilter != 'all' && n['groupId'] != _groupFilter) return false;
      if (_searchQ.isNotEmpty) {
        final q = _searchQ.toLowerCase();
        if (!(n['text'] as String).toLowerCase().contains(q) &&
            !(n['groupPhone'] as String).contains(q) &&
            !(n['ownerName'] ?? '').toString().toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;
    final notes = _filtered(db);

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────
      Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(children: [
          Row(children: [
            const Text('📝', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('ملاحظات المجموعات',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showAddNoteDialog(context, prov, db),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('للخط',
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            // Phase 5: زرار الملاحظة العامة بلون مميز (بنفسجي/إندجو)
            GestureDetector(
              onTap: () => _showAddGeneralNoteDialog(context, prov),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF3F51B5)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.work_outline, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('شغل عام',
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _summaryChip(
                'إجمالي', _allNotes(db).length.toString(), Colors.white24),
            const SizedBox(width: 8),
            _summaryChip(
                'يدوية',
                _allNotes(db)
                    .where((n) => n['type'] == 'manual')
                    .length
                    .toString(),
                const Color(0xFF42A5F5)),
            const SizedBox(width: 8),
            _summaryChip(
                'ثابتة',
                db.groups
                    .where(
                        (g) => g.stickyNote != null && g.stickyNote!.isNotEmpty)
                    .length
                    .toString(),
                const Color(0xFFFFA726)),
          ]),
        ]),
      ),
      // ── Search ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          textDirection: TextDirection.rtl,
          onChanged: (v) => setState(() => _searchQ = v.trim()),
          decoration: InputDecoration(
            hintText: '🔍 بحث في الملاحظات...',
            hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:
                    const BorderSide(color: AppColors.blue, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            suffixIcon: _searchQ.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQ = '');
                    })
                : null,
          ),
        ),
      ),
      // ── Type filter chips ────────────────────────────────────────
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          children: _typeFilters.map((f) {
            final active = _typeFilter == f['key'];
            return GestureDetector(
              onTap: () => setState(() => _typeFilter = f['key'] as String),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.headerGradient : null,
                  color: active ? null : const Color(0xFFf0f4f8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${f['emoji']} ${f['label']}',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.text)),
              ),
            );
          }).toList(),
        ),
      ),
      // ── Group filter dropdown ────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Text('المجموعة: ',
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
          Expanded(
            child: DropdownButton<String>(
              value: _groupFilter,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.text),
              items: [
                DropdownMenuItem(
                    value: 'all',
                    child:
                        Text('الكل', style: GoogleFonts.cairo(fontSize: 12))),
                ...db.groups.map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(
                        '${g.phone}${g.ownerName != null ? " — ${g.ownerName}" : ""}',
                        style: GoogleFonts.cairo(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _groupFilter = v ?? 'all'),
            ),
          ),
        ]),
      ),
      // ── Notes List ──────────────────────────────────────────────
      Expanded(
        child: notes.isEmpty
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📝', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('لا توجد ملاحظات',
                          style: GoogleFonts.cairo(
                              color: AppColors.muted, fontSize: 14)),
                    ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: notes.length,
                itemBuilder: (_, i) {
                  final n = notes[i];
                  final isGeneral = n['type'] == 'general';
                  return _NoteItem(
                    note: n,
                    prov: prov,
                    onDelete: isGeneral
                        ? () => prov.deleteGeneralNote(n['noteId'] as String)
                        : (n['index'] >= 0 && n['type'] != 'sticky'
                            ? () => prov.deleteGroupNote(
                                n['groupId'] as String, n['index'] as int)
                            : null),
                    onDeleteSticky: n['type'] == 'sticky'
                        ? () => prov.updateGroupStickyNote(
                            n['groupId'] as String, null)
                        : null,
                    onToggleCompleted: isGeneral
                        ? () => prov
                            .toggleGeneralNoteCompleted(n['noteId'] as String)
                        : null,
                  );
                },
              ),
      ),
    ]);
  }

  Widget _summaryChip(String label, String val, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(val,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10)),
        ]),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, AppProvider prov, AppDB db) {
    String? selectedGid;
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('📝 إضافة ملاحظة',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'اختر المجموعة',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              isExpanded: true,
              initialValue: selectedGid,
              items: db.groups
                  .map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(
                          '${g.phone}${g.ownerName != null ? " — ${g.ownerName}" : ""}',
                          style: GoogleFonts.cairo(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setS(() => selectedGid = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'نص الملاحظة',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                if (selectedGid == null) return;
                if (textCtrl.text.trim().isEmpty) return;
                prov.addGroupNote(selectedGid!, textCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: Text('إضافة',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Phase 5: إضافة ملاحظة عامة للشغل (مستقلة عن أي خط)
  void _showAddGeneralNoteDialog(BuildContext context, AppProvider prov) {
    final textCtrl = TextEditingController();
    bool reminderEnabled = false;
    DateTime? reminderTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF3F51B5)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.work_outline,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('+ ملاحظة عامة للشغل',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 14)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: textCtrl,
              textDirection: TextDirection.rtl,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'نص الملاحظة',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                hintText: 'مثال: شوف الفواتير مع مين...',
                hintStyle: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.muted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            // Reminder toggle
            GestureDetector(
              onTap: () => setS(() => reminderEnabled = !reminderEnabled),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: reminderEnabled
                      ? const Color(0xFFF3E5F5)
                      : const Color(0xFFf5f5f5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: reminderEnabled
                          ? AppColors.purple
                          : AppColors.border),
                ),
                child: Row(children: [
                  Icon(
                      reminderEnabled
                          ? Icons.alarm_on
                          : Icons.alarm_off,
                      color: reminderEnabled
                          ? AppColors.purple
                          : AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('تفعيل تنبيه تذكيري',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: reminderEnabled
                                ? AppColors.purple
                                : AppColors.muted)),
                  ),
                  Icon(
                      reminderEnabled
                          ? Icons.toggle_on
                          : Icons.toggle_off,
                      color: reminderEnabled
                          ? AppColors.purple
                          : AppColors.muted,
                      size: 26),
                ]),
              ),
            ),
            if (reminderEnabled) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx2,
                    initialDate: DateTime.now().add(const Duration(hours: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date == null) return;
                  if (!ctx2.mounted) return;
                  final time = await showTimePicker(
                    context: ctx2,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time == null) return;
                  setS(() => reminderTime = DateTime(date.year, date.month,
                      date.day, time.hour, time.minute));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.purple),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: AppColors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminderTime != null
                            ? '${reminderTime!.year}/${reminderTime!.month.toString().padLeft(2, '0')}/${reminderTime!.day.toString().padLeft(2, '0')} — ${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}'
                            : 'اختر التاريخ والوقت',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: reminderTime != null
                                ? AppColors.text
                                : AppColors.muted),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (textCtrl.text.trim().isEmpty) return;
                if (reminderEnabled && reminderTime == null) return;
                await prov.addGeneralNote(
                  content: textCtrl.text.trim(),
                  reminderTime: reminderEnabled ? reminderTime : null,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: Text('حفظ',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Note Item ─────────────────────────────────────────────────────────────────
class _NoteItem extends StatelessWidget {
  final Map<String, dynamic> note;
  final AppProvider prov;
  final VoidCallback? onDelete;
  final VoidCallback? onDeleteSticky;
  final VoidCallback? onToggleCompleted;

  const _NoteItem({
    required this.note,
    required this.prov,
    this.onDelete,
    this.onDeleteSticky,
    this.onToggleCompleted,
  });

  Color get _typeColor {
    switch (note['type'] as String) {
      case 'sticky':
        return const Color(0xFFe65100);
      case 'auto':
        return AppColors.blue;
      case 'bill':
        return AppColors.green2;
      case 'general':
        return AppColors.purple;
      default:
        return AppColors.muted;
    }
  }

  Color get _typeBg {
    switch (note['type'] as String) {
      case 'sticky':
        return const Color(0xFFFFF3E0);
      case 'auto':
        return AppColors.blueLight;
      case 'bill':
        return AppColors.greenLight;
      case 'general':
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFf0f4f8);
    }
  }

  String get _typeLabel {
    switch (note['type'] as String) {
      case 'sticky':
        return '📌 ثابتة';
      case 'auto':
        return '🔄 تلقائية';
      case 'bill':
        return '💳 فاتورة';
      case 'general':
        return '💼 شغل عام';
      default:
        return '✍️ يدوية';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = onDelete != null || onDeleteSticky != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: group + type + date
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(8)),
            child: Text(note['groupPhone'] as String,
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue2)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: _typeBg, borderRadius: BorderRadius.circular(8)),
            child: Text(_typeLabel,
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _typeColor)),
          ),
          const Spacer(),
          if ((note['date'] as String).isNotEmpty)
            Text(note['date'] as String,
                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
          // Phase 5: toggle complete for general notes
          if (onToggleCompleted != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onToggleCompleted,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: (note['isCompleted'] == true)
                        ? AppColors.greenLight
                        : const Color(0xFFf5f5f5),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(
                    (note['isCompleted'] == true)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: (note['isCompleted'] == true)
                        ? AppColors.green
                        : AppColors.muted),
              ),
            ),
          ],
          if (canDelete) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (onDeleteSticky != null) {
                  onDeleteSticky!();
                } else {
                  onDelete!();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, size: 12, color: AppColors.red),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        // Note text
        Text(note['text'] as String,
            style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: note['type'] == 'sticky'
                    ? FontWeight.w700
                    : FontWeight.w500)),
        if (note['ownerName'] != null) ...[
          const SizedBox(height: 4),
          Text(note['ownerName'] as String,
              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
        ],
      ]),
    );
  }
}
