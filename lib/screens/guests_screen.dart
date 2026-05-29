// lib/screens/guests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../widgets/common.dart';
import '../utils/phone_utils.dart';
import '../utils/print_helper.dart';
import '../widgets/member_card.dart';

class GuestsScreen extends StatefulWidget {
  const GuestsScreen({super.key});
  @override
  State<GuestsScreen> createState() => _GuestsScreenState();
}

class _GuestsScreenState extends State<GuestsScreen> {
  String _search = '';
  String _filter = 'all'; // all | uncollected | unpaid

  void _printGuests(BuildContext context, AppProvider prov, List<GuestUser> guestList, List<Member> memberGuests) {
    final rows = <List<String>>[];
    for (final g in guestList) {
      rows.add([
        g.clientName,
        g.clientPhone,
        g.dealerName ?? '-',
        '${g.clientAmount.toStringAsFixed(0)} ج',
        '${g.dealerCost.toStringAsFixed(0)} ج',
        '${g.profit.toStringAsFixed(0)} ج',
        g.isCollected ? 'محصَّل' : 'لم يُحصَّل',
        g.isPaid ? 'مدفوع' : 'لم يُدفَع',
      ]);
    }
    for (final m in memberGuests) {
      final grp = prov.db.groups.where((g) => g.id == m.gid).firstOrNull;
      rows.add([
        m.name,
        m.phone,
        grp?.phone ?? '-',
        '${m.price.toStringAsFixed(0)} ج',
        '-',
        '-',
        m.package,
        'عميل ضيف',
      ]);
    }
    PrintHelper.printTable(
      context: context,
      title: 'قائمة الضيوف',
      subtitle: 'إجمالي: ${rows.length} ضيف',
      headers: ['الاسم', 'الرقم', 'التاجر/المجموعة', 'من العميل', 'للتاجر', 'الربح', 'الباقة/الحالة', 'الوضع'],
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final all  = prov.db.guestUsers;
    // Members marked as 'guest' type
    final memberGuests = prov.db.members.where((m) => m.type == 'guest').toList();

    List<GuestUser> list = all.where((g) {
      if (_filter == 'uncollected' && g.isCollected) return false;
      if (_filter == 'unpaid'      && g.isPaid)       return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return g.clientName.toLowerCase().contains(q) ||
            g.clientPhone.contains(q) ||
            (g.dealerName ?? '').toLowerCase().contains(q) ||
            (g.dealerPhone ?? '').contains(q);
      }
      return true;
    }).toList();

    // Filter member-guests by search
    final filteredMemberGuests = _search.isNotEmpty
        ? memberGuests.where((m) {
            final q = _search.toLowerCase();
            return m.name.toLowerCase().contains(q) || m.phone.contains(q);
          }).toList()
        : memberGuests;

    final totalCollect = list.fold<double>(0, (s, g) => s + g.clientAmount);
    final totalCost    = list.fold<double>(0, (s, g) => s + g.dealerCost);
    final totalProfit  = totalCollect - totalCost;
    final totalCount   = all.length + memberGuests.length;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('👥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(child: Text('الضيوف',
                  style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.blue2))),
              IconButton(
                onPressed: () => _printGuests(context, prov, list, filteredMemberGuests),
                icon: const Icon(Icons.print_outlined, color: AppColors.blue2),
                tooltip: 'طباعة',
              ),
              ElevatedButton.icon(
                onPressed: () => _showForm(context, prov, null),
                icon: const Icon(Icons.add, size: 16),
                label: Text('إضافة', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // Stats
            Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('$totalCount ضيف', AppColors.blueLight, AppColors.blue2),
              _chip('${totalCollect.toStringAsFixed(0)} ج محصَّل', AppColors.greenLight, AppColors.green),
              _chip('${totalCost.toStringAsFixed(0)} ج للتجار', AppColors.redLight, AppColors.red2),
              _chip('${totalProfit.toStringAsFixed(0)} ج ربح', AppColors.orangeLight, AppColors.orange),
            ]),
          ]),
        ),
        const Divider(height: 1),

        // ── Search ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: '🔍 بحث بالاسم أو رقم العميل أو التاجر...',
              hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),

        // ── Filters ──────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            _filterChip('all', 'الكل'),
            const SizedBox(width: 8),
            _filterChip('uncollected', '💰 لم يُحصَّل'),
            const SizedBox(width: 8),
            _filterChip('unpaid', '✅ لم يُدفَع للتاجر'),
          ]),
        ),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: (list.isEmpty && filteredMemberGuests.isEmpty)
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('👥', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('لا يوجد ضيوف', style: GoogleFonts.cairo(fontSize: 15, color: AppColors.muted, fontWeight: FontWeight.w700)),
                  Text('اضغط «إضافة» لتسجيل عميل ضيف', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // GuestUser cards
                    ...list.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GuestCard(
                        guest: g,
                        onEdit:   () => _showForm(context, prov, g),
                        onDelete: () => _deleteDialog(context, prov, g),
                        onTransfer: () => _transferDialog(context, prov, g),
                      ),
                    )),
                    // Member-type guests section
                    if (filteredMemberGuests.isNotEmpty) ...[
                      if (list.isNotEmpty) const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('🧳 ضيوف من قائمة العملاء',
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const Expanded(child: Divider()),
                        ]),
                      ),
                      ...filteredMemberGuests.map((m) {
                        final grp = prov.db.groups.where((g) => g.id == m.gid).firstOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MemberGuestCard(member: m, group: grp),
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
  );

  Widget _filterChip(String value, String label) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.blue2 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.blue2 : AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.cairo(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.muted)),
      ),
    );
  }

  void _showForm(BuildContext context, AppProvider prov, GuestUser? existing) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuestForm(existing: existing),
    );
  }

  void _deleteDialog(BuildContext context, AppProvider prov, GuestUser g) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الضيف', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('حذف ${g.clientName}؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () { prov.deleteGuestUser(g.id); Navigator.pop(context); },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _transferDialog(BuildContext context, AppProvider prov, GuestUser g) {
    if (prov.db.groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يوجد مجموعات', style: GoogleFonts.cairo())));
      return;
    }
    String? gid = prov.db.groups.first.id;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🔄 تحويل لعميل دائم', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('سيتم نقل ${g.clientName} إلى قائمة عملاء المجموعة المختارة.', style: GoogleFonts.cairo(fontSize: 13)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: gid,
            decoration: InputDecoration(labelText: 'اختر المجموعة', labelStyle: GoogleFonts.cairo()),
            items: prov.db.groups.map((gr) => DropdownMenuItem(
              value: gr.id,
              child: Text(gr.phone, style: GoogleFonts.cairo(fontSize: 13)),
            )).toList(),
            onChanged: (v) => ss(() => gid = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              prov.transferGuestToPermanent(g.id, gid ?? prov.db.groups.first.id);
              Navigator.pop(ctx);
            },
            child: Text('تحويل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      )),
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────
class _GuestCard extends StatelessWidget {
  final GuestUser    guest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTransfer;
  const _GuestCard({required this.guest, required this.onEdit, required this.onDelete, required this.onTransfer});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        // ── Client + dealer info ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(guest.clientName,
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.text)),
              Text(guest.clientPhone,
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                  textDirection: TextDirection.ltr),
              if (guest.dealerName != null || guest.dealerPhone != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Text('🏪 ', style: TextStyle(fontSize: 12)),
                  Text(guest.dealerName ?? '', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.blue2, fontWeight: FontWeight.w700)),
                  if (guest.dealerPhone != null) ...[
                    const SizedBox(width: 6),
                    Text(guest.dealerPhone!, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted), textDirection: TextDirection.ltr),
                  ],
                ]),
              ],
              if (guest.startDate != null) ...[
                const SizedBox(height: 2),
                Text('منذ: ${guest.startDate}', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
              ],
            ])),
            // Amounts
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _amountBadge('${guest.clientAmount.toStringAsFixed(0)} ج', 'من العميل', AppColors.greenLight, AppColors.green),
              const SizedBox(height: 6),
              _amountBadge('${guest.dealerCost.toStringAsFixed(0)} ج', 'للتاجر', AppColors.redLight, AppColors.red2),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(6)),
                child: Text('ربح: ${guest.profit.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.orange)),
              ),
            ]),
          ]),
        ),

        // ── Status toggles ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            _toggle('💰 تحصّل من العميل', guest.isCollected, AppColors.green, AppColors.greenLight,
                () => prov.toggleGuestCollected(guest.id)),
            const SizedBox(width: 8),
            _toggle('✅ دُفع للتاجر', guest.isPaid, AppColors.blue2, AppColors.blueLight,
                () => prov.toggleGuestPaid(guest.id)),
          ]),
        ),

        // ── Actions ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            _btn('✏️ تعديل',          AppColors.blueLight, AppColors.blue2, onEdit),
            const SizedBox(width: 8),
            _btn('🔄 تحويل لدائم', const Color(0xFFF3E5F5), const Color(0xFF7B1FA2), onTransfer),
            const Spacer(),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline, color: AppColors.muted, size: 20),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _amountBadge(String amount, String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(amount, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
      Text(label,  style: GoogleFonts.cairo(fontSize: 9,  color: fg)),
    ]),
  );

  Widget _toggle(String label, bool active, Color ac, Color bg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? bg : const Color(0xFFf5f5f5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? ac.withValues(alpha: 0.4) : AppColors.border),
          ),
          child: Text(label, style: GoogleFonts.cairo(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: active ? ac : AppColors.muted)),
        ),
      );

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ),
      );
}

