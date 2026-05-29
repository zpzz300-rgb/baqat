// lib/screens/guarantors_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/phone_utils.dart';
import '../widgets/common.dart';
import '../widgets/member_card.dart';

class GuarantorsScreen extends StatefulWidget {
  const GuarantorsScreen({super.key});
  @override
  State<GuarantorsScreen> createState() => _GuarantorsScreenState();
}

class _GuarantorsScreenState extends State<GuarantorsScreen> {
  String _search = '';
  String _filter = 'all'; // all | debt | clear | personal | company | relative | hasClients | noClients

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final entries = _buildEntries(prov);
    final filtered = _applyFilter(entries);

    // Stats for header
    final totalDebt = entries.fold(0.0, (s, e) => s + e.totalDebt);
    final debtCount = entries.where((e) => e.totalDebt > 0).length;

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.trim()),
            style: GoogleFonts.cairo(fontSize: 13),
            decoration: InputDecoration(
              hintText: '🔍 بحث باسم أو رقم الكفيل...',
              hintStyle: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppColors.muted),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // ── Filter chips ────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            children: [
              _chip('الكل', 'all', '📋'),
              _chip('عليهم ديون', 'debt', '🔴'),
              _chip('مسددين', 'clear', '✅'),
              _chip('شخصي', 'personal', '👤'),
              _chip('شركة', 'company', '🏢'),
              _chip('قريب', 'relative', '👨‍👩‍👦'),
              _chip('لديهم عملاء', 'hasClients', '👥'),
              _chip('بدون عملاء', 'noClients', '🚫'),
            ],
          ),
        ),

        // ── Summary bar ─────────────────────────────────────────
        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFe8f4fd),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blueMid)),
              child: Row(children: [
                Text('${entries.length} كفيل', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.blue2, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                if (debtCount > 0) ...[
                  Container(width: 1, height: 14, color: AppColors.blueMid),
                  const SizedBox(width: 10),
                  Text('$debtCount عليهم ديون', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.red2, fontWeight: FontWeight.w700)),
                ],
                const Spacer(),
                if (totalDebt > 0)
                  Text('إجمالي: ${totalDebt.toStringAsFixed(0)} ج', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.red2, fontWeight: FontWeight.w900)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showForm(context, null, prov),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(16)),
                    child: Text('+ كفيل', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ]),
            ),
          ),

        // ── List ────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🤝', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(entries.isEmpty ? 'لا يوجد كفلاء بعد' : 'لا توجد نتائج',
                      style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14)),
                  if (entries.isEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showForm(context, null, prov),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
                        child: Text('+ إضافة كفيل', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _GuarantorCard(
                    entry: filtered[i],
                    prov: prov,
                    onEdit: () {
                      final formal = prov.db.guarantors.cast<Guarantor?>()
                          .firstWhere((g) => g!.phone == filtered[i].phone, orElse: () => null);
                      _showForm(context, formal, prov);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value, String emoji) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.blue2 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.blue2 : AppColors.border),
        ),
        child: Text('$emoji $label',
            style: GoogleFonts.cairo(fontSize: 12, color: active ? Colors.white : AppColors.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  List<_GuarantorEntry> _buildEntries(AppProvider prov) {
    final Map<String, _GuarantorEntry> map = {};
    for (final g in prov.db.guarantors) {
      map[g.phone] = _GuarantorEntry(
        phone: g.phone, name: g.name, phone2: g.phone2,
        typeLabel: g.typeLabel, typeKey: g.type, formalId: g.id, members: [],
      );
    }
    for (final m in prov.db.members) {
      if (m.guarantorPhone?.isNotEmpty != true) continue;
      final phone = m.guarantorPhone!;
      if (!map.containsKey(phone)) {
        map[phone] = _GuarantorEntry(
          phone: phone, name: m.guarantorName ?? 'كفيل',
          phone2: null, typeLabel: '👤 شخصي', typeKey: 'personal',
          formalId: null, members: [],
        );
      }
      map[phone]!.members.add(m);
    }
    return map.values.toList()..sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
  }

  List<_GuarantorEntry> _applyFilter(List<_GuarantorEntry> all) {
    var list = all;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
        e.name.toLowerCase().contains(q) || e.phone.contains(q) ||
        e.members.any((m) => m.name.toLowerCase().contains(q) || m.phone.contains(q))
      ).toList();
    }
    switch (_filter) {
      case 'debt':       return list.where((e) => e.totalDebt > 0).toList();
      case 'clear':      return list.where((e) => e.totalDebt == 0).toList();
      case 'personal':   return list.where((e) => e.typeKey == 'personal').toList();
      case 'company':    return list.where((e) => e.typeKey == 'company').toList();
      case 'relative':   return list.where((e) => e.typeKey == 'relative').toList();
      case 'hasClients': return list.where((e) => e.members.isNotEmpty).toList();
      case 'noClients':  return list.where((e) => e.members.isEmpty).toList();
      default:           return list;
    }
  }

  void _showForm(BuildContext context, Guarantor? existing, AppProvider prov) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _GuarantorForm(existing: existing, prov: prov),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────
class _GuarantorEntry {
  final String phone, name, typeLabel, typeKey;
  final String? phone2, formalId;
  final List<Member> members;

  _GuarantorEntry({
    required this.phone, required this.name, required this.phone2,
    required this.typeLabel, required this.typeKey,
    required this.formalId, required this.members,
  });

  double get totalDebt => members.fold(0.0, (s, m) => s + (m.balance < 0 ? -m.balance : 0.0));
  int get debtorCount  => members.where((m) => m.balance < 0).length;
}

// ── Unified Guarantor Card ────────────────────────────────────────
class _GuarantorCard extends StatelessWidget {
  final _GuarantorEntry entry;
  final AppProvider prov;
  final VoidCallback onEdit;
  const _GuarantorCard({required this.entry, required this.prov, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasDebt = entry.totalDebt > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasDebt ? const Color(0xFFEF9A9A) : AppColors.border, width: hasDebt ? 1.5 : 1),
        boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.07), blurRadius: 14)],
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFe8f4fd), Color(0xFFdbeeff)]),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(15),
              bottom: entry.members.isEmpty ? const Radius.circular(15) : Radius.zero,
            ),
            border: entry.members.isNotEmpty
                ? const Border(bottom: BorderSide(color: AppColors.blueMid, width: 1))
                : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar circle
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: hasDebt ? const Color(0xFFFFCDD2) : const Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(hasDebt ? '🔴' : '🤝', style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: onEdit,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(entry.name,
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(8)),
                    child: Text(entry.typeLabel, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.blue3, fontWeight: FontWeight.w700)),
                  ),
                ]),
                Text(entry.phone, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted), textDirection: TextDirection.ltr),
                if (entry.phone2 != null)
                  Text('📱 ${entry.phone2}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted), textDirection: TextDirection.ltr),
                Row(children: [
                  Text('${entry.members.length} عميل', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  if (entry.debtorCount > 0) ...[
                    const SizedBox(width: 6),
                    Text('• ${entry.debtorCount} مدين', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.red)),
                  ],
                ]),
              ]),
            )),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (hasDebt)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(8)),
                  child: Text('${entry.totalDebt.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.red2)),
                ),
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 5, children: [
                if (hasDebt)
                  _btn('💰', AppColors.blue2, () => _showBulkPay(context)),
                _btn('💬', AppColors.waGreen, () => _openWA(entry.phone, entry.name)),
                if (entry.members.isNotEmpty) ...[
                  _btnLabeled('📋 تفصيلي', AppColors.waGreen, _sendDetailedReport),
                  _btnLabeled('📊 ملخص', const Color(0xFF1976D2), _sendSummaryReport),
                ],
                _btn('✏️', AppColors.blue2, onEdit),
                if (entry.formalId != null)
                  _btn('🗑', AppColors.red, () => _delete(context, entry.formalId!, entry.name, prov)),
              ]),
            ]),
          ]),
        ),

        // ── Member rows ──────────────────────────────────────────
        ...entry.members.asMap().entries.map((e) {
          final m = e.value;
          final isLast = e.key == entry.members.length - 1;
          final group = prov.db.groups.firstWhere((g) => g.id == m.gid, orElse: () => Group(id: '', phone: ''));
          return _MemberRow(
            member: m, group: group, isLast: isLast, prov: prov, guarantorPhone: entry.phone,
          );
        }),
      ]),
    );
  }

  Widget _btn(String icon, Color bg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(icon, style: const TextStyle(fontSize: 13))),
    ),
  );

  Widget _btnLabeled(String label, Color bg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    ),
  );

  void _openWA(String phone, String name) async {
    final p = phone.replaceFirst(RegExp(r'^0'), '20');
    final url = 'https://wa.me/$p?text=${Uri.encodeComponent("السلام عليكم $name 👋")}';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }

  void _sendDetailedReport() async {
    final phone = entry.phone.replaceFirst(RegExp(r'^0'), '20');
    final lines = StringBuffer();
    lines.writeln('📋 تقرير مديونية كفيل — ${entry.name}');
    lines.writeln('═══════════════════════');
    int idx = 1;
    for (final m in entry.members) {
      final debt  = m.balance < 0 ? -m.balance : 0.0;
      final paid  = m.balance >= 0;
      final months = debt > 0 && m.price > 0 ? (debt / m.price).ceil() : 0;
      lines.writeln('$idx) ${m.name}');
      lines.writeln('   📱 ${m.phone}');
      lines.writeln('   💰 اشتراك: ${m.price.toStringAsFixed(0)} ج/شهر');
      if (paid) {
        lines.writeln('   ✅ مسدد');
      } else {
        lines.writeln('   🔴 مديونية: ${debt.toStringAsFixed(0)} ج ($months شهر)');
      }
      lines.writeln('───────────────────────');
      idx++;
    }
    lines.writeln('');
    lines.writeln('💳 إجمالي المديونية: ${entry.totalDebt.toStringAsFixed(0)} ج');
    lines.writeln('👥 إجمالي العملاء: ${entry.members.length}');
    lines.writeln('🔴 عدد المدينين: ${entry.debtorCount}');
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(lines.toString())}';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }

  void _sendSummaryReport() async {
    final phone = entry.phone.replaceFirst(RegExp(r'^0'), '20');
    final msg = '💳 ملخص مديونية — ${entry.name}\n'
        '═══════════════════════\n'
        '🔴 إجمالي المديونية: ${entry.totalDebt.toStringAsFixed(0)} ج\n'
        '👥 عدد العملاء: ${entry.members.length}\n'
        '🔴 عدد المدينين: ${entry.debtorCount}\n'
        '✅ عدد المسددين: ${entry.members.length - entry.debtorCount}';
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }

  void _showBulkPay(BuildContext context) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _BulkPaySheet(phone: entry.phone, name: entry.name, members: entry.members),
  );

  void _delete(BuildContext context, String id, String name, AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الكفيل', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('حذف "$name"؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () { Navigator.pop(context); prov.deleteGuarantor(id); },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Member row inside guarantor card ──────────────────────────────
class _MemberRow extends StatelessWidget {
  final Member member;
  final Group group;
  final bool isLast;
  final AppProvider prov;
  final String guarantorPhone;
  const _MemberRow({required this.member, required this.group, required this.isLast, required this.prov, required this.guarantorPhone});

  @override
  Widget build(BuildContext context) {
    final m = member;
    final hasDebt = m.balance < 0;
    final debtMonths = hasDebt && m.price > 0 ? ((-m.balance) / m.price).ceil() : 0;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => MemberDrawer(member: m, group: group),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: hasDebt ? const Color(0xFFFFF8F8) : Colors.white,
          border: Border(
            bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFFf0f0f0)),
          ),
          borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(15)) : BorderRadius.zero,
        ),
        child: Row(children: [
          // Flag dot
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: m.paymentFlag == 'red' ? AppColors.red : m.paymentFlag == 'yellow' ? AppColors.orange : m.paymentFlag == 'green' ? AppColors.green : Colors.transparent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.blue2)),
            Text(m.phone, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted), textDirection: TextDirection.ltr),
            if (m.package.isNotEmpty)
              Text(m.package, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${m.balance.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 13,
                    color: hasDebt ? AppColors.red2 : AppColors.green)),
            if (hasDebt && debtMonths > 0)
              Text('$debtMonths شهر', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.red)),
          ]),
          const SizedBox(width: 6),
          // Per-member pay button
          if (hasDebt)
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (_) => _SingleMemberPaySheet(member: m, prov: prov),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(8)),
                child: Text('💳 دفع', style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
          if (!hasDebt)
            const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
        ]),
      ),
    );
  }
}

