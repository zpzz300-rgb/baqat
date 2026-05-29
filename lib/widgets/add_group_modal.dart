// lib/widgets/add_group_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/phone_utils.dart';
import '../utils/image_utils.dart';
import 'common.dart';

class AddGroupModal extends StatefulWidget {
  final Group? existing;
  const AddGroupModal({super.key, this.existing});

  @override
  State<AddGroupModal> createState() => _AddGroupModalState();
}

class _AddGroupModalState extends State<AddGroupModal> {
  final _phoneCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerFullNameCtrl = TextEditingController();
  final _ownerNatIdCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _maxClientsCtrl = TextEditingController();
  final _pointsMonthlyCtrl = TextEditingController();
  final _pointPriceCtrl = TextEditingController();
  final _extraFeeCtrl = TextEditingController();
  final _actualBillCtrl = TextEditingController();
  final _lastBillAmountCtrl = TextEditingController();
  final _manualBillCtrl = TextEditingController();
  // Phase 2
  final _totalMinutesCtrl = TextEditingController();
  final _mainLineGbCtrl = TextEditingController();
  final _insuranceCtrl = TextEditingController();
  String? _manualDueDate;
  // Phase 2
  String _tier = '';
  String? _contractPhotoPath;
  String? _weCouponDate;
  bool _monthOnMeToggle = false;
  bool _fixedRateSystem = false;
  bool _weCouponEnabled = false;
  String? _vodafoneRateType;

  // نقاط/شهر — اختيار مسبق أو يدوي
  int? _pointsMonthlySelected; // null = يدوي
  static const _pointsPresets = [500, 1000, 1500, 2000, 3000, 5000];

  String _type = '3800';
  String _payer = 'me';
  String _cycle = '1';
  String? _date;
  String? _lastBillDate;
  String? _phoneError;

  // Main line fields
  String? _provider;
  String? _billingCycle;
  String? _offerEndDate;
  LineType _lineType = LineType.home4g;

  bool _showMainLineSection = false;

