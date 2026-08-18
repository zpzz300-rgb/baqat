// lib/screens/employees_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/responsive.dart';
import '../services/supabase_service.dart';
import '../services/app_search.dart' show searchMatches;
import '../widgets/common.dart';
import '../widgets/group_card.dart' show cycleKeyOf, cycleShortOf;

/// لوحة تحكم المالك في الموظفين: كود المحل + موافقة/إيقاف/حذف الموظفين.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  String? _shopCode;
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final code = await SupabaseService.ensureOwnerProfile();
    final emps = await SupabaseService.fetchEmployees();
    if (!mounted) return;
    setState(() {
      _shopCode = code;
      _employees = emps;
      _loading = false;
    });
  }

  Future<void> _setStatus(String id, String status) async {
    final ok = await SupabaseService.setEmployeeStatus(id, status);
    if (!mounted) return;
    AppSnackbar.show(context, ok ? '✅ تم التحديث' : '⚠️ فشل التحديث');
    if (ok) _load();
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الموظف', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('متأكد إنك عايز تحذف «$name» نهائياً؟ هيتقفل في وشه فوراً.',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await SupabaseService.deleteEmployee(id);
    if (!mounted) return;
    AppSnackbar.show(context, ok ? '🗑 تم حذف الموظف' : '⚠️ فشل الحذف');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf8fbff),
      appBar: AppBar(
        title: Text('إدارة الموظفين',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: AppColors.blue2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _shopCodeCard(),
                  const SizedBox(height: 16),
                  Text('الموظفين (${_employees.length})',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_employees.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text('لا يوجد موظفين بعد.\nاطلب من الموظف يسجّل بكود المحل فوق.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
                    )
                  else
                    ..._employees.map(_employeeTile),
                  if (_employees.where((e) => e['status'] == 'active').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _openDistribute,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF6a1b9a), Color(0xFF8e24aa)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shuffle, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('🗂 توزيع الشغل على الموظفين',
                                style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openPerformance,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF00695c), Color(0xFF00897b)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.leaderboard,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('📊 أداء الموظفين ومتابعتهم',
                                style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _openDistribute() {
    final active = _employees
        .where((e) => e['status'] == 'active')
        .map((e) => {'id': e['id'].toString(), 'name': (e['name'] ?? '').toString()})
        .toList();
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppProvider>(),
        child: _DistributeSheet(employees: active),
      ),
    );
  }

  void _openPerformance() {
    final active = _employees
        .where((e) => e['status'] == 'active')
        .map((e) => (e['name'] ?? '').toString())
        .toList();
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppProvider>(),
        child: _PerformanceSheet(employeeNames: active),
      ),
    );
  }

  Widget _shopCodeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0277bd), Color(0xFF039be5)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🏪 كود المحل',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        Text('اعطِ الكود ده للموظف عشان يسجّل بيه:',
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(_shopCode ?? '——',
                    style: GoogleFonts.robotoMono(
                        fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 4,
                        color: const Color(0xFF0277bd))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _shopCode == null ? null : () {
              Clipboard.setData(ClipboardData(text: _shopCode!));
              AppSnackbar.show(context, '📋 تم نسخ الكود');
            },
            icon: const Icon(Icons.copy, color: Colors.white),
          ),
        ]),
      ]),
    );
  }

  Widget _employeeTile(Map<String, dynamic> e) {
    final id = e['id'].toString();
    final name = (e['name'] ?? '').toString();
    final status = (e['status'] ?? 'pending').toString();

    final (label, color, bg) = switch (status) {
      'active'   => ('نشط', AppColors.green2, const Color(0xFFE8F5E9)),
      'disabled' => ('موقوف', AppColors.red, const Color(0xFFFFEBEE)),
      _          => ('بانتظار الموافقة', const Color(0xFFef6c00), const Color(0xFFFFF3E0)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: const Color(0xFFe3f2fd),
              child: Icon(Icons.person, color: AppColors.blue2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (status == 'pending')
            Expanded(child: _btn('✅ قبول', AppColors.green2, () => _setStatus(id, 'active'))),
          if (status == 'active')
            Expanded(child: _btn('⏸ إيقاف', const Color(0xFFef6c00), () => _setStatus(id, 'disabled'))),
          if (status == 'disabled')
            Expanded(child: _btn('▶️ تفعيل', AppColors.green2, () => _setStatus(id, 'active'))),
          const SizedBox(width: 8),
          Expanded(child: _btn('🗑 حذف', AppColors.red, () => _delete(id, name))),
        ]),
        if (status == 'active') ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _btn('📡 المجموعات المتابَعة', AppColors.blue2,
                  () => _openAssign(id, name)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _btn('🔁 تغطية', const Color(0xFF6a1b9a),
                  () => _coverFor(id, name)),
            ),
          ]),
        ],
      ]),
    );
  }

  /// تغطية: نقل كل مجموعات الموظف [fromId] لموظف تاني (لو غاب).
  void _coverFor(String fromId, String fromName) {
    final others = _employees
        .where((e) => e['status'] == 'active' && e['id'].toString() != fromId)
        .toList();
    if (others.isEmpty) {
      AppSnackbar.show(context, 'مفيش موظف تاني مفعّل تنقل له');
      return;
    }
    showAppSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4))),
          Text('🔁 تغطية مجموعات «$fromName»',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 4),
          Text('هتتنقل كل مجموعاته لموظف تاني (لو غاب). تقدر ترجّعها بعدين.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 14),
          ...others.map((e) {
            final toId = e['id'].toString();
            final toName = (e['name'] ?? '').toString();
            return ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF6a1b9a)),
              title: Text('انقل لـ $toName',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              onTap: () async {
                Navigator.pop(context);
                final n = await context
                    .read<AppProvider>()
                    .transferAssignments(fromId, toId);
                if (!mounted) return;
                AppSnackbar.show(context,
                    n > 0 ? '✅ تم نقل $n مجموعة لـ $toName' : 'مفيش مجموعات تتنقل');
              },
            );
          }),
        ]),
      ),
    );
  }

  void _openAssign(String employeeId, String employeeName) {
    final groups = context.read<AppProvider>().db.groups;
    final empNames = {
      for (final e in _employees) e['id'].toString(): (e['name'] ?? '').toString()
    };
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignSheet(
        employeeId: employeeId,
        employeeName: employeeName,
        groups: groups,
        employeeNames: empNames,
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// شيت تعيين المجموعات لموظف: المالك يحدّد أنهي مجموعات الموظف ده يتابعها.
class _AssignSheet extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final List<Group> groups;
  final Map<String, String> employeeNames; // empId -> name
  const _AssignSheet({
    required this.employeeId,
    required this.employeeName,
    required this.groups,
    required this.employeeNames,
  });
  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  /// group_id -> employee_id (التعيين الحالي لكل المجموعات)
  final Map<String, String> _assign = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await SupabaseService.fetchAssignments();
    if (!mounted) return;
    setState(() {
      _assign
        ..clear()
        ..addEntries(rows.map((r) =>
            MapEntry(r['group_id'].toString(), r['employee_id'].toString())));
      _loading = false;
    });
  }

  Future<void> _toggle(String gid, bool assignToMe) async {
    if (_busy) return;
    setState(() => _busy = true);
    bool ok;
    if (assignToMe) {
      ok = await SupabaseService.setAssignment(gid, widget.employeeId);
      if (ok) _assign[gid] = widget.employeeId;
    } else {
      ok = await SupabaseService.removeAssignment(gid);
      if (ok) _assign.remove(gid);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppSnackbar.show(context, '⚠️ فشل — تأكد من النت');
    } else {
      // حدّث مؤشر «المسؤول» على كروت المجموعات
      context.read<AppProvider>().loadAssignmentsOverview();
    }
  }

  // ─── 🔍 بحث + ⚡ إجراء جماعي ──────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';
  String? _provPick; // فلتر شركة سريع

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// الخطوط الظاهرة دلوقتي (بعد البحث وفلتر الشركة)
  List<Group> get _visible {
    var out = widget.groups;
    if (_provPick != null) {
      out = out.where((g) => g.provider == _provPick).toList();
    }
    if (_q.trim().isNotEmpty) {
      out = out
          .where((g) => searchMatches(_q, [g.phone, g.ownerName ?? '']))
          .toList();
    }
    return out;
  }

  /// يدّي كل الخطوط الظاهرة للموظف ده — دفعة واحدة بدل سويتش سويتش
  Future<void> _assignAllVisible() async {
    final gs = _visible.where((g) => _assign[g.id] != widget.employeeId).toList();
    if (gs.isEmpty) return;
    final taken = gs.where((g) => _assign[g.id] != null).length;
    final ok = await _confirm(
      'إسناد ${gs.length} خط لـ«${widget.employeeName}»',
      taken > 0
          ? 'منهم $taken خط مع موظفين تانيين — هيتنقلوا للموظف ده.\nتحب تكمّل؟'
          : 'تحب تكمّل؟',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final n = await context
        .read<AppProvider>()
        .bulkAssign(gs.map((g) => g.id).toList(), widget.employeeId);
    if (!mounted) return;
    for (final g in gs) {
      _assign[g.id] = widget.employeeId;
    }
    setState(() => _busy = false);
    AppSnackbar.show(context, '✅ اتسند $n خط لـ«${widget.employeeName}»');
  }

  /// يشيل كل الخطوط الظاهرة من الموظف ده (بيسيبها من غير متابِع)
  Future<void> _removeAllVisible() async {
    final gs =
        _visible.where((g) => _assign[g.id] == widget.employeeId).toList();
    if (gs.isEmpty) return;
    final ok = await _confirm(
      'سحب ${gs.length} خط من «${widget.employeeName}»',
      'الخطوط دي هتفضل موجودة زي ما هي — بس من غير متابِع.\nتحب تكمّل؟',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    var n = 0;
    for (final g in gs) {
      if (await SupabaseService.removeAssignment(g.id)) {
        _assign.remove(g.id);
        n++;
      }
    }
    if (!mounted) return;
    context.read<AppProvider>().loadAssignmentsOverview();
    setState(() => _busy = false);
    AppSnackbar.show(context, '✅ اتسحب $n خط من «${widget.employeeName}»');
  }

  Future<bool> _confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: Text(body, style: GoogleFonts.cairo(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue2),
            onPressed: () => Navigator.pop(context, true),
            child: Text('تمام',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final mineCount =
        _assign.values.where((v) => v == widget.employeeId).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📡 مجموعات «${widget.employeeName}»',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text('فعّل المجموعة عشان الموظف ده يتابعها (متابِع واحد لكل مجموعة).',
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text('المُعيّن له حالياً: $mineCount مجموعة',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.blue2)),
                const SizedBox(height: 10),
                // 🔍 بحث
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _q = v),
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: 'دوّر برقم الخط أو اسم صاحبه...',
                    hintStyle:
                        GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _q = '';
                            }),
                          ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                // 🏢 فلتر شركة سريع — بيضيّق «الظاهر» قبل الإجراء الجماعي
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final e in const {
                        null: 'الكل',
                        'vodafone': 'VODA',
                        'etisalat': 'ETIS',
                        'orange': 'ORNG',
                        'we': 'WE',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            selected: _provPick == e.key,
                            selectedColor: AppColors.blue2,
                            onSelected: (_) =>
                                setState(() => _provPick = e.key),
                            label: Text(e.value,
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: _provPick == e.key
                                        ? Colors.white
                                        : AppColors.text)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ⚡ إجراء جماعي على كل الظاهر — بدل سويتش سويتش
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _assignAllVisible,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue2,
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                      icon: const Icon(Icons.done_all,
                          size: 17, color: Colors.white),
                      label: Text('ادّيله الكل (${_visible.length})',
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _removeAllVisible,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12)),
                    icon: const Icon(Icons.remove_done, size: 17),
                    label: Text('اسحب الكل',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _visible.isEmpty
                      ? Center(
                          child: Text(
                              widget.groups.isEmpty
                                  ? 'لا توجد مجموعات.'
                                  : 'مفيش خطوط بالبحث ده',
                              style: GoogleFonts.cairo(color: AppColors.muted)))
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                          itemCount: _visible.length,
                          itemBuilder: (_, i) {
                            final g = _visible[i];
                            final assignee = _assign[g.id];
                            final mine = assignee == widget.employeeId;
                            final otherName = (assignee != null && !mine)
                                ? (widget.employeeNames[assignee] ?? 'موظف آخر')
                                : null;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: mine
                                        ? AppColors.blue2.withValues(alpha: 0.5)
                                        : AppColors.border),
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: mine,
                                activeThumbColor: AppColors.blue2,
                                onChanged: _busy ? null : (v) => _toggle(g.id, v),
                                title: Text(g.phone,
                                    textDirection: TextDirection.ltr,
                                    style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                                subtitle: otherName != null
                                    ? Text('متابِعها حالياً: $otherName',
                                        style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: const Color(0xFFef6c00)))
                                    : (g.ownerName != null &&
                                            g.ownerName!.isNotEmpty
                                        ? Text(g.ownerName!,
                                            style: GoogleFonts.cairo(
                                                fontSize: 11,
                                                color: AppColors.muted))
                                        : null),
                              ),
                            );
                          },
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// شيت توزيع الشغل: تلقائي بالتساوي (#4) + بالشركة (#5) + جماعي Checkbox (#6)
// ─────────────────────────────────────────────────────────────────
class _DistributeSheet extends StatefulWidget {
  final List<Map<String, String>> employees; // [{id, name}]
  const _DistributeSheet({required this.employees});
  @override
  State<_DistributeSheet> createState() => _DistributeSheetState();
}

