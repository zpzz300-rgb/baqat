// lib/screens/company_invoices_cycle_sheets.dart
//
// 📋 الشيتات اللي بتتفتح من عروض الدورة:
//   • تعليم الدورة — «الفاتورة دي نزلت الشهر ده» مرة واحدة وخلاص.
//   • استثناء شهر — لما الشركة تغلط وتنزّل فاتورتين ورا بعض.
//   • مربع الفرق — المفروض ٥٠٠٠ ونزلت ٥٣٠٠، تسجّل الـ٣٠٠ عليهم.
//   • شرح الخانة — تدوس على أي مربع في الجدول يقول لك بالعربي هي إيه.
part of 'company_invoices_screen.dart';

class _CycleSheets {
  const _CycleSheets._();

  /// شرح خانة في الجدول/الأعمدة بالعامية + الأزرار اللي تصلّح بيها.
  static void explainCell(
    BuildContext context,
    AppProvider prov,
    Group head,
    String month,
    _CellState state,
    double expected,
    CompanyBill? bill,
  ) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CellSheet(
        prov: prov,
        head: head,
        month: month,
        state: state,
        expected: expected,
        bill: bill,
      ),
    );
  }

  /// شيت الخط الواحد: تعليم الدورة + استثناء الشهر.
  static void openLine(
      BuildContext context, AppProvider prov, Group line, String month) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LineCycleSheet(prov: prov, line: line, month: month),
    );
  }

  /// مربع الفرق على فاتورة — مطالبة على الشركة.
  static void openDispute(
      BuildContext context, AppProvider prov, CompanyBill bill) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DisputeSheet(prov: prov, bill: bill),
    );
  }

  /// اختيار أرقام الأرضي والهوم 4G اللي في الحساب ده.
  static void pickSideNumbers(
      BuildContext context, AppProvider prov, Group head) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SideNumbersSheet(prov: prov, head: head),
    );
  }

  /// 📊 تقرير الفروق: المتوقع مقابل الفعلي لكل حساب في الشهر.
  static void openDiffReport(
      BuildContext context, AppProvider prov, String month) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiffReportSheet(prov: prov, month: month),
    );
  }

  /// 📌 تعليم دورة كل خطوط الحساب في شاشة واحدة.
  static void anchorAll(BuildContext context, AppProvider prov, Group head,
      String month) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnchorAllSheet(prov: prov, head: head, month: month),
    );
  }

  /// 🌿 ضم الخطوط: علّم ✔ على اللي في نفس الحساب.
  /// 📥 استيراد الدورة من كشف الشركة — تلزق الكشف والبرنامج يعلّم.
  static void importCycle(
      BuildContext context, AppProvider prov, String month) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImportCycleSheet(prov: prov, month: month),
    );
  }

  /// 📋 نسخ دورة خط لخطوط تانية — بيرجّع **عدد** اللي اتغيّر فعلاً،
  /// أو null لو المستخدم قفل الشيت من غير ما ينسخ.
  static Future<int?> copyCycle(
      BuildContext context, AppProvider prov, Group src) {
    return showAppSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CopyCycleSheet(prov: prov, src: src),
    );
  }

  static void linkLines(BuildContext context, AppProvider prov, Group head) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LinkLinesSheet(prov: prov, head: head),
    );
  }

  /// 🔍 مراجعة كل الحسابات — بيانات الفوترة مظبوطة ولا في غلط.
  static void openAudit(BuildContext context, AppProvider prov, String month) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DataAuditSheet(prov: prov, month: month),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🔍 شيت مراجعة البيانات — «هي مظبوطة ولا في غلط؟»
// ══════════════════════════════════════════════════════════════════════════

class _DataAuditSheet extends StatefulWidget {
  const _DataAuditSheet({required this.prov, required this.month});

  final AppProvider prov;
  final String month;

  @override
  State<_DataAuditSheet> createState() => _DataAuditSheetState();
}

class _DataAuditSheetState extends State<_DataAuditSheet> {
  String _q = '';

  /// الخطوط المحدّدة للتصليح الجماعي. فاضية = مفيش وضع تحديد.
  ///
  /// لازمته: «صلّح الكل» بيشتغل على كل حاجة، وساعات انت عايز تصلّح
  /// عشرة من عشرين وسايب الباقي عن قصد. من غير التحديد كنت تفتح كل خط
  /// لوحده — عشرين مرة.
  final Set<String> _picked = {};

  /// نوع المشكلة المعروضة — null يعني الكل.
  String? _issue;

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final wide = context.isWide;
    final all = prov.linesWithBillIssues();
    final halved = all
        .where((g) =>
            prov.billIssuesOf(g).contains(AppProvider.kBillIssueHalved))
        .toList();
    final total = prov.db.groups.length;

    // 🔍 البحث والفلتر — لما تكون ٤٠ خط فيهم مشاكل، الشاشة بتبقى قايمة
    // طويلة وانت بتدوّر على خط معيّن بعينك. دول بيوصّلوك ليه على طول.
    final terms = searchTerms(_q);
    final bad = all.where((g) {
      if (_issue != null && !prov.billIssuesOf(g).contains(_issue)) {
        return false;
      }
      if (terms.isEmpty) return true;
      return searchHitsOf(terms, [g.phone, g.ownerName ?? '']) != null;
    }).toList();

    // أنواع المشاكل الموجودة فعلاً + عدد كل واحدة
    final issueCounts = <String, int>{};
    for (final g in all) {
      for (final i in prov.billIssuesOf(g)) {
        issueCounts[i] = (issueCounts[i] ?? 0) + 1;
      }
    }