// ── Single Member Pay Sheet ───────────────────────────────────────
class _SingleMemberPaySheet extends StatefulWidget {
  final Member member;
  final AppProvider prov;
  const _SingleMemberPaySheet({required this.member, required this.prov});
  @override
  State<_SingleMemberPaySheet> createState() => _SingleMemberPaySheetState();
}

class _SingleMemberPaySheetState extends State<_SingleMemberPaySheet> {
  final _amtCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() { _amtCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final debt = m.balance < 0 ? -m.balance : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Text('💳 دفع عميل', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.blue2)),
        Text('${m.name}  •  ${m.phone}', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 4),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(6)),
            child: Text('الدين: ${debt.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.red2)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(6)),
            child: Text('الاشتراك: ${m.price.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blue2)),
          ),
        ]),
        const SizedBox(height: 14),
        // Quick buttons
        Row(children: [
          Expanded(child: _quickBtn('شهر واحد\n${m.price.toStringAsFixed(0)} ج', () {
            _amtCtrl.text = m.price.toStringAsFixed(0);
          })),
          const SizedBox(width: 8),
          Expanded(child: _quickBtn('سداد كامل\n${debt.toStringAsFixed(0)} ج', () {
            _amtCtrl.text = debt.toStringAsFixed(0);
          })),
          if (debt >= m.price * 2) ...[
            const SizedBox(width: 8),
            Expanded(child: _quickBtn('نصف الدين\n${(debt / 2).toStringAsFixed(0)} ج', () {
              _amtCtrl.text = (debt / 2).toStringAsFixed(0);
            })),
          ],
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _amtCtrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'المبلغ (ج)',
            labelStyle: GoogleFonts.cairo(),
            suffixText: 'ج',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'ملاحظة', hintText: 'مثال: دفع شهر أبريل عن طريق الكفيل',
            labelStyle: GoogleFonts.cairo(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo()))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            onPressed: () {
              final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              widget.prov.addPayment(m.id, amt, _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : 'دفع عن طريق الكفيل');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('✅ تم تسجيل ${amt.toStringAsFixed(0)} ج لـ ${m.name}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                backgroundColor: const Color(0xFF0d1b2e),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ));
            },
            child: Text('✅ تأكيد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          )),
        ]),
      ])),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA5D6A7))),
      child: Center(child: Text(label, textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32)))),
    ),
  );
}

