// lib/screens/bills_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/app_theme.dart';
import '../utils/print_helper.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String _filter = 'all'; // all | unpaid | partial | paid
  final String _groupFilter = 'all'; // all | <groupId>
  final _searchCtrl = TextEditingController();
  String _searchQ = '';

  static const _filters = [
    {'key': 'all', 'label': 'الكل', 'color': 0xFF607d9b},
    {'key': 'unpaid', 'label': '🔴 غير مسدد', 'color': 0xFFc62828},
    {'key': 'partial', 'label': '🟡 جزئي', 'color': 0xFFe65100},
    {'key': 'paid', 'label': '✅ مسدد', 'color': 0xFF2e7d32},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _printBills(BuildContext context, List<CompanyBill> bills, AppDB db) {
    const statusLabels = {'paid': 'مسدد', 'partial': 'جزئي', 'unpaid': 'غير مسدد'};
    final rows = bills.map((b) {
      final grp = db.groups.where((g) => g.id == b.groupId).firstOrNull;
      return [
        grp?.phone ?? '-',
        b.month,
        '${b.fixedAmount.toStringAsFixed(0)} ج',
        '${b.actualAmount.toStringAsFixed(0)} ج',
        '${b.remaining.toStringAsFixed(0)} ج',
        statusLabels[b.status] ?? b.status,
      ];
    }).toList();
    PrintHelper.printTable(
      context: context,
      title: 'فواتير الخطوط',
      subtitle: 'إجمالي: ${rows.length} فاتورة',
      headers: ['المجموعة', 'الشهر', 'المبلغ الثابت', 'الفعلي', 'المتبقي', 'الحالة'],
      rows: rows,
    );
  }

  List<CompanyBill> _filteredBills(AppDB db) {
    var bills = db.companyBills.where((b) {
      if (_filter == 'unpaid' && b.status != 'unpaid') return false;
      if (_filter == 'partial' && b.status != 'partial') return false;
      if (_filter == 'paid' && b.status != 'paid') return false;
      if (_groupFilter != 'all' && b.groupId != _groupFilter) return false;
      if (_searchQ.isNotEmpty) {
        final g = db.groups.firstWhere((x) => x.id == b.groupId,
            orElse: () => Group(id: '', phone: ''));
        final q = _searchQ.toLowerCase();
        if (!g.phone.contains(q) &&
            !(g.ownerName ?? '').toLowerCase().contains(q) &&
            !b.month.contains(q) &&
            !b.actualAmount.toString().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
    bills.sort((a, b) => b.date.compareTo(a.date));
    return bills;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;
    final bills = _filteredBills(db);
    final totalUnpaid = db.companyBills
        .where((b) => b.status != 'paid')
        .fold(0.0, (s, b) => s + b.remaining);

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────
      Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(children: [
          Row(children: [
            const Text('📋', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('فواتير الخطوط',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            IconButton(
              onPressed: () => _printBills(context, bills, db),
              icon: const Icon(Icons.print_outlined, color: Colors.white, size: 22),
              tooltip: 'طباعة',
            ),
            _addBillBtn(context, prov, db),
          ]),
          const SizedBox(height: 10),
          // Summary row
          Row(children: [
            _summaryChip('إجمالي الفواتير', db.companyBills.length.toString(),
                Colors.white24),
            const SizedBox(width: 8),
            _summaryChip('المتبقي', '${totalUnpaid.toStringAsFixed(0)} ج',
                totalUnpaid > 0 ? const Color(0xFFFF6B6B) : Colors.white24),
            const SizedBox(width: 8),
            _summaryChip(
                'مسددة',
                db.companyBills.where((b) => b.isPaid).length.toString(),
                const Color(0xFF66BB6A)),
          ]),
        ]),
      ),
      // ── Search ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          textDirection: TextDirection.rtl,
          onChanged: (v) => setState(() => _searchQ = v.trim()),
          decoration: InputDecoration(
            hintText: '🔍 بحث بالرقم أو الشهر أو المبلغ...',
            hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:
                    const BorderSide(color: AppColors.blue, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            suffixIcon: _searchQ.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQ = '');
                    })
                : null,
          ),
        ),
      ),
      // ── Filter chips ────────────────────────────────────────────
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          children: _filters.map((f) {
            final active = _filter == f['key'];
            return GestureDetector(
              onTap: () => setState(() => _filter = f['key'] as String),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? Color(f['color'] as int)
                      : const Color(0xFFf0f4f8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(f['label'] as String,
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.text)),
              ),
            );
          }).toList(),
        ),
      ),
      // ── Bills List ──────────────────────────────────────────────
      Expanded(
        child: bills.isEmpty
            ? _emptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                itemCount: bills.length,
                itemBuilder: (_, i) => _BillCard(
                  bill: bills[i],
                  db: db,
                  prov: prov,
                ),
              ),
      ),
    ]);
  }

  Widget _summaryChip(String label, String value, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _addBillBtn(BuildContext context, AppProvider prov, AppDB db) {
    return GestureDetector(
      onTap: () => _showAddBillDialog(context, prov, db),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text('فاتورة جديدة',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  void _showAddBillDialog(BuildContext context, AppProvider prov, AppDB db) {
    String? selectedGid;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('📋 إضافة فاتورة جديدة',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Group picker
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'اختر المجموعة',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                isExpanded: true,
                initialValue: selectedGid,
                items: db.groups
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            '${g.phone}${g.ownerName != null ? " — ${g.ownerName}" : ""}',
                            style: GoogleFonts.cairo(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setS(() => selectedGid = v),
              ),
              const SizedBox(height: 12),
              // Show fixed amount hint
              if (selectedGid != null)
                Builder(builder: (_) {
                  final g = db.groups.firstWhere((x) => x.id == selectedGid);
                  if (g.fixedBillAmount <= 0) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.blue2),
                      const SizedBox(width: 6),
                      Text(
                        'المبلغ الثابت: ${g.fixedBillAmount.toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.blue2,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  );
                }),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'مبلغ الفاتورة الفعلية (ج)',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                if (selectedGid == null) return;
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                prov.addGroupBill(selectedGid!, amount,
                    note: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: Text('إضافة',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('📋', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('لا توجد فواتير',
            style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14)),
        const SizedBox(height: 6),
        Text('اضغط "فاتورة جديدة" لإضافة فاتورة شهرية',
            style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────
class _BillCard extends StatefulWidget {
  final CompanyBill bill;
  final AppDB db;
  final AppProvider prov;
  const _BillCard({required this.bill, required this.db, required this.prov});

  @override
  State<_BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<_BillCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.bill.status) {
      case 'paid':
        return AppColors.green;
      case 'partial':
        return const Color(0xFFe65100);
      default:
        return AppColors.red;
    }
  }

  Color get _statusBg {
    switch (widget.bill.status) {
      case 'paid':
        return AppColors.greenLight;
      case 'partial':
        return const Color(0xFFFFF3E0);
      default:
        return AppColors.redLight;
    }
  }

  String get _statusLabel {
    switch (widget.bill.status) {
      case 'paid':
        return '✅ مسدد';
      case 'partial':
        return '🟡 جزئي';
      default:
        return '🔴 غير مسدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final db = widget.db;
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: '—'));
    final percent = b.actualAmount > 0 ? b.paidAmount / b.actualAmount : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.06), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header row ─────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Group info
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.phone,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: AppColors.blue2)),
                        if (g.ownerName != null)
                          Text(g.ownerName!,
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: AppColors.muted)),
                      ]),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_statusLabel,
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor)),
                ),
                const SizedBox(width: 8),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.muted),
              ]),
              const SizedBox(height: 8),
              // Month + amounts row
              Row(children: [
                _infoChip(
                    '📅 ${b.month}', AppColors.blueLight, AppColors.blue2),
                const SizedBox(width: 6),
                if (b.fixedAmount > 0)
                  _infoChip('ثابت: ${b.fixedAmount.toStringAsFixed(0)} ج',
                      const Color(0xFFE8F5E9), AppColors.green2),
                const SizedBox(width: 6),
                _infoChip('فعلي: ${b.actualAmount.toStringAsFixed(0)} ج',
                    AppColors.redLight, AppColors.red2),
              ]),
              const SizedBox(height: 8),
              // Progress bar
              if (!b.isPaid) ...[
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('مدفوع: ${b.paidAmount.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: AppColors.green)),
                      Text('متبقي: ${b.remaining.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.red,
                              fontWeight: FontWeight.w700)),
                    ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 1.0),
                    backgroundColor: AppColors.redLight,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.green),
                    minHeight: 6,
                  ),
                ),
              ],
              if (b.isPaid)
                Text('✅ تم السداد الكامل',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.green,
                        fontWeight: FontWeight.w700)),
              if (b.note != null) ...[
                const SizedBox(height: 4),
                Text('📝 ${b.note}',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.muted)),
              ],
            ]),
          ),
        ),
        // ── Action buttons ─────────────────────────────────────────
        if (!b.isPaid)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPayDialog(context, full: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFe65100))),
                    child: Text('💳 سداد جزئي',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFe65100))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPayDialog(context, full: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.green)),
                    child: Text('✅ سداد كامل',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.red),
                ),
              ),
            ]),
          ),
        if (b.isPaid)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.delete_outline,
                        size: 14, color: AppColors.red),
                    const SizedBox(width: 4),
                    Text('حذف',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: AppColors.red)),
                  ]),
                ),
              ),
            ]),
          ),
        // ── Payment history ────────────────────────────────────────
        if (_expanded && b.payments.isNotEmpty) ...[
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('سجل الدفعات',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue2)),
              const SizedBox(height: 6),
              ...b.payments.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.note != null ? '${p.note} — ' : '',
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ),
                      Text(p.date,
                          style: GoogleFonts.cairo(
                              fontSize: 10, color: AppColors.muted)),
                      const SizedBox(width: 8),
                      Text('${p.amount.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green)),
                    ]),
                  )),
            ]),
          ),
        ],
        if (_expanded && b.payments.isEmpty && b.isPaid) ...[
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('لا يوجد سجل دفعات',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ),
        ],
      ]),
    );
  }

  Widget _infoChip(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: GoogleFonts.cairo(
              fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
    );
  }

  void _showPayDialog(BuildContext context, {required bool full}) {
    final b = widget.bill;
    final ctrl =
        TextEditingController(text: full ? b.remaining.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(full ? '✅ سداد كامل' : '💳 سداد جزئي',
            style:
                GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المتبقي:',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.blue2)),
                  Text('${b.remaining.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue2)),
                ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            readOnly: full,
            decoration: InputDecoration(
              labelText: 'المبلغ (ج)',
              labelStyle: GoogleFonts.cairo(fontSize: 13),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: full,
              fillColor: full ? const Color(0xFFf0f4f8) : null,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: 'ملاحظة (رقم إيصال...)',
              labelStyle: GoogleFonts.cairo(fontSize: 13),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    full ? AppColors.green : const Color(0xFFe65100),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              widget.prov.payCompanyBill(b.id, amount,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim());
              Navigator.pop(context);
            },
            child: Text('تأكيد',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الفاتورة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text(
            'سيتم حذف الفاتورة وعكس تأثيرها على المديونية. هل أنت متأكد؟',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              widget.prov.deleteCompanyBill(widget.bill.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
