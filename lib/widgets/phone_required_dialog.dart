// lib/widgets/phone_required_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

final _egyptMobileRegex = RegExp(r'^01[0125][0-9]{8}$');

/// يطلب رقم الموبايل إجبارياً (مرة واحدة بس) من الحسابات القديمة اللي
/// اتسجلت قبل ما رقم الموبايل يبقى مطلوب وقت التسجيل.
Future<void> showPhoneRequiredDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  String? error;
  bool loading = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('📱 رقم الموبايل مطلوب', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('محتاجين رقم موبايلك عشان نقدر نتواصل معاك عند اللزوم.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'رقم الموبايل',
                  labelStyle: GoogleFonts.cairo(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: GoogleFonts.cairo(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final phone = ctrl.text.trim();
                      if (!_egyptMobileRegex.hasMatch(phone)) {
                        setSt(() => error = 'أدخل رقم موبايل مصري صحيح (01xxxxxxxxx)');
                        return;
                      }
                      setSt(() { loading = true; error = null; });
                      final ok = await AuthService.linkPhoneToDevice(phone);
                      if (ok) {
                        if (ctx.mounted) Navigator.pop(ctx);
                      } else {
                        setSt(() { loading = false; error = 'تعذّر الحفظ، حاول تاني'; });
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    ),
  );
}
