// lib/widgets/workspace_bar.dart
// 🗂️ مساحة العمل متعددة التابات:
//  - WorkspaceBar: شريط علوي أبيض فلات بالتابات المفتوحة (التاب النشط أزرق)
//    قابل للتمرير، كل تاب ليه ✕، ودوسة مطوّلة = قفل كل التابات التانية.
//  - WorkspaceTabHost: بيستضيف شاشة كل تاب جوه Navigator داخلي مستقل —
//    أي فتح/قفل شاشات جوه التاب بيفضل محبوس جواه، ولما يترجع لآخر صفحة
//    التاب بيقفل نفسه تلقائياً.
//  الشاشات بتفضل حية في الذاكرة (IndexedStack في home_screen) فالموظف
//  يرجع للتاب يلاقي البحث والفلاتر والكتابة زي ما سابها بالظبط.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/menu_catalog.dart' show menuItemDef;
import '../screens/today_screen.dart';
import '../screens/help_screen.dart';
import '../screens/guarantors_screen.dart';
import '../screens/unified_billing_screen.dart';
import '../screens/member_filter_screen.dart';
import '../screens/assets_dashboard_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/worknums_screen.dart';
import '../screens/profit_screen.dart';
import '../screens/rentals_screen.dart';
import '../screens/gifts_screen.dart';
import '../screens/guests_screen.dart';
import '../screens/archive_screen.dart';
import '../screens/activity_screen.dart';
import '../screens/dataio_screen.dart';
import '../screens/deleted_screen.dart';
import '../screens/waitlist_screen.dart';
import '../screens/consolidated_screen.dart';
import '../screens/bulk_message_screen.dart';
import '../screens/flagged_members_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/complaints_screen.dart';
import 'member_card.dart';
import 'group_card.dart';

/// 📚 سجل شاشات مساحة العمل: type → (إيموجي، عنوان، بنّاء الشاشة، Scaffold كامل؟)
/// بيستخدمه حاضن التاب + لوحة التنقّل السفلية 🗂 — تضيف شاشة هنا تظهر في الاتنين.
typedef WorkspaceScreenDef = ({
  String emoji,
  String title,
  Widget Function() build,
  bool fullScreen, // الشاشة Scaffold كامل بنفسها (مش محتاجة غلاف)
});

/// بيجيب الاسم والإيموچي من سجل القوايم (menu_catalog) بدل ما نكتبهم
/// هنا تاني — عشان لو غيّرنا اسم شاشة يتغيّر في كل مكان مرة واحدة.
WorkspaceScreenDef _def(String key, Widget Function() build,
    {bool fullScreen = false}) {
  final d = menuItemDef(key);
  return (
    emoji: d?.emoji ?? '📄',
    title: d?.title ?? key,
    build: build,
    fullScreen: fullScreen,
  );
}

final Map<String, WorkspaceScreenDef> kWorkspaceScreens = {
  'today':       _def('today',       () => const TodayScreen()),
  'reminders':   _def('reminders',   () => const RemindersScreen()),
  'guarantors':  _def('guarantors',  () => const GuarantorsScreen()),
  'invoices':    _def('invoices',    () => const UnifiedBillingScreen()),
  'profit':      _def('profit',      () => const ProfitScreen()),
  'filter':      _def('filter',      () => const MemberFilterScreen(), fullScreen: true),
  'assets':      _def('assets',      () => const AssetsDashboardScreen(), fullScreen: true),
  'flagged':     _def('flagged',     () => const FlaggedMembersScreen()),
  'consolidated':_def('consolidated',() => const ConsolidatedScreen()),
  'worknums':    _def('worknums',    () => const WorkNumsScreen()),
  'rentals':     _def('rentals',     () => const RentalsScreen()),
  'gifts':       _def('gifts',       () => const GiftsScreen()),
  'guests':      _def('guests',      () => const GuestsScreen()),
  'bulk':        _def('bulk',        () => const BulkMessageScreen()),
  'notes':       _def('notes',       () => const NotesScreen()),
  'complaints':  _def('complaints',  () => const ComplaintsScreen()),
  'waitlist':    _def('waitlist',    () => const WaitlistScreen()),
  'archive':     _def('archive',     () => const ArchiveScreen()),
  'deleted':     _def('deleted',     () => const DeletedScreen()),
  'activity':    _def('activity',    () => const ActivityScreen()),
  'dataio':      _def('dataio',      () => const DataIOScreen()),
  'help':        _def('help',        () => const HelpScreen(), fullScreen: true),
};

// ─── شريط التابات ───────────────────────────────────────────────
class WorkspaceBar extends StatelessWidget {
  const WorkspaceBar({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final tabs = prov.workspaceTabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    final active = prov.activeWorkspaceIndex;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: Color(0xFFDBE4EF))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          // 🏠 تاب الرئيسية — ثابت مبيتقفلش
          _tabChip(
            context,
            label: '🏠 الرئيسية',
            selected: active == 0,
            onTap: () => prov.activateWorkspaceTab(0),
          ),
          for (int i = 0; i < tabs.length; i++)
            _tabChip(
              context,
              label: '${tabs[i].emoji} ${tabs[i].title}',
              selected: active == i + 1,
              onTap: () => prov.activateWorkspaceTab(i + 1),
              onLongPress: () => prov.closeOtherWorkspaceTabs(i),
              onClose: () => prov.closeWorkspaceTab(i),
            ),
        ],
      ),
    );
  }

  Widget _tabChip(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      VoidCallback? onClose}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.only(
              right: 12, left: onClose != null ? 4 : 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue2 : const Color(0xFFF2F6FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.blue2 : const Color(0xFFD5E0EC)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF1C2B3A),
                ),
              ),
            ),
            if (onClose != null)
              GestureDetector(
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close,
                      size: 14,
                      color: selected ? Colors.white70 : AppColors.muted),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─── حاضن شاشة التاب ─────────────────────────────────────────────
