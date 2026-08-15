// 🌿 شريط التشجير — الخطوط المضمومة على خط رئيسي.
//
// الفاتورة الواحدة ممكن تكون على أكتر من خط (حساب واحد فيه ٢ أو ٣ خطوط).
// الشريط ده بيقول لك: الخط ده ضامم معاه كام خط ومين، وإجمالي كام.
//
// كان متكتوب جوّه كارت المراجعة بس، فكان بيظهر في تاب «الشهر الماضي»
// لوحده. اتنقل هنا عشان يظهر في التلات تابات (الماضي / الحالي / القادم).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';

const _purple = Color(0xFF6A1B9A);

class LinkedLinesStrip extends StatelessWidget {
  const LinkedLinesStrip({
    super.key,
    required this.db,
    required this.group,
    this.onManage,
    this.showTotal = true,
  });

  final AppDB db;

  /// الخط الرئيسي اللي بندوّر على المضمومين عليه.
  final Group group;

  /// زرار الترس — لفك الضم. لو null الترس مابيظهرش.
  final VoidCallback? onManage;

  /// يعرض إجمالي الخام للخط + المضمومين (الفاتورة الواحدة بتغطيهم كلهم).
  final bool showTotal;

  /// الخطوط المضمومة على [gid] — public عشان الكروت تقدر تسأل
  /// «فيه تشجير ولا لأ؟» قبل ما ترسم أي حاجة.
  static List<Group> childrenOf(AppDB db, String gid) =>
      db.groups.where((x) => x.parentGroupId == gid).toList();

  @override
  Widget build(BuildContext context) {
    final children = childrenOf(db, group.id);
    if (children.isEmpty) return const SizedBox.shrink();

    // الإجمالي = الخط الرئيسي + المضمومين، لأن الفاتورة بتنزل عليهم كلهم.
    final total = group.fixedBillAmount +
        children.fold<double>(0, (s, c) => s + c.fixedBillAmount);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCE93D8)),
      ),
      child: Row(children: [
        const Icon(Icons.link, size: 13, color: _purple),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ضُمّ معاه ${children.length} خط: '
                '${children.map((c) => c.phone).join(' • ')}',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: _purple,
                    fontWeight: FontWeight.w700),
              ),
              if (showTotal && total > 0)
                Text(
                  'الفاتورة الواحدة بتغطيهم كلهم — إجمالي '
                  '${total.toStringAsFixed(0)} ج على ${children.length + 1} خط',
                  style: GoogleFonts.cairo(
                      fontSize: 9, color: _purple.withValues(alpha: 0.8)),
                ),
            ],
          ),
        ),
        if (onManage != null)
          GestureDetector(
            onTap: onManage,
            child: const Padding(
              padding: EdgeInsets.only(right: 4),
              child:
                  Icon(Icons.settings_outlined, size: 14, color: _purple),
            ),
          ),
      ]),
    );
  }
}
