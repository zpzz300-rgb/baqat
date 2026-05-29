// lib/screens/waitlist_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/app_theme.dart';
import '../widgets/common.dart';

class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});
  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  String _filter = 'all'; // all, waiting, contacted, assigned

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final list = prov.db.waitlist.where((e) {
      if (_filter == 'all') return true;
      return e.status == _filter;
    }).toList();

    final waiting   = prov.db.waitlist.where((e) => e.status == 'waiting').length;
    final contacted = prov.db.waitlist.where((e) => e.status == 'contacted').length;
    final assigned  = prov.db.waitlist.where((e) => e.status == 'assigned').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ─── Header ───
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.08), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('⏳ قائمة الانتظار', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15))),
                    GestureDetector(
                      onTap: () => _showAddEdit(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFe65100), Color(0xFFff8f00)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('+ إضافة للانتظار', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats
                Wrap(
                  spacing: 8,
                  children: [
                    _statChip('⏳ انتظار: $waiting', const Color(0xFFfff3e0), const Color(0xFFe65100)),
                    _statChip('📞 تم التواصل: $contacted', AppColors.blueLight, AppColors.blue2),
                    _statChip('✅ تم التعيين: $assigned', AppColors.greenLight, AppColors.green),
                  ],
                ),
                const SizedBox(height: 10),
                // Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterBtn('all', 'الكل'),
                      _filterBtn('waiting', '⏳ انتظار'),
                      _filterBtn('contacted', '📞 تواصل'),
                      _filterBtn('assigned', '✅ معيّن'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ─── List ───
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('لا يوجد عملاء في الانتظار', style: GoogleFonts.cairo(color: AppColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildCard(context, list[i], prov),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color bg, Color text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.w700, fontSize: 11)),
      );

  Widget _filterBtn(String key, String label) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.blue2 : const Color(0xFFf0f4f8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.blue2 : AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.cairo(color: active ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  Widget _buildCard(BuildContext context, WaitlistEntry e, AppProvider prov) {
    final statusColor = e.status == 'waiting'
        ? const Color(0xFFe65100)
        : e.status == 'contacted'
            ? AppColors.blue2
            : AppColors.green;
    final statusLabel = e.status == 'waiting' ? '⏳ انتظار' : e.status == 'contacted' ? '📞 تواصل' : '✅ معيّن';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.text)),
                      Text(e.phone, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                      if (e.phone2 != null) Text(e.phone2!, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Text(statusLabel, style: GoogleFonts.cairo(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                    if (e.price > 0) ...[
                      const SizedBox(height: 4),
                      Text('${e.price.toStringAsFixed(0)} ج/شهر', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Package info
          if (e.package != null || e.packageType != 'any')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      e.packageType == '2000' ? '📡 باقة 2000 ج' : e.packageType == '1500' ? '📶 باقة 1500 ج' : '🔄 أي باقة',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (e.package != null) ...[
                    const SizedBox(width: 6),
                    Text(e.package!, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
          if (e.notes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text('📝 ${e.notes}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
            ),
          // Actions
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFf8fafc),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _actionBtn('📞', AppColors.blue, () => _call(e.phone)),
                _actionBtn('💬', AppColors.waGreen, () => _whatsapp(e.phone)),
                const Spacer(),
                _statusDropdown(context, e, prov),
                const SizedBox(width: 6),
                _actionBtn('✏️', AppColors.orange, () => _showAddEdit(context, entry: e)),
                _actionBtn('🗑', AppColors.red, () => _delete(context, e, prov)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(icon, style: const TextStyle(fontSize: 16)),
        ),
      );

  Widget _statusDropdown(BuildContext context, WaitlistEntry e, AppProvider prov) {
    return PopupMenuButton<String>(
      onSelected: (s) => prov.setWaitlistStatus(e.id, s),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'waiting',   child: Text('⏳ انتظار',   style: GoogleFonts.cairo())),
        PopupMenuItem(value: 'contacted', child: Text('📞 تواصل',    style: GoogleFonts.cairo())),
        PopupMenuItem(value: 'assigned',  child: Text('✅ معيّن',    style: GoogleFonts.cairo())),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('تغيير الحالة ▾', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _call(String phone) => launchUrl(Uri.parse('tel:$phone'));
  void _whatsapp(String phone) {
    final p = phone.startsWith('0') ? '2$phone' : phone;
    launchUrl(Uri.parse('https://wa.me/$p'), mode: LaunchMode.externalApplication);
  }

  void _delete(BuildContext context, WaitlistEntry e, AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف من الانتظار', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('هل تريد حذف ${e.name} من قائمة الانتظار؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () { prov.deleteWaitlist(e.id); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddEdit(BuildContext context, {WaitlistEntry? entry}) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaitlistForm(entry: entry),
    );
  }
}

// ─── Add/Edit Form ───────────────────────────────────────────────
class _WaitlistForm extends StatefulWidget {
  final WaitlistEntry? entry;
  const _WaitlistForm({this.entry});
  @override
  State<_WaitlistForm> createState() => _WaitlistFormState();
}

class _WaitlistFormState extends State<_WaitlistForm> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl= TextEditingController();
  final _pkgCtrl   = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _pkgType  = 'any';

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final e = widget.entry!;
      _nameCtrl.text  = e.name;
      _phoneCtrl.text = e.phone;
      _phone2Ctrl.text= e.phone2 ?? '';
      _pkgCtrl.text   = e.package ?? '';
      _priceCtrl.text = e.price > 0 ? e.price.toStringAsFixed(0) : '';
      _notesCtrl.text = e.notes ?? '';
      _pkgType        = e.packageType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text('⏳ ${widget.entry == null ? "إضافة للانتظار" : "تعديل"}',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFFe65100))),
              const SizedBox(height: 16),
              _field('الاسم الكامل', _nameCtrl, hint: 'اسم العميل'),
              Row(children: [
                Expanded(child: _field('رقم الموبايل', _phoneCtrl, hint: '01xxxxxxxxx', numeric: true)),
                const SizedBox(width: 10),
                Expanded(child: _field('رقم ثاني (اختياري)', _phone2Ctrl, hint: '01xxxxxxxxx', numeric: true)),
              ]),
              Text('نوع الباقة المطلوبة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 8),
              Row(children: [
                _pkgTypeBtn('any',  '🔄 أي باقة',     'مش مهم'),
                const SizedBox(width: 8),
                _pkgTypeBtn('1500', '📶 1500 ج',       '2000 نقطة/شهر'),
                const SizedBox(width: 8),
                _pkgTypeBtn('2000', '📡 2000 ج',       '4000 نقطة/شهر'),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field('الباقة (جيجا/دقائق)', _pkgCtrl, hint: 'مثال: 35 جيجا')),
                const SizedBox(width: 10),
                Expanded(child: _field('الميزانية/الشهر', _priceCtrl, hint: '0', numeric: true)),
              ]),
              _field('ملاحظات', _notesCtrl, hint: 'أي تفاصيل إضافية...'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFe65100), Color(0xFFff8f00)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text('💾 إضافة للانتظار', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String hint = '', bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            textDirection: numeric ? TextDirection.ltr : TextDirection.rtl,
            style: GoogleFonts.cairo(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFf8fafc),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pkgTypeBtn(String key, String label, String sub) {
    final active = _pkgType == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _pkgType = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.blueLight : Colors.white,
            border: Border.all(color: active ? AppColors.blue2 : AppColors.border, width: active ? 2 : 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: active ? AppColors.blue2 : AppColors.text), textAlign: TextAlign.center),
              Text(sub, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      AppSnackbar.show(context, '⚠️ الاسم ورقم الموبايل مطلوبان');
      return;
    }
    final prov = context.read<AppProvider>();
    final entry = WaitlistEntry(
      id: widget.entry?.id ?? 0,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      phone2: _phone2Ctrl.text.trim().isEmpty ? null : _phone2Ctrl.text.trim(),
      packageType: _pkgType,
      package: _pkgCtrl.text.trim().isEmpty ? null : _pkgCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text) ?? 0,
      date: DateTime.now().toIso8601String().substring(0, 10),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      status: widget.entry?.status ?? 'waiting',
    );
    if (widget.entry == null) {
      prov.addWaitlist(entry);
    } else {
      prov.editWaitlist(entry);
    }
    Navigator.pop(context);
    AppSnackbar.show(context, widget.entry == null ? '✅ تمت الإضافة للانتظار' : '✅ تم التعديل');
  }
}
