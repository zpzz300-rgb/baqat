// lib/utils/print_helper.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintHelper {
  /// Print a simple table. [headers] = column names, [rows] = list of row data.
  static Future<void> printTable({
    required BuildContext context,
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String subtitle = '',
  }) async {
    final pdf = pw.Document();

    // Use a built-in font that supports Arabic (fallback to Helvetica)
    // For proper Arabic rendering we need an Arabic font; use the system approach.
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context ctx) => [
          // Title
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              title,
              style: pw.TextStyle(font: arabicBold, fontSize: 18),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                subtitle,
                style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.grey600),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
          pw.Divider(thickness: 1.5, color: PdfColors.blueGrey800),
          pw.SizedBox(height: 8),
          // Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: _columnWidths(headers.length),
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: headers.map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(font: arabicBold, fontSize: 10, color: PdfColors.white),
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center,
                  ),
                )).toList(),
              ),
              // Data rows
              ...rows.asMap().entries.map((entry) {
                final isEven = entry.key % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : PdfColors.blueGrey50,
                  ),
                  children: entry.value.map((cell) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text(
                      cell,
                      style: pw.TextStyle(font: arabicFont, fontSize: 9),
                      textDirection: pw.TextDirection.rtl,
                      textAlign: pw.TextAlign.center,
                    ),
                  )).toList(),
                );
              }),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'إجمالي: ${rows.length} سجل',
            style: pw.TextStyle(font: arabicBold, fontSize: 10),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
        footer: (pw.Context ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: pw.TextStyle(font: arabicFont, fontSize: 9, color: PdfColors.grey500),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: title,
    );
  }

  static Map<int, pw.TableColumnWidth> _columnWidths(int count) {
    final result = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < count; i++) {
      result[i] = const pw.FlexColumnWidth();
    }
    return result;
  }
}