    return _SheetShell(
      title: '🔍 مراجعة بيانات الفواتير',
      subtitle: bad.isEmpty
          ? 'راجعت $total خط — كلهم مظبوطين'
          : 'راجعت $total خط — ${bad.length} فيهم حاجة محتاجة نظرة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 📥 الاستيراد — أسرع طريقة تعلّم عشرات الخطوط مرة واحدة
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 11),
            side: BorderSide(color: AppColors.blue.withValues(alpha: 0.5)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            _CycleSheets.importCycle(context, prov, widget.month);
          },
          icon: Icon(Icons.download_outlined, size: 17, color: AppColors.blue2),
          label: Text('استورد الدورة من كشف الشركة',
              style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue2)),
        ),
        const SizedBox(height: 12),

        if (bad.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Icon(Icons.check_circle, size: 34, color: AppColors.green2),
              const SizedBox(height: 6),
              Text('كل الحسابات مظبوطة',
                  style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.green2)),
              Text(
                'كل خط شهر وشهر عليه سعر ومتعلّم عليه دورة، ومفيش رقم '
                'شكله نص فاتورة.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.green2),
              ),
            ]),
          )
        else ...[
          // ── زرار التصليح الجماعي للمنصّفين ──────────────────
          if (halved.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                borderRadius: BorderRadius.circular(11),
                border:
                    Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('⚠️ ${halved.length} خط رقمهم شكله نص الفاتورة',
                        style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.orange)),
                    const SizedBox(height: 3),
                    Text(
                      'دول اتسجّل فيهم نص الفاتورة في خانة السعر الخام، فقايمة '
                      'الفواتير بتتوقّع نص المبلغ اللي هينزل. التصليح بيرجّع '
                      'الخام لسعر الباقة وبيحط الرقم القديم في أساس الربح — '
                      'يعني الربح مش هيتغيّر ولا جنيه، اللي هيتصلّح هو '
                      'التوقّع بس.',
                      style: GoogleFonts.cairo(
                          fontSize: 10.5, color: AppColors.orange),
                    ),
                    const SizedBox(height: 9),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmFixAll(halved.length),
                      child: Text('صلّح الـ${halved.length} كلهم',
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.onAccent)),
                    ),
                  ]),
            ),
            const SizedBox(height: 14),
          ],

          // ── القايمة التفصيلية ───────────────────────────────
          Text('التفاصيل — دوس على أي خط تظبّطه',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          const SizedBox(height: 6),

          // 🔍 بحث بالرقم أو الاسم
          TextField(
            onChanged: (v) => setState(() => _q = v),
            style: GoogleFonts.cairo(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'دوّر على خط بالرقم أو الاسم…',
              hintStyle: GoogleFonts.cairo(fontSize: 11.5),
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 7),

          // 🏷 فلتر بنوع المشكلة — بتشتغل على نوع واحد لحد ما تخلص
          // بدل ما تنطّ بين أنواع مختلفة وتنسى فين وصلت.
          Wrap(spacing: 6, runSpacing: 6, children: [
            _IssueChip(
              label: 'الكل (${all.length})',
              active: _issue == null,
              onTap: () => setState(() => _issue = null),
            ),
            for (final e in issueCounts.entries)
              _IssueChip(
                label: '${_issueLabel(e.key)} (${e.value})',
                active: _issue == e.key,
                onTap: () =>
                    setState(() => _issue = _issue == e.key ? null : e.key),
              ),
          ]),
          const SizedBox(height: 9),

          if (bad.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                _q.isNotEmpty
                    ? 'مفيش خط بالاسم أو الرقم ده وسط اللي فيهم مشاكل'
                    : 'مفيش خط بالمشكلة دي',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              ),
            )
          else ...[
            // ── ✔ التحديد المتعدد ───────────────────────────
            Row(children: [
              TextButton(
                onPressed: () => setState(() {
                  // كله محدّد؟ يبقى الدوسة معناها «امسح». غير كده «حدّد
                  // اللي ظاهر» — اللي ظاهر بس، مش اللي مخفي بالفلتر.
                  final ids = bad.map((g) => g.id).toSet();
                  if (_picked.containsAll(ids)) {
                    _picked.removeAll(ids);
                  } else {
                    _picked.addAll(ids);
                  }
                }),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(
                    _picked.containsAll(bad.map((g) => g.id))
                        ? 'امسح التحديد'
                        : 'حدّد اللي ظاهر (${bad.length})',
                    style: GoogleFonts.cairo(
                        fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              if (_picked.isNotEmpty)
                Text('${_picked.length} محدّد',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.blue2)),
            ]),

            if (_picked.isNotEmpty) _bulkBar(prov),

            for (final g in bad)
              _AuditRow(
                prov: prov,
                group: g,
                month: widget.month,
                wide: wide,
                picked: _picked.contains(g.id),
                onPick: () => setState(() {
                  _picked.contains(g.id)
                      ? _picked.remove(g.id)
                      : _picked.add(g.id);
                }),
                onChanged: () => setState(() {}),
              ),
          ],
        ],
      ]),
    );
  }

  /// شريط الإجراءات على المحدّدين.
  ///
  /// كل زرار بيقول **على كام خط** هيشتغل — لأن مش كل المحدّدين عندهم
  /// نفس المشكلة، فـ«صلّح السعر» على ١٢ محدّد ممكن يمسّ ٥ بس.
  Widget _bulkBar(AppProvider prov) {
    final picked = prov.db.groups.where((g) => _picked.contains(g.id)).toList();
    final halved = picked
        .where((g) =>
            prov.billIssuesOf(g).contains(AppProvider.kBillIssueHalved))
        .toList();
    final noAnchor = picked
        .where((g) =>
            prov.billIssuesOf(g).contains(AppProvider.kBillIssueNoAnchor))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(spacing: 8, runSpacing: 6, children: [
        if (halved.isNotEmpty)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact),
            onPressed: () async {
              // 🛟 نفس حماية التصليح الجماعي — نسخة احتياطية الأول
              final backup = await prov.safetyBackup('اصلاح-محدّدين');
              var n = 0;
              for (final g in halved) {
                if (prov.fixHalvedRawPrice(g.id)) n++;
              }
              if (!mounted) return;
              setState(_picked.clear);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'اتصلّح $n خط — الربح زي ما هو\n'
                    '${backup != null ? '🛟 النسخة الاحتياطية اتاخدت' : '⚠️ ماقدرتش آخد نسخة'}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              ));
            },
            child: Text('صلّح السعر (${halved.length})',
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onAccent)),
          ),
        if (noAnchor.isNotEmpty)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green2,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact),
            onPressed: () => _pickAnchorFor(prov, noAnchor),
            child: Text('علّم بشهر (${noAnchor.length})',
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onAccent)),
          ),
        if (halved.isEmpty && noAnchor.isEmpty)
          Text('المحدّدين دول مشاكلهم محتاجة تظبيط يدوي',
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppColors.blue2)),
      ]),
    );
  }

  /// اختيار شهر واحد يتعلّم على كل المحدّدين.
  void _pickAnchorFor(AppProvider prov, List<Group> lines) {
    final months = _Cycle.months(_nextMonthOf(widget.month), 12);
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('آخر فاتورة نزلت لهم في شهر إيه؟',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          content: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in months)
                _IssueChip(
                  label: _Cycle.shortLabel(m),
                  active: false,
                  onTap: () {
                    prov.setAccountAnchors({
                      for (final g in lines) g.id: m,
                    });
                    Navigator.pop(context);
                    setState(_picked.clear);
                  },
                ),
            ]),
          ),
        ),
      ),
    );
  }

  /// اسم المشكلة بالعامية — نفس اللي مكتوب في سطر الخط عشان الفلتر
  /// واللي بيفلتره يتكلّموا بنفس اللغة.
  static String _issueLabel(String key) => switch (key) {
        AppProvider.kBillIssueHalved => 'رقم نص فاتورة',
        AppProvider.kBillIssueNoAmount => 'من غير سعر',
        AppProvider.kBillIssueNoAnchor => 'من غير علامة',
        _ => key,
      };

  void _confirmFixAll(int n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تصليح $n خط؟',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900, fontSize: 14)),
        content: Text(
          'كل خط فيهم: السعر الخام هيرجع سعر الباقة، والرقم القديم هيروح '
          'لأساس الربح.\n\n'
          '✅ الربح مش هيتغيّر ولا جنيه\n'
          '✅ الفواتير المتسجّلة زي ما هي\n'
          '🔁 اللي هيتغيّر: توقّع الشهور الجاية هيبقى صح\n\n'
          '🛟 وقبل ما يبدأ بياخد نسخة احتياطية من كل البيانات',
          style: GoogleFonts.cairo(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء',
                style: GoogleFonts.cairo(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () async {
              // 🛟 النسخة الاحتياطية الأول — التصليح ما يبدأش غير بعدها.
              final r = await widget.prov.fixAllHalvedRawPricesSafely();
              if (!mounted) return;
              final done = r.fixed;
              Navigator.pop(context);
              setState(() {});
              // 🔙 التراجع في نفس الرسالة — لو الفحص غلط في خط، ترجع
              // الكل بدوسة بدل ما تصلّحهم بإيدك واحد واحد.
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(seconds: 8),
                content: Text(
                    'اتصلّح $done خط — الربح زي ما هو\n'
                    '${r.backup != null ? '🛟 النسخة الاحتياطية اتاخدت' : '⚠️ ماقدرتش آخد نسخة احتياطية — التراجع لسه شغّال'}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                action: SnackBarAction(
                  label: 'تراجع',
                  onPressed: () {
                    final back = widget.prov.undoBulkFix();
                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('رجّعت $back خط زي ما كانوا',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ));
                  },
                ),
              ));
            },
            child: Text('صلّح',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, color: AppColors.onAccent)),
          ),
        ],
      ),
    );
  }
}

/// شريحة فلتر بنوع المشكلة.
class _IssueChip extends StatelessWidget {
  const _IssueChip(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.blue : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? AppColors.blue : AppColors.border),
          ),
          child: Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.onAccent : AppColors.text)),
        ),
      );
}

/// سطر خط في المراجعة: المشكلة بالعربي + زرار يفتح تظبيطه.
class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.prov,
    required this.group,
    required this.month,
    required this.wide,
    required this.onChanged,
    this.picked = false,
    this.onPick,
  });

  final AppProvider prov;
  final Group group;
  final String month;
  final bool wide;
  final VoidCallback onChanged;

  /// الخط ده محدّد للتصليح الجماعي؟
  final bool picked;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final issues = prov.billIssuesOf(group);
    final tier = prov.tierPriceOf(group);
    final halved = issues.contains(AppProvider.kBillIssueHalved);
    final color = halved ? AppColors.orange : AppColors.muted;

    final say = <String>[
      if (halved)
        'الخام ${group.fixedBillAmount.toStringAsFixed(0)} ج والباقة '
            '${tier!.toStringAsFixed(0)} ج — شكله نص الفاتورة',
      if (issues.contains(AppProvider.kBillIssueNoAmount))
        'مفيش سعر متسجّل — التوقّع هيفضل صفر',
      if (issues.contains(AppProvider.kBillIssueNoAnchor))
        'شهر وشهر ومش متعلّم عليه — مش عارفين دوره إمتى',
    ];

    return InkWell(
      onTap: () async {
        await showAppSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              _LineCycleSheet(prov: prov, line: group, month: month),
        );
        onChanged();
      },
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          // ✔ التحديد — مساحة دوسة مستقلة عن فتح الخط، عشان ما تفتحش
          // الشيت وانت بتحدّد بس.
          if (onPick != null)
            GestureDetector(
              onTap: onPick,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  picked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 21,
                  color: picked ? AppColors.blue : AppColors.muted,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.phone,
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 13 : 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
                for (final s in say)
                  Text('• $s',
                      style: GoogleFonts.cairo(fontSize: 10, color: color)),
              ],
            ),
          ),
          if (halved)
            GestureDetector(
              onTap: () {
                prov.fixHalvedRawPrice(group.id);
                onChanged();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('صلّح',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onAccent)),
              ),
            )
          else
            Icon(Icons.chevron_left, size: 17, color: AppColors.muted),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 📊 تقرير الفروق — المتوقع مقابل اللي نزل فعلاً
