// lib/widgets/member_card_log_edit_sheet.dart
// ✏️ تعديل سطر في سجل العميل — جزء من member_card.dart.
// اتفصل عشان الملف كان 2560 سطر وبقى صعب يتقرا. الكود زي ما هو بالظبط.
part of 'member_card.dart';

class _LogEntryEditSheet extends StatefulWidget {
  final Map<String, dynamic> entry;
  final void Function(String desc, double amount, String date, String time) onSave;
  const _LogEntryEditSheet({required this.entry, required this.onSave});
  @override
  State<_LogEntryEditSheet> createState() => _LogEntryEditSheetState();
}

class _LogEntryEditSheetState extends State<_LogEntryEditSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amtCtrl;
  late bool _isCredit; // true = دفعة (موجب/له) ، false = مديونية (سالب/عليه)
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final amount = (widget.entry['amount'] ?? 0).toDouble();
    _isCredit = amount >= 0;
    _descCtrl = TextEditingController(text: (widget.entry['desc'] ?? '').toString());
    _amtCtrl  = TextEditingController(text: amount == 0 ? '' : amount.abs().toStringAsFixed(0));
    _date = _parseDate((widget.entry['date'] ?? '').toString());
    _time = _parseTime((widget.entry['time'] ?? '').toString());
  }

  @override
  void dispose() { _descCtrl.dispose(); _amtCtrl.dispose(); super.dispose(); }

  // التاريخ مخزّن "d/M/yyyy"
  DateTime? _parseDate(String s) {
    final p = s.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    try { return DateTime(y, m, d); } catch (_) { return null; }
  }

  TimeOfDay? _parseTime(String s) {
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), mi = int.tryParse(p[1]);
    if (h == null || mi == null) return null;
    return TimeOfDay(hour: h.clamp(0, 23), minute: mi.clamp(0, 59));
  }

  String get _dateLabel => _date == null
      ? 'اختر التاريخ'
      : '${_date!.day}/${_date!.month}/${_date!.year}';

  String get _timeLabel => _time == null
      ? 'اختر الوقت (اختياري)'
      : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('✏️ تعديل الحركة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.blue2)),
          const SizedBox(height: 14),

          // البيان / الملاحظة
          TextField(
            controller: _descCtrl,
            style: GoogleFonts.cairo(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'البيان / الملاحظة', labelStyle: GoogleFonts.cairo(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // نوع الحركة: دفعة (له +) أو مديونية (عليه −)
          Text('نوع الحركة', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _typeBtn('➕ دفعة (له)', _isCredit, AppColors.green, () => setState(() => _isCredit = true))),
            const SizedBox(width: 10),
            Expanded(child: _typeBtn('➖ مديونية (عليه)', !_isCredit, AppColors.red2, () => setState(() => _isCredit = false))),
          ]),
          const SizedBox(height: 14),

          // المبلغ
          TextField(
            controller: _amtCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'المبلغ (ج)', labelStyle: GoogleFonts.cairo(), suffixText: 'ج',
              helperText: _isCredit ? 'هيتسجّل موجب (+) للعميل' : 'هيتسجّل سالب (−) على العميل',
              helperStyle: GoogleFonts.cairo(fontSize: 10, color: _isCredit ? AppColors.green : AppColors.red2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // التاريخ + الوقت
          Row(children: [
            Expanded(child: _pickerBtn(Icons.calendar_today, _dateLabel, () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2020), lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            })),
            const SizedBox(width: 10),
            Expanded(child: _pickerBtn(Icons.access_time, _timeLabel, () async {
              final picked = await showTimePicker(
                context: context, initialTime: _time ?? TimeOfDay.now(),
              );
              if (picked != null) setState(() => _time = picked);
            })),
          ]),
          if (_time != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _time = null),
                icon: Icon(Icons.close, size: 14, color: AppColors.muted),
                label: Text('شيل الوقت', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
              ),
            ),
          ],
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue2, foregroundColor: Colors.white),
              onPressed: _save,
              child: Text('💾 حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            )),
          ]),
        ]),
      ),
    );
  }

  void _save() {
    final abs = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    final amount = _isCredit ? abs : -abs;
    final dateStr = _date == null ? '' : '${_date!.day}/${_date!.month}/${_date!.year}';
    final timeStr = _time == null
        ? ''
        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    widget.onSave(_descCtrl.text, amount, dateStr, timeStr);
    Navigator.pop(context);
  }

  Widget _typeBtn(String label, bool active, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color : AppColors.border, width: active ? 1.5 : 1),
      ),
      child: Center(child: Text(label, style: GoogleFonts.cairo(
          fontSize: 12, fontWeight: FontWeight.w700, color: active ? color : AppColors.muted))),
    ),
  );

  Widget _pickerBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.blue2),
        const SizedBox(width: 6),
        Expanded(child: Text(label,
            style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.text),
            overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

// ─── محرّر قوالب رسائل الهدايا ───────────────────────────────────