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
        TextCellValue(g.type == '3800' ? '3800 ج' : '1800 ج'),
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
            g.type == '3800' ? '3800' : '1800',
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
