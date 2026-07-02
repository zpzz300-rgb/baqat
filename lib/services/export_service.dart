// lib/services/export_service.dart
// تصدير البيانات إلى Excel أو PDF
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';

class ExportService {
  // ── helpers ──────────────────────────────────────────────────────
  static String _fDate(String? d) => d?.isNotEmpty == true ? d! : '-';
  static String _fNum(double v) =>
      v == 0 ? '-' : intl.NumberFormat('#,##0.##').format(v);

  static String _lastPayDate(Member m) {
    final pays = m.log
        .where((e) =>
            (e['type']?.toString().toLowerCase().contains('pay') == true) ||
            (e['action']?.toString().toLowerCase().contains('دفع') == true) ||
            (e['action']?.toString().toLowerCase().contains('pay') == true))
        .toList();
    if (pays.isEmpty) return '-';
    pays.sort((a, b) =>
        (b['date'] ?? b['time'] ?? '').compareTo(a['date'] ?? a['time'] ?? ''));
    return pays.first['date'] ?? pays.first['time'] ?? '-';
  }

  static int _monthsSubscribed(String? startDate) {
    if (startDate == null || startDate.isEmpty) return 0;
    final start = DateTime.tryParse(startDate);
    if (start == null) return 0;
    final now = DateTime.now();
    return (now.year - start.year) * 12 + (now.month - start.month);
  }

  // ── أعمدة قالب الاستيراد (ثابتة — يعتمد عليها الاستيراد) ──────────
  static const importHeaders = [
    'الاسم',
    'رقم العميل',
    'رقم الخط/المجموعة',
    'الباقة',
    'مبلغ الباقة',
    'مديونية قديمة',
    'الشركة',
    'ملاحظات',
  ];

  // ── تصدير قالب فاضي للأونبوردنج (عملاء + مثال + تعليمات + باقات) ──
  static Future<void> exportTemplateExcel(
      BuildContext context, AppProvider prov) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // شيت العملاء: عناوين + صف مثال
    final sheet = excel['العملاء'];
    sheet.appendRow(importHeaders.map((h) => TextCellValue(h)).toList());
    sheet.appendRow(<CellValue>[
      TextCellValue('محمد أحمد (مثال — امسح الصف)'),
      TextCellValue('01000000000'),
      TextCellValue('01111111111'),
      TextCellValue('20 جيجا'),
      const DoubleCellValue(250),
      const DoubleCellValue(0),
      TextCellValue('etisalat'),
      TextCellValue('عميل تجريبي'),
    ]);

    // شيت التعليمات
    final help = excel['تعليمات'];
    final lines = [
      'إزاي تملأ الملف:',
      '• كل صف = عميل واحد.',
      '• «رقم الخط/المجموعة» = الخط الرئيسي اللي العميل تحته؛ لو رقم جديد البرنامج هيعمل المجموعة تلقائياً.',
      '• «مبلغ الباقة» = اشتراك العميل الشهري بالجنيه.',
      '• «مديونية قديمة» = اللي على العميل من قبل (موجب) — هتتسجّل كمديونية.',
      '• «الشركة» لو سبتها فاضية بتتحسب «اتصالات» تلقائياً (etisalat).',
      '   غيّرها بس لو الخط مش اتصالات: vodafone / orange / we.',
      '• امسح صف المثال قبل الاستيراد.',
      '• الباقات المتاحة مكتوبة في شيت «الباقات».',
    ];
    for (final l in lines) {
      help.appendRow([TextCellValue(l)]);
    }

