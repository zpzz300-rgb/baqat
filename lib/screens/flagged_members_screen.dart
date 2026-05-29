// lib/screens/flagged_members_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../widgets/member_card.dart';
import '../utils/print_helper.dart';

class FlaggedMembersScreen extends StatefulWidget {
  const FlaggedMembersScreen({super.key});

  @override
  State<FlaggedMembersScreen> createState() => _FlaggedMembersScreenState();
}

class _FlaggedMembersScreenState extends State<FlaggedMembersScreen> {
  String _filter = 'red'; // 'red' / 'yellow' / 'green' / 'all'

  void _printFiltered(BuildContext context, List<Member> members, AppProvider prov) {
    const flagLabels = {'red': 'خطر', 'yellow': 'متذبذب', 'green': 'منتظم'};
    final rows = members.map((m) {
      final grp = prov.db.groups.where((g) => g.id == m.gid).firstOrNull;
      return [
        m.name,
        m.phone,
        grp?.phone ?? '-',
        m.package,
        '${m.balance.toStringAsFixed(0)} ج',
        flagLabels[m.paymentFlag] ?? '-',
      ];
    }).toList();
    PrintHelper.printTable(
      context: context,
      title: 'قائمة التصنيف',
      subtitle: 'إجمالي: ${rows.length} عميل',
      headers: ['الاسم', 'الرقم', 'المجموعة', 'الباقة', 'الرصيد', 'التصنيف'],
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final allMembers = prov.db.members;

    List<Member> filtered;
    if (_filter == 'all') {
      filtered = allMembers.where((m) => m.paymentFlag != null).toList();
    } else {
      filtered = allMembers.where((m) => m.paymentFlag == _filter).toList();
    }

    // Sort: red first, then by debt (highest first)
    filtered.sort((a, b) {
      const order = {'red': 0, 'yellow': 1, 'green': 2};
      final flagCmp = (order[a.paymentFlag] ?? 3).compareTo(order[b.paymentFlag] ?? 3);
      if (flagCmp != 0) return flagCmp;
      return a.balance.compareTo(b.balance); // lower balance = more debt = first
    });

    final redCount = allMembers.where((m) => m.paymentFlag == 'red').length;
    final yellowCount = allMembers.where((m) => m.paymentFlag == 'yellow').length;
    final greenCount = allMembers.where((m) => m.paymentFlag == 'green').length;

    return Column(
      children: [
        // ── Summary bar ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.06), blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryChip('🔴', 'خطر', redCount, const Color(0xFFEF5350)),
              _vDivider(),
              _summaryChip('🟡', 'متذبذب', yellowCount, const Color(0xFFFFCA28)),
              _vDivider(),
              _summaryChip('🟢', 'منتظم', greenCount, const Color(0xFF66BB6A)),
              _vDivider(),
              IconButton(
                onPressed: () => _printFiltered(context, filtered, prov),
                icon: const Icon(Icons.print_outlined, color: AppColors.blue2, size: 22),
                tooltip: 'طباعة',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // ── Filter tabs ──────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            _filterChip('red', '🔴 خطر ($redCount)', const Color(0xFFEF5350)),
            const SizedBox(width: 8),
            _filterChip('yellow', '🟡 متذبذب ($yellowCount)', const Color(0xFFFFCA28)),
            const SizedBox(width: 8),
            _filterChip('green', '🟢 منتظم ($greenCount)', const Color(0xFF66BB6A)),
            const SizedBox(width: 8),
            _filterChip('all', '📋 الكل (${redCount + yellowCount + greenCount})', AppColors.blue2),
          ]),
        ),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('😊', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 10),
                      Text(
                        _filter == 'red'
                            ? 'لا يوجد عملاء في قائمة الخطر'
                            : 'لا يوجد عملاء مصنفين',
                        style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final member = filtered[i];
                    final group = prov.db.groups.firstWhere(
                      (g) => g.id == member.gid,
                      orElse: () => Group(id: '', phone: ''),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemberFlagCard(member: member, group: group),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _summaryChip(String icon, String label, int count, Color color) {
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text('$count', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ]),
      Text(label, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
    ]);
  }

  Widget _vDivider() => Container(width: 1, height: 32, color: AppColors.border);

  Widget _filterChip(String val, String label, Color color) {
    final selected = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.muted)),
      ),
    );
  }
}

// ─── Member Flag Card ─────────────────────────────────────────────
class _MemberFlagCard extends StatelessWidget {
  final Member member;
  final Group group;

  const _MemberFlagCard({required this.member, required this.group});

  @override
  Widget build(BuildContext context) {
    final flag = member.paymentFlag;
    Color flagColor = const Color(0xFF66BB6A);
    Color flagBg = const Color(0xFFE8F5E9);
    String flagLabel = '🟢 منتظم';
    if (flag == 'red') {
      flagColor = const Color(0xFFEF5350);
      flagBg = const Color(0xFFFFEBEE);
      flagLabel = '🔴 خطر';
    } else if (flag == 'yellow') {
      flagColor = const Color(0xFFFFCA28);
      flagBg = const Color(0xFFFFFDE7);
      flagLabel = '🟡 متذبذب';
    }

    final hasDebt = member.balance < 0;
    final debt = hasDebt ? -member.balance : 0.0;

    return GestureDetector(
      onTap: () => _openDrawer(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: flagColor.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: flagColor.withValues(alpha: 0.12), blurRadius: 8)],
        ),
        child: Column(
          children: [
            // Flag bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: flagColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Flag badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: flagBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: flagColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(flagLabel,
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: flagColor)),
                  ),
                  const SizedBox(width: 10),
                  // Member info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name,
                            style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.blue2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(member.phone,
                            style: GoogleFonts.cairo(
                                fontSize: 12, color: AppColors.muted),
                            textDirection: TextDirection.ltr),
                        Text('${group.phone} · ${member.package}',
                            style: GoogleFonts.cairo(
                                fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  // Balance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: hasDebt ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasDebt
                              ? '-${debt.toStringAsFixed(0)} ج'
                              : '${member.balance.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: hasDebt
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF2E7D32)),
                        ),
                      ),
                      if (hasDebt) ...[
                        const SizedBox(height: 4),
                        Text('${(debt / member.price).ceil()} شهر',
                            style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: const Color(0xFFEF5350),
                                fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemberDrawer(member: member, group: group),
    );
  }
}
