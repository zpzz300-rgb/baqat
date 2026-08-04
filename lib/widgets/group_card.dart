// lib/widgets/group_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import 'member_card.dart';
import 'add_member_modal.dart';
import 'add_group_modal.dart';
import 'complaints_sheet.dart';
import 'common.dart';
import '../services/supabase_service.dart';
import 'rental_sheet.dart';
import 'pin_dialog.dart';
import '../services/notification_service.dart';

part 'group_card_notepad_sheet.dart';
part 'group_card_points_sheet.dart';

// ─── 🔄 السيكل — مصدر واحد للاسم المختصر والمفتاح ─────────────────
// «سيكل 1» بقت «س1» عشان تاخد مساحة أقل في الهيدر، ونفس الاختصار
// بيتستخدم في فلتر السيكل اللي فوق قايمة الخطوط.

/// مفتاح السيكل بتاع المجموعة (بيوحّد billingCycle مع الرقم القديم cycle)
String cycleKeyOf(Group g) => g.billingCycle ?? 'cycle${g.cycle}';

const _kCycleShort = {
  'day1': '📅 1',
  'day4': '📅 4',
  'mid': '📅 15',
  'cycle1': 'س1',
  'cycle2': 'س2',
};

/// الاسم المختصر اللي بيظهر على البادچ وعلى شريط الفلتر
String cycleShortOf(String key) =>
    _kCycleShort[key] ?? (key.startsWith('cycle') ? 'س${key.substring(5)}' : key);

String cycleShortLabel(Group g) => cycleShortOf(cycleKeyOf(g));

/// الاسم الكامل — بيتستخدم في التلميحات والشرح
const kCycleFullNames = {
  'day1': 'أول الشهر',
  'day4': 'اليوم 4',
  'mid': 'منتصف الشهر',
  'cycle1': 'سيكل 1',
  'cycle2': 'سيكل 2',
};

