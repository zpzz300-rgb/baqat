// lib/widgets/menu_order_editor.dart
// 🔀 محرّر ترتيب قوايم التنقّل:
//  - الأقسام: تسحبها فوق/تحت، وكل قسم جواه بنوده
//  - البنود: سحب وإفلات جوه القسم + سهمين ⬆️⬇️ بديل
//  - ↔️ نقل بند لقسم تاني
//  - 👁 إخفاء/إظهار — إخفاء بس، مفيش أي حذف
//  الترتيب واحد مشترك بيتطبّق على القايمة الجانبية ☰ ولوحة التنقّل 🗂،
//  وبيتحفظ في SharedPreferences فبيرجع زي ما هو بعد قفل البرنامج.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/responsive.dart';
import '../services/menu_catalog.dart';

/// بيفتح المحرّر كـ bottom sheet.
Future<void> showMenuOrderEditor(BuildContext context) => showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MenuOrderEditor(),
    );

class MenuOrderEditor extends StatefulWidget {
  const MenuOrderEditor({super.key});

  @override
  State<MenuOrderEditor> createState() => _MenuOrderEditorState();
}

class _MenuOrderEditorState extends State<MenuOrderEditor> {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final sections = prov.orderedMenuSections;
    final allKeys = kMenuCatalog.map((e) => e.key).toList();
    final hiddenCount = allKeys.where(prov.isMenuHidden).length;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔀 ترتيب القايمة',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                            color: AppColors.blue2)),
                    Text('اسحب البند جوه قسمه • ↔️ ينقله لقسم تاني • 👁 يخفيه',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: AppColors.muted)),
                  ]),
            ),
            TextButton.icon(
              onPressed: () => prov.resetMenuPrefs(),
              icon: const Icon(Icons.restart_alt, size: 17),
              label: Text('الأصلي',
                  style: GoogleFonts.cairo(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              const Text('👁', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    '$hiddenCount بند مخفي — موجود هنا وتقدر ترجّعه في أي وقت',
                    style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: const Color(0xFF9A6A00),
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        const Divider(height: 1),
        // ── الأقسام: القايمة الخارجية قابلة للسحب هي كمان ──
        Flexible(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
            itemCount: sections.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final ids = sections.map((e) => e.id).toList();
              ids.insert(newIndex, ids.removeAt(oldIndex));
              prov.setMenuSectionOrder(ids);
            },
            itemBuilder: (context, si) =>
                _sectionCard(context, prov, sections[si], si),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue2,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('✔️ خلاص',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── كارت القسم ──────────────────────────────────────────────
  Widget _sectionCard(BuildContext context, AppProvider prov,
      MenuSectionDef sec, int sectionIndex) {
    final color = Color(sec.color);
    // المخفي بيفضل ظاهر في المحرّر (dropHidden: false) عشان تقدر ترجّعه
    final keys = prov.menuItemsOfSection(
        kMenuCatalog.map((e) => e.key).toList(), (k) => k, sec.id,
        dropHidden: false);
    final collapsed = prov.isMenuSectionCollapsed(sec.id);
    final visible = keys.where((k) => !prov.isMenuHidden(k)).length;

    return Container(
      key: ValueKey('sec_${sec.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5EE)),
      ),
      child: Column(children: [
        // رأس القسم — دوسة تفتح/تقفل، والسحب من ⣿
        InkWell(
          onTap: () => prov.toggleMenuSection(sec.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: collapsed
                  ? BorderRadius.circular(14)
                  : const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                  right: BorderSide(color: color, width: 3.5)),
            ),
            child: Row(children: [
              Text(sec.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sec.title,
                    style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
              Text('$visible',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted)),
              Icon(collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 20, color: color),
              ReorderableDragStartListener(
                index: sectionIndex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_indicator,
                      size: 19, color: Colors.grey[400]),
                ),
              ),
            ]),
          ),
        ),
        if (!collapsed)
          if (keys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('القسم فاضي — انقل ليه بنود بزرار ↔️',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5, color: AppColors.muted)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              itemCount: keys.length,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final within = List<String>.from(keys);
                within.insert(newIndex, within.removeAt(oldIndex));
                _saveWithinSection(prov, sec.id, within);
              },
              itemBuilder: (context, i) =>
                  _itemRow(context, prov, keys[i], i, color),
            ),
      ]),
    );
  }

  /// بيدمج الترتيب الجديد لقسم واحد جوه الترتيب العام من غير ما يلخبط
  /// باقي الأقسام: بناخد الترتيب الكامل ونستبدل مواقع بنود القسم بس.
  void _saveWithinSection(
      AppProvider prov, String sectionId, List<String> within) {
    final all = prov.applyMenuOrder(
        kMenuCatalog.map((e) => e.key).toList(), (k) => k,
        dropHidden: false);
    var n = 0;
    final merged = [
      for (final k in all)
        if (prov.menuSectionOf(k) == sectionId) within[n++] else k
    ];
    prov.setMenuOrder(merged);
  }

  // ─── سطر البند ───────────────────────────────────────────────
  Widget _itemRow(BuildContext context, AppProvider prov, String key, int i,
      Color secColor) {
    final def = menuItemDef(key)!;
    final hidden = prov.isMenuHidden(key);
    final locked =
        AppProvider.kMenuAlwaysVisible.contains(AppProvider.menuKeyAlias(key));

    return Container(
      key: ValueKey('item_$key'),
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hidden ? const Color(0xFFF6F7F9) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: hidden ? const Color(0xFFE2E6EB) : const Color(0xFFE7EDF4)),
      ),
      child: Row(children: [
        SizedBox(
          width: 20,
          child: Text('${i + 1}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted)),
        ),
        Text(def.emoji,
            style: TextStyle(fontSize: 15, color: hidden ? Colors.grey : null)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(def.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: hidden ? AppColors.muted : const Color(0xFF1C2B3A),
                  decoration: hidden ? TextDecoration.lineThrough : null)),
        ),
        // ↔️ نقل لقسم تاني
        _iconBtn(Icons.swap_horiz, secColor,
            () => _pickSection(context, prov, key, def.title)),
        // 👁 إخفاء / 📌 مقفول
        if (locked)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Icon(Icons.push_pin, size: 14, color: Colors.grey[400]),
          )
        else
          _iconBtn(
              hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              hidden ? const Color(0xFFB08900) : AppColors.blue2,
              () => prov.toggleMenuHidden(key)),
        ReorderableDragStartListener(
          index: i,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child:
                Icon(Icons.drag_indicator, size: 17, color: Colors.grey[400]),
          ),
        ),
      ]),
    );
  }

  Future<void> _pickSection(BuildContext context, AppProvider prov, String key,
      String title) async {
    final current = prov.menuSectionOf(key);
    await showAppSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('انقل «$title» لقسم:',
              style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue2)),
          const SizedBox(height: 12),
          for (final s in prov.orderedMenuSections)
            ListTile(
              dense: true,
              leading: Text(s.emoji, style: const TextStyle(fontSize: 18)),
              title: Text(s.title,
                  style: GoogleFonts.cairo(
                      fontSize: 13, fontWeight: FontWeight.w800)),
              trailing: s.id == current
                  ? Icon(Icons.check_circle, color: Color(s.color), size: 20)
                  : null,
              onTap: () {
                prov.setMenuItemSection(key, s.id);
                Navigator.pop(sheetCtx);
              },
            ),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(6),
        onPressed: onTap,
        icon: Icon(icon, size: 17, color: color),
      );
}
