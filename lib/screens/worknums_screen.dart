// lib/screens/worknums_screen.dart
// مخزون أرقام العمل — مع فلاتر، تتبع آخر اتصال، وتذكيرات قبل التقفيل الجبري

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class WorkNumsScreen extends StatefulWidget {
  const WorkNumsScreen({super.key});
  @override
  State<WorkNumsScreen> createState() => _WorkNumsScreenState();
}

class _WorkNumsScreenState extends State<WorkNumsScreen> {
  String _search = '';
  String _providerFilter = 'all'; // all/etisalat/orange/vodafone/we
  String _statusFilter = 'all';   // all/available/reserved/needsRenewal/damaged
  String _urgencyFilter = 'all';  // all/needsContact/overdue

  static const _statusLabel = {
    'available': '✅ متاح',
    'reserved': '🔒 محجوز',
    'needsRenewal': '🔄 يحتاج تجديد',
    'damaged': '❌ تالف',
  };
  static const _statusColor = {
    'available': Color(0xFF2E7D32),
    'reserved': Color(0xFF1565C0),
    'needsRenewal': Color(0xFFE65100),
    'damaged': Color(0xFFC62828),
  };

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final all = prov.db.workNums;

    // ── Filter pipeline ──
    final filtered = all.where((w) {
      // search
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final hit = w.phone.contains(_search) ||
            w.label.toLowerCase().contains(q) ||
            (w.lastSerial ?? '').toLowerCase().contains(q) ||
            (w.previousOwner ?? '').toLowerCase().contains(q);
        if (!hit) return false;
      }
      if (_providerFilter != 'all' && w.provider != _providerFilter) return false;
      if (_statusFilter != 'all' && w.status != _statusFilter) return false;
      if (_urgencyFilter == 'needsContact' && !prov.worknumNeedsReminder(w)) return false;
      if (_urgencyFilter == 'overdue') {
        final r = prov.worknumDaysUntilDeactivation(w);
        if (r == null || r > 0) return false;
      }
      return true;
    }).toList();

    // sort: overdue first, then needs-contact, then by daysSinceContact desc
    filtered.sort((a, b) {
      final ra = prov.worknumDaysUntilDeactivation(a) ?? 9999;
      final rb = prov.worknumDaysUntilDeactivation(b) ?? 9999;
      return ra.compareTo(rb);
    });

    // ── Stats ──
    final needsContact = all.where((w) => prov.worknumNeedsReminder(w)).length;
    final overdue = all.where((w) {
      final r = prov.worknumDaysUntilDeactivation(w);
      return r != null && r <= 0;
    }).length;

    return Column(children: [
      // ── Header bar ──
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('📋 مخزون أرقام العمل',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15)),
              Text('تتبّع آخر اتصال وتذكير قبل التقفيل الجبري',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
          GestureDetector(
            onTap: () => _showModal(context, null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [Color(0xFF1565c0), Color(0xFF2196f3)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('+ إضافة',
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ]),
      ),

      // ── Stats banner ──
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(children: [
          _statChip('📦 ${all.length}', 'إجمالي', AppColors.blue2, AppColors.blueLight),
          const SizedBox(width: 6),
          _statChip('⚠️ $needsContact', 'محتاج اتصال', const Color(0xFFE65100),
              const Color(0xFFFFF3E0)),
          const SizedBox(width: 6),
          _statChip('🔴 $overdue', 'متأخر', AppColors.red2, AppColors.redLight),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showReminderSettings(prov),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: const Icon(Icons.tune, size: 18, color: AppColors.blue2),
            ),
          ),
        ]),
      ),

      // ── Search ──
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: '🔍 بحث برقم، اسم، سيريال، أو صاحب سابق...',
            hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),

      // ── Filters: provider ──
      _filterRow([
        _filterChip('الكل', _providerFilter == 'all',
            () => setState(() => _providerFilter = 'all')),
        _filterChip('🟢 اتصالات', _providerFilter == 'etisalat',
            () => setState(() => _providerFilter = 'etisalat')),
        _filterChip('🟠 أورانج', _providerFilter == 'orange',
            () => setState(() => _providerFilter = 'orange')),
        _filterChip('🔴 فودافون', _providerFilter == 'vodafone',
            () => setState(() => _providerFilter = 'vodafone')),
        _filterChip('🟣 WE', _providerFilter == 'we',
            () => setState(() => _providerFilter = 'we')),
      ]),

      // ── Filters: urgency + status ──
      _filterRow([
        _filterChip('الكل', _urgencyFilter == 'all' && _statusFilter == 'all',
            () => setState(() {
                  _urgencyFilter = 'all';
                  _statusFilter = 'all';
                })),
        _filterChip('⚠️ محتاج اتصال', _urgencyFilter == 'needsContact',
            () => setState(() => _urgencyFilter = 'needsContact')),
        _filterChip('🔴 متأخر', _urgencyFilter == 'overdue',
            () => setState(() => _urgencyFilter = 'overdue')),
        for (final s in _statusLabel.entries)
          _filterChip(s.value, _statusFilter == s.key,
              () => setState(() => _statusFilter = s.key)),
      ]),
      const SizedBox(height: 8),

      // ── List ──
      Expanded(
        child: filtered.isEmpty
            ? Center(
                child: Text('لا توجد أرقام مطابقة',
                    style: GoogleFonts.cairo(color: AppColors.muted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _card(prov, filtered[i]),
              ),
      ),
    ]);
  }

  // ── Card ──
  Widget _card(AppProvider prov, WorkNum w) {
    final remaining = prov.worknumDaysUntilDeactivation(w);
    final inWindow = prov.worknumNeedsReminder(w);
    final isOverdue = remaining != null && remaining <= 0;

    final statusColor = _statusColor[w.status] ?? AppColors.muted;
    final statusTxt = _statusLabel[w.status] ?? w.status;

    final provColor = MainLine.providerColors[w.provider ?? ''] ?? AppColors.blue;
    final provEmoji = MainLine.providerEmojis[w.provider ?? ''] ?? '📡';
    final provName = MainLine.providerNames[w.provider ?? ''] ?? '';

    final borderColor = isOverdue
        ? AppColors.red
        : (inWindow ? const Color(0xFFE65100) : AppColors.border);
    final borderWidth = (isOverdue || inWindow) ? 2.0 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(color: AppColors.blue2.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(children: [
        // ── Urgency banner ──
        if (isOverdue)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.red.withValues(alpha: 0.08),
            child: Text('🔴 متأخر! اتجاوز ${-remaining} يوم بعد التقفيل المتوقع',
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.red2)),
          )
        else if (inWindow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFFFFF3E0),
            child: Text('⚠️ اتصل قبل ما يتقفل خلال $remaining يوم',
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
          ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row: phone + badges
            Row(children: [
              Expanded(
                child: Text(w.phone,
                    textDirection: TextDirection.ltr,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900,
                        color: AppColors.blue2,
                        fontSize: 17)),
              ),
              _badge(statusTxt, statusColor.withValues(alpha: 0.12), statusColor),
            ]),
            const SizedBox(height: 6),
            // Label + provider + system
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (w.label.isNotEmpty)
                _smallChip(w.label, AppColors.blueLight, AppColors.blue2),
              if (w.provider != null)
                _smallChip('$provEmoji $provName',
                    provColor.withValues(alpha: 0.12), provColor),
              if (w.packageSystem != null && w.packageSystem!.isNotEmpty)
                _smallChip('📦 ${w.packageSystem}',
                    const Color(0xFFF3E5F5), const Color(0xFF6A1B9A)),
            ]),
            const SizedBox(height: 8),
            // Last contact + days + serial
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (w.lastContactDate != null) ...[
                    Text('📞 آخر اتصال: ${w.lastContactDate}',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.text)),
                    if (w.daysSinceContact != null)
                      Text('من ${w.daysSinceContact} يوم',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: isOverdue
                                  ? AppColors.red
                                  : (inWindow ? const Color(0xFFE65100) : AppColors.muted))),
                  ] else
                    Text('📞 لم يُسجَّل اتصال بعد',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  if (w.lastSerial != null && w.lastSerial!.isNotEmpty)
                    Text('🔢 سيريال: ${w.lastSerial}',
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                  if (w.offerExpiryDate != null)
                    Text('🗓 ينتهي: ${w.offerExpiryDate}',
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                  if (w.previousOwner != null && w.previousOwner!.isNotEmpty)
                    Text('👤 سابقاً: ${w.previousOwner}',
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                ]),
              ),
            ]),
            if (w.notes != null && w.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📝 ${w.notes}',
                  style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green2,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text('سجّل اتصال اليوم',
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Provider.of<AppProvider>(context, listen: false).recordWorkNumContact(w.id);
                    AppSnackbar.show(context, '✅ تم تسجيل الاتصال');
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.blue, size: 22),
                onPressed: () => _showModal(context, w),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 22),
                onPressed: () => Provider.of<AppProvider>(context, listen: false).deleteWorkNum(w.id),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Reusable widgets ──
  Widget _statChip(String value, String label, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
        ]),
      ),
    );
  }

  Widget _filterRow(List<Widget> chips) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: chips,
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.blue2 : const Color(0xFFf0f4f8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.blue2 : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.text)),
      ),
    );
  }

  Widget _badge(String txt, Color bg, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _smallChip(String txt, Color bg, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );

  // ── Reminder settings dialog ──
  void _showReminderSettings(AppProvider prov) {
    final deactCtrl = TextEditingController(text: '${prov.worknumDeactivationDays}');
    final reminCtrl = TextEditingController(text: '${prov.worknumReminderDays}');
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('⚙️ إعدادات التذكير',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.blueLight, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'الشركات بتقفل الخط جبري لو معدلش اتصالاً لمدة معينة. '
                'البرنامج هيذكّرك يومياً قبل الموعد ده.',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deactCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'أيام التقفيل الجبري (افتراضي 90)',
                labelStyle: GoogleFonts.cairo(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reminCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'أيام التذكير قبل التقفيل (افتراضي 15)',
                labelStyle: GoogleFonts.cairo(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () {
                final d = int.tryParse(deactCtrl.text.trim()) ?? prov.worknumDeactivationDays;
                final r = int.tryParse(reminCtrl.text.trim()) ?? prov.worknumReminderDays;
                if (d > 0) prov.setWorknumDeactivationDays(d);
                if (r > 0) prov.setWorknumReminderDays(r);
                Navigator.pop(context);
                AppSnackbar.show(context, '✅ تم حفظ الإعدادات');
              },
              child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add/Edit modal ──
  void _showModal(BuildContext context, WorkNum? wn) {
    final phoneCtrl = TextEditingController(text: wn?.phone ?? '');
    final labelCtrl = TextEditingController(text: wn?.label ?? '');
    final notesCtrl = TextEditingController(text: wn?.notes ?? '');
    final serialCtrl = TextEditingController(text: wn?.lastSerial ?? '');
    final systemCtrl = TextEditingController(text: wn?.packageSystem ?? '');
    final ownerCtrl = TextEditingController(text: wn?.previousOwner ?? '');
    final overrideCtrl = TextEditingController(
        text: wn?.reminderDaysOverride != null ? '${wn!.reminderDaysOverride}' : '');
    String? provider = wn?.provider;
    String status = wn?.status ?? 'available';
    String? lastContact = wn?.lastContactDate;
    String? offerExpiry = wn?.offerExpiryDate;

    Future<String?> pickDate(String? init) async {
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(init ?? '') ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (d == null) return init;
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => ModalShell(
          title: wn == null ? '📋 إضافة رقم عمل' : '✏️ تعديل رقم عمل',
          actions: [
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () {
                if (phoneCtrl.text.trim().isEmpty) return;
                final prov = context.read<AppProvider>();
                final m = WorkNum(
                  id: wn?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  phone: phoneCtrl.text.trim(),
                  label: labelCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  provider: provider,
                  packageSystem: systemCtrl.text.trim().isEmpty ? null : systemCtrl.text.trim(),
                  lastContactDate: lastContact,
                  lastSerial: serialCtrl.text.trim().isEmpty ? null : serialCtrl.text.trim(),
                  status: status,
                  offerExpiryDate: offerExpiry,
                  previousOwner: ownerCtrl.text.trim().isEmpty ? null : ownerCtrl.text.trim(),
                  reminderDaysOverride: int.tryParse(overrideCtrl.text.trim()),
                );
                if (wn == null) {
                  prov.addWorkNum(m);
                } else {
                  prov.editWorkNum(m);
                }
                Navigator.pop(ctx);
              },
              child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
          children: [
            AppFormField(
                label: 'رقم الموبايل',
                controller: phoneCtrl,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            AppFormField(label: 'الاسم / التصنيف', controller: labelCtrl),
            const SizedBox(height: 10),

            // Provider dropdown
            DropdownButtonFormField<String?>(
              initialValue: provider,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'نوع الشركة',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— لم يحدّد —', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'etisalat',
                    child: Text('🟢 اتصالات', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'orange',
                    child: Text('🟠 أورانج', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'vodafone',
                    child: Text('🔴 فودافون', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'we',
                    child: Text('🟣 WE', style: GoogleFonts.cairo(fontSize: 13))),
              ],
              onChanged: (v) => setS(() => provider = v),
            ),
            const SizedBox(height: 10),

            AppFormField(label: 'الباقة / النظام (مثال: 3800)', controller: systemCtrl),
            const SizedBox(height: 10),

            // Status
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'حالة الرقم',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                for (final s in _statusLabel.entries)
                  DropdownMenuItem(
                      value: s.key, child: Text(s.value, style: GoogleFonts.cairo(fontSize: 13))),
              ],
              onChanged: (v) => setS(() => status = v ?? 'available'),
            ),
            const SizedBox(height: 10),

            // Last contact date
            InkWell(
              onTap: () async {
                final d = await pickDate(lastContact);
                setS(() => lastContact = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '📞 آخر اتصال',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(children: [
                  Expanded(
                      child: Text(lastContact ?? 'اختر تاريخ',
                          style: GoogleFonts.cairo(fontSize: 13,
                              color: lastContact == null ? AppColors.muted : AppColors.text))),
                  if (lastContact != null)
                    GestureDetector(
                      onTap: () => setS(() => lastContact = null),
                      child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            AppFormField(label: '🔢 آخر سيريال', controller: serialCtrl, textDirection: TextDirection.ltr),
            const SizedBox(height: 10),

            // Offer expiry
            InkWell(
              onTap: () async {
                final d = await pickDate(offerExpiry);
                setS(() => offerExpiry = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '🗓 تاريخ انتهاء العرض/الخط',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(children: [
                  Expanded(
                      child: Text(offerExpiry ?? 'اختياري',
                          style: GoogleFonts.cairo(fontSize: 13,
                              color: offerExpiry == null ? AppColors.muted : AppColors.text))),
                  if (offerExpiry != null)
                    GestureDetector(
                      onTap: () => setS(() => offerExpiry = null),
                      child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            AppFormField(label: '👤 صاحبه السابق (اختياري)', controller: ownerCtrl),
            const SizedBox(height: 10),

            AppFormField(
                label: 'أيام التذكير لهذا الرقم (اختياري — يتجاوز الافتراضي)',
                controller: overrideCtrl,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),

            AppFormField(label: 'ملاحظات (اختياري)', controller: notesCtrl),
          ],
        ),
      ),
    );
  }
}
