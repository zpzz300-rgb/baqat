// lib/widgets/pin_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';

class PinDialog extends StatefulWidget {
  final String title;
  final VoidCallback onConfirm;

  const PinDialog({super.key, required this.title, required this.onConfirm});

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '🔐 ${widget.title}',
        style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('أدخل الرقم السري للمتابعة', style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: GoogleFonts.cairo(fontSize: 22, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: GoogleFonts.cairo(fontSize: 22, letterSpacing: 8),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: GoogleFonts.cairo()),
        ),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text == prov.pin) {
              Navigator.pop(context);
              widget.onConfirm();
            } else {
              setState(() => _error = 'رقم سري خاطئ');
            }
          },
          child: Text('تأكيد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