class _DistributeSheetState extends State<_DistributeSheet> {
  final Set<String> _selectedGroups = {};
  String? _targetEmployee;
  bool _busy = false;

  // 🔍 بحث داخل قايمة الاختيار اليدوي
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── تحديد جماعي ────────────────────────────────────────────────
  // كل الدوال دي بتشتغل على **اللي ظاهر قدامك بس** (بعد البحث)، مش على
  // كل الخطوط — عشان لو دوّرت على «اتصالات» وضغطت «حدّد الكل» ما تلاقيش
  // نفسك حدّدت خطوط شركات تانية من ورا ضهرك.
  void _select(List<Group> gs) =>
      setState(() => _selectedGroups.addAll(gs.map((g) => g.id)));

  void _deselect(List<Group> gs) =>
      setState(() => _selectedGroups.removeAll(gs.map((g) => g.id)));

  void _invert(List<Group> gs) => setState(() {
        for (final g in gs) {
          if (!_selectedGroups.remove(g.id)) _selectedGroups.add(g.id);
        }
      });

  /// شريحة «حدّد حسب النوع» — دوسة واحدة تحدّد أو تشيل مجموعة كاملة
  Widget _pickChip(String label, List<Group> gs) {
    if (gs.isEmpty) return const SizedBox.shrink();
    final all = gs.every((g) => _selectedGroups.contains(g.id));
    return FilterChip(
      selected: all,
      showCheckmark: false,
      selectedColor: const Color(0xFF6a1b9a),
      onSelected: (_) => all ? _deselect(gs) : _select(gs),
      label: Text('$label (${gs.length})',
          style: GoogleFonts.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: all ? Colors.white : AppColors.text)),
    );
  }

  /// السيكلات الموجودة فعلاً في الخطوط دي (بترتيب ثابت)
  List<String> _cyclesOf(List<Group> gs) {
    final keys = <String>{for (final g in gs) cycleKeyOf(g)}.toList()..sort();
    return keys;
  }

  static const _provNames = {
    'vodafone': 'فودافون',
    'etisalat': 'اتصالات',
    'orange': 'أورانج',
    'we': 'WE',
  };

  @override
  void initState() {
    super.initState();
    if (widget.employees.isNotEmpty) _targetEmployee = widget.employees.first['id'];
  }

  Future<void> _autoDistribute() async {
    setState(() => _busy = true);
    final ids = widget.employees.map((e) => e['id']!).toList();
    final n = await context.read<AppProvider>().autoDistribute(ids);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context);
    AppSnackbar.show(context, '✅ تم توزيع $n مجموعة بالتساوي على ${ids.length} موظف');
  }

  Future<void> _assignByProvider(String provider) async {
    if (_targetEmployee == null) return;
    setState(() => _busy = true);
    final prov = context.read<AppProvider>();
    final gids = prov.db.groups
        .where((g) => g.provider == provider)
        .map((g) => g.id)
        .toList();
    final n = await prov.bulkAssign(gids, _targetEmployee!);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context);
    AppSnackbar.show(context, '✅ تم إسناد $n خط ${_provNames[provider]} للموظف');
  }

  Future<void> _assignSelected() async {
    if (_targetEmployee == null || _selectedGroups.isEmpty) return;
    setState(() => _busy = true);
    final n = await context
        .read<AppProvider>()
        .bulkAssign(_selectedGroups.toList(), _targetEmployee!);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context);
    AppSnackbar.show(context, '✅ تم إسناد $n مجموعة للموظف');
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final groups = prov.db.groups;
    // اللي ظاهر في قايمة الاختيار اليدوي بعد البحث — البحث بيستخدم نفس
    // محرّك البحث بتاع البرنامج (بيلاقي «احمد» لما تكتب «أحمد» و«٠١٠» بـ «010»)
    final visible = _q.trim().isEmpty
        ? groups
        : groups
            .where((g) => searchMatches(_q, [g.phone, g.ownerName ?? '']))
            .toList();
    final allVisibleSelected = visible.isNotEmpty &&
        visible.every((g) => _selectedGroups.contains(g.id));
    String empName(String id) => widget.employees.firstWhere(
        (e) => e['id'] == id,
        orElse: () => {'name': '—'})['name']!;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF6a1b9a), Color(0xFF8e24aa)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(children: [
                const Icon(Icons.shuffle, color: Colors.white),
                const SizedBox(width: 8),
                Text('توزيع الشغل على الموظفين',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ]),
            ),
            Expanded(
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.all(14),
                      children: [
                        // #4 توزيع تلقائي
                        _sectionTitle('⚖️ توزيع تلقائي بالتساوي'),
                        Text(
                            'يقسّم ${groups.length} مجموعة على ${widget.employees.length} موظف بالتساوي (بالترتيب).',
                            style: GoogleFonts.cairo(
                                fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _autoDistribute,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6a1b9a)),
                          label: Text('وزّع بالتساوي',
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const Divider(height: 28),
                        // اختيار الموظف الهدف (لـ #5 و #6)
                        _sectionTitle('👤 الموظف المستهدف'),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final e in widget.employees)
                            ChoiceChip(
                              label: Text(e['name']!,
                                  style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _targetEmployee == e['id']
                                          ? Colors.white
                                          : AppColors.text)),
                              selected: _targetEmployee == e['id'],
                              selectedColor: const Color(0xFF6a1b9a),
                              onSelected: (_) =>
                                  setState(() => _targetEmployee = e['id']),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        // #5 توزيع بالشركة
                        _sectionTitle('🏢 إسناد كل خطوط شركة للموظف'),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final p in _provNames.entries)
                            ActionChip(
                              label: Text(
                                  '${p.value} (${groups.where((g) => g.provider == p.key).length})',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: _targetEmployee == null
                                  ? null
                                  : () => _assignByProvider(p.key),
                            ),
                        ]),
                        const Divider(height: 28),
                        // #6 اختيار يدوي — مع تحديد جماعي وتحديد بالنوع
                        _sectionTitle(
                            '☑️ اختيار يدوي (${_selectedGroups.length} من ${visible.length} مختارة)'),
                        // 🔍 بحث بالرقم أو الاسم
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _q = v),
                          style: GoogleFonts.cairo(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'دوّر برقم الخط أو اسم صاحبه...',
                            hintStyle: GoogleFonts.cairo(
                                fontSize: 12, color: AppColors.muted),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _q.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => setState(() {
                                      _searchCtrl.clear();
                                      _q = '';
                                    }),
                                  ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ✅ تحديد جماعي — بيشتغل على اللي ظاهر قدامك بس
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: allVisibleSelected
                                  ? () => _deselect(visible)
                                  : () => _select(visible),
                              icon: Icon(
                                  allVisibleSelected
                                      ? Icons.remove_done
                                      : Icons.done_all,
                                  size: 17),
                              label: Text(
                                  allVisibleSelected
                                      ? 'شيل التحديد'
                                      : 'حدّد الكل (${visible.length})',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _invert(visible),
                            icon: const Icon(Icons.swap_horiz, size: 17),
                            label: Text('اعكس',
                                style: GoogleFonts.cairo(
                                    fontSize: 12, fontWeight: FontWeight.w900)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        // 🎯 تحديد بالنوع — دوسة واحدة تحدد كل خطوط الشركة
                        // أو السيكل أو اللي لسه مش موكلة لحد.
                        Text('حدّد حسب النوع:',
                            style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.muted)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final p in _provNames.entries)
                            _pickChip(
                                p.value,
                                visible
                                    .where((g) => g.provider == p.key)
                                    .toList()),
                          for (final k in _cyclesOf(visible))
                            _pickChip(
                                cycleShortOf(k),
                                visible
                                    .where((g) => cycleKeyOf(g) == k)
                                    .toList()),
                          _pickChip(
                              '👤 غير موكلة',
                              visible
                                  .where((g) => prov.assigneeOf(g.id) == null)
                                  .toList()),
                        ]),
                        const SizedBox(height: 8),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text('مفيش خطوط بالبحث ده',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12, color: AppColors.muted)),
                            ),
                          ),
                        ...visible.map((g) {
                          final assignee = prov.assigneeOf(g.id);
                          return CheckboxListTile(
                            dense: true,
                            value: _selectedGroups.contains(g.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedGroups.add(g.id);
                              } else {
                                _selectedGroups.remove(g.id);
                              }
                            }),
                            title: Text(g.phone,
                                style: GoogleFonts.cairo(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            subtitle: assignee != null
                                ? Text('مع: $assignee',
                                    style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        color: const Color(0xFF6a1b9a)))
                                : null,
                          );
                        }),
                      ],
                    ),
            ),
            if (!_busy && _selectedGroups.isNotEmpty)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    onPressed: _assignSelected,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6a1b9a),
                        minimumSize: const Size.fromHeight(46)),
                    child: Text(
                        'إسناد ${_selectedGroups.length} مجموعة لـ ${empName(_targetEmployee ?? '')}',
                        style: GoogleFonts.cairo(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(t,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: const Color(0xFF6a1b9a))),
      );
}

