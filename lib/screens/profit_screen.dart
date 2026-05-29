// lib/screens/profit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../models/models.dart';

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});
  @override
  State<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends State<ProfitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;

    // ── Aggregates ──────────────────────────────────────────────────
    final monthlyIncome = db.members.fold<double>(0, (s, m) => s + m.price);
    final billingProfit = db.totalBillingProfit;
    final giftProfit = db.groups.fold<double>(0, (s, g) => s + g.giftProfit);
    final rentalIncome = db.rentals
        .where((r) => r.status == 'active')
        .fold<double>(0, (s, r) => s + r.rent);
    final guestProfit = db.guestUsers.fold<double>(0, (s, g) => s + g.profit);
    final totalDebt = db.totalDebt;
    final pointsProfit = db.groups.fold<double>(0, (s, g) => s + g.pendingPointsProfit);
    // صافي الرصيد المطلوب للعمل = رصيد العملاء فقط (بدون الإيجارات)
    final netBalance = db.members.fold<double>(0, (s, m) => s + m.balance);
    // صافي الربح النهائي = ربح الفواتير + الهدايا + الإيجارات + الضيوف + النقاط التراكمية
    final finalNetProfit = billingProfit + giftProfit + rentalIncome + guestProfit + pointsProfit;

    return Column(
      children: [
        // ── Summary strip ─────────────────────────────────────────
        Container(
          color: AppColors.blue2,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(children: [
            Row(children: [
              _topCard('📥 دخل شهري', monthlyIncome),
              const SizedBox(width: 8),
              _topCard('💰 ربح فواتير', billingProfit, positive: billingProfit >= 0),
              const SizedBox(width: 8),
              _topCard('🎁 ربح هدايا', giftProfit),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _topCard('🏠 إيجارات', rentalIncome),
              const SizedBox(width: 8),
              _topCard('🧳 ربح ضيوف', guestProfit),
              const SizedBox(width: 8),
              _topCard('🔴 مديونيات', -totalDebt, positive: false, forceNeg: true),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _topCard('🪙 نقاط تراكمية', pointsProfit),
            ]),
            const SizedBox(height: 8),
            // صافي الرصيد المطلوب للعمل (من العملاء فقط — بدون إيجارات)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('⚖️ صافي الرصيد المطلوب للعمل',
                      style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70)),
                  Text(
                    '${netBalance.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: netBalance >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // صافي الربح النهائي (ربح الفواتير + هدايا + إيجارات + ضيوف)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: finalNetProfit >= 0
                    ? const Color(0xFF1B5E20).withValues(alpha: 0.5)
                    : const Color(0xFFB71C1C).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('💎 صافي الربح النهائي',
                        style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70)),
                    Text('فواتير + هدايا + إيجارات + ضيوف + نقاط',
                        style: GoogleFonts.cairo(fontSize: 9, color: Colors.white54)),
                  ]),
                  Text(
                    '${finalNetProfit.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: finalNetProfit >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),

        // ── Tabs ──────────────────────────────────────────────────
        Material(
          color: AppColors.blue2,
          child: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [
              Tab(text: 'المجموعات'),
              Tab(text: 'الأنواع'),
              Tab(text: 'العملاء'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _GroupsTab(db: db),
              _TypesTab(db: db,
                monthlyIncome: monthlyIncome,
                billingProfit: billingProfit,
                giftProfit: giftProfit,
                rentalIncome: rentalIncome,
                guestProfit: guestProfit,
                totalDebt: totalDebt,
              ),
              _MembersTab(db: db),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topCard(String label, double val,
      {bool? positive, bool forceNeg = false}) {
    final isPos = forceNeg ? false : (positive ?? val >= 0);
    final color = isPos ? const Color(0xFF69F0AE) : const Color(0xFFFF5252);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.cairo(fontSize: 10, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(
            '${val.abs().toStringAsFixed(0)} ج',
            style: GoogleFonts.cairo(
                fontSize: 14, fontWeight: FontWeight.w900, color: color),
          ),
        ]),
      ),
    );
  }
}

// ── Tab 1: Per-group breakdown ────────────────────────────────────────────────
class _GroupsTab extends StatelessWidget {
  final AppDB db;
  const _GroupsTab({required this.db});

  @override
  Widget build(BuildContext context) {
    if (db.groups.isEmpty) {
      return Center(
          child: Text('لا توجد مجموعات',
              style: GoogleFonts.cairo(color: AppColors.muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: db.groups.length,
      itemBuilder: (_, i) => _GroupProfitCard(group: db.groups[i], db: db),
    );
  }
}

class _GroupProfitCard extends StatefulWidget {
  final Group group;
  final AppDB db;
  const _GroupProfitCard({required this.group, required this.db});

  @override
  State<_GroupProfitCard> createState() => _GroupProfitCardState();
}

class _GroupProfitCardState extends State<_GroupProfitCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final db = widget.db;
    final members = db.membersOf(g.id);
    final income = members.fold<double>(0, (s, m) => s + m.price);
    final bill = g.fixedBillAmount > 0 ? g.fixedBillAmount : (g.actualBillAmount ?? 0);
    final profit = db.groupProfit(g.id);
    final debt = db.groupDebt(g.id);
    final giftP = g.giftProfit;

    final providerColor = _provColor(g.provider);
    final providerLabel = _provLabel(g.provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: providerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(providerLabel,
                      style: GoogleFonts.cairo(
                          fontSize: 11, fontWeight: FontWeight.w700, color: providerColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.ownerName?.isNotEmpty == true ? g.ownerName! : g.phone,
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${members.length} عميل',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.muted, size: 20),
              ]),
              const SizedBox(height: 10),
              // Profit summary row
              Wrap(spacing: 10, runSpacing: 6, children: [
                _miniStat('📥 دخل', '${income.toStringAsFixed(0)} ج', AppColors.blue2),
                _miniStat('🧾 فاتورة', bill > 0 ? '${bill.toStringAsFixed(0)} ج' : '-', AppColors.muted),
                _miniStat('💰 ربح', bill > 0 ? '${profit.toStringAsFixed(0)} ج' : '-',
                    profit >= 0 ? AppColors.green : AppColors.red2),
                _miniStat('🔴 ديون', debt > 0 ? '${debt.toStringAsFixed(0)} ج' : '✅', AppColors.red2),
                if (giftP > 0)
                  _miniStat('🎁 هدايا', '${giftP.toStringAsFixed(0)} ج', const Color(0xFF7B1FA2)),
              ]),
            ]),
          ),
        ),

        // Expanded member list
        if (_expanded) ...[
          const Divider(height: 1),
          ...members.map((m) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
            child: Row(children: [
              Expanded(
                child: Text(m.name,
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Text(m.package,
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
              const SizedBox(width: 8),
              Text('${m.price.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: m.balance < 0 ? AppColors.redLight : AppColors.greenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${m.balance.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: m.balance < 0 ? AppColors.red2 : AppColors.green,
                  ),
                ),
              ),
            ]),
          )),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('لا يوجد عملاء',
                  style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
            ),
        ],
      ]),
    );
  }

  Widget _miniStat(String label, String val, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.cairo(fontSize: 9, color: AppColors.muted)),
      Text(val,
          style: GoogleFonts.cairo(
              fontSize: 12, fontWeight: FontWeight.w900, color: color)),
    ],
  );

  Color _provColor(String? p) {
    switch (p) {
      case 'vodafone': return const Color(0xFFE60000);
      case 'etisalat': return const Color(0xFF00A651);
      case 'orange':   return const Color(0xFFFF6600);
      case 'we':       return const Color(0xFF7B2D8B);
      default:         return AppColors.blue2;
    }
  }

  String _provLabel(String? p) {
    switch (p) {
      case 'vodafone': return '🔴 فودافون';
      case 'etisalat': return '🟢 اتصالات';
      case 'orange':   return '🟠 أورانج';
      case 'we':       return '🟣 WE';
      default:         return '📡 غير محدد';
    }
  }
}

