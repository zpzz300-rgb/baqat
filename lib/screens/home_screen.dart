// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/app_theme.dart';
import '../services/supabase_service.dart';
import 'employees_screen.dart';
import '../widgets/group_card.dart';
import '../widgets/common.dart';
import '../utils/print_helper.dart';
import 'profit_screen.dart';
import 'guarantors_screen.dart';
import 'rentals_screen.dart';
import 'archive_screen.dart';
import 'gifts_screen.dart';
import 'activity_screen.dart';
import 'dataio_screen.dart';
import 'deleted_screen.dart';
import 'waitlist_screen.dart';
import 'reminders_screen.dart';
import 'worknums_screen.dart';
import 'guests_screen.dart';
import 'main_lines_screen.dart';
import 'group_folders_screen.dart';
import 'billing_accounts_screen.dart';
import 'consolidated_screen.dart';
import 'bulk_message_screen.dart';
import '../widgets/notes_bubble.dart';
import '../widgets/workspace_bar.dart';
import '../widgets/workspace_switcher.dart';
import '../widgets/menu_order_editor.dart';
import '../services/menu_catalog.dart';
import 'flagged_members_screen.dart';
import 'bills_screen.dart';
import 'notes_screen.dart';
import 'company_invoices_screen.dart';
import 'complaints_screen.dart';
import 'unified_billing_screen.dart';
import '../services/today_tasks.dart' show todayOverdueCount;
import '../widgets/add_group_modal.dart';
import '../widgets/add_member_modal.dart';
import '../widgets/member_card.dart';
import '../widgets/settings_modal.dart';
import '../widgets/ai_modal.dart';

