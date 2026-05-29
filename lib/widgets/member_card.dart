// lib/widgets/member_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/notification_service.dart';
import 'common.dart';
import 'edit_member_modal.dart';
import 'pin_dialog.dart';

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

    final borderColor = highDebt
        ? AppColors.red
        : (flag == 'red'
            ? const Color(0xFFEF5350)
            : (isStockNumber ? Colors.orange : AppColors.border));
    final borderWidth = (highDebt || flag == 'red' || isStockNumber) ? 2.0 : 1.5;

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
          color: highDebt ? const Color(0xFFFFF5F5) : Colors.white,
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
  // Payment
  final _payCtrl = TextEditingController();
  final _payNoteCtrl = TextEditingController();
  // Service (GB/minutes/other)
  final _svcDescCtrl = TextEditingController();
  final _svcAmtCtrl = TextEditingController();
  bool _svcIsPaid = false;
  // Manual adjustment
  final _manAmt = TextEditingController();
  final _manReason = TextEditingController();
  // Notes
  final _noteCtrl = TextEditingController();
  bool _noteDirty = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl.text = widget.member.notes ?? '';
  }

  @override
  void dispose() {
    _payCtrl.dispose();
    _payNoteCtrl.dispose();
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
                  // 1. Info boxes
                  _buildInfoRow(member),
                  const SizedBox(height: 10),

                  // 2. Join date + notes
                  _buildDateAndNotes(member, prov),
                  const SizedBox(height: 12),

                  // 2b. Deferral status
                  _buildDeferralSection(member, prov),
                  const SizedBox(height: 12),

                  // 3. Quick action buttons
                  _buildQuickButtons(member, prov),
                  const SizedBox(height: 12),

                  // 4. Payment registration
                  _buildPaySection(prov),
                  const SizedBox(height: 12),

                  // 5. Add service/GB/minutes
                  _buildServiceSection(prov),
                  const SizedBox(height: 12),

                  // 6. Manual debt adjustment
                  _buildManualAdjustment(prov),
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

  // ── PAYMENT FORM ────────────────────────────────────────────
  Widget _buildPaySection(AppProvider prov) {
    return _card(
      title: '= تسجيل دفعة',
      child: Row(children: [
        Expanded(
          child: _field(_payCtrl, hint: 'المبلغ المدفوع...', isNum: true),
        ),
        const SizedBox(width: 8),
        Expanded(child: _field(_payNoteCtrl, hint: 'ملاحظة')),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_payCtrl.text.trim());
            if (amt == null || amt <= 0) return;
            prov.addPayment(widget.member.id, amt, _payNoteCtrl.text.trim());
            _payCtrl.clear();
            _payNoteCtrl.clear();
            AppSnackbar.show(context, '✅ دفع ${amt.toStringAsFixed(0)} ج');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green2,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
          child: Text('✓ دفع',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }

  // ── SERVICE SECTION ─────────────────────────────────────────
  Widget _buildServiceSection(AppProvider prov) {
    return _card(
      title: '➕ إضافة جيجا / دقائق / خدمة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field(_svcDescCtrl, hint: 'الوصف (مثال: 5 جيجا إضافية، 100 دقيقة...)'),
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
            onPressed: () async {
              final amt = double.tryParse(_svcAmtCtrl.text.trim()) ?? 0;
              final desc = _svcDescCtrl.text.trim();
              if (desc.isEmpty) {
                AppSnackbar.show(context, '⚠️ اكتب وصف الخدمة');
                return;
              }
              final isPaid = _svcIsPaid && amt > 0;
              prov.addService(widget.member.id, desc, amt, isPaid);
              _svcDescCtrl.clear();
              _svcAmtCtrl.clear();
              AppSnackbar.show(context, '✅ تمت الإضافة');
              // فتح واتساب برسالة للعميل
              final member = widget.member;
              final phone = member.waPhone.replaceFirst(RegExp(r'^0'), '20');
              final msg = isPaid
                  ? 'مرحباً ${member.name}،\nتم إضافة: $desc\nبقيمة: ${amt.toStringAsFixed(0)} ج\nرصيدك الحالي: ${(member.balance - amt).toStringAsFixed(0)} ج'
                  : 'مرحباً ${member.name}،\nتم إضافة: $desc\nهدية مجانية 🎁';
              final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.send, size: 16, color: Colors.white),
            label: Text('إضافة + إرسال واتساب',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _svcIsPaid ? AppColors.orange : AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
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
          const Text('✏️', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text('تعديل المديونية يدوياً',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: const Color(0xFF795548))),
        ]),
        const SizedBox(height: 4),
        Text('أضف أو اخصم أي مبلغ يدوياً من رصيد العميل',
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
              child: Text('➖ خصم من الدين',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ]),
      ]),
    );
  }

  void _manualAction(AppProvider prov, {required bool isDebt}) {
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
            Text(entry['date'] ?? '',
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
          onTap: () => prov.deleteMemberLogEntry(widget.member.id, idx),
          child: const Icon(Icons.delete_outline,
              size: 16, color: AppColors.muted),
        ),
      ]),
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
    return Row(children: [
      Expanded(
          child: _actionBtn('💬 واتساب (مديونية)', const Color(0xFFe8f5e9),
              AppColors.green2, () => _openWADebtOnly(member))),
      const SizedBox(width: 8),
      Expanded(
          child: _actionBtn('📋 كشف حساب كامل', const Color(0xFFe8f5e9),
              AppColors.green2, () => _openWAWithStatement(member))),
    ]);
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
            onPressed: () => _openWAWithStatement(member),
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
            final nav = widget.parentContext ?? context;
            Navigator.pop(context);
            await Future.delayed(const Duration(milliseconds: 350));
            if (!nav.mounted) return;
            showModalBottomSheet(useRootNavigator: true,
              context: nav,
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
  Widget _card({required String title, required Widget child}) {
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
        Text(title,
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted)),
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
        ? 'السلام عليكم ${m.name}، تذكير بمديونيتك ${debt.toStringAsFixed(0)} ج، الاشتراك الشهري ${m.price.toStringAsFixed(0)} ج. ${payLine.isNotEmpty ? 'الدفع: $payLine' : ''}$note'
        : 'السلام عليكم ${m.name}، حسابك مسدد، شكرا لك.';
    final phone = m.waPhone;
    final url = 'sms:$phone?body=${Uri.encodeComponent(msg)}';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
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
  void _showWAPreview(String msg, String phone) {
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

  void _openWADebtOnly(Member m) {
    final debt = m.balance < 0 ? -m.balance : 0.0;
    final prov = context.read<AppProvider>();
    final instapay = [prov.instapayPhone, prov.instapayPhone2]
        .where((s) => s.isNotEmpty)
        .map((s) => '\n📲 InstaPay: $s')
        .join('');
    final vodafone = [prov.vodafoneCash, prov.vodafoneCash2]
        .where((s) => s.isNotEmpty)
        .map((s) => '\n📱 فودافون كاش: $s')
        .join('');
    final note = (prov.debtNoteEnabled && prov.debtNoteText.trim().isNotEmpty)
        ? '\n\n📢 ${prov.debtNoteText.trim()}'
        : '';
    final msg = debt > 0
        ? 'السلام عليكم ${m.name} 👋\nتذكير بمديونيتك: 🔴 ${debt.toStringAsFixed(0)} ج\nالاشتراك الشهري: ${m.price.toStringAsFixed(0)} ج$instapay$vodafone$note\nشكراً 🙏'
        : 'السلام عليكم ${m.name} 👋\n✅ حسابك مسدّد، شكراً لك 🙏';
    final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
    _showWAPreview(msg, phone);
  }

  void _openWAWithStatement(Member m) {
    final prov = context.read<AppProvider>();
    final paid = m.log
        .where((l) => (l['amount'] ?? 0) > 0)
        .fold<double>(0, (s, l) => s + ((l['amount'] ?? 0) as num).toDouble());
    final debt = m.balance < 0 ? -m.balance : 0.0;
    final instapay = [prov.instapayPhone, prov.instapayPhone2]
        .where((s) => s.isNotEmpty)
        .map((s) => '\n📲 InstaPay: $s')
        .join('');
    final vodafone = [prov.vodafoneCash, prov.vodafoneCash2]
        .where((s) => s.isNotEmpty)
        .map((s) => '\n📱 فودافون كاش: $s')
        .join('');

    final lines = StringBuffer();
    lines.writeln('السلام عليكم ${m.name} 👋');
    lines.writeln('━━━━━━━━━━━━━━━');
    lines.writeln('📋 كشف حساب تفصيلي:');
    lines.writeln('💳 الاشتراك الشهري: ${m.price.toStringAsFixed(0)} ج');
    lines.writeln('💰 إجمالي المدفوع: ${paid.toStringAsFixed(0)} ج');
    if (debt > 0) {
      lines.writeln('🔴 المديونية الحالية: ${debt.toStringAsFixed(0)} ج');
    } else {
      lines.writeln('✅ لا توجد مديونيات');
    }
    lines.writeln('━━━━━━━━━━━━━━━');
    if (m.log.isNotEmpty) {
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
    if (instapay.isNotEmpty || vodafone.isNotEmpty) {
      lines.writeln('━━━━━━━━━━━━━━━');
      lines.writeln('💳 طرق الدفع:$instapay$vodafone');
    }
    lines.writeln('━━━━━━━━━━━━━━━');

    final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
    _showWAPreview(lines.toString(), phone);
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
