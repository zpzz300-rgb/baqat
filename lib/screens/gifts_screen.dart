// lib/screens/gifts_screen.dart
// 🎁 لوحة الهدايا — تصميم المربعين (هديتين لكل خط) — أبو عمر.
// فوق: مخزن أنواع الهدايا (تضيف أنواع باسمها وسعرها).
// قدام كل خط: مربعين، كل مربع زرار منسدل تختار منه الهدية، فيظهر حرف/حرفين.
// لونين بس:  🔴 أحمر = اتخصصت (لسه ما اتباعتش)   |   🟢 أخضر = اتباعت (ربح).
// ضغطة على المربع = تبديل (أحمر ↔ أخضر).  ضغطة مطوّلة = تغيير/حذف الهدية.
// فلاتر: بالحالة (الكل / لم تُبع / تم البيع) + بنوع الهدية + بحث.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/responsive.dart';
import '../services/app_search.dart';
import '../services/view_prefs.dart';
import '../widgets/app_search_bar.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  String _search = '';
  String _status = 'all'; // all / pending / sold
  String _typeFilter = 'all'; // all / <typeId>
  final _searchCtrl = TextEditingController();

  // 💾 بيفتكر الفلاتر
  final _viewPrefs = ViewPrefs('gifts');

  @override
  void initState() {
    super.initState();
    _viewPrefs.load().then((m) {
      if (!mounted || m.isEmpty) return;
      setState(() {
        _status = m['status'] ?? 'all';
        _typeFilter = m['type'] ?? 'all';
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _set(VoidCallback change) {
    setState(change);
    _viewPrefs.save({'status': _status, 'type': _typeFilter});
  }

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '🎁';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return parts[0].characters.first + parts[1].characters.first;
    }
    return t.characters.take(2).toString();
  }

  bool _lineMatches(AppProvider p, Group g) {
    // 🔍 محرّك البحث الموحّد
    final terms = searchTerms(_search);
    if (terms.isNotEmpty &&
        searchHitsOf(terms, [
              g.phone, g.ownerName ?? '', g.groupInvoiceName ?? '',
              g.notes ?? '',
            ]) == null) {
      return false;
    }
    final s0 = p.lineGiftSlot(g.id, 0);
    final s1 = p.lineGiftSlot(g.id, 1);
    final slots = [s0, s1].whereType<Map<String, dynamic>>().toList();
    if (_status == 'pending' && !slots.any((e) => e['sold'] != true)) {
      return false;
    }
    if (_status == 'sold' && !slots.any((e) => e['sold'] == true)) {
      return false;
    }
    if (_typeFilter != 'all' &&
        !slots.any((e) => e['giftTypeId'] == _typeFilter)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, p, _) {
      final catalog = p.giftCatalog;
      final groups = p.db.groups.where((g) => _lineMatches(p, g)).toList();

      // إحصائيات
      int assigned = 0, sold = 0;
      double profit = 0;
      for (final g in p.db.groups) {
        for (final slot in [0, 1]) {
          final e = p.lineGiftSlot(g.id, slot);
          if (e == null) continue;
          if (e['sold'] == true) {
            sold++;
          } else {
            assigned++;
          }
        }
        profit += g.giftProfit;
      }

      return Column(children: [
        _header(p, catalog, assigned, sold, profit),
        _tableHead(),
        const Divider(height: 1),
        Expanded(
          child: catalog.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '⬆️ أضف أنواع الهدايا من المخزن فوق الأول\n'
                      'عشان تقدر تختارها لكل خط',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(color: AppColors.muted),
                    ),
                  ),
                )
              : groups.isEmpty
                  ? Center(
                      child: Text('لا توجد خطوط مطابقة',
                          style: GoogleFonts.cairo(color: AppColors.muted)))
                  : ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _row(p, groups[i], catalog),
                    ),
        ),
      ]);
    });
  }

  // ─── HEADER (مخزن + إحصائيات + فلاتر) ────────────────────────
  Widget _header(AppProvider p, List<Map<String, dynamic>> catalog,
      int assigned, int sold, double profit) {
    return Container(
      color: AppColors.surface,
      child: Column(children: [
        // شريط علوي + إحصائيات
        Container(
          decoration: BoxDecoration(gradient: AppColors.headerGradient),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            const Text('🎁', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('الهدايا',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17)),
            const Spacer(),
            _miniStat('🔴 $assigned'),
            const SizedBox(width: 6),
            _miniStat('🟢 $sold'),
            const SizedBox(width: 6),
            _miniStat('💰 ${profit.toStringAsFixed(0)}ج'),
          ]),
        ),
        // المخزن
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFe8f4fd),
            border: Border(bottom: BorderSide(color: AppColors.blueMid)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🏪', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text('مخزن الهدايا',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue2,
                      fontSize: 12)),
              const Spacer(),
              InkWell(
                onTap: () => _editType(p, null),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.blue2,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add, size: 13, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('إضافة نوع',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ]),
            if (catalog.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: catalog.map((t) => _typeChip(p, t)).toList(),
              ),
            ],
          ]),
        ),
        // فلاتر + بحث
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(children: [
            Row(children: [
              _statusChip('all', 'الكل'),
              const SizedBox(width: 6),
              _statusChip('pending', '🔴 لم تُبع'),
              const SizedBox(width: 6),
              _statusChip('sold', '🟢 تم البيع'),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFf5f7fa),
                      borderRadius: BorderRadius.circular(9)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      value: _typeFilter,
                      style:
                          GoogleFonts.cairo(fontSize: 11, color: AppColors.text),
                      items: [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text('كل الأنواع',
                                style: GoogleFonts.cairo(fontSize: 11))),
                        ...catalog.map((t) => DropdownMenuItem(
                              value: t['id'] as String,
                              child: Text('🎁 ${t['name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(fontSize: 11)),
                            )),
                      ],
                      onChanged: (v) => _set(() => _typeFilter = v ?? 'all'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: AppSearchBar(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  hint: '🔍 رقم · اسم · ملاحظات',
                  padding: EdgeInsets.zero,
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _miniStat(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10)),
        child: Text(t,
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11)),
      );

  Widget _typeChip(AppProvider p, Map<String, dynamic> t) {
    return InkWell(
      onTap: () => _editType(p, t),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎁', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('${t['name']}',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue2)),
          const SizedBox(width: 4),
          Text('${(t['price'] as num).toStringAsFixed(0)}ج',
              style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green)),
          const SizedBox(width: 3),
          Icon(Icons.edit, size: 11, color: AppColors.muted),
        ]),
      ),
    );
  }

  Widget _statusChip(String value, String label) {
    final active = _status == value;
    return GestureDetector(
      onTap: () => _set(() => _status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.blue2 : const Color(0xFFf0f4f8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.blue2 : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.text)),
      ),
    );
  }

  Widget _tableHead() {
    return Container(
      color: const Color(0xFFf5f7fa),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(children: [
        Expanded(flex: 4, child: _hCell('🔢 الخط')),
        Expanded(flex: 3, child: _hCell('🎁 هدية ١', center: true)),
        Expanded(flex: 3, child: _hCell('🎁 هدية ٢', center: true)),
      ]),
    );
  }

  Widget _hCell(String t, {bool center = false}) => Text(t,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.cairo(
          fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.muted));

  // ─── صف خط (المربعين) ────────────────────────────────────────
  Widget _row(AppProvider p, Group g, List<Map<String, dynamic>> catalog) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.phone,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppColors.blue2)),
            if ((g.ownerName ?? '').isNotEmpty)
              Text(g.ownerName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
            if (g.giftProfit > 0)
              Text('ربح: ${g.giftProfit.toStringAsFixed(0)}ج',
                  style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green)),
          ]),
        ),
        Expanded(flex: 3, child: _square(p, g, 0, catalog)),
        const SizedBox(width: 6),
        Expanded(flex: 3, child: _square(p, g, 1, catalog)),
      ]),
    );
  }

  // مربع هدية واحد (slot)
  Widget _square(
      AppProvider p, Group g, int slot, List<Map<String, dynamic>> catalog) {
    final e = p.lineGiftSlot(g.id, slot);

    if (e == null) {
      // فاضي → زرار منسدل لاختيار الهدية
      return _pickerButton(p, g.id, slot, catalog);
    }

    final sold = e['sold'] == true;
    final color = sold ? AppColors.green2 : AppColors.red2;
    return GestureDetector(
      onTap: () => p.toggleLineGiftSold(g.id, slot),
      onLongPress: () => _slotMenu(p, g.id, slot, catalog),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_initials((e['name'] ?? '').toString()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 1),
          Text(sold ? 'اتباعت' : 'اتخصصت',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 8)),
        ]),
      ),
    );
  }

  Widget _pickerButton(AppProvider p, String gid, int slot,
      List<Map<String, dynamic>> catalog) {
    return PopupMenuButton<String>(
      tooltip: 'اختر هدية',
      padding: EdgeInsets.zero,
      onSelected: (id) {
        final t = catalog.firstWhere((x) => x['id'] == id,
            orElse: () => <String, dynamic>{});
        if (t.isNotEmpty) p.setLineGiftSlot(gid, slot, t);
      },
      itemBuilder: (_) => catalog
          .map((t) => PopupMenuItem(
                value: t['id'] as String,
                child: Text(
                    '🎁 ${t['name']} • ${(t['price'] as num).toStringAsFixed(0)}ج',
                    style: GoogleFonts.cairo(fontSize: 13)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFf5f7fa),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, size: 16, color: AppColors.muted),
          Text('اختر',
              style: GoogleFonts.cairo(fontSize: 9, color: AppColors.muted)),
        ]),
      ),
    );
  }

  void _slotMenu(AppProvider p, String gid, int slot,
      List<Map<String, dynamic>> catalog) {
    showAppSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Text('تغيير هدية الخانة ${slot + 1}',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 6),
          ...catalog.map((t) => ListTile(
                dense: true,
                leading: const Text('🎁', style: TextStyle(fontSize: 18)),
                title: Text(t['name'] ?? '',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                trailing: Text('${(t['price'] as num).toStringAsFixed(0)}ج',
                    style: GoogleFonts.cairo(
                        color: AppColors.green, fontSize: 12)),
                onTap: () {
                  p.setLineGiftSlot(gid, slot, t);
                  Navigator.pop(context);
                },
              )),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline, color: AppColors.red2),
            title: Text('حذف الهدية من الخانة',
                style: GoogleFonts.cairo(
                    color: AppColors.red2, fontWeight: FontWeight.w700)),
            onTap: () {
              p.clearLineGiftSlot(gid, slot);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  // ─── إضافة/تعديل نوع هدية في المخزن ──────────────────────────
  void _editType(AppProvider p, Map<String, dynamic>? gift) {
    final isNew = gift == null;
    final nameCtrl = TextEditingController(text: gift?['name'] as String? ?? '');
    final priceCtrl = TextEditingController(
        text: gift != null ? (gift['price'] as num).toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isNew ? '🎁 نوع هدية جديد' : '🎁 تعديل النوع',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                  labelText: 'اسم الهدية',
                  labelStyle: GoogleFonts.cairo(fontSize: 13)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                  labelText: 'السعر (ج)',
                  labelStyle: GoogleFonts.cairo(fontSize: 13)),
            ),
          ]),
          actions: [
            if (!isNew)
              TextButton(
                onPressed: () {
                  p.deleteGiftTypeV2(gift['id'] as String);
                  Navigator.pop(context);
                },
                child:
                    Text('حذف', style: GoogleFonts.cairo(color: AppColors.red)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                if (name.isEmpty || price <= 0) return;
                if (isNew) {
                  p.addGiftTypeV2(name, price);
                } else {
                  p.updateGiftType(gift['id'] as String, name, price);
                }
                Navigator.pop(context);
              },
              child: Text('حفظ',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
