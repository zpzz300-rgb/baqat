// lib/screens/bulk_message_screen.dart
// إرسال رسائل جماعية للمديونيات مع تنبيهات مجدولة
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/notification_service.dart';

class BulkMessageScreen extends StatefulWidget {
  const BulkMessageScreen({super.key});

  @override
  State<BulkMessageScreen> createState() => _BulkMessageScreenState();
}

class _BulkMessageScreenState extends State<BulkMessageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final Set<String> _selected = {};
  String _filter = 'debt'; // debt / all
  String _msgTemplate = '';
  bool _sending = false;
  int _sentCount = 0;

  // Scheduled reminder
  TimeOfDay? _scheduledTime;
  bool _scheduleEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTemplate());
  }

  void _initTemplate() {
    final prov = context.read<AppProvider>();
    final instapay = prov.instapayPhone.isNotEmpty ? '\n📲 InstaPay: ${prov.instapayPhone}' : '';
    final vodafone = prov.vodafoneCash.isNotEmpty ? '\n📱 فودافون كاش: ${prov.vodafoneCash}' : '';
    setState(() {
      _msgTemplate =
          'السلام عليكم {name} 👋\n🔴 مديونيتك: {debt} ج\n💳 الاشتراك: {price} ج/شهر$instapay$vodafone\nنرجو السداد، شكراً 🙏';
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Member> _getMembers(AppProvider prov) {
    if (_filter == 'debt') return prov.db.members.where((m) => m.balance < 0).toList();
    return prov.db.members;
  }

  String _buildMsg(Member m, String template) {
    final debt = m.balance < 0 ? -m.balance : 0.0;
    return template
        .replaceAll('{name}', m.name)
        .replaceAll('{debt}', debt.toStringAsFixed(0))
        .replaceAll('{price}', m.price.toStringAsFixed(0))
        .replaceAll('{phone}', m.phone);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final members = _getMembers(prov);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.blue2,
        foregroundColor: Colors.white,
        title: Text('📤 رسائل جماعية', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [Tab(text: 'اختيار العملاء'), Tab(text: 'التنبيهات المجدولة')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSendTab(prov, members),
          _buildScheduleTab(prov),
        ],
      ),
    );
  }

  Widget _buildSendTab(AppProvider prov, List<Member> members) {
    return Column(
      children: [
        // Filter + select all bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _filterChip('🔴 ديون', 'debt'),
            const SizedBox(width: 8),
            _filterChip('الكل', 'all'),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                if (_selected.length == members.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(members.map((m) => m.id));
                }
              }),
              child: Text(
                _selected.length == members.length ? 'إلغاء الكل' : 'تحديد الكل',
                style: GoogleFonts.cairo(fontSize: 12),
              ),
            ),
          ]),
        ),

        // Message template
        Container(
          color: const Color(0xFFF8F9FA),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('✏️ قالب الرسالة — {name} {debt} {price} متغيرات تلقائية',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 4),
            TextField(
              controller: TextEditingController(text: _msgTemplate),
              maxLines: 3,
              style: GoogleFonts.cairo(fontSize: 12),
              textDirection: TextDirection.rtl,
              onChanged: (v) => _msgTemplate = v,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ]),
        ),

        // Members list
        Expanded(
          child: members.isEmpty
              ? Center(child: Text('لا يوجد عملاء في هذا الفلتر',
                  style: GoogleFonts.cairo(color: AppColors.muted)))
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final debt = m.balance < 0 ? -m.balance : 0.0;
                    return CheckboxListTile(
                      dense: true,
                      value: _selected.contains(m.id),
                      onChanged: (v) => setState(() =>
                          v == true ? _selected.add(m.id) : _selected.remove(m.id)),
                      title: Text(m.name,
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${m.phone}  •  ${m.package}',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
                      ),
                      secondary: debt > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.redLight, borderRadius: BorderRadius.circular(6)),
                              child: Text('${debt.toStringAsFixed(0)} ج',
                                  style: GoogleFonts.cairo(
                                      fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.red2)),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.greenLight, borderRadius: BorderRadius.circular(6)),
                              child: Text('✅',
                                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.green)),
                            ),
                    );
                  },
                ),
        ),

        // Send button
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(children: [
            if (_sending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(width: 12),
                  Text('جاري الإرسال... $_sentCount/${_selected.length}',
                      style: GoogleFonts.cairo(fontSize: 12)),
                ]),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.send),
                label: Text(
                  'إرسال لـ ${_selected.length} عميل عبر واتساب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: _selected.isEmpty || _sending
                    ? null
                    : () => _sendAll(prov, members),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildScheduleTab(AppProvider prov) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🔔 تنبيهات يومية للمديونيات',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.blue2)),
            const SizedBox(height: 4),
            Text('ستصلك إشعارات يومية بأسماء العملاء الذين عليهم ديون',
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('تفعيل التنبيهات اليومية',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700))),
              Switch(
                value: _scheduleEnabled,
                activeThumbColor: AppColors.blue2,
                onChanged: (v) async {
                  setState(() => _scheduleEnabled = v);
                  if (!v) {
                    await NotificationService.cancelDebtReminder();
                  } else if (_scheduledTime != null) {
                    await _scheduleNotification(prov);
                  }
                },
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('وقت التنبيه', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  _scheduledTime != null
                      ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
                      : 'لم يُحدد بعد',
                  style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w900,
                      color: _scheduledTime != null ? AppColors.blue2 : AppColors.muted),
                ),
              ])),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue2,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) {
                    setState(() => _scheduledTime = picked);
                    if (_scheduleEnabled) await _scheduleNotification(prov);
                  }
                },
                child: Text('اختر الوقت', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              ),
            ]),
            if (_scheduleEnabled && _scheduledTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: AppColors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'سيصلك تنبيه يومياً في ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.green2, fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Debtors summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📊 ملخص المديونيات الحالية',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.blue2)),
            const SizedBox(height: 12),
            ...prov.db.members.where((m) => m.balance < 0).map((m) {
              final debt = -m.balance;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: Text(m.name,
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('${debt.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.red2)),
                ]),
              );
            }),
            if (prov.db.debtorCount == 0)
              Text('✅ لا توجد مديونيات', style: GoogleFonts.cairo(color: AppColors.muted)),
          ]),
        ),
      ],
    );
  }

  Future<void> _scheduleNotification(AppProvider prov) async {
    if (_scheduledTime == null) return;
    final debtors = prov.db.members.where((m) => m.balance < 0).toList();
    final names = debtors.take(5).map((m) => m.name).join('، ');
    final body = debtors.isEmpty
        ? 'لا توجد مديونيات اليوم ✅'
        : '${debtors.length} عملاء عليهم ديون: $names';

    await NotificationService.scheduleDailyDebtReminder(
      hour: _scheduledTime!.hour,
      minute: _scheduledTime!.minute,
      title: '🔔 تذكير يومي بالمديونيات',
      body: body,
    );
  }

  Future<void> _sendAll(AppProvider prov, List<Member> members) async {
    setState(() { _sending = true; _sentCount = 0; });
    final toSend = members.where((m) => _selected.contains(m.id)).toList();

    for (final m in toSend) {
      final msg = _buildMsg(m, _msgTemplate);
      final phone = m.waPhone.replaceFirst(RegExp(r'^0'), '20');
      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}';
      if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
      setState(() => _sentCount++);
      await Future.delayed(const Duration(seconds: 2));
    }

    setState(() { _sending = false; _sentCount = 0; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم إرسال ${toSend.length} رسالة',
            style: GoogleFonts.cairo())));
    }
  }

  Widget _filterChip(String label, String val) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = val;
          _selected.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.blue2 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.blue2 : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : AppColors.muted)),
      ),
    );
  }
}
