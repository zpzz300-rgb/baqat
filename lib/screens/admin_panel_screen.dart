// lib/screens/admin_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
// AdminUnlockWrapper — wraps any widget; 5 taps + password = panel
// ─────────────────────────────────────────────────────────────────
class AdminUnlockWrapper extends StatefulWidget {
  final Widget child;
  const AdminUnlockWrapper({super.key, required this.child});
  @override
  State<AdminUnlockWrapper> createState() => _AdminUnlockWrapperState();
}

class _AdminUnlockWrapperState extends State<AdminUnlockWrapper> {
  int _taps = 0;
  DateTime? _lastTap;

  void _onTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inSeconds > 3) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;
    if (_taps >= 5) {
      _taps = 0;
      _showPasswordDialog();
    }
  }

  void _showPasswordDialog() {
    final ctrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🔐 لوحة الإدارة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: ctrl,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'كلمة السر',
              labelStyle: GoogleFonts.cairo(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setSt(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (_) => _checkPass(ctx, ctrl.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0d47a1)),
              onPressed: () => _checkPass(ctx, ctrl.text),
              child: Text('دخول', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _checkPass(BuildContext ctx, String input) {
    Navigator.pop(ctx);
    if (AuthService.checkAdminPassword(input)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('كلمة السر غلط', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _onTap, child: widget.child);
  }
}

// ─────────────────────────────────────────────────────────────────
// Admin Panel Screen
// ─────────────────────────────────────────────────────────────────
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d47a1),
        title: Text('🔐 لوحة الإدارة',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: [
            Tab(child: Text('➕ مفتاح جديد', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700))),
            Tab(child: Text('📋 سجل المبيعات', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _GenerateKeyTab(),
          _SalesListTab(),
        ],
      ),
    );
  }
}

// ─── Generate Key Tab ─────────────────────────────────────────────
class _GenerateKeyTab extends StatefulWidget {
  const _GenerateKeyTab();
  @override
  State<_GenerateKeyTab> createState() => _GenerateKeyTabState();
}

class _GenerateKeyTabState extends State<_GenerateKeyTab> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _duration = 'year';
  bool   _loading  = false;
  String? _generatedKey;

  static const _durations = {
    'month':   'شهر (30 يوم)',
    'year':    'سنة (365 يوم)',
    'forever': 'دائم ♾️',
  };

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('أدخل اسم العميل', style: GoogleFonts.cairo())),
      );
      return;
    }
    setState(() { _loading = true; _generatedKey = null; });
    final r = await AuthService.createSubscription(
      customerName:  _nameCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim(),
      durationType:  _duration,
      notes:         _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );
    if (!mounted) return;
    if (r.ok) {
      setState(() { _generatedKey = r.key; _loading = false; });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.msg, style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer info
          _section('👤 بيانات العميل', [
            _field('الاسم الكامل', _nameCtrl, icon: Icons.person_outline),
            const SizedBox(height: 12),
            _field('رقم الموبايل', _phoneCtrl,
                keyboard: TextInputType.phone, dir: TextDirection.ltr,
                icon: Icons.phone_outlined),
          ]),
          const SizedBox(height: 16),

          // Duration
          _section('⏳ مدة الاشتراك', [
            Wrap(spacing: 8, runSpacing: 8, children: _durations.entries.map((e) {
              final sel = _duration == e.key;
              return GestureDetector(
                onTap: () => setState(() => _duration = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF0d47a1) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: sel ? const Color(0xFF0d47a1) : AppColors.border, width: 2),
                  ),
                  child: Text(e.value, style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.text)),
                ),
              );
            }).toList()),
          ]),
          const SizedBox(height: 16),

          // Notes
          _section('📝 ملاحظات', [
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'ملاحظات إضافية (اختياري)',
                hintStyle: GoogleFonts.cairo(color: AppColors.muted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Generate button
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.generating_tokens_rounded, color: Colors.white),
              label: Text('توليد رمز التفعيل',
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0d47a1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // Result card
          if (_generatedKey != null) ...[
            const SizedBox(height: 24),
            _KeyResultCard(
              key: ValueKey(_generatedKey),
              keyCode:  _generatedKey!,
              name:     _nameCtrl.text.trim(),
              phone:    _phoneCtrl.text.trim(),
              duration: _durations[_duration]!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: GoogleFonts.cairo(
          fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.blue2)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ],
  );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType keyboard = TextInputType.text,
      TextDirection dir = TextDirection.rtl,
      IconData? icon}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        textDirection: dir,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(),
          prefixIcon: icon != null ? Icon(icon, size: 18) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

// ─── Key Result Card ──────────────────────────────────────────────
class _KeyResultCard extends StatelessWidget {
  final String keyCode, name, phone, duration;
  const _KeyResultCard({
    super.key,
    required this.keyCode,
    required this.name,
    required this.phone,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565c0), Color(0xFF0d47a1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Text('✅ تم توليد الرمز بنجاح',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(keyCode,
                style: GoogleFonts.robotoMono(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
          ),
          const SizedBox(height: 8),
          Text('$name • $duration',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _btn(
              context,
              icon: Icons.copy_rounded,
              label: 'نسخ',
              color: Colors.white24,
              onTap: () {
                Clipboard.setData(ClipboardData(text: keyCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم نسخ الرمز ✅', style: GoogleFonts.cairo())),
                );
              },
            )),
            const SizedBox(width: 10),
            if (phone.isNotEmpty)
              Expanded(child: _btn(
                context,
                icon: Icons.chat_rounded,
                label: 'واتساب',
                color: const Color(0xFF25D366),
                onTap: () => _sendWhatsApp(phone, name, keyCode),
              )),
          ]),
        ],
      ),
    );
  }

  Widget _btn(BuildContext ctx, {required IconData icon, required String label,
      required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  void _sendWhatsApp(String phone, String name, String key) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final num = clean.startsWith('0') ? '2$clean' : clean; // Egypt prefix
    final msg = Uri.encodeComponent(
        'أهلاً يا $name 👋\nكود تفعيل تطبيق باقات الاتصالات:\n\n🔑 $key\n\nادخل الكود في التطبيق لتفعيله.');
    final url = Uri.parse('https://wa.me/$num?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Sales List Tab ───────────────────────────────────────────────
class _SalesListTab extends StatefulWidget {
  const _SalesListTab();
  @override
  State<_SalesListTab> createState() => _SalesListTabState();
}

class _SalesListTabState extends State<_SalesListTab> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await AuthService.fetchSubscriptions();
    if (!mounted) return;
    setState(() { _all = rows; _filtered = rows; _loading = false; });
  }

  void _filter(String q) {
    q = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((r) =>
              (r['customer_name'] ?? '').toLowerCase().contains(q) ||
              (r['customer_phone'] ?? '').contains(q) ||
              (r['key_code'] ?? '').toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: '🔍 بحث بالاسم أو الرقم أو الكود...',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 16),
                      onPressed: () { _searchCtrl.clear(); _filter(''); }) : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Text('${_filtered.length} عميل',
                style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
            const Spacer(),
            GestureDetector(
              onTap: _load,
              child: const Icon(Icons.refresh, color: AppColors.muted, size: 18),
            ),
          ]),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(child: Text('لا توجد نتائج', style: GoogleFonts.cairo(color: AppColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _SubCard(sub: _filtered[i], onRevoke: _load),
                ),
        ),
      ],
    );
  }
}