// ─── Form ────────────────────────────────────────────────────────────────────
class _GuestForm extends StatefulWidget {
  final GuestUser? existing;
  const _GuestForm({this.existing});
  @override
  State<_GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends State<_GuestForm> {
  late TextEditingController _clientNameCtrl, _clientPhoneCtrl;
  late TextEditingController _dealerNameCtrl, _dealerPhoneCtrl;
  late TextEditingController _clientAmountCtrl, _dealerCostCtrl;
  late TextEditingController _notesCtrl;
  String? _startDate;
  String? _clientPhoneError;
  String? _dealerPhoneError;

  static String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _clientNameCtrl   = TextEditingController(text: e?.clientName   ?? '');
    _clientPhoneCtrl  = TextEditingController(text: e?.clientPhone  ?? '');
    _dealerNameCtrl   = TextEditingController(text: e?.dealerName   ?? '');
    _dealerPhoneCtrl  = TextEditingController(text: e?.dealerPhone  ?? '');
    _clientAmountCtrl = TextEditingController(text: e != null ? e.clientAmount.toStringAsFixed(0) : '');
    _dealerCostCtrl   = TextEditingController(text: e != null ? e.dealerCost.toStringAsFixed(0)   : '');
    _notesCtrl        = TextEditingController(text: e?.notes        ?? '');
    _startDate        = e?.startDate ?? _todayStr(); // default to today
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose(); _clientPhoneCtrl.dispose();
    _dealerNameCtrl.dispose(); _dealerPhoneCtrl.dispose();
    _clientAmountCtrl.dispose(); _dealerCostCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalShell(
      title: widget.existing == null ? '👥 إضافة ضيف' : '✏️ تعديل بيانات الضيف',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(onPressed: _save, child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700))),
      ],
      children: [
        // Client info
        Text('👤 بيانات العميل', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: AppFormField(label: 'الاسم', controller: _clientNameCtrl)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFormField(
                  label: 'رقم الموبايل',
                  controller: _clientPhoneCtrl,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneInputFormatter()],
                  onChanged: (v) {
                    final prov = context.read<AppProvider>();
                    final fmtErr = validatePhone(v);
                    String? dupErr;
                    if (fmtErr == null && v.isNotEmpty) {
                      final existing = prov.db.guestUsers
                          .where((g) => g.id != (widget.existing?.id ?? ''))
                          .map((g) => g.clientPhone);
                      dupErr = checkDuplicate(v, [...existing]);
                    }
                    setState(() => _clientPhoneError = fmtErr ?? dupErr);
                  },
                ),
                if (_clientPhoneError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_clientPhoneError!, style: GoogleFonts.cairo(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // Dealer info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🏪 بيانات التاجر المستضيف', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.blue2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: AppFormField(label: 'اسم التاجر', controller: _dealerNameCtrl)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppFormField(
                      label: 'رقم التاجر',
                      controller: _dealerPhoneCtrl,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneInputFormatter()],
                      onChanged: (v) {
                        setState(() => _dealerPhoneError = validatePhone(v));
                      },
                    ),
                    if (_dealerPhoneError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_dealerPhoneError!, style: GoogleFonts.cairo(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        // Amounts
        Text('💰 المبالغ', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: AppFormField(
            label: 'من العميل (ج)',
            controller: _clientAmountCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
          )),
          const SizedBox(width: 10),
          Expanded(child: AppFormField(
            label: 'للتاجر (ج)',
            controller: _dealerCostCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
          )),
        ]),
        const SizedBox(height: 12),
        // Date picker
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate != null ? DateTime.tryParse(_startDate!) ?? now : now,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              locale: const Locale('ar'),
            );
            if (picked != null) {
              setState(() => _startDate =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.muted),
              const SizedBox(width: 8),
              Text(
                _startDate ?? 'تاريخ البداية (اختياري)',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: _startDate != null ? AppColors.text : AppColors.muted,
                ),
              ),
              const Spacer(),
              if (_startDate != null)
                GestureDetector(
                  onTap: () => setState(() => _startDate = null),
                  child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        AppFormField(label: 'ملاحظات', controller: _notesCtrl),
      ],
    );
  }

  void _save() {
    if (_clientNameCtrl.text.trim().isEmpty) return;
    if (_clientPhoneError != null || _dealerPhoneError != null) return;
    final prov = context.read<AppProvider>();
    final e = widget.existing;
    final guest = GuestUser(
      id: e?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      clientName:   _clientNameCtrl.text.trim(),
      clientPhone:  _clientPhoneCtrl.text.trim(),
      dealerName:   _dealerNameCtrl.text.trim().isNotEmpty  ? _dealerNameCtrl.text.trim()  : null,
      dealerPhone:  _dealerPhoneCtrl.text.trim().isNotEmpty ? _dealerPhoneCtrl.text.trim() : null,
      clientAmount: double.tryParse(_clientAmountCtrl.text.trim()) ?? 0,
      dealerCost:   double.tryParse(_dealerCostCtrl.text.trim())   ?? 0,
      isCollected:  e?.isCollected  ?? false,
      isPaid:       e?.isPaid       ?? false,
      startDate:    _startDate,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );
    if (e == null) {
      prov.addGuestUser(guest);
    } else {
      prov.editGuestUser(guest);
    }
    Navigator.pop(context);
  }
}

