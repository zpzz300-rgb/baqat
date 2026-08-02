// lib/screens/group_folders_screen.dart
// 🗂 دليل الخطوط الرئيسية — تصنيف/تشجير قابل للتعشيش لأرقام الخطوط
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';

class GroupFoldersScreen extends StatefulWidget {
  const GroupFoldersScreen({super.key});
  @override
  State<GroupFoldersScreen> createState() => _GroupFoldersScreenState();
}

class _GroupFoldersScreenState extends State<GroupFoldersScreen> {
  final Set<String> _expanded = {};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final searching = _search.trim().isNotEmpty;

    Set<String>? matchGroupIds;
    Set<String> forceExpand = {};
    if (searching) {
      final q = _search.trim().toLowerCase();
      matchGroupIds = prov.db.groups
          .where((g) =>
              g.phone.toLowerCase().contains(q) ||
              (g.ownerName ?? '').toLowerCase().contains(q))
          .map((g) => g.id)
          .toSet();
      for (final g in prov.db.groups.where((g) => matchGroupIds!.contains(g.id))) {
        var fid = g.folderId;
        while (fid != null) {
          if (!forceExpand.add(fid)) break;
          fid = prov.db.groupFolders
              .firstWhere((f) => f.id == fid, orElse: () => GroupFolder(id: '', name: ''))
              .parentFolderId;
        }
      }
    }

    final rows = _buildLevel(context, prov, null, 0,
        searching: searching, matchGroupIds: matchGroupIds, forceExpand: forceExpand);

    return Scaffold(
      backgroundColor: const Color(0xFFf8fbff),
      appBar: AppBar(
        title: Text('🗂 دليل الخطوط الرئيسية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: AppColors.blue2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'فولدر جديد',
            icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white),
            onPressed: () => _promptCreateFolder(context, prov, null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: '🔍 بحث برقم الخط أو اسم صاحبه...',
                hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _search = ''))
                    : null,
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      searching ? 'لا نتائج' : 'مفيش خطوط أو فولدرات لسه\nدوس + فوق عشان تعمل فولدر',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                    children: rows,
                  ),
          ),
        ],
      ),
    );
  }

  // ── بناء مستوى واحد في الشجرة (فولدرات ثم خطوط) ──────────────
  List<Widget> _buildLevel(
    BuildContext context,
    AppProvider prov,
    String? parentFolderId,
    int depth, {
    required bool searching,
    Set<String>? matchGroupIds,
    required Set<String> forceExpand,
  }) {
    final folders = prov.foldersUnder(parentFolderId);
    final groups = prov.groupsInFolder(parentFolderId);
    final widgets = <Widget>[];

    for (var i = 0; i < folders.length; i++) {
      final f = folders[i];
      if (searching && !forceExpand.contains(f.id)) continue;
      final isExpanded = searching ? true : _expanded.contains(f.id);
      widgets.add(_folderRow(context, prov, f, depth, isExpanded, i, folders.length));
      if (isExpanded) {
        widgets.addAll(_buildLevel(context, prov, f.id, depth + 1,
            searching: searching, matchGroupIds: matchGroupIds, forceExpand: forceExpand));
      }
    }

    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      if (searching && !(matchGroupIds?.contains(g.id) ?? true)) continue;
      widgets.add(_groupRow(context, prov, g, depth, i, groups.length));
    }

    return widgets;
  }

  Widget _folderRow(BuildContext context, AppProvider prov, GroupFolder f, int depth,
      bool expanded, int siblingIndex, int siblingCount) {
    return Container(
      margin: EdgeInsets.only(right: depth * 18.0, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        dense: true,
        onTap: () => setState(() {
          if (!_expanded.remove(f.id)) _expanded.add(f.id);
        }),
        leading: Icon(expanded ? Icons.folder_open : Icons.folder, color: AppColors.blue3),
        title: Text(f.name,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              onPressed: siblingIndex == 0
                  ? null
                  : () => prov.reorderFoldersAt(f.parentFolderId, siblingIndex, siblingIndex - 1),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              onPressed: siblingIndex == siblingCount - 1
                  ? null
                  : () => prov.reorderFoldersAt(f.parentFolderId, siblingIndex, siblingIndex + 1),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.muted),
              onSelected: (v) => _onFolderAction(context, prov, f, v),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'addSub', child: Text('➕ فولدر فرعي', style: GoogleFonts.cairo())),
                PopupMenuItem(value: 'rename', child: Text('✏️ تعديل الاسم', style: GoogleFonts.cairo())),
                PopupMenuItem(value: 'move', child: Text('📂 نقل إلى فولدر آخر', style: GoogleFonts.cairo())),
                PopupMenuItem(value: 'delete', child: Text('🗑 حذف الفولدر', style: GoogleFonts.cairo(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupRow(BuildContext context, AppProvider prov, Group g, int depth,
      int siblingIndex, int siblingCount) {
    return Container(
      margin: EdgeInsets.only(right: depth * 18.0, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.podcasts, color: AppColors.blue2),
        title: Text(g.phone,
            textDirection: TextDirection.ltr,
            style: GoogleFonts.robotoMono(fontWeight: FontWeight.w800, fontSize: 13)),
        subtitle: (g.ownerName?.isNotEmpty ?? false)
            ? Text(g.ownerName!, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted))
            : null,
        onTap: () => prov.openWorkspaceTab(
              'group',
              args: {'gid': g.id},
              title: g.ownerName?.isNotEmpty == true ? g.ownerName! : g.phone,
              emoji: '📶',
            ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              onPressed: siblingIndex == 0
                  ? null
                  : () => prov.reorderGroupsInFolder(g.folderId, siblingIndex, siblingIndex - 1),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              onPressed: siblingIndex == siblingCount - 1
                  ? null
                  : () => prov.reorderGroupsInFolder(g.folderId, siblingIndex, siblingIndex + 1),
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move_outline, size: 18, color: AppColors.muted),
              tooltip: 'نقل لفولدر',
              onPressed: () => _pickFolderForGroup(context, prov, g),
            ),
          ],
        ),
      ),
    );
  }

  // ── إنشاء فولدر ────────────────────────────────────────────────
  void _promptCreateFolder(BuildContext context, AppProvider prov, String? parentFolderId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('📁 فولدر جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'اسم الفولدر', hintStyle: GoogleFonts.cairo()),
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                prov.createGroupFolder(ctrl.text, parentFolderId: parentFolderId);
                if (parentFolderId != null) setState(() => _expanded.add(parentFolderId));
              }
              Navigator.pop(context);
            },
            child: Text('إنشاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _onFolderAction(BuildContext context, AppProvider prov, GroupFolder f, String action) {
    switch (action) {
      case 'addSub':
        _promptCreateFolder(context, prov, f.id);
        break;
      case 'rename':
        final ctrl = TextEditingController(text: f.name);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('✏️ تعديل اسم الفولدر', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            content: TextField(controller: ctrl, autofocus: true, style: GoogleFonts.cairo()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  prov.renameGroupFolder(f.id, ctrl.text);
                  Navigator.pop(context);
                },
                child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        break;
      case 'move':
        _pickFolderForFolder(context, prov, f);
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('🗑 حذف الفولدر؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            content: Text(
                'محتويات الفولدر (خطوط وفولدرات فرعية) هتترحّل لمستوى الفولدر الأب، مش هتتحذف.',
                style: GoogleFonts.cairo(fontSize: 12)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  prov.deleteGroupFolder(f.id);
                  Navigator.pop(context);
                },
                child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _pickFolderForGroup(BuildContext context, AppProvider prov, Group g) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderPickerSheet(
        title: 'نقل "${g.phone}" إلى',
        currentId: g.folderId,
        excludeIds: const {},
        onPick: (id) => prov.moveGroupToFolder(g.id, id),
      ),
    );
  }

  void _pickFolderForFolder(BuildContext context, AppProvider prov, GroupFolder f) {
    // استبعاد الفولدر نفسه وكل أحفاده عشان منعملش حلقة لا نهائية
    final exclude = <String>{f.id};
    void collect(String pid) {
      for (final child in prov.db.groupFolders.where((x) => x.parentFolderId == pid)) {
        exclude.add(child.id);
        collect(child.id);
      }
    }

    collect(f.id);
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderPickerSheet(
        title: 'نقل فولدر "${f.name}" إلى',
        currentId: f.parentFolderId,
        excludeIds: exclude,
        onPick: (id) => prov.moveGroupFolder(f.id, id),
      ),
    );
  }
}

