// lib/screens/dataio_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/pin_dialog.dart';

class DataIOScreen extends StatelessWidget {
  const DataIOScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.08), blurRadius: 20)],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💾 إدارة البيانات', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.blue2)),
            const SizedBox(height: 6),
            Text('صدّر كل بيانات البرنامج أو استورد نسخة احتياطية', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 20),

            // Export section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📤 تصدير البيانات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2)),
                  const SizedBox(height: 6),
                  Text('بيحفظ كل المجموعات والعملاء والإيجارات والأرشيف في ملف واحد', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  _exportBtn(context, '📤 تصدير النسخة الاحتياطية (JSON)', [const Color(0xFF1565c0), const Color(0xFF2196f3)], () => _exportJSON(context)),
                  const SizedBox(height: 10),
                  _exportBtn(context, '📊 تصدير Excel (كل البيانات)', [const Color(0xFF2e7d32), const Color(0xFF43a047)], () => _exportExcel(context)),
                  const SizedBox(height: 10),
                  _exportBtn(context, '🖨️ تصدير PDF للطباعة', [AppColors.red2, AppColors.red], () => _exportPDF(context)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Import section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📥 استيراد البيانات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.green2)),
                  const SizedBox(height: 4),
                  Text('⚠️ هيستبدل كل البيانات الحالية بالملف المستورد', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  _exportBtn(context, '📥 استيراد ملف JSON', [const Color(0xFF00695c), AppColors.green], () => _importJSON(context)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Delete section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🗑 حذف البيانات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.red2)),
                  const SizedBox(height: 4),
                  Text('⚠️ تحذير: هذا الإجراء لا يمكن التراجع عنه', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFef9a9a)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _deleteSelected(context),
                      child: Text('🗑 حذف بيانات مختارة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.red2, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _exportBtn(context, '💣 مسح كل البيانات نهائياً', [const Color(0xFFb71c1c), AppColors.red2], () => _deleteAll(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportBtn(BuildContext context, String label, List<Color> colors, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 12)],
          ),
          child: Center(child: Text(label, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
        ),
      ),
    );
  }

  Future<void> _exportJSON(BuildContext context) async {
    final prov = context.read<AppProvider>();
    final json = prov.exportJson();
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final file = File('${dir.path}/telecom_backup_${now.day}-${now.month}-${now.year}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: '📡 نسخة احتياطية - باقات الاتصالات');
  }

  Future<void> _exportExcel(BuildContext context) async {
    AppSnackbar.show(context, '📊 جاري تصدير Excel...');
    // TODO: implement excel export with excel package
  }

  Future<void> _exportPDF(BuildContext context) async {
    AppSnackbar.show(context, '🖨️ جاري تصدير PDF...');
    // TODO: implement PDF export with pdf package
  }

  Future<void> _importJSON(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null) return;
    final f = result.files.single;

    // تحقق من الامتداد
    final name = f.name.toLowerCase();
    if (!name.endsWith('.json')) {
      if (context.mounted) AppSnackbar.show(context, '❌ اختر ملف JSON فقط');
      return;
    }

    String raw;
    if (f.bytes != null) {
      raw = utf8.decode(f.bytes!);
    } else if (f.path != null) {
      raw = await File(f.path!).readAsString();
    } else {
      if (context.mounted) AppSnackbar.show(context, '❌ تعذّر قراءة الملف');
      return;
    }
    if (!context.mounted) return;
    final prov = context.read<AppProvider>();
    final ok = prov.importJson(raw);
    AppSnackbar.show(context, ok ? '✅ تم استيراد البيانات بنجاح' : '❌ خطأ: الملف غير صالح');
  }

  void _deleteAll(BuildContext context) {
    _deleteStep1(context);
  }

  // خطوة 1: تحذير
  void _deleteStep1(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFFFF3F3),
        title: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text('تحذير خطير!', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.red[800], fontSize: 17)),
        ]),
        content: Text(
          'أنت على وشك مسح جميع البيانات نهائياً.\n\nهذا الإجراء لا يمكن التراجع عنه وسيؤدي إلى فقدان:\n• كل العملاء والمجموعات\n• كل سجلات الدفع\n• كل الإعدادات والبيانات\n\nهل أنت متأكد تماماً من الاستمرار؟',
          style: GoogleFonts.cairo(fontSize: 13, height: 1.7, color: Colors.red[900]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteStep2(context);
            },
            child: Text('أفهم، استمر', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // خطوة 2: إدخال كلمة السر أو "DELETE"
  void _deleteStep2(BuildContext context) {
    final ctrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🔐 تأكيد الهوية', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('اكتب كلمة سر الإدارة أو اكتب كلمة DELETE للتأكيد',
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: obscure,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'كلمة السر أو DELETE',
                hintStyle: GoogleFonts.cairo(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => ss(() => obscure = !obscure),
                ),
              ),
              style: GoogleFonts.cairo(),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
              onPressed: () {
                final val = ctrl.text.trim();
                final isAdmin = val == '0100100Aa@';
                final isWord = val.toUpperCase() == 'DELETE';
                if (!isAdmin && !isWord) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('❌ كلمة السر خاطئة', style: GoogleFonts.cairo()),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                Navigator.pop(ctx);
                _deleteStep3(context);
              },
              child: Text('تأكيد', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  // خطوة 3: عداد 5 ثواني
  void _deleteStep3(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CountdownDeleteDialog(
        onConfirm: () {
          context.read<AppProvider>().deleteAllData();
          AppSnackbar.show(context, '✅ تم مسح كل البيانات');
        },
      ),
    );
  }

  void _deleteSelected(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف بيانات مختارة', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('العملاء فقط', style: GoogleFonts.cairo()),
              leading: const Icon(Icons.people, color: AppColors.orange),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => PinDialog(
                    title: 'حذف كل العملاء',
                    onConfirm: () {
                      context.read<AppProvider>().deleteAllMembers();
                      AppSnackbar.show(context, '✅ تم حذف كل العملاء');
                    },
                  ),
                );
              },
            ),
            ListTile(
              title: Text('سجل النشاط', style: GoogleFonts.cairo()),
              leading: const Icon(Icons.history, color: AppColors.blue),
              onTap: () {
                Navigator.pop(context);
                context.read<AppProvider>().clearActivityLog();
                AppSnackbar.show(context, '✅ تم مسح سجل النشاط');
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
        ],
      ),
    );
  }
}

// ── عداد 5 ثواني قبل المسح النهائي ──────────────────────────────
class _CountdownDeleteDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  const _CountdownDeleteDialog({required this.onConfirm});

  @override
  State<_CountdownDeleteDialog> createState() => _CountdownDeleteDialogState();
}

class _CountdownDeleteDialogState extends State<_CountdownDeleteDialog> {
  int _seconds = 5;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    while (_seconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds--);
    }
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFFF3F3),
      title: Text('💣 المسح النهائي', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.red[900])),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('انتظر حتى ينتهي العداد قبل المسح',
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _done
              ? const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.red)
              : Text(
                  '$_seconds',
                  key: ValueKey(_seconds),
                  style: GoogleFonts.cairo(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.red[800]),
                ),
        ),
        const SizedBox(height: 12),
        if (_done)
          Text('يمكنك الآن مسح كل البيانات',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 13, color: Colors.red[800], fontWeight: FontWeight.w700)),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _done ? Colors.red[900] : Colors.grey,
              foregroundColor: Colors.white),
          onPressed: _done
              ? () {
                  Navigator.pop(context);
                  widget.onConfirm();
                }
              : null,
          child: Text('💣 امسح كل البيانات',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}