// ══════════════════════════════════════════════════════════════════════════

/// بيجاوب على «أنا دفعت زيادة كام؟» من غير ما تفتح كل فاتورة وتقارن بإيدك.
///
/// مرتّب بالأكبر فرقاً — لأن الفرق الكبير هو اللي يستاهل تكلّم الشركة عليه،
/// مش اللي فرقه ٥ جنيه.
class _DiffReportSheet extends StatelessWidget {
  const _DiffReportSheet({required this.prov, required this.month});

  final AppProvider prov;
  final String month;

  @override
  Widget build(BuildContext context) {
    final rows = prov.monthDiffReport(month);
    final wide = context.isWide;
    final over = rows.where((r) => r.diff > 0).fold<double>(0, (s, r) => s + r.diff);
    final under =
        rows.where((r) => r.diff < 0).fold<double>(0, (s, r) => s + r.diff);

    return _SheetShell(
      title: '📊 المتوقع مقابل الفعلي',
      subtitle: _monthLabel(month),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text('مفيش فواتير ولا توقّعات في الشهر ده',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
          )
        else ...[
          // ── الخلاصة ─────────────────────────────────────────
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: over > 0 ? AppColors.redLight : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Text('دفعت زيادة',
                      style: GoogleFonts.cairo(
                          fontSize: 10.5, color: AppColors.muted)),
                  Text('${over.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                          fontSize: wide ? 19 : 16,
                          fontWeight: FontWeight.w900,
                          color:
                              over > 0 ? AppColors.red2 : AppColors.muted)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: under < 0 ? AppColors.greenLight : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Text('دفعت أقل',
                      style: GoogleFonts.cairo(
                          fontSize: 10.5, color: AppColors.muted)),
                  Text('${under.abs().toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                          fontSize: wide ? 19 : 16,
                          fontWeight: FontWeight.w900,
                          color:
                              under < 0 ? AppColors.green2 : AppColors.muted)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          Text('الأكبر فرقاً الأول:',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          for (final r in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: r.diff.abs() < 1
                        ? AppColors.border
                        : (r.diff > 0 ? AppColors.red2 : AppColors.green2)
                            .withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.head.groupInvoiceName?.trim().isNotEmpty == true
                            ? r.head.groupInvoiceName!
                            : r.head.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                            fontSize: wide ? 12.5 : 11.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text),
                      ),
                      Text(
                        'متوقع ${r.expected.toStringAsFixed(0)} • '
                        'نزل ${r.actual.toStringAsFixed(0)}',
                        style: GoogleFonts.cairo(
                            fontSize: 9.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  r.diff.abs() < 1
                      ? '✓'
                      : '${r.diff > 0 ? '+' : ''}${r.diff.toStringAsFixed(0)}',
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 14 : 12.5,
                      fontWeight: FontWeight.w900,
                      color: r.diff.abs() < 1
                          ? AppColors.green2
                          : (r.diff > 0 ? AppColors.red2 : AppColors.green2)),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 📌 شيت التعليم الجماعي — كل خطوط الحساب في شاشة واحدة
// ══════════════════════════════════════════════════════════════════════════

/// الحساب اللي فيه ٣ خطوط كان بيتطلّب تفتح الشيت ٣ مرات. الشيت ده بيوريك
/// الخطوط كلها مع بعض، وقدام كل واحد شهر آخر فاتورة — تظبطهم وتحفظ مرة.
///
/// وبيوريك **الناتج** تحت على طول: فاتورة كل شهر من الشهور الجاية هتبقى
/// كام — عشان تتأكد إن التعليم طلع صح قبل ما تسيب الشاشة.
class _AnchorAllSheet extends StatefulWidget {
  const _AnchorAllSheet({
    required this.prov,
    required this.head,
    required this.month,
  });

  final AppProvider prov;
  final Group head;
  final String month;

  @override
  State<_AnchorAllSheet> createState() => _AnchorAllSheetState();
}

class _AnchorAllSheetState extends State<_AnchorAllSheet> {
  /// الشهر المختار لكل خط — بيبدأ باللي متعلّم، وإلا الاقتراح من الفواتير.
  late final Map<String, String> _picked = {
    for (final l in widget.prov.accountLines(widget.head.id))
      if (l.isBimonthly)
        l.id: l.effectiveBillAnchor ??
            widget.prov.suggestedAnchorFor(l.id) ??
            widget.month,
  };

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final wide = context.isWide;
    final lines = prov
        .accountLines(widget.head.id)
        .where((l) => l.isBimonthly)
        .toList();
    final choices = _Cycle.months(_nextMonthOf(widget.month), 12);

    // معاينة الناتج: مجموع اللي دورهم في كل شهر من الستة الجايين، محسوب
    // من الاختيار الحالي مش من المحفوظ — عشان تشوف الأثر قبل الحفظ.
    double previewFor(String m) {
      var total = 0.0;
      for (final l in prov.accountLines(widget.head.id)) {
        if (!l.isBimonthly) {
          total += l.fixedBillAmount;
          continue;
        }
        final anchor = _picked[l.id];
        if (anchor == null) continue;
        final gap = Group.monthsBetween(anchor, m);
        if (gap != null && gap.isEven) total += l.fixedBillAmount;
      }
      return total;
    }

    return _SheetShell(
      title: 'دورة كل خطوط الحساب',
      subtitle: '${lines.length} خط شهر وشهر — ظبّطهم مرة واحدة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Text('مفيش خطوط شهر وشهر في الحساب ده',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
          )
        else ...[
          for (final l in lines) ...[
            Row(children: [
              Expanded(
                child: Text('${l.phone}  •  ${l.fixedBillAmount.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 13 : 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
              ),
              if (!l.hasBillAnchor)
                Text('لسه ما اتعلّمش',
                    style: GoogleFonts.cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange)),
            ]),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final m in choices)
                  GestureDetector(
                    onTap: () => setState(() => _picked[l.id] = m),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: wide ? 11 : 8, vertical: wide ? 7 : 5),
                      decoration: BoxDecoration(
                        color: _picked[l.id] == m
                            ? AppColors.green2
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: _picked[l.id] == m
                                ? AppColors.green2
                                : AppColors.border),
                      ),
                      child: Text(
                        _Cycle.shortLabel(m),
                        style: GoogleFonts.cairo(
                            fontSize: wide ? 11 : 10,
                            fontWeight: FontWeight.w800,
                            color: _picked[l.id] == m
                                ? AppColors.onAccent
                                : AppColors.text),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
          ],

          // ── معاينة الناتج ─────────────────────────────────
          Text('يعني فاتورة الحساب هتبقى كده:',
              style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              for (final m in _Cycle.months(_Cycle.addMonths(widget.month, 5), 6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                      child: Text(_monthLabel(m),
                          style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                    ),
                    Builder(builder: (_) {
                      final v = previewFor(m);
                      return Text(
                        v > 0 ? '${v.toStringAsFixed(0)} ج' : 'مفيش فاتورة',
                        style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color:
                                v > 0 ? AppColors.green2 : AppColors.muted),
                      );
                    }),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green2,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: () {
              prov.setAccountAnchors(_picked);
              Navigator.pop(context);
            },
            child: Text('احفظ تعليم ${lines.length} خط',
                style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onAccent)),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🌿 شيت ضم الخطوط — علّم ✔ على اللي في نفس الحساب
// ══════════════════════════════════════════════════════════════════════════

class _LinkLinesSheet extends StatefulWidget {
  const _LinkLinesSheet({required this.prov, required this.head});

  final AppProvider prov;
  final Group head;

  @override
  State<_LinkLinesSheet> createState() => _LinkLinesSheetState();
}

class _LinkLinesSheetState extends State<_LinkLinesSheet> {
  late final Set<String> _picked = {
    ...widget.prov.db.groups
        .where((g) => g.parentGroupId == widget.head.id)
        .map((g) => g.id),
  };
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final head = widget.head;
    final wide = context.isWide;
    final all = prov.linkCandidatesFor(head.id);
    final q = normalizeArabic(_q);
    final shown = q.isEmpty
        ? all
        : all
            .where((g) =>
                normalizeArabic(g.phone).contains(q) ||
                normalizeArabic(g.ownerName ?? '').contains(q))
            .toList();

    // الإجمالي الخام للحساب بعد التعديل — عشان تشوف الفاتورة بتتجمّع إزاي
    final total = head.fixedBillAmount +
        all
            .where((g) => _picked.contains(g.id))
            .fold<double>(0, (s, g) => s + g.fixedBillAmount);

    return _SheetShell(
      title: 'الخطوط اللي في حساب واحد',
      subtitle: 'الخط الرئيسي: ${head.phone}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'علّم ✔ على الخطوط اللي بتنزل مع الخط ده في **فاتورة واحدة** من '
            'الشركة. بعدها قايمة الفواتير هتجمعهم تحت هيدر واحد، وفاتورة '
            'الشهر = مجموع اللي دورهم فيهم بس.',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2),
          ),
        ),
        const SizedBox(height: 10),

        // 💰 الإجمالي الخام — بيتحرك وانت بتعلّم
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Expanded(
              child: Text('${_picked.length + 1} خط في الحساب',
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 13 : 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
            ),
            Text('${total.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(
                    fontSize: wide ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue2)),
          ]),
        ),
        const SizedBox(height: 4),
        Text('ده الإجمالي الخام لو كلهم نزلوا في نفس الشهر — '
            'الفاتورة الفعلية بتحسب اللي دوره بس',
            style: GoogleFonts.cairo(fontSize: 9.5, color: AppColors.muted)),
        const SizedBox(height: 10),

        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: GoogleFonts.cairo(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'دوّر بالرقم أو الاسم…',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),

        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Text(
              'مفيش خطوط تانية ينفع تتضم هنا.\n'
              'الخط اللي مضموم على حساب تاني، أو ضامّ خطوط تحته، '
              'مابيظهرش في القايمة دي.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.muted),
            ),
          )
        else
          for (final g in shown)
            InkWell(
              onTap: () => setState(() {
                _picked.contains(g.id)
                    ? _picked.remove(g.id)
                    : _picked.add(g.id);
              }),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: wide ? 8 : 6),
                child: Row(children: [
                  Icon(
                    _picked.contains(g.id)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 22,
                    color: _picked.contains(g.id)
                        ? AppColors.green2
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.phone,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                                fontSize: wide ? 13 : 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text)),
                        Text(
                          '${g.ownerName?.trim().isNotEmpty == true ? '${g.ownerName} • ' : ''}'
                          '${g.isBimonthly ? 'شهر وشهر' : 'ثابت'}',
                          style: GoogleFonts.cairo(
                              fontSize: 10, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    g.fixedBillAmount > 0
                        ? '${g.fixedBillAmount.toStringAsFixed(0)} ج'
                        : 'مفيش سعر',
                    style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: g.fixedBillAmount > 0
                            ? AppColors.blue2
                            : AppColors.orange),
                  ),
                ]),
              ),
            ),
        const SizedBox(height: 14),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          onPressed: () {
            prov.setAccountLines(head.id, _picked.toList());
            Navigator.pop(context);
          },
          child: Text(
            _picked.isEmpty
                ? 'خليه خط لوحده'
                : 'اضمّ ${_picked.length} خط على الحساب',
            style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: AppColors.onAccent),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 📥 شيت استيراد الدورة من كشف الشركة