// ── Tab 2: Profit types breakdown ─────────────────────────────────────────────
class _TypesTab extends StatelessWidget {
  final AppDB db;
  final double monthlyIncome, billingProfit, giftProfit, rentalIncome,
      guestProfit, totalDebt;

  const _TypesTab({
    required this.db,
    required this.monthlyIncome,
    required this.billingProfit,
    required this.giftProfit,
    required this.rentalIncome,
    required this.guestProfit,
    required this.totalDebt,
  });

  @override
  Widget build(BuildContext context) {
    final total = monthlyIncome + giftProfit + rentalIncome + guestProfit;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _TypeRow('📥 دخل شهري من العملاء', monthlyIncome, AppColors.blue2,
            sub: 'مجموع اشتراكات ${db.members.length} عميل'),
        _TypeRow('💰 ربح الفواتير', billingProfit,
            billingProfit >= 0 ? AppColors.green : AppColors.red2,
            sub: 'الفرق بين الدخل وفاتورة الشركة'),
        _TypeRow('🎁 ربح الهدايا', giftProfit, const Color(0xFF7B1FA2),
            sub: 'من ${db.groups.length} مجموعة'),
        _TypeRow('🏠 دخل الإيجارات', rentalIncome, const Color(0xFF00695C),
            sub: '${db.rentals.where((r) => r.status == "active").length} وحدة نشطة'),
        _TypeRow('🧳 ربح الضيوف', guestProfit, const Color(0xFFE65100),
            sub: '${db.guestUsers.length} ضيف'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF80CBC4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('💎 إجمالي الدخل', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
            Text('${total.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.green)),
          ]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.redLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF9A9A)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🔴 إجمالي المديونيات', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
              Text('${db.debtorCount} عميل لديهم ديون',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
            ]),
            Text('${totalDebt.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.red2)),
          ]),
        ),

        // Per-provider breakdown
        const SizedBox(height: 16),
        Text('📡 الأرباح حسب المزود',
            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.blue2)),
        const SizedBox(height: 8),
        ..._providerBreakdown(db),
      ],
    );
  }

  List<Widget> _providerBreakdown(AppDB db) {
    final providers = <String, _ProvStats>{};
    for (final g in db.groups) {
      final p = g.provider ?? 'غير محدد';
      providers.putIfAbsent(p, () => _ProvStats());
      final members = db.membersOf(g.id);
      providers[p]!.income += members.fold(0, (s, m) => s + m.price);
      providers[p]!.bill += g.fixedBillAmount > 0 ? g.fixedBillAmount : (g.actualBillAmount ?? 0);
      providers[p]!.debt += db.groupDebt(g.id);
      providers[p]!.groups++;
    }

    return providers.entries.map((e) {
      final profit = e.value.income - e.value.bill;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Text(_provEmoji(e.key), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_provName(e.key), style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${e.value.groups} مجموعة', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('دخل: ${e.value.income.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2, fontWeight: FontWeight.w700)),
            if (e.value.bill > 0)
              Text('ربح: ${profit.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: profit >= 0 ? AppColors.green : AppColors.red2,
                    fontWeight: FontWeight.w700,
                  )),
            if (e.value.debt > 0)
              Text('ديون: ${e.value.debt.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.red2)),
          ]),
        ]),
      );
    }).toList();
  }

  String _provEmoji(String p) {
    switch (p) {
      case 'vodafone': return '🔴';
      case 'etisalat': return '🟢';
      case 'orange':   return '🟠';
      case 'we':       return '🟣';
      default:         return '📡';
    }
  }
  String _provName(String p) {
    switch (p) {
      case 'vodafone': return 'فودافون';
      case 'etisalat': return 'اتصالات';
      case 'orange':   return 'أورانج';
      case 'we':       return 'WE';
      default:         return p;
    }
  }
}

