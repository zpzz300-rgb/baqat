// lib/widgets/rental_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/phone_utils.dart';
import 'common.dart';

class RentalSheet extends StatefulWidget {
  final Group group;
  const RentalSheet({super.key, required this.group});

  @override
  State<RentalSheet> createState() => _RentalSheetState();
}

class _RentalSheetState extends State<RentalSheet> {
  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<AppProvider>();
    final rentals = prov.db.rentals.where((r) => r.gid == widget.group.id).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                const Text('🏠', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إيجار الخط', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.blue2)),
                    Text(widget.group.phone, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700), textDirection: TextDirection.ltr),
                  ],
                ),
                const Spacer(),
                // Add rental button
                if (rentals.isEmpty || rentals.every((r) => r.status == 'ended'))
                  ElevatedButton.icon(
                    onPressed: () => _showRentalForm(context, prov, null),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('تأجير', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // ── Content ─────────────────────────────────────────
          Expanded(
            child: rentals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏠', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('لا يوجد مستأجر حالياً', style: GoogleFonts.cairo(fontSize: 16, color: AppColors.muted, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('اضغط "تأجير" لإضافة مستأجر جديد', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: rentals.map((r) => _RentalCard(rental: r, group: widget.group)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _showRentalForm(BuildContext context, AppProvider prov, Rental? existing) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RentalForm(group: widget.group, existing: existing),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RentalCard extends StatefulWidget {
  final Rental rental;
  final Group group;
  const _RentalCard({required this.rental, required this.group});

  @override
  State<_RentalCard> createState() => _RentalCardState();
}

class _RentalCardState extends State<_RentalCard> {
  bool _showLog = false;

  @override
  Widget build(BuildContext context) {
    final prov   = context.read<AppProvider>();
    final rental = widget.rental;
    final isActive = rental.status == 'active';
    final isPaused = rental.status == 'paused';

    final statusColor  = isActive ? AppColors.green  : isPaused ? AppColors.orange : AppColors.muted;
    final statusBg     = isActive ? AppColors.greenLight : isPaused ? AppColors.orangeLight : const Color(0xFFf5f5f5);
    final statusLabel  = isActive ? '✅ نشط' : isPaused ? '⏸ موقف' : '🔴 منتهي';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // ── Top: name + status ───────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            decoration: BoxDecoration(
              color: statusBg.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rental.name, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
                      if (rental.wa != null && rental.wa!.isNotEmpty)
                        Text(rental.wa!, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted), textDirection: TextDirection.ltr),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.4))),
                  child: Text(statusLabel, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ),

          // ── Financial info ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _infoChip('الإيجار/شهر', '${rental.rent.toStringAsFixed(0)} ج', AppColors.blueLight, AppColors.blue2),
                const SizedBox(width: 8),
                _infoChip(
                  'الرصيد',
                  '${rental.balance >= 0 ? '+' : ''}${rental.balance.toStringAsFixed(0)} ج',
                  rental.balance >= 0 ? AppColors.greenLight : AppColors.redLight,
                  rental.balance >= 0 ? AppColors.green2 : AppColors.red2,
                ),
                if (rental.date != null) ...[
                  const SizedBox(width: 8),
                  _infoChip('منذ', rental.date!, const Color(0xFFf3e5f5), AppColors.purple),
                ],
              ],
            ),
          ),

          // ── Action buttons ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Pay
                _actionBtn('💰 دفعة', AppColors.greenLight, AppColors.green2, () => _showPayDialog(context, prov, rental, true)),
                // Charge
                _actionBtn('➖ خصم', AppColors.redLight, AppColors.red2, () => _showPayDialog(context, prov, rental, false)),
                // Toggle status
                if (rental.status != 'ended') ...[
                  _actionBtn(
                    isActive ? '⏸ إيقاف' : '▶️ تفعيل',
                    isActive ? AppColors.orangeLight : AppColors.greenLight,
                    isActive ? AppColors.orange : AppColors.green,
                    () {
                      prov.toggleRentalStatus(rental.id);
                    },
                  ),
                ],
                // Change renter
                _actionBtn('🔄 تغيير مستأجر', AppColors.blueLight, AppColors.blue3, () => _showChangeRenterDialog(context, prov, rental)),
                // Edit
                _actionBtn('✏️ تعديل', AppColors.blueLight, AppColors.blue3, () {
                  showModalBottomSheet(useRootNavigator: true,
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _RentalForm(group: widget.group, existing: rental),
                  );
                }),
                // Delete
                _actionBtn('🗑 حذف', AppColors.redLight, AppColors.red2, () => _confirmDelete(context, prov, rental)),
                // Log toggle
                _actionBtn(
                  _showLog ? '🔼 إخفاء السجل' : '📋 سجل الدفع',
                  const Color(0xFFf3e5f5),
                  AppColors.purple,
                  () => setState(() => _showLog = !_showLog),
                ),
              ],
            ),
          ),

          // ── Payment log ──────────────────────────────────────
          if (_showLog) ...[
            const Divider(height: 1),
            if (rental.log.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('لا يوجد سجل بعد', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              )
            else
              ...rental.log.map((e) => _logItem(e)),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
          Text(value, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
      ),
    );
  }

  Widget _logItem(Map<String, dynamic> e) {
    final amount = (e['amount'] ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e['desc'] ?? '', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(e['date'] ?? '', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          if (amount != 0)
            Text(
              '${amount > 0 ? '+' : ''}${amount.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: amount > 0 ? AppColors.green2 : AppColors.red2,
              ),
            ),
        ],
      ),
    );
  }

  void _showPayDialog(BuildContext context, AppProvider prov, Rental rental, bool isPay) {
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isPay ? '💰 تسجيل دفعة' : '➖ تسجيل خصم', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [PhoneInputFormatter()],
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(labelText: 'المبلغ (ج)', labelStyle: GoogleFonts.cairo()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(labelText: 'ملاحظة (اختياري)', labelStyle: GoogleFonts.cairo()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              if (isPay) {
                prov.addRentalPayment(rental.id, amount, noteCtrl.text.trim());
              } else {
                prov.addRentalCharge(rental.id, amount, noteCtrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text('تأكيد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showChangeRenterDialog(BuildContext context, AppProvider prov, Rental rental) {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🔄 تغيير المستأجر', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المستأجر الحالي: ${rental.name}', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(labelText: 'اسم المستأجر الجديد', labelStyle: GoogleFonts.cairo()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(labelText: 'رقم الواتساب (اختياري)', labelStyle: GoogleFonts.cairo()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              prov.changeRenter(rental.id, name, phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null);
              Navigator.pop(context);
            },
            child: Text('تغيير', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider prov, Rental rental) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الإيجار', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('سيتم حذف سجل إيجار ${rental.name}. هل أنت متأكد؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              prov.deleteRental(rental.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RentalForm extends StatefulWidget {
  final Group group;
  final Rental? existing;
  const _RentalForm({required this.group, this.existing});

  @override
  State<_RentalForm> createState() => _RentalFormState();
}

class _RentalFormState extends State<_RentalForm> {
  late TextEditingController _nameCtrl, _rentCtrl, _waCtrl, _wa2Ctrl, _notesCtrl;
  String? _date;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl  = TextEditingController(text: e?.name ?? '');
    _rentCtrl  = TextEditingController(text: e != null ? e.rent.toStringAsFixed(0) : '');
    _waCtrl    = TextEditingController(text: e?.wa ?? '');
    _wa2Ctrl   = TextEditingController(text: e?.wa2 ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _date      = e?.date;
    _status    = e?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _rentCtrl.dispose();
    _waCtrl.dispose(); _wa2Ctrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalShell(
      title: widget.existing == null ? '🏠 إضافة مستأجر' : '✏️ تعديل الإيجار',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(
          onPressed: _save,
          child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        ),
      ],
      children: [
        // Name
        AppFormField(label: 'اسم المستأجر', controller: _nameCtrl),
        const SizedBox(height: 12),

        // Rent + Date
        Row(children: [
          Expanded(child: AppFormField(
            label: 'الإيجار / شهر (ج)',
            controller: _rentCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            inputFormatters: [PhoneInputFormatter()],
          )),
          const SizedBox(width: 10),
          Expanded(child: AppDateField(
            label: 'تاريخ البداية',
            initialValue: _date,
            onChanged: (v) => _date = v,
          )),
        ]),
        const SizedBox(height: 12),

        // WhatsApp phones
        AppFormField(
          label: '📱 واتساب 1',
          controller: _waCtrl,
          hint: 'رقم الواتساب',
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneInputFormatter()],
        ),
        const SizedBox(height: 12),
        AppFormField(
          label: '📱 واتساب 2 (اختياري)',
          controller: _wa2Ctrl,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneInputFormatter()],
        ),
        const SizedBox(height: 12),

        // Status
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
                DropdownMenuItem(value: 'paused', child: Text('⏸ موقف', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem(value: 'ended', child: Text('🔴 منتهي', style: GoogleFonts.cairo(fontSize: 13))),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Notes
        AppFormField(label: 'ملاحظات', controller: _notesCtrl),
      ],
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final prov = context.read<AppProvider>();
    final e = widget.existing;
    if (e == null) {
      prov.addRental(Rental(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        gid: widget.group.id,
        name: _nameCtrl.text.trim(),
        rent: double.tryParse(_rentCtrl.text.trim()) ?? 0,
        wa: _waCtrl.text.trim().isNotEmpty ? _waCtrl.text.trim() : null,
        wa2: _wa2Ctrl.text.trim().isNotEmpty ? _wa2Ctrl.text.trim() : null,
        date: _date,
        status: _status,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      ));
    } else {
      prov.editRental(Rental(
        id: e.id,
        gid: e.gid,
        name: _nameCtrl.text.trim(),
        rent: double.tryParse(_rentCtrl.text.trim()) ?? e.rent,
        balance: e.balance,
        wa: _waCtrl.text.trim().isNotEmpty ? _waCtrl.text.trim() : null,
        wa2: _wa2Ctrl.text.trim().isNotEmpty ? _wa2Ctrl.text.trim() : null,
        date: _date,
        status: _status,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        log: e.log,
      ));
    }
    Navigator.pop(context);
  }
}
