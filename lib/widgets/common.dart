// lib/widgets/common.dart
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_theme.dart';

// ─── STAT CHIP ───────────────────────────────────────────────────
class StatChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  const StatChip(this.label, {super.key, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Colors.white.withValues(alpha: 0.25);
    final fg = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color != null ? bg : Colors.white.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── GRADIENT BUTTON ─────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const GradientButton({
    super.key,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── APP SNACKBAR ────────────────────────────────────────────────
class AppSnackbar {
  static void show(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: const Color(0xFF0d1b2e).withValues(alpha: 0.95),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }
}

// ─── SECTION TITLE ────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15)),
              if (subtitle != null)
                Text(subtitle!, style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── FORM FIELD ──────────────────────────────────────────────────
class AppFormField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final String? initialValue;
  final void Function(String)? onChanged;
  final int? maxLines;
  final bool obscure;
  final int? maxLength;
  final String? inputMode;
  final List<TextInputFormatter>? inputFormatters;

  const AppFormField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.textDirection,
    this.initialValue,
    this.onChanged,
    this.maxLines = 1,
    this.obscure = false,
    this.maxLength,
    this.inputMode,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: textDirection,
          maxLines: maxLines,
          obscureText: obscure,
          maxLength: maxLength,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

// ─── DATE FIELD ──────────────────────────────────────────────────
class AppDateField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final void Function(String)? onChanged;

  const AppDateField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.onChanged,
  });

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  late final TextEditingController _ctrl;
  late final bool _ownCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
      _ownCtrl = false;
    } else {
      _ctrl = TextEditingController(text: widget.initialValue ?? '');
      _ownCtrl = true;
    }
  }

  @override
  void dispose() {
    if (_ownCtrl) _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final initial = DateTime.tryParse(_ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.blue2),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    _ctrl.text = formatted;
    widget.onChanged?.call(formatted);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              readOnly: true,
              textDirection: TextDirection.ltr,
              onTap: _pick,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'اختر تاريخ',
                hintStyle:
                    GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _pick,
              icon: const Icon(Icons.calendar_today, color: AppColors.blue2),
              tooltip: 'اختيار التاريخ',
            ),
          ),
        ]),
      ],
    );
  }
}

// ─── MODAL SHELL ─────────────────────────────────────────────────
class ModalShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final bool isBottomSheet;

  const ModalShell({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.isBottomSheet = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFf0f8ff), Colors.white],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 0),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(title, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.blue2)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions.map((a) => Padding(padding: const EdgeInsets.only(right: 8), child: a)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LINE TYPE SELECTOR ──────────────────────────────────────────
class LineTypeSelector extends StatefulWidget {
  final String value;
  final void Function(String) onChanged;
  final String prefix;

  const LineTypeSelector({super.key, required this.value, required this.onChanged, required this.prefix});

  @override
  State<LineTypeSelector> createState() => _LineTypeSelectorState();
}

class _LineTypeSelectorState extends State<LineTypeSelector> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _btn('3800', '📡', '3800 ج', '260 ج')),
        const SizedBox(width: 8),
        Expanded(child: _btn('1800', '📶', '1800 ج', '190 ج')),
        const SizedBox(width: 8),
        Expanded(child: _btn('manual', '✏️', 'يدوي', 'فاتورة يدوية')),
      ],
    );
  }

  Widget _btn(String val, String icon, String title, String sub) {
    final selected = widget.value == val;
    final isManual = val == 'manual';
    final selColor = isManual ? const Color(0xFFE65100) : AppColors.blue3;
    final selBg    = isManual ? const Color(0xFFFFF3E0) : AppColors.blueLight;
    return GestureDetector(
      onTap: () { widget.onChanged(val); setState(() {}); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? selBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? selColor : Colors.grey[300]!, width: 2),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
            Text(sub, style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ─── PAYMENT FLAG SELECTOR ───────────────────────────────────────
class FlagSelector extends StatelessWidget {
  final String? value; // null / 'green' / 'yellow' / 'red'
  final void Function(String?) onChanged;

  const FlagSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _btn(null, '⬜', 'بدون', Colors.grey[200]!, Colors.grey[600]!, Colors.grey[400]!)),
        const SizedBox(width: 7),
        Expanded(child: _btn('green', '🟢', 'منتظم', const Color(0xFFE8F5E9), const Color(0xFF2E7D32), const Color(0xFF66BB6A))),
        const SizedBox(width: 7),
        Expanded(child: _btn('yellow', '🟡', 'متذبذب', const Color(0xFFFFFDE7), const Color(0xFFF57F17), const Color(0xFFFFCA28))),
        const SizedBox(width: 7),
        Expanded(child: _btn('red', '🔴', 'خطر', const Color(0xFFFFEBEE), const Color(0xFFC62828), const Color(0xFFEF5350))),
      ],
    );
  }

  Widget _btn(String? val, String icon, String label, Color bg, Color textColor, Color borderColor) {
    final selected = value == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? borderColor : Colors.grey[300]!, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: borderColor.withValues(alpha: 0.25), blurRadius: 6)] : [],
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? textColor : Colors.grey[500])),
        ]),
      ),
    );
  }
}

// ─── PAYER SELECTOR ──────────────────────────────────────────────
class PayerSelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const PayerSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _btn('me', '👤', 'عليّ أنا')),
        const SizedBox(width: 10),
        Expanded(child: _btn('company', '🏢', 'على الشركة')),
      ],
    );
  }

  Widget _btn(String val, String icon, String title) {
    final selected = value == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.blue3 : Colors.grey[300]!, width: 2),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
