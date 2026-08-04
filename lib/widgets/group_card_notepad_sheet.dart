// lib/widgets/group_card_notepad_sheet.dart
// 📝 نوتة الخط — جزء من group_card.dart.
// اتفصل عشان الملف كان 2984 سطر وبقى صعب يتقرا. الكود زي ما هو بالظبط.
part of 'group_card.dart';

class _GroupNotepadSheet extends StatefulWidget {
  final Group group;
  const _GroupNotepadSheet({required this.group});
  @override
  State<_GroupNotepadSheet> createState() => _GroupNotepadSheetState();
}

class _GroupNotepadSheetState extends State<_GroupNotepadSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final group = prov.db.groups
        .firstWhere((g) => g.id == widget.group.id, orElse: () => widget.group);
    final notes = group.groupNotes;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDE7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
          child: Row(children: [
            const Text('📓', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('مفكرة الخط',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                  Text(group.phone,
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.muted)),
                ])),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        // Add note input
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 2,
                minLines: 1,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'اكتب ملاحظة...',
                  hintStyle:
                      GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_ctrl.text.trim().isEmpty) return;
                context.read<AppProvider>().addGroupNote(group.id, _ctrl.text);
                _ctrl.clear();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        // Notes list
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📝', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('لا توجد ملاحظات بعد',
                      style: GoogleFonts.cairo(
                          color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('الملاحظات التلقائية تظهر عند التجديد',
                      style: GoogleFonts.cairo(
                          color: AppColors.muted, fontSize: 11)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = notes[i];
                    final isAuto = n['type'] == 'auto';
                    final isBill = n['type'] == 'bill';
                    final bg = isBill
                        ? const Color(0xFFEDE7F6)
                        : isAuto
                            ? const Color(0xFFE3F2FD)
                            : Colors.white;
                    final borderColor = isBill
                        ? const Color(0xFFCE93D8)
                        : isAuto
                            ? AppColors.blueMid
                            : AppColors.border;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(n['text'] ?? '',
                                  style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(n['date'] ?? '',
                                  style: GoogleFonts.cairo(
                                      fontSize: 10, color: AppColors.muted)),
                            ])),
                        if (!isAuto)
                          GestureDetector(
                            onTap: () => context
                                .read<AppProvider>()
                                .deleteGroupNote(group.id, i),
                            child: Icon(Icons.delete_outline,
                                size: 18, color: AppColors.muted),
                          ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Points Details Bottom Sheet
// ─────────────────────────────────────────────────────────────────