// lib/screens/billing_accounts_screen.dart
// 🔁 حسابات الفوترة — مجموعة خطوط بتتبادل نزول الفاتورة بينهم (شقّين)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/app_search.dart';
import '../widgets/app_search_bar.dart';

String _monthKeyNow() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}';
}

class BillingAccountsScreen extends StatelessWidget {
  const BillingAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final accounts = prov.billingAccounts;
    final month = _monthKeyNow();

    return Scaffold(
      backgroundColor: const Color(0xFFf8fbff),
      appBar: AppBar(
        title: Text('🔁 حسابات الفوترة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: AppColors.blue2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'حساب جديد',
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _EditBillingAccountScreen()),
            ),
          ),
        ],
      ),
      body: accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'مفيش حسابات فوترة لسه.\n'
                  'اعمل حساب لو عندك كذا خط بيتبادلوا نزول الفاتورة\n'
                  '(مثلاً: 3 خطوط سوا الشهر ده، خط لوحده الشهر اللي بعده)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: accounts.length,
              itemBuilder: (_, i) {
                final acc = accounts[i];
                final dueIds = prov.dueShiftGroupIds(acc, month);
                final dueIsA = dueIds == acc.shiftA;
                final duePhones = dueIds
                    .map((gid) => prov.db.groups
                        .firstWhere((g) => g.id == gid, orElse: () => Group(id: '', phone: '?'))
                        .phone)
                    .join(' • ');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(acc.name,
                              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => _EditBillingAccountScreen(existing: acc)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _confirmDelete(context, prov, acc),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text('شق أ (${acc.shiftA.length} خط): ${_phonesOf(prov, acc.shiftA)}',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                      Text('شق ب (${acc.shiftB.length} خط): ${_phonesOf(prov, acc.shiftB)}',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '📅 الدور الشهر ده على: ${dueIsA ? 'شق أ' : 'شق ب'} — $duePhones',
                          style: GoogleFonts.cairo(
                              fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.blue2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _phonesOf(AppProvider prov, List<String> ids) {
    if (ids.isEmpty) return '—';
    return ids
        .map((gid) => prov.db.groups
            .firstWhere((g) => g.id == gid, orElse: () => Group(id: '', phone: '?'))
            .phone)
        .join(' • ');
  }

  void _confirmDelete(BuildContext context, AppProvider prov, BillingAccount acc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🗑 حذف "${acc.name}"؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('الخطوط نفسها مش هتتحذف، بس هتخرج من نظام التبادل ده.',
            style: GoogleFonts.cairo(fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              prov.deleteBillingAccount(acc.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
class _EditBillingAccountScreen extends StatefulWidget {
  final BillingAccount? existing;
  const _EditBillingAccountScreen({this.existing});

  @override
  State<_EditBillingAccountScreen> createState() => _EditBillingAccountScreenState();
}

class _EditBillingAccountScreenState extends State<_EditBillingAccountScreen> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final Set<String> _shiftA = {...?widget.existing?.shiftA};
  late final Set<String> _shiftB = {...?widget.existing?.shiftB};
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setShift(String gid, int shift) {
    setState(() {
      _shiftA.remove(gid);
      _shiftB.remove(gid);
      if (shift == 1) _shiftA.add(gid);
      if (shift == 2) _shiftB.add(gid);
    });
  }

  void _save(AppProvider prov) {
    if (_nameCtrl.text.trim().isEmpty) return;
    if (widget.existing == null) {
      prov.createBillingAccount(_nameCtrl.text,
          shiftA: _shiftA.toList(), shiftB: _shiftB.toList());
    } else {
      prov.updateBillingAccount(widget.existing!.id,
          name: _nameCtrl.text, shiftA: _shiftA.toList(), shiftB: _shiftB.toList());
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // كل الخطوط المتاحة، ما عدا الفروع (اللي أصلاً بتنزل مع خطها الرئيسي)
    var groups = prov.db.groups
        .where((g) => g.parentGroupId == null || g.parentGroupId!.isEmpty)
        .toList();
    // 🔍 محرّك البحث الموحّد
    final terms = searchTerms(_search);
    if (terms.isNotEmpty) {
      groups = groups
          .where((g) => searchHitsOf(terms, [
                g.phone, g.ownerName ?? '', g.groupInvoiceName ?? '',
                g.accountEmail ?? '',
              ]) != null)
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFf8fbff),
      appBar: AppBar(
        title: Text(widget.existing == null ? '➕ حساب فوترة جديد' : '✏️ تعديل الحساب',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: AppColors.blue2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => _save(prov),
            child: Text('حفظ',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _nameCtrl,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: 'اسم الحساب (مثلاً: محل العتبة)',
              labelStyle: GoogleFonts.cairo(),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: Text('حدّد لكل خط شق أ ولا شق ب (الاتنين بيتبادلوا كل شهر)',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
            ),
          ]),
        ),
        AppSearchBar(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          hint: '🔍 رقم الخط · صاحبه · الإيميل',
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              final inA = _shiftA.contains(g.id);
              final inB = _shiftB.contains(g.id);
              final otherAccount = (!inA && !inB) ? prov.accountOfGroup(g.id) : null;
              final isOtherAccount =
                  otherAccount != null && otherAccount.id != widget.existing?.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.phone,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.robotoMono(fontWeight: FontWeight.w800, fontSize: 13)),
                        if (g.ownerName?.isNotEmpty ?? false)
                          Text(g.ownerName!,
                              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                        if (isOtherAccount)
                          Text('⚠️ موجود في حساب "${otherAccount.name}"',
                              style: GoogleFonts.cairo(fontSize: 10, color: Colors.orange)),
                      ],
                    ),
                  ),
                  if (!isOtherAccount) ...[
                    _shiftChip('شق أ', inA, AppColors.blue2, () => _setShift(g.id, inA ? 0 : 1)),
                    const SizedBox(width: 6),
                    _shiftChip('شق ب', inB, AppColors.purple, () => _setShift(g.id, inB ? 0 : 2)),
                  ],
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _shiftChip(String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: active ? 0 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : color)),
      ),
    );
  }
}