class GroupCard extends StatefulWidget {
  final Group group;
  final bool initiallyExpanded; // بيانات الخط الكاملة تفتح افتراضياً
  final bool initiallyMembersExpanded; // يتفتح تلقائياً (مثلاً بعد البحث عن عميل)
  const GroupCard({
    super.key,
    required this.group,
    this.initiallyExpanded = true,
    this.initiallyMembersExpanded = false,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  late bool _expanded = widget.initiallyExpanded;
  late bool _membersExpanded = widget.initiallyMembersExpanded;

  @override
  void didUpdateWidget(GroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // لو اتطلب فتحها بعد البحث وهي كانت مقفولة → افتحها
    if (!oldWidget.initiallyExpanded && widget.initiallyExpanded && !_expanded) {
      setState(() => _expanded = true);
    }
    if (!oldWidget.initiallyMembersExpanded &&
        widget.initiallyMembersExpanded &&
        !_membersExpanded) {
      setState(() => _membersExpanded = true);
    }
  }

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

  // لون مميِّز للشركة (للبوردر والظل) — null للخطوط بدون شركة
  Color? _providerAccent(String? provider) {
    switch (provider) {
      case 'vodafone':
        return const Color(0xFFe53935);
      case 'etisalat':
        return const Color(0xFF43a047);
      case 'orange':
        return const Color(0xFFef6c00);
      case 'we':
        return const Color(0xFF5e35b1);
      default:
        return null;
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
    // 📆 تحذير آخر فاتورة قابلة للإلغاء — أولوية أعلى من تحذير نهاية العرض
    final isCancelWarning = group.isCancelCountdownActive;

    // Detect landline / Home 4G sub-lines inside this group
    final landlineCount = members.where((m) => m.type == 'landline').length;
    final home4gCount = members.where((m) => m.type == 'homeforgee').length;
    final isSpecialLine = landlineCount > 0 || home4gCount > 0;
    // عدد العملاء العاديين فقط (بدون الأرضي/الهوم فور جي — دول اكسبشن إضافي
    // وبيظهروا برموز بارزة منفصلة، فلا يُحسبوا مع عدد العملاء).
    final regularCount = members.length - landlineCount - home4gCount;
    final unresolvedComplaints =
        group.complaints.where((c) => c['resolved'] != true).length;

    final headerGrad = isCancelWarning
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB71C1C), Color(0xFFE53935)])
        : isSpecialLine
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
    final headerTextColor = isCancelWarning
        ? Colors.white
        : isSpecialLine
            ? const Color(0xFF5D4037)
            : isOfferWarning
                ? Colors.white
                : _providerTextColor(group.provider);

    final accent = _providerAccent(group.provider);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSpecialLine ? const Color(0xFFFFFDE7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isSpecialLine
                ? const Color(0xFFFFC107)
                : (accent?.withValues(alpha: 0.45) ?? AppColors.border),
            width: isSpecialLine ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: (accent ?? AppColors.blue2).withValues(alpha: 0.12),
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
            // 🗂 ضغطة مطوّلة → يفتح الخط في تاب علوي بمساحة العمل
            onLongPress: () {
              HapticFeedback.mediumImpact();
              context.read<AppProvider>().openWorkspaceTab(
                    'group',
                    args: {'gid': widget.group.id},
                    title: widget.group.ownerName?.isNotEmpty == true
                        ? widget.group.ownerName!
                        : widget.group.phone,
                    emoji: '📶',
                  );
            },
            child: Container(
              padding: _expanded
                  ? const EdgeInsets.fromLTRB(14, 12, 10, 10)
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
                    ? Border(
                        bottom:
                            BorderSide(color: AppColors.blueMid, width: 1.5))
                    : null,
              ),
              child: !_expanded
                  ? _buildCompactBar(
                      context,
                      prov,
                      group,
                      regularCount,
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
                      // ☎️/📶 علامة خط الزيادة — **مكان ثابت** جنب الرقم
                      // على طول، مش في صف البادچات اللي بيتلخبط ويتنقّل.
                      _buildExtraLineMark(landlineCount, home4gCount),
                      // الرقم — كبير وثابت: FittedBox بيصغّره لو لزم، لكن
                      // الخانة اللي جنبه محجوزة بعرض ثابت فمكانه مابيتحركش
                      // من كارت لكارت.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            group.phone,
                            style: GoogleFonts.cairo(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: headerTextColor,
                              letterSpacing: 0,
                              height: 1.1,
                            ),
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
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
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.muted,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Row B: badges ────────────────────────────────
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // LineType badge
                      _buildLineTypeBadge(group),
                      // Provider badge
                      if (group.provider != null) _buildProviderBadge(group),
                      _buildRentalIndicator(context, prov),
                      _badge(_cycleLabel(group), AppColors.blueLight,
                          AppColors.blue3, AppColors.blueMid),
                      _buildClientsBadge(regularCount, group),
                      // ☎️/📶 اتنقلوا لمكان ثابت فوق جنب الرقم
                      // «✅ سداد تام» اتشال — بادچ العملاء لو مفيش فيه رقم
                      // أحمر يبقى معناها سداد تام أصلاً، فمالهاش لازمة.
                      // بادچ الفاتورة = المبلغ + العدّاد في حتة واحدة.
                      // العدّاد لوحده بيظهر بس لو مفيش مبلغ فاتورة أصلاً.
                      if (group.lastBillAmount > 0 || group.billDebt > 0)
                        _buildBillBadge(context, prov, group)
                      else
                        _buildNearestBillBadge(prov),
                      if (group.type == 'manual' && group.manualDueDate != null)
                        _buildManualDueDateBadge(group),
                      _buildProfitBadge(prov),
                      _buildComplaintsBadge(context, prov),
                      // بادچ نهاية العرض اتشال — نفس المعلومة موجودة في
                      // الدايرة الصغيرة جنب عدّاد الإلغاء تحت، فكانت تكرار.
                      if (SupabaseService.isEmployee &&
                          !prov.canEditGroup(group.id))
                        _badge('👁 عرض فقط', const Color(0xFFF5F5F5),
                            AppColors.muted, AppColors.border),
                      _buildExpiryBadge(prov),
                      _buildDeferBadge(prov),
                      if (prov.assigneeOf(group.id) != null)
                        _badge('👤 ${prov.assigneeOf(group.id)}',
                            const Color(0xFFEDE7F6), const Color(0xFF4527A0),
                            const Color(0xFFB39DDB)),
                      if (group.billCredit > 0)
                        _badge('💰 رصيد ${group.billCredit.toStringAsFixed(0)} ج',
                            const Color(0xFFE8F5E9), const Color(0xFF00695c),
                            const Color(0xFFA5D6A7)),
                      _buildPointsBadge(context, prov, group),
                    ],
                  ),
                  // ── Sticky Note ──────────────────────────────────
                  if (group.stickyNote != null &&
                      group.stickyNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildStickyNote(context, prov, group),
                  ],

                  const SizedBox(height: 8),

                  // ── Row C: GB bar (full width) ───────────────────
                  _buildGbBar(prov),

                  // ── Minutes Bar (Phase 2) ────────────────────────
                  _buildMinutesBar(prov),

                  // ── 📆 عدّاد الإلغاء (الأهم) + دايرة نهاية العرض ──
                  _buildDeadlineCountdowns(),

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

          // ─── MEMBERS TOGGLE + GRID ─────────────────────────────
          if (_expanded) ...[
            _buildMembersToggleBar(
                members.length, landlineCount + home4gCount),
            if (_membersExpanded)
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
        ],
      ),
    );
  }

  // ── Members Toggle Bar — قائمة منسدلة صغيرة مستقلة لأرقام العملاء ──
  /// الشريط بيوضّح إن الإجمالي = عملاء عاديين + خطوط زيادة، عشان ما يبقاش
  /// فيه لخبطة بين الرقم اللي فوق (العاديين بس) والرقم اللي هنا.
  Widget _buildMembersToggleBar(int count, [int extra = 0]) {
    final label = extra > 0
        ? 'أرقام العملاء (${count - extra} + $extra زيادة)'
        : 'أرقام العملاء ($count)';
    return GestureDetector(
      onTap: () => setState(() => _membersExpanded = !_membersExpanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Icon(Icons.people_outline, size: 16, color: AppColors.blue3),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue3)),
            const Spacer(),
            Icon(
              _membersExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.muted,
            ),
          ],
        ),
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
        // ☎️/📶 نفس المكان بالظبط زي الكارت المفتوح — أقصى اليمين
        _buildExtraLineMark(landlineCount, home4gCount, size: 28),
        // Phone number — large & prominent
        Expanded(
          flex: 7,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              group.phone,
              style: GoogleFonts.cairo(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: headerTextColor,
                letterSpacing: 0,
                height: 1.1,
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Client count
        _miniChip(Icons.people, '$memberCount',
            AppColors.blue3, AppColors.blueLight),
        const SizedBox(width: 4),
        // 📆 عدّاد آخر فاتورة قابلة للإلغاء — يفضل ظاهر والكارت مقفول
        ...() {
          final d = group.daysUntilCancelDeadline;
          if (d == null || d > 60 || d < -30) return const <Widget>[];
          final expired = d < 0;
          return [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCDD2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.red2, width: 1.5),
              ),
              child: Text(
                expired ? '🚫 فات الإلغاء' : '📆 $d ي للإلغاء',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.red2),
              ),
            ),
            const SizedBox(width: 4),
          ];
        }(),
        // عداد انتهاء الخط — يظهر مختصر حتى والكارت مقفول وقت الخطورة
        ...() {
          final info = _expiryInfo(prov);
          if (info == null || !(info.critical || info.days < 0)) return const <Widget>[];
          return [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: info.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: info.color.withValues(alpha: 0.9), width: 1.5),
              ),
              child: Text(
                info.days < 0 ? '🔴 منتهي' : '🔴 ${info.days}ي',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: info.color),
              ),
            ),
            const SizedBox(width: 4),
          ];
        }(),
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
            decoration: BoxDecoration(
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
          icon: Icon(Icons.more_vert,
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
        Icon(Icons.keyboard_arrow_down,
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

  // ── Sticky Note — شريط صغير سطر واحد (دوس عشان تقراها كاملة/تعدّلها) ──
  Widget _buildStickyNote(BuildContext context, AppProvider prov, Group group) {
    return GestureDetector(
      onTap: () => _editStickyNote(context, prov, group),
      onLongPress: () => _editStickyNote(context, prov, group),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFFF9A825).withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            const Text('📌', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                group.stickyNote!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: const Color(0xFF5D4037),
                    fontWeight: FontWeight.w700),
              ),
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

        // Full-width progress bar (اضغط → تقسيم الجيجا/الدقايق/الدولي لكل عميل)
        GestureDetector(
          onTap: () => _showUsageBreakdown(prov),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
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
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple),
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

  // ── 📆 عدّاد آخر فاتورة قابلة للإلغاء (الأهم) ──────────────────
  /// بيظهر في الهيدر قبل التاريخ بشهرين (60 يوم) وبيفضل ظاهر لحد 30 يوم بعده
  /// كتحذير إن ميعاد الإلغاء فات. لو مفيش تاريخ إلغاء بنرجع لعدّاد العرض العادي.
  Widget _buildDeadlineCountdowns() {
    final g = widget.group;
    final cancelDays = g.daysUntilCancelDeadline;
    final showCancel =
        cancelDays != null && cancelDays <= 60 && cancelDays >= -30;
    if (!showCancel) return _buildOfferCountdown();

    final expired = cancelDays < 0;
    final urgent = !expired && cancelDays <= 14;
    // كل ما الوقت يقل، الخلفية تحمرّ أكتر
    final intensity = expired ? 1.0 : (60 - cancelDays) / 60;
    final mainColor =
        expired || urgent ? AppColors.red2 : const Color(0xFFC62828);

    final label = expired
        ? '🚫 فات ميعاد الإلغاء من ${-cancelDays} يوم'
        : cancelDays == 0
            ? '🚨 النهارده آخر يوم تقدر تلغي فيه!'
            : urgent
                ? '🚨 باقي $cancelDays يوم على آخر فاتورة تقدر تلغي عندها'
                : '📆 باقي $cancelDays يوم على آخر فاتورة قابلة للإلغاء';

    return Row(children: [
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFFFF3E0),
                const Color(0xFFFFCDD2), intensity),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: mainColor, width: expired || urgent ? 2 : 1.2),
          ),
          child: Row(children: [
            Icon(
                expired
                    ? Icons.block
                    : urgent
                        ? Icons.notification_important_rounded
                        : Icons.alarm,
                size: 18,
                color: mainColor),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: mainColor)),
                  if (g.cancelDeadlineDate != null)
                    Text(g.cancelDeadlineDate!,
                        style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: mainColor.withValues(alpha: 0.75))),
                ],
              ),
            ),
          ]),
        ),
      ),
      // دايرة صغيرة لنهاية العرض (الهارد) جنب العدّاد الكبير
      _buildOfferEndCircle(),
    ]);
  }

  /// دايرة صغيرة بتوضح الأيام المتبقية على نهاية العرض (الديدلاين النهائي)
  Widget _buildOfferEndCircle() {
    final days = widget.group.daysUntilOfferEnd;
    if (days == null) return const SizedBox.shrink();
    final expired = days < 0;
    final color = expired || days <= 14
        ? AppColors.red2
        : days <= 60
            ? const Color(0xFFE65100)
            : AppColors.green2;
    return Tooltip(
      message: expired
          ? 'العرض انتهى من ${-days} يوم'
          : 'نهاية العرض بعد $days يوم (${widget.group.offerEndDate})',
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color, width: 1.6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(expired ? '—' : '$days',
                style: GoogleFonts.cairo(
                    fontSize: days > 999 ? 10 : 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: color)),
            Text('عرض',
                style: GoogleFonts.cairo(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: color)),
          ],
        ),
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
  /// رمز قصير بالإنجليزي بدل الاسم الكامل — بياخد مساحة أقل بكتير في الهيدر
  static const _pShort = {
    'vodafone': 'VODA',
    'etisalat': 'ETIS',
    'orange': 'ORNG',
    'we': 'WE',
  };

  Widget _buildProviderBadge([Group? g]) {
    final p = (g ?? widget.group).provider!;
    final c = _pColors[p] ?? AppColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(_pShort[p] ?? p,
          textDirection: TextDirection.ltr,
          style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: c,
              letterSpacing: 0.5)),
    );
  }

  // ── Expiry Badge ─────────────────────────────────────────────
  /// قائمة منبثقة: تقسيم استهلاك الجيجا والدقايق والدولي على عملاء الخط.
  void _showUsageBreakdown(AppProvider prov) {
    final g = prov.db.groups
        .firstWhere((x) => x.id == widget.group.id, orElse: () => widget.group);
    final members = prov.db.membersOf(g.id);
    final totalGb = prov.db.groupTotalGb(g.id);
    final usedGb = prov.db.groupUsedGb(g.id);
    final usedMin = prov.db.groupUsedMinutes(g.id);
    final usedIntl = prov.db.groupUsedInternational(g.id);

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, sc) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFf8fbff),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('📊 تقسيم استهلاك الخط ${g.phone}',
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _usageChip('📶 جيجا', '$usedGb / $totalGb'),
                    _usageChip('📞 دقايق', '$usedMin / ${g.totalMinutes}'),
                    _usageChip('🌍 دولي', '$usedIntl / ${g.totalInternational}'),
                  ]),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Text('لا يوجد عملاء',
                            style: GoogleFonts.cairo(color: AppColors.muted)))
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                        itemCount: members.length,
                        itemBuilder: (_, i) {
                          final m = members[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border)),
                            child: Row(children: [
                              Expanded(
                                  child: Text(m.name,
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis)),
                              _miniUsage('📶', '${m.gb}'),
                              _miniUsage('📞', '${m.effectiveMinutes}'),
                              _miniUsage('🌍', '${m.internationalAllocation}'),
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

  Widget _usageChip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border)),
        child: Text('$label: $value',
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.blue2)),
      );

  Widget _miniUsage(String icon, String value) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text('$icon $value',
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.muted)),
      );

  /// بيانات عداد انتهاء الخط — نافذة شهرين (60 يوم) قبل الانتهاء.
  /// يرجّع null لو الخط بره النافذة (مفيش داعي للعرض).
  ({int days, Color color, Color bg, String label, bool critical})?
      _expiryInfo(AppProvider prov) {
    final days = prov.daysToExpiry(widget.group.id);
    if (days == null) return null;
    final expired = days < 0;
    if (!expired && days > 60) return null; // بره نافذة الشهرين
    final critical = !expired && days <= 5; // 🔴 أحمر فاقع آخر 5 أيام
    final urgent = !expired && days <= 15;

    final Color color;
    final Color bg;
    if (expired || critical) {
      color = AppColors.red;
      bg = AppColors.redLight;
    } else if (urgent) {
      color = AppColors.orange;
      bg = AppColors.orangeLight;
    } else {
      color = const Color(0xFFf57c00);
      bg = AppColors.orangeLight;
    }

    final label = expired
        ? '🔴 الخط منتهي'
        : days == 0
            ? '🔴 ينتهي النهاردة!'
            : critical
                ? '🔴 باقي $days يوم على الانتهاء'
                : '⏳ ينتهي خلال $days يوم';
    return (days: days, color: color, bg: bg, label: label, critical: critical);
  }

  Widget _buildExpiryBadge(AppProvider prov) {
    final info = _expiryInfo(prov);
    if (info == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: info.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: info.color
                  .withValues(alpha: info.critical ? 0.9 : 0.5),
              width: info.critical ? 1.5 : 1)),
      child: Text(info.label,
          style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: info.critical ? FontWeight.w900 : FontWeight.w800,
              color: info.color)),
    );
  }

  // ── Nearest Bill Badge — أقرب فاتورة شركة غير مدفوعة (موعد الدفع) ──
  // بره على الكارت بيبان أقرب فاتورة بس؛ التفاصيل الكاملة لكل فاتورة في شاشة الفواتير.
  Widget _buildNearestBillBadge(AppProvider prov) {
    final nearest = prov.nearestUnpaidBill(widget.group.id);
    if (nearest == null) return const SizedBox.shrink();
    final (bill, days) = nearest;
    final deadline = prov.billDeadlineDate(bill);
    if (deadline == null) return const SizedBox.shrink();
    final dd = '${deadline.day}/${deadline.month}';
    final over = days < 0;
    final urgent = !over && days <= 3;
    final bg = over
        ? const Color(0xFFFFEBEE)
        : (urgent ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9));
    final fg = over
        ? const Color(0xFFC62828)
        : (urgent ? const Color(0xFFE65100) : const Color(0xFF00695C));
    final label = over
        ? '🔴 فاتورة فات موعدها بـ ${-days} يوم'
        : (days == 0 ? '🟠 فاتورة آخر يوم دفع' : '🗓️ أقرب فاتورة: $dd ($days يوم)');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.cairo(
              fontSize: 10, fontWeight: FontWeight.w900, color: fg)),
    );
  }

  // ── Defer Badge — فاتورة مؤجَّلة لميعاد سماح ──────────────────
  Widget _buildDeferBadge(AppProvider prov) {
    final bill = prov.activeDeferredBill(widget.group.id);
    if (bill == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE65100), width: 1.2),
      ),
      child: Text('⏸ مؤجل لـ ${bill.deferDate}',
          style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFE65100))),
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
            pts > 0 ? '🏆 $value ج' : '🏆 0',
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
              decoration: BoxDecoration(
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
    final profit = prov.db.groupNetProfit(widget.group.id, prov.db.rentals);
    // يظهر لو فيه فاتورة ثابتة متكتوبة أو فاتورة فعلية أو مجموعة يدوية
    final show = widget.group.fixedBillAmount > 0 ||
        widget.group.actualBillAmount != null ||
        widget.group.type == 'manual';
    if (!show) return const SizedBox.shrink();
    final isPos = profit >= 0;
    return GestureDetector(
      onTap: () => _showProfitBreakdown(prov),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPos ? AppColors.greenLight : AppColors.redLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: (isPos ? AppColors.green : AppColors.red)
                  .withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${isPos ? "💰" : "📉"} ربح: ${profit.toStringAsFixed(0)} ج',
            style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isPos ? AppColors.green2 : AppColors.red2),
          ),
          const SizedBox(width: 3),
          Icon(Icons.info_outline,
              size: 11, color: isPos ? AppColors.green2 : AppColors.red2),
        ]),
      ),
    );
  }

  void _showProfitBreakdown(AppProvider prov) {
    final b = prov.db.groupProfitBreakdown(widget.group.id, prov.db.rentals);
    final hasFixed = (b['hasFixed'] ?? 0) == 1;
    final net = b['net'] ?? 0;
    String f(double? v) => (v ?? 0).toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            const Text('💰', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('تفصيل ربح المجموعة',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!hasFixed)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Text(
                    '⚠️ مفيش «فاتورة ثابتة» متكتوبة للخط — عشان كده ربح الاشتراكات = صفر. اكتبها من إعدادات الخط.',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: const Color(0xFFE65100))),
              ),
            _pRow('➕ إيرادات العملاء', f(b['income']), AppColors.green2),
            if (hasFixed)
              _pRow('➖ الفاتورة الثابتة', '−${f(b['fixedBill'])}', AppColors.red2),
            if (hasFixed && (b['extraFee'] ?? 0) > 0)
              _pRow('➖ عملاء زيادة', '−${f(b['extraFee'])}', AppColors.red2),
            if (hasFixed && (b['extraBundle'] ?? 0) > 0)
              _pRow('➖ باقات إضافية للشهر', '−${f(b['extraBundle'])}',
                  AppColors.red2),
            if ((b['points'] ?? 0) > 0)
              _pRow('➕ نقاط الشهر', '+${f(b['points'])}', AppColors.green2),
            if ((b['rental'] ?? 0) > 0)
              _pRow('➕ إيجار الخط الرئيسي', '+${f(b['rental'])}',
                  AppColors.green2),
            if ((b['gift'] ?? 0) > 0)
              _pRow('➕ هدايا الشهر', '+${f(b['gift'])}', AppColors.green2),
            const Divider(height: 18),
            _pRow('= صافي ربح المجموعة', '${f(net)} ج',
                net >= 0 ? AppColors.green2 : AppColors.red2,
                bold: true),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('تمام',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.cairo(
                  fontSize: bold ? 14 : 12.5,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
        ),
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: bold ? 15 : 13,
                fontWeight: FontWeight.w900,
                color: color)),
      ]),
    );
  }

  // ── Bill Badge ───────────────────────────────────────────────
  // ── 🧾 بادچ الفاتورة — بادچ واحدة بدل اتنين ────────────────────
  //
  // قبل كده كان فيه بادچين منفصلين بياخدوا سطر كامل:
  //   [💳 فاتورة: 3950 ج]   [🔴 فاتورة فات موعدها بـ 71 يوم]
  // دلوقتي بقت بادچ واحدة: «ف» + المبلغ + عدّاد ملوّن
  //   [ف 3950 ج │ 71- يوم]   أحمر = فات الميعاد
  //   [ف 3950 ج │ 5 يوم ]    أخضر = لسه في وقت
  Widget _buildBillBadge(BuildContext context, AppProvider prov, Group group) {
    final hasDebt = group.billDebt > 0;
    final amount = hasDebt ? group.billDebt : group.lastBillAmount;

    // العدّاد بتاع أقرب فاتورة مش مدفوعة
    final nearest = prov.nearestUnpaidBill(group.id);
    int? days;
    if (nearest != null && prov.billDeadlineDate(nearest.$1) != null) {
      days = nearest.$2;
    }
    final over = days != null && days < 0;
    final urgent = days != null && days >= 0 && days <= 3;

    // لون البادچ: الفلوس نفسها حمرا لو عليه مديونية
    final amtColor =
        hasDebt ? const Color(0xFFC62828) : const Color(0xFF6A1B9A);
    final bg = hasDebt ? const Color(0xFFFFEBEE) : const Color(0xFFF3E5F5);
    final bd = hasDebt ? const Color(0xFFEF9A9A) : const Color(0xFFCE93D8);
    // لون العدّاد: أحمر فات / برتقالي قرّب / أخضر لسه بدري
    final cntColor = over
        ? const Color(0xFFC62828)
        : (urgent ? const Color(0xFFE65100) : const Color(0xFF00695C));

    return GestureDetector(
      onTap: () => _showPayBillDialog(context, prov, group),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bd, width: over ? 1.6 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('ف',
              style: GoogleFonts.cairo(
                  fontSize: 13, fontWeight: FontWeight.w900, color: amtColor)),
          const SizedBox(width: 4),
          Text('${amount.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: 13, fontWeight: FontWeight.w900, color: amtColor)),
          if (days != null) ...[
            const SizedBox(width: 5),
            Container(
                width: 1, height: 13, color: bd.withValues(alpha: 0.8)),
            const SizedBox(width: 5),
            Icon(over ? Icons.error : Icons.schedule, size: 12, color: cntColor),
            const SizedBox(width: 2),
            Text(
              over ? '${-days} يوم' : (days == 0 ? 'النهارده' : '$days يوم'),
              style: GoogleFonts.cairo(
                  fontSize: 12, fontWeight: FontWeight.w900, color: cntColor),
            ),
          ],
        ]),
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
    // كل مجموعة أصلاً تحت رقم موبايل — فالبادچ ده زيادة للموبايل، نخفيه.
    if (lt == LineType.mobile) return const SizedBox.shrink();
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

  // ── Clients Badge — رقم واحد ملوّن ──────────────────────────────
  //   أخضر = لسه في السعة  |  أحمر = عدّى الحد (ده اللي بيدفع زيادة)
  //   العدد ده للعملاء العاديين بس — الأرضي/الهوم 4G مش داخلين فيه.
  Widget _buildClientsBadge(int count, [Group? g]) {
    final group = g ?? widget.group;
    final isExempt =
        group.lineType == LineType.home4g || group.lineType == LineType.adsl;
    // السعة: الحد المكتوب في المجموعة، وإلا سعة الباقة (7 للـ 4250 و5 للأصغر)
    final capRaw = group.maxClients ?? group.tierBaseCapacity;
    final cap = capRaw > 0 ? capRaw : null;
    final excess =
        (cap != null && !isExempt && count > cap) ? count - cap : 0;
    final hasExcess = excess > 0;
    // مفيش سعة متحدّدة؟ مانقدرش نقول أحمر ولا أخضر — نوضّح إنها ناقصة
    final unknown = cap == null && !isExempt;

    final c = hasExcess
        ? AppColors.red2
        : (unknown ? const Color(0xFFE65100) : const Color(0xFF2E7D32));
    final bg = hasExcess
        ? AppColors.redLight
        : (unknown ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9));
    final bd = hasExcess
        ? const Color(0xFFEF9A9A)
        : (unknown ? const Color(0xFFFFB74D) : const Color(0xFFA5D6A7));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bd, width: hasExcess ? 2 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people, size: 14, color: c),
        const SizedBox(width: 4),
        // الرقم كبير — دي الحاجة اللي بتتقري من بعيد
        Text('$count',
            style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: c,
                height: 1.2)),
        if (hasExcess) ...[
          const SizedBox(width: 3),
          Text('+$excess',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.red)),
        ] else if (unknown) ...[
          const SizedBox(width: 3),
          Text('؟',
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE65100))),
        ],
      ]),
    );
  }

  // ── ☎️/📶 علامة خط الزيادة — مكان ثابت وحجم كبير ──────────────────
  //
  // قبل كده كانت بادچ صغيرة جوّه صف البادچات (Wrap)، فكانت بتتنقل من سطر
  // لسطر حسب اللي قبلها وتضيع منك وانت بتقلّب. دلوقتي بقت **دايرة ثابتة
  // أول صف الرقم** — نفس المكان في كل كارت، وضِعف الحجم.
  Widget _buildExtraLineMark(int landline, int home4g, {double size = 34}) {
    // ⬛ الخانة محجوزة حتى لو مفيش خط زيادة — عشان رقم المجموعة يبدأ من
    //    **نفس النقطة بالظبط** في كل الكروت وماينطّش يمين وشمال.
    if (landline == 0 && home4g == 0) return SizedBox(width: size + 6);

    Widget mark(String emoji, int n, Color a, Color b) => Container(
          width: size,
          height: size,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [b, a],
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: a.withValues(alpha: 0.4),
                  blurRadius: 5,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: size * 0.5)),
              // العدد يبان بس لو أكتر من واحد
              if (n > 1)
                Positioned(
                  bottom: -1,
                  left: -1,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: a, width: 1.2),
                    ),
                    child: Text('$n',
                        style: GoogleFonts.cairo(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: a)),
                  ),
                ),
            ],
          ),
        );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (landline > 0)
        mark('☎️', landline, kExtraTealA, kExtraTealB),
      if (home4g > 0) mark('📶', home4g, kExtraCyanA, kExtraCyanB),
    ]);
  }

  // ── Cycle Label — مختصر «س1 / س2» بدل «سيكل 1» عشان ياخد مساحة أقل ──
  String _cycleLabel(Group group) => cycleShortLabel(group);

  // ── Badge helper ──────────────────────────────────────────────
  Widget _badge(String label, Color bg, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
            fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
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
    // قفل التعديل: الموظف مايقدرش يعدّل في مجموعة مش ضمن شغله (إلا بتغطية)
    if (!prov.canEditGroup(widget.group.id)) {
      AppSnackbar.show(ctx,
          '👁 عرض فقط — المجموعة دي مش ضمن شغلك. كلّم صاحب المحل يفعّلها لك.',
          background: AppColors.red);
      return;
    }
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
        final childCount = prov.db.groups
            .where((x) => x.parentGroupId == widget.group.id)
            .length;
        showDialog(
          context: ctx,
          builder: (_) => PinDialog(
            title: childCount > 0
                ? 'حذف ${widget.group.phone} (هيتفك $childCount خط تابع)'
                : 'حذف المجموعة ${widget.group.phone}',
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
