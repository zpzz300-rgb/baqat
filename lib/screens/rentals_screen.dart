// lib/screens/rentals_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../widgets/common.dart';

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});
  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  String _search = '';
  String _filter = 'all'; // all|active|paused|ended|debt|clear|partial|deferred

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final all = prov.db.rentals;
    final active = all.where((r) => r.status == 'active').length;
    final totalRent = all.where((r) => r.status == 'active').fold(0.0, (s, r) => s + r.rent);
    final totalDebt = all.fold(0.0, (s, r) => s + r.debt);
    final rentals = _apply(all, prov);

    return Column(
      children: [
        // Header + Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(child: Text('🏠 قائمة الخطوط المؤجرة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2, fontSize: 14))),
              GestureDetector(
                onTap: () => _showAddRental(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1565c0), Color(0xFF2196f3)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 10)],
                  ),
                  child: Text('+ إضافة خط مؤجر', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        // Summary
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.08), blurRadius: 20)],
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _sumItem('نشط', '$active', AppColors.green),
                  _sumItem('إيجار شهري', '${totalRent.toStringAsFixed(0)} ج', AppColors.blue2),
                  _sumItem('مديونيات', '${totalDebt.toStringAsFixed(0)} ج', AppColors.red2),
                ],
              ),
            ),
          ),
        // Search
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.trim()),
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                hintText: '🔍 بحث باسم المستأجر أو الرقم...',
                hintStyle: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
          ),
        // Filter chips
        if (all.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              children: [
                _chip('الكل', 'all', '📋'),
                _chip('نشط', 'active', '✅'),
                _chip('متوقف', 'paused', '⏸'),
                _chip('منتهي', 'ended', '❌'),
                _chip('عليهم دين', 'debt', '🔴'),
                _chip('سدّد جزئي', 'partial', '◑'),
                _chip('مؤجَّل', 'deferred', '⏰'),
                _chip('مسدّدين', 'clear', '🟢'),
              ],
            ),
          ),
        // List
        Expanded(
          child: rentals.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏠', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(all.isEmpty ? 'لا توجد خطوط مؤجرة' : 'لا توجد نتائج',
                        style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rentals.length,
                  itemBuilder: (_, i) => _RentalCard(rental: rentals[i]),
                ),
        ),
      ],
    );
  }

  List<Rental> _apply(List<Rental> all, AppProvider prov) {
    var list = all;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) {
        final g = prov.db.groups.firstWhere((x) => x.id == r.gid, orElse: () => Group(id: '', phone: ''));
        return r.name.toLowerCase().contains(q) ||
            (r.wa ?? '').contains(q) || (r.wa2 ?? '').contains(q) || g.phone.contains(q);
      }).toList();
    }
    switch (_filter) {
      case 'active':   return list.where((r) => r.status == 'active').toList();
      case 'paused':   return list.where((r) => r.status == 'paused').toList();
      case 'ended':    return list.where((r) => r.status == 'ended').toList();
      case 'debt':     return list.where((r) => r.hasDebt).toList();
      case 'partial':  return list.where((r) => r.partlyPaid).toList();
      case 'deferred': return list.where((r) => r.isDeferred).toList();
      case 'clear':    return list.where((r) => !r.hasDebt).toList();
      default:         return list;
    }
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

  Widget _sumItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        Text(val, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
      ],
    );
  }

  void _showAddRental(BuildContext context) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddRentalSheet(rental: null),
    );
  }
}

class _RentalCard extends StatefulWidget {
  final Rental rental;
  const _RentalCard({required this.rental});
  @override
  State<_RentalCard> createState() => _RentalCardState();
}

