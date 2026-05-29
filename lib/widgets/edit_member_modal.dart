// lib/widgets/edit_member_modal.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/phone_utils.dart';
import '../utils/image_utils.dart';
import 'common.dart';
import 'add_member_modal.dart' show AddPackageDialog, PackageManagerDialog;

class EditMemberModal extends StatefulWidget {
  final Member member;
  const EditMemberModal({super.key, required this.member});

  @override
  State<EditMemberModal> createState() => _EditMemberModalState();
}

class _EditMemberModalState extends State<EditMemberModal> {
  late TextEditingController _nameCtrl, _phoneCtrl, _phone2Ctrl;
  late TextEditingController _priceCtrl, _notesCtrl, _natIdCtrl, _addressCtrl;
  late TextEditingController _guarantorNameCtrl, _guarantorPhoneCtrl;

  late String _type;
  late String? _paymentFlag;
  late String? _selectedGroup;
  late bool _waPhone2;
  String? _date;
  String? _phoneError;
  Map<String, dynamic>? _selectedPackage;
  String? _natIdPhotoPath;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nameCtrl = TextEditingController(text: m.name);
    _phoneCtrl = TextEditingController(text: m.phone);
    _phone2Ctrl = TextEditingController(text: m.phone2 ?? '');
    _priceCtrl = TextEditingController(text: m.price.toStringAsFixed(0));
    _notesCtrl = TextEditingController(text: m.notes ?? '');
    _natIdCtrl = TextEditingController(text: m.natId ?? '');
    _addressCtrl = TextEditingController(text: m.address ?? '');
    _guarantorNameCtrl = TextEditingController(text: m.guarantorName ?? '');
    _guarantorPhoneCtrl = TextEditingController(text: m.guarantorPhone ?? '');