// ══════════════════════════════════════════════════════════════════════════

/// الشركة بتبعت كشف بالخطوط اللي نزلت عليها فواتير الشهر ده. بدل ما تفتح
/// كل خط وتعلّم عليه بإيدك، بتلزق الكشف هنا والبرنامج يطلّع الأرقام منه.
///
/// 🛡 مافيش حاجة بتتغيّر غير لما تشوف العدد وتدوس بنفسك — الشيت بيوري
/// **الأول** كام خط عرفهم وكام رقم مالقاهوش.
class _ImportCycleSheet extends StatefulWidget {
  const _ImportCycleSheet({required this.prov, required this.month});

  final AppProvider prov;
  final String month;

  @override
  State<_ImportCycleSheet> createState() => _ImportCycleSheetState();
}

class _ImportCycleSheetState extends State<_ImportCycleSheet> {
  final _ctrl = TextEditingController();
  late String _month = widget.month;
  List<Group> _found = const [];
  List<String> _unknown = const [];
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scan() {
    final r = widget.prov.matchPhonesInText(_ctrl.text);
    setState(() {
      _found = r.found;
      _unknown = r.unknown;
      _scanned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    // الخطوط «شهر وشهر» بس هي اللي ليها مرساة — الثابت بينزل كل شهر
    final usable = _found.where((g) => g.isBimonthly).toList();
    final fixedSkipped = _found.length - usable.length;

    return _SheetShell(
      title: 'استيراد الدورة من كشف الشركة',
      subtitle: 'الفواتير اللي نزلت في ${_monthLabel(_month)}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'الشركة بعتت لك كشف بالخطوط اللي نزلت عليها فواتير؟ '
            'انسخه كله والزقه تحت — البرنامج هيطلّع الأرقام منه ويعلّم '
            'إن فاتورتهم نزلت في الشهر اللي تختاره.\n\n'
            '📱 بيقرا الأرقام المكتوبة متلزقة (01001234567). الكلام اللي '
            'حواليها مش مهم.',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2),
          ),
        ),
        const SizedBox(height: 10),

        // الشهر اللي هنعلّم عليه
        Text('الفواتير دي بتاعة شهر إيه؟',
            style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in _Cycle.months(_nextMonthOf(widget.month), 8))
              GestureDetector(
                onTap: () => setState(() => _month = m),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        _month == m ? AppColors.green2 : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            _month == m ? AppColors.green2 : AppColors.border),
                  ),
                  child: Text(
                    _Cycle.shortLabel(m),
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _month == m
                            ? AppColors.onAccent
                            : AppColors.text),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _ctrl,
          maxLines: wide ? 8 : 5,
          onChanged: (_) {
            if (_scanned) setState(() => _scanned = false);
          },
          style: GoogleFonts.cairo(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'الزق الكشف هنا…',
            hintStyle: GoogleFonts.cairo(fontSize: 11.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _ctrl.text.trim().isEmpty ? null : _scan,
          icon: const Icon(Icons.search, size: 17),
          label: Text('دوّر على الأرقام',
              style: GoogleFonts.cairo(
                  fontSize: 12.5, fontWeight: FontWeight.w900)),
        ),

        if (_scanned) ...[
          const SizedBox(height: 12),
          // 👁 النتيجة قبل أي تغيير
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usable.isEmpty
                      ? 'مالقيتش ولا خط «شهر وشهر» في الكلام ده'
                      : 'لقيت ${usable.length} خط «شهر وشهر»',
                  style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: usable.isEmpty
                          ? AppColors.orange
                          : AppColors.green2),
                ),
                if (fixedSkipped > 0)
                  Text('و$fixedSkipped خط ثابت — دول بينزلوا كل شهر فمالهمش علامة',
                      style: GoogleFonts.cairo(
                          fontSize: 10.5, color: AppColors.muted)),
                if (_unknown.isNotEmpty)
                  Text('و${_unknown.length} رقم مش موجودين عندك في البرنامج',
                      style: GoogleFonts.cairo(
                          fontSize: 10.5, color: AppColors.orange)),
              ],
            ),
          ),

          if (usable.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 210),
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final g in usable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Icon(Icons.check_circle,
                            size: 15, color: AppColors.green2),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(g.phone,
                              textDirection: TextDirection.ltr,
                              style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text)),
                        ),
                        Text(
                          g.effectiveBillAnchor == null
                              ? 'مافيش علامة'
                              : 'كانت ${_Cycle.shortLabel(g.effectiveBillAnchor!)}',
                          style: GoogleFonts.cairo(
                              fontSize: 10, color: AppColors.muted),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
          ],

          if (_unknown.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('أرقام مش عندك: ${_unknown.take(12).join('، ')}'
                '${_unknown.length > 12 ? ' …' : ''}',
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(
                    fontSize: 10, color: AppColors.muted)),
          ],

          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  usable.isEmpty ? AppColors.border : AppColors.green2,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: usable.isEmpty
                ? null
                : () {
                    final n = widget.prov.applyImportedCycle(
                        usable.map((g) => g.id).toList(), _month);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          n == 0
                              ? 'كانوا معلّمين كده أصلاً — مفيش حاجة اتغيّرت'
                              : 'اتعلّم $n خط: فاتورتهم نزلت ${_monthLabel(_month)}',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ));
                  },
            child: Text(
              usable.isEmpty
                  ? 'مفيش خطوط تتعلّم'
                  : 'علّم ${usable.length} خط',
              style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onAccent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ده بيعلّم الدورة بس — مابيسجّلش فلوس ولا بيغيّر مبالغ.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 📋 شيت نسخ الدورة من خط لخطوط تانية
// ══════════════════════════════════════════════════════════════════════════

/// انت ظبّطت خط واحد صح، وعندك عشرين خط دورتهم نفس الدورة. بدل ما تفتح كل
/// واحد وتعلّم عليه، علّم ✔ عليهم هنا مرة واحدة.
///
/// الشيت بيوري لكل خط **دورته الحالية** جنب اسمه، وتحت خانة كل خط بيقول
/// «هيبقى: …» — عشان تشوف اللي هيتغيّر **قبل** ما تدوس، مش بعدها.
class _CopyCycleSheet extends StatefulWidget {
  const _CopyCycleSheet({required this.prov, required this.src});

  final AppProvider prov;
  final Group src;

  @override
  State<_CopyCycleSheet> createState() => _CopyCycleSheetState();
}

class _CopyCycleSheetState extends State<_CopyCycleSheet> {
  final Set<String> _picked = {};
  String _q = '';

  /// وصف الدورة بالعامية: «تنزل يوليو، أغسطس ببلاش» بدل أرقام مرساة.
  String _cycleWord(Group g) {
    final a = g.effectiveBillAnchor;
    if (a == null) return 'لسه ما اتعلّمش';
    final n = g.billCycleMonths;
    return '${_monthLabel(a)}${n == 2 ? '' : ' • كل $n'}';
  }

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final src = widget.src;
    final wide = context.isWide;
    final all = prov.cycleCopyCandidates(src.id);
    final q = normalizeArabic(_q);
    final shown = q.isEmpty
        ? all
        : all
            .where((g) =>
                normalizeArabic(g.phone).contains(q) ||
                normalizeArabic(g.ownerName ?? '').contains(q))
            .toList();
    final srcWord = _cycleWord(src);

    return _SheetShell(
      title: 'انسخ الدورة',
      subtitle: 'من الخط ${src.phone}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'الخطوط اللي تعلّم عليها ✔ هتنزل فواتيرها في **نفس شهور** الخط ده '
            '($srcWord).\n\n'
            '✅ اللي بينتقل: العلامة وطول الدورة\n'
            '🚫 اللي مابينتقلش: المبلغ، والاستثناءات بتاعة غلطات الشركة',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: GoogleFonts.cairo(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'دوّر بالرقم أو الاسم…',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 4),

        // ✔ الكل / مفيش — أسرع من عشرين دوسة
        if (all.isNotEmpty)
          Row(children: [
            TextButton(
              onPressed: () =>
                  setState(() => _picked.addAll(shown.map((g) => g.id))),
              child: Text('علّم الكل',
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue2)),
            ),
            if (_picked.isNotEmpty)
              TextButton(
                onPressed: () => setState(_picked.clear),
                child: Text('شيل التعليم',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.muted)),
              ),
          ]),

        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Text(
              'مفيش خطوط «شهر وشهر» تانية عندك تنسخ لها.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.muted),
            ),
          )
        else
          for (final g in shown)
            InkWell(
              onTap: () => setState(() {
                _picked.contains(g.id)
                    ? _picked.remove(g.id)
                    : _picked.add(g.id);
              }),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: wide ? 8 : 6),
                child: Row(children: [
                  Icon(
                    _picked.contains(g.id)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 22,
                    color: _picked.contains(g.id)
                        ? AppColors.green2
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.phone,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                                fontSize: wide ? 13 : 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text)),
                        Text(
                          '${g.ownerName?.trim().isNotEmpty == true ? '${g.ownerName} • ' : ''}'
                          'دلوقتي: ${_cycleWord(g)}',
                          style: GoogleFonts.cairo(
                              fontSize: 10, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  // 👁 اللي هيحصل للخط ده لو دوست — قبل ما تدوس
                  if (_picked.contains(g.id))
                    Text('هيبقى: $srcWord',
                        style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green2)),
                ]),
              ),
            ),
        const SizedBox(height: 14),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _picked.isEmpty ? AppColors.border : AppColors.blue,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          onPressed: _picked.isEmpty
              ? null
              : () {
                  final n = prov.copyCycleTo(src.id, _picked.toList());
                  Navigator.pop(context, n);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        n == 0
                            ? 'كانوا زي بعضهم أصلاً — مفيش حاجة اتغيّرت'
                            : 'اتنسخت الدورة لـ $n خط',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  ));
                },
          child: Text(
            _picked.isEmpty
                ? 'علّم على خطوط الأول'
                : 'انسخ لـ ${_picked.length} خط',
            style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: AppColors.onAccent),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ☎️ شيت اختيار أرقام الأرضي والهوم 4G