// ── قائمة اختيار فولدر (Bottom Sheet) ─────────────────────────────
class _FolderPickerSheet extends StatelessWidget {
  final String title;
  final String? currentId;
  final Set<String> excludeIds;
  final void Function(String? id) onPick;
  const _FolderPickerSheet({
    required this.title,
    required this.currentId,
    required this.excludeIds,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final rows = <(GroupFolder, int)>[];
    void walk(String? parentId, int depth) {
      for (final f in prov.foldersUnder(parentId)) {
        if (excludeIds.contains(f.id)) continue;
        rows.add((f, depth));
        walk(f.id, depth + 1);
      }
    }

    walk(null, 0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.layers_clear, color: AppColors.muted),
                    title: Text('بدون تصنيف (جذر الدليل)',
                        style: GoogleFonts.cairo(
                            fontWeight: currentId == null ? FontWeight.w900 : FontWeight.w600)),
                    trailing: currentId == null
                        ? const Icon(Icons.check, color: AppColors.blue2)
                        : null,
                    onTap: () {
                      onPick(null);
                      Navigator.pop(context);
                    },
                  ),
                  for (final (f, depth) in rows)
                    ListTile(
                      contentPadding: EdgeInsets.only(right: 16.0 + depth * 20, left: 16),
                      leading: const Icon(Icons.folder, color: AppColors.blue3),
                      title: Text(f.name,
                          style: GoogleFonts.cairo(
                              fontWeight: currentId == f.id ? FontWeight.w900 : FontWeight.w600)),
                      trailing: currentId == f.id
                          ? const Icon(Icons.check, color: AppColors.blue2)
                          : null,
                      onTap: () {
                        onPick(f.id);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