/// 🔍 فتح البحث الشامل من **أي شاشة** في البرنامج.
///
/// الشاشة الرئيسية بتسجّل نفسها هنا وهي بتتبني، فأي حتة تانية (زي لوحة
/// التنقّل السريع 🗂) تقدر تفتح البحث من غير ما تعرف حاجة عن الرئيسية.
/// بيفضل `null` قبل ما الرئيسية تفتح — فاستخدم `?.call()`.
void Function()? openGlobalSearch;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _searchCtrl = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _headerExpanded = true;
  bool _empViewAll = false; // الموظف: false=شغلي، true=القائمة العامة

  // التمرير لمجموعة معيّنة بعد البحث (يفتح/يبيّن مجموعة العميل)
  final _groupsScrollCtrl = ScrollController();
  final Map<String, GlobalKey> _groupKeys = {};
  String? _focusExpandGid; // المجموعة اللي تتفتح تلقائياً بعد البحث

  // ─── ترتيب عرض الخطوط في الشاشة الرئيسية ────────────────────────
  // 'manual' = الترتيب اليدوي المحفوظ (بالسحب) — وهو الافتراضي.
  // أي وضع تاني بيقفل السحب عشان مايبوّظش الترتيب المحفوظ.
  // 🔍 بحث القايمة الجانبية (بيفلتر بنود التنقّل، مش البيانات)
  final TextEditingController _menuSearchCtrl = TextEditingController();
  String _menuQuery = '';

  static const _kSortPrefKey = 'groups_sort_mode';
  String _groupSort = 'manual';
  static const _sortModes = [
    {'key': 'manual', 'label': '✋ يدوي'},
    {'key': 'cancel', 'label': '📆 الأقرب للإلغاء'},
    {'key': 'name', 'label': '🔤 الاسم'},
    {'key': 'account', 'label': '🔁 الحساب'},
    {'key': 'provider', 'label': '🏢 الشركة'},
    {'key': 'cycle', 'label': '📅 السيكل'},
    {'key': 'package', 'label': '📦 الباقة'},
  ];

  // ─── 🏢 فلتر الشركة السريع ────────────────────────────────────────
  // ضغطة واحدة: «اتصالات» تورّيك خطوط اتصالات بس، وهكذا. بيتحفظ عشان
  // لما ترجع للبرنامج تلاقي نفس الفلتر شغّال.
  static const _kProvPrefKey = 'groups_provider_filter';
  String? _provFilter; // null = الكل
  static const _provOrder = ['vodafone', 'etisalat', 'orange', 'we'];
  static const _provShort = {
    'vodafone': 'VODA',
    'etisalat': 'ETIS',
    'orange': 'ORNG',
    'we': 'WE',
  };
  static const _provColors = {
    'vodafone': Color(0xFFe53935),
    'etisalat': Color(0xFF43a047),
    'orange': Color(0xFFfb8c00),
    'we': Color(0xFF5e35b1),
  };

  @override
  void initState() {
    super.initState();
    _loadSortMode();
    // 🔍 خلّي البحث الشامل متاح من أي شاشة في البرنامج
    openGlobalSearch = () {
      if (!mounted) return;
      _showGlobalSearch(context.read<AppProvider>());
    };
  }

  @override
  void dispose() {
    openGlobalSearch = null;
    _menuSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kSortPrefKey);
    final savedProv = prefs.getString(_kProvPrefKey);
    if (!mounted) return;
    setState(() {
      if (saved != null && _sortModes.any((m) => m['key'] == saved)) {
        _groupSort = saved;
      }
      if (savedProv != null && _provOrder.contains(savedProv)) {
        _provFilter = savedProv;
      }
    });
  }

  Future<void> _setSortMode(String key) async {
    setState(() => _groupSort = key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortPrefKey, key);
  }

  Future<void> _setProvFilter(String? p) async {
    setState(() => _provFilter = p);
    final prefs = await SharedPreferences.getInstance();
    if (p == null) {
      await prefs.remove(_kProvPrefKey);
    } else {
      await prefs.setString(_kProvPrefKey, p);
    }
  }

  // الإحصائيات المالية (الربح/الديون/الملخص) تظهر فقط في تاب المجموعات.
  // شاشة الأرباح (تاب 4) ليها ملخصها الخاص — فمنظهرش الهيدر هناك عشان
  // مايحصلش تكرار ولا overflow.
  bool get _showFinancialStats => _tab == 0;

  /// الاسم والإيموچي بييجوا من سجل القوايم (menu_catalog) — مصدر واحد
  /// للتلاتة (القايمة الجانبية + لوحة 🗂 + شريط التابات).
  static Map<String, dynamic> _nav(String key, {int? tab, String? wsKey}) {
    final d = menuItemDef(wsKey ?? AppProvider.menuKeyAlias(key));
    return {
      'icon': d?.emoji ?? '📄',
      'label': d?.title ?? key,
      'key': key,
      if (tab != null) 'tab': tab,
    };
  }

  // Main nav tabs (always visible)
  late final List<Map<String, dynamic>> _tabs = [
    _nav('groups'),
    _nav('reminders'),
    _nav('flagged', tab: 16),
    _nav('guarantors', tab: 2),
    _nav('worknums', tab: 3),
    _nav('profit', tab: 4),
    _nav('rentals', tab: 5),
    _nav('gifts', tab: 6),
    _nav('guests', tab: 12),
    _nav('consolidated', tab: 14),
  ];

  // "المزيد" menu items
  late final List<Map<String, dynamic>> _moreTabs = [
    _nav('billing', tab: 22), // الاسم بييجي من مفتاح invoices
    _nav('notes', tab: 18),
    _nav('complaints', tab: 21),
    _nav('archive', tab: 7),
    _nav('activity', tab: 8),
    _nav('dataio', tab: 9),
    _nav('deleted', tab: 10),
    _nav('waitlist', tab: 11),
    _nav('bulk', tab: 15),
  ];

  // Arabic-Indic → Western digit normalization for search input
  static String _normalizeInput(String q) {
    const indic = '٠١٢٣٤٥٦٧٨٩';
    var r = q;
    for (var i = 0; i < indic.length; i++) {
      r = r.replaceAll(indic[i], '$i');
    }
    return r;
  }

  void _onSearch(String q, AppProvider prov) {
    final normalized = _normalizeInput(q);
    if (normalized.isEmpty) {
      setState(() {
        _searching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchResults = prov.searchAll(normalized);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // لما الكيبورد يفتح: أخفي الهيدر الكبير عشان الشاشة تاخد كل المساحة
    // ومايحصلش overflow في أي بحث جوّه التابات.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFf5f7fa),
      drawer: _buildDrawer(context, prov),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // ── محتوى الرئيسية (زي ما هو من غير أي تغيير) ──
          final homeContent = Column(
            children: [
              if (!keyboardOpen)
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: constraints.maxHeight * 0.55),
                  child: SingleChildScrollView(child: _buildHeader(prov)),
                )
              else
                SizedBox(height: MediaQuery.of(context).padding.top),
              if (!prov.isOnline) _readOnlyBanner(),
              Expanded(child: _buildBody(prov)),
            ],
          );

          // ── من غير تابات مفتوحة: نفس الشكل القديم بالظبط ──
          final hasTabs = prov.workspaceTabs.isNotEmpty;
          final content = !hasTabs
              ? homeContent
              : Column(children: [
                  // شريط أزرق غامق خلف شريط حالة النظام (عشان الساعة تبان)
                  Container(
                      color: const Color(0xFF0D1B3E),
                      height: MediaQuery.of(context).padding.top),
                  const WorkspaceBar(),
                  // IndexedStack = كل التابات عايشة بحالتها في الذاكرة
                  Expanded(
                    child: IndexedStack(
                      index: prov.activeWorkspaceIndex
                          .clamp(0, prov.workspaceTabs.length),
                      children: [
                        // الرئيسية: نشيل حشوة شريط الحالة من هيدرها
                        // لأن الشريط الأزرق فوق غطّاها خلاص
                        MediaQuery.removePadding(
                            context: context,
                            removeTop: true,
                            child: homeContent),
                        for (final t in prov.workspaceTabs)
                          WorkspaceTabHost(key: ValueKey(t.id), tab: t),
                      ],
                    ),
                  ),
                ]);

          return Stack(
            children: [
              content,
              // 📝 فقاعة الملاحظات العائمة (تختفي مع الكيبورد عشان ماتغطيش الكتابة)
              if (!keyboardOpen) const NotesBubble(),
              // 🗂 زرار التنقّل السفلي — لوحة تنقّل سريعة بين التابات
              if (!keyboardOpen) const WorkspaceSwitcherButton(),
            ],
          );
        },
      ),
    );
  }

  // ─── READ-ONLY BANNER (offline) ─────────────────────────────
  Widget _readOnlyBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFb71c1c),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'وضع القراءة فقط — مفيش نت. فعّل الإنترنت لإجراء أي تعديل',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────
  Widget _buildHeader(AppProvider prov) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B3E), Color(0xFF1A237E)],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title + Action buttons ──
          Row(
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 36, height: 36,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 20),
                ),
              ),
              // 📌 لوحة النهاردة — بره صف الزراير المتزحلق عشان يفضل
              // باين دايماً. الرقم الأحمر = كام حاجة متأخرة عليك.
              _iconBtn(
                Icons.push_pin,
                badge: todayOverdueCount(prov),
                onTap: () => prov.openWorkspaceTab('today',
                    title: menuItemDef('today')?.title ?? 'لوحة النهاردة',
                    emoji: '📌'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _headerExpanded = !_headerExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '📡 باقات الاتصالات',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _headerExpanded ? 0 : 0.5,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.keyboard_arrow_up,
                            color: Colors.white54, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _headerBtn(
                        '+ مجموعة',
                        bg: Colors.white.withValues(alpha: 0.15),
                        border: true,
                        onTap: () {
                          if (!guardEdit(context)) return;
                          showModalBottomSheet(
                            useRootNavigator: true,
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.black54,
                            builder: (_) => const AddGroupModal(),
                          );
                        },
                      ),
                      const SizedBox(width: 5),
                      _headerBtn(
                        '+ عميل',
                        bg: Colors.white,
                        textColor: AppColors.blue2,
                        onTap: () {
                          if (!guardEdit(context)) return;
                          showModalBottomSheet(
                            useRootNavigator: true,
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.black54,
                            builder: (_) => const AddMemberModal(),
                          );
                        },
                      ),
                      const SizedBox(width: 5),
                      _iconBtn(Icons.search, onTap: () => _showGlobalSearch(prov)),
                      const SizedBox(width: 5),
                      _iconBtn(Icons.chat, color: AppColors.waGreen, onTap: () => _sendWAAll(prov)),
                      const SizedBox(width: 5),
                      _iconBtn(Icons.auto_awesome, color: AppColors.purple,
                          onTap: () => showModalBottomSheet(
                            useRootNavigator: true,
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.black54,
                            builder: (_) => const AiModal(),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ── Collapsible body ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _headerExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            secondChild: const SizedBox.shrink(),
            firstChild: Column(children: [
              const SizedBox(height: 14),
              // Owner info glass row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prov.ownerName,
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                        Text(prov.ownerPhone,
                            style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11),
                            textDirection: TextDirection.ltr),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final wp = prov.ownerPhone.replaceFirst(RegExp(r'^0'), '20');
                      final url = Uri.parse('https://wa.me/$wp');
                      if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.chat, color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                        Text('واتس', style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ]),
              ),
              // 2×2 glass stats grid — تظهر فقط في التابات المالية، وكلها أزرار تفاعلية
              if (_showFinancialStats) ...[
                const SizedBox(height: 10),
                Row(children: [
                  _glassStatCard('💰 ربح', prov.db.financialSummary['netProfit']!, const Color(0xFF69F0AE),
                      suffix: ' ج', onTap: () => setState(() => _tab = 4)),
                  const SizedBox(width: 8),
                  _glassStatCard('👥 عملاء', prov.db.members.length.toDouble(), const Color(0xFF40C4FF),
                      onTap: () => setState(() => _tab = 14)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _glassStatCard('🏘️ مجموعات', prov.db.groups.length.toDouble(), const Color(0xFFE040FB),
                      onTap: () => setState(() => _tab = 0)),
                  const SizedBox(width: 8),
                  _glassStatCard('📋 ديون', prov.db.totalDebt, const Color(0xFFFF6E40),
                      highlight: prov.db.totalDebt > 0, suffix: ' ج',
                      onTap: () => _showDebtorsList(prov)),
                ]),
                if (prov.db.totalBillsOwed > 0) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _tab = 22),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('🧾 فواتير عليك: ${prov.db.totalBillsOwed.toStringAsFixed(0)} ج',
                              style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                        const Icon(Icons.chevron_left, color: Colors.redAccent, size: 18),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _buildFinancialDashboard(prov),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _glassStatCard(String label, double value, Color accent,
      {bool highlight = false, String suffix = '', VoidCallback? onTap}) {
    final display = value == value.roundToDouble()
        ? '${value.toInt()}$suffix'
        : '${value.toStringAsFixed(0)}$suffix';
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: highlight
                ? accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.cairo(
                          color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (onTap != null)
                  const Icon(Icons.touch_app, color: Colors.white24, size: 13),
              ]),
              const SizedBox(height: 4),
              Text(display,
                  style: GoogleFonts.cairo(
                      color: accent, fontSize: 20, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialDashboard(AppProvider prov) {
    final s = prov.db.financialSummary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          collapsedBackgroundColor: Colors.white.withValues(alpha: 0.08),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          title: Text('📊 الملخص المالي',
              style: GoogleFonts.cairo(
                  fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white70)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(children: [
                Row(children: [
                  _glassFinCard('ليا كام', s['receivables']!, const Color(0xFF69F0AE)),
                  const SizedBox(width: 8),
                  _glassFinCard('عليا كام', s['payables']!, const Color(0xFFFF6E40)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _glassFinCard('الفرق مع التجار', s['difference']!,
                      s['difference']! >= 0 ? const Color(0xFFB0BEC5) : const Color(0xFFFF6E40)),
                  const SizedBox(width: 8),
                  _glassFinCard('صافي الربح', s['netProfit']!, const Color(0xFF40C4FF)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _glassFinCard('💰 ربح الفواتير', prov.db.totalBillingProfit, const Color(0xFFE040FB)),
                  const SizedBox(width: 8),
                  _glassFinCard('📥 دخل شهري', prov.db.totalMonthlyIncome, const Color(0xFFFFD740)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassFinCard(String label, double value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.cairo(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('${value.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: accent),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // ─── قائمة المديونين (تظهر عند الضغط على بطاقة «ديون») ──────────
  void _showDebtorsList(AppProvider prov) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) {
        // كل العملاء عليهم مديونية (رصيد سالب) مرتبين تنازلياً بالأكبر
        final debtors = prov.db.members.where((m) => m.balance < 0).toList()
          ..sort((a, b) => a.balance.compareTo(b.balance));
        final total = debtors.fold<double>(0, (s, m) => s + (-m.balance));
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Color(0xFFf5f7fa),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Center(
              child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                const Text('📋', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('المديونون (${debtors.length})',
                      style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(10)),
                  child: Text('${total.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.red2)),
                ),
              ]),
            ),
            const Divider(height: 1),
            Flexible(
              child: debtors.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🎉', style: TextStyle(fontSize: 42)),
                        const SizedBox(height: 10),
                        Text('مفيش مديونيات — كله سداد!',
                            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.muted)),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      itemCount: debtors.length,
                      itemBuilder: (_, i) {
                        final m = debtors[i];
                        final g = prov.db.groups.firstWhere((x) => x.id == m.gid,
                            orElse: () => prov.db.groups.isNotEmpty ? prov.db.groups.first : Group(id: '', phone: ''));
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet(
                              useRootNavigator: true,
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              barrierColor: Colors.black54,
                              builder: (_) => MemberDrawer(member: m, group: g, parentContext: context),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(m.name,
                                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
                                      overflow: TextOverflow.ellipsis),
                                  Text('${m.phone}  •  📡 ${g.phone}',
                                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                                      textDirection: TextDirection.ltr),
                                ]),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(9)),
                                child: Text('${(-m.balance).toStringAsFixed(0)} ج',
                                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.red2)),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }

  Widget _iconBtn(IconData icon,
      {Color color = Colors.white,
      required VoidCallback onTap,
      int badge = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color == Colors.white
                ? Colors.white.withValues(alpha: 0.25)
                : color,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        if (badge > 0)
          Positioned(
            top: -2,
            left: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.red2,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Text(badge > 99 ? '99+' : '$badge',
                  style: GoogleFonts.cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ),
      ]),
    );
  }

  Widget _headerBtn(
    String label, {
    required Color bg,
    Color textColor = Colors.white,
    bool border = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: border
              ? Border.all(color: Colors.white.withValues(alpha: 0.5))
              : null,
          boxShadow: border
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8)
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ─── NAV ────────────────────────────────────────────────────
  // ─── SIDE DRAWER (القائمة الجانبية) ──────────────────────────
  Widget _buildDrawer(BuildContext ctx, AppProvider prov) {
    // كل بنود التنقّل: تابات الشاشة الرئيسية + الشاشات اللي بتفتح في تابات
    // مساحة عمل ('ws'). الترتيب والأقسام والإخفاء كلهم من الـ Provider.
    final navItems = <Map<String, dynamic>>[
      ..._tabs,
      ..._moreTabs,
      {..._nav('filter'), 'ws': 'filter'},
      {..._nav('assets'), 'ws': 'assets'},
    ];
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              18, MediaQuery.of(context).padding.top + 20, 18, 18),
          decoration: BoxDecoration(gradient: AppColors.headerGradient),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.satellite_alt, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('📡 باقات الاتصالات',
                      style: GoogleFonts.cairo(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis),
                  Text(prov.ownerName,
                      style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            // ── هوية المستخدم الحالي: مالك ولا موظف + الاسم ──
            _identityBadge(prov),
          ]),
        ),
        // 🔍 بحث في القايمة — تكتب حرفين تلاقي الشاشة على طول
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _menuSearchCtrl,
            onChanged: (v) => setState(() => _menuQuery = v),
            style: GoogleFonts.cairo(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'دوّر على شاشة…',
              hintStyle:
                  GoogleFonts.cairo(fontSize: 12.5, color: AppColors.muted),
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: _menuQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 17),
                      onPressed: () => setState(() {
                        _menuSearchCtrl.clear();
                        _menuQuery = '';
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
        ),
        // Sections list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (_menuQuery.trim().isNotEmpty)
                ..._drawerSearchResults(ctx, prov, navItems)
              else
                ..._drawerSectioned(ctx, prov, navItems),
              const Divider(height: 16),
              // 🔀 ترتيب القايمة — أقسام + سحب وإفلات + إخفاء (مفيش أي حذف)
              _drawerItem('🔀 ترتيب القايمة', () {
                Navigator.pop(context);
                showMenuOrderEditor(ctx);
              }),
              // 💾 حفظ البيانات + 🖨️ طباعة — اتنقلوا هنا من الشاشة الرئيسية
              _drawerItem('💾 حفظ البيانات', () {
                Navigator.pop(context);
                _showSaveOptions();
              }),
              _drawerItem('🖨️ طباعة المجموعات', () {
                Navigator.pop(context);
                _printGroups(prov);
              }),
              // ملحوظة: «لوحة الأصول» و«تصنيف العملاء» بقوا جوه الأقسام فوق
              // (قسم 💵 الفلوس و 👥 العملاء) — فمشيلناهم من هنا عشان ما يتكرروش.
              _drawerItem('🗂 دليل الخطوط الرئيسية', () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupFoldersScreen()),
                );
              }),
              _drawerItem('🔁 حسابات الفوترة', () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillingAccountsScreen()),
                );
              }),
              // إدارة الموظفين — للمالك فقط
              if (!SupabaseService.isEmployee)
                _drawerItem('👥 إدارة الموظفين', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmployeesScreen()),
                  );
                }),
              _drawerItem('⚙️ الإعدادات', () {
                Navigator.pop(context);
                showDialog(
                    context: context,
                    builder: (_) => SettingsModal(
                          onRenew: () => _showBillingMenu(prov),
                        ));
              }),
            ],
          ),
        ),
        // ── تسجيل الخروج ──
        const Divider(height: 1),
        InkWell(
          onTap: () {
            Navigator.pop(context); // اقفل الـ drawer
            _confirmLogout(prov);
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                18, 14, 18, MediaQuery.of(context).padding.bottom + 14),
            child: Row(children: [
              Icon(Icons.logout, size: 18, color: AppColors.red),
              const SizedBox(width: 10),
              Text('تسجيل الخروج',
                  style: GoogleFonts.cairo(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.red)),
            ]),
          ),
        ),
      ]),
    );
  }

  /// شارة هوية المستخدم الحالي داخل هيدر الـ drawer.
  Widget _identityBadge(AppProvider prov) {
    final isEmp = SupabaseService.isEmployee;
    final role  = isEmp ? '👤 موظف' : '👑 المالك';
    final name  = isEmp
        ? (SupabaseService.employeeName?.trim().isNotEmpty == true
            ? SupabaseService.employeeName!.trim()
            : 'موظف')
        : (prov.ownerName.trim().isNotEmpty
            ? prov.ownerName.trim()
            : (SupabaseService.userEmail ?? 'المالك'));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(role,
              style: GoogleFonts.cairo(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              style: GoogleFonts.cairo(
                  color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  /// تسجيل الخروج — يأكّد أولاً، وبعدها يمسح الجلسة. الـ AuthGate بيرجّع لشاشة الدخول.
  void _confirmLogout(AppProvider prov) {
    final isEmp = SupabaseService.isEmployee;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسجيل الخروج',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text(
          isEmp
              ? 'هتسجّل خروج من حساب الموظف. هتحتاج كود المحل واسمك والكود السري عشان تدخل تاني.'
              : 'هتسجّل خروج من حسابك. تقدر تدخل تاني ببريدك وكلمة السر.',
          style: GoogleFonts.cairo(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx); // اقفل الديالوج
              // للموظف: امسح بيانات المحل من الذاكرة فوراً (خصوصية)
              if (SupabaseService.isEmployee) prov.wipeInMemoryData();
              await SupabaseService.signOut();
              // الـ _AuthGate بيسمع حدث signedOut ويرجّع لشاشة الدخول تلقائياً.
            },
            child: Text('خروج', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(String label, VoidCallback onTap,
      {bool selected = false, VoidCallback? onLongPress, double indent = 18}) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? AppColors.blueLight : Colors.transparent,
        padding: EdgeInsets.fromLTRB(18, 13, indent, 13),
        child: Row(children: [
          if (selected)
            Container(
              width: 3, height: 22,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.blue2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? AppColors.blue2 : AppColors.text)),
          ),
          Icon(Icons.arrow_back_ios,
              size: 13,
              color: selected ? AppColors.blue2 : AppColors.muted),
        ]),
      ),
    );
  }

  // ─── 📂 بنود القايمة الجانبية: أقسام + بحث + دوسة مطوّلة ──────────
  /// دوسة عادية: بتفتح الشاشة مكان الحالية (أو في تاب لو `ws`).
  /// دوسة مطوّلة: بتفتحها في **تاب جديد** من غير ما تسيب اللي انت فيه.
  Widget _drawerNavItem(
      BuildContext ctx, AppProvider prov, Map<String, dynamic> s,
      {bool inSection = true}) {
    final key = s['key'] as String;
    final ws = s['ws'] as String?;
    // 'groups' و 'reminders' مالهمش مفتاح 'tab' — تابهم ثابت بالمفتاح مش
    // بمكانهم في القايمة (الترتيب بقى متغيّر).
    final tabIndex = s['tab'] as int? ?? (key == 'reminders' ? 1 : 0);
    // مفتاح مساحة العمل: القايمة بتسمّي الفواتير 'billing' والسجل 'invoices'
    final wsType = ws ?? AppProvider.menuKeyAlias(key);
    final canOpenTab = kWorkspaceScreens.containsKey(wsType);

    return _drawerItem(
      '${s['icon']} ${s['label']}',
      () {
        Navigator.pop(ctx);
        if (ws != null) {
          prov.openWorkspaceTab(ws,
              title: s['label'] as String, emoji: s['icon'] as String);
        } else {
          setState(() {
            _tab = tabIndex;
            _searching = false;
            _searchResults = [];
          });
        }
      },
      selected: ws == null && _tab == tabIndex,
      indent: inSection ? 30 : 18,
      onLongPress: !canOpenTab
          ? null
          : () {
              Navigator.pop(ctx);
              prov.openWorkspaceTab(wsType,
                  title: s['label'] as String, emoji: s['icon'] as String);
            },
    );
  }

  List<Widget> _drawerSectioned(
      BuildContext ctx, AppProvider prov, List<Map<String, dynamic>> items) {
    final out = <Widget>[];
    for (final sec in prov.orderedMenuSections) {
      final inSec =
          prov.menuItemsOfSection(items, (s) => s['key'] as String, sec.id);
      if (inSec.isEmpty) continue; // قسم كل بنوده مخفية → ما يظهرش أصلاً
      final collapsed = prov.isMenuSectionCollapsed(sec.id);
      final color = Color(sec.color);
      out.add(InkWell(
        onTap: () => prov.toggleMenuSection(sec.id),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border(right: BorderSide(color: color, width: 3.5)),
          ),
          child: Row(children: [
            Text(sec.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(sec.title,
                  style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: color)),
            ),
            Text('${inSec.length}',
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
            const SizedBox(width: 4),
            Icon(collapsed ? Icons.expand_more : Icons.expand_less,
                size: 20, color: color),
          ]),
        ),
      ));
      if (!collapsed) {
        out.addAll([for (final s in inSec) _drawerNavItem(ctx, prov, s)]);
      }
    }
    return out;
  }

  List<Widget> _drawerSearchResults(
      BuildContext ctx, AppProvider prov, List<Map<String, dynamic>> items) {
    final q = normalizeArabic(_menuQuery);
    // البحث بيلاقي المخفي كمان — الإخفاء بيشيله من العرض مش من البرنامج.
    final hits = prov
        .applyMenuOrder(items, (s) => s['key'] as String, dropHidden: false)
        .where((s) => normalizeArabic(s['label'] as String).contains(q))
        .toList();
    if (hits.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('مفيش شاشة بالاسم ده',
                style:
                    GoogleFonts.cairo(fontSize: 12.5, color: AppColors.muted)),
          ),
        )
      ];
    }
    return [
      for (final s in hits) _drawerNavItem(ctx, prov, s, inSection: false)
    ];
  }

  // ─── BODY ────────────────────────────────────────────────────
  Widget _buildBody(AppProvider prov) {
    switch (_tab) {
      // ── Main tabs ──
      case 0:
        return _buildGroupsSection(prov);
      case 1:
        return const RemindersScreen();
      case 2:
        return const GuarantorsScreen();
      case 3:
        return const WorkNumsScreen();
      case 4:
        return const ProfitScreen();
      case 5:
        return const RentalsScreen();
      case 6:
        return const GiftsScreen();
      case 12:
        return const GuestsScreen();
      // ── "المزيد" tabs ──
      case 7:
        return const ArchiveScreen();
      case 8:
        return const ActivityScreen();
      case 9:
        return const DataIOScreen();
      case 10:
        return const DeletedScreen();
      case 11:
        return const WaitlistScreen();
      case 13:
        return const MainLinesScreen();
      case 14:
        return const ConsolidatedScreen();
      case 15:
        return const BulkMessageScreen();
      case 16:
        return const FlaggedMembersScreen();
      case 17:
        return const BillsScreen();
      case 18:
        return const NotesScreen();
      case 19:
        return const CompanyInvoicesScreen();
      case 21:
        return const ComplaintsScreen();
      case 22:
        return const UnifiedBillingScreen();
      default:
        return _buildGroupsSection(prov);
    }
  }

  void _printGroups(AppProvider prov) {
    final rows = prov.db.groups.map((g) {
      final members = prov.db.membersOf(g.id);
      final debt = prov.db.groupDebt(g.id);
      return [
        g.phone,
        g.ownerName ?? '-',
        '${members.length} عميل',
        '${prov.db.groupUsedGb(g.id)} GB',
        '${debt.toStringAsFixed(0)} ج',
      ];
    }).toList();
    PrintHelper.printTable(
      context: context,
      title: 'قائمة المجموعات',
      subtitle: 'إجمالي: ${rows.length} مجموعة',
      headers: ['الرقم', 'المالك', 'العملاء', 'الجيجا المستخدمة', 'المديونية'],
      rows: rows,
    );
  }

  // ─── GROUPS SECTION ──────────────────────────────────────────
  Widget _buildGroupsSection(AppProvider prov) {
    return Column(
      children: [
        // Search + buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              // Search + زرار تصنيف العملاء
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => _onSearch(v, prov),
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: '🔍 بحث بالاسم أو الرقم أو الباقة أو المبلغ...',
                      hintStyle:
                          GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: AppColors.blue, width: 1.5),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearch('', prov);
                              })
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 🎛️ بحث متقدّم: باقات / دفع / شهر اشتراك / نوع
                // بيتفتح في تاب علوي — فلترك بيفضل محفوظ وانت بتنقّل
                GestureDetector(
                  onTap: () => prov.openWorkspaceTab('filter',
                      title: menuItemDef('filter')?.title ?? 'بحث متقدّم',
                      emoji: menuItemDef('filter')?.emoji ?? '🎛️'),
                  child: Container(
                    height: 44, width: 44,
                    decoration: BoxDecoration(
                      color: AppColors.blue2,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: AppColors.blue2.withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.tune, size: 22, color: Colors.white),
                  ),
                ),
              ]),
              // ملاحظة: «تجديد الاشتراكات» اتنقل للإعدادات، و«حفظ البيانات»
              // و«طباعة المجموعات» اتنقلوا للقائمة الجانبية — لتنضيف الشاشة.
            ],
          ),
        ),
        // شريط ترتيب الخطوط (مبيظهرش وانت بتدوّر)
        if (!_searching) _buildSortBar(),
        // 🏢 فلتر الشركة السريع
        if (!_searching) ...[
          const SizedBox(height: 6),
          _buildProviderFilterBar(prov),
        ],
        // الموظف: تبديل بين «شغلي» و«القائمة العامة»
        if (SupabaseService.isEmployee && !_searching) _buildEmpViewToggle(prov),
        // Content
        Expanded(
          child:
              _searching ? _buildSearchResults(prov) : _buildGroupsList(prov),
        ),
      ],
    );
  }

  Widget _buildEmpViewToggle(AppProvider prov) {
    final mine = prov.visibleGroups.length;
    final all = prov.db.groups.length;
    Widget btn(bool all_, String label, int count) {
      final sel = _empViewAll == all_;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _empViewAll = all_),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.blue2 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? AppColors.blue2 : AppColors.border, width: 1.5),
            ),
            child: Text('$label ($count)',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : AppColors.text)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(children: [
        btn(false, '👤 شغلي', mine),
        btn(true, '🌐 القائمة العامة', all),
      ]),
    );
  }

  Widget _buildSearchResults(AppProvider prov) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text('لا توجد نتائج',
            style: GoogleFonts.cairo(color: AppColors.muted)),
      );
    }
    const typeIcon  = {'member':'👤','group':'📡','waitlist':'⏳','worknum':'📋','guarantor':'🤝'};
    const typeLabel = {'member':'عميل','group':'مجموعة','waitlist':'انتظار','worknum':'رقم عمل','guarantor':'كفيل'};
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) {
        final r       = _searchResults[i];
        final type    = r['type']     as String;
        final positive= (r['positive'] as bool?) ?? false;
        final extra   = (r['extra']   as String?) ?? '';
        return GestureDetector(
          onTap: () => _handleSearchResult(r, prov),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: AppColors.blue2.withValues(alpha: 0.05), blurRadius: 6)],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${typeIcon[type] ?? '🔍'} ${typeLabel[type] ?? type}',
                  style: GoogleFonts.cairo(
                      fontSize: 10, color: AppColors.blue2,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(r['label'] as String,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(r['subtitle'] as String,
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppColors.muted)),
                ]),
              ),
              if (extra.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: positive ? AppColors.greenLight : AppColors.redLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(extra,
                      style: GoogleFonts.cairo(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: positive ? AppColors.green : AppColors.red2)),
                ),
              // للعميل: زرار يفتح مجموعته مباشرة (من غير ما يفتح كارت العميل)
              if (type == 'member' && (r['gid'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _goToGroup(r['gid'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.blueMid),
                    ),
                    child: const Text('📡', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.muted),
            ]),
          ),
        );
      },
    );
  }

  // ─── 🏢 شريط فلتر الشركة (ضغطة واحدة) ──────────────────────────
  Widget _buildProviderFilterBar(AppProvider prov) {
    final showAll = !SupabaseService.isEmployee || _empViewAll;
    final src = showAll ? prov.db.groups : prov.visibleGroups;
    final counts = <String, int>{};
    for (final g in src) {
      final p = g.provider;
      if (p != null) counts[p] = (counts[p] ?? 0) + 1;
    }
    // شركة واحدة بس؟ الفلتر مالوش لازمة — نخفيه بدل ما ياخد مساحة.
    final present = _provOrder.where((p) => (counts[p] ?? 0) > 0).toList();
    if (present.length < 2) return const SizedBox.shrink();

    Widget chip(String? p) {
      final active = _provFilter == p;
      final c = p == null ? AppColors.blue2 : _provColors[p]!;
      final label = p == null ? 'الكل' : _provShort[p]!;
      final n = p == null ? src.length : counts[p]!;
      return GestureDetector(
        onTap: () => _setProvFilter(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active ? c : c.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: active ? Colors.white : c)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.28)
                    : c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$n',
                  style: GoogleFonts.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: active ? Colors.white : c)),
            ),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          chip(null),
          for (final p in present) ...[const SizedBox(width: 6), chip(p)],
        ],
      ),
    );
  }

  // ─── شريط ترتيب الخطوط ─────────────────────────────────────────
  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _sortModes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final m = _sortModes[i];
                final active = _groupSort == m['key'];
                return GestureDetector(
                  onTap: () => _setSortMode(m['key']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.blue2 : Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                          color: active ? AppColors.blue2 : AppColors.border,
                          width: 1.5),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color:
                                      AppColors.blue2.withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : null,
                    ),
                    child: Text(
                      m['label']!,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                        color: active ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_groupSort != 'manual' || _provFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text(
                  _provFilter != null && _groupSort == 'manual'
                      ? '✋ السحب متوقف — شيل فلتر الشركة عشان ترتّب بإيدك'
                      : '✋ السحب متوقف — ارجع لـ«يدوي» عشان ترتّب الخطوط بإيدك',
                  style: GoogleFonts.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted)),
            ),
        ],
      ),
    );
  }

  /// بيرجّع الخطوط مرتّبة حسب الوضع المختار — من غير ما يمسّ الترتيب المحفوظ
  List<Group> _sortedGroups(AppProvider prov, List<Group> src) {
    if (_groupSort == 'manual') return src;
    final list = List<Group>.from(src);

    switch (_groupSort) {
      // 📆 الأقرب لميعاد الإلغاء الأول، بعدهم اللي فات ميعاده، وآخر حاجة
      // الخطوط اللي مالهاش تاريخ إلغاء أصلاً
      case 'cancel':
        int rank(Group g) {
          final d = g.daysUntilCancelDeadline;
          if (d == null) return 1000000;
          if (d < 0) return 500000 - d;
          return d;
        }
        list.sort((a, b) {
          final c = rank(a).compareTo(rank(b));
          return c != 0 ? c : a.phone.compareTo(b.phone);
        });

      // 🔤 بالاسم (اسم صاحب الخط، وإلا اسم الفاتورة، وإلا الرقم)
      case 'name':
        String key(Group g) {
          final o = g.ownerName?.trim();
          if (o != null && o.isNotEmpty) return o;
          final inv = g.groupInvoiceName?.trim();
          if (inv != null && inv.isNotEmpty) return inv;
          return g.phone;
        }
        list.sort((a, b) => key(a).compareTo(key(b)));

      // 🔁 خطوط الحساب الواحد ورا بعض — بترتيب الحساب ثم الشق A ثم B
      case 'account':
        final keys = <String, List<int>>{};
        for (var i = 0; i < prov.billingAccounts.length; i++) {
          final acc = prov.billingAccounts[i];
          for (var j = 0; j < acc.shiftA.length; j++) {
            keys[acc.shiftA[j]] = [i, 0, j];
          }
          for (var j = 0; j < acc.shiftB.length; j++) {
            keys[acc.shiftB[j]] = [i, 1, j];
          }
        }
        // الخطوط اللي مش في أي حساب تنزل الآخر
        List<int> key(Group g) => keys[g.id] ?? const [999999, 0, 0];
        list.sort((a, b) {
          final ka = key(a), kb = key(b);
          for (var i = 0; i < 3; i++) {
            final c = ka[i].compareTo(kb[i]);
            if (c != 0) return c;
          }
          return a.phone.compareTo(b.phone);
        });

      // 🏢 حسب الشركة
      case 'provider':
        const order = {'vodafone': 0, 'etisalat': 1, 'orange': 2, 'we': 3};
        list.sort((a, b) {
          final c =
              (order[a.provider] ?? 9).compareTo(order[b.provider] ?? 9);
          return c != 0 ? c : a.phone.compareTo(b.phone);
        });

      // 📅 حسب سيكل الفوترة
      case 'cycle':
        const order = {
          'day1': 0,
          'day4': 1,
          'mid': 2,
          'cycle1': 3,
          'cycle2': 4
        };
        list.sort((a, b) {
          final c =
              (order[a.billingCycle] ?? 9).compareTo(order[b.billingCycle] ?? 9);
          return c != 0 ? c : a.phone.compareTo(b.phone);
        });

      // 📦 حسب الباقة — الفاتورة الكبيرة الأول (4250 ← 2150 ← الأصغر)
      case 'package':
        double amount(Group g) {
          if (g.tier == 'tier1_4250') return 4250;
          if (g.tier == 'tier2_smaller') return 2150;
          if (g.fixedBillAmount > 0) return g.fixedBillAmount;
          return g.actualBillAmount ?? 0;
        }
        list.sort((a, b) {
          final c = amount(b).compareTo(amount(a));
          return c != 0 ? c : a.phone.compareTo(b.phone);
        });
    }
    return list;
  }

  Widget _buildGroupsList(AppProvider prov) {
    // الموالك يشوف الكل؛ الموظف: «شغلي» = الموكلة، «القائمة العامة» = الكل
    final showAll = !SupabaseService.isEmployee || _empViewAll;
    var src = showAll ? prov.db.groups : prov.visibleGroups;
    // 🏢 فلتر الشركة
    if (_provFilter != null) {
      src = src.where((g) => g.provider == _provFilter).toList();
    }
    final groups = _sortedGroups(prov, src);
    if (groups.isEmpty && _provFilter != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏢', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text('مفيش خطوط ${_provShort[_provFilter]} هنا',
                style: GoogleFonts.cairo(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _setProvFilter(null),
              child: Text('اعرض الكل',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }
    if (groups.isEmpty) {
      final isEmp = SupabaseService.isEmployee;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              isEmp ? 'لا توجد مجموعات موكلة لك بعد' : 'لا توجد مجموعات بعد',
              style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              isEmp
                  ? 'صاحب المحل لسه ما عيّنلكش مجموعات تتابعها'
                  : 'اضغط + مجموعة لإضافة خط رئيسي',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    // الموظف: قائمة عادية (مفيش إعادة ترتيب على مجموعات مش بتاعته)
    // وكمان: السحب بيتقفل في أي وضع ترتيب غير «يدوي» عشان مايبوّظش
    // الترتيب المحفوظ (لأن الـ indexes ساعتها مش بتاعة الترتيب الأصلي)
    // ⚠️ السحب بيشتغل بأرقام الترتيب في القايمة الكاملة — فلازم يتقفل لو
    // في فلتر شركة شغّال، وإلا الترتيب المحفوظ هيتبوّظ.
    final canReorder = !SupabaseService.isEmployee &&
        _groupSort == 'manual' &&
        _provFilter == null;
    return ReorderableListView.builder(
      scrollController: _groupsScrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: groups.length,
      buildDefaultDragHandles: canReorder,
      onReorder: (oldIndex, newIndex) {
        if (canReorder) prov.reorderGroups(oldIndex, newIndex);
      },
      itemBuilder: (_, i) {
        final key = _groupKeys[groups[i].id] ??= GlobalKey();
        return GroupCard(
          key: key,
          group: groups[i],
          initiallyMembersExpanded: groups[i].id == _focusExpandGid,
        );
      },
    );
  }

  /// يروح لتاب المجموعات ويمرّر الشاشة لكارت مجموعة معيّنة (بعد البحث).
  void _goToGroup(String gid) {
    setState(() {
      _tab = 0;
      _searching = false;
      _searchResults = [];
      _searchCtrl.clear();
      _focusExpandGid = gid; // تتفتح تلقائياً
    });
    // بعد ما القائمة تتبني، مرّر لكارت المجموعة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _groupKeys[gid]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.05);
      }
    });
  }

  // ─── GLOBAL SEARCH ───────────────────────────────────────────
  void _showGlobalSearch(AppProvider prov) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
              barrierColor: Colors.black54,
      builder: (_) => _GlobalSearchSheet(
        prov: prov,
        onSelect: (result) => _handleSearchResult(result, prov, fromModal: true),
      ),
    );
  }

  Future<void> _handleSearchResult(
      Map<String, dynamic> result, AppProvider prov,
      {bool fromModal = false}) async {
    if (fromModal) {
      Navigator.pop(context); // close the search bottom sheet
      // لو كنت واقف في تاب مساحة عمل، ارجع للرئيسية الأول — وإلا النتيجة
      // هتتفتح تحت التاب وانت مش شايفها.
      prov.activateWorkspaceTab(0);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
    } else {
      // Inline search — just clear results, no pop needed
      setState(() {
        _searching = false;
        _searchResults = [];
        _searchCtrl.clear();
      });
    }

    final type = result['type'] as String;

    switch (type) {
      case 'member':
        final mid = result['id'] as String;
        final gid = result['gid'] as String? ?? '';
        final member = prov.db.members
            .firstWhere((m) => m.id == mid, orElse: () => prov.db.members.first);
        final group = prov.db.groups
            .firstWhere((g) => g.id == gid, orElse: () => prov.db.groups.first);
        // يروح لمجموعة العميل ويمرّر لها — فلمّا يقفل كارت العميل يلاقي
        // مجموعته قدامه (الرجوع بيوديه للمجموعة).
        _goToGroup(gid);
        showModalBottomSheet(useRootNavigator: true,
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black54,
          builder: (_) => MemberDrawer(member: member, group: group, parentContext: context),
        );
        break;

      case 'group':
        _goToGroup(result['id'] as String? ?? result['gid'] as String? ?? '');
        break;

      case 'waitlist':
        setState(() => _tab = 11);
        break;

      case 'worknum':
        setState(() => _tab = 3);
        break;

      case 'guarantor':
        setState(() => _tab = 2);
        break;

      default:
        final tab = result['tab'] as int? ?? 0;
        setState(() => _tab = tab);
    }
  }

  // ─── ACTIONS ─────────────────────────────────────────────────
  void _showBillingMenu(AppProvider prov) {
    final options = [
      ('cycle1', '📅 إضافة سايكل 1 فقط',  'خطوط سيكل 1 (أول الشهر)'),
      ('cycle2', '📅 إضافة سايكل 2 فقط',  'خطوط سيكل 2 (منتصف الشهر)'),
      ('cycle4', '📅 إضافة سايكل 4 فقط',  'خطوط يوم 4'),
      ('all',    '📅 إضافة شهر للجميع',   'كل الخطوط بدون استثناء'),
    ];

    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
              barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(ctx).viewPadding.bottom),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('تجديد الاشتراكات',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('اختر نوع السايكل المراد تجديده',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 14),
              ...options.map((opt) {
                final key      = opt.$1;
                final label    = opt.$2;
                final subtitle = opt.$3;
                final locked   = prov.isCycleLocked(key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: locked ? null : () {
                      Navigator.pop(ctx);
                      _confirmCycleBilling(prov, key, label);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: locked ? const Color(0xFFf0fdf4) : const Color(0xFFf5f7fa),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: locked ? const Color(0xFF86efac) : AppColors.border,
                          width: locked ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(label,
                                style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: locked ? const Color(0xFF15803d) : AppColors.text)),
                            Text(subtitle,
                                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                          ]),
                        ),
                        if (locked)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle, color: Color(0xFF16a34a), size: 18),
                            const SizedBox(width: 4),
                            Text('تم هذا الشهر',
                                style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF15803d), fontWeight: FontWeight.w700)),
                          ])
                        else
                          Icon(Icons.chevron_left, color: AppColors.muted, size: 20),
                        const SizedBox(width: 6),
                        // زرار حذف اشتراك هذا الشهر للسايكل (لو اتضاف بالغلط)
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _confirmUndoCycle(prov, key, label);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF9A9A)),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Color(0xFFD32F2F), size: 18),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              const Divider(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _showBulkPriceDialog(prov);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(children: [
                    const Text('📈', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('رفع أسعار الاشتراكات',
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE65100))),
                        Text('زوّد سعر كل العملاء دفعة واحدة (بمبلغ أو نسبة)',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                      ]),
                    ),
                    const Icon(Icons.chevron_left, color: Color(0xFFE65100), size: 20),
                  ]),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _showBulkPriceDialog(AppProvider prov) {
    final amountCtrl = TextEditingController();
    bool isPercent = false;
    bool skipZero = true;
    String? gid; // null = كل العملاء

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            final affected = prov.previewBulkPriceCount(gid: gid, skipZero: skipZero);
            final val = double.tryParse(amountCtrl.text.trim()) ?? 0;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text('📈 رفع أسعار الاشتراكات',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // نوع الزيادة
                  Text('نوع الزيادة', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setS(() => isPercent = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: !isPercent ? const Color(0xFFE65100) : const Color(0xFFf0f4f8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('💵 مبلغ ثابت',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700,
                                color: !isPercent ? Colors.white : AppColors.muted)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: GestureDetector(
                      onTap: () => setS(() => isPercent = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isPercent ? const Color(0xFFE65100) : const Color(0xFFf0f4f8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('٪ نسبة مئوية',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700,
                                color: isPercent ? Colors.white : AppColors.muted)),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setS(() {}),
                    decoration: InputDecoration(
                      labelText: isPercent ? 'نسبة الزيادة (%)' : 'مبلغ الزيادة لكل عميل (ج)',
                      labelStyle: GoogleFonts.cairo(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // نطاق التطبيق
                  Text('على مين يتطبّق؟', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    initialValue: gid,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      DropdownMenuItem<String?>(value: null,
                          child: Text('👥 كل العملاء', style: GoogleFonts.cairo(fontSize: 13))),
                      ...prov.db.groups.map((g) => DropdownMenuItem<String?>(
                            value: g.id,
                            child: Text('📱 ${g.phone}', style: GoogleFonts.cairo(fontSize: 13), textDirection: TextDirection.ltr),
                          )),
                    ],
                    onChanged: (v) => setS(() => gid = v),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setS(() => skipZero = !skipZero),
                    child: Row(children: [
                      Icon(skipZero ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 20, color: const Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('تجاهل العملاء سعرهم صفر (هدايا/مجاني)',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.text))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'هيتأثر $affected عميل'
                      '${val > 0 ? (isPercent ? '\nمثال: 200 ج → ${(200 * (1 + val / 100)).round()} ج' : '\nمثال: 200 ج → ${(200 + val).round()} ج') : ''}',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blue2),
                    ),
                  ),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: val <= 0
                      ? null
                      : () {
                          final n = prov.bulkAdjustPrices(value: val, isPercent: isPercent, gid: gid, skipZero: skipZero);
                          Navigator.pop(context);
                          AppSnackbar.show(context, '✅ تم تعديل أسعار $n عميل');
                        },
                  child: Text('تطبيق الزيادة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// يطلب الرقم السري قبل تنفيذ عملية حساسة (تجديد/حذف اشتراكات).
  /// بينفّذ onOk بس لو الرقم صح. ده بيمنع أي لخبطة في فلوس العملاء.
  void _requirePin(AppProvider prov, String title, VoidCallback onOk) {
    final ctrl = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(Icons.lock_outline, color: AppColors.blue2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('اكتب الرقم السري للتأكيد — عملية حسّاسة تخص فلوس العملاء.',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'الرقم السري',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  errorText: error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue2),
                onPressed: () {
                  if (ctrl.text.trim() == prov.pin) {
                    Navigator.pop(ctx);
                    onOk();
                  } else {
                    setS(() => error = 'الرقم السري غلط');
                  }
                },
                child: Text('تأكيد',
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmUndoCycle(AppProvider prov, String cycleKey, String label) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.delete_outline, color: Color(0xFFD32F2F)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('حذف اشتراك هذا الشهر',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ]),
          content: Text(
              'هيتم حذف اشتراك الشهر الحالي لـ «$label» عن كل العملاء وإرجاع الرصيد. تستخدمه لو نزلت فاتورة بالغلط أو اتكررت. متأكد؟',
              style: GoogleFonts.cairo(fontSize: 13, height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _requirePin(prov, '🔒 تأكيد حذف الاشتراكات', () {
                  final (count, total) =
                      prov.undoCycleBillingThisMonth(cycleKey);
                  AppSnackbar.show(context,
                      count == 0
                          ? 'مفيش اشتراكات لهذا الشهر تتحذف'
                          : '🗑️ اتحذف $count اشتراك (${total.toStringAsFixed(0)} ج) ورجع الرصيد');
                });
              },
              child: Text('احذف',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCycleBilling(AppProvider prov, String cycleKey, String label) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: Text(
          'سيتم إضافة اشتراك هذا الشهر للخطوط المحددة. هل أنت متأكد؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requirePin(prov, '🔒 تأكيد تجديد الاشتراك', () {
                prov.addMonthBillingForCycle(cycleKey);
                AppSnackbar.show(context, '✅ تمت إضافة الاشتراك');
              });
            },
            child: Text('تأكيد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSaveOptions() {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
              barrierColor: Colors.black54,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),
            Text('💾 حفظ البيانات',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.blue2)),
            const SizedBox(height: 16),
            _saveOption('📤', 'تصدير JSON', 'نسخة احتياطية كاملة', () {
              Navigator.pop(context);
              setState(() => _tab = 9);
            }),
            _saveOption('📊', 'تصدير Excel', 'ملف Excel بكل البيانات', () {
              Navigator.pop(context);
              setState(() => _tab = 9);
            }),
            _saveOption('🖨️', 'تصدير PDF', 'طباعة تقرير', () {
              Navigator.pop(context);
              setState(() => _tab = 9);
            }),
          ],
        ),
      ),
    );
  }

  Widget _saveOption(
      String icon, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900,
                        color: AppColors.blue2,
                        fontSize: 14)),
                Text(sub,
                    style: GoogleFonts.cairo(
                        color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendWAAll(AppProvider prov) {
    // WhatsApp broadcast to all debtors
    final debtors = prov.db.members.where((m) => m.balance < 0).toList();
    if (debtors.isEmpty) {
      AppSnackbar.show(context, '✅ لا يوجد عملاء عليهم مديونية');
      return;
    }
    AppSnackbar.show(context, '💬 ${debtors.length} عميل عليهم مديونية');
  }
}

// ─── GLOBAL SEARCH SHEET ─────────────────────────────────────
class _GlobalSearchSheet extends StatefulWidget {
  final AppProvider prov;
  final void Function(Map<String, dynamic> result) onSelect;
  const _GlobalSearchSheet({required this.prov, required this.onSelect});

  @override
  State<_GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<_GlobalSearchSheet> {
  final _ctrl = TextEditingController();
  String _filter = 'all';
  List<Map<String, dynamic>> _results = [];

  static const _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'members', 'label': '👤 عملاء'},
    {'key': 'debt', 'label': '🔴 مدينون'},
    {'key': 'clear', 'label': '✅ مسددون'},
    {'key': 'groups', 'label': '📡 مجموعات'},
    {'key': 'waitlist', 'label': '⏳ الانتظار'},
    {'key': 'worknums', 'label': '📋 أرقام العمل'},
    {'key': 'guarantors', 'label': '🤝 كفلاء'},
    {'key': 'notes', 'label': '📝 ملاحظات'},
    {'key': 'complaints', 'label': '📢 شكاوى'},
  ];

  static const _typeIcon = {
    'member': '👤',
    'group': '📡',
    'waitlist': '⏳',
    'worknum': '📋',
    'guarantor': '🤝',
    'guest': '🧳',
    'note': '📝',
    'complaint': '📢',
  };

  static const _typeLabel = {
    'member': 'عميل',
    'group': 'مجموعة',
    'waitlist': 'قائمة انتظار',
    'worknum': 'رقم عمل',
    'guarantor': 'كفيل',
    'guest': 'ضيف',
    'note': 'ملاحظة',
    'complaint': 'شكوى',
  };

  void _search(String q) {
    setState(() {
      _results = widget.prov.searchAll(q, filter: _filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          // Title + close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('🔍 بحث شامل',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.blue2)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textDirection: TextDirection.rtl,
              onChanged: _search,
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الرقم أو الباقة...',
                hintStyle:
                    GoogleFonts.cairo(color: AppColors.muted, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFf0f4f8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          _search('');
                        })
                    : Icon(Icons.search,
                        size: 20, color: AppColors.muted),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filters.map((f) {
                final active = _filter == f['key'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _filter = f['key']!);
                    _search(_ctrl.text);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.headerGradient : null,
                      color: active ? null : const Color(0xFFf0f4f8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f['label']!,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Results
          Expanded(
            child: _ctrl.text.isEmpty
                ? Center(
                    child: Text('اكتب للبحث في كل القوائم',
                        style: GoogleFonts.cairo(
                            color: AppColors.muted, fontSize: 13)))
                : _results.isEmpty
                    ? Center(
                        child: Text('لا توجد نتائج',
                            style: GoogleFonts.cairo(color: AppColors.muted)))
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 12),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          final type = r['type'] as String;
                          final positive = r['positive'] as bool;
                          return GestureDetector(
                            onTap: () => widget.onSelect(r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(
                                    color: AppColors.border, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.blue2
                                          .withValues(alpha: 0.05),
                                      blurRadius: 6)
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Type badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.blueLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_typeIcon[type]} ${_typeLabel[type]}',
                                      style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          color: AppColors.blue2,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Label + subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r['label'] as String,
                                            style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13)),
                                        Text(r['subtitle'] as String,
                                            style: GoogleFonts.cairo(
                                                fontSize: 11,
                                                color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  // Extra badge
                                  if ((r['extra'] as String).isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: positive
                                            ? AppColors.greenLight
                                            : AppColors.redLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        r['extra'] as String,
                                        style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: positive
                                              ? AppColors.green
                                              : AppColors.red2,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_ios,
                                      size: 14, color: AppColors.muted),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