class _RentalCardState extends State<_RentalCard> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final rental = widget.rental;
    final prov = context.watch<AppProvider>();
    final g = prov.db.groups.firstWhere((x) => x.id == rental.gid, orElse: () => Group(id: '', phone: '—'));
    final statusColor = rental.status == 'active' ? AppColors.green : rental.status == 'paused' ? AppColors.orange : AppColors.muted;
    final statusLabel = rental.status == 'active' ? '✅ نشط' : rental.status == 'paused' ? '⏸ متوقف' : '❌ منتهي';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFe8f4fd), Color(0xFFdbeeff)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppColors.blueMid, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rental.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 16)),
                      Text('خط: ${g.phone}', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(statusLabel, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                        if (rental.partlyPaid)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                            child: Text('◑ سدّد جزئي', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.orange)),
                          ),
                        if (rental.isDeferred)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                            child: Text('⏰ مؤجَّل حتى ${rental.deferralDate}', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.purple)),
                          ),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${rental.rent.toStringAsFixed(0)} ج/م', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue3, fontSize: 15)),
                    if (rental.balance < 0)
                      Text('مديونية: ${(-rental.balance).toStringAsFixed(0)} ج', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.red2, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (rental.wa != null && rental.wa!.isNotEmpty)
                _btn('💬 واتساب', AppColors.waGreen, () => _openWA(rental)),
              _btn('💰 دفع', AppColors.blue2, () => _showPayment(context, rental)),
              _btn('⏰ تأجيل', AppColors.purple, () => _showDeferral(context, rental)),
              _btn('✏️ تعديل', AppColors.blueLight, () => _edit(context, rental), textColor: AppColors.blue2),
              if (rental.log.isNotEmpty)
                _btn(_showHistory ? '🔼 إخفاء السجل' : '📋 السجل (${rental.log.length})',
                    AppColors.blueLight, () => setState(() => _showHistory = !_showHistory),
                    textColor: AppColors.blue2),
              _btn('🗑 حذف', AppColors.red, () => _delete(context, rental)),
            ]),
          ),

          // Payment history
          if (_showHistory && rental.log.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFf7f9fc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: rental.log.asMap().entries.map((e) {
                  final entry = e.value;
                  final amount = (entry['amount'] ?? 0).toDouble();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFf0f0f0)))),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(entry['desc'] ?? '', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(entry['date'] ?? '', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                      ])),
                      if (amount != 0)
                        Text('${amount > 0 ? "+" : ""}${amount.toStringAsFixed(0)} ج',
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700,
                                color: amount >= 0 ? AppColors.green : AppColors.red2)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.read<AppProvider>().deleteRentalLogEntry(rental.id, e.key),
                        child: Icon(Icons.delete_outline, size: 15, color: AppColors.muted),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeferral(BuildContext context, Rental r) {
    final noteCtrl = TextEditingController(text: r.deferralNote ?? '');
    DateTime picked = r.deferralDate != null
        ? (DateTime.tryParse(r.deferralDate!) ?? DateTime.now().add(const Duration(days: 7)))
        : DateTime.now().add(const Duration(days: 7));
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('⏰ تأجيل دفع - ${r.name}', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_today, color: AppColors.purple),
              title: Text('مؤجَّل حتى: ${picked.day}/${picked.month}/${picked.year}', style: GoogleFonts.cairo(fontSize: 13)),
              onTap: () async {
                final d = await showDatePicker(context: dialogCtx, initialDate: picked, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setLocal(() => picked = d);
              },
            ),
            TextField(controller: noteCtrl, style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(hintText: 'سبب التأجيل (اختياري)', hintStyle: GoogleFonts.cairo(fontSize: 12))),
          ]),
          actions: [
            if (r.isDeferred)
              TextButton(
                onPressed: () { context.read<AppProvider>().setRentalDeferral(r.id, null, null); Navigator.pop(dialogCtx); },
                child: Text('إلغاء التأجيل', style: GoogleFonts.cairo(color: AppColors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('إغلاق', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
              onPressed: () {
                final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                context.read<AppProvider>().setRentalDeferral(r.id, dateStr, noteCtrl.text.trim());
                Navigator.pop(dialogCtx);
              },
              child: Text('تأجيل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  Widget _btn(String label, Color bg, VoidCallback onTap, {Color textColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: GoogleFonts.cairo(color: textColor, fontWeight: FontWeight.w700, fontSize: 11)),
      ),
    );
  }

  // Phase 6: رسالة واتساب ديناميكية — حجم الباقة + السعر + المديونية + الإجمالي
  void _openWA(Rental r) async {
    final phone = (r.wa ?? '').replaceFirst(RegExp(r'^0'), '20');
    final pkgSize = r.packageSize?.trim().isNotEmpty == true
        ? r.packageSize!
        : 'باقة الخط';
    final pkgPrice = r.effectivePrice;
    final oldDebt = r.balance < 0 ? -r.balance : 0.0;
    final total = pkgPrice + oldDebt;
    final body = 'السلام عليكم يا ${r.name}، تذكير بتجديد إيجار الخط.\n'
        'باقتك الحالية هي $pkgSize بقيمة ${pkgPrice.toStringAsFixed(0)} ج.\n'
        'المديونية السابقة: ${oldDebt.toStringAsFixed(0)} ج.\n'
        'إجمالي المطلوب سداده: ${total.toStringAsFixed(0)} ج.\n'
        'شكراً لك. 🙏';
    final msg = Uri.encodeComponent(body);
    final url = 'https://wa.me/$phone?text=$msg';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }

  void _showPayment(BuildContext context, Rental r) {
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('💰 دفعة إيجار - ${r.name}', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, keyboardType: TextInputType.number, textDirection: TextDirection.ltr,
              decoration: InputDecoration(hintText: 'المبلغ', hintStyle: GoogleFonts.cairo(fontSize: 13))),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, decoration: InputDecoration(hintText: 'ملاحظة', hintStyle: GoogleFonts.cairo(fontSize: 13))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(ctrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              context.read<AppProvider>().addRentalPayment(r.id, amt, noteCtrl.text.trim());
              Navigator.pop(context);
            },
            child: Text('دفع', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, Rental r) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRentalSheet(rental: r),
    );
  }

  void _delete(BuildContext context, Rental r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الإيجار', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('حذف ${r.name}؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              context.read<AppProvider>().deleteRental(r.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _AddRentalSheet extends StatefulWidget {
  final Rental? rental;
  const _AddRentalSheet({required this.rental});
  @override
  State<_AddRentalSheet> createState() => _AddRentalSheetState();
}

class _AddRentalSheetState extends State<_AddRentalSheet> {
  late TextEditingController _nameCtrl, _rentCtrl, _waCtrl, _wa2Ctrl, _msgCtrl, _notesCtrl;
  // Phase 6
  late TextEditingController _pkgSizeCtrl, _pkgPriceCtrl;
  String? _selectedGroup;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final r = widget.rental;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _rentCtrl = TextEditingController(text: r?.rent.toStringAsFixed(0) ?? '');
    _waCtrl = TextEditingController(text: r?.wa ?? '');
    _wa2Ctrl = TextEditingController(text: r?.wa2 ?? '');
    _msgCtrl = TextEditingController(text: r?.msg ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _pkgSizeCtrl = TextEditingController(text: r?.packageSize ?? '');
    _pkgPriceCtrl = TextEditingController(
        text: (r?.packagePrice ?? 0) > 0
            ? (r!.packagePrice).toStringAsFixed(0)
            : '');
    _selectedGroup = r?.gid;
    _status = r?.status ?? 'active';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return ModalShell(
      title: widget.rental == null ? '🏠 إضافة خط مؤجر' : '✏️ تعديل الإيجار',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(onPressed: _save, child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700))),
      ],
      children: [
        AppFormField(label: 'اسم المستأجر', controller: _nameCtrl),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الخط الرئيسي', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                initialValue: _selectedGroup,
                decoration: const InputDecoration(),
                hint: Text('اختر الخط', style: GoogleFonts.cairo(fontSize: 13)),
                items: prov.db.groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.phone, style: GoogleFonts.cairo(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _selectedGroup = v),
              ),
            ],
          )),
          const SizedBox(width: 10),
          Expanded(child: AppFormField(label: 'سعر الإيجار / شهر', controller: _rentCtrl, keyboardType: TextInputType.number, textDirection: TextDirection.ltr)),
        ]),
        const SizedBox(height: 12),
        AppFormField(label: '📱 رقم واتساب 1 (رئيسي)', controller: _waCtrl, textDirection: TextDirection.ltr, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        AppFormField(label: '📱 رقم واتساب 2 (احتياطي)', controller: _wa2Ctrl, textDirection: TextDirection.ltr, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        // Phase 6: تفاصيل الباقة للرسالة الديناميكية + الفوترة الآلية
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueMid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📦 تفاصيل الباقة (للرسالة + الفوترة الآلية)',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue2)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: AppFormField(
                    label: 'حجم الباقة',
                    controller: _pkgSizeCtrl,
                    hint: 'مثال: 20 جيجا',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppFormField(
                    label: 'سعر الباقة/شهر',
                    controller: _pkgPriceCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    hint: '0',
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                  'هتتخصم تلقائياً يوم 1 أو 15 (حسب دورة الخط) من الرصيد',
                  style: GoogleFonts.cairo(
                      fontSize: 10, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حالة الإيجار', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(),
              items: [
                DropdownMenuItem(value: 'active', child: Text('✅ نشط', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem(value: 'paused', child: Text('⏸ متوقف', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem(value: 'ended', child: Text('❌ منتهي', style: GoogleFonts.cairo(fontSize: 13))),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppFormField(label: 'ملاحظات', controller: _notesCtrl),
      ],
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _selectedGroup == null) return;
    final prov = context.read<AppProvider>();
    final rental = Rental(
      id: widget.rental?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      gid: _selectedGroup!,
      name: _nameCtrl.text.trim(),
      rent: double.tryParse(_rentCtrl.text.trim()) ?? 0,
      balance: widget.rental?.balance ?? 0,
      wa: _waCtrl.text.trim().isNotEmpty ? _waCtrl.text.trim() : null,
      wa2: _wa2Ctrl.text.trim().isNotEmpty ? _wa2Ctrl.text.trim() : null,
      msg: _msgCtrl.text.trim().isNotEmpty ? _msgCtrl.text.trim() : null,
      status: _status,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      log: widget.rental?.log ?? [],
      packageSize: _pkgSizeCtrl.text.trim().isNotEmpty
          ? _pkgSizeCtrl.text.trim()
          : null,
      packagePrice: double.tryParse(_pkgPriceCtrl.text.trim()) ?? 0,
      lastBilledMonth: widget.rental?.lastBilledMonth,
    );
    if (widget.rental == null) {
      prov.addRental(rental);
    } else {
      prov.editRental(rental);
    }
    Navigator.pop(context);
  }
}