    // شيت الباقات (مرجع — تقدر تربط Data Validation عليه)
    // الافتراضي باقات اتصالات بالجيجا، + أي باقات موجودة عندك
    final pkgSheet = excel['الباقات'];
    pkgSheet.appendRow([TextCellValue('الباقات المتاحة')]);
    const defaultPkgs = ['10 جيجا', '20 جيجا', '30 جيجا', '40 جيجا'];
    final existing = <String>{
      for (final m in prov.db.members)
        if (m.package.trim().isNotEmpty) m.package.trim()
    };
    final packages = <String>{...defaultPkgs, ...existing}.toList();
    for (final p in packages) {
      pkgSheet.appendRow([TextCellValue(p)]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      _snack(context, 'فشل إنشاء القالب');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/telecom_template_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],
        text: '📄 قالب استيراد العملاء — باقات الاتصالات');
  }

  /// قراءة ملف قالب وإرجاع صفوف منظّمة (للمعاينة قبل الاستيراد).
  /// كل صف: {name, phone, groupPhone, package, price, debt, provider, notes}
  static List<Map<String, dynamic>> parseTemplate(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    // نفضّل شيت «العملاء»، وإلا أول شيت
    final sheet = excel.tables['العملاء'] ?? excel.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) return [];
    String cell(List<Data?> r, int i) =>
        (i < r.length ? r[i]?.value : null)?.toString().trim() ?? '';
    double num_(List<Data?> r, int i) {
      final v = cell(r, i).replaceAll(',', '');
      return double.tryParse(v) ?? 0;
    }

    final out = <Map<String, dynamic>>[];
    for (var ri = 1; ri < rows.length; ri++) {
      // تخطّي الهيدر (0) + صف المثال
      final r = rows[ri];
      final name = cell(r, 0);
      final phone = cell(r, 1);
      final groupPhone = cell(r, 2);
      if (name.isEmpty && phone.isEmpty && groupPhone.isEmpty) continue;
      if (name.contains('مثال')) continue;
      out.add({
        'name': name,
        'phone': phone,
        'groupPhone': groupPhone,
        'package': cell(r, 3),
        'price': num_(r, 4),
        'debt': num_(r, 5),
        'provider': cell(r, 6),
        'notes': cell(r, 7),
      });
    }
    return out;
  }

  // ── Excel export ─────────────────────────────────────────────────
  static Future<void> exportExcel(
      BuildContext context, AppProvider prov) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildMembersSheet(excel, prov, deleted: false);
    _buildMembersSheet(excel, prov, deleted: true);
    _buildGroupsSheet(excel, prov);
    _buildMainLinesSheet(excel, prov);

    final bytes = excel.save();
    if (bytes == null) {
      _snack(context, 'فشل إنشاء الملف');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/telecom_export_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
  }

  // ── Profit report Excel export ──────────────────────────────────
  static Future<void> exportProfitReport(
      BuildContext context, AppProvider prov) async {
    final db = prov.db;
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // ملخص
    final monthlyIncome = db.members.fold<double>(0, (s, m) => s + m.price);
    final billing = db.totalBillingProfit;
    final gift = db.groups.fold<double>(0, (s, g) => s + g.giftProfit);
    final rental = db.rentals
        .where((r) => r.status == 'active')
        .fold<double>(0, (s, r) => s + r.rent);
    final guest = db.guestUsers.fold<double>(0, (s, g) => s + g.profit);
    final points = db.groups.fold<double>(0, (s, g) => s + g.pendingPointsProfit);
    final debt = db.totalDebt;
    final s1 = excel['ملخص'];
    s1.appendRow([TextCellValue('البند'), TextCellValue('القيمة (ج)')]);
    void add(String k, double v) =>
        s1.appendRow([TextCellValue(k), DoubleCellValue(v)]);
    add('دخل شهري متوقّع', monthlyIncome);
    add('ربح الفواتير', billing);
    add('ربح الهدايا', gift);
    add('دخل الإيجارات', rental);
    add('ربح الضيوف', guest);
    add('نقاط تراكمية', points);
    add('إجمالي المديونيات', debt);
    add('صافي الربح النهائي', billing + gift + rental + guest + points);

    // المجموعات
    final s2 = excel['المجموعات'];
    s2.appendRow([
      'الرقم', 'المالك', 'المزود', 'العملاء', 'دخل', 'فاتورة', 'ربح', 'ديون'
    ].map((h) => TextCellValue(h)).toList());
    for (final g in db.groups) {
      final members = db.membersOf(g.id);
      final income = members.fold<double>(0, (s, m) => s + m.price);
      final bill = g.fixedBillAmount > 0 ? g.fixedBillAmount : (g.actualBillAmount ?? 0);
      s2.appendRow(<CellValue>[
        TextCellValue(g.phone),
        TextCellValue(g.ownerName ?? '-'),
        TextCellValue(g.provider ?? '-'),
        IntCellValue(members.length),
        DoubleCellValue(income),
        DoubleCellValue(bill),
        DoubleCellValue(db.groupProfit(g.id)),
        DoubleCellValue(db.groupDebt(g.id)),
      ]);
    }

    // العملاء
    final s3 = excel['العملاء'];
    s3.appendRow(['الاسم', 'الرقم', 'الباقة', 'الاشتراك', 'الرصيد']
        .map((h) => TextCellValue(h))
        .toList());
    for (final m in db.members) {
      s3.appendRow(<CellValue>[
        TextCellValue(m.name),
        TextCellValue(m.phone),
        TextCellValue(m.package),
        DoubleCellValue(m.price),
        DoubleCellValue(m.balance),
      ]);
    }

    // لقطات الجرد
    final snaps = prov.profitSnapshots;
    if (snaps.isNotEmpty) {
      final s4 = excel['الجرد الشهري'];
      s4.appendRow(['الشهر', 'دخل', 'ربح فواتير', 'هدايا', 'إيجارات', 'ضيوف', 'نقاط', 'ديون', 'صافي']
          .map((h) => TextCellValue(h))
          .toList());
      for (final s in snaps) {
        double g(String k) => (s[k] as num?)?.toDouble() ?? 0;
        s4.appendRow(<CellValue>[
          TextCellValue(s['month']?.toString() ?? ''),
          DoubleCellValue(g('income')),
          DoubleCellValue(g('billing')),
          DoubleCellValue(g('gift')),
          DoubleCellValue(g('rental')),
          DoubleCellValue(g('guest')),
          DoubleCellValue(g('points')),
          DoubleCellValue(g('debt')),
          DoubleCellValue(g('net')),
        ]);
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      _snack(context, 'فشل إنشاء التقرير');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/telecom_profit_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: '💰 تقرير الأرباح');
  }

  // ── Guarantors Excel export ─────────────────────────────────────
  static Future<void> exportGuarantorsExcel(
      BuildContext context, AppProvider prov) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['الكفلاء'];
    const headers = [
      'اسم الكفيل', 'رقم الكفيل', 'رقم 2', 'النوع', 'حد الكفالة',
      'عدد العملاء', 'عدد المدينين', 'إجمالي المديونية', 'نسبة السداد %', 'العملاء',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // تجميع العملاء تحت كل كفيل (بالرقم) — نفس منطق شاشة الكفلاء
    final byPhone = <String, List<Member>>{};
    for (final m in prov.db.members) {
      final p = (m.guarantorPhone ?? '').trim();
      if (p.isEmpty) continue;
      byPhone.putIfAbsent(p, () => []).add(m);
    }
    final phones = <String>{
      ...prov.db.guarantors.map((g) => g.phone),
      ...byPhone.keys,
    };
    for (final phone in phones) {
      final g = prov.db.guarantors.cast<Guarantor?>()
          .firstWhere((x) => x!.phone == phone, orElse: () => null);
      final mems = byPhone[phone] ?? [];
      final name = g?.name ?? (mems.isNotEmpty ? (mems.first.guarantorName ?? 'كفيل') : 'كفيل');
      final debtors = mems.where((m) => m.balance < 0).length;
      final totalDebt = mems.fold<double>(0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));
      final rate = mems.isEmpty ? 100 : ((mems.length - debtors) / mems.length * 100).round();
      sheet.appendRow(<CellValue>[
        TextCellValue(name),
        TextCellValue(phone),
        TextCellValue(g?.phone2 ?? '-'),
        TextCellValue(g?.typeLabel ?? '👤 شخصي'),
        TextCellValue(g?.maxDebt != null ? g!.maxDebt!.toStringAsFixed(0) : '-'),
        IntCellValue(mems.length),
        IntCellValue(debtors),
        DoubleCellValue(totalDebt),
        IntCellValue(rate),
        TextCellValue(mems.map((m) => '${m.name} (${m.balance.toStringAsFixed(0)})').join(' • ')),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) { _snack(context, 'فشل إنشاء الملف'); return; }
    final dir = await getApplicationDocumentsDirectory();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/telecom_guarantors_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: '🤝 كشف الكفلاء');
  }

  // ── Invoices-only Excel export ──────────────────────────────────
  static Future<void> exportInvoicesExcel(
      BuildContext context, AppProvider prov) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    _buildInvoicesSheet(excel, prov);

    final bytes = excel.save();
    if (bytes == null) {
      _snack(context, 'فشل إنشاء الملف');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/telecom_invoices_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: '🧾 فواتير الخطوط');
  }

  static void _buildInvoicesSheet(Excel excel, AppProvider prov) {
    final sheet = excel['الفواتير'];
    const headers = [
      'الرقم',
      'صاحب الخط',
      'المزود',
      'الشهر',
      'الثابت/المتوقع',
      'الفعلي',
      'الزيادة',
      'المدفوع',
      'المتبقي',
      'الحالة',
      'مؤجَّل لـ',
      'تاريخ الإضافة',
      'آخر دفعة',
      'ملاحظة',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    const statusLabels = {
      'paid': 'مسدد',
      'partial': 'جزئي',
      'unpaid': 'غير مسدد'
    };
    final bills = [...prov.db.companyBills]
      ..sort((a, b) => b.month.compareTo(a.month));
    for (final b in bills) {
      final g = prov.db.groups.cast<Group?>().firstWhere(
            (x) => x?.id == b.groupId,
            orElse: () => null,
          );
      final lastPay = b.payments.isNotEmpty ? b.payments.last.date : '-';
      sheet.appendRow(<CellValue>[
        TextCellValue(g?.phone ?? b.groupId),
        TextCellValue(g?.ownerName ?? '-'),
        TextCellValue(g?.provider ?? '-'),
        TextCellValue(b.month),
        DoubleCellValue(b.fixedAmount),
        DoubleCellValue(b.actualAmount),
        DoubleCellValue(b.actualAmount - b.fixedAmount),
        DoubleCellValue(b.paidAmount),
        DoubleCellValue(b.remaining),
        TextCellValue(statusLabels[b.status] ?? b.status),
        TextCellValue(b.deferDate ?? '-'),
        TextCellValue(_fDate(b.date)),
        TextCellValue(lastPay),
        TextCellValue(b.note ?? '-'),
      ]);
    }
  }

  static void _buildMembersSheet(Excel excel, AppProvider prov,
      {required bool deleted}) {
    final sheetName = deleted ? 'المحذوفون' : 'العملاء النشطون';
    final sheet = excel[sheetName];
    final members = deleted ? prov.db.deleted : prov.db.members;

    // Header
    final headers = deleted
        ? [
            'الاسم',
            'رقم الموبايل',
            'الباقة',
            'سعر الاشتراك',
            'تاريخ الاشتراك',
            'تاريخ الحذف',
            'شهور الاشتراك',
            'المديونية',
            'آخر دفعة',
            'المجموعة',
            'المزود',
            'نوع الخط',
            'نوع العميل',
            'الكفيل',
            'رقم الكفيل',
            'ملاحظات',
          ]
        : [
            'الاسم',
            'رقم الموبايل',
            'رقم 2',
            'الباقة',
            'الجيجابايت',
            'سعر الاشتراك',
            'الرصيد',
            'المديونية',
            'تاريخ الاشتراك',
            'شهور الاشتراك',
            'آخر دفعة',
            'المجموعة',
            'المزود',
            'نوع الخط',
            'انتهاء العرض',
            'نوع العميل',
            'الكفيل',
            'رقم الكفيل',
            'الرقم القومي',
            'ملاحظات',
          ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final m in members) {
      final group = prov.db.groups.cast<Group?>().firstWhere(
            (g) => g?.id == m.gid,
            orElse: () => null,
          );
      final groupLabel = group != null
          ? (group.ownerName?.isNotEmpty == true
              ? group.ownerName!
              : group.phone)
          : '-';
      final provider = group?.provider ?? '-';
      final lineType = group?.lineType.label ?? '-';
      final offerEnd = group?.offerEndDate ?? '-';

      final debt = m.balance < 0 ? (-m.balance).toStringAsFixed(1) : '0';
      final lastPay = _lastPayDate(m);
      final months = _monthsSubscribed(m.date).toString();

      final row = deleted
          ? <CellValue>[
              TextCellValue(m.name),
              TextCellValue(m.phone),
              TextCellValue(m.package),
              DoubleCellValue(m.price),
              TextCellValue(_fDate(m.date)),
              TextCellValue('-'), // deletion date not stored in model yet
              TextCellValue(months),
              TextCellValue(debt),
              TextCellValue(lastPay),
              TextCellValue(groupLabel),
              TextCellValue(provider),
              TextCellValue(lineType),
              TextCellValue(m.typeIcon),
              TextCellValue(m.guarantorName ?? '-'),
              TextCellValue(m.guarantorPhone ?? '-'),
              TextCellValue(m.notes ?? '-'),
            ]
          : <CellValue>[
              TextCellValue(m.name),
              TextCellValue(m.phone),
              TextCellValue(m.phone2 ?? '-'),
              TextCellValue(m.package),
              IntCellValue(m.gb),
              DoubleCellValue(m.price),
              DoubleCellValue(m.balance),
              TextCellValue(debt),
              TextCellValue(_fDate(m.date)),
              TextCellValue(months),
              TextCellValue(lastPay),
              TextCellValue(groupLabel),
              TextCellValue(provider),
              TextCellValue(lineType),
              TextCellValue(_fDate(offerEnd)),
              TextCellValue(m.typeIcon),
              TextCellValue(m.guarantorName ?? '-'),
              TextCellValue(m.guarantorPhone ?? '-'),
              TextCellValue(m.natId ?? '-'),
              TextCellValue(m.notes ?? '-'),
            ];

      sheet.appendRow(row);
    }
  }

  static void _buildGroupsSheet(Excel excel, AppProvider prov) {
    final sheet = excel['المجموعات'];
    sheet.appendRow([
      TextCellValue('رقم المجموعة'),
      TextCellValue('صاحب الخط'),
      TextCellValue('رقم الخط'),
      TextCellValue('المزود'),
      TextCellValue('نوع الباقة'),
      TextCellValue('نوع الخط'),
      TextCellValue('الحد الأقصى للعملاء'),
      TextCellValue('العملاء الحاليون'),
      TextCellValue('سعر الاشتراك الكلي'),
      TextCellValue('فاتورة الشركة'),
      TextCellValue('الربح'),
      TextCellValue('تاريخ بداية الخط'),
      TextCellValue('انتهاء العرض'),
      TextCellValue('دورة الفوترة'),
      TextCellValue('النقاط الشهرية'),
      TextCellValue('قيمة النقطة'),
      TextCellValue('مديونية المجموعة'),
      TextCellValue('الرقم القومي'),
      TextCellValue('ملاحظات'),
    ]);

    for (final g in prov.db.groups) {
      final members = prov.db.membersOf(g.id);
      final totalPrice =
          members.fold<double>(0, (s, m) => s + m.price);
      final profit = prov.db.groupProfit(g.id);
      final debt = prov.db.groupDebt(g.id);

      sheet.appendRow([
        TextCellValue(g.id),
        TextCellValue(g.ownerName ?? '-'),
        TextCellValue(g.phone),
        TextCellValue(g.provider ?? '-'),
        TextCellValue(g.type == '3800' ? '4250 ج' : '2150 ج'),
        TextCellValue(g.lineType.label),
        IntCellValue(g.maxClients ?? 0),
        IntCellValue(members.length),
        DoubleCellValue(totalPrice),
        DoubleCellValue(g.actualBillAmount ?? 0),
        DoubleCellValue(profit),
        TextCellValue(_fDate(g.offerStartDate ?? g.date)),
        TextCellValue(_fDate(g.offerEndDate)),
        TextCellValue(g.billingCycle ?? '-'),
        IntCellValue(g.pointsMonthly ?? 0),
        DoubleCellValue(g.pointPrice ?? 0),
        DoubleCellValue(debt),
        TextCellValue(g.ownerNatId ?? '-'),
        TextCellValue(g.notes ?? '-'),
      ]);
    }
  }

  static void _buildMainLinesSheet(Excel excel, AppProvider prov) {
    final sheet = excel['الخطوط الرئيسية'];
    sheet.appendRow([
      TextCellValue('المزود'),
      TextCellValue('رقم الخط'),
      TextCellValue('صاحب الخط'),
      TextCellValue('أقصى عملاء'),
      TextCellValue('النقاط الشهرية'),
      TextCellValue('سعر النقطة'),
      TextCellValue('رسوم العميل الإضافي'),
      TextCellValue('دورة الفوترة'),
      TextCellValue('تاريخ البداية'),
      TextCellValue('تاريخ الانتهاء'),
      TextCellValue('مدة العرض (شهر)'),
      TextCellValue('الرصيد الافتتاحي'),
      TextCellValue('ملاحظات'),
    ]);

    for (final line in prov.db.mainLines) {
      sheet.appendRow([
        TextCellValue(line.name),
        TextCellValue(line.phone),
        TextCellValue(line.ownerName),
        IntCellValue(line.maxClients),
        IntCellValue(line.pointsMonthly),
        DoubleCellValue(line.pointPrice),
        DoubleCellValue(line.extraClientFee),
        TextCellValue(line.cycleLabel),
        TextCellValue(_fDate(line.startDate)),
        TextCellValue(_fDate(line.endDate)),
        IntCellValue(line.offerDuration ?? 0),
        DoubleCellValue(line.openingBalance),
        TextCellValue(line.notes ?? '-'),
      ]);
    }
  }

  // ── PDF export ───────────────────────────────────────────────────
  static Future<void> exportPdf(
      BuildContext context, AppProvider prov) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final pdf = pw.Document();

    final now = intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // ── Active members page ──
    final activeMembers = prov.db.members;
    if (activeMembers.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          _pdfTitle('العملاء النشطون', now, fontBold),
          pw.SizedBox(height: 8),
          _buildMembersPdfTable(activeMembers, prov, font, fontBold,
              deleted: false),
        ],
      ));
    }

    // ── Deleted members page ──
    final deletedMembers = prov.db.deleted;
    if (deletedMembers.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          _pdfTitle('العملاء المحذوفون', now, fontBold),
          pw.SizedBox(height: 8),
          _buildMembersPdfTable(deletedMembers, prov, font, fontBold,
              deleted: true),
        ],
      ));
    }

    // ── Groups page ──
    if (prov.db.groups.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          _pdfTitle('المجموعات', now, fontBold),
          pw.SizedBox(height: 8),
          _buildGroupsPdfTable(prov, font, fontBold),
        ],
      ));
    }

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/telecom_report_$ts.pdf');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
  }

  // ── Guarantor statement PDF (كشف حساب كفيل) ─────────────────────
  static Future<void> exportGuarantorStatement(
    BuildContext context,
    AppProvider prov, {
    required String name,
    required String phone,
    String? phone2,
    required List<Member> members,
    List<Map<String, dynamic>> log = const [],
    double? maxDebt,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final pdf = pw.Document();
    final now = intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final totalDebt =
        members.fold<double>(0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));
    final debtors = members.where((m) => m.balance < 0).length;
    final totalPaid = log
        .where((e) => e['type'] == 'payment')
        .fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    pw.Widget infoRow(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.Text('$k: ',
                style: pw.TextStyle(font: fontBold, fontSize: 11),
                textDirection: pw.TextDirection.rtl),
            pw.Text(v,
                style: pw.TextStyle(font: font, fontSize: 11),
                textDirection: pw.TextDirection.rtl),
          ]),
        );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => [
        _pdfTitle('كشف حساب الكفيل', now, fontBold),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.93, 0.96, 1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            infoRow('الاسم', name),
            infoRow('الرقم', phone),
            if (phone2?.isNotEmpty == true) infoRow('رقم آخر', phone2!),
            if (maxDebt != null && maxDebt > 0)
              infoRow('حد الكفالة', '${_fNum(maxDebt)} ج'),
            infoRow('عدد العملاء', '${members.length}'),
            infoRow('عدد المدينين', '$debtors'),
            infoRow('إجمالي المديونية', '${_fNum(totalDebt)} ج'),
            infoRow('إجمالي المدفوعات المسجّلة', '${_fNum(totalPaid)} ج'),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Text('العملاء المكفولون',
            style: pw.TextStyle(font: fontBold, fontSize: 13),
            textDirection: pw.TextDirection.rtl),
        pw.SizedBox(height: 6),
        _guarantorMembersTable(members, prov, font, fontBold),
        if (log.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('سجل المدفوعات والأحداث',
              style: pw.TextStyle(font: fontBold, fontSize: 13),
              textDirection: pw.TextDirection.rtl),
          pw.SizedBox(height: 6),
          _guarantorLogTable(log, font, fontBold),
        ],
      ],
    ));

    final bytes = await pdf.save();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final safe = name.replaceAll(RegExp(r'[^\w؀-ۿ]+'), '_');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/كشف_كفيل_${safe}_$ts.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],
        text: 'كشف حساب الكفيل $name');
  }

  static pw.Widget _guarantorMembersTable(List<Member> members,
      AppProvider prov, pw.Font font, pw.Font fontBold) {
    final cols = ['الاسم', 'رقم الموبايل', 'الباقة', 'الرصيد', 'مديونية', 'المجموعة'];
    final rows = [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
        children: cols.map((c) => _pdfCell(c, fontBold, isHeader: true)).toList(),
      ),
      ...members.asMap().entries.map((e) {
        final m = e.value;
        final group = prov.db.groups.cast<Group?>()
            .firstWhere((g) => g?.id == m.gid, orElse: () => null);
        final groupLabel = group != null
            ? (group.ownerName?.isNotEmpty == true ? group.ownerName! : group.phone)
            : '-';
        final debt = m.balance < 0 ? _fNum(-m.balance) : '-';
        final bg = e.key.isEven ? PdfColors.white : const PdfColor(0.96, 0.96, 0.97);
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [m.name, m.phone, m.package, _fNum(m.balance), debt, groupLabel]
              .map((c) => _pdfCell(c, font)).toList(),
        );
      }),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      children: rows,
    );
  }

  static pw.Widget _guarantorLogTable(
      List<Map<String, dynamic>> log, pw.Font font, pw.Font fontBold) {
    final cols = ['التاريخ', 'الحركة', 'المبلغ'];
    final rows = [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
        children: cols.map((c) => _pdfCell(c, fontBold, isHeader: true)).toList(),
      ),
      ...log.asMap().entries.map((e) {
        final it = e.value;
        final amt = (it['amount'] as num?)?.toDouble() ?? 0;
        final bg = e.key.isEven ? PdfColors.white : const PdfColor(0.96, 0.96, 0.97);
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            (it['date'] ?? '-').toString(),
            (it['desc'] ?? '-').toString(),
            amt != 0 ? _fNum(amt) : '-',
          ].map((c) => _pdfCell(c, font)).toList(),
        );
      }),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      children: rows,
    );
  }

  static pw.Widget _pdfTitle(String title, String date, pw.Font fontBold) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title,
              style: pw.TextStyle(font: fontBold, fontSize: 16),
              textDirection: pw.TextDirection.rtl),
          pw.Text(date,
              style: pw.TextStyle(font: fontBold, fontSize: 10,
                  color: PdfColors.grey600)),
        ],
      );

  static pw.Widget _buildMembersPdfTable(
    List<Member> members,
    AppProvider prov,
    pw.Font font,
    pw.Font fontBold, {
    required bool deleted,
  }) {
    final cols = deleted
        ? ['الاسم', 'الباقة', 'السعر', 'الاشتراك', 'شهور', 'مديونية', 'آخر دفع', 'المجموعة']
        : ['الاسم', 'رقم الموبايل', 'الباقة', 'GB', 'السعر', 'الرصيد', 'مديونية', 'الاشتراك', 'شهور', 'آخر دفع', 'المجموعة', 'المزود'];

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      children: cols
          .map((c) => _pdfCell(c, fontBold, isHeader: true))
          .toList(),
    );

    final rows = [
      headerRow,
      ...members.asMap().entries.map((entry) {
        final i = entry.key;
        final m = entry.value;
        final group = prov.db.groups.cast<Group?>().firstWhere(
              (g) => g?.id == m.gid,
              orElse: () => null,
            );
        final groupLabel = group != null
            ? (group.ownerName?.isNotEmpty == true
                ? group.ownerName!
                : group.phone)
            : '-';
        final debt = m.balance < 0 ? _fNum(-m.balance) : '-';
        final lastPay = _lastPayDate(m);
        final months = _monthsSubscribed(m.date).toString();
        final bg = i.isEven ? PdfColors.white : const PdfColor(0.96, 0.96, 0.97);

        final cells = deleted
            ? [
                m.name, m.package, _fNum(m.price), _fDate(m.date),
                months, debt, lastPay, groupLabel,
              ]
            : [
                m.name, m.phone, m.package, '${m.gb}',
                _fNum(m.price), _fNum(m.balance), debt,
                _fDate(m.date), months, lastPay, groupLabel,
                group?.provider ?? '-',
              ];

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: cells.map((c) => _pdfCell(c, font)).toList(),
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      children: rows,
    );
  }

  static pw.Widget _buildGroupsPdfTable(
      AppProvider prov, pw.Font font, pw.Font fontBold) {
    final cols = ['صاحب الخط', 'الرقم', 'المزود', 'النوع', 'عملاء', 'دخل', 'فاتورة', 'ربح', 'مديونية', 'انتهاء العرض'];

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      children: cols.map((c) => _pdfCell(c, fontBold, isHeader: true)).toList(),
    );

    final rows = [
      headerRow,
      ...prov.db.groups.asMap().entries.map((entry) {
        final i = entry.key;
        final g = entry.value;
        final members = prov.db.membersOf(g.id);
        final income = members.fold<double>(0, (s, m) => s + m.price);
        final profit = prov.db.groupProfit(g.id);
        final debt = prov.db.groupDebt(g.id);
        final bg = i.isEven ? PdfColors.white : const PdfColor(0.96, 0.96, 0.97);

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            g.ownerName ?? '-',
            g.phone,
            g.provider ?? '-',
            g.type == '3800' ? '4250' : '2150',
            '${members.length}',
            _fNum(income),
            _fNum(g.actualBillAmount ?? 0),
            _fNum(profit),
            _fNum(debt),
            _fDate(g.offerEndDate),
          ].map((c) => _pdfCell(c, font)).toList(),
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      children: rows,
    );
  }

  static pw.Widget _pdfCell(String text, pw.Font font,
      {bool isHeader = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: isHeader ? 8 : 7,
            color: isHeader ? PdfColors.white : PdfColors.black,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );

  static void _snack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Share (WhatsApp / other) ─────────────────────────────────────
  static Future<void> shareExcel(
      BuildContext context, AppProvider prov) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    _buildMembersSheet(excel, prov, deleted: false);
    _buildMembersSheet(excel, prov, deleted: true);
    _buildGroupsSheet(excel, prov);
    _buildMainLinesSheet(excel, prov);

    final bytes = excel.save();
    if (bytes == null) {
      _snack(context, 'فشل إنشاء الملف');
      return;
    }

    final dir = await getTemporaryDirectory();
    final ts = intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/telecom_export_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير التليكوم - $ts');
  }
}
