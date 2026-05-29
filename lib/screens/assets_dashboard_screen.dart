// lib/screens/assets_dashboard_screen.dart
// 📊 لوحة الأصول والإكسيبشن
// تعرض كل خط رئيسي (Group) وتوضّح هل جواه أرضي (☎️) أو هوم 4G (🏠) أو فاضي.
// أي تعديل/حذف هنا يتزامن تلقائياً مع المجموعة الرئيسية والهيدر،
// لأن الشاشة بتقرأ وتكتب على نفس عملاء AppProvider (Member من نوع landline/homeforgee).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../widgets/common.dart';

class AssetsDashboardScreen extends StatefulWidget {
  const AssetsDashboardScreen({super.key});

  @override
  State<AssetsDashboardScreen> createState() => _AssetsDashboardScreenState();
}

class _AssetsDashboardScreenState extends State<AssetsDashboardScreen> {
  String _query = '';
  // فلتر: all / landline / home4g / empty
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final groups = prov.db.groups;

    // إحصائيات سريعة
    int withLandline = 0, withHome4g = 0, empty = 0;
    for (final g in groups) {
      final mems = prov.db.membersOf(g.id);
      final hasL = mems.any((m) => m.type == 'landline');
      final hasH = mems.any((m) => m.type == 'homeforgee');
      if (hasL) withLandline++;
      if (hasH) withHome4g++;
      if (!hasL && !hasH) empty++;
    }