class _ProvStats {
  double income = 0, bill = 0, debt = 0;
  int groups = 0;
}

class _TypeRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String? sub;
  const _TypeRow(this.label, this.value, this.color, {this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
          if (sub != null)
            Text(sub!, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        ])),
        Text(
          '${value.toStringAsFixed(0)} ج',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: color),
        ),
      ]),
    );
  }
}

// ── Tab 3: All members with balance ──────────────────────────────────────────
class _MembersTab extends StatefulWidget {
  final AppDB db;
  const _MembersTab({required this.db});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  String _filter = 'all'; // all / debt / clear

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final filtered = db.members.where((m) {
      if (_filter == 'debt') return m.balance < 0;
      if (_filter == 'clear') return m.balance >= 0;
      return true;
    }).toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));

    return Column(
      children: [
        // Filter bar
        Container(
          color: const Color(0xFFF8F9FA),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _filterBtn('الكل', 'all'),
            const SizedBox(width: 8),
            _filterBtn('🔴 مديونيات', 'debt'),
            const SizedBox(width: 8),
            _filterBtn('🟢 مسددون', 'clear'),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final m = filtered[i];
              final group = db.groups.cast<Group?>().firstWhere(
                    (g) => g?.id == m.gid,
                    orElse: () => null,
                  );
              final groupLabel = group != null
                  ? (group.ownerName?.isNotEmpty == true
                      ? group.ownerName!
                      : group.phone)
                  : '-';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: m.balance < 0
                        ? const Color(0xFFFFCDD2)
                        : AppColors.border,
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name,
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(groupLabel,
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  ])),
                  Text(m.package,
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(width: 10),
                  Text('${m.price.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.blue2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: m.balance < 0 ? AppColors.redLight : AppColors.greenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${m.balance.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: m.balance < 0 ? AppColors.red2 : AppColors.green,
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterBtn(String label, String val) {
    final sel = _filter == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppColors.blue2 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? AppColors.blue2 : AppColors.border),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : AppColors.muted,
                )),
          ),
        ),
      ),
    );
  }
}
