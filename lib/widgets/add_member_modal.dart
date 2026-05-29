// lib/widgets/add_member_modal.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/phone_utils.dart';
import '../utils/image_utils.dart';
import 'common.dart';

class AddMemberModal extends StatefulWidget {
  final String? preselectedGroup;
  const AddMemberModal({super.key, this.preselectedGroup});

  @override
  State<AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends State<AddMemberModal> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _natIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _guarantorNameCtrl = TextEditingController();
  final _guarantorPhoneCtrl = TextEditingController();

  String? _selectedGroup;
  String _type = 'regular';
  String? _paymentFlag;
  String? _date;
  String? _phoneError;
  String? _guarantorPhoneError;
  String? _idPhotoPath;
  Map<String, dynamic>? _selectedPackage; // {name, gb, price}

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.preselectedGroup;
  }

  List<String> _allPhones(AppProvider prov) {
    final phones = <String>[];
    for (final m in prov.db.members) {
      phones.add(m.phone);
    }
    for (final g in prov.db.groups) {
      phones.add(g.phone);
    }
    for (final w in prov.db.workNums) {
      phones.add(w.phone);
    }
    for (final e in prov.db.waitlist) {
      phones.add(e.phone);
      if (e.phone2 != null) phones.add(e.phone2!);
    }
    return phones;
  }

  void _validatePhone(String val, AppProvider prov) {
    final fmtErr = validatePhone(val);
    final dupErr =
        fmtErr == null ? checkDuplicate(val, _allPhones(prov)) : null;
    setState(() => _phoneError = fmtErr ?? dupErr);
  }

  void _validateGuarantorPhone(String val, AppProvider prov) {
    final fmtErr = validatePhone(val);
    setState(() => _guarantorPhoneError = fmtErr);
  }

  Future<void> _pickContactPhone(
      TextEditingController controller, AppProvider prov) async {
    try {
      if (!await FlutterContacts.requestPermission()) {
        if (!mounted) return;
        AppSnackbar.show(context, '⚠️ الرجاء السماح للوصول إلى جهات الاتصال');
        return;
      }
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;
      final full = await FlutterContacts.getContact(contact.id);
      final rawPhone = full?.phones.firstOrNull?.number.trim() ?? '';
      if (rawPhone.isEmpty) {
        if (!mounted) return;
        AppSnackbar.show(context, '⚠️ جهة الاتصال المختارة ليس بها رقم');
        return;
      }
      controller.text = normalizeEgyptPhone(rawPhone);
      if (controller == _phoneCtrl) _validatePhone(controller.text, prov);
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = full?.displayName ?? '';
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(context, '⚠️ لم يتم اختيار جهة الاتصال');
    }
  }

  Future<void> _pickIdPhoto() async {
    final picked = await ImageUtils.pickCompressed(source: ImageSource.gallery);
    if (picked != null) setState(() => _idPhotoPath = picked.path);
  }

  Future<void> _captureIdPhoto() async {
    final picked = await ImageUtils.pickCompressed(source: ImageSource.camera);
    if (picked != null) setState(() => _idPhotoPath = picked.path);
  }

  void _onPackageSelected(Map<String, dynamic>? pkg) {
    setState(() {
      _selectedPackage = pkg;
      if (pkg != null) {
        _priceCtrl.text = pkg['price'].toString();
      }
    });
  }

  void _showPackageManagerDialog(AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => const PackageManagerDialog(),
    );
  }

  /// يفتح dialog مدمج لإضافة باقة مخصصة من جوة الفورم،
  /// يتحفظ في الـ DB ويتختار تلقائياً للعميل الحالي.
  void _showAddCustomPackageInline(AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AddPackageDialog(
        onSave: (gb, price, label) {
          final name = buildPackageName(gb, price, label);
          final pkg = {
            'name': name,
            'gb': gb,
            'price': price,
            'label': label,
          };
          prov.addCustomPackage(pkg);
          _onPackageSelected(pkg);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    final seenPhones = <String>{};
    final guarantorEntries = <MapEntry<String, String>>[];
    for (final g in prov.db.guarantors) {
      if (seenPhones.add(g.phone)) guarantorEntries.add(MapEntry(g.phone, g.name));
    }
    for (final m in prov.db.members) {
      if (m.guarantorPhone != null && m.guarantorName != null) {
        if (seenPhones.add(m.guarantorPhone!)) {
          guarantorEntries.add(MapEntry(m.guarantorPhone!, m.guarantorName!));
        }
      }
    }
    final existingGuarantors = guarantorEntries;

    return ModalShell(
      title: '👤 إضافة عميل جديد',
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
        // ── Name ──
        AppFormField(
            label: 'الاسم', controller: _nameCtrl, hint: 'اسم العميل الكامل'),
        const SizedBox(height: 12),

        // ── Phone ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم الموبايل',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  onChanged: (v) => _validatePhone(v, prov),
                  inputFormatters: [PhoneInputFormatter()],
                  style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: '01xxxxxxxxx',
                    hintStyle:
                        GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _pickContactPhone(_phoneCtrl, prov),
                  icon: const Icon(Icons.contacts, color: AppColors.blue2),
                  tooltip: 'استيراد من جهات الاتصال',
                ),
              ),
            ]),
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

        // ── Phone2 (WhatsApp) ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📱 رقم الواتساب (اختياري)',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _phone2Ctrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [PhoneInputFormatter()],
                  style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'لو مختلف عن رقم الخط',
                    hintStyle:
                        GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _pickContactPhone(_phone2Ctrl, prov),
                  icon: const Icon(Icons.contacts, color: AppColors.blue2),
                  tooltip: 'استيراد من جهات الاتصال',
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),

        // ── Package dropdown ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('الباقة',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showPackageManagerDialog(prov),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('📦 إدارة الباقات',
                        style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: AppColors.blue2,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: _selectedPackage?['name'] as String?,
              decoration: const InputDecoration(),
              hint: Text('اختر الباقة', style: GoogleFonts.cairo(fontSize: 13)),
              isExpanded: true,
              items: [
                ...() {
                  final seen = <String>{};
                  return prov.db.allPackages
                      .where((pkg) => seen.add(pkg['name'] as String))
                      .map((pkg) {
                    final label = (pkg['label'] as String?)?.trim() ?? '';
                    final gb = pkg['gb'];
                    final price = pkg['price'];
                    return DropdownMenuItem<String>(
                      value: pkg['name'] as String,
                      child: Row(children: [
                        if (label.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.blueLight,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('[$label]',
                                style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.blue2)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text('$gb GB',
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        const Text('⬅️', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text('$price ج/شهر',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.green2,
                                fontWeight: FontWeight.w700)),
                      ]),
                    );
                  }).toList();
                }(),
                DropdownMenuItem<String>(
                  value: '__ADD_NEW__',
                  child: Row(children: [
                    const Icon(Icons.add_circle,
                        color: AppColors.blue2, size: 18),
                    const SizedBox(width: 6),
                    Text('إضافة باقة مخصصة جديدة',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.blue2)),
                  ]),
                ),
              ],
              onChanged: (name) {
                if (name == null) return;
                if (name == '__ADD_NEW__') {
                  _showAddCustomPackageInline(prov);
                  return;
                }
                final pkg =
                    prov.db.allPackages.firstWhere((p) => p['name'] == name);
                _onPackageSelected(pkg);
              },
            ),
            if (_selectedPackage != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        '✅ ${_selectedPackage!['gb']} جيجا  •  ${_selectedPackage!['price']} ج/شهر',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.green2,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Price ──
        AppFormField(
          label: 'السعر/شهر',
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          inputFormatters: [PhoneInputFormatter()],
        ),
        const SizedBox(height: 12),

        // ── Group ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المجموعة',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: _selectedGroup,
              decoration: const InputDecoration(),
              hint:
                  Text('اختر المجموعة', style: GoogleFonts.cairo(fontSize: 13)),
              isExpanded: true,
              items: prov.db.groups.map((g) {
                final rem = prov.db.groupRemainingGb(g.id);
                return DropdownMenuItem(
                  value: g.id,
                  child: Row(
                    children: [
                      Text(g.phone,
                          style: GoogleFonts.cairo(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text('متبقي: $rem GB',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color:
                                  rem < 10 ? AppColors.red : AppColors.green)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedGroup = v),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Payment Flag ──
        Text('🚦 تصنيف الدفع', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        FlagSelector(value: _paymentFlag, onChanged: (v) => setState(() => _paymentFlag = v)),
        const SizedBox(height: 12),

        // ── Type + Date ──
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نوع العميل',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(),
                  items: [
                    DropdownMenuItem(
                        value: 'regular',
                        child: Text('👤 عادي',
                            style: GoogleFonts.cairo(fontSize: 13))),
                    DropdownMenuItem(
                        value: 'guest',
                        child: Text('🧳 ضيف',
                            style: GoogleFonts.cairo(fontSize: 13))),
                    DropdownMenuItem(
                        value: 'landline',
                        child: Text('☎️ أرضي',
                            style: GoogleFonts.cairo(fontSize: 13))),
                    DropdownMenuItem(
                        value: 'homeforgee',
                        child: Text('🏠 هوم فور جي',
                            style: GoogleFonts.cairo(fontSize: 13))),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'regular'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: AppDateField(
                  label: 'تاريخ الانضمام',
                  onChanged: (v) => _date = v)),
        ]),
        const SizedBox(height: 12),

        // ── National ID + Photo ──
        Row(children: [
          Expanded(
            child: AppFormField(
              label: 'الرقم القومي',
              controller: _natIdCtrl,
              hint: '14 رقم',
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              inputFormatters: [NatIdInputFormatter()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('صورة الإثبات',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickIdPhoto,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: _idPhotoPath != null
                                ? AppColors.greenLight
                                : const Color(0xFFf8fafc),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _idPhotoPath != null
                                    ? AppColors.green
                                    : AppColors.border),
                          ),
                          child: _idPhotoPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(File(_idPhotoPath!),
                                      fit: BoxFit.cover),
                                )
                              : Center(
                                  child: Text('🖼 معرض',
                                      style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: AppColors.muted))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _captureIdPhoto,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.blueMid),
                        ),
                        child: const Center(
                            child: Text('📷', style: TextStyle(fontSize: 20))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Address ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 العنوان',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'العنوان بالتفصيل',
                hintStyle:
                    GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Notes ──
        AppFormField(label: 'ملاحظات', controller: _notesCtrl),
        const SizedBox(height: 12),

        // ── Guarantor ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.blueMid, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🤝 الكفيل (اختياري)',
                  style: GoogleFonts.cairo(
                      color: AppColors.blue2,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              const SizedBox(height: 4),
              Text('يمكنك اختيار كفيل موجود أو كتابة كفيل جديد',
                  style:
                      GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 10),
              if (existingGuarantors.isNotEmpty) ...[
                Text('كفلاء موجودون',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  initialValue: null,
                  decoration: const InputDecoration(),
                  hint: Text('اختر كفيل موجود',
                      style: GoogleFonts.cairo(fontSize: 13)),
                  items: existingGuarantors
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value} — ${e.key}',
                                style: GoogleFonts.cairo(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (phone) {
                    if (phone == null) return;
                    final g =
                        existingGuarantors.firstWhere((e) => e.key == phone);
                    setState(() {
                      _guarantorPhoneCtrl.text = g.key;
                      _guarantorNameCtrl.text = g.value;
                    });
                  },
                ),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(
                    child: AppFormField(
                        label: 'اسم الكفيل',
                        controller: _guarantorNameCtrl,
                        hint: 'الاسم')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رقم الكفيل',
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _guarantorPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            inputFormatters: [PhoneInputFormatter()],
                            onChanged: (v) =>
                                _validateGuarantorPhone(v, prov),
                            style: GoogleFonts.cairo(
                                fontSize: 13, color: AppColors.text),
                            decoration: InputDecoration(
                              hintText: '01xxxxxxxxx',
                              hintStyle: GoogleFonts.cairo(
                                  fontSize: 13, color: AppColors.muted),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () =>
                                _pickContactPhone(_guarantorPhoneCtrl, prov),
                            icon: const Icon(Icons.contacts,
                                color: AppColors.blue2),
                            tooltip: 'استيراد من جهات الاتصال',
                          ),
                        ),
                      ]),
                      if (_guarantorPhoneError != null)
                        Text(_guarantorPhoneError!,
                            style: GoogleFonts.cairo(
                                color: AppColors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(context, '⚠️ الاسم مطلوب');
      return;
    }
    if (_selectedGroup == null) {
      AppSnackbar.show(context, '⚠️ اختر المجموعة');
      return;
    }
    if (_phoneError != null) {
      AppSnackbar.show(context, '⚠️ $_phoneError');
      return;
    }
    if (_guarantorPhoneError != null) {
      AppSnackbar.show(context, '⚠️ رقم الكفيل: $_guarantorPhoneError');
      return;
    }
    final prov = context.read<AppProvider>();
    // Phase 3 — Over-Allocation Protection
    final wantGb = (_selectedPackage?['gb'] as int?) ?? 0;
    if (wantGb > 0 && _type == 'regular') {
      final remaining = prov.db.groupRemainingGb(_selectedGroup!);
      if (wantGb > remaining) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('⚠️ السعة غير كافية',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            content: Text(
                'عذراً، المتبقي الحر $remaining جيجا والباقة المختارة $wantGb جيجا.\n'
                'يرجى ترقية باقة الخط الرئيسي أو شحن باقة إضافية أو نقل العميل لمجموعة أخرى.',
                style: GoogleFonts.cairo()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('حسناً', style: GoogleFonts.cairo())),
            ],
          ),
        );
        return;
      }
    }
    prov.addMember(Member(
      id: prov.newMemberId(),
      gid: _selectedGroup!,
      name: name,
      phone: phone,
      phone2:
          _phone2Ctrl.text.trim().isNotEmpty ? _phone2Ctrl.text.trim() : null,
      package: _selectedPackage?['name'] as String? ?? '',
      gb: _selectedPackage?['gb'] as int? ?? 0,
      price: double.tryParse(_priceCtrl.text.trim()) ??
          (_selectedPackage?['price'] as num?)?.toDouble() ??
          0,
      balance: 0,
      type: _type,
      date: _date,
      natId: _natIdCtrl.text.trim().isNotEmpty ? _natIdCtrl.text.trim() : null,
      address:
          _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      guarantorName: _guarantorNameCtrl.text.trim().isNotEmpty
          ? _guarantorNameCtrl.text.trim()
          : null,
      guarantorPhone: _guarantorPhoneCtrl.text.trim().isNotEmpty
          ? _guarantorPhoneCtrl.text.trim()
          : null,
      paymentFlag: _paymentFlag,
    ));
    Navigator.pop(context);
    AppSnackbar.show(context, '✅ تمت إضافة $name');
  }
}

// ─── Package Manager Dialog ────────────────────────────────────────
/// Shows all packages with ability to add new, edit price/GB, and delete custom.
class PackageManagerDialog extends StatefulWidget {
  const PackageManagerDialog({super.key});
  @override
  State<PackageManagerDialog> createState() => _PackageManagerDialogState();
}

class _PackageManagerDialogState extends State<PackageManagerDialog> {
  static const _defaultNames = {
    '10 جيجا', '20 جيجا', '30 جيجا', '40 جيجا', '50 جيجا',
  };

  void _editPackage(AppProvider prov, Map<String, dynamic> pkg) {
    final oldName = pkg['name'] as String;
    showDialog(
      context: context,
      builder: (_) => AddPackageDialog(
        initialGb: pkg['gb'] as int,
        initialPrice: (pkg['price'] as num).toDouble(),
        initialLabel: pkg['label'] as String? ?? '',
        onSave: (gb, price, label) {
          // امسح القديم لو الاسم اتغيّر، ضيف الجديد
          final newName = buildPackageName(gb, price, label);
          if (newName != oldName) {
            prov.deleteCustomPackageByName(oldName);
          }
          prov.addCustomPackage({
            'name': newName,
            'gb': gb,
            'price': price,
            'label': label,
          });
        },
      ),
    );
  }

  void _addNew(AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AddPackageDialog(
        onSave: (gb, price, label) {
          prov.addCustomPackage({
            'name': buildPackageName(gb, price, label),
            'gb': gb,
            'price': price,
            'label': label,
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final all = prov.db.allPackages;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('📦 إدارة الباقات',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.blue2)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...all.map((pkg) {
              final name = pkg['name'] as String;
              final gb = pkg['gb'] as int;
              final price = (pkg['price'] as num).toDouble();
              final isDefault = _defaultNames.contains(name) &&
                  !prov.db.customPackages.any((c) => c['name'] == name);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDefault ? AppColors.blueLight : AppColors.greenLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDefault ? AppColors.blueMid : AppColors.green),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$gb GB',
                              style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.blue2)),
                          Text('$price ج/شهر',
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: AppColors.green2)),
                        ]),
                  ),
                  IconButton(
                    onPressed: () => _editPackage(prov, pkg),
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.blue2),
                    tooltip: 'تعديل',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  if (!isDefault)
                    IconButton(
                      onPressed: () {
                        prov.deleteCustomPackageByName(name);
                      },
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.red),
                      tooltip: 'حذف',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (isDefault)
                    const SizedBox(width: 22),
                ]),
              );
            }),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addNew(prov),
                icon: const Icon(Icons.add, size: 16),
                label:
                    Text('إضافة باقة جديدة', style: GoogleFonts.cairo(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('تم',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    );
  }
}