    // تطبيق الفلتر + البحث
    final filtered = groups.where((g) {
      final mems = prov.db.membersOf(g.id);
      final hasL = mems.any((m) => m.type == 'landline');
      final hasH = mems.any((m) => m.type == 'homeforgee');
      switch (_filter) {
        case 'landline':
          if (!hasL) return false;
          break;
        case 'home4g':
          if (!hasH) return false;
          break;
        case 'empty':
          if (hasL || hasH) return false;
          break;
      }
      if (_query.isEmpty) return true;
      final q = _query.trim();
      return g.phone.contains(q) ||
          (g.ownerName ?? '').contains(q) ||
          (g.groupInvoiceName ?? '').contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('📊 لوحة الأصول والإكسيبشن',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.blue2,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── عدّاد سريع ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: Row(
              children: [
                _statChip('الإجمالي', groups.length, Colors.white,
                    active: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                _statChip('☎️ أرضي', withLandline, AppColors.greenLight,
                    active: _filter == 'landline',
                    onTap: () => setState(() => _filter = 'landline')),
                _statChip('🏠 هوم 4G', withHome4g, AppColors.blueLight,
                    active: _filter == 'home4g',
                    onTap: () => setState(() => _filter = 'home4g')),
                _statChip('➖ فاضي', empty, AppColors.orangeLight,
                    active: _filter == 'empty',
                    onTap: () => setState(() => _filter = 'empty')),
              ],
            ),
          ),
          // ── بحث ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                hintText: 'ابحث برقم الخط أو اسم صاحبه…',
                hintStyle: GoogleFonts.cairo(color: AppColors.muted),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          // ── رأس الجدول ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Expanded(flex: 4, child: _headCell('🔢 الخط الرئيسي')),
                Expanded(flex: 3, child: _headCell('☎️ أرضي')),
                Expanded(flex: 3, child: _headCell('🏠 هوم 4G')),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── الصفوف ─────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('لا توجد خطوط مطابقة',
                        style: GoogleFonts.cairo(color: AppColors.muted)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _groupRow(prov, filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ── عدّاد قابل للضغط (يعمل كفلتر) ─────────────────────────────
  Widget _statChip(String label, int count, Color bg,
      {required bool active, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.28 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: active ? 0.9 : 0.0),
                width: 1.5),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headCell(String t) => Text(t,
      style: GoogleFonts.cairo(
          fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.muted));

  // ── صف خط واحد ────────────────────────────────────────────────
  Widget _groupRow(AppProvider prov, Group g) {
    final mems = prov.db.membersOf(g.id);
    Member? landline;
    Member? home4g;
    for (final m in mems) {
      if (m.type == 'landline') landline ??= m;
      if (m.type == 'homeforgee') home4g ??= m;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // العمود 1: الخط الرئيسي
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.phone,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.text)),
                if ((g.ownerName ?? '').isNotEmpty)
                  Text(g.ownerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          // العمود 2: أرضي
          Expanded(
            flex: 3,
            child: _exceptionCell(prov, g, landline, 'landline'),
          ),
          // العمود 3: هوم 4G
          Expanded(
            flex: 3,
            child: _exceptionCell(prov, g, home4g, 'homeforgee'),
          ),
        ],
      ),
    );
  }

  // ── خانة الإكسيبشن (أرضي/هوم 4G) ──────────────────────────────
  Widget _exceptionCell(
      AppProvider prov, Group g, Member? m, String type) {
    final exists = m != null;
    final isLandline = type == 'landline';
    final color = isLandline ? AppColors.green2 : AppColors.blue3;
    final bg = isLandline ? AppColors.greenLight : AppColors.blueLight;

    return InkWell(
      onTap: () => _openEditDialog(prov, g, m, type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          color: exists ? bg : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: exists ? color.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: exists
            ? Column(
                children: [
                  Text('✅ ${m.phone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: color)),
                  if (m.name.isNotEmpty)
                    Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                            fontSize: 10, color: AppColors.muted)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 14, color: AppColors.muted),
                  const SizedBox(width: 3),
                  Text('فاضي',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
      ),
    );
  }

  // ── حوار التعديل/الإضافة/الحذف ────────────────────────────────
  void _openEditDialog(
      AppProvider prov, Group g, Member? existing, String defaultType) {
    showDialog(
      context: context,
      builder: (_) => _ExceptionEditDialog(
        prov: prov,
        group: g,
        existing: existing,
        defaultType: defaultType,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _ExceptionEditDialog extends StatefulWidget {
  final AppProvider prov;
  final Group group;
  final Member? existing;
  final String defaultType;

  const _ExceptionEditDialog({
    required this.prov,
    required this.group,
    required this.existing,
    required this.defaultType,
  });

  @override
  State<_ExceptionEditDialog> createState() => _ExceptionEditDialogState();
}

class _ExceptionEditDialogState extends State<_ExceptionEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late String _type; // 'landline' | 'homeforgee'

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _type = widget.existing?.type ?? widget.defaultType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(
        isEdit ? '✏️ تعديل الإكسيبشن' : '➕ إضافة إكسيبشن',
        style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخط الرئيسي: ${widget.group.phone}',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            // النوع
            Text('النوع', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('☎️ أرضي',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _type == 'landline'
                                ? Colors.white
                                : AppColors.text)),
                    selected: _type == 'landline',
                    selectedColor: AppColors.green2,
                    onSelected: (_) => setState(() => _type = 'landline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('🏠 هوم 4G',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _type == 'homeforgee'
                                ? Colors.white
                                : AppColors.text)),
                    selected: _type == 'homeforgee',
                    selectedColor: AppColors.blue3,
                    onSelected: (_) => setState(() => _type = 'homeforgee'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                labelText: 'رقم الإكسيبشن',
                labelStyle: GoogleFonts.cairo(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                labelText: 'الاسم (اختياري)',
                labelStyle: GoogleFonts.cairo(),
              ),
            ),
            if (_type == 'landline') ...[
              const SizedBox(height: 8),
              Text('ℹ️ الأرضي بيخصم 10 جيجا من رصيد الخط تلقائياً.',
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: AppColors.orange)),
            ],
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
            label: Text('حذف',
                style: GoogleFonts.cairo(color: AppColors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: GoogleFonts.cairo()),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  void _save() {
    final phone = _phoneCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (phone.isEmpty) {
      AppSnackbar.show(context, '⚠️ اكتب رقم الإكسيبشن');
      return;
    }
    final prov = widget.prov;
    if (widget.existing != null) {
      // تعديل عميل موجود (يتزامن مع المجموعة والهيدر فوراً)
      final m = widget.existing!;
      m.phone = phone;
      m.name = name;
      m.type = _type;
      m.gb = _type == 'landline' ? 10 : 0;
      prov.editMember(m);
    } else {
      // إضافة إكسيبشن جديد
      prov.addMember(Member(
        id: prov.newMemberId(),
        gid: widget.group.id,
        name: name,
        phone: phone,
        type: _type,
        gb: _type == 'landline' ? 10 : 0,
        price: 0,
      ));
    }
    Navigator.pop(context);
    AppSnackbar.show(context, '✅ تم الحفظ');
  }

  void _delete() {
    final m = widget.existing;
    if (m == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('هتحذف الإكسيبشن "${m.phone}" من الخط؟',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('تراجع', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              widget.prov.deleteMember(m.id);
              Navigator.pop(context); // confirm
              Navigator.pop(context); // edit dialog
              AppSnackbar.show(context, '🗑️ تم حذف الإكسيبشن');
            },
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
