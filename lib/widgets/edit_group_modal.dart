// lib/widgets/edit_group_modal.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/image_utils.dart';
import 'common.dart';

class EditGroupModal extends StatefulWidget {
  final Group group;
  const EditGroupModal({super.key, required this.group});

  @override
  State<EditGroupModal> createState() => _EditGroupModalState();
}

class _EditGroupModalState extends State<EditGroupModal> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _ownerFullNameCtrl;
  late TextEditingController _ownerNatIdCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _invoiceNameCtrl;
  late TextEditingController _fixedAmountCtrl;
  late TextEditingController _voucherValueCtrl;
  late TextEditingController _manualBillCtrl;
  // Phase 2: Master Line
  late TextEditingController _totalMinutesCtrl;
  late TextEditingController _mainLineGbCtrl;
  late TextEditingController _insuranceCtrl;
  late TextEditingController _pointsMonthlyCtrl;
  late TextEditingController _pointsValueCtrl;
  late String _type, _payer, _cycle, _voucherPeriod;
  String? _date, _lastBillDate, _expiryDate, _voucherStartDate, _manualDueDate;
  String? _parentGroupId;
  String? _ownerPhotoPath;
  // Phase 2
  String? _contractPhotoPath;
  String? _weCouponDate;
  String _tier = '';
  String? _selectedProvider;
  bool _monthOnMeToggle = false;
  bool _fixedRateSystem = false;
  bool _weCouponEnabled = false;
  String? _vodafoneRateType;
  bool _showAdvanced = true; // مفتوح بالـ default عشان يكون واضح

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _phoneCtrl = TextEditingController(text: g.phone);
    _ownerNameCtrl = TextEditingController(text: g.ownerName ?? '');
    _ownerFullNameCtrl = TextEditingController(text: g.ownerFullName ?? '');
    _ownerNatIdCtrl = TextEditingController(text: g.ownerNatId ?? '');
    _notesCtrl = TextEditingController(text: g.notes ?? '');
    _invoiceNameCtrl = TextEditingController(text: g.groupInvoiceName ?? '');
    _fixedAmountCtrl = TextEditingController(
        text:
            g.fixedBillAmount > 0 ? g.fixedBillAmount.toStringAsFixed(0) : '');
    _voucherValueCtrl = TextEditingController(
        text: g.voucherValue > 0 ? g.voucherValue.toStringAsFixed(0) : '');
    _manualBillCtrl = TextEditingController(
        text:
            g.fixedBillAmount > 0 ? g.fixedBillAmount.toStringAsFixed(0) : '');
    _totalMinutesCtrl =
        TextEditingController(text: g.totalMinutes > 0 ? '${g.totalMinutes}' : '');
    _mainLineGbCtrl = TextEditingController(
        text: g.mainLineAllocationGb > 0 ? '${g.mainLineAllocationGb}' : '');
    _insuranceCtrl = TextEditingController(
        text: g.refundableInsurance > 0
            ? g.refundableInsurance.toStringAsFixed(0)
            : '');
    _pointsMonthlyCtrl = TextEditingController(
        text: (g.pointsMonthly ?? 0) > 0 ? '${g.pointsMonthly}' : '');
    _pointsValueCtrl = TextEditingController(
        text: (g.pointPrice ?? 0) > 0
            ? (g.pointPrice ?? 0).toStringAsFixed(2)
            : '');
    _type = g.type;
    _payer = g.payer;
    _cycle = g.cycle;
    _voucherPeriod = g.voucherPeriod;
    _date = g.date;
    _lastBillDate = g.lastBillDate;
    _expiryDate = g.expiryDate;
    _voucherStartDate = g.voucherStartDate;
    _manualDueDate = g.manualDueDate;
    _parentGroupId = g.parentGroupId;
    _ownerPhotoPath = g.ownerPhoto;
    _contractPhotoPath = g.contractPhotoPath;
    _tier = g.tier;
    _selectedProvider = g.provider;
    _monthOnMeToggle = g.monthOnMeToggle;
    _fixedRateSystem = g.fixedRateSystem;
    _weCouponEnabled = g.weCouponEnabled;
    _weCouponDate = g.weCouponDate;
    _vodafoneRateType = g.vodafoneRateType;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerFullNameCtrl.dispose();
    _ownerNatIdCtrl.dispose();
    _notesCtrl.dispose();
    _invoiceNameCtrl.dispose();
    _fixedAmountCtrl.dispose();
    _voucherValueCtrl.dispose();
    _manualBillCtrl.dispose();
    _totalMinutesCtrl.dispose();
    _mainLineGbCtrl.dispose();
    _insuranceCtrl.dispose();
    _pointsMonthlyCtrl.dispose();
    _pointsValueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fixed = double.tryParse(_fixedAmountCtrl.text) ?? 0;
    final voucher = double.tryParse(_voucherValueCtrl.text) ?? 0;
    final isManual = _type == 'manual';

    return ModalShell(
      title: '✏️ تعديل المجموعة',
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(
            onPressed: _save,
            child: Text('حفظ',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700))),
      ],
      children: [
        AppFormField(
            label: 'رقم الفاتورة',
            controller: _phoneCtrl,
            textDirection: TextDirection.ltr),
        const SizedBox(height: 12),
        Text('نوع الخط',
            style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        LineTypeSelector(
            value: _type,
            onChanged: (v) => setState(() => _type = v),
            prefix: 'eg'),
        const SizedBox(height: 12),

        // ── Manual section ──────────────────────────────────────
        if (isManual) ...[
          _buildManualSection(),
          const SizedBox(height: 12),
        ],

        // ── Regular section (hidden for manual) ─────────────────
        if (!isManual) ...[
          Text('شهر الفاتورة الحالي (على مين؟)',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          PayerSelector(
              value: _payer, onChanged: (v) => setState(() => _payer = v)),
          const SizedBox(height: 12),
          AppFormField(
              label: 'تاريخ آخر فاتورة نزلت',
              hint: 'مثال: 2024-3',
              initialValue: _lastBillDate,
              onChanged: (v) => _lastBillDate = v),
          const SizedBox(height: 12),
        ],

        AppDateField(
            label: 'تاريخ التشغيل',
            initialValue: _date,
            onChanged: (v) => _date = v),
        const SizedBox(height: 12),
        AppDateField(
          label: '📅 تاريخ انتهاء الخط',
          initialValue: _expiryDate,
          onChanged: (v) => _expiryDate = v.trim().isNotEmpty ? v.trim() : null,
        ),

        if (!isManual) ...[
          const SizedBox(height: 16),
          // ── بيانات الفاتورة المالية ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💰 بيانات الفاتورة',
                    style: GoogleFonts.cairo(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                AppFormField(
                  label: 'اسم الفاتورة',
                  controller: _invoiceNameCtrl,
                  hint: 'مثال: فاتورة نت المنزل',
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: AppFormField(
                      label: 'المبلغ الثابت (ج)',
                      controller: _fixedAmountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('🎫 القسيمة الذكية',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: AppFormField(
                      label: 'قيمة القسيمة (ج)',
                      controller: _voucherValueCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الدورية',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: _PeriodBtn(
                                label: '6 شهور',
                                value: '6m',
                                selected: _voucherPeriod,
                                onTap: (v) =>
                                    setState(() => _voucherPeriod = v)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _PeriodBtn(
                                label: 'سنة',
                                value: '1y',
                                selected: _voucherPeriod,
                                onTap: (v) =>
                                    setState(() => _voucherPeriod = v)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                AppDateField(
                  label: '📅 تاريخ بدء القسيمة',
                  initialValue: _voucherStartDate,
                  onChanged: (v) => setState(() => _voucherStartDate =
                      v.trim().isNotEmpty ? v.trim() : null),
                ),
                if (voucher > 0) ...[
                  const SizedBox(height: 10),
                  _FormulaPreview(
                      fixed: fixed, voucher: voucher, period: _voucherPeriod),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👤 بيانات صاحب الخط',
                  style: GoogleFonts.cairo(
                      color: AppColors.blue2, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: AppFormField(
                        label: 'الاسم', controller: _ownerNameCtrl)),
                const SizedBox(width: 10),
                Expanded(
                    child: AppFormField(
                        label: 'الرقم القومي',
                        controller: _ownerNatIdCtrl,
                        maxLength: 14,
                        textDirection: TextDirection.ltr)),
              ]),
              const SizedBox(height: 10),
              _buildOwnerPhoto(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!isManual) ...[
          _buildAdvancedSection(),
          const SizedBox(height: 12),
        ],
        AppFormField(label: 'ملاحظات', controller: _notesCtrl),
        const SizedBox(height: 12),
        _buildParentGroupPicker(context),
      ],
    );
  }

  Widget _buildParentGroupPicker(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // Only show groups other than self as potential parents
    final candidates = prov.db.groups
        .where((g) => g.id != widget.group.id)
        .toList();
    final selected = _parentGroupId != null
        ? candidates.firstWhere(
            (g) => g.id == _parentGroupId,
            orElse: () => Group(id: '', phone: '—'),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCE93D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔗 ربط بخط رئيسي',
              style: GoogleFonts.cairo(
                  color: const Color(0xFF6A1B9A), fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('الفواتير المدخلة على الخط الرئيسي ستُوزَّع تلقائياً على هذا الخط',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _parentGroupId,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCE93D8))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: Text('بدون خط رئيسي', style: GoogleFonts.cairo(fontSize: 13, color: AppColors.muted)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('— بدون خط رئيسي', style: GoogleFonts.cairo(fontSize: 13)),
              ),
              ...candidates.map((g) => DropdownMenuItem<String?>(
                    value: g.id,
                    child: Text(g.phone,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textDirection: TextDirection.ltr),
                  )),
            ],
            onChanged: (v) => setState(() => _parentGroupId = v),
          ),
          if (selected != null && _parentGroupId != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.link, size: 14, color: Color(0xFF6A1B9A)),
              const SizedBox(width: 4),
              Text('مرتبط بـ ${selected.phone}',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: const Color(0xFF6A1B9A), fontWeight: FontWeight.w700),
                  textDirection: TextDirection.ltr),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildOwnerPhoto() {
    final hasPhoto = _ownerPhotoPath != null && _ownerPhotoPath!.isNotEmpty;
    final file = hasPhoto ? File(_ownerPhotoPath!) : null;
    final exists = file != null && file.existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('صورة صاحب الخط',
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          GestureDetector(
            onTap: _pickOwnerPhoto,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFe3f2fd),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blueMid),
                image: exists
                    ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                    : null,
              ),
              child: !exists
                  ? const Icon(Icons.add_a_photo_outlined, color: AppColors.blue2, size: 28)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exists ? '✅ تم رفع الصورة' : 'لا توجد صورة',
                    style: GoogleFonts.cairo(fontSize: 12, color: exists ? AppColors.green : AppColors.muted)),
                if (exists) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _ownerPhotoPath = null),
                    child: Text('حذف الصورة',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.red2, fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 4),
                Text('اضغط على الصورة لاختيار صورة جديدة',
                    style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _pickOwnerPhoto() async {
    final picked =
        await ImageUtils.pickCompressed(source: ImageSource.gallery);
    if (picked != null) setState(() => _ownerPhotoPath = picked.path);
  }

  Future<void> _pickContractPhoto(ImageSource src) async {
    final picked = await ImageUtils.pickCompressed(source: src);
    if (picked != null) setState(() => _contractPhotoPath = picked.path);
  }

  Widget _buildAdvancedSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(children: [
              const Text('⚙️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('إعدادات الخط الرئيسي المتقدمة',
                    style: GoogleFonts.cairo(
                        color: const Color(0xFFE65100),
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ),
              Icon(
                  _showAdvanced
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFFE65100)),
            ]),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 12),
            // الاسم الرباعي
            AppFormField(
              label: 'اسم صاحب الخط (رباعي)',
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
                child: _TierBtn(
                  label: 'Tier 1 — 4250 ج\n7 عملاء + exception',
                  value: 'tier1_4250',
                  selected: _tier,
                  onTap: (v) => setState(() {
                    _tier = v;
                    _totalMinutesCtrl.text = '12000';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TierBtn(
                  label: 'Tier 2 — أصغر\n5 عملاء + exception',
                  value: 'tier2_smaller',
                  selected: _tier,
                  onTap: (v) => setState(() {
                    _tier = v;
                    _totalMinutesCtrl.text = '10000';
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
            const SizedBox(height: 10),
            // Provider selector
            Text('🏢 شركة الاتصالات',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ['etisalat', 'vodafone', 'orange', 'we'].map((p) {
                final sel = _selectedProvider == p;
                return GestureDetector(
                  onTap: () => setState(() => _selectedProvider = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? MainLine.providerColors[p]
                          : MainLine.providerBg[p],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: MainLine.providerColors[p] ?? AppColors.border,
                          width: sel ? 2 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(MainLine.providerEmojis[p] ?? '📡',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(MainLine.providerNames[p] ?? p,
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : MainLine.providerColors[p])),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Conditional fields based on provider
            if (_selectedProvider == 'etisalat') _buildEtisalatFields(),
            if (_selectedProvider == 'we') _buildWeFields(),
            if (_selectedProvider == 'vodafone') _buildVodafoneFields(),
            const SizedBox(height: 12),
            // Contract photo
            _buildContractPhoto(),
          ],
        ],
      ),
    );
  }

  Widget _buildEtisalatFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggles
        _ToggleRow(
          label: '📅 شهر عليا وشهر على الشركة',
          value: _monthOnMeToggle,
          onChanged: (v) => setState(() => _monthOnMeToggle = v),
        ),
        const SizedBox(height: 8),
        _ToggleRow(
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
        Text('سيظهر تذكير بالمطالبة بعد 6 شهور من بداية العرض',
            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: AppFormField(
              label: '🏆 نقاط شهرية',
              controller: _pointsMonthlyCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              hint: '4000',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppFormField(
              label: '💵 قيمة النقطة (ج)',
              controller: _pointsValueCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              hint: '0.04',
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildWeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          label: '🎫 قسيمة الـ 5000',
          value: _weCouponEnabled,
          onChanged: (v) => setState(() => _weCouponEnabled = v),
        ),
        if (_weCouponEnabled) ...[
          const SizedBox(height: 10),
          AppDateField(
            label: '📅 تاريخ نزول القسيمة',
            initialValue: _weCouponDate,
            onChanged: (v) =>
                setState(() => _weCouponDate = v.trim().isNotEmpty ? v : null),
          ),
          const SizedBox(height: 4),
          Text('سيظهر عداد تنازلي في الهيدر بالأيام المتبقية',
              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
        ],
      ],
    );
  }

  Widget _buildVodafoneFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💱 نوع النظام',
            style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _TierBtn(
              label: 'عرض متغير',
              value: 'variable',
              selected: _vodafoneRateType ?? '',
              onTap: (v) => setState(() => _vodafoneRateType = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TierBtn(
              label: 'سعر ثابت',
              value: 'fixed',
              selected: _vodafoneRateType ?? '',
              onTap: (v) => setState(() => _vodafoneRateType = v),
            ),
          ),
        ]),
      ],
    );
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
                        : const Color(0xFFE65100),
                  ),
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

  void _save() {
    final prov = context.read<AppProvider>();
    final g = widget.group;
    final isManual = _type == 'manual';
    final manualBill = isManual
        ? (double.tryParse(_manualBillCtrl.text.trim()) ?? g.fixedBillAmount)
        : g.fixedBillAmount;

    // For manual groups: if bill amount changed, update billDebt by the difference
    double newBillDebt = g.billDebt;
    if (isManual && manualBill != g.fixedBillAmount) {
      // Replace old fixed bill with new — reflect difference in debt
      final diff = manualBill - g.fixedBillAmount;
      newBillDebt = (g.billDebt + diff).clamp(0, double.infinity);
    } else if (isManual && g.billDebt == 0 && manualBill > 0) {
      // First time setting manual bill — initialize debt
      newBillDebt = manualBill;
    }

    prov.editGroup(Group(
      id: g.id,
      phone: _phoneCtrl.text.trim(),
      type: _type,
      payer: _payer,
      cycle: _cycle,
      lastBilledMonth: g.lastBilledMonth,
      lastBillDate: isManual ? null : _lastBillDate,
      lastBillActualMonth: g.lastBillActualMonth,
      lastBillActual: g.lastBillActual,
      ownerName: _ownerNameCtrl.text.trim().isNotEmpty
          ? _ownerNameCtrl.text.trim()
          : null,
      ownerNatId: _ownerNatIdCtrl.text.trim().isNotEmpty
          ? _ownerNatIdCtrl.text.trim()
          : null,
      ownerPhoto: _ownerPhotoPath,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      date: _date,
      expiryDate: _expiryDate,
      rewardPoints: g.rewardPoints,
      pointsValue: g.pointsValue,
      complaints: g.complaints,
      gifts: g.gifts,
      giftProfit: g.giftProfit,
      pointsRedemptions: g.pointsRedemptions,
      groupInvoiceName: isManual
          ? null
          : (_invoiceNameCtrl.text.trim().isNotEmpty
              ? _invoiceNameCtrl.text.trim()
              : null),
      fixedBillAmount: manualBill,
      voucherValue:
          isManual ? 0 : (double.tryParse(_voucherValueCtrl.text) ?? 0),
      voucherPeriod: _voucherPeriod,
      voucherStartDate: isManual ? null : _voucherStartDate,
      orderIndex: g.orderIndex,
      provider: _selectedProvider ?? g.provider,
      maxClients:
          _tier == 'tier1_4250' ? 7 : (_tier == 'tier2_smaller' ? 5 : g.maxClients),
      pointsMonthly:
          int.tryParse(_pointsMonthlyCtrl.text.trim()) ?? g.pointsMonthly,
      pointPrice: double.tryParse(_pointsValueCtrl.text.trim()) ?? g.pointPrice,
      extraClientFee: _tier.isNotEmpty ? 125 : g.extraClientFee,
      billingCycle: g.billingCycle,
      offerEndDate: g.offerEndDate,
      actualBillAmount: g.actualBillAmount,
      lineType: g.lineType,
      stickyNote: g.stickyNote,
      lastBillAmount: g.lastBillAmount,
      billDebt: newBillDebt,
      groupNotes: g.groupNotes,
      lastNotesMonth: g.lastNotesMonth,
      pendingPointsProfit: g.pendingPointsProfit,
      lastGiftResetMonth: g.lastGiftResetMonth,
      manualDueDate: isManual ? _manualDueDate : null,
      parentGroupId: _parentGroupId,
      // Phase 2 — Master Line fields
      ownerFullName: _ownerFullNameCtrl.text.trim().isNotEmpty
          ? _ownerFullNameCtrl.text.trim()
          : null,
      contractPhotoPath: _contractPhotoPath,
      mainLineAllocationGb:
          int.tryParse(_mainLineGbCtrl.text.trim()) ?? g.mainLineAllocationGb,
      totalMinutes:
          int.tryParse(_totalMinutesCtrl.text.trim()) ?? g.totalMinutes,
      tier: _tier,
      monthOnMeToggle: _monthOnMeToggle,
      fixedRateSystem: _fixedRateSystem,
      refundableInsurance:
          double.tryParse(_insuranceCtrl.text.trim()) ?? g.refundableInsurance,
      insuranceClaimDate: g.insuranceClaimDate,
      pointsResetDay: g.pointsResetDay,
      weCouponEnabled: _weCouponEnabled,
      weCouponDate: _weCouponDate,
      vodafoneRateType: _vodafoneRateType,
      extraBundles: g.extraBundles,
    ));
    Navigator.pop(context);
  }
}

class _TierBtn extends StatelessWidget {
  final String label, value, selected;
  final void Function(String) onTap;
  const _TierBtn({
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

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _ToggleRow({
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

class _PeriodBtn extends StatelessWidget {
  final String label, value, selected;
  final void Function(String) onTap;
  const _PeriodBtn(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? const Color(0xFF2E7D32) : AppColors.border),
        ),
        child: Center(
            child: Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: active ? Colors.white : AppColors.muted,
                    fontWeight: FontWeight.w700))),
      ),
    );
  }
}

class _FormulaPreview extends StatelessWidget {
  final double fixed, voucher;
  final String period;
  const _FormulaPreview(
      {required this.fixed, required this.voucher, required this.period});

  @override
  Widget build(BuildContext context) {
    final periodLabel = period == '1y' ? 'سنوياً' : 'كل 6 شهور';
    final total = fixed - voucher;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFA5D6A7))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📊 معادلة الشهر العادي:',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          Text('الإجمالي = $fixed - $voucher = ${total.toStringAsFixed(0)} ج',
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: total >= 0 ? const Color(0xFF2E7D32) : Colors.red)),
          Text('🎫 القسيمة تنزل $periodLabel',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