// ─── Member Guest Card ────────────────────────────────────────────
/// Shows a Member whose type == 'guest' inside the guests screen.
/// Tapping opens MemberDrawer for editing (same as flagged_members_screen).
class _MemberGuestCard extends StatelessWidget {
  final Member member;
  final Group? group;
  const _MemberGuestCard({required this.member, this.group});

  @override
  Widget build(BuildContext context) {
    final hasDebt = member.balance < 0;
    return GestureDetector(
      onTap: () => showModalBottomSheet(useRootNavigator: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MemberDrawer(
          member: member,
          group: group ?? Group(id: '', phone: ''),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
          boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(children: [
          // Orange top bar indicates guest-member
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFFF9800),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('🧳 ', style: TextStyle(fontSize: 13)),
                    Text(member.name,
                        style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text)),
                  ]),
                  Text(member.phone,
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                      textDirection: TextDirection.ltr),
                  if (group != null) ...[
                    const SizedBox(height: 2),
                    Text('📡 ${group!.phone}  •  ${member.package}',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2)),
                  ],
                ]),
              ),
              // Balance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasDebt ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasDebt
                      ? '-${(-member.balance).toStringAsFixed(0)} ج'
                      : '${member.balance.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: hasDebt ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
                ),
              ),
            ]),
          ),
          // Hint
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Row(children: [
              const Icon(Icons.touch_app_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('اضغط للتفاصيل والتعديل',
                  style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
