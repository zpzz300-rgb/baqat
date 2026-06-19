// lib/screens/employees_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppProvider>(),
        child: _DistributeSheet(employees: active),
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
                color: Colors.white,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(radius: 18, backgroundColor: Color(0xFFe3f2fd),
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
          SizedBox(
            width: double.infinity,
            child: _btn('📡 المجموعات المتابَعة', AppColors.blue2,
                () => _openAssign(id, name)),
          ),
        ],
      ]),
    );
  }

  void _openAssign(String employeeId, String employeeName) {
    final groups = context.read<AppProvider>().db.groups;
    final empNames = {
      for (final e in _employees) e['id'].toString(): (e['name'] ?? '').toString()
    };
    showModalBottomSheet(
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
          decoration: const BoxDecoration(
            color: Color(0xFFf8fbff),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.groups.isEmpty
                      ? Center(
                          child: Text('لا توجد مجموعات.',
                              style: GoogleFonts.cairo(color: AppColors.muted)))
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                          itemCount: widget.groups.length,
                          itemBuilder: (_, i) {
                            final g = widget.groups[i];
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
                                color: Colors.white,
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                        // #6 جماعي Checkbox
                        _sectionTitle(
                            '☑️ اختيار يدوي (${_selectedGroups.length} مختارة)'),
                        ...groups.map((g) {
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