    _type = m.type;
    _paymentFlag = m.paymentFlag;
    _selectedGroup = m.gid;
    _waPhone2 = m.waPhone2;
    _date = m.date;
    _natIdPhotoPath = m.natIdPhotoPath;
  }

  void _validatePhone(String val, AppProvider prov) {
    final fmtErr = validatePhone(val);
    final allPhones = prov.db.members
        .where((x) => x.id != widget.member.id)
        .map((x) => x.phone)
        .toList();
    final dupErr = fmtErr == null ? checkDuplicate(val, allPhones) : null;
    setState(() => _phoneError = fmtErr ?? dupErr);
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

  void _onPackageSelected(Map<String, dynamic>? pkg) {
    setState(() {
      _selectedPackage = pkg;
      if (pkg != null) _priceCtrl.text = pkg['price'].toString();
    });
  }

  void _showPackageManagerDialog() {
    showDialog(
      context: context,
      builder: (_) => const PackageManagerDialog(),
    );
  }

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

  Future<void> _pickNatIdPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('📷 رفع صورة البطاقة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: Text('الكاميرا', style: GoogleFonts.cairo()),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: Text('المعرض', style: GoogleFonts.cairo()),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;
    final file = await ImageUtils.pickCompressed(source: source);
    if (file == null) return;
    setState(() => _natIdPhotoPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    // Match current package from allPackages on first build
    _selectedPackage ??= prov.db.allPackages
        .cast<Map<String, dynamic>?>()
        .firstWhere((p) => p?['name'] == widget.member.package,
            orElse: () => null);

    // Pull from dedicated guarantors list + fallback to member-based guarantors
    final seenPhones = <String>{};
    final guarantorEntries = <MapEntry<String, String>>[];
    for (final g in prov.db.guarantors) {
      if (seenPhones.add(g.phone)) {
        guarantorEntries.add(MapEntry(g.phone, g.name));
      }
    }
    for (final m in prov.db.members) {
      if (m.id != widget.member.id &&
          m.guarantorPhone != null &&
          m.guarantorName != null) {
        if (seenPhones.add(m.guarantorPhone!)) {
          guarantorEntries.add(MapEntry(m.guarantorPhone!, m.guarantorName!));
        }
      }
    }
    final existingGuarantors = guarantorEntries;

    return ModalShell(
      title: '✏️ تعديل العميل',
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(
          onPressed: _phoneError == null ? _save : null,
          child: Text('حفظ',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        ),
      ],
      children: [
        // ── Name ──
        AppFormField(label: 'الاسم', controller: _nameCtrl),
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

        // ── Phone2 + WA toggle ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📱 رقم تاني (اختياري)',
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
                    hintText: 'رقم إضافي للتواصل أو الواتساب',
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
        const SizedBox(height: 8),
        // WA default selector
        StatefulBuilder(
            builder: (ctx, ss) => GestureDetector(
                  onTap: () => ss(() => _waPhone2 = !_waPhone2),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFF25D366).withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.chat,
                          size: 16, color: Color(0xFF25D366)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        'رقم الواتساب الافتراضي: ${_waPhone2 ? 'الرقم التاني' : 'رقم الخط'}',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2e7d32)),
                      )),
                      Icon(
                        _waPhone2 ? Icons.toggle_on : Icons.toggle_off,
                        color: _waPhone2
                            ? const Color(0xFF25D366)
                            : AppColors.muted,
                        size: 28,
                      ),
                    ]),
                  ),
                )),
        const SizedBox(height: 12),

        // ── Package dropdown ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('الباقة',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showPackageManagerDialog(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('📦 إدارة الباقات',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: AppColors.blue2,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
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
                _onPackageSelected(Map<String, dynamic>.from(pkg));
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
                child: Text(
                  '✅ ${_selectedPackage!['gb']} جيجا  •  ${_selectedPackage!['price']} ج/شهر',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.green2,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Price + Group ──
        Row(children: [
          Expanded(
              child: AppFormField(
            label: 'سعر الاشتراك / شهر',
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          )),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المجموعة',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                initialValue: prov.db.groups.any((g) => g.id == _selectedGroup)
                    ? _selectedGroup
                    : null,
                decoration: const InputDecoration(),
                isExpanded: true,
                items: prov.db.groups.map((g) {
                  final rem = prov.db.groupRemainingGb(g.id);
                  return DropdownMenuItem(
                    value: g.id,
                    child: Row(children: [
                      Expanded(
                          child: Text(g.phone,
                              style: GoogleFonts.cairo(fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                      Text(' $rem GB',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color:
                                  rem < 10 ? AppColors.red : AppColors.green)),
                    ]),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedGroup = v),
              ),
            ],
          )),
        ]),
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
          )),
          const SizedBox(width: 10),
          Expanded(
              child: AppDateField(
            label: 'تاريخ الانضمام',
            initialValue: _date,
            onChanged: (v) => _date = v,
          )),
        ]),
        const SizedBox(height: 12),

        // ── National ID + Photo ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الرقم القومي',
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _natIdCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [NatIdInputFormatter()],
                  maxLength: 14,
                  style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text),
                  decoration: const InputDecoration(counterText: ''),
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
                  onPressed: _pickNatIdPhoto,
                  icon: Icon(
                    _natIdPhotoPath != null ? Icons.check_circle : Icons.camera_alt,
                    color: _natIdPhotoPath != null ? AppColors.green : AppColors.blue2,
                  ),
                  tooltip: 'رفع صورة البطاقة',
                ),
              ),
            ]),
            if (_natIdPhotoPath != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_natIdPhotoPath!), fit: BoxFit.contain),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_natIdPhotoPath!),
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
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
              Text('🤝 الكفيل',
                  style: GoogleFonts.cairo(
                      color: AppColors.blue2,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              const SizedBox(height: 10),
              if (existingGuarantors.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: null,
                  decoration: const InputDecoration(),
                  hint: Text('اختر كفيل موجود',
                      style: GoogleFonts.cairo(fontSize: 13)),
                  items: existingGuarantors
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value,
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
                        label: 'اسم الكفيل', controller: _guarantorNameCtrl)),
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
                            style: GoogleFonts.cairo(
                                fontSize: 13, color: AppColors.text),
                            decoration: const InputDecoration(counterText: ''),
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
    if (_nameCtrl.text.trim().isEmpty || _selectedGroup == null) return;
    final prov = context.read<AppProvider>();
    final m = widget.member;
    prov.editMember(Member(
      id: m.id,
      gid: _selectedGroup!,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      phone2:
          _phone2Ctrl.text.trim().isNotEmpty ? _phone2Ctrl.text.trim() : null,
      waPhone2: _waPhone2,
      package: _selectedPackage?['name'] as String? ?? m.package,
      gb: _selectedPackage?['gb'] as int? ?? m.gb,
      price: double.tryParse(_priceCtrl.text.trim()) ?? m.price,
      balance: m.balance,
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
      invoiceName: m.invoiceName,
      lineType: m.lineType,
      fixedMonthlyAmount: m.fixedMonthlyAmount,
      lastInvoiceDate: m.lastInvoiceDate,
      paymentFlag: _paymentFlag,
      log: m.log,
      files: m.files,
      invoiceLog: m.invoiceLog,
      natIdPhotoPath: _natIdPhotoPath,
    ));
    Navigator.pop(context);
  }
}
