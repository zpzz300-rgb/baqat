// lib/screens/member_filter_screen.dart
// 🎛️ تصنيف/فلتر العملاء — ابحث بالباقة (جيجا) / حالة الدفع / شهر الاشتراك / النوع
// النتيجة: عدد + جدول عملاء تحت بعض، تدوس على عميل يفتح ملفه، ورسايل واتساب فردي/جماعي.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/phone_utils.dart';
import '../widgets/member_card.dart';

class MemberFilterScreen extends StatefulWidget {
  const MemberFilterScreen({super.key});
  @override
  State<MemberFilterScreen> createState() => _MemberFilterScreenState();
}

class _MemberFilterScreenState extends State<MemberFilterScreen> {
  int? _gb;            // null = كل الباقات
  String _pay = 'all'; // all | regular | debtor | green | yellow | red
  int? _month;         // شهر الاشتراك (1-12)
  int? _year;          // سنة الاشتراك
  String _type = 'all'; // all | regular | landline | homeforgee
  String _q = '';

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  /// كل العملاء المرئيين (يحترم صلاحيات الموظف)
  List<Member> _allMembers(AppProvider prov) {
    final gids = prov.visibleGroups.map((g) => g.id).toSet();
    return prov.db.members.where((m) => gids.contains(m.gid)).toList();
  }

  DateTime? _subDate(Member m) =>
      (m.date == null || m.date!.isEmpty) ? null : DateTime.tryParse(m.date!);

  bool _match(Member m) {
    if (_gb != null && m.gb != _gb) return false;
    switch (_pay) {
      case 'regular': if (m.balance < 0) return false; break;
      case 'debtor':  if (m.balance >= 0) return false; break;
      case 'green':
      case 'yellow':
      case 'red':     if (m.paymentFlag != _pay) return false; break;
    }
    if (_month != null || _year != null) {
      final d = _subDate(m);
      if (d == null) return false;
      if (_month != null && d.month != _month) return false;
      if (_year != null && d.year != _year) return false;
    }
    if (_type != 'all' && m.type != _type) return false;
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      if (!m.name.toLowerCase().contains(q) &&
          !m.phone.contains(q) &&
          !m.package.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final all = _allMembers(prov);
    final filtered = all.where(_match).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // عدّادات ديناميكية للباقات (كل قيم الجيجا الموجودة فعلاً)
    final gbCounts = <int, int>{};
    for (final m in all) {
      if (m.gb > 0) gbCounts[m.gb] = (gbCounts[m.gb] ?? 0) + 1;
    }
    final gbKeys = gbCounts.keys.toList()..sort();

    // سنوات الاشتراك الموجودة فعلاً
    final years = <int>{};
    for (final m in all) {
      final d = _subDate(m);
      if (d != null) years.add(d.year);
    }
    final yearList = years.toList()..sort((a, b) => b.compareTo(a));

    final totalDebt = filtered.fold(0.0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));
    final totalIncome = filtered.fold(0.0, (s, m) => s + m.price);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: AppColors.blue2,
          foregroundColor: Colors.white,
          title: Text('🎛️ تصنيف العملاء',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
          actions: [
            if (filtered.isNotEmpty)
              IconButton(
                tooltip: 'رسالة جماعية للنتيجة',
                icon: const Icon(Icons.campaign),
                onPressed: () => _showBulkMsg(filtered, prov),
              ),
          ],
        ),
        body: Column(children: [
          // ── بحث سريع جوّه النتيجة ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                hintText: '🔍 بحث بالاسم أو الرقم جوّه النتيجة...',
                hintStyle: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.muted),
                isDense: true,
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),

          // ── 1) الباقات (الأهم) ──
          _sectionTitle('📦 الباقة'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('الكل (${all.length})', _gb == null, () => setState(() => _gb = null)),
                for (final k in gbKeys)
                  _chip('$k جيجا (${gbCounts[k]})', _gb == k,
                      () => setState(() => _gb = _gb == k ? null : k)),
              ],
            ),
          ),

          // ── 2) حالة الدفع ──
          _sectionTitle('💳 الدفع'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('الكل', _pay == 'all', () => setState(() => _pay = 'all')),
                _chip('✅ منتظم', _pay == 'regular', () => setState(() => _pay = 'regular')),
                _chip('🔻 مدين', _pay == 'debtor', () => setState(() => _pay = 'debtor')),
                _chip('🟢 علامة خضرا', _pay == 'green', () => setState(() => _pay = 'green')),
                _chip('🟡 علامة صفرا', _pay == 'yellow', () => setState(() => _pay = 'yellow')),
                _chip('🔴 علامة حمرا', _pay == 'red', () => setState(() => _pay = 'red')),
              ],
            ),
          ),

          // ── 3) شهر/سنة الاشتراك ──
          _sectionTitle('🗓️ شهر الاشتراك'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('الكل', _month == null, () => setState(() => _month = null)),
                for (int i = 1; i <= 12; i++)
                  _chip('$i ${_monthNames[i - 1]}', _month == i,
                      () => setState(() => _month = _month == i ? null : i)),
              ],
            ),
          ),
          if (yearList.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                children: [
                  _chip('كل السنين', _year == null, () => setState(() => _year = null)),
                  for (final y in yearList)
                    _chip('$y', _year == y,
                        () => setState(() => _year = _year == y ? null : y)),
                ],
              ),
            ),

          // ── 4) نوع العميل ──
          _sectionTitle('👤 النوع'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('الكل', _type == 'all', () => setState(() => _type = 'all')),
                _chip('📱 عادي', _type == 'regular', () => setState(() => _type = 'regular')),
                _chip('☎️ أرضي', _type == 'landline', () => setState(() => _type = 'landline')),
                _chip('📡 هوم 4G', _type == 'homeforgee', () => setState(() => _type = 'homeforgee')),
              ],
            ),
          ),

          // ── شريط النتيجة ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Text('👥 ${filtered.length} عميل',
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5)),
                const Spacer(),
                Flexible(child: Text(
                  '💰 ${totalIncome.toStringAsFixed(0)} ج شهري'
                  '${totalDebt > 0 ? '  ·  🔴 ${totalDebt.toStringAsFixed(0)} ج ديون' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                )),
              ]),
            ),
          ),

          // ── جدول العملاء ──
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('لا يوجد عملاء مطابقين للفلتر',
                    style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _memberRow(filtered[i], prov),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Text(t, style: GoogleFonts.cairo(
              fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.blue2)),
        ),
      );

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? AppColors.blue2 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? AppColors.blue2 : AppColors.border),
            ),
            child: Text(label, style: GoogleFonts.cairo(
                fontSize: 11.5, fontWeight: FontWeight.w700,
                color: sel ? Colors.white : AppColors.text)),
          ),
        ),
      );

  Widget _memberRow(Member m, AppProvider prov) {
    final g = prov.db.groups.cast<Group?>()
        .firstWhere((x) => x!.id == m.gid, orElse: () => null);
    final debt = m.balance < 0 ? -m.balance : 0.0;
    final d = _subDate(m);

    return GestureDetector(
      onTap: () {
        if (g != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black54,
            builder: (_) => MemberDrawer(member: m, group: g),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: debt > 0 ? const Color(0xFFEF9A9A) : AppColors.border),
        ),
        child: Row(children: [
          // باقة الجيجا — دايرة زرقا
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: AppColors.blueLight, shape: BoxShape.circle),
            child: Center(child: Text(m.gb > 0 ? '${m.gb}\nGB' : '—',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900,
                    color: AppColors.blue2, height: 1.1))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (m.paymentFlag != null)
                Text(m.paymentFlag == 'green' ? '🟢 '
                    : m.paymentFlag == 'yellow' ? '🟡 ' : '🔴 ',
                    style: const TextStyle(fontSize: 10)),
              Flexible(child: Text(m.name, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w800))),
            ]),
            Text(
              '${m.phone}${g != null ? '  ·  📡 ${g.ownerName?.isNotEmpty == true ? g.ownerName : g.phone}' : ''}'
              '${d != null ? '  ·  🗓 ${d.month}/${d.year}' : ''}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted),
            ),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${m.price.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.blue2)),
            if (debt > 0)
              Text('🔻 ${debt.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.red2)),
          ]),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendWA(m),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.waGreen, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.chat, size: 16, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendWA(Member m) async {
    final p = waDigits(m.waPhone);
    final url = 'https://wa.me/$p';
    if (await canLaunchUrl(Uri.parse(url))) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // ── 📣 رسالة جماعية لكل عملاء النتيجة — واحد ورا التاني مع ✅ ──
  void _showBulkMsg(List<Member> members, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MembersBulkMsgSheet(members: members),
    );
  }
}

