// lib/screens/activation_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  final bool isExpired; // false = first install trial skip not needed
  const ActivationScreen({super.key, required this.onActivated, this.isExpired = true});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyCtrl = TextEditingController();
  bool    _loading = false;
  String? _error;
  String? _success;
  String? _pendingKey; // key waiting for migration confirmation

  @override
  void dispose() { _keyCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; _success = null; _pendingKey = null; });
    final r = await AuthService.activate(_keyCtrl.text);
    if (!mounted) return;

    if (r.ok) {
      setState(() { _success = r.msg; _loading = false; });
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onActivated();
      return;
    }

    if (r.needsMigration) {
      setState(() { _loading = false; _pendingKey = _keyCtrl.text.trim().toUpperCase(); });
      _showMigrationDialog(r.msg);
      return;
    }

    setState(() { _error = r.msg; _loading = false; });
  }

  void _showMigrationDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text('نقل الجهاز', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
        content: Text(msg, style: GoogleFonts.cairo(fontSize: 13, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); setState(() => _pendingKey = null); },
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0d47a1)),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              final r2 = await AuthService.confirmMigration(_pendingKey!);
              if (!mounted) return;
              if (r2.ok) {
                setState(() { _success = r2.msg; _loading = false; });
                await Future.delayed(const Duration(milliseconds: 800));
                widget.onActivated();
              } else {
                setState(() { _error = r2.msg; _loading = false; });
              }
            },
            child: Text('نعم، انقل الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d47a1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Text(widget.isExpired ? '🔒' : '🔑',
                    style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                Text(
                  widget.isExpired ? 'انتهت الفترة التجريبية' : 'تفعيل التطبيق',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'أدخل رمز التفعيل للاستمرار',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('رمز التفعيل',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                              fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF0d47a1))),
                      const SizedBox(height: 18),

                      TextField(
                        controller: _keyCtrl,
                        textDirection: TextDirection.ltr,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.robotoMono(
                            fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4),
                        textAlign: TextAlign.center,
                        onChanged: (v) {
                          // auto-format: insert dashes XXXX-XXXX-XXXX
                          final clean = v.replaceAll('-', '').toUpperCase();
                          if (clean.length <= 12) {
                            final formatted = _format(clean);
                            if (formatted != v) {
                              _keyCtrl.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(offset: formatted.length),
                              );
                            }
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'XXXX-XXXX-XXXX',
                          hintStyle: GoogleFonts.robotoMono(
                              color: Colors.grey[400], fontSize: 18, letterSpacing: 4),
                          filled: true, fillColor: const Color(0xFFF5F7FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0d47a1), width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        _msgBox(_error!, const Color(0xFFFFEBEB), Colors.red[700]!),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 10),
                        _msgBox(_success!, const Color(0xFFE8F5E9), Colors.green[700]!),
                      ],
                      const SizedBox(height: 20),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.vpn_key_rounded, color: Colors.white),
                          label: Text('تفعيل الآن',
                              style: GoogleFonts.cairo(
                                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0d47a1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final deviceId = await AuthService.getDeviceId();
                    final msg = 'السلام عليكم أبو عمر،\nأريد كود التفعيل\nرقم الجهاز: $deviceId';
                    final url = Uri.parse('https://wa.me/201001005891?text=${Uri.encodeComponent(msg)}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.chat, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'للحصول على كود التفعيل تواصل مع أبو عمر',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _msgBox(String msg, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(msg, textAlign: TextAlign.center,
        style: GoogleFonts.cairo(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
  );

  String _format(String s) {
    if (s.length <= 4) return s;
    if (s.length <= 8) return '${s.substring(0, 4)}-${s.substring(4)}';
    return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8)}';
  }
}
