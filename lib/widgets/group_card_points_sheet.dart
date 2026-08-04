// lib/widgets/group_card_points_sheet.dart
// 🎯 لوحة نقاط الخط — جزء من group_card.dart.
// اتفصل عشان الملف كان 2984 سطر وبقى صعب يتقرا. الكود زي ما هو بالظبط.
part of 'group_card.dart';

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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      side: BorderSide(color: AppColors.blueMid),
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
                                  Icon(Icons.calendar_today,
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