// Navigator داخلي بطبقتين: [صفحة قاعدة، المحتوى].
// أي «رجوع/✕» جوه التاب بيرجّع لصفحة القاعدة → القاعدة تقفل التاب تلقائياً.
class WorkspaceTabHost extends StatelessWidget {
  final TabSession tab;
  const WorkspaceTabHost({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: tab.navKey,
      observers: [tab.routeObserver],
      onGenerateInitialRoutes: (nav, initial) => [
        MaterialPageRoute(builder: (_) => _TabBasePage(tab: tab)),
        MaterialPageRoute(builder: (_) => _TabRoot(tab: tab)),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (ctx) => _TabRoot(tab: tab),
      ),
    );
  }
}

// صفحة القاعدة: أول ما تبان (يعني المحتوى اتقفل من جواه) بتقفل التاب كله
class _TabBasePage extends StatefulWidget {
  final TabSession tab;
  const _TabBasePage({required this.tab});
  @override
  State<_TabBasePage> createState() => _TabBasePageState();
}

class _TabBasePageState extends State<_TabBasePage> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) widget.tab.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.tab.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // المحتوى اللي فوقي اتقفل → اقفل التاب نفسه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<AppProvider>();
      final i = prov.workspaceTabs.indexWhere((t) => t.id == widget.tab.id);
      if (i >= 0) prov.closeWorkspaceTab(i);
    });
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: AppColors.bg);
}

class _TabRoot extends StatelessWidget {
  final TabSession tab;
  const _TabRoot({required this.tab});

  /// قفل التاب ده نفسه من مدير التابات
  void _closeSelf(BuildContext context) {
    final prov = context.read<AppProvider>();
    final i = prov.workspaceTabs.indexWhere((t) => t.id == tab.id);
    if (i >= 0) prov.closeWorkspaceTab(i);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    switch (tab.type) {
      // ── ملف عميل ──
      case 'member': {
        final mid = tab.args['mid'];
        final mi = prov.db.members.indexWhere((m) => m.id == mid);
        if (mi < 0) return _gone(context, 'العميل اتحذف أو اتنقل');
        final m = prov.db.members[mi];
        final g = prov.db.groups.cast<Group?>()
            .firstWhere((x) => x!.id == m.gid, orElse: () => null);
        if (g == null) return _gone(context, 'مجموعة العميل مش موجودة');
        // حدّث عنوان التاب لو الاسم اتغير
        tab.title = m.name;
        // MemberDrawer ارتفاعه ثابت (0.93 من الشاشة) وفيه سكرول داخلي —
        // بيتحضن مباشرة، و✕ بتاعه بيقفل التاب (عن طريق صفحة القاعدة)
        // ارتفاعه أكبر بشوية من مساحة التاب → سكرول خارجي خفيف يمنع الـ overflow
        return _shell(
          context,
          body: SingleChildScrollView(
              child: MemberDrawer(member: m, group: g)),
          bg: const Color(0xFFEDF2F8),
        );
      }

      // ── خط/مجموعة ──
      case 'group': {
        final gid = tab.args['gid'];
        final gi = prov.db.groups.indexWhere((g) => g.id == gid);
        if (gi < 0) return _gone(context, 'الخط اتحذف أو اتأرشف');
        final g = prov.db.groups[gi];
        tab.title = g.ownerName?.isNotEmpty == true ? g.ownerName! : g.phone;
        return _shell(
          context,
          body: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              GroupCard(
                  group: g,
                  initiallyExpanded: true,
                  initiallyMembersExpanded: true),
            ],
          ),
          bg: const Color(0xFFEDF2F8),
        );
      }

      // ── باقي شاشات البرنامج من السجل الموحّد ──
      default: {
        final def = kWorkspaceScreens[tab.type];
        if (def == null) return _gone(context, 'شاشة غير معروفة');
        // الشاشات الكاملة (Scaffold خاص بها) بتتحط مباشرة —
        // زرار الرجوع بتاعها بيرجّع لصفحة القاعدة فالتاب بيقفل نفسه
        if (def.fullScreen) return def.build();
        return _shell(context, body: def.build());
      }
    }
  }

  /// غلاف موحّد بسيط للشاشات المدمجة
  Widget _shell(BuildContext context, {required Widget body, Color? bg}) {
    return Scaffold(
      backgroundColor: bg ?? const Color(0xFFF5F7FA),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _gone(BuildContext context, String msg) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🗑', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(msg, style: GoogleFonts.cairo(color: AppColors.muted)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue2),
            onPressed: () => _closeSelf(context),
            child: Text('اقفل التاب',
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}
