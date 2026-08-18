// lib/widgets/workspace_switcher.dart
// 🗂 زرار التنقّل السفلي الثابت:
//  - زرار صغير تحت في نص الشاشة بعدد التابات المفتوحة
//  - دوسة → لوحة تنقّل سريعة: الرئيسية + التابات المفتوحة (بـ ✕ لكل واحد)
//    + اختصارات لفتح شاشات جديدة في تابات
//  - التنقّل بيسيب كل شاشة زي ما هي بالظبط (التابات حية في الذاكرة)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/responsive.dart';
import 'workspace_bar.dart' show kWorkspaceScreens, WorkspaceScreenDef;
import 'menu_order_editor.dart' show showMenuOrderEditor;
import '../services/menu_catalog.dart' show normalizeArabic;
import '../screens/home_screen.dart' show openGlobalSearch;

class WorkspaceSwitcherButton extends StatelessWidget {
  const WorkspaceSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final count = prov.workspaceTabs.length;

    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => _openSwitcher(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B3E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🗂', style: TextStyle(fontSize: 15)),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text('$count',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  void _openSwitcher(BuildContext context) {
    showAppSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SwitcherSheet(),
    );
  }
}

class _SwitcherSheet extends StatefulWidget {
  const _SwitcherSheet();

  @override
  State<_SwitcherSheet> createState() => _SwitcherSheetState();
}

class _SwitcherSheetState extends State<_SwitcherSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final tabs = prov.workspaceTabs;
    final active = prov.activeWorkspaceIndex;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text('🗂 التنقّل السريع',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.blue2)),
        Text('كل شاشة بترجع لها تلاقيها زي ما سبتها',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 12),

        Flexible(
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── الرئيسية + التابات المفتوحة ──
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _tabTile(
                      context,
                      label: '🏠 الرئيسية',
                      selected: active == 0,
                      onTap: () {
                        prov.activateWorkspaceTab(0);
                        Navigator.pop(context);
                      },
                    ),
                    for (int i = 0; i < tabs.length; i++)
                      _tabTile(
                        context,
                        label: '${tabs[i].emoji} ${tabs[i].title}',
                        selected: active == i + 1,
                        onTap: () {
                          prov.activateWorkspaceTab(i + 1);
                          Navigator.pop(context);
                        },
                        onClose: () => prov.closeWorkspaceTab(i),
                      ),
                  ]),

                  const SizedBox(height: 14),

                  // 🔍 البحث الشامل — متاح من هنا يعني من أي شاشة، لأن
                  // اللوحة دي بتتفتح من زرار التنقّل السفلي في كل مكان.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blueLight,
                        foregroundColor: AppColors.blue2,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.blueMid)),
                      ),
                      icon: const Icon(Icons.search, size: 19),
                      label: Text('دوّر في البرنامج كله',
                          style: GoogleFonts.cairo(
                              fontSize: 13, fontWeight: FontWeight.w900)),
                      onPressed: () {
                        Navigator.pop(context);
                        openGlobalSearch?.call();
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(children: [
                    Expanded(
                      child: Text('فتح في تاب جديد:',
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted)),
                    ),
                    // 🔀 نفس محرّر ترتيب القايمة الجانبية — ترتيب واحد للاتنين
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        showMenuOrderEditor(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Text('🔀 ترتيب',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blue2)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),

                  // 🔍 بحث في الشاشات
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.cairo(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'دوّر على شاشة…',
                      hintStyle: GoogleFonts.cairo(
                          fontSize: 12.5, color: AppColors.muted),
                      prefixIcon: const Icon(Icons.search, size: 19),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _query = '';
                              }),
                            ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF3F6FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── الشاشات: مقسّمة لأقسام، أو نتيجة بحث مسطّحة ──
                  ..._screens(context, prov),
                ]),
          ),
        ),
      ]),
    );
  }

  Widget _tabTile(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap,
      VoidCallback? onClose}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
            right: 12, left: onClose != null ? 4 : 12, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue2 : const Color(0xFFF2F6FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.blue2 : const Color(0xFFD5E0EC)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color:
                        selected ? Colors.white : const Color(0xFF1C2B3A))),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(Icons.close,
                    size: 14,
                    color: selected ? Colors.white70 : AppColors.muted),
              ),
            ),
        ]),
      ),
    );
  }

  // ─── الشاشات: أقسام قابلة للطي، أو نتيجة بحث مسطّحة ──────────────
  List<Widget> _screens(BuildContext context, AppProvider prov) {
    final all = kWorkspaceScreens.entries.toList();

    void open(MapEntry<String, WorkspaceScreenDef> e) {
      prov.openWorkspaceTab(e.key,
          title: e.value.title, emoji: e.value.emoji);
      Navigator.pop(context);
    }

    // 🔍 وضع البحث: بنسطّح كل الأقسام، والمخفي بيظهر برضه — الإخفاء
    // بيشيله من العرض مش من البرنامج.
    if (_query.trim().isNotEmpty) {
      final q = normalizeArabic(_query);
      final hits = prov
          .applyMenuOrder(all, (e) => e.key, dropHidden: false)
          .where((e) => normalizeArabic(e.value.title).contains(q))
          .toList();
      if (hits.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('مفيش شاشة بالاسم ده',
                  style: GoogleFonts.cairo(
                      fontSize: 12.5, color: AppColors.muted)),
            ),
          )
        ];
      }
      return [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in hits)
            _shortcut(context, '${e.value.emoji} ${e.value.title}',
                () => open(e)),
        ])
      ];
    }

    // 📂 وضع الأقسام
    final out = <Widget>[];
    for (final sec in prov.orderedMenuSections) {
      final inSec = prov.menuItemsOfSection(all, (e) => e.key, sec.id);
      if (inSec.isEmpty) continue;
      final collapsed = prov.isMenuSectionCollapsed(sec.id);
      final color = Color(sec.color);
      out.add(GestureDetector(
        onTap: () => prov.toggleMenuSection(sec.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border(right: BorderSide(color: color, width: 3.5)),
          ),
          child: Row(children: [
            Text(sec.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(sec.title,
                  style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: color)),
            ),
            Text('${inSec.length}',
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
            const SizedBox(width: 4),
            Icon(collapsed ? Icons.expand_more : Icons.expand_less,
                size: 18, color: color),
          ]),
        ),
      ));
      if (!collapsed) {
        out.add(Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in inSec)
              _shortcut(context, '${e.value.emoji} ${e.value.title}',
                  () => open(e)),
          ]),
        ));
      }
    }
    return out;
  }

  Widget _shortcut(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB9D4EF)),
        ),
        child: Text('+ $label',
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.blue2)),
      ),
    );
  }
}
