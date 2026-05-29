// lib/screens/reminders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/notification_service.dart';
import '../models/models.dart';
import '../widgets/member_card.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  List<PendingNotificationRequest> _pending = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
    _tab.addListener(() => setState(() {}));
  }

  Future<void> _loadPending() async {
    final list = await NotificationService.listPending();
    if (mounted) setState(() => _pending = list);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Tab bar ─────────────────────────────────────────────
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelStyle:
              GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
          labelColor: AppColors.blue2,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.blue2,
          tabs: const [
            Tab(text: '⚙️ الإعدادات'),
            Tab(text: '📋 الجدول'),
            Tab(text: '🔴 المدينون'),
            Tab(text: '⏰ التأجيلات'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tab, children: [
          _SettingsTab(onChanged: _loadPending),
          _ScheduleTab(pending: _pending, onRefresh: _loadPending),
          const _DebtorsTab(),
          const _DeferralsTab(),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════
// TAB 1 — إعدادات الإشعارات
// ══════════════════════════════════════════════════════
class _SettingsTab extends StatelessWidget {
  final VoidCallback onChanged;
  const _SettingsTab({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    // Stats
    final debtors = prov.db.members.where((m) => m.balance < 0).length;
    final expiringLines = _countExpiring(prov.db.groups, 30);
    final endingOffers = _countOffersEnding(prov.db.groups, 30);
    final vouchersDue = _countVouchersDue(prov.db.groups, 30);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Summary stats ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text('📊 حالة التنبيهات الآن',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              _statPill('$debtors مديون', '🔴', debtors > 0),
              const SizedBox(width: 8),
              _statPill(
                  '$expiringLines خط ينتهي (30 يوم)', '⚠️', expiringLines > 0),
              const SizedBox(width: 8),
              _statPill('$endingOffers عرض ينتهي', '🎁', endingOffers > 0),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _statPill('$vouchersDue قسيمة قادمة', '🎫', vouchersDue > 0),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // ── 1. Daily debt reminder ─────────────────────────
        _NotifCard(
          emoji: '🔔',
          title: 'تذكير المديونيات اليومي',
          subtitle: 'إشعار يومي بعدد العملاء المدينين وإجمالي الديون',
          active: prov.notifDailyDebt,
          onToggle: (v) {
            prov.setNotifDailyDebt(v);
            onChanged();
          },
          children: [
            _TimeRow(
              label: 'وقت الإشعار',
              value: prov.notifDailyDebtTime,
              onChanged: (t) {
                prov.setNotifDailyDebtTime(t);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── 2. Line expiry warning ─────────────────────────
        _NotifCard(
          emoji: '📅',
          title: 'تنبيه انتهاء الخطوط',
          subtitle: 'تذكير عند اقتراب موعد انتهاء أي خط',
          active: prov.notifExpiry,
          badge: expiringLines > 0 ? '$expiringLines خط' : null,
          onToggle: (v) {
            prov.setNotifExpiry(v);
            onChanged();
          },
          children: [
            _DaysRow(
              label: 'التنبيه قبل',
              value: prov.notifExpiryDays,
              options: const [1, 3, 7, 14, 30],
              onChanged: (d) {
                prov.setNotifExpiryDays(d);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── 3. Voucher alerts ──────────────────────────────
        _NotifCard(
          emoji: '🎫',
          title: 'تنبيه مواعيد القسائم',
          subtitle: 'إشعار قبل موعد تطبيق القسيمة',
          active: prov.notifVoucher,
          badge: vouchersDue > 0 ? '$vouchersDue قسيمة' : null,
          onToggle: (v) {
            prov.setNotifVoucher(v);
            onChanged();
          },
          children: [
            _DaysRow(
              label: 'التنبيه قبل',
              value: prov.notifVoucherDays,
              options: const [0, 1, 3, 7],
              onChanged: (d) {
                prov.setNotifVoucherDays(d);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── 4. Offer end alerts ────────────────────────────
        _NotifCard(
          emoji: '🎁',
          title: 'تنبيه انتهاء العروض',
          subtitle: 'تذكير عند اقتراب انتهاء عروض الخطوط',
          active: prov.notifOffer,
          badge: endingOffers > 0 ? '$endingOffers عرض' : null,
          onToggle: (v) {
            prov.setNotifOffer(v);
            onChanged();
          },
          children: [
            _DaysRow(
              label: 'التنبيه قبل',
              value: prov.notifOfferDays,
              options: const [1, 3, 7, 14, 30],
              onChanged: (d) {
                prov.setNotifOfferDays(d);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── 5. Weekly summary ──────────────────────────────
        _NotifCard(
          emoji: '📊',
          title: 'ملخص أسبوعي',
          subtitle: 'تقرير كل أحد بإجمالي الديون والمديونيات',
          active: prov.notifWeekly,
          onToggle: (v) {
            prov.setNotifWeekly(v);
            onChanged();
          },
        ),
        const SizedBox(height: 10),

        // ── 6. Monthly collection ──────────────────────────
        _NotifCard(
          emoji: '💰',
          title: 'تذكير التحصيل الشهري',
          subtitle: 'إشعار يوم بداية التحصيل كل شهر',
          active: prov.notifMonthly,
          onToggle: (v) {
            prov.setNotifMonthly(v);
            onChanged();
          },
          children: [
            _MonthDayRow(
              value: prov.notifMonthlyDay,
              onChanged: (d) {
                prov.setNotifMonthlyDay(d);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Apply all button ───────────────────────────────
        ElevatedButton.icon(
          onPressed: () {
            context.read<AppProvider>().applyAllNotifications();
            onChanged();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('✅ تم تطبيق جميع إعدادات الإشعارات',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              backgroundColor: AppColors.green2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          },
          icon: const Icon(Icons.notifications_active),
          label: Text('تطبيق الإعدادات الآن',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue2,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        // Test instant notification
        OutlinedButton.icon(
          onPressed: () async {
            final pv = context.read<AppProvider>();
            final d = pv.db.members.where((m) => m.balance < 0).length;
            final t = pv.db.totalDebt;
            await NotificationService.showInstant(
              title: '🔔 اختبار الإشعار',
              body: d > 0
                  ? '$d عميل مدين — إجمالي: ${t.toStringAsFixed(0)} ج'
                  : '✅ لا توجد مديونيات',
            );
          },
          icon: const Icon(Icons.send, size: 18),
          label: Text('🧪 اختبار إشعار فوري',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700, color: AppColors.blue2)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: AppColors.blue2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _statPill(String label, String emoji, bool highlight) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$emoji $label',
            style: GoogleFonts.cairo(
                fontSize: 11,
                color: Colors.white,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w400),
            textAlign: TextAlign.center),
      ),
    );
  }

  int _countExpiring(List<Group> groups, int withinDays) {
    final limit = DateTime.now().add(Duration(days: withinDays));
    return groups.where((g) {
      if (g.expiryDate == null) return false;
      final d = _pd(g.expiryDate!);
      return d != null && d.isBefore(limit) && d.isAfter(DateTime.now());
    }).length;
  }

  int _countOffersEnding(List<Group> groups, int withinDays) {
    final limit = DateTime.now().add(Duration(days: withinDays));
    return groups.where((g) {
      if (g.offerEndDate == null) return false;
      final d = _pd(g.offerEndDate!);
      return d != null && d.isBefore(limit) && d.isAfter(DateTime.now());
    }).length;
  }

  int _countVouchersDue(List<Group> groups, int withinDays) {
    final limit = DateTime.now().add(Duration(days: withinDays));
    return groups.where((g) {
      if (g.voucherValue <= 0) return false;
      final next = NotificationService.nextVoucherDate(
          g.voucherStartDate, g.voucherPeriod);
      return next != null && next.isBefore(limit);
    }).length;
  }

  DateTime? _pd(String s) {
    final p = s.split('-');
    if (p.length < 2) return null;
    return DateTime(int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0,
        p.length > 2 ? (int.tryParse(p[2]) ?? 1) : 1);
  }
}

// ══════════════════════════════════════════════════════
// TAB 2 — الجدول القادم
// ══════════════════════════════════════════════════════
class _ScheduleTab extends StatelessWidget {
  final List<PendingNotificationRequest> pending;
  final VoidCallback onRefresh;
  const _ScheduleTab({required this.pending, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final events = _buildEvents(prov);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Active scheduled count ──────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFe8f4fd),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.blueMid),
          ),
          child: Row(children: [
            const Icon(Icons.notifications_active,
                color: AppColors.blue2, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text('${pending.length} إشعار مجدول نشط على التليفون',
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.blue2,
                        fontWeight: FontWeight.w700))),
            GestureDetector(
              onTap: onRefresh,
              child:
                  const Icon(Icons.refresh, color: AppColors.blue2, size: 20),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        if (events.isEmpty)
          Center(
              child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              const Text('🗓', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('لا توجد أحداث قادمة',
                  style:
                      GoogleFonts.cairo(color: AppColors.muted, fontSize: 13)),
            ]),
          ))
        else ...[
          Text('📋 الأحداث القادمة (90 يوم)',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue2,
                  fontSize: 13)),
          const SizedBox(height: 8),
          ...events.map((e) => _EventRow(event: e)),
        ],

        // ── Active pending list ──────────────────────────────
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            Text('⏰ الإشعارات المجدولة النشطة',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue2,
                    fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                await NotificationService.cancelAll();
                prov.applyAllNotifications();
                onRefresh();
              },
              child: Text('إلغاء الكل',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.red)),
            ),
          ]),
          const SizedBox(height: 8),
          ...pending.take(20).map((n) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.alarm, size: 16, color: AppColors.blue2),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(n.title ?? '—',
                            style: GoogleFonts.cairo(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        if (n.body != null)
                          Text(n.body!,
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: AppColors.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ])),
                  GestureDetector(
                    onTap: () async {
                      await NotificationService.cancelVoucherAlert(n.id);
                      onRefresh();
                    },
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.muted),
                  ),
                ]),
              )),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  List<_UpcomingEvent> _buildEvents(AppProvider prov) {
    final events = <_UpcomingEvent>[];
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 90));

    for (final g in prov.db.groups) {
      // Expiry
      if (g.expiryDate != null) {
        final d = _pd(g.expiryDate!);
        if (d != null && d.isAfter(now) && d.isBefore(limit)) {
          events.add(_UpcomingEvent(
            type: 'expiry',
            date: d,
            icon: '⚠️',
            title: 'انتهاء خط ${g.phone}',
            subtitle: 'تاريخ الانتهاء: ${g.expiryDate}',
            color: AppColors.orange,
          ));
        }
      }
      // Offer end
      if (g.offerEndDate != null) {
        final d = _pd(g.offerEndDate!);
        if (d != null && d.isAfter(now) && d.isBefore(limit)) {
          events.add(_UpcomingEvent(
            type: 'offer',
            date: d,
            icon: '🎁',
            title: 'انتهاء عرض ${g.phone}',
            subtitle: 'ينتهي: ${g.offerEndDate}',
            color: AppColors.blue2,
          ));
        }
      }
      // Voucher
      if (g.voucherValue > 0) {
        final next = NotificationService.nextVoucherDate(
            g.voucherStartDate, g.voucherPeriod);
        if (next != null && next.isAfter(now) && next.isBefore(limit)) {
          events.add(_UpcomingEvent(
            type: 'voucher',
            date: next,
            icon: '🎫',
            title: 'قسيمة ${g.groupInvoiceName ?? g.phone}',
            subtitle:
                'قيمة: ${g.voucherValue.toStringAsFixed(0)} ج — الإجمالي: ${(g.fixedBillAmount - g.voucherValue).toStringAsFixed(0)} ج',
            color: AppColors.green,
          ));
        }
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  DateTime? _pd(String s) {
    final p = s.split('-');
    if (p.length < 2) return null;
    return DateTime(int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0,
        p.length > 2 ? (int.tryParse(p[2]) ?? 1) : 1);
  }
}

class _UpcomingEvent {
  final String type, icon, title, subtitle;
  final DateTime date;
  final Color color;
  const _UpcomingEvent(
      {required this.type,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.date,
      required this.color});
}

class _EventRow extends StatelessWidget {
  final _UpcomingEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = event.date.difference(now).inDays;
    final urgentColor = diff <= 3
        ? AppColors.red
        : diff <= 7
            ? AppColors.orange
            : AppColors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: diff <= 7
                ? urgentColor.withValues(alpha: 0.5)
                : AppColors.border),
        boxShadow: [
          BoxShadow(color: event.color.withValues(alpha: 0.07), blurRadius: 8)
        ],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: Center(
              child: Text(event.icon, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.title,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.blue2)),
          Text(event.subtitle,
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: urgentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Text(
            diff == 0
                ? 'اليوم'
                : diff == 1
                    ? 'غداً'
                    : 'بعد $diff يوم',
            style: GoogleFonts.cairo(
                fontSize: 11, fontWeight: FontWeight.w700, color: urgentColor),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════
// TAB 3 — المدينون
// ══════════════════════════════════════════════════════
class _DebtorsTab extends StatelessWidget {
  const _DebtorsTab();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final debtors = prov.db.members.where((m) => m.balance < 0).toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));

    if (debtors.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('لا يوجد متأخرات!',
            style: GoogleFonts.cairo(
                color: AppColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        Text('كل العملاء مسددون 👍',
            style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
      ]));
    }

    final totalDebt = debtors.fold(0.0, (s, m) => s + (-m.balance));

    return Column(children: [
      // Summary
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF9A9A))),
          child: Row(children: [
            Text('${debtors.length} عميل مدين',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.red2,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('الإجمالي: ${totalDebt.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.red2,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
          itemCount: debtors.length,
          itemBuilder: (_, i) {
            final m = debtors[i];
            final debt = -m.balance;
            final g = prov.db.groups.firstWhere((x) => x.id == m.gid,
                orElse: () => Group(id: '', phone: '—'));
            final months = m.price > 0 ? (debt / m.price).ceil() : 0;
            final flagColor = m.paymentFlag == 'red'
                ? AppColors.red
                : m.paymentFlag == 'yellow'
                    ? AppColors.orange
                    : m.paymentFlag == 'green'
                        ? AppColors.green
                        : AppColors.muted;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: m.paymentFlag == 'red'
                        ? const Color(0xFFEF9A9A)
                        : AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.05),
                      blurRadius: 10)
                ],
              ),
              child: Row(children: [
                // Flag dot
                Container(
                    width: 6,
                    height: 40,
                    decoration: BoxDecoration(
                        color: flagColor,
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(m.name,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w900, fontSize: 14)),
                      Text('${m.phone} · ${g.phone}',
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: AppColors.muted)),
                      Text(
                          '$months شهر متأخر · ${m.price.toStringAsFixed(0)} ج/شهر',
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _sendWA(m.waPhone, m.name, debt, m.price),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.waGreen,
                              borderRadius: BorderRadius.circular(16)),
                          child: Text('💬 تذكير واتساب',
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ),
                      ),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text('${debt.toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            color: AppColors.red2,
                            fontSize: 16)),
                    Text('مديونية',
                        style: GoogleFonts.cairo(
                            fontSize: 10, color: AppColors.muted)),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _sendWA(
      String phone, String name, double debt, double price) async {
    final p = phone.replaceFirst(RegExp(r'^0'), '20');
    final msg = Uri.encodeComponent(
        'السلام عليكم $name 👋\nإجمالي مديونيتك: ${debt.toStringAsFixed(0)} ج\nالاشتراك الشهري: ${price.toStringAsFixed(0)} ج\nيرجى السداد 🙏');
    final url = 'https://wa.me/$p?text=$msg';
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }
}

// ══════════════════════════════════════════════════════
// TAB 4 — التأجيلات
// ══════════════════════════════════════════════════════
class _DeferralsTab extends StatelessWidget {
  const _DeferralsTab();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final deferred = prov.db.members
        .where((m) => m.deferralDate != null)
        .toList()
      ..sort((a, b) => (a.deferralDate ?? '').compareTo(b.deferralDate ?? ''));

    if (deferred.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('لا توجد تأجيلات',
              style: GoogleFonts.cairo(
                  color: AppColors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text('كل العملاء بدون تأجيل دفع',
              style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
        ]),
      );
    }

    final now = DateTime.now();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.access_time, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text('${deferred.length} عميل مؤجل الدفع',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
          itemCount: deferred.length,
          itemBuilder: (_, i) {
            final m = deferred[i];
            final g = prov.db.groups.firstWhere(
              (x) => x.id == m.gid,
              orElse: () => Group(id: '', phone: '—'),
            );
            final dDate = _pd(m.deferralDate!);
            final daysLeft = dDate?.difference(now).inDays;
            final isOverdue = daysLeft != null && daysLeft < 0;
            final urgentColor = isOverdue
                ? AppColors.red
                : (daysLeft != null && daysLeft <= 2)
                    ? AppColors.orange
                    : AppColors.green;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOverdue ? AppColors.redLight : const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOverdue
                      ? AppColors.red.withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                      color: urgentColor.withValues(alpha: 0.06), blurRadius: 8)
                ],
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900, fontSize: 14)),
                        Text('${m.phone} · ${g.phone}',
                            style: GoogleFonts.cairo(
                                fontSize: 11, color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text('حتى: ${m.deferralDate}',
                              style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange[800])),
                        ]),
                        if (m.deferralNote != null &&
                            m.deferralNote!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(m.deferralNote!,
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: AppColors.muted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 6),
                        Row(children: [
                          GestureDetector(
                            onTap: () => showModalBottomSheet(useRootNavigator: true,
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => MemberDrawer(member: m, group: g),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppColors.blue2,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Text('📂 فتح الملف',
                                  style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              prov.clearMemberDeferral(m.id);
                              await NotificationService.cancelDeferralReminder(
                                  m.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.redLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color:
                                        AppColors.red.withValues(alpha: 0.3)),
                              ),
                              child: Text('إلغاء التأجيل',
                                  style: GoogleFonts.cairo(
                                      color: AppColors.red2,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11)),
                            ),
                          ),
                        ]),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: urgentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Text(
                      isOverdue
                          ? '${(-daysLeft)} يوم'
                          : daysLeft == 0
                              ? 'اليوم'
                              : '$daysLeft يوم',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          color: urgentColor,
                          fontSize: 15),
                    ),
                    Text(
                      isOverdue ? 'تجاوز' : 'متبقي',
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.muted),
                    ),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  DateTime? _pd(String s) {
    final p = s.split('-');
    if (p.length < 2) return null;
    return DateTime(
      int.tryParse(p[0]) ?? 0,
      int.tryParse(p[1]) ?? 0,
      p.length > 2 ? (int.tryParse(p[2]) ?? 1) : 1,
    );
  }
}

// ══════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════
class _NotifCard extends StatefulWidget {
  final String emoji, title, subtitle;
  final bool active;
  final String? badge;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  const _NotifCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onToggle,
    this.badge,
    this.children = const [],
  });

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: widget.active ? AppColors.blueMid : AppColors.border,
            width: widget.active ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue2.withValues(alpha: 0.06), blurRadius: 10)
        ],
      ),
      child: Column(children: [
        InkWell(
          onTap: widget.children.isEmpty
              ? null
              : () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(widget.title,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.blue2)),
                      if (widget.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppColors.redLight,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(widget.badge!,
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.red2,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    Text(widget.subtitle,
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: AppColors.muted)),
                  ])),
              if (widget.children.isNotEmpty)
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.muted),
              const SizedBox(width: 6),
              Switch(
                value: widget.active,
                onChanged: widget.onToggle,
                activeThumbColor: AppColors.blue2,
              ),
            ]),
          ),
        ),
        if (_expanded && widget.children.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFf8fbff),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              border:
                  Border(top: BorderSide(color: AppColors.blueMid, width: 1)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              ...widget.children,
            ]),
          ),
      ]),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  const _TimeRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    return Row(children: [
      Text('$label: ',
          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
      GestureDetector(
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: h, minute: m),
          );
          if (t != null) {
            onChanged(
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(8)),
          child: Text(value,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue2,
                  fontSize: 13)),
        ),
      ),
    ]);
  }
}

class _DaysRow extends StatelessWidget {
  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  const _DaysRow(
      {required this.label,
      required this.value,
      required this.options,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label: ',
          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: options.map((d) {
            final active = d == value;
            return GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppColors.blue2 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: active ? AppColors.blue2 : AppColors.border),
                ),
                child: Text(d == 0 ? 'في اليوم' : '$d يوم',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: active ? Colors.white : AppColors.muted,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400)),
              ),
            );
          }).toList()),
        ),
      ),
    ]);
  }
}

class _MonthDayRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _MonthDayRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('يوم التذكير: ',
          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: [1, 2, 3, 5, 7, 10, 15, 20, 25].map((d) {
            final active = d == value;
            return GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppColors.blue2 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: active ? AppColors.blue2 : AppColors.border),
                ),
                child: Text('$d',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: active ? Colors.white : AppColors.muted,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400)),
              ),
            );
          }).toList()),
        ),
      ),
    ]);
  }
}