// ══════════════════════════════════════════════════════════════════════════

class _SideNumbersSheet extends StatefulWidget {
  const _SideNumbersSheet({required this.prov, required this.head});

  final AppProvider prov;
  final Group head;

  @override
  State<_SideNumbersSheet> createState() => _SideNumbersSheetState();
}

class _SideNumbersSheetState extends State<_SideNumbersSheet> {
  late final Set<String> _picked = {
    // لو لسه ما اخترتش حاجة، بنبدأ باقتراح الأرقام اللي أصلاً جوّه الحساب
    ...(widget.head.sideNumberIds.isEmpty
        ? widget.prov.suggestedSideNumberIds(widget.head.id)
        : widget.head.sideNumberIds),
  };
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = widget.prov.allSideNumbers;
    final q = normalizeArabic(_q);
    final shown = q.isEmpty
        ? all
        : all
            .where((m) =>
                normalizeArabic(m.name).contains(q) ||
                normalizeArabic(m.phone).contains(q))
            .toList();
    final wide = context.isWide;

    return _SheetShell(
      title: 'أرقام الأرضي والهوم 4G',
      subtitle: 'علّم صح على اللي في نفس حساب ${widget.head.phone}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'الأرقام دي بتنزل في نفس فاتورة الشركة. لما تعلّم عليها هنا، '
            'تلاقيها قدامك وانت بتراجع — لو الشركة قالت «الزيادة بسبب '
            'الأرضي» ما تروحش تدوّر عليه.',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: GoogleFonts.cairo(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'دوّر بالاسم أو الرقم…',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'مفيش أرقام أرضي ولا هوم 4G مضافة في البرنامج لسه',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
            ),
          )
        else
          for (final m in shown)
            InkWell(
              onTap: () => setState(() {
                _picked.contains(m.id) ? _picked.remove(m.id) : _picked.add(m.id);
              }),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: wide ? 8 : 6),
                child: Row(children: [
                  Icon(
                    _picked.contains(m.id)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 21,
                    color: _picked.contains(m.id)
                        ? AppColors.green2
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                            style: GoogleFonts.cairo(
                                fontSize: wide ? 13 : 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text)),
                        Text(m.phone,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                                fontSize: 10.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.type == 'landline' ? 'أرضي' : 'هوم 4G',
                      style: GoogleFonts.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted),
                    ),
                  ),
                ]),
              ),
            ),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          onPressed: () {
            widget.prov
                .setAccountSideNumbers(widget.head.id, _picked.toList());
            Navigator.pop(context);
          },
          child: Text(
            _picked.isEmpty
                ? 'من غير أرقام'
                : 'اربط ${_picked.length} رقم بالحساب',
            style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: AppColors.onAccent),
          ),
        ),
      ]),
    );
  }
}

