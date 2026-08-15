// lib/screens/company_invoices_audit_card.dart
// 🔍 كارت مراجعة الفاتورة — جزء من company_invoices_screen.dart.
// اتفصل عشان الملف كان 4366 سطر وبقى صعب يتقرا. الكود زي ما هو بالظبط.
part of 'company_invoices_screen.dart';

class _AuditCard extends StatefulWidget {
  final CompanyBill bill;
  final AppDB db;
  final AppProvider prov;
  final _Anomaly anomaly;

  const _AuditCard({
    required this.bill,
    required this.db,
    required this.prov,
    required this.anomaly,
  });

  @override
  State<_AuditCard> createState() => _AuditCardState();
}

class _AuditCardState extends State<_AuditCard> {
  bool _expanded = false;

  CompanyBill get b => widget.bill;
  AppDB get db => widget.db;
  AppProvider get prov => widget.prov;

  Color get _typeColor {
    if (b.isPaid) return AppColors.green;
    if (b.isActual) return const Color(0xFF2e7d32);
    return const Color(0xFF6a1b9a);
  }

  Color get _typeBg {
    if (b.isPaid) return AppColors.greenLight;
    if (b.isActual) return const Color(0xFFE8F5E9);
    return const Color(0xFFF3E5F5);
  }

  String get _typeLabel {
    if (b.isPaid) return '💰 مسددة';
    if (b.isActual) return '✅ فعلية';
    return '📊 تقديرية';
  }

  // فاتورة «منتظمة» = آخر 3 شهور فعلية للخط بنفس المبلغ تقريباً (مايتغيّرش)
  bool _isRegularLine() {
    final actuals = db.companyBills
        .where((x) => x.groupId == b.groupId && x.isActual && x.actualAmount > 0)
        .toList()
      ..sort((a, c) => c.month.compareTo(a.month));
    if (actuals.length < 3) return false;
    final recent = actuals.take(3).toList();
    final first = recent.first.actualAmount;
    return recent.every((x) => (x.actualAmount - first).abs() < 1);
  }

