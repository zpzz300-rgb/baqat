// lib/screens/deleted_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class DeletedScreen extends StatelessWidget {
  const DeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final deleted = prov.db.deleted;
    final totalDebt = deleted.fold<double>(
        0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));
    final debtors = deleted.where((m) => m.balance < 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Summary bar
          if (debtors.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF9A9A)),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🔴 عملاء محذوفون عليهم ديون',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.red2)),
                  Text('${debtors.length} عميل • إجمالي: ${totalDebt.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                ])),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.send, size: 16),
                  label: Text('رسائل جماعية', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () => _sendBulkReminders(context, debtors, prov),
                ),
              ]),
            ),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.08), blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🗑 المحذوفون', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2, fontSize: 14)),
                    Text('اضغط على أي عميل لعرض تفاصيله وإرسال تذكير', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
                const Divider(height: 1),
                if (deleted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('لا يوجد عملاء محذوفون', style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: deleted.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) => _DeletedRow(member: deleted[i], prov: prov),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendBulkReminders(BuildContext context, List<Member> debtors, AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => _BulkReminderDialog(debtors: debtors, prov: prov),
    );
  }
}

// ── Single deleted member row ─────────────────────────────────────────────────
class _DeletedRow extends StatelessWidget {
  final Member member;
  final AppProvider prov;
  const _DeletedRow({required this.member, required this.prov});

  @override
  Widget build(BuildContext context) {
    final m = member;
    final hasDebt = m.balance < 0;
    final debt = hasDebt ? -m.balance : 0.0;

    return InkWell(
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // Icon
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: hasDebt ? AppColors.redLight : AppColors.greenLight,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(hasDebt ? '🔴' : '✅', style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${m.phone}  •  ${m.package}',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasDebt ? AppColors.redLight : AppColors.greenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasDebt ? '🔴 ${debt.toStringAsFixed(0)} ج' : '✅ مسدّد',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  color: hasDebt ? AppColors.red2 : AppColors.green,
                  fontSize: 11,
                ),
              ),
            ),
          ]),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.restore, color: AppColors.blue, size: 20),
            tooltip: 'استعادة',
            onPressed: () {
              prov.restoreMember(m.id);
              AppSnackbar.show(context, '✅ تمت استعادة ${m.name}');
            },
          ),
        ]),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final m = member;
    final debt = m.balance < 0 ? -m.balance : 0.0;
    final instapay = prov.instapayPhone.isNotEmpty ? '\n📲 InstaPay: ${prov.instapayPhone}' : '';
    final vodafone = prov.vodafoneCash.isNotEmpty ? '\n📱 فودافون كاش: ${prov.vodafoneCash}' : '';

    final debtMsg = debt > 0
        ? 'السلام عليكم ${m.name} 👋\nلا تزال لديك مديونية: 🔴 ${debt.toStringAsFixed(0)} ج\nباقة: ${m.package} — ${m.price.toStringAsFixed(0)} ج/شهر$instapay$vodafone\nنرجو التسوية، شكراً 🙏'
        : 'السلام عليكم ${m.name} 👋\n✅ حسابك مسدّد، شكراً لك 🙏';
    final msgCtrl = TextEditingController(text: debtMsg);
    final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');

    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text(m.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
                    const Spacer(),
                    if (debt > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(8)),
                        child: Text('🔴 ${debt.toStringAsFixed(0)} ج',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.red2)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text('${m.phone}  •  ${m.package}  •  ${m.price.toStringAsFixed(0)} ج/شهر',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                  if (m.log.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('📌 آخر الحركات:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blue2)),
                    ...m.log.take(5).map((log) {
                      final amount = ((log['amount'] ?? 0) as num).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          Text('• ${log['desc'] ?? ''}',
                              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.text)),
                          if (amount != 0) ...[
                            const Spacer(),
                            Text(
                              '${amount > 0 ? "+" : ""}${amount.toStringAsFixed(0)} ج',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: amount > 0 ? AppColors.green : AppColors.red2,
                              ),
                            ),
                          ],
                        ]),
                      );
                    }),
                  ],
                  if (debt > 0) ...[
                    const SizedBox(height: 16),
                    Text('✏️ رسالة التذكير:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blue2)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: msgCtrl,
                      maxLines: 6,
                      style: GoogleFonts.cairo(fontSize: 12),
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.send),
                        label: Text('إرسال تذكير واتساب', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(msgCtrl.text)}';
                          if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restore, size: 18),
                      label: Text('استعادة العميل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        prov.restoreMember(m.id);
                        AppSnackbar.show(context, '✅ تمت استعادة ${m.name}');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bulk reminder dialog ──────────────────────────────────────────────────────
class _BulkReminderDialog extends StatefulWidget {
  final List<Member> debtors;
  final AppProvider prov;
  const _BulkReminderDialog({required this.debtors, required this.prov});

  @override
  State<_BulkReminderDialog> createState() => _BulkReminderDialogState();
}

class _BulkReminderDialogState extends State<_BulkReminderDialog> {
  final Set<String> _selected = {};
  int _current = -1; // index being sent

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.debtors.map((m) => m.id));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('📤 رسائل تذكير جماعية', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختر العملاء الذين تريد إرسال تذكير لهم:',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 8),
              Row(children: [
                TextButton(
                  onPressed: () => setState(() => _selected.addAll(widget.debtors.map((m) => m.id))),
                  child: Text('تحديد الكل', style: GoogleFonts.cairo(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: Text('إلغاء الكل', style: GoogleFonts.cairo(fontSize: 12)),
                ),
              ]),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.debtors.length,
                  itemBuilder: (_, i) {
                    final m = widget.debtors[i];
                    final debt = m.balance < 0 ? -m.balance : 0.0;
                    return CheckboxListTile(
                      dense: true,
                      value: _selected.contains(m.id),
                      onChanged: (v) => setState(() => v == true ? _selected.add(m.id) : _selected.remove(m.id)),
                      title: Text(m.name, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
                      subtitle: Text('🔴 ${debt.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.red2)),
                      secondary: _current == i
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: GoogleFonts.cairo()),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.send, size: 16),
          label: Text('إرسال (${_selected.length})', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          onPressed: _selected.isEmpty ? null : () => _sendAll(context),
        ),
      ],
    );
  }

  Future<void> _sendAll(BuildContext context) async {
    final prov = widget.prov;
    final instapay = prov.instapayPhone.isNotEmpty ? '\n📲 InstaPay: ${prov.instapayPhone}' : '';
    final vodafone = prov.vodafoneCash.isNotEmpty ? '\n📱 فودافون كاش: ${prov.vodafoneCash}' : '';

    for (int i = 0; i < widget.debtors.length; i++) {
      final m = widget.debtors[i];
      if (!_selected.contains(m.id)) continue;
      setState(() => _current = i);
      final debt = m.balance < 0 ? -m.balance : 0.0;
      final msg =
          'السلام عليكم ${m.name} 👋\nلا تزال لديك مديونية: 🔴 ${debt.toStringAsFixed(0)} ج$instapay$vodafone\nنرجو التسوية، شكراً 🙏';
      final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}';
      if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
      await Future.delayed(const Duration(seconds: 2));
    }
    setState(() => _current = -1);
    if (context.mounted) Navigator.pop(context);
  }
}
