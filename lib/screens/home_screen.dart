// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
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
import 'admin_panel_screen.dart';
import 'consolidated_screen.dart';
import 'bulk_message_screen.dart';
import 'flagged_members_screen.dart';
import 'bills_screen.dart';
import 'notes_screen.dart';
import 'company_invoices_screen.dart';
import '../widgets/add_group_modal.dart';
import '../widgets/add_member_modal.dart';
import '../widgets/member_card.dart';
import '../widgets/settings_modal.dart';
import '../widgets/ai_modal.dart';

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

  // Main nav tabs (always visible)
  final List<Map<String, dynamic>> _tabs = [
    {'icon': '🏠', 'label': 'المجموعات', 'key': 'groups'},
    {'icon': '🔔', 'label': 'التنبيهات', 'key': 'reminders'},
    {'icon': '🚦', 'label': 'التصنيف', 'key': 'flagged', 'tab': 16},
    {'icon': '🤝', 'label': 'الكفلاء', 'key': 'guarantors', 'tab': 2},
    {'icon': '📋', 'label': 'أرقام العمل', 'key': 'worknums', 'tab': 3},
    {'icon': '💰', 'label': 'الأرباح', 'key': 'profit', 'tab': 4},
    {'icon': '🏠', 'label': 'المؤجرة', 'key': 'rentals', 'tab': 5},
    {'icon': '🎁', 'label': 'الهدايا', 'key': 'gifts', 'tab': 6},
    {'icon': '👥', 'label': 'الضيوف', 'key': 'guests', 'tab': 12},
    {'icon': '📊', 'label': 'كل العملاء', 'key': 'consolidated', 'tab': 14},
  ];

  // "المزيد" menu items
  final List<Map<String, dynamic>> _moreTabs = [
    {'icon': '📋', 'label': 'فواتير الخطوط', 'key': 'bills', 'tab': 17},
    {'icon': '🧾', 'label': 'مراجعة الفواتير', 'key': 'invoice_audit', 'tab': 19},
    {'icon': '📝', 'label': 'الملاحظات', 'key': 'notes', 'tab': 18},
    {'icon': '📡', 'label': 'خطوط رئيسية', 'key': 'mainlines', 'tab': 13},
    {'icon': '📦', 'label': 'الأرشيف', 'key': 'archive', 'tab': 7},
    {'icon': '📋', 'label': 'النشاط', 'key': 'activity', 'tab': 8},
    {'icon': '💾', 'label': 'البيانات', 'key': 'dataio', 'tab': 9},
    {'icon': '🗑', 'label': 'المحذوفون', 'key': 'deleted', 'tab': 10},
    {'icon': '⏳', 'label': 'قائمة الانتظار', 'key': 'waitlist', 'tab': 11},
    {'icon': '📤', 'label': 'رسائل جماعية', 'key': 'bulk', 'tab': 15},
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFf5f7fa),
      drawer: _buildDrawer(prov),
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: constraints.maxHeight * 0.55),
              child: SingleChildScrollView(child: _buildHeader(prov)),
            ),
            Expanded(child: _buildBody(prov)),
          ],
        ),
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
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _headerExpanded = !_headerExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: AdminUnlockWrapper(
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
                        onTap: () => showModalBottomSheet(
                          useRootNavigator: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          barrierColor: Colors.black54,
                          builder: (_) => const AddGroupModal(),
                        ),
                      ),
                      const SizedBox(width: 5),
                      _headerBtn(
                        '+ عميل',
                        bg: Colors.white,
                        textColor: AppColors.blue2,
                        onTap: () => showModalBottomSheet(
                          useRootNavigator: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          barrierColor: Colors.black54,
                          builder: (_) => const AddMemberModal(),
                        ),
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
              const SizedBox(height: 10),
              // 2×2 glass stats grid
              Row(children: [
                _glassStatCard('💰 ربح', prov.db.totalProfit, const Color(0xFF69F0AE), suffix: ' ج'),
                const SizedBox(width: 8),
                _glassStatCard('👥 عملاء', prov.db.members.length.toDouble(), const Color(0xFF40C4FF)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _glassStatCard('🏘️ مجموعات', prov.db.groups.length.toDouble(), const Color(0xFFE040FB)),
                const SizedBox(width: 8),
                _glassStatCard('📋 ديون', prov.db.totalDebt, const Color(0xFFFF6E40),
                    highlight: prov.db.totalDebt > 0, suffix: ' ج'),
              ]),
              if (prov.db.totalBillsOwed > 0) ...[
                const SizedBox(height: 8),
                Container(
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
                    Text('فواتير عليك: ${prov.db.totalBillsOwed.toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              _buildFinancialDashboard(prov),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _glassStatCard(String label, double value, Color accent,
      {bool highlight = false, String suffix = ''}) {
    final display = value == value.roundToDouble()
        ? '${value.toInt()}$suffix'
        : '${value.toStringAsFixed(0)}$suffix';
    return Expanded(
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
            Text(label,
                style: GoogleFonts.cairo(
                    color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(display,
                style: GoogleFonts.cairo(
                    color: accent, fontSize: 20, fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis),
          ],
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

  Widget _iconBtn(IconData icon,
      {Color color = Colors.white, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
  Widget _buildDrawer(AppProvider prov) {
    final allSections = [..._tabs, ..._moreTabs];
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              18, MediaQuery.of(context).padding.top + 20, 18, 18),
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
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
          ]),
        ),
        // Sections list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (int i = 0; i < allSections.length; i++) ...[
                Builder(builder: (_) {
                  final s = allSections[i];
                  final tabIndex = s['tab'] as int? ?? (i < 2 ? i : 0);
                  return _drawerItem(
                    '${s['icon']} ${s['label']}',
                    () {
                      Navigator.pop(context);
                      setState(() {
                        _tab = tabIndex;
                        _searching = false;
                        _searchResults = [];
                      });
                    },
                    selected: _tab == tabIndex,
                  );
                }),
              ],
              const Divider(height: 16),
              _drawerItem('⚙️ الإعدادات', () {
                Navigator.pop(context);
                showDialog(context: context, builder: (_) => const SettingsModal());
              }),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _drawerItem(String label, VoidCallback onTap, {bool selected = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.blueLight : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
              // Search
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => _onSearch(v, prov),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: '🔍 بحث بالاسم أو الرقم أو الباقة أو المبلغ...',
                  hintStyle:
                      GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.blue, width: 1.5),
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
              const SizedBox(height: 8),
              // Billing + Save + Print buttons
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: '📅 تجديد الاشتراكات',
                      colors: const [Color(0xFF0d47a1), Color(0xFF1565c0)],
                      onTap: () => _showBillingMenu(prov),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GradientButton(
                      label: '💾 حفظ البيانات',
                      colors: const [Color(0xFF2e7d32), Color(0xFF43a047)],
                      onTap: () => _showSaveOptions(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _printGroups(prov),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.blueMid),
                      ),
                      child: const Icon(Icons.print_outlined,
                          color: AppColors.blue2, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child:
              _searching ? _buildSearchResults(prov) : _buildGroupsList(prov),
        ),
      ],
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
              color: Colors.white,
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
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.muted),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildGroupsList(AppProvider prov) {
    if (prov.db.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'لا توجد مجموعات بعد',
              style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط + مجموعة لإضافة خط رئيسي',
              style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: prov.db.groups.length,
      onReorder: (oldIndex, newIndex) => prov.reorderGroups(oldIndex, newIndex),
      itemBuilder: (_, i) => GroupCard(
          key: ValueKey(prov.db.groups[i].id), group: prov.db.groups[i]),
    );
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
        setState(() => _tab = 0);
        final mid = result['id'] as String;
        final gid = result['gid'] as String? ?? '';
        final member = prov.db.members
            .firstWhere((m) => m.id == mid, orElse: () => prov.db.members.first);
        final group = prov.db.groups
            .firstWhere((g) => g.id == gid, orElse: () => prov.db.groups.first);
        showModalBottomSheet(useRootNavigator: true,
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black54,
          builder: (_) => MemberDrawer(member: member, group: group, parentContext: context),
        );
        break;

      case 'group':
        setState(() => _tab = 0);
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
      backgroundColor: Colors.transparent,
              barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                          const Icon(Icons.chevron_left, color: AppColors.muted, size: 20),
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
              prov.addMonthBillingForCycle(cycleKey);
              Navigator.pop(context);
              AppSnackbar.show(context, '✅ تمت إضافة الاشتراك');
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          color: Colors.white,
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
  ];

  static const _typeIcon = {
    'member': '👤',
    'group': '📡',
    'waitlist': '⏳',
    'worknum': '📋',
    'guarantor': '🤝',
  };

  static const _typeLabel = {
    'member': 'عميل',
    'group': 'مجموعة',
    'waitlist': 'قائمة انتظار',
    'worknum': 'رقم عمل',
    'guarantor': 'كفيل',
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    : const Icon(Icons.search,
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
                                color: Colors.white,
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
                                  const Icon(Icons.arrow_forward_ios,
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
