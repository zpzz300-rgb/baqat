// lib/widgets/member_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/notification_service.dart';
import 'common.dart';
import 'edit_member_modal.dart';
import 'pin_dialog.dart';

// ─── قوالب رسائل الهدايا (قابلة للتعديل وتُحفظ في SharedPreferences) ───
// المتغيّرات: {اسم} {الهدية} {جيجا} {دقائق} {الخدمات} {الشهر} {العدد} {رقم} {الخط}
const String _kDefaultGiftNow =
    '🎁 هدية ليك يا {اسم} 🎁\n'
    'ـــــــــــــــــــــ\n'
    '✨ {الهدية}\n'
    'ـــــــــــــــــــــ\n'
    'دي هدية مننا 🤍 شكراً لتعاملك معانا 🌟';

const String _kDefaultGiftMonth =
    '📊 كشف هدايا شهر {الشهر} 🎁\n'
    'أهلاً يا {اسم} 👋\n'
    'ـــــــــــــــــــــ\n'
    '🌐 نت: {جيجا} جيجا\n'
    '⏱️ دقائق: {دقائق} دقيقة\n'
    '🎁 عدد الهدايا: {العدد}\n'
    '{الخدمات}'
    'ـــــــــــــــــــــ\n'
    'كل ده هدية مننا خلال الشهر 🤍 ربنا يخليك معانا 🌟';

class MemberCard extends StatelessWidget {
  final Member member;
  final Group group;
  const MemberCard({super.key, required this.member, required this.group});