class _SubCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  final VoidCallback onRevoke;
  const _SubCard({required this.sub, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final name    = sub['customer_name'] ?? '-';
    final phone   = sub['customer_phone'] ?? '';
    final key     = sub['key_code'] ?? '';
    final active  = sub['is_active'] == true;
    final bound   = sub['device_id'] != null;
    final expiry  = sub['expiry_date'] != null
        ? DateTime.tryParse(sub['expiry_date'].toString()) : null;
    final expired = expiry != null && DateTime.now().isAfter(expiry);
    final daysLeft = expiry?.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AppColors.border : AppColors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(name,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14))),
            if (!active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(6)),
                child: Text('معطّل', style: GoogleFonts.cairo(color: AppColors.red2, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
          ]),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(phone, style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          // Key
          Row(children: [
            Expanded(
              child: Text(key,
                  style: GoogleFonts.robotoMono(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.blue2, letterSpacing: 2)),
            ),
            GestureDetector(
              onTap: () { Clipboard.setData(ClipboardData(text: key)); },
              child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.muted),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip(bound ? '📱 مرتبط بجهاز' : '⚪ غير مرتبط',
                bound ? AppColors.blueLight : const Color(0xFFF5F5F5),
                bound ? AppColors.blue2 : AppColors.muted),
            if (expiry == null)
              _chip('♾️ دائم', AppColors.greenLight, AppColors.green2)
            else if (expired)
              _chip('⛔ منتهي', AppColors.redLight, AppColors.red2)
            else
              _chip('✅ $daysLeft يوم متبقي', AppColors.greenLight, AppColors.green2),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (phone.isNotEmpty)
              _actionBtn('واتساب', const Color(0xFF25D366), () => _whatsapp(phone, name, key)),
            const SizedBox(width: 8),
            if (active)
              _actionBtn('إلغاء الربط', AppColors.orange, () async {
                await AuthService.revokeSubscription(sub['id']);
                onRevoke();
              }),
          ]),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: text)),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label, style: GoogleFonts.cairo(
          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ),
  );

  void _whatsapp(String phone, String name, String key) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final num = clean.startsWith('0') ? '2$clean' : clean;
    final msg = Uri.encodeComponent(
        'أهلاً يا $name 👋\nكود تفعيل تطبيق باقات الاتصالات:\n\n🔑 $key\n\nادخل الكود في التطبيق لتفعيله.');
    final url = Uri.parse('https://wa.me/$num?text=$msg');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