  @override
  Widget build(BuildContext context) {
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: '—'));
    final provColor =
        MainLine.providerColors[g.provider] ?? AppColors.blue;
    final provEmoji =
        MainLine.providerEmojis[g.provider] ?? '📡';
    final percent = b.actualAmount > 0
        ? (b.paidAmount / b.actualAmount).clamp(0.0, 1.0)
        : 0.0;

    // Comparison with prev month
    final prevM = _prevMonthOf(b.month);
    final CompanyBill? prev = db.companyBills
        .cast<CompanyBill?>()
        .firstWhere(
            (x) => x!.groupId == b.groupId && x.month == prevM,
            orElse: () => null);
    final delta = (prev != null && prev.actualAmount > 0)
        ? (b.actualAmount - prev.actualAmount) /
            prev.actualAmount *
            100
        : null;

    final hasAnomaly = widget.anomaly != _Anomaly.none;
    // الفاتورة التقديرية = بلون باهت (مجرد متوقّع للشهر الجاي، مالهاش تأثير على الربح)
    final isEstimated = !b.isActual && !b.isPaid;

    return Opacity(
      opacity: isEstimated ? 0.62 : 1.0,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isEstimated ? const Color(0xFFFAF6FC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasAnomaly
                ? const Color(0xFFe65100).withValues(alpha: 0.5)
                : AppColors.border,
            width: hasAnomaly ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.05),
              blurRadius: 8)
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main content ──────────────────────────────────
            GestureDetector(
              onTap: () =>
                  setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Top row: badges
                      Row(children: [
                        _badge(
                          '$provEmoji ${MainLine.providerNames[g.provider] ?? (g.provider ?? '?')}',
                          provColor.withValues(alpha: 0.12),
                          provColor,
                        ),
                        const SizedBox(width: 6),
                        _badge(
                            _typeLabel, _typeBg, _typeColor),
                        if (_isRegularLine()) ...[
                          const SizedBox(width: 6),
                          _badge('🔁 منتظمة', const Color(0xFFE3F2FD),
                              const Color(0xFF1565C0)),
                        ],
                        if (prov.accountOfGroup(g.id) != null) ...[
                          const SizedBox(width: 6),
                          _badge('🔗 ${prov.accountOfGroup(g.id)!.name}',
                              const Color(0xFFF3E5F5), const Color(0xFF6a1b9a)),
                        ],
                        if ((prov.groupBillingReliability(g.id) ?? 1) < 0.8) ...[
                          const SizedBox(width: 6),
                          _badge(
                              '⚠️ منتظم ${((prov.groupBillingReliability(g.id) ?? 0) * 100).toStringAsFixed(0)}%',
                              const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                        ],
                        const Spacer(),
                        if (hasAnomaly)
                          _anomalyBadge(widget.anomaly),
                        Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.muted),
                      ]),
                      const SizedBox(height: 6),
                      // Phone + owner + month
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.phone,
                                  style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w900,
                                      color: AppColors.blue2),
                                ),
                                if (g.ownerName != null)
                                  Text(g.ownerName!,
                                      style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          color:
                                              AppColors.muted)),
                              ]),
                        ),
                        // 📅 يوم النزول (١/٥) مش شهر التسجيل — ده اللي
                        // بتتكلم بيه، والفترة المغطّاة تحته في سطر لوحدها.
                        _badge(
                          '📅 ${db.billIssueLabel(b)}',
                          AppColors.blueLight,
                          AppColors.blue2,
                        ),
                      ]),
                      Builder(builder: (_) {
                        final covered = db.billCoveredPeriod(b);
                        if (covered.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '⏱ $covered'
                            '${db.groupIsMidCycle(g) ? '  •  سيكل ٢' : ''}',
                            style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted),
                          ),
                        );
                      }),
                      // ── Linked sub-lines (this bill covers them too) ──
                      LinkedLinesStrip(
                        db: db,
                        group: g,
                        onManage: () => _showUnlinkDialog(
                            context, LinkedLinesStrip.childrenOf(db, g.id)),
                      ),
                      const SizedBox(height: 6),
                      // Amounts row
                      Row(children: [
                        if (b.fixedAmount > 0) ...[
                          _infoChip(
                            'ثابت: ${b.fixedAmount.toStringAsFixed(0)} ج',
                            const Color(0xFFE8F5E9),
                            AppColors.green,
                          ),
                          const SizedBox(width: 6),
                        ],
                        _infoChip(
                          '${b.isActual ? 'فعلي' : 'تقدير'}: ${b.actualAmount.toStringAsFixed(0)} ج',
                          AppColors.blueLight,
                          AppColors.blue2,
                        ),
                        if (delta != null) ...[
                          const SizedBox(width: 6),
                          _deltaChip(delta),
                        ],
                      ]),
                      // Payment progress
                      if (!b.isPaid) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'مدفوع: ${b.paidAmount.toStringAsFixed(0)} ج',
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.green),
                            ),
                            Text(
                              'متبقي: ${b.remaining.toStringAsFixed(0)} ج',
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: AppColors.redLight,
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(AppColors.green),
                            minHeight: 5,
                          ),
                        ),
                      ],
                      if (b.isPaid)
                        Text(
                          '✅ تم السداد الكامل',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.green,
                              fontWeight: FontWeight.w700),
                        ),
                      if (b.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📝 ${b.note}',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.muted),
                        ),
                      ],
                      if (b.isActual && b.fixedAmount > 0) ...[
                        const SizedBox(height: 5),
                        _diffChip(),
                      ],
                      if (b.isDeferred) ...[
                        const SizedBox(height: 5),
                        _deferCountdownChip(),
                      ] else if (!b.isPaid) ...[
                        const SizedBox(height: 5),
                        _deadlineChip(),
                      ],
                    ]),
              ),
            ),
            // ── Anomaly details (expanded) ─────────────────────
            if (hasAnomaly && _expanded)
              _anomalyDetails(widget.anomaly, prev),
            // ── نظام فواتير الخط (ثابت / شهر وشهر) — للمراجعة فقط ──
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _billingSystemToggle(),
              ),
            // ── السعر الخام + أساس الربح (بندين منفصلين) ──────────
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _pricingBox(),
              ),
            // ── الدور: فاتت على مين والجاية على مين ───────────────
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _turnBox(),
              ),
            // ── سجل تعديلات المبلغ (لو اتصحح قبل كده) ────────────
            if (_expanded && b.editHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📜 سجل التعديلات',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
                      const SizedBox(height: 4),
                      for (final e in b.editHistory)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${e['date']}: ${(e['oldAmount'] as num).toStringAsFixed(0)} ← ${(e['newAmount'] as num).toStringAsFixed(0)} ج'
                            '${e['reason'] != null ? ' — ${e['reason']}' : ''}',
                            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // ── Actions ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                if (!b.isActual) ...[
                  Expanded(
                    flex: 4,
                    child: _actionBtn(
                      '✅ تأكيد الفاتورة الفعلية',
                      const Color(0xFF2e7d32),
                      const Color(0xFFE8F5E9),
                      () => _showConfirmDialog(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (b.isActual && !b.isPaid) ...[
                  Expanded(
                    flex: 3,
                    child: _actionBtn(
                      '💳 جزئي',
                      const Color(0xFFe65100),
                      const Color(0xFFFFF3E0),
                      () => _showPayDialog(context,
                          full: false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: _actionBtn(
                      '✅ كامل',
                      AppColors.green,
                      AppColors.greenLight,
                      () => _showPayDialog(context,
                          full: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (db.groups.any((g) => g.parentGroupId == b.groupId)) ...[
                  _splitBtn(context),
                  const SizedBox(width: 6),
                ],
                if (!b.isPaid) ...[
                  _deferBtn(context),
                  const SizedBox(width: 6),
                ],
                _editBtn(context),
                const SizedBox(width: 6),
                _linkBtn(context),
                const SizedBox(width: 6),
                _deleteBtn(context),
              ]),
            ),
            // ── Payment history (expanded) ─────────────────────
            if (_expanded && b.payments.isNotEmpty) ...[
              Divider(
                  height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سجل الدفعات',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blue2),
                      ),
                      const SizedBox(height: 4),
                      ...b.payments.map((p) => Padding(
                            padding: const EdgeInsets.only(
                                top: 3),
                            child: Row(children: [
                              Icon(
                                  Icons.check_circle_outline,
                                  size: 12,
                                  color: AppColors.green),
                              const SizedBox(width: 6),
                              if (p.note != null)
                                Expanded(
                                  child: Text(
                                    p.note!,
                                    style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        color: AppColors.muted),
                                  ),
                                ),
                              Text(
                                p.time != null && p.time!.isNotEmpty
                                    ? '${p.date} • ${p.time}'
                                    : p.date,
                                style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    color: AppColors.muted),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${p.amount.toStringAsFixed(0)} ج',
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.green),
                              ),
                            ]),
                          )),
                    ]),
              ),
            ],
          ]),
      ),
    );
  }

  Widget _badge(String txt, Color bg, Color textColor) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10,
                color: textColor,
                fontWeight: FontWeight.w800)),
      );

  Widget _infoChip(
          String txt, Color bg, Color textColor) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor)),
      );

  Widget _deltaChip(double delta) {
    final isUp = delta > 0;
    final color = isUp ? AppColors.red : AppColors.green;
    final bg =
        isUp ? AppColors.redLight : AppColors.greenLight;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            isUp
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 10,
            color: color),
        Text(
          '${delta.abs().toStringAsFixed(0)}%',
          style: GoogleFonts.cairo(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  // زرار اختيار نوع نظام الخط: ثابت / شهر وشهر — لمراجعة الفواتير فقط
  Widget _billingSystemToggle() {
    final groups = widget.db.groups;
    final idx = groups.indexWhere((x) => x.id == widget.bill.groupId);
    if (idx < 0) return const SizedBox.shrink();
    final g = groups[idx];
    final isBi = g.billingSystem == 'bimonthly';
    Widget opt(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.blue2 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? AppColors.blue2 : AppColors.border),
              ),
              child: Center(
                child: Text(label,
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColors.muted)),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🔄 نظام فواتير الخط (للمراجعة فقط):',
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.muted)),
        const SizedBox(height: 5),
        Row(children: [
          opt('📅 ثابت (كل شهر)', !isBi,
              () => widget.prov.setGroupBillingSystem(g.id, 'fixed')),
          const SizedBox(width: 6),
          opt('🔂 شهر وشهر', isBi,
              () => widget.prov.setGroupBillingSystem(g.id, 'bimonthly')),
        ]),
        // ── السيكل: هو اللي بيحدد الفاتورة بتغطي إيه ──────────
        // سيكل ١ بتنزل يوم ١ وبتغطي الشهر اللي فات كله.
        // سيكل ٢ بتنزل يوم ١٥ وبتغطي من ١٥ للـ ١٥.
        const SizedBox(height: 8),
        Text('📆 سيكل الخط:',
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.muted)),
        const SizedBox(height: 5),
        Row(children: [
          opt('١ — تنزل يوم ١', !db.groupIsMidCycle(g),
              () => widget.prov.setGroupBillingCycle(g.id, 'cycle1')),
          const SizedBox(width: 6),
          opt('٢ — تنزل يوم ١٥', db.groupIsMidCycle(g),
              () => widget.prov.setGroupBillingCycle(g.id, 'cycle2')),
        ]),
      ]),
    );
  }

  // ── 🔁 الدور: الفاتورة اللي فاتت كانت على مين والجاية على مين ──
  //
  // الحساب الواحد ممكن يكون فيه شقّين بيتبادلوا الفاتورة. البرنامج بيستنتج
  // الدور من تاريخ الفواتير، بس الاستنتاج بيغلط لو شهر عدّى من غير تسجيل.
  // عشان كده فيه تثبيت يدوي بيغلبه: تقول مرة «شهر ٨ على الشق الأول»
  // والباقي بالتبادل قدّام وورا لوحده.
  Widget _turnBox() {
    final acc = widget.prov.accountOfGroup(b.groupId);
    if (acc == null) return const SizedBox.shrink();

    final prevM = _prevMonthOf(b.month);
    final nextM = _nextMonthOf(b.month);
    final pinned = acc.turnPinMonth != null;

    Widget line(String label, String month, Color color) {
      final phones = widget.prov.turnLabelFor(b.groupId, month);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
            width: 78,
            child: Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
          ),
          Expanded(
            child: Text(phones.isEmpty ? '—' : phones,
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('🔁 الدور في حساب «${acc.name}»',
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE65100))),
          ),
          Text(pinned ? '📌 مثبّت' : '🤖 تلقائي',
              style: GoogleFonts.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted)),
        ]),
        const SizedBox(height: 4),
        line('اللي فاتت:', prevM, AppColors.muted),
        line('دي:', b.month, const Color(0xFFE65100)),
        line('الجاية:', nextM, const Color(0xFF1565C0)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showPinTurnDialog(context, acc),
              child: Text('📌 ثبّت الدور بإيدي',
                  style: GoogleFonts.cairo(
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
          if (pinned) ...[
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: () => widget.prov.clearAccountTurnPin(acc.id),
              child: Text('🤖 رجّعه تلقائي',
                  style: GoogleFonts.cairo(
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ]),
    );
  }

  void _showPinTurnDialog(BuildContext context, BillingAccount acc) {
    String names(List<String> ids) => ids
        .map((id) => db.groups
            .firstWhere((g) => g.id == id, orElse: () => Group(id: '', phone: ''))
            .phone)
        .where((p) => p.isNotEmpty)
        .join(' • ');

    void pin(bool isShiftA) {
      widget.prov.pinAccountTurn(acc.id, b.month, isShiftA);
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('📌 مين الدور عليه في ${_monthLabel(b.month)}؟',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختار مرة واحدة والبرنامج هيكمّل بالتبادل لوحده قدّام وورا — '
                'مش هتقعد تكتبه كل شهر.',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => pin(true),
                child: Text('الشق الأول: ${names(acc.shiftA)}',
                    style: GoogleFonts.cairo(
                        fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => pin(false),
                child: Text('الشق التاني: ${names(acc.shiftB)}',
                    style: GoogleFonts.cairo(
                        fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
          ],
        ),
      ),
    );
  }

  // ── 💰 التسعير: السعر الخام vs أساس الربح ─────────────────────
  //
  // ليه بندين مش بند واحد: فاتورة «شهر وشهر» بتنزل ٤٢٥٠ عشان هي بتغطي
  // شهرين. لو حسبنا الربح على الرقم ده، الشهر اللي فيه فاتورة يبان خسران
  // والشهر اللي بعده يبان مكسبان — وهو مش كده. فالخام للفلوس والمديونية،
  // وأساس الربح لتكلفة الشهر الواحد.
  Widget _pricingBox() {
    final idx = db.groups.indexWhere((x) => x.id == b.groupId);
    if (idx < 0) return const SizedBox.shrink();
    final g = db.groups[idx];

    Widget row(String icon, String label, String value, String hint,
        VoidCallback onTap, Color color) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted)),
                  Text(hint,
                      style: GoogleFonts.cairo(
                          fontSize: 9, color: AppColors.muted)),
                ],
              ),
            ),
            Text(value,
                style: GoogleFonts.cairo(
                    fontSize: 13, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 12, color: AppColors.muted),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC5E1A5)),
      ),
      child: Column(children: [
        row(
          '💰',
          'سعر فاتورة الشركة الخام',
          g.fixedBillAmount > 0 ? '${g.fixedBillAmount.toStringAsFixed(0)} ج' : '— اضغط',
          g.isBimonthly ? 'اللي بينزل كل شهرين' : 'اللي بينزل كل شهر',
          () => _editPricingDialog(context, g, raw: true),
          const Color(0xFF2E7D32),
        ),
        const Divider(height: 8),
        row(
          '📊',
          'أساس الربح (الشهر الواحد)',
          g.profitBillAmount != null
              ? '${g.profitBillAmount!.toStringAsFixed(0)} ج'
              : 'زي الخام',
          'الربح بيتحسب على الرقم ده بس',
          () => _editPricingDialog(context, g, raw: false),
          const Color(0xFF1565C0),
        ),
        // تنبيه: خط شهر وشهر والربح لسه بيتحسب على الفاتورة الكبيرة
        if (g.needsProfitBasis)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 12, color: Color(0xFFe65100)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    'الخط شهر وشهر والربح لسه بيتحسب على ${g.fixedBillAmount.toStringAsFixed(0)} ج — '
                    'اكتب أساس الربح عشان الأرقام تظبط.',
                    style: GoogleFonts.cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFe65100))),
              ),
            ]),
          ),
      ]),
    );
  }

  /// تعديل السعر الخام أو أساس الربح. [raw] = true للخام.
  void _editPricingDialog(BuildContext context, Group g, {required bool raw}) {
    final ctrl = TextEditingController(
      text: raw
          ? (g.fixedBillAmount > 0 ? g.fixedBillAmount.toStringAsFixed(0) : '')
          : (g.profitBillAmount?.toStringAsFixed(0) ?? ''),
    );
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(raw ? '💰 سعر فاتورة الشركة الخام' : '📊 أساس الربح',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                raw
                    ? 'الرقم اللي الشركة بتاخده فعلاً. ملوش دعوة بالربح خالص.'
                    : 'تكلفة الشهر الواحد اللي الربح بيتحسب عليها. سيبها فاضية '
                        'عشان ترجع تتحسب على السعر الخام.',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'المبلغ (ج)',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              // اقتراح ÷ ٢ للخطوط اللي شهر وشهر — اقتراح بس، مابيتطبّقش لوحده
              // لأن القسمة على ٢ مش قاعدة صحيحة في كل الخطوط.
              if (!raw && g.isBimonthly && g.fixedBillAmount > 0) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => ctrl.text =
                      g.suggestedProfitBasis.toStringAsFixed(0),
                  icon: const Icon(Icons.calculate, size: 16),
                  label: Text(
                      'اقتراح: ${g.fixedBillAmount.toStringAsFixed(0)} ÷ ٢ = '
                      '${g.suggestedProfitBasis.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                raw
                    ? '⚠️ التغيير بيسري على الفواتير الجاية. الفواتير المتسجّلة '
                        'محتفظة بأرقامها ومش هتتغيّر.'
                    : '⚠️ بيأثر على شاشة الأرباح بس — مايمسّش المديونية ولا '
                        'مبالغ الفواتير.',
                style: GoogleFonts.cairo(
                    fontSize: 10, color: const Color(0xFFe65100)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: () {
                final txt = ctrl.text.trim();
                final v = double.tryParse(txt);
                if (raw) {
                  if (v != null && v >= 0) widget.prov.setGroupFixedBill(g.id, v);
                } else {
                  // فاضية = ارجع للسعر الخام
                  widget.prov.setGroupProfitBill(g.id, txt.isEmpty ? null : v);
                }
                Navigator.pop(context);
              },
              child: Text('حفظ',
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _anomalyBadge(_Anomaly a) {
    final isDoubled = a == _Anomaly.doubled;
    final color = isDoubled
        ? const Color(0xFFc62828)
        : const Color(0xFFe65100);
    final txt = isDoubled
        ? '⚠️ مضاعفة'
        : a == _Anomaly.unexpectedBimonthly
            ? '🚨 شهر مفروض فاضي'
            : a == _Anomaly.sameMonthDuplicate
                ? '🚨 فاتورة مكررة'
                : '⚠️ تكرار';
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: color.withValues(alpha: 0.4))),
      child: Text(txt,
          style: GoogleFonts.cairo(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _anomalyDetails(_Anomaly a, CompanyBill? prev) {
    String msg;
    Color color;
    if (a == _Anomaly.doubled) {
      color = const Color(0xFFc62828);
      msg = 'تنبيه: الفاتورة (${b.actualAmount.toStringAsFixed(0)} ج) أكبر بكثير من '
          'الشهر الماضي${prev != null ? " (${prev.actualAmount.toStringAsFixed(0)} ج)" : ""}.'
          ' احتمال وجود خطأ أو تراكم فواتير من الشركة.';
    } else if (a == _Anomaly.unexpectedBimonthly) {
      color = const Color(0xFFc62828);
      msg = '🚨 الخط ده نظامه «شهر وشهر» والمفروض الشهر ده يكون ببلاش، '
          'بس نزلت فاتورة (${b.actualAmount.toStringAsFixed(0)} ج)! راجع حسابك مع الشركة فوراً.';
    } else if (a == _Anomaly.sameMonthDuplicate) {
      color = const Color(0xFFc62828);
      msg = '🚨 الخط ده عليه أكتر من فاتورة فعلية في نفس الشهر (${_monthLabel(b.month)})! '
          'ده غالباً تسجيل مكرر بالغلط — امسح الفاتورة الزيادة عشان متحاسبش الشركة مرتين.';
    } else {
      color = const Color(0xFFe65100);
      msg = 'تنبيه: نفس المبلغ (${b.actualAmount.toStringAsFixed(0)} ج) تكرر شهرين متتاليين.'
          ' تحقق من احتمال وجود فاتورة مكررة بالخطأ.';
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color.withValues(alpha: 0.3))),
      child: Text(msg,
          style: GoogleFonts.cairo(
              fontSize: 11,
              color: color.withValues(alpha: 0.9))),
    );
  }

  Widget _actionBtn(String label, Color color, Color bg,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: color.withValues(alpha: 0.5))),
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      );

  Widget _deleteBtn(BuildContext context) => GestureDetector(
        onTap: () => _confirmDelete(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.delete_outline,
              size: 14, color: AppColors.red),
        ),
      );

  // زرار تحكّم كامل: تعديل تاريخ النزول + تعديل المبلغ
  Widget _editBtn(BuildContext context) => GestureDetector(
        onTap: () => _showEditSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF90CAF9))),
          child: const Icon(Icons.edit_calendar_outlined,
              size: 14, color: Color(0xFF1565C0)),
        ),
      );

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text('🛠️ تحكّم في الفاتورة',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.blue2)),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.event, color: Color(0xFF6A1B9A)),
              title: Text('تعديل تاريخ نزول الفاتورة',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: Text('بيحسب منه آخر موعد دفع (التاريخ + سماح الشركة)',
                  style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
              onTap: () { Navigator.pop(context); _pickIssueDate(context); },
            ),
            if (b.isActual)
              ListTile(
                leading: const Icon(Icons.attach_money, color: Color(0xFF2E7D32)),
                title: Text('تعديل مبلغ الفاتورة',
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text('الحالي: ${b.actualAmount.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                onTap: () { Navigator.pop(context); _editAmountDialog(context); },
              ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF1565C0)),
              title: Text('سجل الخط الكامل (كل الفواتير)',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: Text('كل فواتير الخط بالشهور + الإجماليات',
                  style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
              onTap: () { Navigator.pop(context); _showLineHistory(context); },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickIssueDate(BuildContext context) async {
    final now = DateTime.now();
    DateTime? curParsed;
    final p = b.date.split('/');
    if (p.length == 3) {
      final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
      if (d != null && m != null && y != null) curParsed = DateTime(y, m, d);
    }
    final cur = curParsed ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      widget.prov.setBillIssueDate(b.id, '${picked.day}/${picked.month}/${picked.year}');
    }
  }

  void _editAmountDialog(BuildContext context) {
    final ctrl = TextEditingController(text: b.actualAmount.toStringAsFixed(0));
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تعديل مبلغ الفاتورة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'المبلغ الفعلي (ج)',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'سبب التعديل (اختياري)',
                  hintText: 'مثلاً: الرقم كان متسجل غلط',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  hintStyle: GoogleFonts.cairo(fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: () {
                final v = double.tryParse(ctrl.text.trim());
                if (v != null && v >= 0) {
                  widget.prov.editBillAmount(b.id, v, reason: reasonCtrl.text);
                }
                Navigator.pop(context);
              },
              child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // السجل الكامل لكل فواتير الخط بالشهور + إجماليات (للمراجعة مع الشركة)
  void _showLineHistory(BuildContext context) {
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: '—'));
    final bills = db.companyBills.where((x) => x.groupId == b.groupId).toList()
      ..sort((a, c) => c.month.compareTo(a.month));
    final totalActual = bills.fold<double>(0, (s, x) => s + x.actualAmount);
    final totalPaid = bills.fold<double>(0, (s, x) => s + x.paidAmount);
    final totalRemaining = bills.fold<double>(0, (s, x) => s + x.remaining);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Color(0xFFf5f7fa),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                const Icon(Icons.history, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سجل ${g.phone}',
                        style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
                        textDirection: TextDirection.ltr),
                    if (g.ownerName != null && g.ownerName!.isNotEmpty)
                      Text(g.ownerName!,
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
                Text('${bills.length} فاتورة',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            // إجماليات
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _histPill('إجمالي', totalActual, AppColors.blue2),
                _histPill('مدفوع', totalPaid, const Color(0xFF2E7D32)),
                _histPill('متبقّي', totalRemaining, AppColors.red2),
              ]),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                itemCount: bills.length,
                itemBuilder: (_, i) {
                  final x = bills[i];
                  final status = x.isPaid
                      ? ('مسددة', const Color(0xFF2E7D32), const Color(0xFFE8F5E9))
                      : (x.paidAmount > 0
                          ? ('جزئي', const Color(0xFFE65100), const Color(0xFFFFF3E0))
                          : (x.isActual
                              ? ('غير مسددة', AppColors.red2, AppColors.redLight)
                              : ('تقديرية', const Color(0xFF6A1B9A), const Color(0xFFF3E5F5))));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.surface, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(_monthLabel(x.month),
                            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.blue2)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${x.actualAmount.toStringAsFixed(0)} ج'
                            '${x.remaining > 0 ? '  •  متبقّي ${x.remaining.toStringAsFixed(0)}' : ''}',
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: status.$3, borderRadius: BorderRadius.circular(8)),
                        child: Text(status.$1,
                            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: status.$2)),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _histPill(String label, double v, Color c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${v.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: c)),
          Text(label, style: GoogleFonts.cairo(fontSize: 9, color: AppColors.muted)),
        ],
      );

  Widget _linkBtn(BuildContext context) => GestureDetector(
        onTap: () => _showLinkDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFCE93D8))),
          child: const Icon(Icons.add_link,
              size: 14, color: Color(0xFF6A1B9A)),
        ),
      );

  // عدّاد واحد واضح لكل فاتورة:
  // آخر موعد دفع = تاريخ نزول الفاتورة + سماح الشركة (مخزّن لكل شركة، قابل للتعديل).
  // كل فاتورة ليها عدّادها المستقل — لو فيه فاتورتين غير مدفوعتين كل واحدة بتبان بموعدها.
  Widget _deadlineChip() {
    final days = widget.prov.billGraceDaysLeft(b);
    final deadline = widget.prov.billDeadlineDate(b);
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: ''));
    final grace = widget.prov.graceForGroup(g);

    // مفيش تاريخ نزول → لمّح للمستخدم يحطّه (من زرار 🕐 تعديل التاريخ)
    if (days == null || deadline == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(8)),
        child: Text('🗓️ حدّد تاريخ نزول الفاتورة (زرار 🕐) لعرض الموعد',
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
      );
    }

    final dd = '${deadline.day}/${deadline.month}';
    final over = days < 0;
    final urgent = !over && days <= 3;
    final bg = over
        ? AppColors.redLight
        : (urgent ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9));
    final fg = over
        ? AppColors.red2
        : (urgent ? const Color(0xFFE65100) : const Color(0xFF2E7D32));
    final label = over
        ? '🔴 فات موعد الدفع بـ ${-days} يوم (كان $dd)'
        : (days == 0
            ? '🟠 النهارده آخر يوم دفع ($dd)'
            : '🗓️ آخر موعد دفع $dd — باقي $days يوم (سماح $grace)');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: GoogleFonts.cairo(
              fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  // مقارنة الفاتورة الفعلية بالمبلغ الثابت المرجعي (لاكتشاف الغلط/الزيادة)
  Widget _diffChip() {
    final diff = b.actualAmount - b.fixedAmount;
    final same = diff.abs() < 0.5;
    final over = diff > 0;
    final bg = same
        ? const Color(0xFFE8F5E9)
        : (over ? AppColors.redLight : const Color(0xFFFFF8E1));
    final fg = same
        ? const Color(0xFF2E7D32)
        : (over ? AppColors.red2 : const Color(0xFFE65100));
    final label = same
        ? '⚖️ مطابق للمتوقّع (${b.fixedAmount.toStringAsFixed(0)})'
        : over
            ? '🔺 أعلى من المتوقّع بـ ${diff.toStringAsFixed(0)} ج (المتوقّع ${b.fixedAmount.toStringAsFixed(0)})'
            : '🔻 أقل من المتوقّع بـ ${(-diff).toStringAsFixed(0)} ج';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: GoogleFonts.cairo(
              fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  // عدّاد تنازلي لميعاد سماح الفاتورة المؤجَّلة
  Widget _deferCountdownChip() {
    final d = DateTime.tryParse(b.deferDate ?? '');
    if (d == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final days = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    final late = days < 0;
    final urgent = !late && days <= 3;
    final bg = late ? AppColors.redLight : (urgent ? const Color(0xFFFFF3E0) : const Color(0xFFEDE7F6));
    final fg = late ? AppColors.red2 : (urgent ? const Color(0xFFE65100) : const Color(0xFF5E35B1));
    final label = late
        ? '⏰ تأخّر سداد المؤجَّلة من ${-days} يوم'
        : (days == 0 ? '⏰ آخر يوم للسداد المؤجَّل' : '⏰ مؤجَّلة — باقي $days يوم');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _splitBtn(BuildContext context) => GestureDetector(
        onTap: () => showModalBottomSheet(
          useRootNavigator: true,
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SplitBillSheet(parentId: b.groupId, prov: widget.prov),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA5D6A7))),
          child: const Icon(Icons.call_split, size: 14, color: Color(0xFF2E7D32)),
        ),
      );

  Widget _deferBtn(BuildContext context) => GestureDetector(
        onTap: () => _showDeferDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: b.isDeferred ? const Color(0xFFEDE7F6) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: b.isDeferred ? const Color(0xFF7E57C2) : AppColors.border)),
          child: Icon(Icons.schedule,
              size: 14, color: b.isDeferred ? const Color(0xFF5E35B1) : AppColors.muted),
        ),
      );

  // تأجيل سداد الفاتورة لميعاد سماح من خدمة العملاء + عدّاد تنازلي
  void _showDeferDialog(BuildContext context) {
    final noteCtrl = TextEditingController(text: b.deferNote ?? '');
    DateTime picked = (b.deferDate != null && b.deferDate!.isNotEmpty)
        ? (DateTime.tryParse(b.deferDate!) ?? DateTime.now().add(const Duration(days: 7)))
        : DateTime.now().add(const Duration(days: 7));
    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(builder: (dCtx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('⏰ تأجيل الفاتورة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF5E35B1))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('ميعاد السماح من خدمة العملاء — هيظهر عدّاد تنازلي على الفاتورة.',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: Color(0xFF5E35B1)),
              title: Text('مؤجَّلة حتى: ${picked.day}/${picked.month}/${picked.year}',
                  style: GoogleFonts.cairo(fontSize: 13)),
              onTap: () async {
                final d = await showDatePicker(context: dCtx, initialDate: picked,
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setLocal(() => picked = d);
              },
            ),
            TextField(controller: noteCtrl, style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(hintText: 'سبب التأجيل (اختياري)', hintStyle: GoogleFonts.cairo(fontSize: 12))),
          ]),
          actions: [
            if (b.isDeferred)
              TextButton(
                onPressed: () { widget.prov.deferCompanyBill(b.id, null); Navigator.pop(dCtx); },
                child: Text('إلغاء التأجيل', style: GoogleFonts.cairo(color: AppColors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(dCtx), child: Text('إغلاق', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E35B1)),
              onPressed: () {
                final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                widget.prov.deferCompanyBill(b.id, dateStr, note: noteCtrl.text.trim());
                Navigator.pop(dCtx);
              },
              child: Text('تأجيل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  // ضمّ خط فرعي لهذا الخط الرئيسي — الفاتورة تنزل عليه تلقائياً
  void _showLinkDialog(BuildContext context) {
    final parent = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: '—'));
    // مرشحون: خطوط من غير خط رئيسي + مش الخط ده نفسه + مش مربوطين بحد تاني
    final candidates = db.groups
        .where((g) =>
            g.id != parent.id &&
            (g.parentGroupId == null || g.parentGroupId!.isEmpty))
        .toList();
    String? selected;
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Text('🔗 ضمّ خط لـ ${parent.phone}',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 15),
                textDirection: TextDirection.rtl),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'الخط اللي تختاره هيتحسب فاتورته مع الخط الرئيسي ده. '
                      'لما تنزّل فاتورة على الخط الرئيسي هتنزل عليه تلقائياً.',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: const Color(0xFF6A1B9A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (candidates.isEmpty)
                    Text('مفيش خطوط متاحة للضمّ',
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: AppColors.muted))
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'اختر الخط الفرعي',
                        labelStyle:
                            GoogleFonts.cairo(fontSize: 13),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                      ),
                      items: candidates
                          .map((g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  '${g.phone}${g.ownerName != null ? " — ${g.ownerName}" : ""}',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12),
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setS(() => selected = v),
                    ),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء',
                      style: GoogleFonts.cairo())),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                onPressed: candidates.isEmpty || selected == null
                    ? null
                    : () {
                        prov.setGroupParent(selected!, parent.id);
                        Navigator.pop(context);
                      },
                child: Text('ضمّ الخط',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // فصل خط فرعي من الخط الرئيسي
  void _showUnlinkDialog(
      BuildContext context, List<Group> children) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text('🔗 الخطوط المضمومة',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${c.phone}${c.ownerName != null ? " — ${c.ownerName}" : ""}',
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          prov.setGroupParent(c.id, null);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: AppColors.redLight,
                              borderRadius:
                                  BorderRadius.circular(8)),
                          child: Text('فصل',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.red,
                                  fontWeight:
                                      FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    Text('تمام', style: GoogleFonts.cairo())),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────
  void _showConfirmDialog(BuildContext context) {
    final ctrl = TextEditingController(
        text: b.actualAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    // المتوقع: آخر فاتورة فعلية للشهر السابق، وإلا المبلغ الثابت، وإلا التقدير الحالي.
    final g = db.groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: ''));
    final prevM = _prevMonthOf(b.month);
    final CompanyBill? prevBill = db.companyBills.cast<CompanyBill?>().firstWhere(
        (x) => x!.groupId == b.groupId && x.month == prevM && x.isActual,
        orElse: () => null);
    final expected = (prevBill != null && prevBill.actualAmount > 0)
        ? prevBill.actualAmount
        : (g.fixedBillAmount > 0 ? g.fixedBillAmount : b.actualAmount);

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (context, setLocal) {
          final amount = double.tryParse(ctrl.text.trim()) ?? 0;
          final overage = expected > 0 && amount > expected + 0.5;
          final diff = amount - expected;
          final noteMissing = overage && noteCtrl.text.trim().isEmpty;
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Text('✅ تأكيد الفاتورة الفعلية',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 15)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── القيمة المتوقعة بخط باهت ──
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'المتوقع لهذا الشهر: ${expected.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('أدخل المبلغ الفعلي الوارد من الشركة',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.muted)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  labelText: 'المبلغ الفعلي (ج)',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              // ── تحذير الزيادة + ملاحظة إجبارية ──
              if (overage) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.5))),
                  child: Text(
                    '🔴 يوجد زيادة ${diff.toStringAsFixed(0)} ج عن المتوقع — راجع الشركة لمعرفة السبب، واكتب الملاحظة:',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.red),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  textDirection: TextDirection.rtl,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    labelText: 'سبب الزيادة / الملاحظة (إجباري)',
                    labelStyle: GoogleFonts.cairo(fontSize: 12),
                    errorText:
                        noteMissing ? 'لازم تكتب سبب الزيادة قبل التأكيد' : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo())),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: (amount <= 0 || noteMissing)
                    ? null
                    : () {
                        final note = noteCtrl.text.trim();
                        prov.confirmActualBill(b.id, amount);
                        // أرشفة دائمة (غير قابلة للحذف) على السيرفر + قيد نشاط
                        prov.recordLineInvoiceAudit(
                          groupId: b.groupId,
                          month: b.month,
                          expected: expected,
                          actual: amount,
                          hasOverage: overage,
                          note: note.isEmpty ? null : note,
                        );
                        Navigator.pop(context);
                      },
                child: Text('تأكيد',
                    style: GoogleFonts.cairo(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _showPayDialog(BuildContext context,
      {required bool full}) {
    final ctrl = TextEditingController(
        text: full ? b.remaining.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController();
    DateTime payDate = DateTime.now();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (dCtx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text(full ? '✅ سداد كامل' : '💳 سداد جزئي',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius:
                          BorderRadius.circular(10)),
                  child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المتبقي:',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.blue2)),
                        Text(
                          '${b.remaining.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.blue2),
                        ),
                      ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  readOnly: full,
                  decoration: InputDecoration(
                    labelText: 'المبلغ (ج)',
                    labelStyle:
                        GoogleFonts.cairo(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                    filled: full,
                    fillColor: full
                        ? const Color(0xFFf0f4f8)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'ملاحظة (رقم إيصال...)',
                    labelStyle:
                        GoogleFonts.cairo(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 4),
                // تاريخ الدفع (للدفع المنسي بتاريخ سابق)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.event, size: 18, color: AppColors.blue2),
                  title: Text('تاريخ الدفع: ${payDate.day}/${payDate.month}/${payDate.year}',
                      style: GoogleFonts.cairo(fontSize: 12)),
                  trailing: Text('غيّر', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue3)),
                  onTap: () async {
                    final d = await showDatePicker(context: dCtx, initialDate: payDate,
                        firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) setLocal(() => payDate = d);
                  },
                ),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: full
                      ? AppColors.green
                      : const Color(0xFFe65100),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10))),
              onPressed: () {
                final amount =
                    double.tryParse(ctrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                final ds = '${payDate.day}/${payDate.month}/${payDate.year}';
                prov.payCompanyBill(
                  b.id,
                  amount,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  payDate: ds,
                );
                Navigator.pop(context);
              },
              child: Text('تأكيد',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        )),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('حذف الفاتورة',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900)),
          content: Text(
              'سيتم حذف الفاتورة وعكس تأثيرها على المديونية.',
              style: GoogleFonts.cairo()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red),
              onPressed: () {
                prov.deleteCompanyBill(b.id);
                Navigator.pop(context);
              },
              child: Text('حذف',
                  style: GoogleFonts.cairo(
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Expected Bill Card (next month preview)
// ══════════════════════════════════════════════════════════════════════════════