  @override
  Widget build(BuildContext context) {
    final threshold = context.watch<AppProvider>().debtThreshold;
    final highDebt = member.balance < -threshold;
    final dotColor = member.hasDebt
        ? AppColors.red
        : (member.isClear ? const Color(0xFF43a047) : Colors.grey[400]!);
    final amtBg = member.hasDebt
        ? AppColors.redLight
        : (member.isClear ? AppColors.greenLight : const Color(0xFFf5f5f5));
    final amtColor = member.hasDebt
        ? AppColors.red2
        : (member.isClear ? AppColors.green : AppColors.muted);

    // Orange border for available stock numbers
    final bool isStockNumber =
        member.name.isEmpty || member.name == 'رقم زيادة';
    final borderColor = highDebt
        ? AppColors.red
        : isStockNumber
            ? Colors.orange
            : AppColors.border;
    final borderWidth = highDebt
        ? 2.0
        : isStockNumber
            ? 2.0
            : 1.5;

    // Dynamic background based on line type from group
    Color cardBg = Colors.white;
    if (group.lineType.label == 'خط أرضي') {
      cardBg = Colors.blue.withValues(alpha: 0.05);
    } else if (group.lineType.label == 'Home 4G') {
      cardBg = Colors.purple.withValues(alpha: 0.05);
    }

    // Payment flag
    final flag = member.paymentFlag;
    Color? flagColor;
    if (flag == 'red') { flagColor = const Color(0xFFEF5350); }
    else if (flag == 'yellow') { flagColor = const Color(0xFFFFCA28); }
    else if (flag == 'green') { flagColor = const Color(0xFF66BB6A); }

    final effectiveBorderColor = flag == 'red' && !highDebt
        ? const Color(0xFFEF5350)
        : borderColor;
    final effectiveBorderWidth = flag == 'red' && !highDebt ? 2.0 : borderWidth;

    return GestureDetector(
      onTap: () => _openDrawer(context),
      child: Container(
        height: 175,
        decoration: BoxDecoration(
          color: highDebt ? const Color(0xFFFFF5F5) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: effectiveBorderColor, width: effectiveBorderWidth),
          boxShadow: [
            BoxShadow(
              color: highDebt
                  ? AppColors.red.withValues(alpha: 0.18)
                  : AppColors.blue2.withValues(alpha: 0.06),
              blurRadius: highDebt ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            children: [
              // Flag color bar at top
              if (flagColor != null)
                Container(height: 4, color: flagColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        child: GestureDetector(
                          onTap: () => _openWA(member),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat, color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 6)
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              member.phone,
                              style: GoogleFonts.cairo(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.blue2,
                                  letterSpacing: 0.3),
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                            ),
                          ),
                          if (member.phone2 != null && member.phone2!.isNotEmpty)
                            GestureDetector(
                              onTap: () => context.read<AppProvider>().toggleWaPhone2(member.id),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.chat, size: 9, color: Color(0xFF25D366)),
                                const SizedBox(width: 2),
                                Text(member.waPhone2 ? 'رقم 2' : 'رقم 1',
                                    style: GoogleFonts.cairo(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF25D366)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                          Text(member.name,
                              style: GoogleFonts.cairo(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(member.package,
                              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (member.type == 'landline' || member.type == 'homeforgee')
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: member.type == 'landline'
                                      ? const Color(0xFFE3F2FD)
                                      : const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: member.type == 'landline'
                                        ? const Color(0xFF42A5F5)
                                        : const Color(0xFFAB47BC),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  member.type == 'landline' ? '☎️ أرضي' : '🏠 هوم فور جي',
                                  style: GoogleFonts.cairo(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: member.type == 'landline'
                                        ? const Color(0xFF1565C0)
                                        : const Color(0xFF6A1B9A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (highDebt)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text('⚠️ دين مرتفع',
                                  style: GoogleFonts.cairo(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.red2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          if (member.deferralDate != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text('⏰ مؤجل ${member.deferralDate}',
                                  style: GoogleFonts.cairo(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.orange[800]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                                color: amtBg, borderRadius: BorderRadius.circular(7)),
                            child: Text('${member.balance.toStringAsFixed(0)} ج',
                                style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: amtColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWA(Member m) async {
    final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
    final url = 'https://wa.me/$phone';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => MemberDrawer(member: member, group: group, parentContext: context),
    );
  }
}

// ─── COMPACT MEMBER CARD (3 per row grid) ────────────────────────
class CompactMemberCard extends StatelessWidget {
  final Member member;
  final Group group;
  const CompactMemberCard({super.key, required this.member, required this.group});

  @override
  Widget build(BuildContext context) {
    final threshold = context.watch<AppProvider>().debtThreshold;
    final highDebt = member.balance < -threshold;
    final dotColor = member.hasDebt
        ? AppColors.red
        : (member.isClear ? const Color(0xFF43a047) : Colors.grey[400]!);
    final amtBg = member.hasDebt
        ? AppColors.redLight
        : (member.isClear ? AppColors.greenLight : const Color(0xFFf5f5f5));
    final amtColor = member.hasDebt
        ? AppColors.red2
        : (member.isClear ? AppColors.green : AppColors.muted);

    final bool isStockNumber =
        member.name.isEmpty || member.name == 'رقم زيادة';
    final flag = member.paymentFlag;
    Color? flagColor;
    if (flag == 'red') { flagColor = const Color(0xFFEF5350); }
    else if (flag == 'yellow') { flagColor = const Color(0xFFFFCA28); }
    else if (flag == 'green') { flagColor = const Color(0xFF66BB6A); }

    // أنواع خاصة: أرضي (أزرق) / هوم فور جي (بنفسجي) — لون وحدود مميزة وسط المربعات
    final isLandline = member.type == 'landline';
    final isHome4g = member.type == 'homeforgee';
    final isSpecial = isLandline || isHome4g;
    final specialColor = isLandline ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A);
    final specialBg = isLandline ? const Color(0xFFEAF4FF) : const Color(0xFFF7EEFB);

    final borderColor = highDebt
        ? AppColors.red
        : (flag == 'red'
            ? const Color(0xFFEF5350)
            : (isStockNumber
                ? Colors.orange
                : (isSpecial ? specialColor : AppColors.border)));
    final borderWidth = (highDebt || flag == 'red' || isStockNumber || isSpecial) ? 2.0 : 1.5;

    final displayName = isStockNumber ? 'رقم متاح' : member.name;
    final balanceTxt = member.balance == 0
        ? '0'
        : (member.balance < 0
            ? '${(-member.balance).toStringAsFixed(0)}-'
            : member.balance.toStringAsFixed(0));

    return GestureDetector(
      onTap: () => MemberCard(member: member, group: group)._openDrawer(context),
      child: Container(
        decoration: BoxDecoration(
          color: highDebt
              ? const Color(0xFFFFF5F5)
              : (isSpecial ? specialBg : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (flagColor != null) Container(height: 3, color: flagColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status dot + line-type icon
                    Row(children: [
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                      const Spacer(),
                      if (member.type == 'landline')
                        const Icon(Icons.phone_in_talk,
                            size: 12, color: Color(0xFF1565C0))
                      else if (member.type == 'homeforgee')
                        const Icon(Icons.router,
                            size: 12, color: Color(0xFF6A1B9A)),
                    ]),
                    const SizedBox(height: 3),
                    // Phone number — large & prominent (primary)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        member.phone.isEmpty ? '—' : member.phone,
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.blue2,
                            letterSpacing: 0.3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Name — tiny (secondary)
                    Text(displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                          color: amtBg, borderRadius: BorderRadius.circular(7)),
                      child: Text('$balanceTxt ج',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                              fontSize: 12, fontWeight: FontWeight.w900, color: amtColor)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MEMBER DRAWER ───────────────────────────────────────────────
class MemberDrawer extends StatefulWidget {
  final Member member;
  final Group group;
  final BuildContext? parentContext;
  const MemberDrawer({super.key, required this.member, required this.group, this.parentContext});

  @override
  State<MemberDrawer> createState() => _MemberDrawerState();
}

class _MemberDrawerState extends State<MemberDrawer> {
  // Gift / Service (GB / minutes / other)
  final _gbCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _svcDescCtrl = TextEditingController();
  final _svcAmtCtrl = TextEditingController();
  bool _svcIsPaid = false;
  // Manual adjustment / payment (merged)
  final _manAmt = TextEditingController();
  final _manReason = TextEditingController();
  // Notes
  final _noteCtrl = TextEditingController();
  bool _noteDirty = false;
  // Editable message templates
  String _giftNowTpl = _kDefaultGiftNow;
  String _giftMonthTpl = _kDefaultGiftMonth;

  @override
  void initState() {
    super.initState();
    _noteCtrl.text = widget.member.notes ?? '';
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _giftNowTpl = p.getString('tcm_gift_now_tpl') ?? _kDefaultGiftNow;
      _giftMonthTpl = p.getString('tcm_gift_month_tpl') ?? _kDefaultGiftMonth;
    });
  }

  @override
  void dispose() {
    _gbCtrl.dispose();
    _minCtrl.dispose();
    _svcDescCtrl.dispose();
    _svcAmtCtrl.dispose();
    _manAmt.dispose();
    _manReason.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final member = prov.db.members.firstWhere(
      (x) => x.id == widget.member.id,
      orElse: () => widget.member,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: const BoxDecoration(
        color: Color(0xFFf8fbff),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // ── Handle ────────────────────────────────────────────
        Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),

        // ── Header ────────────────────────────────────────────
        _buildHeader(member, prov),

        // ── Body ──────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Info boxes (المديونية + قيمة الاشتراك)
                  _buildInfoRow(member),
                  const SizedBox(height: 10),

                  // 2. Payment / manual debt adjustment — مرفوع لفوق تحت المديونية مباشرة
                  _buildManualAdjustment(prov),
                  const SizedBox(height: 12),

                  // 3. Join date + notes
                  _buildDateAndNotes(member, prov),
                  const SizedBox(height: 12),

                  // 3b. Deferral status
                  _buildDeferralSection(member, prov),
                  const SizedBox(height: 12),

                  // 4. Quick action buttons
                  _buildQuickButtons(member, prov),
                  const SizedBox(height: 12),

                  // 5. Gift / service (GB / minutes) + messages
                  _buildServiceSection(member, prov),
                  const SizedBox(height: 12),

                  // 7. Full log
                  _buildLog(member, prov),
                  const SizedBox(height: 12),

                  // 8. Actions
                  _buildActions(member, prov),
                  const SizedBox(height: 8),
                ]),
          ),
        ),

        // ── Bottom bar ────────────────────────────────────────
        _buildBottomBar(member, prov),
      ]),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────
  Widget _buildHeader(Member member, AppProvider prov) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.name,
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            if (member.phone2 != null && member.phone2!.isNotEmpty)
              Row(children: [
                GestureDetector(
                  onTap: () => prov.toggleWaPhone2(member.id),
                  child: Row(children: [
                    Icon(
                        member.waPhone2
                            ? Icons.radio_button_off
                            : Icons.radio_button_on,
                        color: member.waPhone2
                            ? Colors.white38
                            : Colors.greenAccent,
                        size: 13),
                    const SizedBox(width: 3),
                    Text(member.phone,
                        style: GoogleFonts.cairo(
                            color:
                                member.waPhone2 ? Colors.white54 : Colors.white,
                            fontSize: 12),
                        textDirection: TextDirection.ltr),
                  ]),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => prov.toggleWaPhone2(member.id),
                  child: Row(children: [
                    Icon(
                        member.waPhone2
                            ? Icons.radio_button_on
                            : Icons.radio_button_off,
                        color: member.waPhone2
                            ? Colors.greenAccent
                            : Colors.white38,
                        size: 13),
                    const SizedBox(width: 3),
                    Text(member.phone2!,
                        style: GoogleFonts.cairo(
                            color:
                                member.waPhone2 ? Colors.white : Colors.white54,
                            fontSize: 12),
                        textDirection: TextDirection.ltr),
                  ]),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chat, color: Colors.greenAccent, size: 12),
              ])
            else
              Text(member.phone,
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
                  textDirection: TextDirection.ltr),
            Text('${widget.group.phone} · ${member.package}',
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }

  // ── INFO ROW ────────────────────────────────────────────────
  Widget _buildInfoRow(Member member) {
    final hasDebt = member.balance < 0;
    return Row(children: [
      Expanded(
          child: _infoBox(
        '💳 الاشتراك الشهري',
        '${member.price.toStringAsFixed(0)} ج/شهر',
        AppColors.blue2,
      )),
      const SizedBox(width: 10),
      Expanded(
          child: _infoBox(
        hasDebt ? '🔴 إجمالي المديونية' : '✅ الرصيد',
        hasDebt
            ? '${(-member.balance).toStringAsFixed(0)} ج'
            : member.balance == 0
                ? 'لا يوجد دين'
                : '${member.balance.toStringAsFixed(0)} ج',
        hasDebt ? AppColors.red2 : AppColors.green,
        subtitle: hasDebt ? 'متأخر' : 'مسدّد',
        subtitleColor: hasDebt ? AppColors.red : AppColors.green,
        onPencilTap: () =>
            _editBalanceDialog(member, context.read<AppProvider>()),
      )),
    ]);
  }

  Widget _infoBox(String label, String value, Color valueColor,
      {String? subtitle, Color? subtitleColor, VoidCallback? onPencilTap}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.06), blurRadius: 10)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style:
                      GoogleFonts.cairo(fontSize: 10, color: AppColors.muted))),
          if (onPencilTap != null)
            GestureDetector(
              onTap: onPencilTap,
              child: const Icon(Icons.edit, size: 13, color: AppColors.muted),
            ),
        ]),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: 17, fontWeight: FontWeight.w900, color: valueColor)),
        if (subtitle != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (subtitleColor ?? AppColors.muted).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(subtitle,
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor ?? AppColors.muted)),
          ),
      ]),
    );
  }

  void _editBalanceDialog(Member member, AppProvider prov) {
    final ctrl = TextEditingController(text: member.balance.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✏️ تعديل الرصيد مباشرة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('رقم موجب = رصيد دائن، رقم سالب = مديونية',
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textDirection: TextDirection.ltr,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'الرصيد الجديد',
              labelStyle: GoogleFonts.cairo(),
              suffixText: 'ج',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null) {
                final diff = val - member.balance;
                if (diff != 0) {
                  prov.addCharge(member.id, -diff, 'تعديل رصيد مباشر');
                }
              }
              Navigator.pop(context);
            },
            child: Text('حفظ',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── DATE + NOTES ────────────────────────────────────────────
  Widget _buildDateAndNotes(Member member, AppProvider prov) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Join date
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Text('تاريخ الانضمام: ',
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
          Text(member.date ?? '—',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue2)),
        ]),
      ),
      const SizedBox(height: 8),
      // Notes
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _noteDirty ? AppColors.orange : AppColors.border),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              const Icon(Icons.edit_note, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text('ملاحظات العميل 📝',
                  style:
                      GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              const Spacer(),
              if (_noteDirty)
                GestureDetector(
                  onTap: () {
                    prov.saveMemberNotes(member.id, _noteCtrl.text);
                    setState(() => _noteDirty = false);
                    AppSnackbar.show(context, '✅ تم حفظ الملاحظة');
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('حفظ',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            minLines: 2,
            onChanged: (_) => setState(() => _noteDirty = true),
            style: GoogleFonts.cairo(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'اكتب ملاحظة...',
              hintStyle:
                  GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── DEFERRAL SECTION ────────────────────────────────────────
  Widget _buildDeferralSection(Member member, AppProvider prov) {
    final hasDeferral = member.deferralDate != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasDeferral ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDeferral ? Colors.orange : AppColors.border,
          width: hasDeferral ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('⏰ تأجيل الدفع',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: hasDeferral ? Colors.orange[800] : AppColors.muted)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showDeferralDialog(member, prov),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: hasDeferral ? Colors.orange : AppColors.blue2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasDeferral ? '✏️ تعديل' : '🕐 تأجيل',
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          if (hasDeferral) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                prov.clearMemberDeferral(member.id);
                await NotificationService.cancelDeferralReminder(member.id);
                if (context.mounted) AppSnackbar.show(context, '✅ تم إلغاء التأجيل');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red2)),
              ),
            ),
          ],
        ]),
        if (hasDeferral) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today, size: 13, color: Colors.orange),
            const SizedBox(width: 5),
            Text('حتى: ${member.deferralDate}',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange[800])),
          ]),
          if (member.deferralNote != null && member.deferralNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.notes, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(member.deferralNote!,
                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('لا يوجد تأجيل — اضغط للتسجيل',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ),
      ]),
    );
  }

  void _showDeferralDialog(Member member, AppProvider prov) {
    final dateCtrl = TextEditingController(text: member.deferralDate ?? '');
    final noteCtrl = TextEditingController(text: member.deferralNote ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('⏰ تأجيل الدفع — ${member.name}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: dateCtrl,
            keyboardType: TextInputType.datetime,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'تاريخ التأجيل (YYYY-MM-DD)',
              labelStyle: GoogleFonts.cairo(fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today, size: 18),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    dateCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'سبب التأجيل',
              hintText: 'مثال: سفر، ضائقة مالية...',
              labelStyle: GoogleFonts.cairo(fontSize: 12),
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: GoogleFonts.cairo(fontSize: 13),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final date = dateCtrl.text.trim();
              if (date.isEmpty) {
                AppSnackbar.show(context, '⚠️ أدخل تاريخ التأجيل');
                return;
              }
              Navigator.pop(ctx);
              prov.setMemberDeferral(member.id, date, noteCtrl.text);
              await NotificationService.scheduleDeferralReminder(
                memberId: member.id,
                memberName: member.name,
                deferralDate: date,
                note: noteCtrl.text.trim(),
              );
              if (context.mounted) {
                AppSnackbar.show(context, '✅ تم تسجيل التأجيل وجدولة الإشعار');
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── QUICK BUTTONS ───────────────────────────────────────────
  Widget _buildQuickButtons(Member member, AppProvider prov) {
    return Row(children: [
      Expanded(
        child: _bigBtn(
          label: '💰 سدّد',
          sub: '${member.price.toStringAsFixed(0)} ج',
          bg: AppColors.green2,
          onTap: () {
            if (member.price <= 0) return;
            prov.addPayment(member.id, member.price, 'اشتراك');
            AppSnackbar.show(context,
                '✅ تم تسجيل دفعة ${member.price.toStringAsFixed(0)} ج');
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _bigBtn(
          label: '➕ سدّدتله',
          sub: '${member.price.toStringAsFixed(0)} ج',
          bg: AppColors.red,
          onTap: () {
            if (member.price <= 0) return;
            prov.addCharge(member.id, member.price, 'اشتراك');
            AppSnackbar.show(
                context, '✅ تم تسجيل خصم ${member.price.toStringAsFixed(0)} ج');
          },
        ),
      ),
    ]);
  }

  Widget _bigBtn(
      {required String label,
      required String sub,
      required Color bg,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: bg.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          Text(label,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          Text(sub,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    );
  }

  // ── GIFT / SERVICE SECTION (GB / minutes) ───────────────────
  Widget _buildServiceSection(Member member, AppProvider prov) {
    final summary = prov.monthlyGiftSummary(member.id);
    final mGb = (summary['gb'] as double);
    final mMin = (summary['minutes'] as double);
    final mCount = (summary['count'] as int);
    return _card(
      title: '🎁 هدية / جيجا / دقائق',
      trailing: GestureDetector(
        onTap: _openGiftTemplateEditor,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.edit_note, size: 16, color: AppColors.muted),
          const SizedBox(width: 2),
          Text('القالب',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: _pickerField(
                  ctrl: _gbCtrl,
                  hint: '🌐 جيجا',
                  presets: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])),
          const SizedBox(width: 8),
          Expanded(
              child: _pickerField(
                  ctrl: _minCtrl,
                  hint: '⏱️ دقائق',
                  presets: const [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000])),
        ]),
        const SizedBox(height: 8),
        _field(_svcDescCtrl, hint: 'خدمة أخرى (اختياري)'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _field(_svcAmtCtrl,
                  hint: 'المبلغ (اتركه 0 لو مجاني)', isNum: true)),
          const SizedBox(width: 8),
          _toggleBtn('💰 بفلوس', _svcIsPaid, AppColors.orange,
              () => setState(() => _svcIsPaid = true)),
          const SizedBox(width: 6),
          _toggleBtn('🎁 مجاني', !_svcIsPaid, AppColors.green,
              () => setState(() => _svcIsPaid = false)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _addGiftAndSend(member, prov),
            icon: const Icon(Icons.card_giftcard, size: 16, color: Colors.white),
            label: Text('إضافة + إرسال رسالة الهدية',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _svcIsPaid ? AppColors.orange : AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Monthly aggregated summary ──
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB7DFB7)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📅 كشف هدايا الشهر (بيتصفّر كل شهر)',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: const Color(0xFF2E7D32))),
            const SizedBox(height: 4),
            Text('🌐 ${_fmtGb(mGb)} جيجا  •  ⏱️ ${mMin.toStringAsFixed(0)} دقيقة  •  🎁 $mCount هدية',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: const Color(0xFF1B5E20))),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: mCount == 0
                    ? null
                    : () => _sendMonthlySummary(member, prov),
                icon: const Icon(Icons.send, size: 15),
                label: Text('إرسال الكشف المجمّع للعميل',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // حقل رقمي + منسدل (preset) مع إمكانية الكتابة اليدوي.
  Widget _pickerField({
    required TextEditingController ctrl,
    required String hint,
    required List<int> presets,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              isDense: true,
            ),
          ),
        ),
        PopupMenuButton<int>(
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.muted),
          padding: EdgeInsets.zero,
          onSelected: (v) => setState(() => ctrl.text = v.toString()),
          itemBuilder: (_) => presets
              .map((v) => PopupMenuItem<int>(
                    value: v,
                    child: Text(v.toString(),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Future<void> _addGiftAndSend(Member member, AppProvider prov) async {
    final gb = double.tryParse(_gbCtrl.text.trim()) ?? 0;
    final mins = double.tryParse(_minCtrl.text.trim()) ?? 0;
    final desc = _svcDescCtrl.text.trim();
    final amt = double.tryParse(_svcAmtCtrl.text.trim()) ?? 0;
    if (gb <= 0 && mins <= 0 && desc.isEmpty) {
      AppSnackbar.show(context, '⚠️ اختر جيجا أو دقائق أو اكتب خدمة');
      return;
    }
    final isPaid = _svcIsPaid && amt > 0;
    prov.addGiftService(member.id,
        gb: gb, minutes: mins, desc: desc, amount: amt, isPaid: isPaid);

    // نصّ «الهدية» للرسالة الوقتية
    final parts = <String>[];
    if (gb > 0) parts.add('🌐 ${_fmtGb(gb)} جيجا');
    if (mins > 0) parts.add('⏱️ ${mins.toStringAsFixed(0)} دقيقة');
    if (desc.isNotEmpty) parts.add('🎯 $desc');
    if (isPaid) parts.add('💰 بقيمة ${amt.toStringAsFixed(0)} ج');
    final giftText = parts.join('\n');

    _gbCtrl.clear();
    _minCtrl.clear();
    _svcDescCtrl.clear();
    _svcAmtCtrl.clear();
    if (mounted) AppSnackbar.show(context, '✅ تمت الإضافة');

    final msg = _giftNowTpl
        .replaceAll('{اسم}', member.salutation)
        .replaceAll('{الهدية}', giftText)
        .replaceAll('{جيجا}', _fmtGb(gb))
        .replaceAll('{دقائق}', mins.toStringAsFixed(0))
        .replaceAll('{رقم}', member.phone)
        .replaceAll('{الخط}', widget.group.phone);
    await _sendWA(member, msg);
  }

  Future<void> _sendMonthlySummary(Member member, AppProvider prov) async {
    final s = prov.monthlyGiftSummary(member.id);
    final gb = s['gb'] as double;
    final mins = s['minutes'] as double;
    final items = (s['items'] as List).cast<String>();
    final count = s['count'] as int;
    const months = ['', 'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final now = DateTime.now();
    final itemsText =
        items.isEmpty ? '' : '${items.map((e) => '• $e').join('\n')}\n';
    final msg = _giftMonthTpl
        .replaceAll('{اسم}', member.salutation)
        .replaceAll('{الشهر}', months[now.month])
        .replaceAll('{جيجا}', _fmtGb(gb))
        .replaceAll('{دقائق}', mins.toStringAsFixed(0))
        .replaceAll('{العدد}', count.toString())
        .replaceAll('{الخدمات}', itemsText)
        .replaceAll('{رقم}', member.phone)
        .replaceAll('{الخط}', widget.group.phone);
    await _sendWA(member, msg);
  }

  String _fmtGb(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _sendWA(Member member, String msg) async {
    final phone = member.waPhone.replaceFirst(RegExp(r'^0'), '20');
    final url =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openGiftTemplateEditor() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftTemplateSheet(
        nowTpl: _giftNowTpl,
        monthTpl: _giftMonthTpl,
      ),
    );
    if (changed == true) _loadTemplates();
  }

  // ── MANUAL ADJUSTMENT ───────────────────────────────────────
  Widget _buildManualAdjustment(AppProvider prov) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC02), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💵', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text('دفعة / تعديل رصيد',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: const Color(0xFF795548))),
        ]),
        const SizedBox(height: 4),
        Text('سجّل دفعة (خصم من الدين) أو زوّد الدين يدوياً',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _field(_manAmt,
                  hint: 'المبلغ', isNum: true, bg: Colors.white)),
          const SizedBox(width: 8),
          Expanded(
              child: _field(_manReason,
                  hint: 'السبب (رصيد سابق، خصم...)', bg: Colors.white)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _manualAction(prov, isDebt: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('➕ زيادة دين',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _manualAction(prov, isDebt: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('✓ دفعة / خصم',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ]),
      ]),
    );
  }

  void _manualAction(AppProvider prov, {required bool isDebt}) {
    if (!guardEdit(context)) return;
    final amt = double.tryParse(_manAmt.text.trim());
    if (amt == null || amt <= 0) return;
    final reason = _manReason.text.trim().isNotEmpty
        ? _manReason.text.trim()
        : (isDebt ? 'زيادة دين' : 'خصم دين');
    if (isDebt) {
      prov.addCharge(widget.member.id, amt, reason);
      AppSnackbar.show(
          context, '✅ تمت زيادة الدين ${amt.toStringAsFixed(0)} ج');
    } else {
      prov.addPayment(widget.member.id, amt, reason);
      AppSnackbar.show(
          context, '✅ تم خصم ${amt.toStringAsFixed(0)} ج من الدين');
    }
    _manAmt.clear();
    _manReason.clear();
  }

  // ── LOG ─────────────────────────────────────────────────────
  Widget _buildLog(Member member, AppProvider prov) {
    // Compute running balances (oldest → newest, display newest first)
    final log = member.log;
    final List<double> runningBalances = [];
    double running = 0;
    for (int i = log.length - 1; i >= 0; i--) {
      running += (log[i]['amount'] ?? 0).toDouble();
      runningBalances.insert(0, running);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('📋 السجل الكامل',
            style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.muted)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(8)),
          child: Text('${log.length} حركة',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2)),
        ),
        const Spacer(),
        if (log.isNotEmpty)
          GestureDetector(
            onTap: () => _confirmClearLog(prov),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Text('مسح الكل',
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.red2,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      if (log.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
              child: Text('لا توجد حركات',
                  style:
                      GoogleFonts.cairo(color: AppColors.muted, fontSize: 12))),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFf5f7fa),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(children: [
                Expanded(flex: 2, child: _thCell('البيان')),
                _thCell('المبلغ'),
                const SizedBox(width: 6),
                _thCell('الرصيد'),
                const SizedBox(width: 24),
              ]),
            ),
            // Rows
            ...log.asMap().entries.map((e) {
              final idx = e.key;
              final entry = e.value;
              final amount = (entry['amount'] ?? 0).toDouble();
              final runBal =
                  idx < runningBalances.length ? runningBalances[idx] : 0.0;
              return _logRow(entry, amount, runBal, idx, prov);
            }),
          ]),
        ),
    ]);
  }

  Widget _thCell(String text) => Expanded(
        child: Text(text,
            style: GoogleFonts.cairo(
                fontSize: 10,
                color: AppColors.muted,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      );

  Widget _logRow(Map<String, dynamic> entry, double amount, double runBal,
      int idx, AppProvider prov) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFf5f5f5)))),
      child: Row(children: [
        Expanded(
          flex: 2,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry['desc'] ?? '',
                style: GoogleFonts.cairo(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text(
                '${entry['date'] ?? ''}${(entry['time'] ?? '').toString().isNotEmpty ? ' • ${entry['time']}' : ''}',
                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
          ]),
        ),
        Expanded(
          child: Text(
            '${amount > 0 ? "+" : ""}${amount.toStringAsFixed(0)} ج',
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: amount >= 0 ? AppColors.green : AppColors.red2),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${runBal.toStringAsFixed(0)} ج',
            style: GoogleFonts.cairo(
                fontSize: 11,
                color: runBal < 0 ? AppColors.red2 : AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
        GestureDetector(
          onTap: () => _editLogEntry(entry, idx, prov),
          child: const Icon(Icons.edit_outlined,
              size: 16, color: AppColors.blue2),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _confirmDeleteLogEntry(entry, idx, prov),
          child: const Icon(Icons.delete_outline,
              size: 16, color: AppColors.muted),
        ),
      ]),
    );
  }

  void _confirmDeleteLogEntry(Map<String, dynamic> entry, int idx, AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الحركة', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('حذف "${entry['desc'] ?? 'الحركة'}"؟ الرصيد هيترجع زي ما كان.',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(context);
              prov.deleteMemberLogEntry(widget.member.id, idx);
            },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _editLogEntry(Map<String, dynamic> entry, int idx, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogEntryEditSheet(
        entry: entry,
        onSave: (desc, amount, date, time) {
          prov.editMemberLogEntry(widget.member.id, idx,
              desc: desc, amount: amount, date: date, time: time);
        },
      ),
    );
  }

  void _confirmClearLog(AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('مسح السجل',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('هل تريد مسح كل حركات العميل؟ لن يتغير الرصيد.',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(context);
              prov.clearMemberLog(widget.member.id);
            },
            child: Text('مسح',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── ACTIONS (2 WA buttons only — rest in bottom bar) ─────────
  Widget _buildActions(Member member, AppProvider prov) {
    final count = member.reminderCountThisMonth;
    return Row(children: [
      Expanded(
        child: Stack(clipBehavior: Clip.none, children: [
          _actionBtn('💬 واتساب (مديونية)', const Color(0xFFe8f5e9),
              AppColors.green2, () => _openWADebtOnly(member)),
          if (count > 0)
            Positioned(
              top: -7,
              right: -5,
              child: GestureDetector(
                onTap: () => _showReminderLog(member, prov),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text('$count',
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
          child: _actionBtn('📋 كشف حساب كامل', const Color(0xFFe8f5e9),
              AppColors.green2, () => _openWAWithStatement(member))),
      const SizedBox(width: 6),
      // زرار سجل/عداد التذكيرات
      GestureDetector(
        onTap: () => _showReminderLog(member, prov),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFe8f5e9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.blue2.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.history, size: 18, color: AppColors.blue2),
        ),
      ),
    ]);
  }

  // ── سجل/عداد تذكيرات المديونية ───────────────────────────────
  static String _reminderChLabel(String ch) => switch (ch) {
        'wa_debt' => '💬 واتساب (مديونية)',
        'wa_statement' => '📋 كشف حساب كامل',
        'sms' => '📱 SMS',
        'manual' => '✏️ إضافة يدوية',
        _ => 'إرسال',
      };

  static String _fmtReminderTs(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} - ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _reminderCounterBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _showReminderLog(Member member, AppProvider prov) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final m = prov.db.members.firstWhere((x) => x.id == member.id,
              orElse: () => member);
          final count = m.reminderCountThisMonth;
          final entries = List<Map<String, dynamic>>.from(m.reminderLog);
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Text('🔔 عداد تذكيرات المديونية',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(m.name,
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                // العداد + / -
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _reminderCounterBtn(Icons.remove, AppColors.red, () {
                    prov.decrementReminder(m.id);
                    setSt(() {});
                  }),
                  const SizedBox(width: 26),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$count',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            color: AppColors.blue2)),
                    Text('هذا الشهر',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: Colors.grey[600])),
                  ]),
                  const SizedBox(width: 26),
                  _reminderCounterBtn(Icons.add, AppColors.green2, () {
                    prov.incrementReminderManual(m.id);
                    setSt(() {});
                  }),
                ]),
                const SizedBox(height: 16),
                const Divider(),
                Align(
                    alignment: Alignment.centerRight,
                    child: Text('📋 سجل الإرسال (${entries.length})',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700, fontSize: 13))),
                const SizedBox(height: 6),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('لا توجد تذكيرات بعد',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(color: Colors.grey)),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        final ts = (e['ts'] ?? 0) as int;
                        final ch = (e['ch'] ?? '') as String;
                        return ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          title: Text(_reminderChLabel(ch),
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(_fmtReminderTs(ts),
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: Colors.grey[600])),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.red, size: 20),
                            onPressed: () {
                              prov.deleteReminderEntry(m.id, ts);
                              setSt(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── BOTTOM BAR ──────────────────────────────────────────────
  Widget _buildBottomBar(Member member, AppProvider prov) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openWAWithStatement(member, countReminder: false),
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text('📁 الملف الكامل والتقرير',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue2,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _bottomBtn(
                  '💬 واتساب', AppColors.green2, () => _openWA(member))),
          const SizedBox(width: 6),
          Expanded(
              child: _bottomBtn(
                  '📱 SMS', AppColors.blue2, () => _sendSMS(member))),
          const SizedBox(width: 6),
          Expanded(
              child: _bottomBtn('✏️ تعديل', AppColors.blue2, () async {
            // نمسك كونتكست الـ root navigator (ثابت دايماً ومش بيتفصل لما نقفل
            // درج العميل)، بدل الكونتكست المؤقت اللي كان بيخلّي التعديل «يهرب»
            // لما نفتح العميل من البحث أو الكفلاء (مش من المجموعات).
            final rootCtx = Navigator.of(context, rootNavigator: true).context;
            Navigator.pop(context);
            await Future.delayed(const Duration(milliseconds: 350));
            if (!rootCtx.mounted) return;
            showModalBottomSheet(useRootNavigator: true,
              context: rootCtx,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Colors.black54,
              builder: (_) => EditMemberModal(member: member),
            );
          })),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _bottomBtn(
                  '🗑 حذف', AppColors.red, () => _deleteMember(prov))),
          const SizedBox(width: 6),
          Expanded(
              child: _bottomBtn('🔀 نقل ←', AppColors.purple,
                  () => _moveMember(member, prov))),
        ]),
      ]),
    );
  }

  Widget _bottomBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.cairo(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────
  Widget _card({required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
          ),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _field(TextEditingController ctrl,
      {required String hint, bool isNum = false, Color? bg}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      textDirection: isNum ? TextDirection.ltr : null,
      style: GoogleFonts.cairo(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
        filled: true,
        fillColor: bg ?? const Color(0xFFf5f7fa),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _toggleBtn(
      String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.muted)),
      ),
    );
  }

  Widget _actionBtn(
      String label, Color bg, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                color: textColor, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  void _openWA(Member m) async {
    final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
    final url = 'https://wa.me/$phone';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }

  void _sendSMS(Member m) async {
    final prov = context.read<AppProvider>();
    final debt = m.balance < 0 ? -m.balance : 0.0;
    final instapay = [prov.instapayPhone, prov.instapayPhone2]
        .where((s) => s.isNotEmpty).map((s) => 'InstaPay: $s').join(' | ');
    final vodafone = [prov.vodafoneCash, prov.vodafoneCash2]
        .where((s) => s.isNotEmpty).map((s) => 'فودافون كاش: $s').join(' | ');
    final payLine = [instapay, vodafone].where((s) => s.isNotEmpty).join(' | ');
    final note = (prov.debtNoteEnabled && prov.debtNoteText.trim().isNotEmpty)
        ? ' ${prov.debtNoteText.trim()}'
        : '';
    final msg = debt > 0
        ? 'السلام عليكم ${m.salutation}، تذكير بمديونيتك ${debt.toStringAsFixed(0)} ج، الاشتراك الشهري ${m.price.toStringAsFixed(0)} ج. ${payLine.isNotEmpty ? 'الدفع: $payLine' : ''}$note'
        : 'السلام عليكم ${m.salutation}، حسابك مسدد، شكرا لك.';
    final phone = m.waPhone;
    final url = 'sms:$phone?body=${Uri.encodeComponent(msg)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
      if (debt > 0 && mounted) prov.recordReminderSent(m.id, 'sms');
    }
  }

  void _moveMember(Member member, AppProvider prov) {
    final otherGroups =
        prov.db.groups.where((g) => g.id != widget.group.id).toList();
    if (otherGroups.isEmpty) {
      AppSnackbar.show(context, '⚠️ لا توجد مجموعات أخرى');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('نقل العميل',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: otherGroups.length,
              itemBuilder: (_, i) {
                final g = otherGroups[i];
                return ListTile(
                  title: Text(g.phone,
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  subtitle: Text(g.ownerName ?? '',
                      style: GoogleFonts.cairo(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    prov.moveMember(member.id, g.id);
                    Navigator.pop(context);
                    AppSnackbar.show(context, '✅ تم نقل العميل إلى ${g.phone}');
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  // ── WhatsApp preview dialog ──────────────────────────────────
  void _showWAPreview(String msg, String phone, {String? memberId, String? channel}) {
    final ctrl = TextEditingController(text: msg);
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Text('👁 معاينة الرسالة — يمكنك التعديل قبل الإرسال',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.blue2)),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  maxLines: 10,
                  minLines: 4,
                  style: GoogleFonts.cairo(fontSize: 12),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إلغاء', style: GoogleFonts.cairo()),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.send, size: 18),
                        label: Text('إرسال واتساب',
                            style:
                                GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final url =
                              'https://wa.me/$phone?text=${Uri.encodeComponent(ctrl.text)}';
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                            // سجّل تذكير المديونية (لو الإرسال من زرار مديونية/كشف حساب)
                            if (memberId != null && channel != null && mounted) {
                              context
                                  .read<AppProvider>()
                                  .recordReminderSent(memberId, channel);
                            }
                          }
                        },
                      )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// كتلة طرق الدفع — كل رقم في سطر واضح بإيموجي، من غير تداخل.
  String _payBlock(AppProvider prov) {
    final b = StringBuffer();
    for (final n in [prov.instapayPhone, prov.instapayPhone2].where((s) => s.trim().isNotEmpty)) {
      b.writeln('📲 إنستا باي: $n');
    }
    for (final n in [prov.vodafoneCash, prov.vodafoneCash2].where((s) => s.trim().isNotEmpty)) {
      b.writeln('📱 فودافون كاش: $n');
    }
    if (prov.bankInfo.trim().isNotEmpty) {
      b.writeln('🏦 تحويل بنكي: ${prov.bankInfo.trim()}');
    }
    return b.toString().trimRight();
  }

  void _openWADebtOnly(Member m) {
    final debt = m.balance < 0 ? -m.balance : 0.0;
    final prov = context.read<AppProvider>();
    final pay = _payBlock(prov);
    final note = (prov.debtNoteEnabled && prov.debtNoteText.trim().isNotEmpty)
        ? prov.debtNoteText.trim()
        : '';
    final String msg;
    if (debt > 0) {
      final months = m.price > 0 ? (debt / m.price).ceil() : 0;
      final b = StringBuffer();
      b.writeln('السلام عليكم ${m.salutation} 👋');
      b.writeln('');
      b.writeln('🔴 تذكير بمديونية مستحقة');
      b.writeln('━━━━━━━━━━━━━');
      b.writeln('📱 رقمك: ${m.phone}');
      b.writeln('🛰️ الخط الرئيسي: ${widget.group.phone}');
      b.writeln('━━━━━━━━━━━━━');
      b.writeln('🔴 المطلوب: ${debt.toStringAsFixed(0)} ج${months > 0 ? '  ($months شهر)' : ''}');
      b.writeln('💳 الاشتراك الشهري: ${m.price.toStringAsFixed(0)} ج');
      if (pay.isNotEmpty) {
        b.writeln('━━━━━━━━━━━━━');
        b.writeln('💳 طرق الدفع:');
        b.writeln(pay);
      }
      if (note.isNotEmpty) {
        b.writeln('━━━━━━━━━━━━━');
        b.writeln('📢 $note');
      }
      b.writeln('');
      b.writeln('شكراً لتعاونك معنا 🙏');
      msg = b.toString();
    } else {
      msg = 'السلام عليكم ${m.salutation} 👋\n\n✅ حسابك مسدّد بالكامل، شكراً لك 🙏';
    }
    final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
    _showWAPreview(msg, phone, memberId: m.id, channel: 'wa_debt');
  }

  void _openWAWithStatement(Member m, {bool countReminder = true}) {
    final prov = context.read<AppProvider>();
    final paid = m.log
        .where((l) => (l['amount'] ?? 0) > 0)
        .fold<double>(0, (s, l) => s + ((l['amount'] ?? 0) as num).toDouble());
    final debt = m.balance < 0 ? -m.balance : 0.0;
    final pay = _payBlock(prov);

    final lines = StringBuffer();
    lines.writeln('السلام عليكم ${m.salutation} 👋');
    lines.writeln('');
    lines.writeln('📋 كشف حساب تفصيلي');
    lines.writeln('━━━━━━━━━━━━━');
    lines.writeln('📱 رقمك: ${m.phone}');
    lines.writeln('🛰️ الخط الرئيسي: ${widget.group.phone}');
    lines.writeln('━━━━━━━━━━━━━');
    lines.writeln('💳 الاشتراك الشهري: ${m.price.toStringAsFixed(0)} ج');
    lines.writeln('💰 إجمالي المدفوع: ${paid.toStringAsFixed(0)} ج');
    if (debt > 0) {
      lines.writeln('🔴 المديونية الحالية: ${debt.toStringAsFixed(0)} ج');
    } else {
      lines.writeln('✅ لا توجد مديونيات');
    }
    if (m.log.isNotEmpty) {
      lines.writeln('━━━━━━━━━━━━━');
      lines.writeln('📌 آخر الحركات:');
      for (final log in m.log.take(8)) {
        final desc = log['desc'] ?? '';
        final amount = ((log['amount'] ?? 0) as num).toDouble();
        final amtTxt = amount == 0
            ? ''
            : ' (${amount > 0 ? "+" : ""}${amount.toStringAsFixed(0)} ج)';
        lines.writeln('• $desc$amtTxt');
      }
    }
    if (pay.isNotEmpty) {
      lines.writeln('━━━━━━━━━━━━━');
      lines.writeln('💳 طرق الدفع:');
      lines.writeln(pay);
    }
    lines.writeln('');
    lines.writeln('شكراً لتعاونك معنا 🙏');

    final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
    _showWAPreview(lines.toString(), phone,
        memberId: countReminder ? m.id : null,
        channel: countReminder ? 'wa_statement' : null);
  }

  void _deleteMember(AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => PinDialog(
        title: 'حذف العميل',
        onConfirm: () {
          prov.deleteMember(widget.member.id);
          Navigator.pop(context);
          AppSnackbar.show(context, '✅ تم حذف العميل');
        },
      ),
    );
  }
}

// ── ورقة تعديل حركة في كشف العميل (بيان + مبلغ +/- + تاريخ + وقت) ──
class _LogEntryEditSheet extends StatefulWidget {
  final Map<String, dynamic> entry;
  final void Function(String desc, double amount, String date, String time) onSave;
  const _LogEntryEditSheet({required this.entry, required this.onSave});
  @override
  State<_LogEntryEditSheet> createState() => _LogEntryEditSheetState();
}

class _LogEntryEditSheetState extends State<_LogEntryEditSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amtCtrl;
  late bool _isCredit; // true = دفعة (موجب/له) ، false = مديونية (سالب/عليه)
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final amount = (widget.entry['amount'] ?? 0).toDouble();
    _isCredit = amount >= 0;
    _descCtrl = TextEditingController(text: (widget.entry['desc'] ?? '').toString());
    _amtCtrl  = TextEditingController(text: amount == 0 ? '' : amount.abs().toStringAsFixed(0));
    _date = _parseDate((widget.entry['date'] ?? '').toString());
    _time = _parseTime((widget.entry['time'] ?? '').toString());
  }

  @override
  void dispose() { _descCtrl.dispose(); _amtCtrl.dispose(); super.dispose(); }

  // التاريخ مخزّن "d/M/yyyy"
  DateTime? _parseDate(String s) {
    final p = s.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    try { return DateTime(y, m, d); } catch (_) { return null; }
  }

  TimeOfDay? _parseTime(String s) {
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), mi = int.tryParse(p[1]);
    if (h == null || mi == null) return null;
    return TimeOfDay(hour: h.clamp(0, 23), minute: mi.clamp(0, 59));
  }

  String get _dateLabel => _date == null
      ? 'اختر التاريخ'
      : '${_date!.day}/${_date!.month}/${_date!.year}';

  String get _timeLabel => _time == null
      ? 'اختر الوقت (اختياري)'
      : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('✏️ تعديل الحركة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.blue2)),
          const SizedBox(height: 14),

          // البيان / الملاحظة
          TextField(
            controller: _descCtrl,
            style: GoogleFonts.cairo(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'البيان / الملاحظة', labelStyle: GoogleFonts.cairo(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // نوع الحركة: دفعة (له +) أو مديونية (عليه −)
          Text('نوع الحركة', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _typeBtn('➕ دفعة (له)', _isCredit, AppColors.green, () => setState(() => _isCredit = true))),
            const SizedBox(width: 10),
            Expanded(child: _typeBtn('➖ مديونية (عليه)', !_isCredit, AppColors.red2, () => setState(() => _isCredit = false))),
          ]),
          const SizedBox(height: 14),

          // المبلغ
          TextField(
            controller: _amtCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'المبلغ (ج)', labelStyle: GoogleFonts.cairo(), suffixText: 'ج',
              helperText: _isCredit ? 'هيتسجّل موجب (+) للعميل' : 'هيتسجّل سالب (−) على العميل',
              helperStyle: GoogleFonts.cairo(fontSize: 10, color: _isCredit ? AppColors.green : AppColors.red2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // التاريخ + الوقت
          Row(children: [
            Expanded(child: _pickerBtn(Icons.calendar_today, _dateLabel, () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2020), lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            })),
            const SizedBox(width: 10),
            Expanded(child: _pickerBtn(Icons.access_time, _timeLabel, () async {
              final picked = await showTimePicker(
                context: context, initialTime: _time ?? TimeOfDay.now(),
              );
              if (picked != null) setState(() => _time = picked);
            })),
          ]),
          if (_time != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _time = null),
                icon: const Icon(Icons.close, size: 14, color: AppColors.muted),
                label: Text('شيل الوقت', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
              ),
            ),
          ],
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue2, foregroundColor: Colors.white),
              onPressed: _save,
              child: Text('💾 حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            )),
          ]),
        ]),
      ),
    );
  }

  void _save() {
    final abs = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    final amount = _isCredit ? abs : -abs;
    final dateStr = _date == null ? '' : '${_date!.day}/${_date!.month}/${_date!.year}';
    final timeStr = _time == null
        ? ''
        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    widget.onSave(_descCtrl.text, amount, dateStr, timeStr);
    Navigator.pop(context);
  }

  Widget _typeBtn(String label, bool active, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color : AppColors.border, width: active ? 1.5 : 1),
      ),
      child: Center(child: Text(label, style: GoogleFonts.cairo(
          fontSize: 12, fontWeight: FontWeight.w700, color: active ? color : AppColors.muted))),
    ),
  );

  Widget _pickerBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.blue2),
        const SizedBox(width: 6),
        Expanded(child: Text(label,
            style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.text),
            overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

// ─── محرّر قوالب رسائل الهدايا ───────────────────────────────────
class _GiftTemplateSheet extends StatefulWidget {
  final String nowTpl;
  final String monthTpl;
  const _GiftTemplateSheet({required this.nowTpl, required this.monthTpl});

  @override
  State<_GiftTemplateSheet> createState() => _GiftTemplateSheetState();
}

class _GiftTemplateSheetState extends State<_GiftTemplateSheet> {
  late final TextEditingController _nowCtrl;
  late final TextEditingController _monthCtrl;

  @override
  void initState() {
    super.initState();
    _nowCtrl = TextEditingController(text: widget.nowTpl);
    _monthCtrl = TextEditingController(text: widget.monthTpl);
  }

  @override
  void dispose() {
    _nowCtrl.dispose();
    _monthCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tcm_gift_now_tpl', _nowCtrl.text);
    await p.setString('tcm_gift_month_tpl', _monthCtrl.text);
    if (mounted) Navigator.pop(context, true);
  }

  void _reset() {
    setState(() {
      _nowCtrl.text = _kDefaultGiftNow;
      _monthCtrl.text = _kDefaultGiftMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FBFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Text('✏️ تعديل قوالب رسائل الهدايا',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                  'المتغيّرات: {اسم} {الهدية} {جيجا} {دقائق} {الخدمات} {الشهر} {العدد} {رقم} {الخط}',
                  style:
                      GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 14),
              Text('🎁 رسالة الهدية الوقتية',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 6),
              _tplField(_nowCtrl),
              const SizedBox(height: 14),
              Text('📅 رسالة الكشف الشهري المجمّع',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 6),
              _tplField(_monthCtrl),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('استرجاع الافتراضي',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green2,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('💾 حفظ القوالب',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tplField(TextEditingController ctrl) => TextField(
        controller: ctrl,
        maxLines: 6,
        minLines: 3,
        style: GoogleFonts.cairo(fontSize: 13, height: 1.5),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
        ),
      );
}