/// غلاف موحّد لكل الشيتات — نفس الشكل والحواف.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            maxWidth: wide ? 620 : double.infinity,
          ),
          margin: wide ? const EdgeInsets.symmetric(horizontal: 40) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 17 : 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
                const SizedBox(height: 3),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 12.5 : 11, color: AppColors.muted)),
              ]),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                child: child,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 📖 شيت شرح الخانة
// ══════════════════════════════════════════════════════════════════════════

class _CellSheet extends StatelessWidget {
  const _CellSheet({
    required this.prov,
    required this.head,
    required this.month,
    required this.state,
    required this.expected,
    required this.bill,
  });

  final AppProvider prov;
  final Group head;
  final String month;
  final _CellState state;
  final double expected;
  final CompanyBill? bill;

  @override
  Widget build(BuildContext context) {
    final dueLines = prov.dueLinesOfAccount(head.id, month);
    final allLines = prov.accountLines(head.id);
    final wide = context.isWide;

    return _SheetShell(
      title: head.groupInvoiceName?.trim().isNotEmpty == true
          ? head.groupInvoiceName!
          : head.phone,
      subtitle: _monthLabel(month),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── الخلاصة بالعامية ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: state.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: state.fg.withValues(alpha: 0.4)),
          ),
          child: Column(children: [
            Text(expected <= 0 ? '٠' : '${expected.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(
                    fontSize: wide ? 30 : 26,
                    fontWeight: FontWeight.w900,
                    color: state.fg)),
            Text(state.say,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: wide ? 13 : 12,
                    fontWeight: FontWeight.w800,
                    color: state.fg)),
            if (bill != null) ...[
              const SizedBox(height: 4),
              Text('اللي نزل فعلاً: ${bill!.actualAmount.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: state.fg)),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // ── الحساب اتعمل إزاي ─────────────────────────────────
        Text('الرقم ده جه منين؟',
            style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        Text('دوس على أي خط تظبّط دورته',
            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
        const SizedBox(height: 6),
        // كل خط بيفتح دورته هو — مش الخط الأول بس، لأن كل خط في الحساب
        // ليه مرساة لوحده وهو ده أصل الفكرة.
        for (final l in allLines)
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _CycleSheets.openLine(context, prov, l, month);
            },
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(children: [
                Icon(
                  dueLines.contains(l)
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  size: 15,
                  color: dueLines.contains(l) ? AppColors.green2 : AppColors.muted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Row(children: [
                    Text(l.phone,
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    if (l.effectiveBillAnchor == null && l.isBimonthly) ...[
                      const SizedBox(width: 5),
                      Text('لسه ما اتعلّمش',
                          style: GoogleFonts.cairo(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange)),
                    ],
                  ]),
                ),
                Text(
                  dueLines.contains(l)
                      ? '+ ${l.fixedBillAmount.toStringAsFixed(0)}'
                      : 'ببلاش',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color:
                          dueLines.contains(l) ? AppColors.green2 : AppColors.muted),
                ),
                const SizedBox(width: 3),
                Icon(Icons.chevron_left, size: 15, color: AppColors.muted),
              ]),
            ),
          ),
        const Divider(height: 20),

        if (bill != null)
          _SheetButton(
            icon: Icons.receipt_long,
            label: bill!.hasOpenDispute
                ? 'المطالبة: ${bill!.disputeAmount.toStringAsFixed(0)} ج'
                : 'الشركة نزّلت زيادة؟ سجّل الفرق',
            hint: 'المفروض كذا ونزلت كذا — يفضل مسجّل لحد ما يتحل',
            color: AppColors.red2,
            onTap: () {
              Navigator.pop(context);
              _CycleSheets.openDispute(context, prov, bill!);
            },
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🔁 شيت دورة الخط — التعليم مرة واحدة + استثناء الشهر
// ══════════════════════════════════════════════════════════════════════════

class _LineCycleSheet extends StatefulWidget {
  const _LineCycleSheet({
    required this.prov,
    required this.line,
    required this.month,
  });

  final AppProvider prov;
  final Group line;
  final String month;

  @override
  State<_LineCycleSheet> createState() => _LineCycleSheetState();
}

class _LineCycleSheetState extends State<_LineCycleSheet> {
  late String _selected = widget.line.effectiveBillAnchor ?? widget.month;

  /// 💰 الفاتورة بتنزل بكام — السعر الخام اللي الشركة بتاخده.
  /// كان مدفون في شاشة تعديل المجموعة، فبقى هنا جنب التعليم عشان
  /// «الرقم والعلامة» يبقوا في مكان واحد زي ما المفروض.
  late final _amountCtrl = TextEditingController(
      text: widget.line.fixedBillAmount > 0
          ? widget.line.fixedBillAmount.toStringAsFixed(0)
          : '');

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Group get _g =>
      widget.prov.db.groups.firstWhere((g) => g.id == widget.line.id,
          orElse: () => widget.line);

  /// حفظ السعر الخام.
  ///
  /// **للخطوط «شهر وشهر» بس** بنثبّت أساس الربح على الرقم القديم قبل ما
  /// نغيّر الخام، عشان تصليح رقم منصّف (٢٢٥٠ → ٤٢٥٠) ما يضاعفش التكلفة
  /// في حسابات الربح.
  ///
  /// ⚠️ الخط **الثابت** مالوش التثبيت ده: عنده الخام هو نفسه أساس الربح،
  /// فلو ثبّتناه كنت تعدّل ١١٥٠ → ١٢٥٠ ويفضل الربح محسوب على ١١٥٠ للأبد.
  /// 📋 يفتح اختيار الخطوط اللي هتاخد نفس الدورة.
  Future<void> _openCopyCycle(Group g) async {
    // الشيت هو اللي بيعرض رسالة النتيجة — هنا بنحدّث الشاشة بس.
    await _CycleSheets.copyCycle(context, widget.prov, g);
    if (mounted) setState(() {});
  }

  void _saveAmount() {
    final v = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final g = _g;
    if (v <= 0 || v == g.fixedBillAmount) return;
    if (g.isBimonthly && g.profitBillAmount == null && g.fixedBillAmount > 0) {
      widget.prov.setGroupProfitBill(g.id, g.fixedBillAmount);
    }
    widget.prov.setGroupFixedBill(g.id, v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final wide = context.isWide;
    // ١٢ شهر حوالين الشهر المعروض — تختار منهم شهر نزلت فيه فاتورة
    final choices = _Cycle.months(_nextMonthOf(widget.month), 12);
    // الستة شهور الجاية ابتداءً من الشهر المعروض — معاينة تطمّنك إن
    // التعليم طلع صح قبل ما تسيب الشيت.
    final next6 = _Cycle.months(_Cycle.addMonths(widget.month, 5), 6);

    return _SheetShell(
      title: 'دورة الخط ${g.phone}',
      subtitle: g.isBimonthly
          ? 'شهر وشهر — علّم مرة واحدة والباقي يمشي لوحده'
          : 'الخط ده ثابت — بينزل كل شهر',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── 💰 الرقم ──────────────────────────────────────────
        _AmountBox(
          prov: widget.prov,
          group: g,
          controller: _amountCtrl,
          onSave: _saveAmount,
        ),
        const Divider(height: 24),

        if (!g.isBimonthly) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'الخط ده نظامه ثابت: بينزل ${g.fixedBillAmount.toStringAsFixed(0)} ج '
              'كل شهر، فمفيش دورة يتعلّم عليها. لو غلط، غيّر نظامه من كارت الفاتورة.',
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.blue2),
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          // ── التعليم ───────────────────────────────────────
          Text('٢) آخر فاتورة نزلت للخط ده في شهر إيه؟',
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          Text('اختار الشهر مرة واحدة بس — البرنامج هيكمّل بالتبادل لوحده',
              style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted)),

          // 🔁 طول الدورة — معظم الخطوط «شهر وشهر»، بس في عروض دورتها
          // ٣ شهور أو ٤. بيبان بس لو الخط مش على الافتراضي، أو تدوس تغيّره.
          const SizedBox(height: 7),
          Row(children: [
            Text('كل كام شهر؟',
                style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
            const SizedBox(width: 8),
            for (final n in const [2, 3, 4]) ...[
              GestureDetector(
                onTap: () {
                  widget.prov.setBillCycleMonths(g.id, n);
                  setState(() {});
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: g.billCycleMonths == n
                        ? AppColors.blue
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: g.billCycleMonths == n
                            ? AppColors.blue
                            : AppColors.border),
                  ),
                  child: Text(
                    n == 2 ? 'شهر وشهر' : 'كل $n',
                    style: GoogleFonts.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: g.billCycleMonths == n
                            ? AppColors.onAccent
                            : AppColors.text),
                  ),
                ),
              ),
            ],
          ]),

          // 💡 اقتراح من تاريخ الفواتير المسجّلة — مالكش لازمة تدوّر في ورق
          // طالما البرنامج شايف آخر فاتورة نزلت إمتى فعلاً.
          Builder(builder: (_) {
            final sug = widget.prov.suggestedAnchorFor(g.id);
            if (sug == null || sug == g.billAnchorMonth) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () {
                  setState(() => _selected = sug);
                  widget.prov.setBillAnchor(g.id, sug);
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: AppColors.green2.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline,
                        size: 15, color: AppColors.green2),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'آخر فاتورة مسجّلة عندك للخط ده في '
                        '${_monthLabel(sug)} — دوس تستخدمها',
                        style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green2),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in choices)
                GestureDetector(
                  onTap: () => setState(() => _selected = m),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: wide ? 14 : 10, vertical: wide ? 9 : 7),
                    decoration: BoxDecoration(
                      color: _selected == m ? AppColors.green2 : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _selected == m ? AppColors.green2 : AppColors.border),
                    ),
                    child: Text(
                      _Cycle.shortLabel(m),
                      style: GoogleFonts.cairo(
                          fontSize: wide ? 12.5 : 11,
                          fontWeight: FontWeight.w800,
                          color: _selected == m ? AppColors.onAccent : AppColors.text),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  widget.prov.setBillAnchor(g.id, _selected);
                  setState(() {});
                },
                icon: const Icon(Icons.check, size: 17, color: AppColors.onAccent),
                label: Text('احفظ التعليم',
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onAccent)),
              ),
            ),
            if (g.hasBillAnchor) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  widget.prov.setBillAnchor(g.id, null);
                  setState(() {});
                },
                child: Text('شيل التعليم',
                    style: GoogleFonts.cairo(
                        fontSize: 11.5, color: AppColors.muted)),
              ),
            ],
          ]),

          // ── 📋 نسخ الدورة لخطوط تانية ─────────────────────
          // معظم الخطوط اللي اتفتحت مع بعض دورتها واحدة. من غير ده تفضل
          // تعلّم عشرين خط واحد واحد بنفس الشهر — وأول ما تغلط في واحد
          // منهم يبقى في خط شغّال بالعكس ومش هتاخد بالك.
          if (g.effectiveBillAnchor != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openCopyCycle(g),
              icon: Icon(Icons.copy_all, size: 16, color: AppColors.blue2),
              label: Text('انسخ الدورة دي لخطوط تانية',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue2)),
            ),
          ],

          // ── المعاينة: الشهور الجاية ───────────────────────
          // بتظهر سواء علّمت بإيدك أو الدورة اتاخدت من تاريخ المجموعة.
          if (g.effectiveBillAnchor != null) ...[
            if (g.anchorFromGroupDate) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'الدورة دلوقتي متاخدة من «تاريخ آخر فاتورة نزلت» اللي '
                  'كاتبه في تعديل المجموعة. لو تعلّم هنا، التعليم ده هو '
                  'اللي هيمشي.',
                  style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.blue2),
                ),
              ),
            ],
            // 📋 نسخ الدورة — لما تكون ظبّطت خط وعندك عشرة زيه بالظبط،
            // ما تفضلش تعلّم على كل واحد لوحده.
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: BorderSide(color: AppColors.blue.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await _CycleSheets.copyCycle(context, widget.prov, g);
                if (mounted) setState(() {});
              },
              icon: Icon(Icons.copy_all, size: 16, color: AppColors.blue2),
              label: Text('انسخ الدورة دي لخطوط تانية',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue2)),
            ),

            const SizedBox(height: 14),
            Text('يعني الجاي كده:',
                style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                for (final m in next6)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        child: Text(_monthLabel(m),
                            style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                      ),
                      Text(
                        widget.prov.isLineDueIn(g, m)
                            ? 'تنزل ${g.fixedBillAmount.toStringAsFixed(0)} ج'
                            : 'ببلاش',
                        style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: widget.prov.isLineDueIn(g, m)
                                ? AppColors.green2
                                : AppColors.muted),
                      ),
                    ]),
                  ),
              ]),
            ),
          ],
        ],

        const Divider(height: 24),

        // ── 🛑 قفل الخط ───────────────────────────────────────
        // من غير ده، الخط اللي وقف يفضل طالع في القايمة وانت بتدوّر على
        // فاتورته كل شهر ومش لاقيها — فتفتكر إن في فاتورة ضايعة.
        _ClosedLineBox(
          prov: widget.prov,
          group: g,
          month: widget.month,
          onChanged: () => setState(() {}),
        ),

        const Divider(height: 24),

        // ── الاستثناء (غلطات الشركة) ─────────────────────────
        Text('٣) الشركة غلطت في ${_monthLabel(widget.month)}؟',
            style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        Text(
          'لو نزّلوا فاتورتين ورا بعض أو قالوا «هنعوضك الشهر الجاي ببلاش» — '
          'علّم الشهر ده استثناء. الدورة الأصلية هترجع لوحدها بعده.',
          style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _OverrideChip(
              label: 'نزلت غصب عني',
              active: g.billMonthOverrides[widget.month] == 'billed',
              color: AppColors.orange,
              onTap: () {
                widget.prov.setBillMonthOverride(
                    g.id,
                    widget.month,
                    g.billMonthOverrides[widget.month] == 'billed' ? null : 'billed');
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OverrideChip(
              label: 'ببلاش تعويض',
              active: g.billMonthOverrides[widget.month] == 'free',
              color: AppColors.green2,
              onTap: () {
                widget.prov.setBillMonthOverride(
                    g.id,
                    widget.month,
                    g.billMonthOverrides[widget.month] == 'free' ? null : 'free');
                setState(() {});
              },
            ),
          ),
        ]),
        if (g.billMonthOverrides.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('الشهور المعدّلة بإيدك:',
              style: GoogleFonts.cairo(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final e in g.billMonthOverrides.entries)
                GestureDetector(
                  onTap: () {
                    widget.prov.setBillMonthOverride(g.id, e.key, null);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.orangeLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_Cycle.shortLabel(e.key)}: '
                      '${e.value == 'billed' ? 'نزلت' : 'ببلاش'} ✕',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ]),
    );
  }
}