// ─── Shared Add-Package Dialog ────────────────────────────────────
class AddPackageDialog extends StatefulWidget {
  final void Function(int gb, double price, String label) onSave;
  final int? initialGb;
  final double? initialPrice;
  final String? initialLabel;
  const AddPackageDialog({
    super.key,
    required this.onSave,
    this.initialGb,
    this.initialPrice,
    this.initialLabel,
  });
  @override
  State<AddPackageDialog> createState() => AddPackageDialogState();
}

class AddPackageDialogState extends State<AddPackageDialog> {
  static const _gbOptions = [5, 10, 12, 15, 20, 25, 30, 40, 50, 60, 100, 200];
  static const _defaultPrices = {
    10: 190, 20: 260, 30: 320, 40: 400, 50: 475, 60: 600, 100: 900, 200: 1500
  };

  late int _selectedGb;
  late TextEditingController _priceCtrl;
  late TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _selectedGb = widget.initialGb ?? 20;
    final initPrice =
        widget.initialPrice?.toStringAsFixed(0) ?? '${_defaultPrices[_selectedGb] ?? ''}';
    _priceCtrl = TextEditingController(text: initPrice);
    _labelCtrl = TextEditingController(text: widget.initialLabel ?? '');
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        widget.initialGb != null ? '✏️ تعديل الباقة' : '➕ إضافة باقة جديدة',
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AppColors.blue2),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // GB selector
            Align(
              alignment: Alignment.centerRight,
              child: Text('اختر الجيجابايت',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _gbOptions.map((gb) {
                final sel = _selectedGb == gb;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedGb = gb;
                    if (_defaultPrices[gb] != null) {
                      _priceCtrl.text = '${_defaultPrices[gb]}';
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.blue2 : AppColors.blueLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.blue2 : AppColors.border),
                    ),
                    child: Text('$gb GB',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.blue2,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Price field
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cairo(
                  fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'السعر (قابل للتعديل)',
                labelStyle: GoogleFonts.cairo(fontSize: 12),
                prefixIcon: const Icon(Icons.monetization_on_outlined,
                    color: AppColors.green),
                suffixText: 'ج',
                filled: true,
                fillColor: AppColors.greenLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            // Label field
            TextField(
              controller: _labelCtrl,
              style: GoogleFonts.cairo(
                  fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'وصف الباقة (اختياري)',
                labelStyle: GoogleFonts.cairo(fontSize: 12),
                hintText: 'مثال: نظام خاص، عرض قديم',
                hintStyle: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.muted),
                prefixIcon:
                    const Icon(Icons.label_outline, color: AppColors.blue2),
                filled: true,
                fillColor: AppColors.blueLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: Text('إلغاء',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          onPressed: () {
            final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
            if (price <= 0) return;
            widget.onSave(_selectedGb, price, _labelCtrl.text.trim());
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('حفظ',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    );
  }
}