// ─────────────────────────────────────────────────────────────────
// شيت أداء الموظفين (#8 متابعة لكل موظف + #10 مقارنة)
// ─────────────────────────────────────────────────────────────────
class _PerformanceSheet extends StatefulWidget {
  final List<String> employeeNames;
  const _PerformanceSheet({required this.employeeNames});
  @override
  State<_PerformanceSheet> createState() => _PerformanceSheetState();
}

class _PerformanceSheetState extends State<_PerformanceSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await SupabaseService.fetchAuditLogs(limit: 1000);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  bool _isToday(dynamic ts) {
    final d = DateTime.tryParse((ts ?? '').toString())?.toLocal();
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isPay(String type) =>
      type.contains('pay') || type.contains('سداد') || type.contains('bill_pay');

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // عدد المجموعات لكل موظف (من خريطة المسؤول)
    final groupsByEmp = <String, int>{};
    for (final name in prov.assigneeOfValues) {
      groupsByEmp[name] = (groupsByEmp[name] ?? 0) + 1;
    }
    // تجميع الحركات لكل موظف من user_type ("موظف: الاسم")
    final stats = <String, Map<String, dynamic>>{};
    for (final name in widget.employeeNames) {
      stats[name] = {'total': 0, 'today': 0, 'payToday': 0, 'last': null};
    }
    for (final e in _logs) {
      final by = (e['user_type'] ?? '').toString();
      String? who;
      for (final name in widget.employeeNames) {
        if (by.contains(name)) { who = name; break; }
      }
      if (who == null) continue;
      final s = stats[who]!;
      s['total'] = (s['total'] as int) + 1;
      final ts = e['client_ts'] ?? e['created_at'];
      final type = (e['action_type'] ?? '').toString();
      if (_isToday(ts)) {
        s['today'] = (s['today'] as int) + 1;
        if (_isPay(type)) s['payToday'] = (s['payToday'] as int) + 1;
      }
      final dt = DateTime.tryParse((ts ?? '').toString());
      if (dt != null) {
        final cur = s['last'] as DateTime?;
        if (cur == null || dt.isAfter(cur)) s['last'] = dt;
      }
    }
    // ترتيب حسب نشاط النهارده (#10 مقارنة)
    final sorted = [...widget.employeeNames]
      ..sort((a, b) =>
          (stats[b]!['today'] as int).compareTo(stats[a]!['today'] as int));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF00695c), Color(0xFF00897b)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(children: [
                const Icon(Icons.leaderboard, color: Colors.white),
                const SizedBox(width: 8),
                Text('أداء الموظفين النهارده',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.all(14),
                      children: [
                        if (widget.employeeNames.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('مفيش موظفين مفعّلين',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(color: AppColors.muted)),
                          ),
                        for (var i = 0; i < sorted.length; i++)
                          _empCard(i, sorted[i], stats[sorted[i]]!,
                              groupsByEmp[sorted[i]] ?? 0),
                      ],
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _empCard(int rank, String name, Map<String, dynamic> s, int groups) {
    final last = s['last'] as DateTime?;
    final lastStr = last == null
        ? 'مفيش نشاط'
        : '${last.toLocal().hour.toString().padLeft(2, '0')}:${last.toLocal().minute.toString().padLeft(2, '0')} — ${last.toLocal().day}/${last.toLocal().month}';
    final medal = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '•';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$medal ', style: const TextStyle(fontSize: 16)),
          Expanded(
            child: Text(name,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: const Color(0xFF00695c))),
          ),
          Text('آخر نشاط: $lastStr',
              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _stat('📡 مجموعاته', '$groups'),
          _stat('⚡ النهارده', '${s['today']}'),
          _stat('💳 تحصيلات', '${s['payToday']}'),
          _stat('Σ الكل', '${s['total']}'),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.blue2)),
          Text(label,
              style: GoogleFonts.cairo(fontSize: 9, color: AppColors.muted)),
        ]),
      );
}