/// 🛑 خانة «الخط ده وقف» — آخر شهر نزلت فيه فاتورة.
///
/// لما خط يتقفل من الشركة، لو ماقولناش للبرنامج كده هيفضل يعدّه في تقدير كل
/// شهر جاي، وانت هتفضل تدوّر على فاتورة عمرها ما هتيجي وتفتكر إنها ضايعة.
///
/// الشهر اللي بتختاره هو **آخر شهر نزلت فيه فاتورة فعلاً** — اللي بعده هو
/// اللي بيقف. والفواتير القديمة كلها بتفضل زي ما هي.
class _ClosedLineBox extends StatelessWidget {
  const _ClosedLineBox({
    required this.prov,
    required this.group,
    required this.month,
    required this.onChanged,
  });

  final AppProvider prov;
  final Group group;
  final String month;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final closed = group.billEndMonth != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('٤) الخط ده وقف خلاص؟',
                  style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text)),
              Text(
                closed
                    ? 'آخر فاتورة كانت ${_monthLabel(group.billEndMonth!)} — '
                        'اللي بعدها البرنامج بيقول «مفيش فاتورة»'
                    : 'لو الشركة قفلت الخط، علّم آخر شهر نزلت فيه فاتورة',
                style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    color: closed ? AppColors.orange : AppColors.muted),
              ),
            ],
          ),
        ),
        Switch(
          value: closed,
          activeThumbColor: AppColors.orange,
          onChanged: (v) {
            prov.setBillEndMonth(group.id, v ? month : null);
            onChanged();
          },
        ),
      ]),
      if (closed) ...[
        const SizedBox(height: 8),
        Text('آخر شهر نزلت فيه فاتورة:',
            style: GoogleFonts.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.muted)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in _Cycle.months(_nextMonthOf(month), 12))
              GestureDetector(
                onTap: () {
                  prov.setBillEndMonth(group.id, m);
                  onChanged();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: group.billEndMonth == m
                        ? AppColors.orange
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: group.billEndMonth == m
                            ? AppColors.orange
                            : AppColors.border),
                  ),
                  child: Text(
                    _Cycle.shortLabel(m),
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: group.billEndMonth == m
                            ? AppColors.onAccent
                            : AppColors.text),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.orangeLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'الفواتير القديمة كلها زي ما هي — مفيش حاجة اتمسحت. '
            'لو الشركة نزّلت فاتورة على الخط بعد الشهر ده، علّمها '
            '«نزلت غصب عني» وهتبان.',
            style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.orange),
          ),
        ),
      ],
    ]);
  }
}

