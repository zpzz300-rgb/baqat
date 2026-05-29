// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool   _obscure  = true;
  bool   _loading  = false;
  bool   _isSignUp = false;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'أدخل البريد وكلمة السر');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final r = _isSignUp
        ? await SupabaseService.signUp(email, pass)
        : await SupabaseService.signIn(email, pass);

    if (!mounted) return;
    if (!r.ok) setState(() { _error = r.msg; _loading = false; });
    // لو نجح — الـ AuthGate في main.dart هيتعامل مع الباقي تلقائي
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d47a1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const Text('📡', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 10),
              Text('باقات الاتصالات',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              Text('Pro Ledger',
                  style: GoogleFonts.cairo(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(_isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0d47a1))),
                  const SizedBox(height: 20),

                  // Email
                  _field(controller: _emailCtrl, label: 'البريد الإلكتروني',
                      keyboard: TextInputType.emailAddress, icon: Icons.email_outlined),
                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textDirection: TextDirection.ltr,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة السر',
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFFFEBEB), borderRadius: BorderRadius.circular(8)),
                      child: Text(_error!, textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0d47a1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_isSignUp ? 'إنشاء الحساب' : 'دخول',
                              style: GoogleFonts.cairo(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                    child: Text(
                      _isSignUp ? 'عندك حساب؟ سجّل دخول' : 'مفيش حساب؟ سجّل الآن',
                      style: GoogleFonts.cairo(color: const Color(0xFF0d47a1), fontSize: 13),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),
              Text('30 يوم تجريبي مجاناً بعد التسجيل',
                  style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field({required TextEditingController controller, required String label,
      TextInputType keyboard = TextInputType.text, required IconData icon}) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label, labelStyle: GoogleFonts.cairo(),
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: const Color(0xFFF5F7FA),
        ),
      );
}