// ── BULK PAY SHEET ────────────────────────────────────────────────
class _BulkPaySheet extends StatefulWidget {
  final String phone, name;
  final List<Member> members;
  const _BulkPaySheet({required this.phone, required this.name, required this.members});
  @override
  State<_BulkPaySheet> createState() => _BulkPaySheetState();
}

class _BulkPaySheetState extends State<_BulkPaySheet> {
  final _amtCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _mode = 'debt';
  Map<String, double>? _preview;

  @override
  void dispose() { _amtCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    final debtors = widget.members.where((m) => m.balance < 0).toList();
    final totalDebt = debtors.fold(0.0, (s, m) => s + (-m.balance));
    final monthlyTotal = widget.members.fold(0.0, (s, m) => s + m.price);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Text('💰 دفع الكفيل بالجملة', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.blue2)),
        Text('${widget.name}  •  ${widget.members.length} عميل  •  إجمالي الديون: ${totalDebt.toStringAsFixed(0)} ج',
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 14),

        // Quick buttons row
        Wrap(spacing: 8, runSpacing: 8, children: [
          _quickBtn('شهر للكل\n${monthlyTotal.toStringAsFixed(0)} ج', () {
            _amtCtrl.text = monthlyTotal.toStringAsFixed(0);
            setState(() { _mode = 'price'; _preview = null; });
          }),
          _quickBtn('سداد كامل\n${totalDebt.toStringAsFixed(0)} ج', () {
            _amtCtrl.text = totalDebt.toStringAsFixed(0);
            setState(() { _mode = 'full'; _preview = null; });
          }),
          _quickBtn('نصف الديون\n${(totalDebt / 2).toStringAsFixed(0)} ج', () {
            _amtCtrl.text = (totalDebt / 2).toStringAsFixed(0);
            setState(() { _mode = 'debt'; _preview = null; });
          }),
        ]),
        const SizedBox(height: 12),

