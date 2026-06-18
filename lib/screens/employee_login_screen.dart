// lib/screens/employee_login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';

/// شاشة دخول/تسجيل الموظف — يدخل بكود المحل + اسمه + كود سري.
/// التسجيل ينتظر موافقة المالك، والدخول يفتح البرنامج لو الحساب active.
class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});
  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _shopCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pinCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _isRegister = false;
  bool _pending = false; // بعد التسجيل: مستني موافقة المالك
  String? _error;
  String? _info;

  @override
  void dispose() {
    _shopCtrl.dispose();
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _shopCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _pinCtrl.text.trim().length >= 4;

  Future<void> _register() async {
    if (!_valid) {
      setState(() => _error = 'اكتب كود المحل واسمك وكود سري (4 أرقام على الأقل)');
      return;
    }
    setState(() { _loading = true; _error = null; _info = null; });
    final r = await SupabaseService.employeeRegister(
      shopCode: _shopCtrl.text, name: _nameCtrl.text, pin: _pinCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _pending = true;
        _info = 'تم التسجيل ✅ بانتظار موافقة المالك وتفعيل حسابك.';
      } else {
        _error = r.msg;
      }
    });
  }

  Future<void> _login() async {
    if (!_valid) {
      setState(() => _error = 'اكتب كود المحل واسمك والكود السري');
      return;
    }
    setState(() { _loading = true; _error = null; _info = null; });
    final r = await SupabaseService.employeeLogin(
      shopCode: _shopCtrl.text, name: _nameCtrl.text, pin: _pinCtrl.text,
    );
    if (!mounted) return;

    switch (r.status) {
      case 'active':
        // الجلسة اتفتحت — الـ AuthGate هيحمّل البيانات. نقفل الشاشة دي.
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      case 'pending':
        setState(() {
          _loading = false; _pending = true;
          _info = 'حسابك لسه بانتظار موافقة المالك ⏳';
        });
        break;
      case 'disabled':
        setState(() {
          _loading = false;
          _error = 'حسابك موقوف. تواصل مع المالك.';
        });
        break;
      default:
        setState(() { _loading = false; _error = r.msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d47a1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('دخول الموظف',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const Text('👤', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(_isRegister ? 'تسجيل موظف جديد' : 'دخول الموظف',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0d47a1))),
                  const SizedBox(height: 20),

                  _field(_shopCtrl, 'كود المحل', Icons.store_outlined, ltr: true),
                  const SizedBox(height: 12),
                  _field(_nameCtrl, 'اسمك', Icons.person_outline),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'الكود السري',
                      labelStyle: GoogleFonts.cairo(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: const Color(0xFFF5F7FA),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _banner(_error!, const Color(0xFFFFEBEB), Colors.red.shade700),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 10),
                    _banner(_info!, const Color(0xFFE8F5E9), Colors.green.shade800),
                  ],
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : (_isRegister ? _register : _login),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0d47a1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _pending ? 'تأكد من الموافقة'
                                       : (_isRegister ? 'تسجيل' : 'دخول'),
                              style: GoogleFonts.cairo(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _error = null; _info = null; _pending = false;
                    }),
                    child: Text(
                      _isRegister ? 'عندك حساب موظف؟ سجّل دخول' : 'موظف جديد؟ سجّل الآن',
                      style: GoogleFonts.cairo(color: const Color(0xFF0d47a1), fontSize: 13),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text('اطلب «كود المحل» من صاحب المحل',
                  style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController c, String label, IconData icon, {bool ltr = false}) =>
      TextField(
        controller: c,
        textDirection: ltr ? TextDirection.ltr : null,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label, labelStyle: GoogleFonts.cairo(),
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: const Color(0xFFF5F7FA),
        ),
      );
}
