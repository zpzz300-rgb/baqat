// lib/screens/activity_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../widgets/member_card.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'all';
  String _byFilter = 'all';   // فلتر حسب الموظف/المالك (user_type)
  DateTime? _dayFilter;        // فلتر حسب يوم محدد
  late Future<List<Map<String, dynamic>>> _future;

  final _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'add', 'label': '➕ إضافة'},
    {'key': 'edit', 'label': '✏️ تعديل'},
    {'key': 'pay', 'label': '💰 دفع'},
    {'key': 'charge', 'label': '➖ خصم'},
    {'key': 'message', 'label': '💬 رسائل'},
    {'key': 'move', 'label': '🔀 نقل'},
    {'key': 'service', 'label': '🔌 خدمة/نت'},
    {'key': 'delete', 'label': '🗑 حذف'},
    {'key': 'bill', 'label': '📅 اشتراك'},
  ];

  @override
  void initState() {
    super.initState();
    _future = context.read<AppProvider>().fetchServerAudit();
  }

  void _refresh() {
    setState(() {
      _future = context.read<AppProvider>().fetchServerAudit();
    });
  }

  /// يوحّد شكل السطر سواء جاي من السيرفر أو النسخة المحلية.
  Map<String, dynamic> _norm(Map<String, dynamic> e) {
    final isServer = e.containsKey('action_type') || e.containsKey('details');
    if (isServer) {
      return {
        'type': e['action_type'] ?? '',
        'desc': e['details'] ?? '',
        'by': e['user_type'] ?? '',
        'isEmployee': e['is_employee'] == true,
        'targetId': e['target_id'],
        'targetType': e['target_type'],
        'when': _fmt(e['client_ts'] ?? e['created_at']),
        'dt': DateTime.tryParse((e['client_ts'] ?? e['created_at'] ?? '').toString())?.toLocal(),
      };
    }
    return {
      'type': e['type'] ?? '',
      'desc': e['desc'] ?? '',
      'by': e['by'] ?? '',
      'isEmployee': e['isEmployee'] == true,
      'targetId': e['targetId'],
      'targetType': e['targetType'],
      'when': e['ts'] != null
          ? _fmt(e['ts'])
          : '${e['date'] ?? ''}${e['time'] != null ? ' - ${e['time']}' : ''}',
      'dt': DateTime.tryParse((e['ts'] ?? '').toString())?.toLocal(),
    };
  }

  String _fmt(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString())?.toLocal();
    if (d == null) return iso.toString();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} - ${two(d.hour)}:${two(d.minute)}';
  }

  Color _dotColor(String type) {
    switch (type) {
      case 'add': return AppColors.green;
      case 'pay': return AppColors.blue;
      case 'charge': return AppColors.orange;
      case 'delete': return AppColors.red;
      case 'bill': return AppColors.orange;
      case 'message': return AppColors.blue2;
      case 'move': return Colors.purple;
      case 'service': return Colors.teal;
      default: return AppColors.muted;
    }
  }

  /// الضغط على السطر → يفتح العنصر المرتبط (الرابط النشط).
  void _openTarget(AppProvider prov, String? type, String? id) {
    if (id == null || type == null) return;
    if (type == 'member') {
      final idx = prov.db.members.indexWhere((m) => m.id == id);
      if (idx < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('العميل لم يعد موجوداً (محذوف)')),
        );
        return;
      }
      final m = prov.db.members[idx];
      final g = prov.db.groups.firstWhere((x) => x.id == m.gid,
          orElse: () => Group(id: '', phone: '—'));
      showModalBottomSheet(
        useRootNavigator: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (_) =>
            MemberDrawer(member: m, group: g, parentContext: context),
      );
      return;
    }
    // أنواع أخرى (مجموعة/إيجار/رقم عمل): تنبيه بسيط
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('عنصر من نوع: $type')),
    );
  }

  void _confirmClear(AppProvider prov) {
    final pinCtrl = TextEditingController();
    String? err;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('مسح السجل المحلي',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '🔒 السجل الرسمي محفوظ على السيرفر ولا يمكن مسحه نهائياً.\nهذا يمسح النسخة الظاهرة على الجهاز فقط، ويتطلب الرقم السري للمالك.',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  labelText: 'الرقم السري للمالك',
                  labelStyle: GoogleFonts.cairo(),
                  errorText: err,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () {
                if (SupabaseService.isEmployee) {
                  setSt(() => err = '🚫 غير مسموح — هذه صلاحية المالك فقط');
                  return;
                }
                final ok = prov.clearActivityLog(pinCtrl.text.trim());
                if (!ok) {
                  setSt(() => err = '❌ الرقم السري غير صحيح');
                  return;
                }
                Navigator.pop(ctx);
                _refresh();
              },
              child: Text('مسح',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  /// شريط فلترة المالك: حسب الموظف + حسب اليوم.
  Widget _auditFilterBar(List<String> actors) {
    final dayLabel = _dayFilter == null
        ? 'كل الأيام'
        : '${_dayFilter!.year}/${_dayFilter!.month.toString().padLeft(2, '0')}/${_dayFilter!.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: actors.contains(_byFilter) ? _byFilter : 'all',
                icon: const Icon(Icons.person_outline, size: 18),
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.blue2,
                    fontWeight: FontWeight.w700),
                items: [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('كل الموظفين',
                          style: GoogleFonts.cairo(fontSize: 12))),
                  ...actors.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a,
                          style: GoogleFonts.cairo(fontSize: 12),
                          overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _byFilter = v ?? 'all'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _dayFilter ?? now,
              firstDate: DateTime(2024),
              lastDate: now,
            );
            if (picked != null) setState(() => _dayFilter = picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _dayFilter != null ? AppColors.blue2 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today,
                  size: 14,
                  color: _dayFilter != null ? Colors.white : AppColors.blue2),
              const SizedBox(width: 6),
              Text(dayLabel,
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          _dayFilter != null ? Colors.white : AppColors.blue2)),
            ]),
          ),
        ),
        if (_dayFilter != null)
          IconButton(
            onPressed: () => setState(() => _dayFilter = null),
            icon: const Icon(Icons.close, size: 18, color: AppColors.red),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📋 سجل النشاط الكامل (الصندوق الأسود)',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            color: AppColors.blue2,
                            fontSize: 14)),
                    Text('كل حركة محفوظة على السيرفر — مين عمل إيه وامتى',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: AppColors.blue2),
                tooltip: 'تحديث',
              ),
              GestureDetector(
                onTap: () => _confirmClear(prov),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFef9a9a)),
                  ),
                  child: Text('🗑 مسح',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                          color: AppColors.red2,
                          fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f = _filters[i];
                final active = _filter == f['key'];
                return GestureDetector(
                  onTap: () => setState(() => _filter = f['key']!),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.headerGradient : null,
                      color: active ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: active
                          ? null
                          : Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Text(f['label']!,
                        style: GoogleFonts.cairo(
                            color: active ? Colors.white : AppColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Log list
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // مصدر البيانات: السيرفر لو متاح، وإلا النسخة المحلية
              final server = snap.data ?? [];
              final source = server.isNotEmpty
                  ? server
                  : prov.db.activityLog;
              final all = source.map(_norm).toList();
              // قائمة الموظفين/المالك المتاحين للفلترة
              final actors = <String>{
                for (final e in all)
                  if ((e['by'] as String).isNotEmpty) e['by'] as String
              }.toList()
                ..sort();
              final rows = all.where((e) {
                if (_filter != 'all' && e['type'] != _filter) return false;
                if (_byFilter != 'all' && e['by'] != _byFilter) return false;
                if (_dayFilter != null) {
                  final dt = e['dt'] as DateTime?;
                  if (dt == null ||
                      dt.year != _dayFilter!.year ||
                      dt.month != _dayFilter!.month ||
                      dt.day != _dayFilter!.day) {
                    return false;
                  }
                }
                return true;
              }).toList();

              return Column(children: [
                _auditFilterBar(actors),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text('لا يوجد نشاط مطابق للفلاتر',
                              style: GoogleFonts.cairo(color: AppColors.muted)))
                      : RefreshIndicator(
                          onRefresh: () async => _refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final e = rows[i];
                    final type = e['type'] as String;
                    final tid = e['targetId'] as String?;
                    final ttype = e['targetType'] as String?;
                    final clickable = tid != null && ttype != null;
                    final isEmp = e['isEmployee'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: clickable
                              ? () => _openTarget(prov, ttype, tid)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: _dotColor(type),
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e['desc'] ?? '',
                                          style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isEmp
                                                  ? const Color(0xFFFFF3E0)
                                                  : const Color(0xFFE3F2FD),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                                isEmp
                                                    ? '👤 ${e['by']}'
                                                    : '${e['by']}',
                                                style: GoogleFonts.cairo(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isEmp
                                                        ? AppColors.orange
                                                        : AppColors.blue2)),
                                          ),
                                          const SizedBox(width: 6),
                                          if (clickable)
                                            Text('• اضغط للفتح',
                                                style: GoogleFonts.cairo(
                                                    fontSize: 10,
                                                    color: AppColors.blue)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(e['when'] ?? '',
                                    style: GoogleFonts.cairo(
                                        fontSize: 10, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ]);
            },
          ),
        ),
      ],
    );
  }
}
