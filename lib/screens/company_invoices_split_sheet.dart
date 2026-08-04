// lib/screens/company_invoices_split_sheet.dart
// ✂️ لوحة تقسيم الفاتورة — جزء من company_invoices_screen.dart.
// اتفصل عشان الملف كان 4366 سطر وبقى صعب يتقرا. الكود زي ما هو بالظبط.
part of 'company_invoices_screen.dart';

class _SplitBillSheet extends StatefulWidget {
  final String parentId;
  final AppProvider prov;
  const _SplitBillSheet({required this.parentId, required this.prov});
  @override
  State<_SplitBillSheet> createState() => _SplitBillSheetState();
}

class _SplitBillSheetState extends State<_SplitBillSheet> {
  late final List<Group> _lines;          // الأب + التوابع
  final Map<String, TextEditingController> _amtCtrls = {};
  final Map<String, String> _systems = {}; // gid → 'fixed' | 'bimonthly'

  @override
  void initState() {
    super.initState();
    final db = widget.prov.db;
    final parent = db.groups.firstWhere((g) => g.id == widget.parentId,
        orElse: () => Group(id: '', phone: '—'));
    final children = db.groups.where((g) => g.parentGroupId == widget.parentId).toList();
    _lines = [parent, ...children];
    for (final g in _lines) {
      _amtCtrls[g.id] = TextEditingController(
          text: g.fixedBillAmount > 0 ? g.fixedBillAmount.toStringAsFixed(0) : '');
      _systems[g.id] = g.billingSystem == 'bimonthly' ? 'bimonthly' : 'fixed';
    }
  }

  @override
  void dispose() {
    for (final c in _amtCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (s, g) => s + (double.tryParse(_amtCtrls[g.id]!.text.trim()) ?? 0));

  void _save() {
    for (final g in _lines) {
      final amt = double.tryParse(_amtCtrls[g.id]!.text.trim()) ?? 0;
      widget.prov.setGroupFixedBill(g.id, amt);
      widget.prov.setGroupBillingSystem(g.id, _systems[g.id]!);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ تم حفظ تقسيمة ${_lines.length} خط',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('✂️ تقسيم فاتورة الحساب',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.blue2)),
          Text('اكتب مبلغ كل خط واختار نظامه — «شهر وشهر» بيتعكس تلقائياً، و«ثابت» ينزل كل شهر.',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 12),
          ..._lines.asMap().entries.map((e) {
            final g = e.value;
            final isParent = e.key == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isParent ? const Color(0xFFE8F4FD) : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isParent ? AppColors.blueMid : AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(isParent ? Icons.star : Icons.subdirectory_arrow_right,
                      size: 14, color: isParent ? AppColors.blue2 : AppColors.muted),
                  const SizedBox(width: 4),
                  Text(g.phone, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.blue2),
                      textDirection: TextDirection.ltr),
                  if (isParent) ...[
                    const SizedBox(width: 6),
                    Text('(رئيسي)', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                  ],
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _amtCtrls[g.id],
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'المبلغ', labelStyle: GoogleFonts.cairo(fontSize: 12), suffixText: 'ج',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )),
                  const SizedBox(width: 8),
                  _sysToggle(g.id),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text('💰 إجمالي الفاتورة المدموجة',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20))),
              const Spacer(),
              Text('${_total.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue2, foregroundColor: Colors.white),
              onPressed: _save,
              child: Text('💾 حفظ التقسيمة', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _sysToggle(String gid) {
    final isBi = _systems[gid] == 'bimonthly';
    return GestureDetector(
      onTap: () => setState(() => _systems[gid] = isBi ? 'fixed' : 'bimonthly'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isBi ? const Color(0xFFEDE7F6) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isBi ? const Color(0xFF7E57C2) : const Color(0xFF66BB6A)),
        ),
        child: Text(isBi ? '🔄 شهر وشهر' : '📌 ثابت',
            style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800,
                color: isBi ? const Color(0xFF5E35B1) : const Color(0xFF2E7D32))),
      ),
    );
  }
}