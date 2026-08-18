// lib/widgets/member_card_gift_template_sheet.dart
// 🎁 قالب رسالة الهدية — جزء من member_card.dart.
// اتفصل عشان الملف كان 2560 سطر وبقى صعب يتقرا. الكود زي ما هو بالظبط.
part of 'member_card.dart';

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
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
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
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border)),
        ),
      );
}