        TextField(
          controller: _amtCtrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'المبلغ الإجمالي (ج)', labelStyle: GoogleFonts.cairo(), suffixText: 'ج',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _mode, decoration: const InputDecoration(),
          items: [
            DropdownMenuItem(value: 'equal', child: Text('توزيع متساوٍ على الكل', style: GoogleFonts.cairo(fontSize: 13))),
            DropdownMenuItem(value: 'debt',  child: Text('حسب المديونية (المدينين فقط)', style: GoogleFonts.cairo(fontSize: 13))),
            DropdownMenuItem(value: 'price', child: Text('حسب سعر الاشتراك', style: GoogleFonts.cairo(fontSize: 13))),
            DropdownMenuItem(value: 'full',  child: Text('سداد كامل لكل المدينين', style: GoogleFonts.cairo(fontSize: 13))),
          ],
          onChanged: (v) => setState(() { _mode = v!; _preview = null; }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'ملاحظة', hintText: 'مثال: دفع شهر أبريل',
            labelStyle: GoogleFonts.cairo(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        if (_preview != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFf9f9f9),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('📋 معاينة التوزيع:', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue3, fontSize: 13)),
              const SizedBox(height: 6),
              ..._preview!.entries.map((e) {
                final m = widget.members.firstWhere((x) => x.id == e.key, orElse: () => widget.members.first);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Text(m.name, style: GoogleFonts.cairo(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Text('+${e.value.toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.green, fontSize: 12)),
                  ]),
                );
              }),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo()))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.blue3)),
            onPressed: _buildPreview,
            child: Text('👁 معاينة', style: GoogleFonts.cairo(color: AppColors.blue3, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green2, foregroundColor: Colors.white),
            onPressed: () {
              final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              prov.guarantorBulkPay(widget.phone, amt, _mode, _noteCtrl.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('✅ تم توزيع ${amt.toStringAsFixed(0)} ج', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                backgroundColor: const Color(0xFF0d1b2e),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ));
            },
            child: Text('✅ تأكيد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          )),
        ]),
      ])),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.blueMid)),
      child: Text(label, textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.blue2)),
    ),
  );

  void _buildPreview() {
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;
    final Map<String, double> dist = {};
    final debtors = widget.members.where((m) => m.balance < 0).toList();
    if (_mode == 'equal') {
      final share = amt / widget.members.length;
      for (final m in widget.members) {
        dist[m.id] = share;
      }
    } else if (_mode == 'debt') {
      if (debtors.isEmpty) return;
      final share = amt / debtors.length;
      for (final m in debtors) {
        dist[m.id] = share;
      }
    } else if (_mode == 'price') {
      final total = widget.members.fold(0.0, (s, m) => s + m.price);
      for (final m in widget.members) {
        dist[m.id] = total > 0 ? (m.price / total) * amt : 0;
      }
    } else {
      for (final m in debtors) {
        dist[m.id] = -m.balance;
      }
    }
    setState(() => _preview = dist);
  }
}

