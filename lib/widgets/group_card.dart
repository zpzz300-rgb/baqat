// lib/widgets/group_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import 'member_card.dart';
import 'add_member_modal.dart';
import 'add_group_modal.dart';
import 'complaints_sheet.dart';
import 'rental_sheet.dart';
import 'pin_dialog.dart';
import '../services/notification_service.dart';

class GroupCard extends StatefulWidget {
  final Group group;
  const GroupCard({super.key, required this.group});

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _expanded = false;

  // Provider-based header gradient
  LinearGradient _providerGradient(String? provider) {
    switch (provider) {
      case 'vodafone':
        return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEBEB), Color(0xFFFFCDD2)]);
      case 'etisalat':
        return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]);
      case 'orange':
        return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]);
      case 'we':
        return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)]);
      default:
        return AppColors.groupHeadGradient;
    }
  }

  Color _providerTextColor(String? provider) {
    switch (provider) {
      case 'vodafone':
        return const Color(0xFFC62828);
      case 'etisalat':
        return const Color(0xFF1B5E20);
      case 'orange':
        return const Color(0xFFE65100);
      case 'we':
        return const Color(0xFF4A148C);
      default:
        return AppColors.blue2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // Always read fresh group from db to avoid stale widget snapshot
    final group = prov.db.groups
        .firstWhere((g) => g.id == widget.group.id, orElse: () => widget.group);
    final members = prov.db.membersOf(group.id)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final debt = prov.db.groupDebt(group.id);
    final debtors = members.where((m) => m.balance < 0).length;
    // Offer end-date warning — blue header when ≤ 60 days left
    final offerEnd = group.offerEndDate != null
        ? DateTime.tryParse(group.offerEndDate!)
        : null;
    final today = DateTime.now();
    final offerDaysLeft = offerEnd
        ?.difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final isOfferWarning =
        offerDaysLeft != null && offerDaysLeft >= 0 && offerDaysLeft <= 60;

    // Detect landline / Home 4G sub-lines inside this group
    final landlineCount = members.where((m) => m.type == 'landline').length;
    final home4gCount = members.where((m) => m.type == 'homeforgee').length;
    final isSpecialLine = landlineCount > 0 || home4gCount > 0;
    final unresolvedComplaints =
        group.complaints.where((c) => c['resolved'] != true).length;

    final headerGrad = isSpecialLine
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEB3B), Color(0xFFFFC107)])
        : isOfferWarning
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)])
            : _providerGradient(group.provider);
    final headerTextColor = isSpecialLine
        ? const Color(0xFF5D4037)
        : isOfferWarning
            ? Colors.white
            : _providerTextColor(group.provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSpecialLine ? const Color(0xFFFFFDE7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color:
                isSpecialLine ? const Color(0xFFFFC107) : AppColors.border,
            width: isSpecialLine ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue2.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── GROUP HEADER ─────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: _expanded
                  ? const EdgeInsets.fromLTRB(16, 16, 12, 14)
                  : const EdgeInsets.fromLTRB(14, 8, 6, 8),
              decoration: BoxDecoration(
                gradient: headerGrad,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft:
                      _expanded ? Radius.zero : const Radius.circular(20),
                  bottomRight:
                      _expanded ? Radius.zero : const Radius.circular(20),
                ),
                border: _expanded
                    ? const Border(
                        bottom:
                            BorderSide(color: AppColors.blueMid, width: 1.5))
                    : null,
              ),
              child: !_expanded
                  ? _buildCompactBar(
                      context,
                      prov,
                      group,
                      members.length,
                      landlineCount,
                      home4gCount,
                      unresolvedComplaints,
                      headerTextColor,
                    )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row A: phone number + menu + arrow ──────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            group.phone,
                            style: GoogleFonts.cairo(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: headerTextColor,
                              letterSpacing: 0.5,
                            ),
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: AppColors.muted, size: 22),
                        onSelected: (v) => _onAction(v, context, prov),
                        itemBuilder: (_) => [
                          _menuItem('edit', '✏️ تعديل'),
                          _menuItem('addMember', '👤 إضافة عميل'),
                          _menuItem('notepad', '📓 المفكرة'),
                          _menuItem('stickyNote', '📌 ملاحظة ثابتة'),
                          _menuItem('complaints', '📝 الشكاوى'),
                          _menuItem('rental', '🏠 الإيجار'),
                          _menuItem('delete', '🗑 حذف', isRed: true),
                        ],
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.muted,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Row B: badges ────────────────────────────────
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // LineType badge
                      _buildLineTypeBadge(group),
                      // Provider badge
                      if (group.provider != null) _buildProviderBadge(group),
                      _badge(
                          group.type == '3800' ? '📡 3800' : '📶 1800',
                          AppColors.blueLight,
                          AppColors.blue3,
                          AppColors.blueMid),
                      _buildRentalIndicator(context, prov),
                      _badge(_cycleLabel(group), AppColors.blueLight,
                          AppColors.blue3, AppColors.blueMid),
                      _buildClientsBadge(members.length, group),
                      ..._buildMemberTypeBadges(members),
                      if (debtors > 0)
                        _badge('$debtors مديون', AppColors.redLight,
                            AppColors.red2, const Color(0xFFef9a9a)),
                      if (debt == 0 && members.isNotEmpty)
                        _badge('✅ سداد تام', AppColors.greenLight,
                            const Color(0xFF00695c), const Color(0xFF80cbc4)),
                      if (group.lastBillAmount > 0 || group.billDebt > 0)
                        _buildBillBadge(context, prov, group),
                      if (group.type == 'manual' && group.manualDueDate != null)
                        _buildManualDueDateBadge(group),
                      _buildProfitBadge(prov),
                      _buildComplaintsBadge(context, prov),
                      // Offer end date badge
                      if (group.offerEndDate != null)
                        _buildOfferEndBadge(group),
                      _buildExpiryBadge(prov),
                      _buildPointsBadge(context, prov, group),
                    ],
                  ),
                  // ── Sticky Note ──────────────────────────────────
                  if (group.stickyNote != null &&
                      group.stickyNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildStickyNote(context, prov, group),
                  ],

                  const SizedBox(height: 12),

                  // ── Row C: GB bar (full width) ───────────────────
                  _buildGbBar(prov),

                  // ── Minutes Bar (Phase 2) ────────────────────────
                  _buildMinutesBar(prov),

                  // ── Offer Countdown (Phase 2) ────────────────────
                  _buildOfferCountdown(),

                  // ── Insurance / WE coupon badges ─────────────────
                  _buildInsuranceBadge(),
                  _buildWeCouponBadge(),

                  // ── Row D: Financial summary (if set) ────────────
                  if (group.fixedBillAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildFinancialRow(group),
                  ],
                ],
              ),
            ),
          ),

          // ─── MEMBERS GRID ──────────────────────────────────────
          if (_expanded)
            members.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'لا يوجد عملاء في هذه المجموعة',
                      style: GoogleFonts.cairo(
                          color: AppColors.muted, fontSize: 13),
                    ),
                  )
                : prov.compactMembers
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: members.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.92,
                          ),
                          itemBuilder: (_, i) => CompactMemberCard(
                              member: members[i], group: group),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: members.length,
                          onReorder: (o, n) =>
                              prov.reorderMembers(group.id, o, n),
                          itemBuilder: (_, i) => Padding(
                            key: ValueKey(members[i].id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: MemberCard(
                                member: members[i], group: group),
                          ),
                        ),
                      ),
        ],
      ),
    );
  }

  // ── Compact Header Bar (collapsed state) ─────────────────────
  Widget _buildCompactBar(
    BuildContext context,
    AppProvider prov,
    Group group,
    int memberCount,
    int landlineCount,
    int home4gCount,
    int unresolvedComplaints,
    Color headerTextColor,
  ) {
    final billAmount = group.billDebt > 0
        ? group.billDebt
        : (group.lastBillAmount > 0 ? group.lastBillAmount : 0.0);
    final hasBillDebt = group.billDebt > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Phone number — large & prominent
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              group.phone,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: headerTextColor,
                letterSpacing: 0.5,
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Line type icons
        if (landlineCount > 0)
          _miniChip(Icons.phone_in_talk, '$landlineCount',
              const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
        if (home4gCount > 0) ...[
          if (landlineCount > 0) const SizedBox(width: 4),
          _miniChip(Icons.router, '$home4gCount',
              const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
        ],
        if (landlineCount > 0 || home4gCount > 0)
          const SizedBox(width: 4),
        // Client count
        _miniChip(Icons.people, '$memberCount',
            AppColors.blue3, AppColors.blueLight),
        const SizedBox(width: 4),
        // Bill amount (if any)
        if (billAmount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: hasBillDebt
                  ? const Color(0xFFFFEBEE)
                  : const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: hasBillDebt
                      ? const Color(0xFFEF9A9A)
                      : const Color(0xFFCE93D8)),
            ),
            child: Text(
              '${billAmount.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: hasBillDebt
                      ? const Color(0xFFC62828)
                      : const Color(0xFF6A1B9A)),
            ),
          ),
        if (unresolvedComplaints > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$unresolvedComplaints',
              style: GoogleFonts.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1),
            ),
          ),
        ],
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert,
              color: AppColors.muted, size: 20),
          onSelected: (v) => _onAction(v, context, prov),
          itemBuilder: (_) => [
            _menuItem('edit', '✏️ تعديل'),
            _menuItem('addMember', '👤 إضافة عميل'),
            _menuItem('notepad', '📓 المفكرة'),
            _menuItem('stickyNote', '📌 ملاحظة ثابتة'),
            _menuItem('complaints', '📝 الشكاوى'),
            _menuItem('rental', '🏠 الإيجار'),
            _menuItem('delete', '🗑 حذف', isRed: true),
          ],
        ),
        const Icon(Icons.keyboard_arrow_down,
            color: AppColors.muted, size: 22),
      ],
    );
  }

  Widget _miniChip(IconData icon, String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  // ── Sticky Note ───────────────────────────────────────────────
  Widget _buildStickyNote(BuildContext context, AppProvider prov, Group group) {
    return GestureDetector(
      onLongPress: () => _editStickyNote(context, prov, group),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFFF9A825).withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📌', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                group.stickyNote!,
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: const Color(0xFF5D4037),
                    fontWeight: FontWeight.w700),
              ),
            ),
            GestureDetector(
              onTap: () => _editStickyNote(context, prov, group),
              child: const Icon(Icons.edit_note,
                  size: 16, color: Color(0xFFF9A825)),
            ),
          ],
        ),
      ),
    );
  }

  void _editStickyNote(BuildContext context, AppProvider prov, Group group) {
    final ctrl = TextEditingController(text: group.stickyNote ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('📌 ملاحظة ثابتة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'اكتب تنبيهاً أو ملاحظة مهمة...',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: GoogleFonts.cairo(fontSize: 13),
        ),
        actions: [
          if (group.stickyNote != null)
            TextButton(
              onPressed: () {
                prov.updateGroupStickyNote(group.id, null);
                Navigator.pop(context);
              },
              child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              prov.updateGroupStickyNote(group.id, ctrl.text);
              Navigator.pop(context);
            },
            child: Text('حفظ',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── GB Bar ────────────────────────────────────────────────────
  Widget _buildGbBar(AppProvider prov) {
    final total = prov.db.groupTotalGb(widget.group.id);
    final used = prov.db.groupUsedGb(widget.group.id);
    final remaining = total - used;
    final fraction = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    // Phase 3 — Conditional colors based on FREE percentage
    final freePercent = total > 0 ? remaining / total : 0.0;
    final barColor = freePercent < 0.15
        ? AppColors.red
        : freePercent < 0.30
            ? AppColors.orange
            : AppColors.green;
    final mainLineGb = widget.group.mainLineAllocationGb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats row above bar
        Row(
          children: [
            // Used
            RichText(
              text: TextSpan(
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                children: [
                  const TextSpan(text: 'المستخدم: '),
                  TextSpan(
                    text: '$used GB',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: barColor,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Remaining badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color:
                    remaining <= 0 ? AppColors.redLight : AppColors.greenLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: remaining <= 0
                      ? AppColors.red.withValues(alpha: 0.3)
                      : AppColors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                remaining <= 0 ? '🔴 اكتمل' : '✅ متبقي $remaining GB',
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: remaining <= 0 ? AppColors.red2 : AppColors.green2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),

        // Full-width progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),

        const SizedBox(height: 3),
        // Total label + main line allocation hint
        Row(
          children: [
            Text(
              'الإجمالي: $total GB',
              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted),
            ),
            if (mainLineGb > 0) ...[
              const SizedBox(width: 8),
              Text(
                '(الخط الرئيسي: $mainLineGb)',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: AppColors.blue2,
                    fontWeight: FontWeight.w700),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () => _showExtraBundleDialog(prov),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.blue2,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('+ باقة إضافية',
                    style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Minutes Bar (Phase 2) ──────────────────────────────────────
  Widget _buildMinutesBar(AppProvider prov) {
    final total = widget.group.totalMinutes;
    if (total <= 0) return const SizedBox.shrink();
    final used = prov.db.groupUsedMinutes(widget.group.id);
    final remaining = total - used;
    final fraction = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(children: [
          const Text('🎙', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('الدقائق: ',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          Text('$used / $total',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(8)),
            child: Text('متبقي $remaining',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purple)),
          ),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 7,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
          ),
        ),
      ],
    );
  }

  // ── Dialog: إضافة باقة إضافية مؤقتة ──────────────────────────
  void _showExtraBundleDialog(AppProvider prov) {
    final gbCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🚀 شحن باقة إضافية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gbCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                  labelText: 'حجم الباقة (GB)',
                  labelStyle: GoogleFonts.cairo()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                  labelText: 'التكلفة (ج)', labelStyle: GoogleFonts.cairo()),
            ),
            const SizedBox(height: 8),
            Text(
                'هتُضاف للسعة هذا الشهر فقط، والتكلفة هتُخصم من صافي الربح',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final gb = int.tryParse(gbCtrl.text.trim()) ?? 0;
              final cost = double.tryParse(costCtrl.text.trim()) ?? 0;
              if (gb <= 0 || cost <= 0) return;
              prov.addExtraBundle(widget.group.id, gb, cost);
              Navigator.pop(context);
            },
            child: Text('تأكيد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Countdown Widget for offer end (Phase 2) ───────────────────
  Widget _buildOfferCountdown() {
    final days = widget.group.daysUntilOfferEnd;
    if (days == null || days < 0 || days > 75) return const SizedBox.shrink();
    final intensity = widget.group.offerWarningIntensity;
    final urgent = days <= 14;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0xFFFFF8E1), const Color(0xFFFFEBEE),
            intensity),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: urgent ? AppColors.red : const Color(0xFFFFB300),
            width: urgent ? 2 : 1),
      ),
      child: Row(children: [
        Icon(urgent ? Icons.warning_amber_rounded : Icons.timelapse,
            size: 16,
            color: urgent ? AppColors.red : const Color(0xFFE65100)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            urgent
                ? '⚠️ متبقي $days يوم على نهاية العرض!'
                : '⏳ متبقي $days يوم على نهاية العرض',
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: urgent ? AppColors.red2 : const Color(0xFFE65100)),
          ),
        ),
      ]),
    );
  }

  // ── Insurance reminder badge ───────────────────────────────────
  Widget _buildInsuranceBadge() {
    if (widget.group.refundableInsurance <= 0) return const SizedBox.shrink();
    final days = widget.group.daysUntilInsuranceClaim;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Text(
        days != null && days <= 0
            ? '💰 تأمين ${widget.group.refundableInsurance.toStringAsFixed(0)} ج — جاهز للاسترداد'
            : '💰 تأمين ${widget.group.refundableInsurance.toStringAsFixed(0)} ج — استرداد بعد ${days ?? '?'} يوم',
        style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.green2),
      ),
    );
  }

  // ── WE coupon countdown ────────────────────────────────────────
  Widget _buildWeCouponBadge() {
    final days = widget.group.daysUntilWeCoupon;
    if (days == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
      ),
      child: Text(
        days <= 0
            ? '🎫 قسيمة 5000 — جاهزة للمطالبة'
            : '🎫 قسيمة 5000 — متبقي $days يوم',
        style: GoogleFonts.cairo(
            fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.purple),
      ),
    );
  }

  // ── Financial Row ─────────────────────────────────────────────
  Widget _buildFinancialRow(Group group) {
    final fixed = group.fixedBillAmount;
    final voucher = group.voucherValue;
    final total = fixed - voucher;
    final nextDate = NotificationService.nextVoucherDate(
        group.voucherStartDate, group.voucherPeriod);
    final hasVoucher = voucher > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (group.groupInvoiceName != null) ...[
            Text('📄 ${group.groupInvoiceName}',
                style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70)),
            const SizedBox(width: 8),
          ],
          Text('${fixed.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (hasVoucher) ...[
            Text(' - ${voucher.toStringAsFixed(0)} 🎫',
                style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70)),
            Text(' = ${total.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: total >= 0
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFFEF9A9A))),
          ],
          if (hasVoucher && nextDate != null) ...[
            const Spacer(),
            Text('${nextDate.day}/${nextDate.month}/${nextDate.year}',
                style: GoogleFonts.cairo(fontSize: 10, color: Colors.white60)),
          ],
        ],
      ),
    );
  }

  // ── Rental Indicator ─────────────────────────────────────────
  Widget _buildRentalIndicator(BuildContext context, AppProvider prov) {
    final rentals =
        prov.db.rentals.where((r) => r.gid == widget.group.id).toList();
    final active = rentals.any((r) => r.status == 'active');
    final paused = !active && rentals.any((r) => r.status == 'paused');
    if (!active && !paused) return const SizedBox.shrink();

    final color = active ? AppColors.green : AppColors.orange;
    final bg = active ? AppColors.greenLight : AppColors.orangeLight;

    return GestureDetector(
      onTap: () => showModalBottomSheet(useRootNavigator: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (_) => RentalSheet(group: widget.group),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              active ? '🏠 مستأجر' : '⏸ موقف',
              style: GoogleFonts.cairo(
                  fontSize: 10, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // ── Provider Badge ────────────────────────────────────────────
  static const _pColors = {
    'vodafone': Color(0xFFe53935),
    'etisalat': Color(0xFF43a047),
    'orange': Color(0xFFef6c00),
    'we': Color(0xFF5e35b1),
  };
  static const _pEmojis = {
    'vodafone': '📱',
    'etisalat': '📡',
    'orange': '🟠',
    'we': '🔵',
  };
  static const _pNames = {
    'vodafone': 'فودافون',
    'etisalat': 'اتصالات',
    'orange': 'أورنج',
    'we': 'WE',
  };

  Widget _buildProviderBadge([Group? g]) {
    final p = (g ?? widget.group).provider!;
    final c = _pColors[p] ?? AppColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_pEmojis[p] ?? '📡', style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(_pNames[p] ?? p,
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w800, color: c)),
      ]),
    );
  }

  // ── Offer End Badge ───────────────────────────────────────────
  Widget _buildOfferEndBadge([Group? g]) {
    final endStr = (g ?? widget.group).offerEndDate!;
    final end = DateTime.tryParse(endStr);
    if (end == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final days =
        end.difference(DateTime(now.year, now.month, now.day)).inDays;
    final expired = days < 0;
    final warning = !expired && days <= 60;

    Color bgColor;
    Color textColor;
    String label;

    if (expired) {
      bgColor = AppColors.redLight;
      textColor = AppColors.red2;
      label = '🔴 عرض منتهي منذ ${-days} يوم';
    } else if (days == 0) {
      bgColor = const Color(0xFFFFEBEE);
      textColor = AppColors.red2;
      label = '🔴 آخر يوم للعرض';
    } else if (warning) {
      bgColor = const Color(0xFFE3F2FD);
      textColor = const Color(0xFF1565C0);
      label = '⏳ تبقى $days يوم للعرض';
    } else {
      bgColor = AppColors.greenLight;
      textColor = AppColors.green2;
      label = '✅ العرض: $days يوم';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
            fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  // ── Expiry Badge ─────────────────────────────────────────────
  Widget _buildExpiryBadge(AppProvider prov) {
    final days = prov.daysToExpiry(widget.group.id);
    if (days == null) return const SizedBox.shrink();
    final expired = days <= 0;
    final urgent = days <= 30;
    final warn = days <= 90;
    if (!warn && !expired) return const SizedBox.shrink();
    final color = expired
        ? AppColors.red
        : urgent
            ? AppColors.orange
            : const Color(0xFFf57c00);
    final bg = expired ? AppColors.redLight : AppColors.orangeLight;
    final label = expired ? '🔴 منتهي' : '⚠️ ينتهي خلال $days يوم';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label,
          style: GoogleFonts.cairo(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  // ── Points Badge ──────────────────────────────────────────────
  Widget _buildPointsBadge(BuildContext context, AppProvider prov, [Group? g]) {
    final grp = g ?? widget.group;
    final pts = grp.rewardPoints;
    final value = (pts * grp.pointsValue).toStringAsFixed(0);
    return GestureDetector(
      onTap: () => _openPointsSheet(context, prov),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: pts > 0 ? const Color(0xFFFFF8E1) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: pts > 0 ? const Color(0xFFFFD54F) : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            pts > 0 ? '🏆 $pts نقطة = $value ج' : '🏆 نقاط: 0',
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: pts > 0 ? const Color(0xFFF9A825) : AppColors.muted,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 12,
              color: pts > 0 ? const Color(0xFFF9A825) : AppColors.muted),
        ]),
      ),
    );
  }

  void _openPointsSheet(BuildContext context, AppProvider prov) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PointsSheet(group: widget.group),
    );
  }

  // ── Guest Badge ───────────────────────────────────────────────

  // ── Complaints Badge ──────────────────────────────────────────
  Widget _buildComplaintsBadge(BuildContext context, AppProvider prov) {
    final group = prov.db.groups
        .firstWhere((g) => g.id == widget.group.id, orElse: () => widget.group);
    final unresolved =
        group.complaints.where((c) => c['resolved'] != true).length;
    if (unresolved == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => showModalBottomSheet(useRootNavigator: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (_) => ComplaintsSheet(group: group),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.redLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppColors.red, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$unresolved شكوى',
              style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.red2)),
        ]),
      ),
    );
  }

  // ── Profit Badge ─────────────────────────────────────────────
  Widget _buildProfitBadge(AppProvider prov) {
    final profit = prov.db.groupProfit(widget.group.id);
    if (widget.group.actualBillAmount == null) return const SizedBox.shrink();
    final isPos = profit >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPos ? AppColors.greenLight : AppColors.redLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (isPos ? AppColors.green : AppColors.red)
                .withValues(alpha: 0.4)),
      ),
      child: Text(
        '${isPos ? "💰" : "📉"} ربح: ${profit.toStringAsFixed(0)} ج',
        style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isPos ? AppColors.green2 : AppColors.red2),
      ),
    );
  }

  // ── Bill Badge ───────────────────────────────────────────────
  Widget _buildBillBadge(BuildContext context, AppProvider prov, Group group) {
    final hasDebt = group.billDebt > 0;
    return GestureDetector(
      onTap: () => _showPayBillDialog(context, prov, group),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: hasDebt ? const Color(0xFFFFEBEE) : const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  hasDebt ? const Color(0xFFEF9A9A) : const Color(0xFFCE93D8)),
        ),
        child: Text(
          hasDebt
              ? '🔴 مديونية: ${group.billDebt.toStringAsFixed(0)} ج'
              : '💳 فاتورة: ${group.lastBillAmount.toStringAsFixed(0)} ج',
          style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color:
                  hasDebt ? const Color(0xFFC62828) : const Color(0xFF6A1B9A)),
        ),
      ),
    );
  }

  // ── Manual Due Date Badge ─────────────────────────────────────
  Widget _buildManualDueDateBadge(Group group) {
    final dueDate = DateTime.tryParse(group.manualDueDate!);
    if (dueDate == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final hoursLeft = dueDate.difference(now).inHours;
    final isPast = hoursLeft < 0;
    final isUrgent = hoursLeft <= 48;
    if (!isUrgent && !isPast) {
      // Show subtle reminder badge (>48h away)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFCC02)),
        ),
        child: Text(
          '📅 موعد السداد: ${group.manualDueDate}',
          style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE65100)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPast ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isPast ? const Color(0xFFC62828) : const Color(0xFFE65100),
            width: 1.5),
      ),
      child: Text(
        isPast ? '🔴 فات موعد السداد!' : '⚠️ موعد السداد بعد $hoursLeftس',
        style: GoogleFonts.cairo(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isPast ? const Color(0xFFC62828) : const Color(0xFFE65100),
        ),
      ),
    );
  }

  void _showPayBillDialog(BuildContext context, AppProvider prov, Group group) {
    final addCtrl = TextEditingController();
    final payCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('💳 فواتير ${group.phone}',
            style:
                GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── إجمالي المديونية ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: group.billDebt > 0
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Text('إجمالي مديونيتك: ',
                    style: GoogleFonts.cairo(
                        fontSize: 13, color: AppColors.muted)),
                Text('${group.billDebt.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: group.billDebt > 0
                            ? const Color(0xFFC62828)
                            : AppColors.green2)),
              ]),
            ),
            const SizedBox(height: 14),
            // ── إضافة فاتورة جديدة ──
            Text('📋 إضافة فاتورة جديدة',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: addCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'قيمة الفاتورة الجديدة (ج)',
                hintStyle: GoogleFonts.cairo(fontSize: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF6A1B9A)),
                  onPressed: () {
                    final amt = double.tryParse(addCtrl.text.trim());
                    if (amt == null || amt <= 0) return;
                    Navigator.pop(ctx);
                    prov.addGroupBill(group.id, amt);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '📋 تم إضافة فاتورة ${amt.toStringAsFixed(0)} ج للمديونية',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF6A1B9A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── سداد جزئي أو كلي ──
            Text('💰 سداد (جزئي أو كلي)',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: payCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'المبلغ المسدد (ج)',
                hintStyle: GoogleFonts.cairo(fontSize: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon:
                      const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                  onPressed: () {
                    final amt = double.tryParse(payCtrl.text.trim());
                    if (amt == null || amt <= 0) return;
                    Navigator.pop(ctx);
                    prov.payGroupBillDebt(group.id, amt);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('✅ تم سداد ${amt.toStringAsFixed(0)} ج',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      backgroundColor: AppColors.green2,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                ),
              ),
            ),
            if (group.billDebt > 0) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  prov.payGroupBillDebt(group.id, group.billDebt);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '✅ تم سداد كامل المديونية ${group.billDebt.toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    backgroundColor: AppColors.green2,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.green),
                  ),
                  child: Text(
                      '✅ سداد كامل المديونية (${group.billDebt.toStringAsFixed(0)} ج)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green2)),
                ),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  // ── LineType Badge ────────────────────────────────────────────
  Widget _buildLineTypeBadge([Group? g]) {
    final lt = (g ?? widget.group).lineType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: lt.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: lt.color.withValues(alpha: 0.4)),
      ),
      child: Text('${lt.emoji} ${lt.label}',
          style: GoogleFonts.cairo(
              fontSize: 10, fontWeight: FontWeight.w800, color: lt.color)),
    );
  }

  // ── Clients Badge (red excess indicator) ─────────────────────
  Widget _buildClientsBadge(int count, [Group? g]) {
    final group = g ?? widget.group;
    final max = group.maxClients;
    final isExempt =
        group.lineType == LineType.home4g || group.lineType == LineType.adsl;
    if (max == null || count <= max || isExempt) {
      return _badge('$count عميل', AppColors.blueLight, AppColors.blue3,
          AppColors.blueMid);
    }
    final excess = count - max;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _badge(
          '$max عميل', AppColors.blueLight, AppColors.blue3, AppColors.blueMid),
      const SizedBox(width: 4),
      _badge('+$excess زيادة', AppColors.redLight, AppColors.red2,
          const Color(0xFFef9a9a)),
    ]);
  }

  // ── Member Type Badges ────────────────────────────────────────
  List<Widget> _buildMemberTypeBadges(List<Member> members) {
    final landline = members.where((m) => m.type == 'landline').length;
    final home4g = members.where((m) => m.type == 'homeforgee').length;
    final widgets = <Widget>[];
    if (landline > 0) {
      widgets.add(_badge('☎️ أرضي: $landline', const Color(0xFFE3F2FD),
          const Color(0xFF1565C0), const Color(0xFF42A5F5)));
    }
    if (home4g > 0) {
      widgets.add(_badge('🏠 هوم فور جي: $home4g', const Color(0xFFF3E5F5),
          const Color(0xFF6A1B9A), const Color(0xFFAB47BC)));
    }
    return widgets;
  }

  // ── Cycle Label ───────────────────────────────────────────────
  static const _cycleLabels = {
    'day1': '📅 أول الشهر',
    'day4': '📅 اليوم 4',
    'mid': '📅 منتصف الشهر',
    'cycle1': '🔄 سيكل 1',
    'cycle2': '🔄 سيكل 2',
  };
  String _cycleLabel(Group group) {
    if (group.billingCycle != null &&
        _cycleLabels.containsKey(group.billingCycle)) {
      return _cycleLabels[group.billingCycle]!;
    }
    return '🔄 سيكل ${group.cycle}';
  }

  // ── Badge helper ──────────────────────────────────────────────
  Widget _badge(String label, Color bg, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
            fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label,
      {bool isRed = false}) {
    return PopupMenuItem(
      value: value,
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: isRed ? AppColors.red : AppColors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _onAction(String action, BuildContext ctx, AppProvider prov) {
    switch (action) {
      case 'edit':
        showModalBottomSheet(useRootNavigator: true,
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
          builder: (_) => ChangeNotifierProvider.value(
            value: prov,
            child: AddGroupModal(existing: widget.group),
          ),
        );
        break;
      case 'addMember':
        showModalBottomSheet(useRootNavigator: true,
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
          builder: (_) => AddMemberModal(preselectedGroup: widget.group.id),
        );
        break;
      case 'notepad':
        showModalBottomSheet(useRootNavigator: true,
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
          builder: (_) => _GroupNotepadSheet(group: widget.group),
        );
        break;
      case 'stickyNote':
        final freshGroup = prov.db.groups.firstWhere(
            (g) => g.id == widget.group.id,
            orElse: () => widget.group);
        _editStickyNote(ctx, prov, freshGroup);
        break;
      case 'complaints':
        showModalBottomSheet(useRootNavigator: true,
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
          builder: (_) => ComplaintsSheet(group: widget.group),
        );
        break;
      case 'rental':
        showModalBottomSheet(useRootNavigator: true,
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
          builder: (_) => RentalSheet(group: widget.group),
        );
        break;
      case 'delete':
        showDialog(
          context: ctx,
          builder: (_) => PinDialog(
            title: 'حذف المجموعة ${widget.group.phone}',
            onConfirm: () {
              prov.deleteGroup(widget.group.id);
            },
          ),
        );
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Group Notepad Bottom Sheet
// ─────────────────────────────────────────────────────────────────
class _GroupNotepadSheet extends StatefulWidget {
  final Group group;
  const _GroupNotepadSheet({required this.group});
  @override
  State<_GroupNotepadSheet> createState() => _GroupNotepadSheetState();
}

class _GroupNotepadSheetState extends State<_GroupNotepadSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final group = prov.db.groups
        .firstWhere((g) => g.id == widget.group.id, orElse: () => widget.group);
    final notes = group.groupNotes;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDE7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
          child: Row(children: [
            const Text('📓', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('مفكرة الخط',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                  Text(group.phone,
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.muted)),
                ])),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        // Add note input
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 2,
                minLines: 1,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'اكتب ملاحظة...',
                  hintStyle:
                      GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_ctrl.text.trim().isEmpty) return;
                context.read<AppProvider>().addGroupNote(group.id, _ctrl.text);
                _ctrl.clear();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        // Notes list
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📝', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('لا توجد ملاحظات بعد',
                      style: GoogleFonts.cairo(
                          color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('الملاحظات التلقائية تظهر عند التجديد',
                      style: GoogleFonts.cairo(
                          color: AppColors.muted, fontSize: 11)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = notes[i];
                    final isAuto = n['type'] == 'auto';
                    final isBill = n['type'] == 'bill';
                    final bg = isBill
                        ? const Color(0xFFEDE7F6)
                        : isAuto
                            ? const Color(0xFFE3F2FD)
                            : Colors.white;
                    final borderColor = isBill
                        ? const Color(0xFFCE93D8)
                        : isAuto
                            ? AppColors.blueMid
                            : AppColors.border;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(n['text'] ?? '',
                                  style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(n['date'] ?? '',
                                  style: GoogleFonts.cairo(
                                      fontSize: 10, color: AppColors.muted)),
                            ])),
                        if (!isAuto)
                          GestureDetector(
                            onTap: () => context
                                .read<AppProvider>()
                                .deleteGroupNote(group.id, i),
                            child: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.muted),
                          ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Points Details Bottom Sheet
// ─────────────────────────────────────────────────────────────────
class _PointsSheet extends StatefulWidget {
  final Group group;
  const _PointsSheet({required this.group});
  @override
  State<_PointsSheet> createState() => _PointsSheetState();
}

class _PointsSheetState extends State<_PointsSheet> {
  final _ptsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _date = '';
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ptsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // Read the latest group from provider (not the widget snapshot)
    final group = prov.db.groups.firstWhere(
      (g) => g.id == widget.group.id,
      orElse: () => widget.group,
    );
    final pts = group.rewardPoints;
    final rate = group.pointsValue; // EGP per point
    final totalVal = pts * rate;
    final per1000 = (1000 * rate).toStringAsFixed(0);
    final history = group.pointsRedemptions;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF9A825), Color(0xFFFFD54F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('🏆', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نقاط المكافآت',
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                      Text('1000 نقطة = $per1000 ج',
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                // Edit rate
                GestureDetector(
                  onTap: () => _editRateDialog(context, prov, group.id, rate),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.tune, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('السعر',
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Balance Card ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: pts > 0
                          ? const Color(0xFFFFF8E1)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: pts > 0
                            ? const Color(0xFFFFD54F)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCol(
                            'الرصيد', '$pts\nنقطة', const Color(0xFFF9A825)),
                        Container(
                            width: 1, height: 40, color: AppColors.border),
                        _statCol(
                            'القيمة',
                            '${totalVal.toStringAsFixed(0)}\nجنيه',
                            AppColors.green2),
                        Container(
                            width: 1, height: 40, color: AppColors.border),
                        _statCol('المستردة', '${history.length}\nعملية',
                            AppColors.blue2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Manual Edit ─────────────────────────────────
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue2,
                      side: const BorderSide(color: AppColors.blueMid),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text('تعديل الرصيد يدوياً',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    onPressed: () =>
                        _editPointsDialog(context, prov, group.id, pts),
                  ),
                  const SizedBox(height: 16),

                  // ── Redeem Form Toggle ───────────────────────────
                  if (pts > 0)
                    GestureDetector(
                      onTap: () => setState(() => _showForm = !_showForm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF81C784)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.redeem,
                                color: Color(0xFF388E3C), size: 18),
                            const SizedBox(width: 8),
                            Text('استرداد نقاط',
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E7D32))),
                            const Spacer(),
                            Icon(
                                _showForm
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: const Color(0xFF388E3C)),
                          ],
                        ),
                      ),
                    ),

                  // ── Redeem Form ─────────────────────────────────
                  if (_showForm && pts > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Points input + live value
                          StatefulBuilder(
                            builder: (ctx, setSt) {
                              final entered =
                                  int.tryParse(_ptsCtrl.text.trim()) ?? 0;
                              final enteredVal =
                                  (entered * rate).toStringAsFixed(0);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _ptsCtrl,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setSt(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'عدد النقاط (الرصيد: $pts)',
                                      labelStyle:
                                          GoogleFonts.cairo(fontSize: 12),
                                      hintText: '$pts',
                                      suffixText: 'نقطة',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                  if (entered > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        '$entered نقطة = $enteredVal ج',
                                        style: GoogleFonts.cairo(
                                            color: AppColors.green2,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          // Date picker
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                locale: const Locale('ar'),
                              );
                              if (picked != null) {
                                setState(() {
                                  _date =
                                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 16, color: AppColors.muted),
                                  const SizedBox(width: 8),
                                  Text(_date,
                                      style: GoogleFonts.cairo(fontSize: 13)),
                                  const Spacer(),
                                  Text('تغيير',
                                      style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          color: AppColors.blue3)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notesCtrl,
                            decoration: InputDecoration(
                              labelText: 'ملاحظات (اختياري)',
                              labelStyle: GoogleFonts.cairo(fontSize: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF388E3C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.redeem, size: 18),
                              label: Text('استرداد',
                                  style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w900)),
                              onPressed: () {
                                final entered =
                                    int.tryParse(_ptsCtrl.text.trim());
                                final toRedeem =
                                    (entered != null && entered > 0)
                                        ? entered
                                        : pts;
                                if (toRedeem > pts) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'النقاط المدخلة أكثر من الرصيد ($pts)',
                                            style: GoogleFonts.cairo())),
                                  );
                                  return;
                                }
                                prov.redeemPoints(
                                  group.id,
                                  ptsToRedeem: toRedeem,
                                  notes: _notesCtrl.text.trim(),
                                  date: _date,
                                );
                                _ptsCtrl.clear();
                                _notesCtrl.clear();
                                setState(() => _showForm = false);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Redemption History ───────────────────────────
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('سجل الاستردادات',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.blue2)),
                    const SizedBox(height: 8),
                    ...history.map((r) {
                      final rPts = r['pts'] as int? ?? 0;
                      final rVal = (r['value'] as num?)?.toDouble() ?? 0;
                      final rDate = r['date'] ?? '';
                      final rNote = r['notes'] as String? ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Row(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '$rPts نقطة = ${rVal.toStringAsFixed(0)} ج',
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: const Color(0xFFF9A825))),
                                  Text(rDate,
                                      style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          color: AppColors.muted)),
                                  if (rNote.isNotEmpty)
                                    Text(rNote,
                                        style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: AppColors.text)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  if (history.isEmpty && pts == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Text('لا توجد نقاط بعد',
                            style: GoogleFonts.cairo(
                                color: AppColors.muted, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  void _editRateDialog(
      BuildContext context, AppProvider prov, String gid, double currentRate) {
    final ctrl =
        TextEditingController(text: (currentRate * 1000).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('⚙️ سعر الاسترداد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('كم جنيه تساوي 1000 نقطة؟',
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'قيمة 1000 نقطة بالجنيه',
                labelStyle: GoogleFonts.cairo(),
                suffixText: 'ج',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final per1000 = double.tryParse(ctrl.text.trim());
              if (per1000 != null && per1000 > 0) {
                prov.setPointsValueRate(gid, per1000 / 1000);
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

  void _editPointsDialog(
      BuildContext context, AppProvider prov, String gid, int currentPts) {
    final ctrl = TextEditingController(text: currentPts.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✏️ تعديل الرصيد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'عدد النقاط',
            labelStyle: GoogleFonts.cairo(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final pts = int.tryParse(ctrl.text.trim());
              if (pts != null && pts >= 0) prov.setGroupPoints(gid, pts);
              Navigator.pop(context);
            },
            child: Text('حفظ',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
