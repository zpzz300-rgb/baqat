// lib/screens/admin_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/app_theme.dart';
import '../services/export_service.dart';

// ─────────────────────────────────────────────────────────────────
// showAdminPasswordDialog — نافذة كلمة سر لوحة الإدارة (ضغطة مطوّلة على
// عنوان شاشة الإعدادات، بدل الـ5 ضغطات القديمة على عنوان الرئيسية).
// ─────────────────────────────────────────────────────────────────
void showAdminPasswordDialog(BuildContext context) {
  final ctrl = TextEditingController();
  bool obscure = true;
  String? error;

  void checkPass(BuildContext ctx, String input, void Function(String) onError) {
    if (AuthService.checkAdminPassword(input)) {
      Navigator.pop(ctx);
      try {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فتح اللوحة: $e', style: GoogleFonts.cairo())),
        );
      }
    } else {
      onError('❌ كلمة السر غلط');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ كلمة السر غلط', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🔐 لوحة الإدارة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              obscureText: obscure,
              autofocus: true,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setSt(() => obscure = !obscure),
                ),
              ),
              onSubmitted: (v) => checkPass(ctx, v, (msg) => setSt(() => error = msg)),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: GoogleFonts.cairo(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0d47a1)),
            onPressed: () => checkPass(ctx, ctrl.text, (msg) => setSt(() => error = msg)),
            child: Text('دخول', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    ),
  );
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
    _tabs = TabController(length: 3, vsync: this);
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
          isScrollable: true,
          tabs: [
            Tab(child: Text('➕ مفتاح جديد', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700))),
            Tab(child: Text('📋 سجل المبيعات', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700))),
            Tab(child: Text('📱 كل التثبيتات', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _GenerateKeyTab(),
          _SalesListTab(),
          _InstallationsTab(),
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
  String _quickFilter = 'all'; // all | active | expired | frozen | vip | soon
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await AuthService.fetchSubscriptions();
    if (!mounted) return;
    setState(() { _all = rows; _loading = false; });
    _applyFilters();
  }

  bool _isExpired(Map<String, dynamic> r) {
    final expiry = r['expiry_date'] != null ? DateTime.tryParse(r['expiry_date'].toString()) : null;
    if (expiry == null) return false;
    final grace = (r['grace_days'] as num?)?.toInt() ?? 0;
    return DateTime.now().isAfter(expiry.add(Duration(days: grace)));
  }

  bool _isExpiringSoon(Map<String, dynamic> r) {
    final expiry = r['expiry_date'] != null ? DateTime.tryParse(r['expiry_date'].toString()) : null;
    if (expiry == null) return false;
    final days = expiry.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 7;
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((r) {
        if (q.isNotEmpty) {
          final hay = '${r['customer_name'] ?? ''} ${r['customer_phone'] ?? ''} ${r['key_code'] ?? ''}'.toLowerCase();
          if (!hay.contains(q)) return false;
        }
        switch (_quickFilter) {
          case 'active':
            return r['is_active'] == true && !_isExpired(r);
          case 'expired':
            return _isExpired(r);
          case 'frozen':
            return r['is_active'] == false;
          case 'vip':
            return r['is_vip'] == true;
          case 'soon':
            return _isExpiringSoon(r);
          default:
            return true;
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final activeCount = _all.where((r) => r['is_active'] == true && !_isExpired(r)).length;
    final expiredCount = _all.where(_isExpired).length;
    final frozenCount = _all.where((r) => r['is_active'] == false).length;
    final vipCount = _all.where((r) => r['is_vip'] == true).length;

    return Column(
      children: [
        // ── ملخص سريع ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            _statTile('${_all.length}', 'الكل', AppColors.blueLight, AppColors.blue2),
            const SizedBox(width: 6),
            _statTile('$activeCount', 'نشط', AppColors.greenLight, AppColors.green2),
            const SizedBox(width: 6),
            _statTile('$expiredCount', 'منتهي', AppColors.redLight, AppColors.red2),
            const SizedBox(width: 6),
            _statTile('$frozenCount', 'مجمّد', const Color(0xFFF5F5F5), AppColors.muted),
            const SizedBox(width: 6),
            _statTile('$vipCount', 'VIP', const Color(0xFFFFF8E1), const Color(0xFFF9A825)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: '🔍 بحث بالاسم أو الرقم أو الكود...',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 16),
                      onPressed: () { _searchCtrl.clear(); _applyFilters(); }) : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('الكل', 'all'),
                _filterChip('نشط', 'active'),
                _filterChip('منتهي', 'expired'),
                _filterChip('مجمّد', 'frozen'),
                _filterChip('⭐ VIP', 'vip'),
                _filterChip('هينتهي قريب', 'soon'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(children: [
            Text('${_filtered.length} عميل',
                style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
            const Spacer(),
            GestureDetector(
              onTap: () => ExportService.exportSubscriptionsExcel(context, _filtered),
              child: const Icon(Icons.table_view, color: AppColors.muted, size: 18),
            ),
            const SizedBox(width: 12),
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

  Widget _statTile(String value, String label, Color bg, Color fg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: fg)),
            Text(label, style: GoogleFonts.cairo(fontSize: 9, color: fg)),
          ]),
        ),
      );

  Widget _filterChip(String label, String key) {
    final active = _quickFilter == key;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () { setState(() => _quickFilter = key); _applyFilters(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.blue2 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? AppColors.blue2 : AppColors.border),
          ),
          child: Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.text)),
        ),
      ),
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
    final id      = sub['id'].toString();
    final active  = sub['is_active'] == true;
    final vip     = sub['is_vip'] == true;
    final bound   = sub['device_id'] != null;
    final graceDays = (sub['grace_days'] as num?)?.toInt() ?? 0;
    final notes   = (sub['notes'] ?? '').toString();
    final expiry  = sub['expiry_date'] != null
        ? DateTime.tryParse(sub['expiry_date'].toString()) : null;
    final expired = expiry != null &&
        DateTime.now().isAfter(expiry.add(Duration(days: graceDays)));
    final daysLeft = expiry?.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vip ? const Color(0xFFFFFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: vip
                ? const Color(0xFFF9A825).withValues(alpha: 0.6)
                : (active ? AppColors.border : AppColors.red.withValues(alpha: 0.4)),
            width: vip ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () async {
                await AuthService.setSubscriptionVip(id, !vip);
                onRevoke();
              },
              child: Icon(vip ? Icons.star_rounded : Icons.star_border_rounded,
                  color: vip ? const Color(0xFFF9A825) : AppColors.muted, size: 20),
            ),
            const SizedBox(width: 4),
            Expanded(child: Text(name,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14))),
            GestureDetector(
              onTap: () => _showTimeline(context),
              child: const Icon(Icons.history, size: 18, color: AppColors.muted),
            ),
            const SizedBox(width: 8),
            if (!active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(6)),
                child: Text('مجمّد/معطّل', style: GoogleFonts.cairo(color: AppColors.red2, fontSize: 10, fontWeight: FontWeight.w700)),
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
            if (graceDays > 0)
              _chip('🕊️ سماح $graceDays يوم', const Color(0xFFF3E5F5), const Color(0xFF6a1b9a)),
          ]),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('📝 $notes', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (phone.isNotEmpty)
              _actionBtn('واتساب', const Color(0xFF25D366), () => _whatsapp(phone, name, key)),
            _actionBtn('تمديد/تقصير', AppColors.blue2, () => _showAdjustDays(context)),
            _actionBtn('سماح', const Color(0xFF6a1b9a), () => _showGraceDialog(context)),
            _actionBtn('ملاحظة', AppColors.muted, () => _showNotesDialog(context, notes)),
            active
                ? _actionBtn('تجميد', AppColors.orange, () async {
                    await AuthService.freezeSubscription(id);
                    onRevoke();
                  })
                : _actionBtn('إلغاء التجميد', AppColors.green, () async {
                    await AuthService.unfreezeSubscription(id);
                    onRevoke();
                  }),
            if (active)
              _actionBtn('إلغاء الربط', AppColors.red, () async {
                await AuthService.revokeSubscription(id);
                onRevoke();
              }),
          ]),
        ],
      ),
    );
  }

  void _showAdjustDays(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('⏳ تمديد أو تقصير المدة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'عدد الأيام (سالب = تقصير)',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            Text('مثال: 30 لتمديد شهر، -30 لتقصير شهر',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final days = int.tryParse(ctrl.text.trim());
              if (days == null || days == 0) return;
              Navigator.pop(context);
              final ok = await AuthService.adjustSubscriptionDays(sub['id'].toString(), days);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ مينفعش تعدّل — الاشتراك دائم', style: GoogleFonts.cairo())));
              }
              onRevoke();
            },
            child: Text('تأكيد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showGraceDialog(BuildContext context) {
    final ctrl = TextEditingController(text: '${(sub['grace_days'] as num?)?.toInt() ?? 0}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🕊️ فترة السماح', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'عدد أيام السماح بعد انتهاء الاشتراك',
            labelStyle: GoogleFonts.cairo(fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final days = int.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(context);
              await AuthService.setSubscriptionGraceDays(sub['id'].toString(), days);
              onRevoke();
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('📝 ملاحظة العميل', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'اكتب ملاحظة عن العميل...',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.updateSubscriptionNotes(sub['id'].toString(), ctrl.text.trim());
              onRevoke();
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showTimeline(BuildContext context) {
    final history = sub['history'] is List ? List.from(sub['history']) : [];
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, sc) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFf8fbff),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('🕓 سجل ${sub['customer_name'] ?? ''}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              const Divider(height: 1),
              Expanded(
                child: history.isEmpty
                    ? Center(child: Text('مفيش سجل لسه', style: GoogleFonts.cairo(color: AppColors.muted)))
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.all(14),
                        itemCount: history.length,
                        itemBuilder: (_, i) {
                          final h = history[i];
                          final date = DateTime.tryParse(h['date']?.toString() ?? '');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Expanded(child: Text(h['event']?.toString() ?? '',
                                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700))),
                              if (date != null)
                                Text('${date.day}/${date.month}/${date.year}',
                                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                            ]),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
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

/// هوية جهاز في لوحة الإدارة بعد ربطه بصاحبه.
/// kind: owner = صاحب محل، employee = موظف بيشتغل على محل، unknown = جهاز
/// نزّل البرنامج ومسجّلش دخول (فمفيش أي طريقة نعرف منها مين هو).
class InstallIdentity {
  final String kind;
  final String title;        // اسم المحل/العميل
  final String? phone;
  final String? employeeName; // لو الدخول كان بموظف
  final String? email;
  final String? deviceId;
  const InstallIdentity({
    required this.kind,
    required this.title,
    this.phone,
    this.employeeName,
    this.email,
    this.deviceId,
  });
}

// ─── Installations Tab — كل جهاز فتح البرنامج (تجريبي + مفعّل) ──────
class _InstallationsTab extends StatefulWidget {
  const _InstallationsTab();
  @override
  State<_InstallationsTab> createState() => _InstallationsTabState();
}

class _InstallationsTabState extends State<_InstallationsTab> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, Map<String, dynamic>> _subsByKey = {};
  bool _loading = true;
  String _statusFilter = 'all'; // all | trial | active | expired | recent | inactive
  String _kindFilter = 'all'; // all | owner | employee | unknown
  /// user_id لصاحب المحل → اسمه ورقمه (بيتبني من صفوف الأجهزة نفسها)
  Map<String, ({String? name, String? phone})> _ownerIndex = {};
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final installs = await AuthService.fetchInstallations();
    final subs = await AuthService.fetchSubscriptions();
    if (!mounted) return;
    setState(() {
      _all = installs;
      _subsByKey = {for (final s in subs) if (s['key_code'] != null) s['key_code'].toString(): s};
      _ownerIndex = _buildOwnerIndex(installs);
      _loading = false;
    });
    _applyFilter();
  }

  /// بيبني دليل «حساب المحل → اسمه ورقمه» من صفوف الأجهزة نفسها.
  /// بنعمل كده بدل ما نقرا جداول العملاء مباشرة، لأن صلاحيات قاعدة البيانات
  /// (وده مقصود) بتمنع أي حساب من قراءة بيانات حساب تاني.
  Map<String, ({String? name, String? phone})> _buildOwnerIndex(
      List<Map<String, dynamic>> rows) {
    final idx = <String, ({String? name, String? phone})>{};
    for (final r in rows) {
      // جهاز الموظف مبيحملش بيانات صاحب المحل — بناخدها من جهاز المالك نفسه
      if (r['account_type'] == 'employee') continue;
      final uid = r['user_id']?.toString();
      if (uid == null || uid.isEmpty) continue;
      final name = (r['customer_name'] as String?)?.trim();
      final phone = (r['customer_phone'] as String?)?.trim();
      if ((name == null || name.isEmpty) && (phone == null || phone.isEmpty)) {
        continue;
      }
      final prev = idx[uid];
      idx[uid] = (
        name: (name?.isNotEmpty == true) ? name : prev?.name,
        phone: (phone?.isNotEmpty == true) ? phone : prev?.phone,
      );
    }
    return idx;
  }

  /// هوية الصف بعد الربط — ده اللي بيشيل «بدون اسم».
  /// kind: owner | employee | unknown
  InstallIdentity _identityOf(Map<String, dynamic> inst) {
    final manualName = (inst['customer_name'] as String?)?.trim();
    final manualPhone = (inst['customer_phone'] as String?)?.trim();
    final sub = _subsByKey[inst['key_code']?.toString() ?? ''];
    final subName = (sub?['customer_name'] as String?)?.trim();
    final subPhone = (sub?['customer_phone'] as String?)?.trim();

    String? pick(String? a, String? b) =>
        (a?.isNotEmpty == true) ? a : ((b?.isNotEmpty == true) ? b : null);

    final type = inst['account_type']?.toString();

    if (type == 'employee') {
      final empName = (inst['employee_name'] as String?)?.trim();
      final owner = _ownerIndex[inst['owner_user_id']?.toString() ?? ''];
      return InstallIdentity(
        kind: 'employee',
        title: pick(owner?.name, pick(manualName, subName)) ?? 'محل غير معروف',
        phone: pick(owner?.phone, pick(manualPhone, subPhone)),
        employeeName: empName?.isNotEmpty == true ? empName : 'موظف',
      );
    }

    final name = pick(manualName, subName);
    final phone = pick(manualPhone, subPhone);
    if (name != null || phone != null || type == 'owner') {
      return InstallIdentity(
        kind: 'owner',
        title: name ?? phone ?? 'صاحب محل',
        phone: phone,
        email: (inst['login_email'] as String?)?.trim(),
      );
    }

    // مفيش أي هوية — الجهاز نزّل البرنامج ومسجّلش دخول
    return InstallIdentity(
      kind: 'unknown',
      title: 'جهاز مسجّلش دخول',
      deviceId: inst['device_id']?.toString(),
    );
  }

  // trial | trial_expired | active | expired
  String _statusOf(Map<String, dynamic> inst) {
    final keyCode = inst['key_code']?.toString();
    if (keyCode == null || keyCode.isEmpty) {
      final firstSeen = DateTime.tryParse(inst['first_seen']?.toString() ?? '');
      if (firstSeen != null && DateTime.now().difference(firstSeen).inDays >= 30) {
        return 'trial_expired';
      }
      return 'trial';
    }
    final sub = _subsByKey[keyCode];
    if (sub == null) return 'trial';
    if (sub['is_active'] == false) return 'expired';
    final expiryStr = sub['expiry_date']?.toString();
    if (expiryStr != null && expiryStr.isNotEmpty) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) return 'expired';
    }
    return 'active';
  }

  bool _isRecent(Map<String, dynamic> inst) {
    final lastSeen = DateTime.tryParse(inst['last_seen']?.toString() ?? '');
    return lastSeen != null && DateTime.now().difference(lastSeen).inDays <= 3;
  }

  Map<String, int> _phoneCounts() {
    final counts = <String, int>{};
    for (final inst in _all) {
      final phone = (inst['customer_phone'] as String?)?.trim();
      if (phone != null && phone.isNotEmpty) {
        counts[phone] = (counts[phone] ?? 0) + 1;
      }
    }
    return counts;
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((inst) {
        if (_statusFilter == 'recent' && !_isRecent(inst)) return false;
        if (_statusFilter == 'inactive' && _isRecent(inst)) return false;
        if (_statusFilter == 'trial' && _statusOf(inst) != 'trial') return false;
        if (_statusFilter == 'active' && _statusOf(inst) != 'active') return false;
        if (_statusFilter == 'expired' &&
            !(_statusOf(inst) == 'expired' || _statusOf(inst) == 'trial_expired')) {
          return false;
        }
        final id = _identityOf(inst);
        if (_kindFilter != 'all' && id.kind != _kindFilter) return false;
        if (q.isNotEmpty) {
          final hay = '${inst['customer_name'] ?? ''} ${inst['customer_phone'] ?? ''} '
                  '${inst['device_id'] ?? ''} ${inst['key_code'] ?? ''} '
                  '${inst['employee_name'] ?? ''} ${inst['login_email'] ?? ''} '
                  '${id.title} ${id.phone ?? ''}'
              .toLowerCase();
          if (!hay.contains(q)) return false;
        }
        return true;
      }).toList();
      // الأحدث ظهوراً الأول
      _filtered.sort((a, b) {
        final da = DateTime.tryParse(a['last_seen']?.toString() ?? '');
        final db = DateTime.tryParse(b['last_seen']?.toString() ?? '');
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final trialCount = _all.where((i) => _statusOf(i) == 'trial').length;
    final activeCount = _all.where((i) => _statusOf(i) == 'active').length;
    final expiredCount = _all
        .where((i) => _statusOf(i) == 'expired' || _statusOf(i) == 'trial_expired')
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            Expanded(child: _counterChip('$trialCount', 'تجريبي', const Color(0xFF6a1b9a), const Color(0xFFF3E5F5))),
            const SizedBox(width: 6),
            Expanded(child: _counterChip('$activeCount', 'مفعّل', AppColors.green2, AppColors.greenLight)),
            const SizedBox(width: 6),
            Expanded(child: _counterChip('$expiredCount', 'منتهي', AppColors.red2, AppColors.redLight)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilter(),
            decoration: InputDecoration(
              hintText: '🔍 بحث بالاسم أو الرقم أو الجهاز أو الكود...',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 16),
                      onPressed: () { _searchCtrl.clear(); _applyFilter(); }) : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('all', 'الكل'),
                _filterChip('trial', 'تجريبي'),
                _filterChip('active', 'مفعّل'),
                _filterChip('expired', 'منتهي'),
                _filterChip('recent', '🟢 نشط الآن'),
                _filterChip('inactive', '⚪ مش نشط'),
              ],
            ),
          ),
        ),
        // فلتر نوع الحساب — مالك / موظف / جهاز مسجّلش دخول
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _kindChip('all', 'كل الأنواع'),
                _kindChip('owner', '🏪 أصحاب محلات'),
                _kindChip('employee', '👤 موظفين'),
                _kindChip('unknown', '❓ مسجّلش دخول'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Text('${_filtered.length} جهاز',
                style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
            const Spacer(),
            GestureDetector(onTap: _load, child: const Icon(Icons.refresh, color: AppColors.muted, size: 18)),
          ]),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(child: Text('لا توجد نتائج', style: GoogleFonts.cairo(color: AppColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final phone = (_filtered[i]['customer_phone'] as String?)?.trim() ?? '';
                    return _InstallCard(
                      inst: _filtered[i],
                      identity: _identityOf(_filtered[i]),
                      status: _statusOf(_filtered[i]),
                      isRecent: _isRecent(_filtered[i]),
                      phoneCount: phone.isEmpty ? 1 : _phoneCounts()[phone] ?? 1,
                      onEdit: () => _editInstall(_filtered[i]),
                      onTapPhoneCount: phone.isEmpty ? null : () {
                        _searchCtrl.text = phone;
                        _applyFilter();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _counterChip(String value, String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: fg)),
      Text(label, style: GoogleFonts.cairo(fontSize: 10, color: fg)),
    ]),
  );

  Widget _filterChip(String key, String label) {
    final active = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () { setState(() => _statusFilter = key); _applyFilter(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0d47a1) : const Color(0xFFf0f4f8),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.cairo(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.text)),
        ),
      ),
    );
  }

  Widget _kindChip(String key, String label) {
    final active = _kindFilter == key;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () { setState(() => _kindFilter = key); _applyFilter(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6a1b9a) : const Color(0xFFf0f4f8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active ? const Color(0xFF6a1b9a) : AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.cairo(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.text)),
        ),
      ),
    );
  }

  void _editInstall(Map<String, dynamic> inst) {
    final nameCtrl = TextEditingController(text: inst['customer_name'] ?? '');
    final phoneCtrl = TextEditingController(text: inst['customer_phone'] ?? '');
    final notesCtrl = TextEditingController(text: inst['notes'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✏️ بيانات الجهاز', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'اسم العميل', labelStyle: GoogleFonts.cairo()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: 'رقم الموبايل', labelStyle: GoogleFonts.cairo()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'ملاحظات', labelStyle: GoogleFonts.cairo()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final ok = await AuthService.updateInstallation(
                inst['device_id'].toString(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(context);
              if (ok) _load();
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _InstallCard extends StatelessWidget {
  final Map<String, dynamic> inst;
  final InstallIdentity identity;
  final String status;
  final bool isRecent;
  final int phoneCount;
  final VoidCallback onEdit;
  final VoidCallback? onTapPhoneCount;
  const _InstallCard({
    required this.inst,
    required this.identity,
    required this.status,
    required this.isRecent,
    this.phoneCount = 1,
    required this.onEdit,
    this.onTapPhoneCount,
  });

  (String, Color, Color) get _statusInfo => switch (status) {
        'active' => ('✅ مفعّل', AppColors.green2, AppColors.greenLight),
        'trial' => ('⏳ تجريبي', const Color(0xFF6a1b9a), const Color(0xFFF3E5F5)),
        'trial_expired' => ('⛔ تجريبي منتهي', AppColors.red2, AppColors.redLight),
        _ => ('⛔ منتهي', AppColors.red2, AppColors.redLight),
      };

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  /// بقاله قد إيه ما فتحش البرنامج
  String _idleLabel() {
    final last = DateTime.tryParse(inst['last_seen']?.toString() ?? '');
    if (last == null) return 'مش نشط';
    final days = DateTime.now().difference(last).inDays;
    if (days >= 365) return 'من ${days ~/ 365} سنة';
    if (days >= 30) return 'من ${days ~/ 30} شهر';
    return 'من $days يوم';
  }

  @override
  Widget build(BuildContext context) {
    final name = identity.title;
    final phone = identity.phone;
    final keyCode = inst['key_code']?.toString();
    final (statusLabel, statusFg, statusBg) = _statusInfo;
    final isUnknown = identity.kind == 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                isUnknown ? '❓ $name' : name,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 14,
                    color: isUnknown ? AppColors.muted : AppColors.text,
                    fontStyle: isUnknown ? FontStyle.italic : FontStyle.normal),
              ),
            ),
            // نشط الآن / مش نشط من كام يوم — عشان تعرف مين سايب البرنامج
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: isRecent ? AppColors.blueLight : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(
                  isRecent ? '🟢 نشط الآن' : '⚪ ${_idleLabel()}',
                  style: GoogleFonts.cairo(
                      fontSize: 9,
                      color: isRecent ? AppColors.blue2 : AppColors.muted,
                      fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
              child: Text(statusLabel, style: GoogleFonts.cairo(color: statusFg, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          // 👤 الموظف اللي سجّل دخول — وتحته صاحب المحل اللي هو تابع له
          if (identity.kind == 'employee') ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB39DDB)),
              ),
              child: Text('👤 دخل بموظف: ${identity.employeeName}',
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4527A0))),
            ),
          ],
          if (identity.kind == 'unknown') ...[
            const SizedBox(height: 2),
            Text('نزّل البرنامج وما سجّلش دخول — مفيش بيانات تعرّفه',
                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
          ],
          if (identity.email?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text('✉️ ${identity.email}',
                style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted),
                textDirection: TextDirection.ltr),
          ],
          if (phone?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Row(children: [
              Text(phone!, style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12), textDirection: TextDirection.ltr),
              if (phoneCount > 1) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onTapPhoneCount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                    child: Text('🔁 على $phoneCount أجهزة', style: GoogleFonts.cairo(fontSize: 9, color: const Color(0xFFE65100), fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ]),
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _infoChip('📅 نزّل: ${_fmtDate(inst['first_seen']?.toString())}'),
            _infoChip('👁 آخر ظهور: ${_fmtDate(inst['last_seen']?.toString())}'),
            if (keyCode != null && keyCode.isNotEmpty) _infoChip('🔑 $keyCode'),
          ]),
          if ((inst['notes'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text('📝 ${inst['notes']}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.blue2.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blue2.withValues(alpha: 0.4))),
                child: Text('✏️ تعديل البيانات', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.blue2)),
              ),
            ),
            if (phone?.isNotEmpty == true) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _whatsapp(phone!, name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.5))),
                  child: Text('واتساب', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF25D366))),
                ),
              ),
              const SizedBox(width: 8),
              _actionBtn('📞 اتصال', const Color(0xFF1565C0),
                  () => _call(phone!)),
            ],
            const SizedBox(width: 8),
            // نسخ رقم الجهاز — بيفيد لما تحب تدوّر عليه أو تربطه بمفتاح
            _actionBtn('📋 نسخ الجهاز', AppColors.muted, () async {
              final id = inst['device_id']?.toString() ?? '';
              await Clipboard.setData(ClipboardData(text: id));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('اتنسخ: $id',
                        style: GoogleFonts.cairo(), textAlign: TextAlign.center)));
              }
            }),
          ]),
        ],
      ),
    );
  }

  Widget _infoChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4))),
          child: Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      );

  void _call(String phone) async {
    final url = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _whatsapp(String phone, String name) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final num = clean.startsWith('0') ? '2$clean' : clean;
    final msg = Uri.encodeComponent('أهلاً يا $name 👋');
    final url = Uri.parse('https://wa.me/$num?text=$msg');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