// ── GUARANTOR FORM ────────────────────────────────────────────────
class _GuarantorForm extends StatefulWidget {
  final Guarantor? existing;
  final AppProvider prov;
  const _GuarantorForm({this.existing, required this.prov});
  @override
  State<_GuarantorForm> createState() => _GuarantorFormState();
}

class _GuarantorFormState extends State<_GuarantorForm> {
  late final _nameCtrl   = TextEditingController(text: widget.existing?.name ?? '');
  late final _phoneCtrl  = TextEditingController(text: widget.existing?.phone ?? '');
  late final _phone2Ctrl = TextEditingController(text: widget.existing?.phone2 ?? '');
  late final _natIdCtrl  = TextEditingController(text: widget.existing?.natId ?? '');
  late final _notesCtrl  = TextEditingController(text: widget.existing?.notes ?? '');
  late String _type = widget.existing?.type ?? 'personal';
  String? _phoneError;

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _phone2Ctrl.dispose();
    _natIdCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text(widget.existing == null ? '🤝 إضافة كفيل جديد' : '✏️ تعديل الكفيل',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.blue2)),
            const SizedBox(height: 14),
            AppFormField(label: 'الاسم', controller: _nameCtrl, hint: 'اسم الكفيل الكامل'),
            const SizedBox(height: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppFormField(
                label: 'رقم الموبايل', controller: _phoneCtrl,
                hint: '01xxxxxxxxx', textDirection: TextDirection.ltr,
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                onChanged: (v) => setState(() => _phoneError = validatePhone(v)),
              ),
              if (_phoneError != null)
                Text(_phoneError!, style: GoogleFonts.cairo(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            AppFormField(
              label: '📱 رقم ثانٍ (اختياري)', controller: _phone2Ctrl,
              hint: '01xxxxxxxxx', textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone, inputFormatters: [PhoneInputFormatter()],
            ),
            const SizedBox(height: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('نوع الكفيل', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                initialValue: _type, decoration: const InputDecoration(),
                items: [
                  DropdownMenuItem(value: 'personal', child: Text('👤 شخصي', style: GoogleFonts.cairo(fontSize: 13))),
                  DropdownMenuItem(value: 'relative', child: Text('👨‍👩‍👦 قريب', style: GoogleFonts.cairo(fontSize: 13))),
                  DropdownMenuItem(value: 'company',  child: Text('🏢 شركة',  style: GoogleFonts.cairo(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'personal'),
              ),
            ]),
            const SizedBox(height: 12),
            AppFormField(label: 'الرقم القومي (اختياري)', controller: _natIdCtrl,
                textDirection: TextDirection.ltr, inputFormatters: [NatIdInputFormatter()]),
            const SizedBox(height: 12),
            AppFormField(label: 'ملاحظات', controller: _notesCtrl),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo()))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: _phoneError == null ? _save : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue2, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    final g = Guarantor(
      id:    widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name:  _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      phone2: _phone2Ctrl.text.trim().isNotEmpty ? _phone2Ctrl.text.trim() : null,
      type:  _type,
      natId: _natIdCtrl.text.trim().isNotEmpty ? _natIdCtrl.text.trim() : null,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );
    if (widget.existing == null) {
      widget.prov.addGuarantor(g);
    } else {
      widget.prov.editGuarantor(g);
    }
    Navigator.pop(context);
  }
}
