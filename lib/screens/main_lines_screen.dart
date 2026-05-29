// lib/screens/main_lines_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/main_line.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/phone_utils.dart';
import '../widgets/common.dart';

class MainLinesScreen extends StatefulWidget {
  const MainLinesScreen({super.key});
  @override
  State<MainLinesScreen> createState() => _MainLinesScreenState();
}

class _MainLinesScreenState extends State<MainLinesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov     = context.watch<AppProvider>();
    final all      = prov.db.mainLines;
    final filtered = _search.isEmpty
        ? all
        : all.where((l) =>
            l.phone.contains(_search) ||
            l.ownerName.toLowerCase().contains(_search.toLowerCase()) ||
            l.name.contains(_search)).toList();

    return Column(
      children: [
        _buildHeader(context, prov, all),

        // ── Search ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: '🔍 بحث بالرقم أو الاسم أو الشركة...',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _search = ''))
                  : null,
            ),
          ),
        ),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('📡', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text('لا توجد خطوط رئيسية بعد', style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _openForm(context, prov),
                      icon: const Icon(Icons.add),
                      label: Text('إضافة خط', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _MainLineCard(
                    line: filtered[i],
                    onEdit:   () => _openForm(context, prov, existing: filtered[i]),
                    onDelete: () => _confirmDelete(context, prov, filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AppProvider prov, List<MainLine> all) {
    final counts = <String, int>{};
    for (final l in all) {
      counts[l.provider] = (counts[l.provider] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0d47a1), Color(0xFF1565c0)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('📡 الخطوط الرئيسية',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
            GestureDetector(
              onTap: () => _openForm(context, prov),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, size: 16, color: Color(0xFF0d47a1)),
                  const SizedBox(width: 4),
                  Text('إضافة خط', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF0d47a1))),
                ]),
              ),
            ),
          ]),
          if (all.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _statChip('الإجمالي: ${all.length}', Colors.white.withValues(alpha: 0.2), Colors.white),
              for (final p in MainLine.providerNames.keys)
                if ((counts[p] ?? 0) > 0)
                  _statChip(
                    '${MainLine.providerEmojis[p]} ${MainLine.providerNames[p]}: ${counts[p]}',
                    MainLine.providerColors[p]!.withValues(alpha: 0.3),
                    Colors.white,
                  ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, Color bg, Color text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: GoogleFonts.cairo(color: text, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  void _openForm(BuildContext context, AppProvider prov, {MainLine? existing}) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _MainLineForm(existing: existing),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider prov, MainLine line) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الخط', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('حذف خط ${line.phone} (${line.name})؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () { prov.deleteMainLine(line.id); Navigator.pop(context); },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Main Line Card  — كل حقل قابل للتعديل لوحده بضغطة
// ─────────────────────────────────────────────────────────────────
class _MainLineCard extends StatelessWidget {
  final MainLine     line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MainLineCard({required this.line, required this.onEdit, required this.onDelete});

  // ── save helper ──────────────────────────────────────────────
  void _save(BuildContext ctx, MainLine updated) =>
      ctx.read<AppProvider>().editMainLine(updated);

  // ── quick number dialog ───────────────────────────────────────
  void _editNum(BuildContext ctx, String title, String hint, num current,
      void Function(num) onSave) {
    final ctrl = TextEditingController(text: current.toString());
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(
          controller: ctrl, autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: hint, labelStyle: GoogleFonts.cairo(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final v = num.tryParse(ctrl.text.trim());
              if (v != null) onSave(v);
              Navigator.pop(ctx);
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── quick text dialog ─────────────────────────────────────────
  void _editText(BuildContext ctx, String title, String current,
      void Function(String) onSave) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () { onSave(ctrl.text.trim()); Navigator.pop(ctx); },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── provider picker (bottom sheet) ───────────────────────────
  void _editProvider(BuildContext ctx) {
    showModalBottomSheet(useRootNavigator: true,
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
          Text('🏢 اختر الشركة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 16),
          Row(children: MainLine.providerNames.entries.map((e) {
            final c   = MainLine.providerColors[e.key]!;
            final sel = line.provider == e.key;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _save(ctx, _copy(provider: e.key));
                  Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? c : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c, width: 2),
                    boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(MainLine.providerEmojis[e.key]!, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(e.value, style: GoogleFonts.cairo(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: sel ? Colors.white : c)),
                    if (sel) ...[
                      const SizedBox(height: 4),
                      Icon(Icons.check_circle, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                    ],
                  ]),
                ),
              ),
            );
          }).toList()),
        ]),
      ),
    );
  }

  // ── billing cycle picker (bottom sheet) ───────────────────────
  void _editCycle(BuildContext ctx) {
    showModalBottomSheet(useRootNavigator: true,
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
          Text('🔄 دورة الفاتورة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 8),
          ...MainLine.cycleLabels.entries.map((e) {
            final sel = line.billingCycle == e.key;
            return ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: sel ? AppColors.blueLight : null,
              leading: Icon(
                sel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: sel ? AppColors.blue : AppColors.muted, size: 20,
              ),
              title: Text(e.value, style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  color: sel ? AppColors.blue2 : AppColors.text)),
              trailing: sel ? const Icon(Icons.check, color: AppColors.blue, size: 18) : null,
              onTap: () {
                _save(ctx, _copy(billingCycle: e.key));
                Navigator.pop(ctx);
              },
            );
          }),
        ]),
      ),
    );
  }

  // ── date picker ───────────────────────────────────────────────
  Future<void> _editDate(BuildContext ctx, String label, String? current,
      void Function(String) onSave) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: current != null ? DateTime.tryParse(current) ?? now : now,
      firstDate: DateTime(2020), lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      onSave('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  // ── copy with one field changed ───────────────────────────────
  MainLine _copy({
    String? provider, String? phone, String? ownerName,
    int? maxClients, int? pointsMonthly, double? pointPrice,
    double? extraClientFee, String? billingCycle,
    String? startDate, String? endDate, int? offerDuration, String? notes,
  }) => MainLine(
    id:             line.id,
    provider:       provider       ?? line.provider,
    phone:          phone          ?? line.phone,
    ownerName:      ownerName      ?? line.ownerName,
    maxClients:     maxClients     ?? line.maxClients,
    pointsMonthly:  pointsMonthly  ?? line.pointsMonthly,
    pointPrice:     pointPrice     ?? line.pointPrice,
    extraClientFee: extraClientFee ?? line.extraClientFee,
    billingCycle:   billingCycle   ?? line.billingCycle,
    startDate:      startDate      ?? line.startDate,
    endDate:        endDate        ?? line.endDate,
    offerDuration:  offerDuration  ?? line.offerDuration,
    idPhotoPath:    line.idPhotoPath,
    notes:          notes          ?? line.notes,
  );

  // ── tap chip helper ───────────────────────────────────────────
  Widget _tapChip(BuildContext ctx, String label, Color bg, Color textColor,
      Color border, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(width: 3),
          Icon(Icons.edit, size: 9, color: textColor.withValues(alpha: 0.6)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days     = line.daysToEnd;
    final expired  = days != null && days < 0;
    final expiring = days != null && days >= 0 && days <= 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: line.color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── Colored stripe (tap = change provider) ──────────
            GestureDetector(
              onTap: () => _editProvider(context),
              child: Container(
                width: 10,
                decoration: BoxDecoration(
                  color: line.color,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                ),
                child: const RotatedBox(
                  quarterTurns: 3,
                  child: Center(child: Icon(Icons.edit, size: 10, color: Colors.white54)),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Row 1: provider + phone + menu ───────────
                    Row(children: [
                      // Provider badge — tap to change
                      GestureDetector(
                        onTap: () => _editProvider(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: line.bg, borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: line.color.withValues(alpha: 0.5)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(line.emoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(line.name, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: line.color)),
                            const SizedBox(width: 3),
                            Icon(Icons.swap_horiz, size: 11, color: line.color.withValues(alpha: 0.7)),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Phone — tap to edit
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editText(context, '📞 رقم الخط', line.phone,
                              (v) { if (v.isNotEmpty) _save(context, _copy(phone: v)); }),
                          child: Row(children: [
                            Flexible(child: Text(line.phone,
                                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.blue2),
                                textDirection: TextDirection.ltr)),
                            const SizedBox(width: 3),
                            const Icon(Icons.edit, size: 11, color: AppColors.muted),
                          ]),
                        ),
                      ),
                      // Delete only
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      ),
                    ]),
                    const SizedBox(height: 6),

                    // ── Owner — tap to edit ───────────────────────
                    GestureDetector(
                      onTap: () => _editText(context, '👤 اسم صاحب الخط', line.ownerName,
                          (v) { if (v.isNotEmpty) _save(context, _copy(ownerName: v)); }),
                      child: Row(children: [
                        const Icon(Icons.person_outline, size: 13, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(line.ownerName.isNotEmpty ? line.ownerName : 'اضغط لإضافة الاسم',
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600,
                                color: line.ownerName.isNotEmpty ? AppColors.text : AppColors.muted)),
                        const SizedBox(width: 3),
                        const Icon(Icons.edit, size: 10, color: AppColors.muted),
                      ]),
                    ),
                    const SizedBox(height: 8),

                    // ── Stats chips — كل واحدة تعدل لوحدها ──────
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _tapChip(context, '👥 ${line.maxClients} عميل',
                          AppColors.blueLight, AppColors.blue2, AppColors.blueMid,
                          () => _editNum(context, '👥 عدد العملاء المتاحين', 'عدد', line.maxClients,
                              (v) => _save(context, _copy(maxClients: v.toInt())))),

                      _tapChip(context, '📊 ${line.pointsMonthly} نقطة/شهر',
                          AppColors.blueLight, AppColors.blue2, AppColors.blueMid,
                          () => _editNum(context, '📊 النقاط المنزلة شهرياً', 'نقطة', line.pointsMonthly,
                              (v) => _save(context, _copy(pointsMonthly: v.toInt())))),

                      _tapChip(context, '💰 ${line.pointPrice.toStringAsFixed(0)} ج/نقطة',
                          AppColors.blueLight, AppColors.blue2, AppColors.blueMid,
                          () => _editNum(context, '💰 سعر النقطة', 'جنيه', line.pointPrice,
                              (v) => _save(context, _copy(pointPrice: v.toDouble())))),

                      _tapChip(context, '🔄 ${line.cycleLabel}',
                          AppColors.blueLight, AppColors.blue2, AppColors.blueMid,
                          () => _editCycle(context)),

                      _tapChip(context,
                          '➕ ${line.extraClientFee > 0 ? "${line.extraClientFee.toStringAsFixed(0)} ج/إضافي" : "زيادة عميل"}',
                          line.extraClientFee > 0 ? const Color(0xFFFFF3E0) : AppColors.blueLight,
                          line.extraClientFee > 0 ? const Color(0xFFE65100) : AppColors.muted,
                          line.extraClientFee > 0 ? const Color(0xFFFFCC80) : AppColors.border,
                          () => _editNum(context, '➕ زيادة لكل عميل إضافي', 'جنيه', line.extraClientFee,
                              (v) => _save(context, _copy(extraClientFee: v.toDouble())))),
                    ]),
                    const SizedBox(height: 6),

                    // ── Dates ────────────────────────────────────
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _tapChip(context,
                          line.startDate != null ? '🗓 ${line.startDate}' : '🗓 تاريخ البداية',
                          AppColors.blueLight, AppColors.blue2, AppColors.blueMid,
                          () => _editDate(context, 'تاريخ البداية', line.startDate, (d) {
                            final newEnd = MainLine.calcEndDate(d, line.offerDuration);
                            _save(context, _copy(startDate: d, endDate: newEnd));
                          })),

                      _tapChip(context,
                          '⏳ ${line.offerDuration != null ? "${line.offerDuration} شهر" : "المدة"}',
                          const Color(0xFFF3E5F5), const Color(0xFF6a1b9a), const Color(0xFFCE93D8),
                          () => _editNum(context, '⏳ مدة العرض', 'شهر', line.offerDuration ?? 0, (v) {
                            final months = v.toInt();
                            final newEnd = MainLine.calcEndDate(line.startDate, months);
                            _save(context, _copy(offerDuration: months, endDate: newEnd));
                          })),

                      if (line.endDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:  expired ? AppColors.redLight : expiring ? AppColors.orangeLight : AppColors.greenLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            expired  ? '🔴 منتهي: ${line.endDate}' :
                            expiring ? '⚠️ $days يوم متبقي' :
                                       '✅ ينتهي: ${line.endDate}',
                            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700,
                                color: expired ? AppColors.red2 : expiring ? const Color(0xFFE65100) : AppColors.green2),
                          ),
                        ),
                    ]),

                    // ── Notes ─────────────────────────────────────
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _editText(context, '📝 ملاحظات', line.notes ?? '',
                          (v) => _save(context, _copy(notes: v.isNotEmpty ? v : null))),
                      child: Row(children: [
                        Flexible(child: Text(
                          line.notes != null && line.notes!.isNotEmpty ? line.notes! : '+ إضافة ملاحظة',
                          style: GoogleFonts.cairo(fontSize: 11,
                              color: line.notes != null ? AppColors.text : AppColors.muted),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        )),
                        const SizedBox(width: 3),
                        const Icon(Icons.edit, size: 10, color: AppColors.muted),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Add / Edit Form
// ─────────────────────────────────────────────────────────────────
class _MainLineForm extends StatefulWidget {
  final MainLine? existing;
  const _MainLineForm({this.existing});
  @override
  State<_MainLineForm> createState() => _MainLineFormState();
}

class _MainLineFormState extends State<_MainLineForm> {
  final _phoneCtrl            = TextEditingController();
  final _ownerCtrl            = TextEditingController();
  final _maxClientsCtrl       = TextEditingController();
  final _pointsMonthlyCtrl    = TextEditingController();
  final _pointPriceCtrl       = TextEditingController();
  final _extraFeeCtrl         = TextEditingController();
  final _offerDurCtrl         = TextEditingController();
  final _notesCtrl            = TextEditingController();
  final _openingBalanceCtrl   = TextEditingController();

  String  _provider     = 'vodafone';
  String  _billingCycle = 'cycle1';
  String? _startDate;
  String? _endDate;
  String? _idPhotoPath;
  String? _phoneError;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _provider             = e.provider;
      _billingCycle         = e.billingCycle;
      _startDate            = e.startDate;
      _endDate              = e.endDate;
      _idPhotoPath          = e.idPhotoPath;
      _phoneCtrl.text         = e.phone;
      _ownerCtrl.text         = e.ownerName;
      _maxClientsCtrl.text    = e.maxClients.toString();
      _pointsMonthlyCtrl.text = e.pointsMonthly.toString();
      _pointPriceCtrl.text    = e.pointPrice.toStringAsFixed(0);
      _extraFeeCtrl.text      = e.extraClientFee.toStringAsFixed(0);
      _offerDurCtrl.text        = e.offerDuration?.toString() ?? '';
      _notesCtrl.text           = e.notes ?? '';
      _openingBalanceCtrl.text  = e.openingBalance > 0 ? e.openingBalance.toStringAsFixed(0) : '';
    } else {
      _startDate = _today();
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose(); _ownerCtrl.dispose();
    _maxClientsCtrl.dispose(); _pointsMonthlyCtrl.dispose();
    _pointPriceCtrl.dispose(); _extraFeeCtrl.dispose();
    _offerDurCtrl.dispose(); _notesCtrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  void _recalcEndDate() {
    final months = int.tryParse(_offerDurCtrl.text.trim());
    setState(() => _endDate = MainLine.calcEndDate(_startDate, months));
  }

  @override
  Widget build(BuildContext context) {
    final color = MainLine.providerColors[_provider] ?? AppColors.blue;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              Text(
                widget.existing == null ? '📡 إضافة خط رئيسي' : '✏️ تعديل الخط',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: _save,
                child: Text('حفظ ✅', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider selector
                  _label('🏢 شركة الاتصالات'),
                  const SizedBox(height: 8),
                  Row(children: MainLine.providerNames.entries.map((e) {
                    final sel = _provider == e.key;
                    final c   = MainLine.providerColors[e.key]!;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _provider = e.key),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? c : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sel ? c : AppColors.border, width: 2),
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(MainLine.providerEmojis[e.key]!, style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 2),
                            Text(e.value, style: GoogleFonts.cairo(
                                fontSize: 10, fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : AppColors.text)),
                          ]),
                        ),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 18),

                  // Phone + Owner
                  _label('📋 بيانات الخط'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AppFormField(
                        label: 'رقم الخط',
                        controller: _phoneCtrl,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [PhoneInputFormatter()],
                        onChanged: (v) => setState(() => _phoneError = validatePhone(v)),
                      ),
                      if (_phoneError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_phoneError!, style: GoogleFonts.cairo(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                    ])),
                    const SizedBox(width: 10),
                    Expanded(child: AppFormField(label: 'اسم صاحب الخط', controller: _ownerCtrl)),
                  ]),
                  const SizedBox(height: 14),

                  // Opening Balance
                  _label('💵 الرصيد الافتتاحي'),
                  const SizedBox(height: 8),
                  AppFormField(
                    label: 'الرصيد الافتتاحي (جنيه)',
                    controller: _openingBalanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    hint: '0',
                  ),
                  const SizedBox(height: 18),

                  // System details
                  _label('⚙️ تفاصيل النظام'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: AppFormField(label: 'عدد العملاء المتاحين', controller: _maxClientsCtrl,
                        keyboardType: TextInputType.number, textDirection: TextDirection.ltr)),
                    const SizedBox(width: 10),
                    Expanded(child: AppFormField(label: 'النقاط المنزلة/شهر', controller: _pointsMonthlyCtrl,
                        keyboardType: TextInputType.number, textDirection: TextDirection.ltr)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: AppFormField(label: 'سعر النقطة (ج)', controller: _pointPriceCtrl,
                        keyboardType: TextInputType.number, textDirection: TextDirection.ltr)),
                    const SizedBox(width: 10),
                    Expanded(child: AppFormField(label: 'زيادة/عميل إضافي (ج)', controller: _extraFeeCtrl,
                        keyboardType: TextInputType.number, textDirection: TextDirection.ltr)),
                  ]),
                  const SizedBox(height: 18),

                  // Billing cycle
                  _label('🔄 دورة الفاتورة'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: MainLine.cycleLabels.entries.map((e) {
                    final sel = _billingCycle == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _billingCycle = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.headerGradient : null,
                          color: sel ? null : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? AppColors.blue : AppColors.border, width: 1.5),
                        ),
                        child: Text(e.value, style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.text)),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 18),

                  // Dates
                  _label('📅 التواريخ والعرض'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _datePicker('تاريخ البداية', _startDate, (d) {
                      setState(() { _startDate = d; _recalcEndDate(); });
                    })),
                    const SizedBox(width: 10),
                    Expanded(child: AppFormField(
                      label: 'مدة العرض (شهر)',
                      controller: _offerDurCtrl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (_) => _recalcEndDate(),
                    )),
                  ]),
                  if (_endDate != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.green2),
                        const SizedBox(width: 8),
                        Text('تاريخ الانتهاء: $_endDate',
                            style: GoogleFonts.cairo(color: AppColors.green2, fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // ID Photo
                  _label('🪪 صورة البطاقة'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickIdPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.blueMid),
                      ),
                      child: Row(children: [
                        const Icon(Icons.image_outlined, color: AppColors.blue2, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          _idPhotoPath != null
                              ? _idPhotoPath!.split('/').last.split('\\').last
                              : 'اضغط لاختيار صورة البطاقة',
                          style: GoogleFonts.cairo(fontSize: 12,
                              color: _idPhotoPath != null ? AppColors.text : AppColors.muted),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                        if (_idPhotoPath != null)
                          GestureDetector(
                            onTap: () => setState(() => _idPhotoPath = null),
                            child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  AppFormField(label: 'ملاحظات (اختياري)', controller: _notesCtrl, maxLines: 3),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.blue2));

  Widget _datePicker(String label, String? value, void Function(String) onPicked) {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value != null ? DateTime.tryParse(value) ?? now : now,
          firstDate: DateTime(2020), lastDate: DateTime(2035),
          locale: const Locale('ar'),
        );
        if (picked != null) {
          onPicked('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(value ?? label,
              style: GoogleFonts.cairo(fontSize: 12,
                  color: value != null ? AppColors.text : AppColors.muted))),
        ]),
      ),
    );
  }

  Future<void> _pickIdPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _idPhotoPath = result.files.single.path!);
    }
  }

  void _save() {
    if (_phoneCtrl.text.trim().isEmpty || _ownerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رقم الخط واسم صاحب الخط مطلوبان', style: GoogleFonts.cairo())),
      );
      return;
    }
    if (_phoneError != null) return;

    final prov = context.read<AppProvider>();
    final line = MainLine(
      id:             widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      provider:       _provider,
      phone:          _phoneCtrl.text.trim(),
      maxClients:     int.tryParse(_maxClientsCtrl.text.trim())    ?? 0,
      pointsMonthly:  int.tryParse(_pointsMonthlyCtrl.text.trim()) ?? 0,
      pointPrice:     double.tryParse(_pointPriceCtrl.text.trim()) ?? 0,
      extraClientFee: double.tryParse(_extraFeeCtrl.text.trim())   ?? 0,
      billingCycle:   _billingCycle,
      ownerName:      _ownerCtrl.text.trim(),
      idPhotoPath:    _idPhotoPath,
      startDate:      _startDate,
      endDate:        _endDate,
      offerDuration:  int.tryParse(_offerDurCtrl.text.trim()),
      notes:          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      openingBalance: double.tryParse(_openingBalanceCtrl.text.trim()) ?? 0,
    );

    if (widget.existing == null) {
      prov.addMainLine(line);
    } else {
      prov.editMainLine(line);
    }
    Navigator.pop(context);
  }
}