/// 💰 خانة «الفاتورة بتنزل بكام» — السعر الخام اللي الشركة بتاخده.
///
/// موجودة هنا جنب التعليم عن قصد: الخط ليه حاجتين بس — **رقم** و**علامة** —
/// وماكانش ليه لازمة إن الرقم يبقى مدفون في شاشة تعديل تانية بينما العلامة
/// هنا. الرقم ده هو اللي قايمة الفواتير بتجمع بيه.
///
/// ⚠️ مش أساس الربح. أساس الربح (نص الفاتورة للخطوط شهر وشهر) رقم تاني
/// مستقل، والكتابة هنا مابتلمسهوش.
class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.prov,
    required this.group,
    required this.controller,
    required this.onSave,
  });

  final AppProvider prov;
  final Group group;
  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final tier = kLineTypePrices[group.type];
    final history = prov.rawPriceHistory(group.id);
    // الخام أقل بكتير من سعر الباقة = على الأغلب النص متكتوب مكانه بالغلط
    final looksHalved = group.isBimonthly &&
        tier != null &&
        group.fixedBillAmount > 0 &&
        group.fixedBillAmount < tier * 0.75;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('١) الفاتورة بتنزل بكام؟',
          style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.text)),
      Text(
        group.isBimonthly
            ? 'المبلغ اللي الشركة بتاخده لما الفاتورة تنزل — مش نص الفاتورة'
            : 'المبلغ اللي بينزل كل شهر',
        style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.muted),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                fontSize: wide ? 18 : 16, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              hintText: tier?.toStringAsFixed(0) ?? 'المبلغ',
              hintStyle: GoogleFonts.cairo(fontSize: 14),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: (_) => onSave(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            padding: EdgeInsets.symmetric(
                horizontal: wide ? 22 : 16, vertical: wide ? 16 : 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onSave,
          child: Text('احفظ',
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onAccent)),
        ),
      ]),

      // ⚠️ تنبيه الرقم المنصّف — ده أشهر غلط في البيانات القديمة
      if (looksHalved) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.orangeLight,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '⚠️ الرقم ده شكله نص الفاتورة مش الفاتورة',
              style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.orange),
            ),
            Text(
              'باقة الخط ${tier.toStringAsFixed(0)} ج، والمكتوب هنا '
              '${group.fixedBillAmount.toStringAsFixed(0)} ج. لو ده نص '
              'الفاتورة، دوس تحت وهو هيحطه في أساس الربح ويرجّع الخام '
              '${tier.toStringAsFixed(0)} — والربح مش هيتغيّر ولا جنيه.',
              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.orange),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                controller.text = tier.toStringAsFixed(0);
                onSave();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'أيوه صلّحها — الخام ${tier.toStringAsFixed(0)} ج',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onAccent),
                ),
              ),
            ),
          ]),
        ),
      ],

      // 📊 أساس الربح — للعلم بس، بيتظبط من كارت الفاتورة
      if (group.profitBillAmount != null) ...[
        const SizedBox(height: 6),
        Text(
          '📊 أساس الربح: ${group.profitBillAmount!.toStringAsFixed(0)} ج '
          'للشهر الواحد — رقم منفصل، الكتابة فوق مابتلمسهوش',
          style: GoogleFonts.cairo(fontSize: 9.5, color: AppColors.muted),
        ),
      ],

      // 📜 سجل تغييرات السعر — «الرقم ده اتغيّر إمتى ومن إيه لإيه».
      //
      // السعر الخام بيحرّك التوقّع والتحذيرات كلها، فلو اتغيّر بالغلط
      // لازم تقدر تشوف إمتى حصل بدل ما تفضل تخمّن.
      if (history.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📜 السعر اتغيّر قبل كده:',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
            const SizedBox(height: 3),
            for (final e in history.take(4))
              Text(
                '• ${e['text'] ?? ''}',
                style: GoogleFonts.cairo(fontSize: 9, color: AppColors.muted),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class _OverrideChip extends StatelessWidget {
  const _OverrideChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.onAccent : AppColors.text)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🧾 مربع الفرق — مطالبة على الشركة
// ══════════════════════════════════════════════════════════════════════════

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({required this.prov, required this.bill});

  final AppProvider prov;
  final CompanyBill bill;

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  late final _shouldCtrl = TextEditingController(
      text: widget.bill.fixedAmount > 0
          ? widget.bill.fixedAmount.toStringAsFixed(0)
          : '');
  late final _noteCtrl = TextEditingController(text: widget.bill.disputeNote ?? '');

  @override
  void dispose() {
    _shouldCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _diff {
    final should = double.tryParse(_shouldCtrl.text.trim()) ?? 0;
    if (should <= 0) return 0;
    return widget.bill.actualAmount - should;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.prov.db.companyBills
        .firstWhere((x) => x.id == widget.bill.id, orElse: () => widget.bill);
    final wide = context.isWide;
    final diff = _diff;

    return _SheetShell(
      title: 'الشركة نزّلت زيادة؟',
      subtitle: '${_monthLabel(b.month)} — اختياري بالكامل',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(children: [
                Text('نزلت فعلاً',
                    style: GoogleFonts.cairo(
                        fontSize: 10.5, color: AppColors.muted)),
                Text('${b.actualAmount.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(
                        fontSize: wide ? 20 : 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
              ]),
            ),
            Container(width: 1, height: 34, color: AppColors.border),
            Expanded(
              child: Column(children: [
                Text('الفرق',
                    style: GoogleFonts.cairo(
                        fontSize: 10.5, color: AppColors.muted)),
                Text(
                  diff == 0 ? '—' : '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                      fontSize: wide ? 20 : 17,
                      fontWeight: FontWeight.w900,
                      color: diff > 0 ? AppColors.red2 : AppColors.muted),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        Text('المفروض تنزل بكام؟',
            style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        const SizedBox(height: 6),
        TextField(
          controller: _shouldCtrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            hintText: 'مثلاً ٥٠٠٠',
            hintStyle: GoogleFonts.cairo(fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),

        Text('كلمت الشركة قالوا إيه؟ (اختياري)',
            style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        const SizedBox(height: 6),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          style: GoogleFonts.cairo(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'قالوا هيعوضوني الشهر الجاي…',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'المطالبة دي بتتسجّل عندك وبس — ما لهاش أي دعوة بحساب دور '
            'الشهر اللي بعده. لو الشركة قالت هتعوّضك ببلاش، علّم كده من '
            'شيت الخط في خانة «ببلاش تعويض».',
            style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.blue2),
          ),
        ),
        const SizedBox(height: 14),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red2,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11)),
          ),
          onPressed: diff <= 0
              ? null
              : () {
                  widget.prov.setBillDispute(b.id, diff,
                      note: _noteCtrl.text.trim().isEmpty
                          ? null
                          : _noteCtrl.text.trim());
                  Navigator.pop(context);
                },
          child: Text(
            diff <= 0
                ? 'اكتب المبلغ المفروض الأول'
                : 'سجّل ${diff.toStringAsFixed(0)} ج على الشركة',
            style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: AppColors.onAccent),
          ),
        ),

        if (b.disputeAmount > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.prov.toggleBillDisputeResolved(b.id);
                  Navigator.pop(context);
                },
                icon: Icon(
                    b.disputeResolved
                        ? Icons.replay
                        : Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.green2),
                label: Text(
                  b.disputeResolved ? 'افتحها تاني' : 'اترجعت / اتعوّضت',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                widget.prov.setBillDispute(b.id, 0);
                Navigator.pop(context);
              },
              child: Text('امسح المطالبة',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5, color: AppColors.muted)),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// زرار عريض داخل الشيتات
// ══════════════════════════════════════════════════════════════════════════

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  Text(hint,
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_left, size: 17, color: color),
          ]),
        ),
      ),
    );
  }
}