  static const _providerColors = {
    'vodafone': Color(0xFFe53935),
    'etisalat': Color(0xFF43a047),
    'orange': Color(0xFFef6c00),
    'we': Color(0xFF5e35b1),
  };
  static const _providerEmojis = {
    'vodafone': '📱',
    'etisalat': '📡',
    'orange': '🟠',
    'we': '🔵',
  };
  static const _providerNames = {
    'vodafone': 'فودافون',
    'etisalat': 'اتصالات',
    'orange': 'أورنج',
    'we': 'WE',
  };
  static const _cycleLabels = {
    'day4': 'اليوم 4',
    'cycle1': 'سيكل 1 — يتجدد يوم 1',
    'cycle2': 'سيكل 2 — يتجدد يوم 15',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _phoneCtrl.text = e.phone;
      _ownerNameCtrl.text = e.ownerName ?? '';
      _ownerNatIdCtrl.text = e.ownerNatId ?? '';
      _notesCtrl.text = e.notes ?? '';
      _type = e.type;
      _payer = e.payer;
      _cycle = e.cycle;
      _date = e.date;
      _lastBillDate = e.lastBillDate;
      _provider = e.provider;
      _billingCycle = e.billingCycle;
      _offerEndDate = e.offerEndDate;
      if (e.maxClients != null) _maxClientsCtrl.text = e.maxClients.toString();
      if (e.pointsMonthly != null) {
        if (_pointsPresets.contains(e.pointsMonthly)) {
          _pointsMonthlySelected = e.pointsMonthly;
        } else {
          _pointsMonthlyCtrl.text = e.pointsMonthly.toString();
        }
      }
      if (e.pointPrice != null) {
        _pointPriceCtrl.text = e.pointPrice!.toStringAsFixed(0);
      }
      if (e.extraClientFee != null) {
        _extraFeeCtrl.text = e.extraClientFee!.toStringAsFixed(0);
      }
      if (e.actualBillAmount != null) {
        _actualBillCtrl.text = e.actualBillAmount!.toStringAsFixed(0);
      }
      if (e.lastBillAmount > 0) {
        _lastBillAmountCtrl.text = e.lastBillAmount.toStringAsFixed(0);
      }
      if (e.fixedBillAmount > 0 && e.type == 'manual') {
        _manualBillCtrl.text = e.fixedBillAmount.toStringAsFixed(0);
      }
      _manualDueDate = e.manualDueDate;
      _lineType = e.lineType;
      // Phase 2
      _ownerFullNameCtrl.text = e.ownerFullName ?? '';
      if (e.totalMinutes > 0) _totalMinutesCtrl.text = '${e.totalMinutes}';
      if (e.mainLineAllocationGb > 0) {
        _mainLineGbCtrl.text = '${e.mainLineAllocationGb}';
      }
      if (e.refundableInsurance > 0) {
        _insuranceCtrl.text = e.refundableInsurance.toStringAsFixed(0);
      }
      _tier = e.tier;
      _contractPhotoPath = e.contractPhotoPath;
      _weCouponDate = e.weCouponDate;
      _monthOnMeToggle = e.monthOnMeToggle;
      _fixedRateSystem = e.fixedRateSystem;
      _weCouponEnabled = e.weCouponEnabled;
      _vodafoneRateType = e.vodafoneRateType;
      if (_provider != null) _showMainLineSection = true;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerFullNameCtrl.dispose();
    _ownerNatIdCtrl.dispose();
    _notesCtrl.dispose();
    _maxClientsCtrl.dispose();
    _pointsMonthlyCtrl.dispose();
    _pointPriceCtrl.dispose();
    _extraFeeCtrl.dispose();
    _actualBillCtrl.dispose();
    _lastBillAmountCtrl.dispose();
    _manualBillCtrl.dispose();
    _totalMinutesCtrl.dispose();
    _mainLineGbCtrl.dispose();
    _insuranceCtrl.dispose();
    super.dispose();
  }

  void _validatePhone(String val, AppProvider prov) {
    final fmtErr = validatePhone(val);
    final allPhones = [
      ...prov.db.members.map((m) => m.phone),
      ...prov.db.groups
          .where((g) => g.id != (widget.existing?.id ?? ''))
          .map((g) => g.phone),
      ...prov.db.workNums.map((w) => w.phone),
    ];
    final dupErr = fmtErr == null ? checkDuplicate(val, allPhones) : null;
    setState(() => _phoneError = fmtErr ?? dupErr);
  }

