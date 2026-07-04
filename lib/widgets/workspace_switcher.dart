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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SwitcherSheet(),
    );
  }
}

class _SwitcherSheet extends StatelessWidget {
  const _SwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final tabs = prov.workspaceTabs;
    final active = prov.activeWorkspaceIndex;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
        Text('فتح في تاب جديد:',
            style: GoogleFonts.cairo(
                fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
        const SizedBox(height: 6),

        // ── اختصارات فتح تابات جديدة ──
        Wrap(spacing: 8, runSpacing: 8, children: [
          _shortcut(context, '🧾 الفواتير', () {
            prov.openWorkspaceTab('invoices', title: 'الفواتير', emoji: '🧾');
            Navigator.pop(context);
          }),
          _shortcut(context, '🤝 الكفلاء', () {
            prov.openWorkspaceTab('guarantors', title: 'الكفلاء', emoji: '🤝');
            Navigator.pop(context);
          }),
          _shortcut(context, '🎛️ تصنيف العملاء', () {
            prov.openWorkspaceTab('filter', title: 'تصنيف العملاء', emoji: '🎛️');
            Navigator.pop(context);
          }),
          _shortcut(context, '📊 لوحة الأصول', () {
            prov.openWorkspaceTab('assets', title: 'الأصول', emoji: '📊');
            Navigator.pop(context);
          }),
        ]),
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

  Widget _shortcut(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
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