// ── شيت الرسالة الجماعية لعملاء النتيجة ─────────────────────────────
class _MembersBulkMsgSheet extends StatefulWidget {
  final List<Member> members;
  const _MembersBulkMsgSheet({required this.members});
  @override
  State<_MembersBulkMsgSheet> createState() => _MembersBulkMsgSheetState();
}

class _MembersBulkMsgSheetState extends State<_MembersBulkMsgSheet> {
  final _msgCtrl = TextEditingController();
  final Set<String> _sent = {};

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _send(Member m) async {
    final greeting = 'السلام عليكم ${m.nickname?.isNotEmpty == true ? m.nickname : m.name} 👋\n';
    final url = 'https://wa.me/${waDigits(m.waPhone)}'
        '?text=${Uri.encodeComponent(greeting + _msgCtrl.text.trim())}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      setState(() => _sent.add(m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.members.where((m) => !_sent.contains(m.id)).length;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('📣 رسالة لعملاء النتيجة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.blue2))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(10)),
            child: Text('باقي $remaining من ${widget.members.length}',
                style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.blue2)),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _msgCtrl,
          maxLines: 3,
          style: GoogleFonts.cairo(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'نص الرسالة (بيتضاف قبلها سلام باسم العميل)',
            labelStyle: GoogleFonts.cairo(fontSize: 12),
            hintText: 'مثال: في عرض جديد على باقة 50 جيجا...',
            hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final m = widget.members[i];
              final done = _sent.contains(m.id);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: done ? AppColors.green.withValues(alpha: 0.07) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: done ? AppColors.green : AppColors.border),
                ),
                child: Row(children: [
                  Text(done ? '✅' : '👤', style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    Text('${m.phone} · ${m.gb} جيجا',
                        style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted)),
                  ])),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: done ? Colors.grey[300] : AppColors.waGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _msgCtrl.text.trim().isEmpty ? null : () => _send(m),
                    child: Text(done ? 'تاني' : '💬 إرسال',
                        style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800,
                            color: done ? AppColors.muted : Colors.white)),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