  Future<String?> _pickDate(String? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null ? DateTime.tryParse(current) ?? now : now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked == null) return null;
    return '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return ModalShell(
      title: widget.existing == null
          ? '➕ إضافة مجموعة جديدة'
          : '✏️ تعديل المجموعة',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: GoogleFonts.cairo()),
        ),
        ElevatedButton(
          onPressed: _phoneError == null ? _save : null,
          child: Text('حفظ',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        ),
      ],
      children: [
        // ── Phone ─────────────────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFormField(
              label: 'رقم الفاتورة',
              controller: _phoneCtrl,
              hint: 'رقم الخط الرئيسي',
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              onChanged: (v) => _validatePhone(v, prov),
            ),
            if (_phoneError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_phoneError!,
                    style: GoogleFonts.cairo(
                        color: AppColors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Line type ─────────────────────────────────────────────
        Text('نوع الخط',
            style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        LineTypeSelector(
            value: _type,
            onChanged: (v) => setState(() => _type = v),
            prefix: 'ng'),
        const SizedBox(height: 12),

        // ── Manual section ─────────────────────────────────────────
        if (_type == 'manual') ...[
          _buildManualSection(),
          const SizedBox(height: 12),
        ],

        // ── Regular fields (hidden for manual) ─────────────────────
        if (_type != 'manual') ...[
          // ── Payer ────────────────────────────────────────────────
          Text('شهر الفاتورة الحالي (على مين؟)',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          PayerSelector(
              value: _payer, onChanged: (v) => setState(() => _payer = v)),
          const SizedBox(height: 12),

          // ── Billing cycle ─────────────────────────────────────────
          Text('🔄 دورة الفاتورة',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _billingCycle,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            hint: Text('اختر دورة الفاتورة',
                style: GoogleFonts.cairo(fontSize: 13)),
            isExpanded: true,
            items: _cycleLabels.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value,
                          style: GoogleFonts.cairo(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _billingCycle = v;
              _cycle = (v == 'cycle2') ? '2' : '1';
            }),
          ),
          const SizedBox(height: 12),

          // ── Last bill date ────────────────────────────────────────
          AppFormField(
            label: 'تاريخ آخر فاتورة نزلت (اختياري)',
            hint: 'مثال: 2024-3',
            initialValue: _lastBillDate,
            onChanged: (v) => _lastBillDate = v,
          ),
          const SizedBox(height: 10),
          AppFormField(
            label: '💳 قيمة آخر فاتورة (ج)',
            controller: _lastBillAmountCtrl,
            hint: 'المبلغ الذي نزل على الفاتورة',
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 12),
        ],

        // ── Activation date ───────────────────────────────────────
        _datePickerField(
            'تاريخ التشغيل', _date, (d) => setState(() => _date = d)),
        const SizedBox(height: 12),

        // ── Owner ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👤 بيانات صاحب الخط',
                  style: GoogleFonts.cairo(
                      color: AppColors.blue2, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              AppFormField(
                  label: 'الاسم',
                  controller: _ownerNameCtrl,
                  hint: 'اسم صاحب الخط'),
              const SizedBox(height: 10),
              AppFormField(
                  label: 'الرقم القومي',
                  controller: _ownerNatIdCtrl,
                  hint: '14 رقم',
                  maxLength: 14,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [NatIdInputFormatter()]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Main Line Section toggle ──────────────────────────────
        GestureDetector(
          onTap: () =>
              setState(() => _showMainLineSection = !_showMainLineSection),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _provider != null
                  ? _providerColors[_provider]!.withValues(alpha: 0.08)
                  : AppColors.blueLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _provider != null
                      ? _providerColors[_provider]!
                      : AppColors.border),
            ),
            child: Row(children: [
              Text(
                _provider != null
                    ? '${_providerEmojis[_provider]} ${_providerNames[_provider]}'
                    : '📡 تفاصيل الخط الرئيسي',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: _provider != null
                        ? _providerColors[_provider]
                        : AppColors.blue2),
              ),
              const Spacer(),
              Icon(_showMainLineSection ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.muted),
            ]),
          ),
        ),

        if (_showMainLineSection) ...[
          const SizedBox(height: 12),
          _buildMainLineSection(),
        ],
        const SizedBox(height: 12),

        // ── Notes ─────────────────────────────────────────────────
        AppFormField(label: 'ملاحظات', controller: _notesCtrl, hint: '...'),
      ],
    );
  }

  // ── Main line details section ─────────────────────────────────
  Widget _buildMainLineSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider selector (Phase 2: شلنا LineTypeSelector الزيادة)
          Text('🏢 شركة الاتصالات',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
              children: _providerNames.entries.map((e) {
            final sel = _provider == e.key;
            final c = _providerColors[e.key]!;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _provider = e.key),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? c : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: sel ? c : AppColors.border, width: 2),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_providerEmojis[e.key]!,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(e.value,
                        style: GoogleFonts.cairo(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: sel ? Colors.white : AppColors.text)),
                  ]),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),

          // Numbers row
          AppFormField(
              label: 'عدد العملاء المتاحين',
              controller: _maxClientsCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr),
          const SizedBox(height: 10),

          // نقاط/شهر — dropdown أو يدوي
          Text('🏅 نقاط/شهر (تُضاف يوم 7 تلقائياً)',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._pointsPresets.map((pts) {
                final sel = _pointsMonthlySelected == pts;
                return GestureDetector(
                  onTap: () => setState(() {
                    _pointsMonthlySelected = pts;
                    _pointsMonthlyCtrl.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.blue2 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.blue2 : AppColors.border),
                    ),
                    child: Text('$pts نقطة',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.muted)),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => setState(() => _pointsMonthlySelected = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _pointsMonthlySelected == null
                        ? AppColors.orange
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _pointsMonthlySelected == null
                            ? AppColors.orange
                            : AppColors.border),
                  ),
                  child: Text('يدوي ✏️',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _pointsMonthlySelected == null
                              ? Colors.white
                              : AppColors.muted)),
                ),
              ),
            ],
          ),
          if (_pointsMonthlySelected == null) ...[
            const SizedBox(height: 8),
            AppFormField(
              label: 'أدخل عدد النقاط يدوياً',
              controller: _pointsMonthlyCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: AppFormField(
                    label: 'سعر النقطة (ج)',
                    controller: _pointPriceCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr)),
            const SizedBox(width: 10),
            Expanded(
                child: AppFormField(
                    label: 'زيادة/عميل إضافي (ج)',
                    controller: _extraFeeCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr)),
          ]),
          const SizedBox(height: 10),
          AppFormField(
            label: '💵 المبلغ الفعلي للفاتورة (ج)',
            controller: _actualBillCtrl,
            hint: 'المبلغ الذي تدفعه للشركة شهرياً',
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 14),

          // Offer end date
          Text('📅 تاريخ نهاية العرض',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _datePickerField('اختر تاريخ انتهاء العرض', _offerEndDate, (d) {
            setState(() => _offerEndDate = d);
          }),
          if (_offerEndDate != null) ...[
            const SizedBox(height: 8),
            _buildOfferPreview(_offerEndDate!),
          ],
          const SizedBox(height: 14),

          // ───── Phase 2: إعدادات الخط الرئيسي المتقدمة ─────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('⚙️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text('إعدادات الخط الرئيسي المتقدمة',
                      style: GoogleFonts.cairo(
                          color: const Color(0xFFE65100),
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                // الاسم الرباعي
                AppFormField(
                  label: '👤 اسم صاحب الخط (رباعي)',
                  controller: _ownerFullNameCtrl,
                  hint: 'الاسم بالكامل (4 أسماء)',
                ),
                const SizedBox(height: 10),
                // Tier selector
                Text('🎯 نوع الباقة (Tier)',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: _GroupTierBtn(
                      label: 'Tier 1 — 4250 ج\n7 + exception',
                      value: 'tier1_4250',
                      selected: _tier,
                      onTap: (v) => setState(() {
                        _tier = v;
                        _totalMinutesCtrl.text = '12000';
                        _maxClientsCtrl.text = '7';
                        _extraFeeCtrl.text = '125';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GroupTierBtn(
                      label: 'Tier 2 — أصغر\n5 + exception',
                      value: 'tier2_smaller',
                      selected: _tier,
                      onTap: (v) => setState(() {
                        _tier = v;
                        _totalMinutesCtrl.text = '10000';
                        _maxClientsCtrl.text = '5';
                        _extraFeeCtrl.text = '125';
                      }),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: AppFormField(
                      label: '🎙 إجمالي الدقائق',
                      controller: _totalMinutesCtrl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      hint: '12000',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppFormField(
                      label: '📡 حصة الخط من الجيجا',
                      controller: _mainLineGbCtrl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      hint: '0',
                    ),
                  ),
                ]),
                // Etisalat conditional
                if (_provider == 'etisalat') ...[
                  const SizedBox(height: 14),
                  _GroupToggleRow(
                    label: '📅 شهر عليا وشهر على الشركة',
                    value: _monthOnMeToggle,
                    onChanged: (v) => setState(() => _monthOnMeToggle = v),
                  ),
                  const SizedBox(height: 8),
                  _GroupToggleRow(
                    label: '🔒 نظام ثابت',
                    value: _fixedRateSystem,
                    onChanged: (v) => setState(() => _fixedRateSystem = v),
                  ),
                  const SizedBox(height: 10),
                  AppFormField(
                    label: '💰 التأمين المسترد (ج)',
                    controller: _insuranceCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    hint: '0',
                  ),
                  const SizedBox(height: 4),
                  Text('تذكير الاسترداد بعد 6 شهور من بداية العرض',
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.muted)),
                ],
                // WE conditional
                if (_provider == 'we') ...[
                  const SizedBox(height: 14),
                  _GroupToggleRow(
                    label: '🎫 قسيمة الـ 5000',
                    value: _weCouponEnabled,
                    onChanged: (v) => setState(() => _weCouponEnabled = v),
                  ),
                  if (_weCouponEnabled) ...[
                    const SizedBox(height: 10),
                    Text('📅 تاريخ نزول القسيمة',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    _datePickerField('اختر تاريخ القسيمة', _weCouponDate,
                        (d) => setState(() => _weCouponDate = d)),
                    const SizedBox(height: 4),
                    Text('عداد تنازلي بالأيام المتبقية يظهر في الهيدر',
                        style: GoogleFonts.cairo(
                            fontSize: 10, color: AppColors.muted)),
                  ],
                ],
                // Vodafone conditional
                if (_provider == 'vodafone') ...[
                  const SizedBox(height: 14),
                  Text('💱 نوع النظام',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: _GroupTierBtn(
                        label: 'عرض متغير',
                        value: 'variable',
                        selected: _vodafoneRateType ?? '',
                        onTap: (v) =>
                            setState(() => _vodafoneRateType = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GroupTierBtn(
                        label: 'سعر ثابت',
                        value: 'fixed',
                        selected: _vodafoneRateType ?? '',
                        onTap: (v) =>
                            setState(() => _vodafoneRateType = v),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 14),
                // Contract photo
                _buildContractPhoto(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickContractPhoto(ImageSource src) async {
    final picked = await ImageUtils.pickCompressed(source: src);
    if (picked != null) setState(() => _contractPhotoPath = picked.path);
  }

  Widget _buildContractPhoto() {
    final hasPhoto =
        _contractPhotoPath != null && _contractPhotoPath!.isNotEmpty;
    final file = hasPhoto ? File(_contractPhotoPath!) : null;
    final exists = file != null && file.existsSync();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📄 صورة العقد / شروط العرض',
            style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          GestureDetector(
            onTap: () => _pickContractPhoto(ImageSource.gallery),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
                image: exists
                    ? DecorationImage(
                        image: FileImage(file), fit: BoxFit.cover)
                    : null,
              ),
              child: !exists
                  ? const Icon(Icons.photo_library_outlined,
                      color: Color(0xFFE65100), size: 30)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickContractPhoto(ImageSource.camera),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blueMid),
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.blue2, size: 30),
            ),
          ),
          const SizedBox(width: 10),
          if (exists)
            GestureDetector(
              onTap: () => setState(() => _contractPhotoPath = null),
              child: Text('حذف',
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.red2,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ],
    );
  }

  Widget _buildOfferPreview(String endDateStr) {
    final end = DateTime.tryParse(endDateStr);
    if (end == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final daysLeft = end.difference(DateTime(now.year, now.month, now.day)).inDays;
    final isWarning = daysLeft <= 60;
    final isExpired = daysLeft < 0;
    final color = isExpired
        ? const Color(0xFFC62828)
        : isWarning
            ? const Color(0xFFE65100)
            : AppColors.green2;
    final bgColor = isExpired
        ? const Color(0xFFFFEBEE)
        : isWarning
            ? const Color(0xFFFFF3E0)
            : AppColors.greenLight;
    final icon = isExpired
        ? Icons.error_outline
        : isWarning
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline;
    final label = isExpired
        ? 'انتهى العرض منذ ${-daysLeft} يوم'
        : isWarning
            ? 'تبقى $daysLeft يوم على انتهاء العرض'
            : 'تبقى $daysLeft يوم على انتهاء العرض';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.cairo(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _buildManualSection() {
    final dueDate =
        _manualDueDate != null ? DateTime.tryParse(_manualDueDate!) : null;
    final now = DateTime.now();
    final hoursLeft = dueDate?.difference(now).inHours;
    final isUrgent = hoursLeft != null && hoursLeft <= 48;
    final isPast = hoursLeft != null && hoursLeft < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFFB300), width: isUrgent ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('✏️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text('بيانات الفاتورة اليدوية',
                style: GoogleFonts.cairo(
                    color: const Color(0xFFE65100),
                    fontWeight: FontWeight.w900)),
          ]),
          if (isUrgent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isPast ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isPast
                        ? const Color(0xFFC62828)
                        : const Color(0xFFE65100)),
              ),
              child: Row(children: [
                Icon(isPast ? Icons.error : Icons.warning_amber_rounded,
                    size: 16,
                    color: isPast
                        ? const Color(0xFFC62828)
                        : const Color(0xFFE65100)),
                const SizedBox(width: 6),
                Text(
                  isPast
                      ? '🔴 فات موعد السداد!'
                      : '⚠️ موعد السداد خلال $hoursLeft ساعة',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPast
                          ? const Color(0xFFC62828)
                          : const Color(0xFFE65100)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          AppFormField(
            label: 'قيمة الفاتورة الثابتة (ج)',
            controller: _manualBillCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            hint: 'مثال: 500',
          ),
          const SizedBox(height: 10),
          AppDateField(
            label: '📅 تاريخ موعد السداد',
            initialValue: _manualDueDate,
            onChanged: (v) => setState(
                () => _manualDueDate = v.trim().isNotEmpty ? v.trim() : null),
          ),
          const SizedBox(height: 6),
          Text('سيتم تنبيهك قبل 48 ساعة من موعد السداد',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _datePickerField(
      String label, String? value, void Function(String) onPicked) {
    return GestureDetector(
      onTap: () async {
        final d = await _pickDate(value);
        if (d != null) onPicked(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value ?? label,
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color:
                          value != null ? AppColors.text : AppColors.muted))),
        ]),
      ),
    );
  }

  void _save() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('⚠️ رقم الفاتورة مطلوب', style: GoogleFonts.cairo())),
      );
      return;
    }
    if (_phoneError != null) return;
    final prov = context.read<AppProvider>();
    final isManual = _type == 'manual';
    final manualBill =
        isManual ? (double.tryParse(_manualBillCtrl.text.trim()) ?? 0) : 0.0;

    // Preserve billDebt when editing; new manual groups start with manualBill as debt
    double billDebt = widget.existing?.billDebt ?? 0;
    if (isManual && widget.existing == null && manualBill > 0) {
      billDebt = manualBill; // initialize debt for brand-new manual group
    } else if (isManual &&
        widget.existing != null &&
        manualBill != widget.existing!.fixedBillAmount) {
      final diff = manualBill - widget.existing!.fixedBillAmount;
      billDebt = (billDebt + diff).clamp(0, double.infinity);
    }

    final g = Group(
      id: widget.existing?.id ?? prov.newGroupId(),
      phone: phone,
      type: _type,
      payer: _payer,
      cycle: _cycle,
      ownerName: _ownerNameCtrl.text.trim().isNotEmpty
          ? _ownerNameCtrl.text.trim()
          : null,
      ownerNatId: _ownerNatIdCtrl.text.trim().isNotEmpty
          ? _ownerNatIdCtrl.text.trim()
          : null,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      date: _date,
      lastBillDate: isManual ? null : _lastBillDate,
      rewardPoints: widget.existing?.rewardPoints ?? 0,
      pointsValue: widget.existing?.pointsValue ?? 0.04,
      complaints: widget.existing?.complaints ?? [],
      gifts: widget.existing?.gifts ?? [],
      giftProfit: widget.existing?.giftProfit ?? 0,
      pointsRedemptions: widget.existing?.pointsRedemptions ?? [],
      expiryDate: widget.existing?.expiryDate,
      provider: _provider,
      maxClients: int.tryParse(_maxClientsCtrl.text.trim()),
      pointsMonthly: _pointsMonthlySelected ??
          int.tryParse(_pointsMonthlyCtrl.text.trim()),
      pointPrice: double.tryParse(_pointPriceCtrl.text.trim()),
      extraClientFee: double.tryParse(_extraFeeCtrl.text.trim()),
      billingCycle: isManual ? null : _billingCycle,
      offerEndDate: _offerEndDate,
      actualBillAmount: double.tryParse(_actualBillCtrl.text.trim()),
      lineType: _lineType,
      lastBillAmount: isManual
          ? manualBill
          : (double.tryParse(_lastBillAmountCtrl.text.trim()) ??
              widget.existing?.lastBillAmount ??
              0),
      fixedBillAmount: manualBill,
      billDebt: billDebt,
      groupNotes: widget.existing?.groupNotes ?? [],
      lastNotesMonth: widget.existing?.lastNotesMonth,
      pendingPointsProfit: widget.existing?.pendingPointsProfit ?? 0,
      lastGiftResetMonth: widget.existing?.lastGiftResetMonth,
      stickyNote: widget.existing?.stickyNote,
      manualDueDate: isManual ? _manualDueDate : null,
      parentGroupId: widget.existing?.parentGroupId,
      // Phase 2: Master Line fields
      ownerFullName: _ownerFullNameCtrl.text.trim().isNotEmpty
          ? _ownerFullNameCtrl.text.trim()
          : null,
      contractPhotoPath: _contractPhotoPath,
      mainLineAllocationGb: int.tryParse(_mainLineGbCtrl.text.trim()) ??
          (widget.existing?.mainLineAllocationGb ?? 0),
      totalMinutes: int.tryParse(_totalMinutesCtrl.text.trim()) ??
          (widget.existing?.totalMinutes ?? 0),
      tier: _tier,
      monthOnMeToggle: _monthOnMeToggle,
      fixedRateSystem: _fixedRateSystem,
      refundableInsurance: double.tryParse(_insuranceCtrl.text.trim()) ??
          (widget.existing?.refundableInsurance ?? 0),
      insuranceClaimDate: widget.existing?.insuranceClaimDate,
      pointsResetDay: widget.existing?.pointsResetDay ?? 7,
      weCouponEnabled: _weCouponEnabled,
      weCouponDate: _weCouponDate,
      vodafoneRateType: _vodafoneRateType,
      extraBundles: widget.existing?.extraBundles ?? [],
    );
    if (widget.existing == null) {
      prov.addGroup(g);
    } else {
      prov.editGroup(g);
    }
    Navigator.pop(context);
  }
}

class _GroupTierBtn extends StatelessWidget {
  final String label, value, selected;
  final void Function(String) onTap;
  const _GroupTierBtn({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.blue2 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? AppColors.blue2 : AppColors.border, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _GroupToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? AppColors.greenLight : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value ? AppColors.green : AppColors.border, width: 1.2),
        ),
        child: Row(children: [
          Icon(value ? Icons.toggle_on : Icons.toggle_off,
              color: value ? AppColors.green : AppColors.muted, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
          ),
        ]),
      ),
    );
  }
}
