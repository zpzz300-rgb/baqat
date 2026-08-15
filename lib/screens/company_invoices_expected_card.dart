// lib/screens/company_invoices_expected_card.dart
// 📅 كارت الفاتورة المتوقّعة — جزء من company_invoices_screen.dart.
// اتفصل عشان الملف كان 4366 سطر وبقى صعب يتقرا. الكود زي ما هو بالظبط.
part of 'company_invoices_screen.dart';

class _ExpectedCard extends StatefulWidget {
  final Group group;
  final String month;
  final AppProvider prov;
  final double? lastMonthAmount;
  final bool isFreeThisMonth;

  const _ExpectedCard({
    required this.group,
    required this.month,
    required this.prov,
    this.lastMonthAmount,
    this.isFreeThisMonth = false,
  });

  @override
  State<_ExpectedCard> createState() => _ExpectedCardState();
}

class _ExpectedCardState extends State<_ExpectedCard> {
  final _amountCtrl = TextEditingController();
  bool _overrideNotDue = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _saveInline() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    _checkLockThenSave(amount);
  }

  void _finalizeSave(double amount) {
    widget.prov.addGroupBill(widget.group.id, amount, forMonth: widget.month);
    _amountCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  void _checkLockThenSave(double amount) {
    if (widget.prov.isBillMonthLocked(widget.month)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🔒 ${_monthLabel(widget.month)} مقفولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          content: Text('مراجعة الشهر ده اتقفلت. متأكد إنك عايز تسجّل فاتورة فيه برضه؟',
              style: GoogleFonts.cairo(fontSize: 12)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _checkOverAmountThenSave(amount);
              },
              child: Text('أكمل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    _checkOverAmountThenSave(amount);
  }

  void _checkOverAmountThenSave(double amount) {
    final fixed = widget.group.fixedBillAmount;
    if (fixed > 0 && amount > fixed * 1.15) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('⚠️ المبلغ أعلى من المتفق عليه',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          content: Text(
              'المبلغ (${amount.toStringAsFixed(0)} ج) أعلى من الثابت المسجل (${fixed.toStringAsFixed(0)} ج) بفرق ${(amount - fixed).toStringAsFixed(0)} ج. اتأكد من الشركة قبل ما تسجّل.',
              style: GoogleFonts.cairo(fontSize: 12)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(context);
                _checkNotDueThenSave(amount);
              },
              child: Text('صح، سجّل', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    _checkNotDueThenSave(amount);
  }

  void _checkNotDueThenSave(double amount) {
    if (widget.isFreeThisMonth) {
      final acc = widget.prov.accountOfGroup(widget.group.id);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('⚠️ الخط ده مش دوره الشهر ده',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          content: Text(
            acc != null
                ? 'الخط ده جزء من حساب "${acc.name}"، والمفروض يبقى الدور على شق تاني الشهر ده. متأكد إنك عايز تسجّل الفاتورة برضه؟'
                : 'نظام الخط ده "شهر وشهر" والمفروض يبقى مجاني الشهر ده. متأكد إنك عايز تسجّل فاتورة برضه؟',
            style: GoogleFonts.cairo(fontSize: 12),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(context);
                _finalizeSave(amount);
              },
              child: Text('سجّل برضه',
                  style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    _finalizeSave(amount);
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final month = widget.month;
    final prov = widget.prov;
    final g = group;
    final provColor =
        MainLine.providerColors[g.provider] ?? AppColors.blue;
    final provEmoji =
        MainLine.providerEmojis[g.provider] ?? '📡';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                const Color(0xFF6a1b9a).withValues(alpha: 0.25),
            width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.purple.withValues(alpha: 0.04),
              blurRadius: 8)
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: provColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      '$provEmoji ${MainLine.providerNames[g.provider] ?? (g.provider ?? '?')}',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: provColor,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      '📅 $month',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: const Color(0xFF6a1b9a),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (prov.accountOfGroup(g.id) != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(5)),
                      child: Text(
                        '🔗 ${prov.accountOfGroup(g.id)!.name}',
                        style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: const Color(0xFF6a1b9a),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 5),
                Text(
                  g.phone,
                  style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue2),
                ),
                if (g.ownerName != null)
                  Text(g.ownerName!,
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  'تقدير: ${g.fixedBillAmount.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF6a1b9a),
                      fontWeight: FontWeight.w700),
                ),
                // 🌿 التشجير — لازم يبان هنا كمان مش في «الشهر الماضي» بس،
                // عشان وانت بتسجّل فاتورة الشهر ده تعرف هي على كام خط.
                LinkedLinesStrip(db: prov.db, group: g),
                if (widget.lastMonthAmount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '📅 الشهر اللي فات: ${widget.lastMonthAmount!.toStringAsFixed(0)} ج',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700),
                  ),
                ],
                Builder(builder: (_) {
                  final now = DateTime.now();
                  final isCurrentCalMonth =
                      month == '${now.year}-${now.month.toString().padLeft(2, '0')}';
                  if (!isCurrentCalMonth) return const SizedBox.shrink();
                  final expectedDay = prov.expectedBillDay(g.id);
                  if (expectedDay == null) return const SizedBox.shrink();
                  final daysLeft = expectedDay - now.day;
                  final soon = daysLeft >= 0 && daysLeft <= 3;
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      daysLeft < 0
                          ? '🔔 متوقع كانت نزلت يوم $expectedDay'
                          : (daysLeft == 0
                              ? '🔔 متوقع تنزل النهاردة'
                              : '🔔 متوقع تنزل بعد $daysLeft يوم (يوم $expectedDay)'),
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: soon ? FontWeight.w800 : FontWeight.w600,
                          color: soon ? const Color(0xFFE65100) : AppColors.muted),
                    ),
                  );
                }),
              ]),
        ),
        const SizedBox(width: 8),
        if (widget.isFreeThisMonth && !_overrideNotDue)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border)),
                child: Text('⏸ مش دوره الشهر ده',
                    style: GoogleFonts.cairo(
                        fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _overrideNotDue = true),
                child: Text('سجّل فاتورة برضه',
                    style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: Colors.orange[800],
                        decoration: TextDecoration.underline)),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: 'المبلغ',
                    hintStyle: GoogleFonts.cairo(fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.check_circle, color: AppColors.green, size: 20),
                      onPressed: _saveInline,
                    ),
                  ),
                  onSubmitted: (_) => _saveInline(),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => prov.addEstimatedBill(g.id, forMonth: month),
                child: Text(
                  '+ تقديرية',
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: const Color(0xFF6a1b9a),
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
      ]),
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
// شاشة تقسيم فاتورة الحساب المدموج — كل خط: مبلغه + نظامه (ثابت/شهر وشهر) في مكان واحد
// ══════════════════════════════════════════════════════════════════════════════