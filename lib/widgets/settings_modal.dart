// lib/widgets/settings_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/export_service.dart';
import '../screens/activation_screen.dart';
import '../screens/neumorphic_demo_screen.dart';
import 'common.dart';
import 'pin_dialog.dart';

class SettingsModal extends StatefulWidget {
  const SettingsModal({super.key});
  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  final _oldPinCtrl       = TextEditingController();
  final _newPinCtrl       = TextEditingController();
  final _thresholdCtrl    = TextEditingController();
  final _apiKeyCtrl       = TextEditingController();
  final _instapayCtrl     = TextEditingController();
  final _instapay2Ctrl    = TextEditingController();
  final _vodafoneCtrl     = TextEditingController();
  final _vodafone2Ctrl    = TextEditingController();
  final _bankCtrl         = TextEditingController();
  final _ownerNameCtrl    = TextEditingController();
  final _ownerPhoneCtrl   = TextEditingController();
  final _tgTokenCtrl      = TextEditingController();
  final _tgChatIdCtrl     = TextEditingController();
  final _debtNoteCtrl     = TextEditingController();
  bool  _apiKeyObscured   = true;
  bool  _tgTokenObscured  = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<AppProvider>();
    if (_thresholdCtrl.text.isEmpty)   _thresholdCtrl.text  = prov.debtThreshold.toStringAsFixed(0);
    if (_apiKeyCtrl.text.isEmpty)      _apiKeyCtrl.text     = prov.apiKey;
    if (_instapayCtrl.text.isEmpty)    _instapayCtrl.text   = prov.instapayPhone;
    if (_instapay2Ctrl.text.isEmpty)   _instapay2Ctrl.text  = prov.instapayPhone2;
    if (_vodafoneCtrl.text.isEmpty)    _vodafoneCtrl.text   = prov.vodafoneCash;
    if (_vodafone2Ctrl.text.isEmpty)   _vodafone2Ctrl.text  = prov.vodafoneCash2;
    if (_bankCtrl.text.isEmpty)        _bankCtrl.text       = prov.bankInfo;
    if (_ownerNameCtrl.text.isEmpty)   _ownerNameCtrl.text  = prov.ownerName;
    if (_ownerPhoneCtrl.text.isEmpty)  _ownerPhoneCtrl.text = prov.ownerPhone;
    if (_tgTokenCtrl.text.isEmpty)     _tgTokenCtrl.text    = prov.telegramToken;
    if (_tgChatIdCtrl.text.isEmpty)    _tgChatIdCtrl.text   = prov.telegramChatId;
    if (_debtNoteCtrl.text.isEmpty)    _debtNoteCtrl.text   = prov.debtNoteText;
  }

  @override
  void dispose() {
    _oldPinCtrl.dispose(); _newPinCtrl.dispose(); _thresholdCtrl.dispose();
    _apiKeyCtrl.dispose(); _instapayCtrl.dispose(); _instapay2Ctrl.dispose();
    _vodafoneCtrl.dispose(); _vodafone2Ctrl.dispose();
    _bankCtrl.dispose(); _ownerNameCtrl.dispose(); _ownerPhoneCtrl.dispose();
    _tgTokenCtrl.dispose(); _tgChatIdCtrl.dispose(); _debtNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚙️ إعدادات البرنامج', style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.blue2)),
            const SizedBox(height: 16),

            // Neumorphism design preview (top — easy to find)
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const NeumorphicDemoScreen()));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E5EC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(4, 4), blurRadius: 10),
                    BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E5EC),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(3, 3), blurRadius: 6),
                        BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF1565C0), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('👁 معاينة التصميم الجديد',
                          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF4A5568))),
                      Text('ستايل Neumorphism + قائمة جانبية',
                          style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF8A97A8))),
                    ]),
                  ),
                  const Icon(Icons.arrow_back_ios, color: Color(0xFF8A97A8), size: 16),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Font size
            Text('🔤 حجم الخط', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2)),
            const SizedBox(height: 8),
            Row(children: [
              _fsBtn(prov, 'small', 'صغير', 12),
              const SizedBox(width: 8),
              _fsBtn(prov, 'medium', 'متوسط', 14),
              const SizedBox(width: 8),
              _fsBtn(prov, 'large', 'كبير', 16),
            ]),
            const SizedBox(height: 16),

            // Theme style
            Text('🎨 ثيم التطبيق', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _styleBtn(prov, 'classic', '🔵 كلاسيكي', const Color(0xFF0d47a1))),
              const SizedBox(width: 6),
              Expanded(child: _styleBtn(prov, 'emerald', '🟢 زمردي', const Color(0xFF1b5e20))),
              const SizedBox(width: 6),
              Expanded(child: _styleBtn(prov, 'purple',  '🟣 بنفسجي', const Color(0xFF4a148c))),
            ]),
            const SizedBox(height: 16),

            // Dark mode
            Text('🌙 الوضع الليلي', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _themeBtn(prov, false, '☀️ فاتح')),
              const SizedBox(width: 8),
              Expanded(child: _themeBtn(prov, true, '🌙 داكن')),
            ]),
            const SizedBox(height: 16),

            // Member view density
            Text('👥 شكل عرض العملاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _viewBtn(prov, true, '▦ مضغوط (3 في الصف)')),
              const SizedBox(width: 8),
              Expanded(child: _viewBtn(prov, false, '☰ تفصيلي')),
            ]),
            const SizedBox(height: 16),

            // PIN change
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFfff3e0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔐 تغيير الرقم السري', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: const Color(0xFFe65100))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _oldPinCtrl,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'الرقم السري الحالي',
                      hintStyle: GoogleFonts.cairo(fontSize: 13),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPinCtrl,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'الرقم السري الجديد (6 أرقام)',
                      hintStyle: GoogleFonts.cairo(fontSize: 13),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe65100)),
                      onPressed: () {
                        if (prov.changePin(_oldPinCtrl.text, _newPinCtrl.text)) {
                          AppSnackbar.show(context, '✅ تم تغيير الرقم السري');
                          _oldPinCtrl.clear();
                          _newPinCtrl.clear();
                        } else {
                          AppSnackbar.show(context, '❌ رقم سري خاطئ');
                        }
                      },
                      child: Text('🔐 تغيير الرقم السري', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Activation ────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivationScreen(
                    isExpired: false,
                    onActivated: () => Navigator.pop(context),
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user, color: Color(0xFF1565C0), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('🔑 تفعيل التطبيق / إدخال مفتاح الترخيص',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: const Color(0xFF1565C0))),
                      Text('اضغط هنا لإدخال مفتاح التفعيل في أي وقت',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Debt Alert Threshold ────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFef9a9a)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🚨 تنبيه الديون المرتفعة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.red2)),
                  const SizedBox(height: 4),
                  Text('أي عميل تتجاوز ديونه هذا المبلغ يظهر بإطار أحمر ومؤشر تحذير', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _thresholdCtrl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(),
                      decoration: InputDecoration(
                        hintText: '500',
                        hintStyle: GoogleFonts.cairo(),
                        suffixText: 'ج',
                        labelText: 'حد التنبيه',
                        labelStyle: GoogleFonts.cairo(),
                      ),
                    )),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red2,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final v = double.tryParse(_thresholdCtrl.text.trim());
                        if (v != null && v > 0) {
                          prov.setDebtThreshold(v);
                          AppSnackbar.show(context, '✅ تم ضبط حد التنبيه على ${v.toStringAsFixed(0)} ج');
                        }
                      },
                      child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Auto Backup ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF80cbc4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💾 نسخ احتياطي تلقائي',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.green2),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                            Text('يحفظ ملف JSON يومياً في المجلد Download',
                                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                                softWrap: true,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: prov.autoBackup,
                        activeThumbColor: AppColors.green,
                        onChanged: (v) => prov.setAutoBackup(v),
                      ),
                    ],
                  ),
                  if (prov.lastBackup != null) ...[
                    const SizedBox(height: 6),
                    Text('آخر نسخة: ${prov.lastBackup}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.green2, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.green2,
                        side: const BorderSide(color: AppColors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.backup, size: 18),
                      label: Text('نسخ احتياطي الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        final path = await prov.performBackup();
                        if (context.mounted) {
                          AppSnackbar.show(context, path != null
                              ? '✅ تم حفظ النسخة في: $path'
                              : '❌ فشل الحفظ');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── AI API Key ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFf3e5f5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFce93d8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🤖 مفتاح Gemini (Google AI Studio)', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: const Color(0xFF6a1b9a))),
                  const SizedBox(height: 4),
                  Text('مطلوب لتشغيل المساعد الذكي. احصل على المفتاح مجاناً من aistudio.google.com/app/apikey', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  StatefulBuilder(
                    builder: (ctx, setSt) => Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _apiKeyCtrl,
                            obscureText: _apiKeyObscured,
                            style: GoogleFonts.cairo(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'AIzaSy...',
                              hintStyle: GoogleFonts.cairo(fontSize: 12),
                              suffixIcon: IconButton(
                                icon: Icon(_apiKeyObscured ? Icons.visibility_off : Icons.visibility, size: 18),
                                onPressed: () => setSt(() => _apiKeyObscured = !_apiKeyObscured),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6a1b9a),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            context.read<AppProvider>().setApiKey(_apiKeyCtrl.text.trim());
                            AppSnackbar.show(context, '✅ تم حفظ المفتاح');
                          },
                          child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Owner Info ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blueMid),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('👤 بيانات صاحب الحساب', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2)),
                const SizedBox(height: 10),
                TextField(
                  controller: _ownerNameCtrl,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ownerPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(labelText: 'رقم الموبايل', labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue2, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () {
                    prov.setOwnerName(_ownerNameCtrl.text.trim());
                    prov.setOwnerPhone(_ownerPhoneCtrl.text.trim());
                    AppSnackbar.show(context, '✅ تم حفظ البيانات');
                  },
                  child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Payment Info ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💳 بيانات الدفع والتحصيل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.green2)),
                const SizedBox(height: 4),
                Text('تُستخدم في رسائل التحصيل والكشوفات', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 10),
                TextField(controller: _instapayCtrl, keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr, style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(labelText: '📲 رقم InstaPay', labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 8),
                TextField(controller: _instapay2Ctrl, keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr, style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(labelText: '📲 رقم InstaPay 2 (اختياري)', labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 8),
                TextField(controller: _vodafoneCtrl, keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr, style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(labelText: '📱 فودافون كاش', labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 8),
                TextField(controller: _vodafone2Ctrl, keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr, style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(labelText: '📱 فودافون كاش 2 (اختياري)', labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 8),
                TextField(controller: _bankCtrl, style: GoogleFonts.cairo(fontSize: 13), maxLines: 2,
                  decoration: InputDecoration(labelText: '🏦 بيانات التحويل البنكي', labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green2, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () {
                    prov.setInstapay(_instapayCtrl.text.trim());
                    prov.setInstapay2(_instapay2Ctrl.text.trim());
                    prov.setVodafoneCash(_vodafoneCtrl.text.trim());
                    prov.setVodafoneCash2(_vodafone2Ctrl.text.trim());
                    prov.setBankInfo(_bankCtrl.text.trim());
                    AppSnackbar.show(context, '✅ تم حفظ بيانات الدفع');
                  },
                  child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Debt message extra note (package increase) ──────
            StatefulBuilder(
              builder: (ctx, setSt) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('📢 تنويه في رسالة المديونية', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
                      Text('يضاف تلقائياً لرسائل المديونية (واتساب/SMS)', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                    ])),
                    Switch(
                      value: prov.debtNoteEnabled,
                      activeThumbColor: const Color(0xFFE65100),
                      onChanged: (v) {
                        prov.setDebtNoteText(_debtNoteCtrl.text.trim());
                        prov.setDebtNoteEnabled(v);
                        setSt(() {});
                        AppSnackbar.show(context, v ? '✅ التنويه هيتضاف للرسائل' : '❌ تم إيقاف التنويه');
                      },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _debtNoteCtrl,
                    maxLines: 3,
                    minLines: 2,
                    style: GoogleFonts.cairo(fontSize: 12),
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'نص التنويه',
                      labelStyle: GoogleFonts.cairo(fontSize: 12),
                      hintText: 'مثال: تم رفع الاشتراك 49 ج بسبب زيادة أسعار الشركة',
                      hintStyle: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () {
                      prov.setDebtNoteText(_debtNoteCtrl.text.trim());
                      AppSnackbar.show(context, '✅ تم حفظ نص التنويه');
                    },
                    child: Text('💾 حفظ النص', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Export ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📤 تصدير البيانات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: const Color(0xFF6A1B9A))),
                const SizedBox(height: 4),
                Text('تصدير جميع بيانات العملاء والمجموعات', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: Text('Excel', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    onPressed: () => ExportService.exportExcel(context, prov),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text('PDF', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    onPressed: () => ExportService.exportPdf(context, prov),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text('مشاركة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    onPressed: () => ExportService.shareExcel(context, prov),
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Telegram Bot ─────────────────────────────────────
            StatefulBuilder(
              builder: (ctx, setSt) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF80DEEA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('✈️ بوت تليجرام (يعمل 24 ساعة)', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: const Color(0xFF006064))),
                          Text('يرد على أوامرك حتى لو التطبيق مقفول', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                        ])),
                        Switch(
                          value: prov.telegramEnabled,
                          activeThumbColor: const Color(0xFF00ACC1),
                          onChanged: (v) async {
                            // save token/chatId from fields before toggling
                            prov.setTelegram(_tgTokenCtrl.text, _tgChatIdCtrl.text);
                            if (v) {
                              AppSnackbar.show(context, '⏳ جارى تفعيل البوت على السيرفر...');
                            }
                            final res = await prov.setTelegramEnabled(v);
                            if (context.mounted) {
                              AppSnackbar.show(context, (res.ok ? '✅ ' : '❌ ') + res.msg);
                              setSt(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _tgTokenCtrl,
                        obscureText: _tgTokenObscured,
                        style: GoogleFonts.cairo(fontSize: 11),
                        decoration: InputDecoration(
                          labelText: '🔑 Bot Token',
                          labelStyle: GoogleFonts.cairo(fontSize: 12),
                          suffixIcon: IconButton(
                            icon: Icon(_tgTokenObscured ? Icons.visibility_off : Icons.visibility, size: 18),
                            onPressed: () => setSt(() => _tgTokenObscured = !_tgTokenObscured),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tgChatIdCtrl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: '💬 Chat ID',
                        labelStyle: GoogleFonts.cairo(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00838F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          prov.setTelegram(_tgTokenCtrl.text, _tgChatIdCtrl.text);
                          AppSnackbar.show(context, '✅ تم حفظ إعدادات التليجرام');
                        },
                        child: Text('💾 حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00838F),
                          side: const BorderSide(color: Color(0xFF00ACC1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final ok = await prov.sendTelegram('🧪 اختبار الاتصال — البوت يعمل بنجاح ✅');
                          if (context.mounted) {
                            AppSnackbar.show(context, ok ? '✅ تم الإرسال بنجاح' : '❌ فشل الإرسال — تحقق من الإعدادات');
                          }
                        },
                        child: Text('🧪 اختبار', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Text(
                        '📌 طريقة التفعيل:\n'
                        '1) افتح @BotFather في تليجرام واكتب /newbot\n'
                        '2) انسخ التوكن والصقه في الخانة فوق\n'
                        '3) فعّل المفتاح ✈️ بالأعلى\n'
                        '4) ابعت /start لبوتك — هيرد عليك فوراً\n'
                        '(Chat ID اختياري — البوت يتعرف عليك تلقائياً)',
                        style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF795548), height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الأوامر: /تقرير /ربح /ديون /فواتير /مجموعات /عملاء /تنبيهات /انتهاء /انتظار /ضيوف /ايجارات /اليوم',
                      style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Delete all
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ حذف البيانات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.red2)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.red2),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => PinDialog(
                          title: 'مسح كل البيانات نهائياً',
                          onConfirm: () {
                            prov.deleteAllData();
                            Navigator.pop(context);
                            AppSnackbar.show(context, '✅ تم مسح كل البيانات');
                          },
                        ),
                      ),
                      child: Text('🗑 مسح كل البيانات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق', style: GoogleFonts.cairo()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fsBtn(AppProvider prov, String val, String label, double size) {
    final selected = prov.fontSize == val;
    return Expanded(child: GestureDetector(
      onTap: () => prov.setFontSize(val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueLight : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.blue3 : AppColors.border, width: 2),
        ),
        child: Center(child: Text(label, style: GoogleFonts.cairo(fontSize: size, fontWeight: FontWeight.w700))),
      ),
    ));
  }

  Widget _styleBtn(AppProvider prov, String style, String label, Color color) {
    final selected = prov.themeStyle == style;
    return GestureDetector(
      onTap: () => prov.setThemeStyle(style),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : AppColors.border, width: 2),
        ),
        child: Center(child: Text(label, style: GoogleFonts.cairo(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? color : AppColors.muted,
        ))),
      ),
    );
  }

  Widget _themeBtn(AppProvider prov, bool dark, String label) {
    final selected = prov.darkMode == dark;
    return GestureDetector(
      onTap: () => prov.setDarkMode(dark),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueLight : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.blue3 : AppColors.border, width: 2),
        ),
        child: Center(child: Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _viewBtn(AppProvider prov, bool compact, String label) {
    final selected = prov.compactMembers == compact;
    return GestureDetector(
      onTap: () => prov.setCompactMembers(compact),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueLight : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.blue3 : AppColors.border, width: 2),
        ),
        child: Center(
            child: Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700))),
      ),
    );
  }
}
