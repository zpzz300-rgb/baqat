// lib/screens/consolidated_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../widgets/member_card.dart';
import '../utils/print_helper.dart';

class ConsolidatedScreen extends StatefulWidget {
  const ConsolidatedScreen({super.key});
  @override
  State<ConsolidatedScreen> createState() => _ConsolidatedScreenState();
}

class _ConsolidatedScreenState extends State<ConsolidatedScreen> {
  String _filter = 'all';   // all / debt / clear / highdebt
  String _sort   = 'name';  // name / debt / group
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _filters = [
    ('all',      'الكل'),
    ('debt',     '🔴 مديونون'),
    ('clear',    '✅ مسدّدون'),
    ('highdebt', '⚠️ دين مرتفع'),
  ];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _printMembers(BuildContext context, List<Member> members, AppProvider prov) {
    final rows = members.map((m) {
      final grp = prov.db.groups.where((g) => g.id == m.gid).firstOrNull;
      return [
        m.name,
        m.phone,
        grp?.phone ?? '-',
        m.package,
        '${m.price.toStringAsFixed(0)} ج',
        '${m.balance.toStringAsFixed(0)} ج',
      ];
    }).toList();
    PrintHelper.printTable(
      context: context,
      title: 'قائمة كل العملاء',
      subtitle: 'إجمالي: ${rows.length} عميل',
      headers: ['الاسم', 'الرقم', 'المجموعة', 'الباقة', 'السعر', 'الرصيد'],
      rows: rows,
    );
  }

  List<Member> _filtered(AppProvider prov) {
    final q = _search.toLowerCase();
    var list = prov.db.members.where((m) {
      final matchQ = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.phone.contains(q) ||
          m.package.toLowerCase().contains(q);
      final matchF = switch (_filter) {
        'debt'     => m.balance < 0,
        'clear'    => m.balance >= 0,
        'highdebt' => m.balance < -prov.debtThreshold,
        _          => true,
      };
      return matchQ && matchF;
    }).toList();

    list.sort((a, b) => switch (_sort) {
      'debt'  => a.balance.compareTo(b.balance),
      'group' => a.gid.compareTo(b.gid),
      _       => a.name.compareTo(b.name),
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final members = _filtered(prov);

    return Column(children: [
      // ── Filter + Search bar ──────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: '🔍 بحث بالاسم أو الرقم أو الباقة...',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              filled: true,
              fillColor: const Color(0xFFf5f7fa),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
              suffixIcon: _search.isNotEmpty
                  ? GestureDetector(
                      onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                      child: const Icon(Icons.close, size: 16, color: AppColors.muted))
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final sel = _filter == f.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.headerGradient : null,
                          color: sel ? null : const Color(0xFFf0f4f8),
                          borderRadius: BorderRadius.circular(20),
                          border: sel ? null : Border.all(color: AppColors.border),
                        ),
                        child: Text(f.$2,
                            style: GoogleFonts.cairo(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.text)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'name',  child: Text('ترتيب: الاسم',    style: GoogleFonts.cairo())),
                PopupMenuItem(value: 'debt',  child: Text('ترتيب: المديونية', style: GoogleFonts.cairo())),
                PopupMenuItem(value: 'group', child: Text('ترتيب: المجموعة',  style: GoogleFonts.cairo())),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blueMid),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.sort, size: 14, color: AppColors.blue2),
                  const SizedBox(width: 4),
                  Text('ترتيب', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _printMembers(context, members, prov),
              icon: const Icon(Icons.print_outlined, color: AppColors.blue2, size: 20),
              tooltip: 'طباعة',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ]),
      ),

      // ── Stats bar ────────────────────────────────────────────
      Container(
        color: const Color(0xFFf8fbff),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          Text('${members.length} عميل',
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('مديونية: ${members.where((m) => m.balance < 0).fold(0.0, (s, m) => s + (-m.balance)).toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.red2, fontWeight: FontWeight.w700)),
        ]),
      ),

      // ── Members list ─────────────────────────────────────────
      Expanded(
        child: members.isEmpty
            ? Center(child: Text('لا توجد نتائج', style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14)))
            : ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final m = members[i];
                  final group = prov.db.groups.firstWhere(
                    (g) => g.id == m.gid,
                    orElse: () => Group(id: m.gid, phone: '?'),
                  );
                  return _MemberRow(member: m, group: group);
                },
              ),
      ),
    ]);
  }
}

class _MemberRow extends StatelessWidget {
  final Member member;
  final Group  group;
  const _MemberRow({required this.member, required this.group});

  @override
  Widget build(BuildContext context) {
    final hasDebt = member.balance < 0;
    final debtColor = hasDebt ? AppColors.red2 : AppColors.green;
    final debtBg    = hasDebt ? AppColors.redLight : AppColors.greenLight;

    return GestureDetector(
      onTap: () => showModalBottomSheet(useRootNavigator: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MemberDrawer(member: member, group: group),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasDebt ? AppColors.red.withValues(alpha: 0.3) : AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Row(children: [
          // Status dot
          Container(
            width: 10, height: 10,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: hasDebt ? AppColors.red : AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
          // Name + phone + group
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member.name,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Text(member.phone,
                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                    textDirection: TextDirection.ltr),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(group.phone,
                      style: GoogleFonts.cairo(fontSize: 9, color: AppColors.blue2, fontWeight: FontWeight.w700),
                      textDirection: TextDirection.ltr),
                ),
              ]),
              Text(member.package, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
            ]),
          ),
          // Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: debtBg, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${hasDebt ? "-" : "+"}${member.balance.abs().toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: debtColor),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_left, size: 16, color: AppColors.muted),
        ]),
      ),
    );
  }
}
