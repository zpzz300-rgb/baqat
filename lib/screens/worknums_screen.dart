// lib/screens/worknums_screen.dart
// مخزون أرقام العمل — مع فلاتر، تتبع آخر اتصال، وتذكيرات قبل التقفيل الجبري

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/menu_catalog.dart' show normalizeArabic;
import '../models/models.dart';
import '../widgets/common.dart';

class WorkNumsScreen extends StatefulWidget {
  const WorkNumsScreen({super.key});
  @override
  State<WorkNumsScreen> createState() => _WorkNumsScreenState();
}

/// 🔎 حقل طابق البحث — بنستخدمه نوريّ المستخدم البند ظهر ليه.
typedef WnHit = ({String label, String text});

class _WorkNumsScreenState extends State<WorkNumsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _providerFilter = 'all'; // all/etisalat/orange/vodafone/we
  String _statusFilter = 'all';   // all/available/reserved/needsRenewal/damaged
  String _urgencyFilter = 'all';  // all/needsContact/overdue
  String _sort = 'urgent';        // urgent/lastContact/alpha
  bool _compact = false;          // 📇 عرض مضغوط: سطر واحد لكل رقم

  /// 💾 بيفتكر الفلاتر وطريقة العرض — ترجع للشاشة تلاقيها زي ما سبتها.
  static const _kPrefsKey = 'wn_view_v1';

  static const _statusLabel = {
    'available': '✅ متاح',
    'reserved': '🔒 محجوز',
    'needsRenewal': '🔄 يحتاج تجديد',
    'damaged': '❌ تالف',
  };
  static const _statusColor = {
    'available': Color(0xFF2E7D32),
    'reserved': Color(0xFF1565C0),
    'needsRenewal': Color(0xFFE65100),
    'damaged': Color(0xFFC62828),
  };

  static const _providerChips = {
    'etisalat': '🟢 اتصالات',
    'orange': '🟠 أورانج',
    'vodafone': '🔴 فودافون',
    'we': '🟣 WE',
  };

  // ── 🧠 كلمات البحث الذكي: تكتبها في خانة البحث تشتغل كفلتر ──────
  // المفاتيح متطبّعة سلفاً (من غير همزات) عشان تطابق normalizeArabic.
  static const _smartProvider = {
    'اتصالات': 'etisalat', 'etisalat': 'etisalat',
    'اورانج': 'orange',    'orange': 'orange',
    // موبينيل = الاسم القديم لأورانج
    'موبينيل': 'orange',   'mobinil': 'orange', 'موبينل': 'orange',
    'فودافون': 'vodafone', 'vodafone': 'vodafone',
    'وي': 'we',            'we': 'we',
  };

  /// أسماء إضافية بيدوّر بيها البحث النصّي على الشركة.
  static const _providerAka = {'orange': 'موبينيل mobinil'};
  static const _smartStatus = {
    'متاح': 'available', 'محجوز': 'reserved',
    'تجديد': 'needsRenewal', 'تالف': 'damaged',
  };
  static const _smartUrgency = {
    'متاخر': 'overdue', 'محتاج': 'needsContact',
  };

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'ابريل', 'مايو', 'يونيو',
    'يوليو', 'اغسطس', 'سبتمبر', 'اكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || !mounted) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _providerFilter = m['provider'] ?? 'all';
        _statusFilter = m['status'] ?? 'all';
        _urgencyFilter = m['urgency'] ?? 'all';
        _sort = m['sort'] ?? 'urgent';
        _compact = m['compact'] ?? false;
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPrefsKey,
        jsonEncode({
          'provider': _providerFilter,
          'status': _statusFilter,
          'urgency': _urgencyFilter,
          'sort': _sort,
          'compact': _compact,
        }));
  }

  void _set(VoidCallback change) {
    setState(change);
    _savePrefs();
  }

  // ── 🔎 محرّك البحث ────────────────────────────────────────────
  String _n(String s) => normalizeArabic(s);

  /// تاريخ + اسم الشهر بالعربي — عشان تدوّر بـ «يوليو» زي ما تدوّر بـ «07».
  String _dateText(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '$iso ${_monthNames[d.month - 1]} ${d.year}';
  }

  /// كل الحقول اللي البحث بيدوّر فيها، مع اسم الحقل للعرض.
  List<WnHit> _searchableFields(AppProvider prov, WorkNum w) {
    final days = w.daysSinceContact;
    return [
      (label: '📱 الرقم',          text: w.phone),
      (label: '🏷 الاسم',          text: w.label),
      (label: '🔢 السيريال',       text: w.lastSerial ?? ''),
      (label: '👤 الصاحب السابق',  text: w.previousOwner ?? ''),
      (label: '📝 ملاحظات',        text: w.notes ?? ''),
      (label: '🏢 الشركة',
          text: '${MainLine.providerNames[w.provider ?? ''] ?? ''} '
              '${w.provider ?? ''} '
              '${_providerAka[w.provider ?? ''] ?? ''}'),
      (label: '📦 الباقة',         text: w.packageSystem ?? ''),
      (label: '⚡ الحالة',          text: _statusLabel[w.status] ?? ''),
      (label: '📞 آخر اتصال',
          text: '${_dateText(w.lastContactDate)}'
              '${days != null ? ' من $days يوم' : ''}'),
      (label: '🗓 ينتهي العرض',    text: _dateText(w.offerExpiryDate)),
    ];
  }

  /// بيفصل كلام البحث: الكلمات اللي هي فلاتر (اتصالات/متأخر/متاح…) بتتحوّل
  /// لفلاتر، والباقي بيفضل بحث نصّي عادي.
  ({String? provider, String? status, String? urgency, List<String> terms,
    List<({String token, String label})> smart}) _parseQuery(String q) {
    String? p, s, u;
    final terms = <String>[];
    final smart = <({String token, String label})>[];
    for (final raw in q.split(RegExp(r'\s+'))) {
      if (raw.trim().isEmpty) continue;
      final t = _n(raw);
      if (_smartProvider.containsKey(t)) {
        p = _smartProvider[t];
        smart.add((token: raw, label: _providerChips[p]! ));
      } else if (_smartStatus.containsKey(t)) {
        s = _smartStatus[t];
        smart.add((token: raw, label: _statusLabel[s]!));
      } else if (_smartUrgency.containsKey(t)) {
        u = _smartUrgency[t];
        smart.add((
          token: raw,
          label: u == 'overdue' ? '🔴 متأخر' : '⚠️ محتاج اتصال'
        ));
      } else {
        terms.add(t);
      }
    }
    return (provider: p, status: s, urgency: u, terms: terms, smart: smart);
  }

  /// بيشيل كلمة من خانة البحث (لما تدوس ✕ على شريحة ذكية).
  void _removeToken(String token) {
    final left = _search
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty && w != token)
        .join(' ');
    _searchCtrl.text = left;
    setState(() => _search = left);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final all = prov.db.workNums;

    // 🧠 الفلاتر اللي جت من البحث الذكي بتغلب اللي متظبّط بالإيد
    final q = _parseQuery(_search);
    final fProv = q.provider ?? _providerFilter;
    final fStat = q.status ?? _statusFilter;
    final fUrg  = q.urgency ?? _urgencyFilter;

    // ── الفلترة + جمع الحقول اللي طابقت لكل رقم ──
    final rows = <({WorkNum w, List<WnHit> hits})>[];
    for (final w in all) {
      if (fProv != 'all' && w.provider != fProv) continue;
      if (fStat != 'all' && w.status != fStat) continue;
      if (fUrg == 'needsContact' && !prov.worknumNeedsReminder(w)) continue;
      if (fUrg == 'overdue') {
        final r = prov.worknumDaysUntilDeactivation(w);
        if (r == null || r > 0) continue;
      }
      var hits = <WnHit>[];
      if (q.terms.isNotEmpty) {
        final fields = _searchableFields(prov, w);
        var ok = true;
        for (final t in q.terms) {
          // كل كلمة لازم تلاقي حقل (AND) — عشان «احمد 0100» تضيّق مش توسّع
          final m = fields.where((f) => _n(f.text).contains(t)).toList();
          if (m.isEmpty) {
            ok = false;
            break;
          }
          hits.addAll(m);
        }
        if (!ok) continue;
        // شيل التكرار مع الحفاظ على الترتيب
        final seen = <String>{};
        hits = hits.where((h) => seen.add(h.label)).toList();
      }
      rows.add((w: w, hits: hits));
    }

    rows.sort((a, b) {
      switch (_sort) {
        case 'lastContact':
          // الأقدم اتصالاً الأول (محتاج متابعة)
          return (b.w.daysSinceContact ?? 99999)
              .compareTo(a.w.daysSinceContact ?? 99999);
        case 'alpha':
          return a.w.phone.compareTo(b.w.phone);
        case 'urgent':
        default:
          final ra = prov.worknumDaysUntilDeactivation(a.w) ?? 9999;
          final rb = prov.worknumDaysUntilDeactivation(b.w) ?? 9999;
          return ra.compareTo(rb);
      }
    });

    // ── الإحصائيات ──
    final needsContact = all.where((w) => prov.worknumNeedsReminder(w)).length;
    final overdue = all.where((w) {
      final r = prov.worknumDaysUntilDeactivation(w);
      return r != null && r <= 0;
    }).length;
    final pending = needsContact + overdue;
    // 🏢 عدّاد كل شركة — بيبان في الهيدر عشان تعرف الخط تبع مين على طول
    final provCounts = <String, int>{};
    for (final w in all) {
      final p = w.provider ?? '';
      if (p.isNotEmpty) provCounts[p] = (provCounts[p] ?? 0) + 1;
    }
    // عدد الفلاتر الشغّالة (اللي متظبّطة بالإيد بس — الذكية ليها شرايحها)
    final activeFilters = [_providerFilter, _statusFilter, _urgencyFilter]
        .where((f) => f != 'all')
        .length;

    return Column(children: [
      // ── صف ①: البحث + الفلاتر + العرض + إضافة ──
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: '🔍 دوّر بأي حاجة…',
                hintStyle:
                    GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                suffixIcon: _search.isEmpty
                    ? IconButton(
                        icon: Icon(Icons.help_outline,
                            size: 17, color: AppColors.muted),
                        tooltip: 'البحث بيدوّر في إيه؟',
                        onPressed: _showSearchHelp,
                      )
                    : IconButton(
                        icon: const Icon(Icons.close, size: 17),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        BorderSide(color: AppColors.border, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        BorderSide(color: AppColors.border, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // ⚙️ كل الفلاتر جوه لوحة واحدة — والرقم = كام فلتر شغّال
          _iconPill(
            icon: Icons.tune,
            badge: activeFilters,
            onTap: () => _showFilterSheet(prov),
          ),
          const SizedBox(width: 6),
          // 📇 تبديل العرض المضغوط
          _iconPill(
            icon: _compact ? Icons.view_agenda_outlined : Icons.view_list,
            active: _compact,
            onTap: () => _set(() => _compact = !_compact),
          ),
          const SizedBox(width: 6),
          _iconPill(
            icon: Icons.add,
            filled: true,
            onTap: () => _showModal(context, null),
          ),
        ]),
      ),

      // ── صف ②: شريط الشركات — شكل كل شركة قدامك، دوسة = فلتر ──
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          children: [
            _provBtn(
                pkey: 'all',
                emoji: '📦',
                name: 'الكل',
                count: all.length,
                color: AppColors.blue2,
                active: fProv == 'all'),
            for (final p in _providerChips.keys)
              if ((provCounts[p] ?? 0) > 0)
                _provBtn(
                    pkey: p,
                    emoji: MainLine.providerEmojis[p] ?? '📡',
                    name: MainLine.providerNames[p] ?? p,
                    count: provCounts[p]!,
                    color: MainLine.providerColors[p] ?? AppColors.blue2,
                    active: fProv == p),
          ],
        ),
      ),

      // ── صف ③: الاستعجال + الترتيب ──
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          _statBtn('⚠️ $needsContact', const Color(0xFFE65100),
              active: _urgencyFilter == 'needsContact',
              onTap: () => _set(() => _urgencyFilter =
                  _urgencyFilter == 'needsContact' ? 'all' : 'needsContact')),
          const SizedBox(width: 5),
          _statBtn('🔴 $overdue', AppColors.red2,
              active: _urgencyFilter == 'overdue',
              onTap: () => _set(() => _urgencyFilter =
                  _urgencyFilter == 'overdue' ? 'all' : 'overdue')),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.blueMid),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sort,
                isDense: true,
                icon: Icon(Icons.sort, size: 15, color: AppColors.blue2),
                style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue2),
                items: [
                  DropdownMenuItem(
                      value: 'urgent',
                      child: Text('الأقرب تقفيل',
                          style: GoogleFonts.cairo(fontSize: 10.5))),
                  DropdownMenuItem(
                      value: 'lastContact',
                      child: Text('الأقدم اتصالاً',
                          style: GoogleFonts.cairo(fontSize: 10.5))),
                  DropdownMenuItem(
                      value: 'alpha',
                      child: Text('بالرقم',
                          style: GoogleFonts.cairo(fontSize: 10.5))),
                ],
                onChanged: (v) => _set(() => _sort = v ?? 'urgent'),
              ),
            ),
          ),
        ]),
      ),

      // ── صف ④ (لو فيه): شرايح الفلاتر الشغّالة ──
      if (q.smart.isNotEmpty || activeFilters > 0)
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            children: [
              // شرايح جاية من كلام البحث — ✕ بتشيل الكلمة من الخانة
              for (final s in q.smart)
                _activeChip(s.label, () => _removeToken(s.token)),
              if (_providerFilter != 'all')
                _activeChip(_providerChips[_providerFilter] ?? '',
                    () => _set(() => _providerFilter = 'all')),
              if (_statusFilter != 'all')
                _activeChip(_statusLabel[_statusFilter] ?? '',
                    () => _set(() => _statusFilter = 'all')),
              if (_urgencyFilter != 'all')
                _activeChip(
                    _urgencyFilter == 'overdue' ? '🔴 متأخر' : '⚠️ محتاج اتصال',
                    () => _set(() => _urgencyFilter = 'all')),
            ],
          ),
        ),

      // ── صف ⑤ (لو فيه مستحق): تسجيل اتصال جماعي ──
      if (pending > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.done_all, size: 15),
              label: Text('سجّل اتصال للكل ($pending)',
                  style: GoogleFonts.cairo(
                      fontSize: 11, fontWeight: FontWeight.w800)),
              onPressed: () => _confirmBulkContact(prov, pending),
            ),
          ),
        ),
      const SizedBox(height: 6),

      // ── القايمة ──
      Expanded(
        child: rows.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('مفيش رقم مطابق',
                      style: GoogleFonts.cairo(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  if (_search.isNotEmpty || activeFilters > 0) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        _searchCtrl.clear();
                        _set(() {
                          _search = '';
                          _providerFilter = 'all';
                          _statusFilter = 'all';
                          _urgencyFilter = 'all';
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: Text('امسح البحث والفلاتر',
                          style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                  ],
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: rows.length,
                itemBuilder: (_, i) => _compact
                    ? _compactCard(prov, rows[i].w, rows[i].hits)
                    : _card(prov, rows[i].w, rows[i].hits),
              ),
      ),
    ]);
  }

  // ── 🎯 سطر «لقاه فين»: بيبان بس لو الطابق مش الرقم نفسه ──────────
  Widget _matchLine(List<WnHit> hits) {
    final shown = hits.where((h) => h.label != '📱 الرقم').toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Text(
          'لقاه في: ${shown.map((h) => h.label).join(' · ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8D6E00))),
    );
  }

  // ── 📇 كارت مضغوط: سطر واحد لكل رقم ──────────────────────────
  Widget _compactCard(AppProvider prov, WorkNum w, List<WnHit> hits) {
    final remaining = prov.worknumDaysUntilDeactivation(w);
    final inWindow = prov.worknumNeedsReminder(w);
    final isOverdue = remaining != null && remaining <= 0;
    final statusColor = _statusColor[w.status] ?? AppColors.muted;
    final provEmoji = MainLine.providerEmojis[w.provider ?? ''] ?? '📡';
    final provColor = MainLine.providerColors[w.provider ?? ''] ?? AppColors.muted;
    final dayColor = isOverdue
        ? AppColors.red2
        : (inWindow ? const Color(0xFFE65100) : AppColors.green2);
    final edge = isOverdue
        ? AppColors.red
        : (inWindow ? const Color(0xFFE65100) : AppColors.border);

    return InkWell(
      onTap: () => _showModal(context, w),
      onLongPress: () => _callAndRecord(context, w),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: edge, width: (isOverdue || inWindow) ? 1.6 : 1),
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // 🏢 حافة ملوّنة بلون الشركة — تعرف الخط تبع مين من بعيد
            Container(width: 5, color: provColor),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(children: [
          Row(children: [
            Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(provEmoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(w.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.blue2)),
            ),
            if (w.label.isNotEmpty) ...[
              Flexible(
                child: Text(w.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 10.5, color: AppColors.muted)),
              ),
              const SizedBox(width: 6),
            ],
            // دوسة على العدّاد = سجّل اتصال (النهاردة أو بتاريخ فات)
            if (remaining != null)
              InkWell(
                onTap: () => _showRecordSheet(w),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  child: Text(isOverdue ? '🔴 ${-remaining}ي' : '⏳ $remaining ي',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: dayColor)),
                ),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(right: 6),
              icon: Icon(Icons.call, size: 17, color: AppColors.green2),
              onPressed: () => _callAndRecord(context, w),
            ),
          ]),
                  _matchLine(hits),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── ⚙️ لوحة الفلاتر: كل الفلاتر في مكان واحد ─────────────────
  void _showFilterSheet(AppProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          void pick(VoidCallback f) {
            setSheet(f);
            _set(f);
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Text('⚙️ فلاتر أرقام العمل',
                        style: GoogleFonts.cairo(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.blue2)),
                  ),
                  TextButton.icon(
                    onPressed: () => pick(() {
                      _providerFilter = 'all';
                      _statusFilter = 'all';
                      _urgencyFilter = 'all';
                    }),
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: Text('امسح',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const Divider(),
                _sheetLabel('🏢 الشركة'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _filterChip('الكل', _providerFilter == 'all',
                      () => pick(() => _providerFilter = 'all')),
                  for (final e in _providerChips.entries)
                    _filterChip(e.value, _providerFilter == e.key,
                        () => pick(() => _providerFilter = e.key)),
                ]),
                const SizedBox(height: 14),
                _sheetLabel('⚡ الحالة'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _filterChip('الكل', _statusFilter == 'all',
                      () => pick(() => _statusFilter = 'all')),
                  for (final e in _statusLabel.entries)
                    _filterChip(e.value, _statusFilter == e.key,
                        () => pick(() => _statusFilter = e.key)),
                ]),
                const SizedBox(height: 14),
                _sheetLabel('⏳ الاستعجال'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _filterChip('الكل', _urgencyFilter == 'all',
                      () => pick(() => _urgencyFilter = 'all')),
                  _filterChip('⚠️ محتاج اتصال',
                      _urgencyFilter == 'needsContact',
                      () => pick(() => _urgencyFilter = 'needsContact')),
                  _filterChip('🔴 متأخر', _urgencyFilter == 'overdue',
                      () => pick(() => _urgencyFilter = 'overdue')),
                ]),
                const Divider(height: 28),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _sharePendingList(prov);
                      },
                      icon: const Icon(Icons.share, size: 16),
                      label: Text('شارك المستحق',
                          style: GoogleFonts.cairo(
                              fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _showReminderSettings(prov);
                      },
                      icon: const Icon(Icons.notifications_active_outlined,
                          size: 16),
                      label: Text('إعدادات التذكير',
                          style: GoogleFonts.cairo(
                              fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── 📞 تسجيل اتصال يدوي: النهاردة أو بتاريخ فات ────────────────
  /// لو اتصلت من تليفون تاني أو نسيت تسجّل، تقدر تحطّ التاريخ الحقيقي
  /// عشان العدّاد التنازلي يبقى مظبوط.
  void _showRecordSheet(WorkNum w) {
    final prov = Provider.of<AppProvider>(context, listen: false);
    final today = DateTime.now();
    String fmt(DateTime d) => '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    void apply(BuildContext sheetCtx, DateTime d) {
      prov.recordWorkNumContact(w.id, at: d);
      Navigator.pop(sheetCtx);
      if (!mounted) return;
      AppSnackbar.show(
          context, '✅ اتسجّل اتصال يوم ${fmt(d)} — العدّاد بدأ من أول وجديد');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text('📞 اتصلت من الرقم ده إمتى؟',
                style: GoogleFonts.cairo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue2)),
            const SizedBox(height: 2),
            Text(w.phone,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
            if (w.lastContactDate != null)
              Text('آخر اتصال متسجّل: ${w.lastContactDate}',
                  style:
                      GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 16),

            // ✅ النهاردة — الحالة الشائعة، زرار كبير
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11))),
                icon: const Icon(Icons.today, size: 18),
                label: Text('اتصلت النهاردة',
                    style: GoogleFonts.cairo(
                        fontSize: 13.5, fontWeight: FontWeight.w900)),
                onPressed: () => apply(sheetCtx, today),
              ),
            ),
            const SizedBox(height: 10),

            // اختصارات سريعة لأيام قريبة فاتت
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
              for (final e in const [
                ('امبارح', 1),
                ('من يومين', 2),
                ('من 3 أيام', 3),
                ('من أسبوع', 7),
              ])
                _filterChip(e.$1, false,
                    () => apply(sheetCtx, today.subtract(Duration(days: e.$2)))),
            ]),
            const SizedBox(height: 12),

            // 📅 تاريخ محدد
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.blue2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11))),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text('📅 اختار التاريخ بنفسي',
                    style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.blue2)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: DateTime.tryParse(w.lastContactDate ?? '') ?? today,
                    firstDate: today.subtract(const Duration(days: 730)),
                    lastDate: today,
                    builder: (c, child) => Directionality(
                        textDirection: TextDirection.rtl, child: child!),
                  );
                  if (picked == null || !sheetCtx.mounted) return;
                  apply(sheetCtx, picked);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showSearchHelp() {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🔎 البحث بيدوّر في إيه؟',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in const [
                    '📱 الرقم — 01012 أو 1012',
                    '🏷 الاسم/اللقب',
                    '🔢 السيريال',
                    '👤 الصاحب السابق',
                    '📝 الملاحظات',
                    '🏢 الشركة — اتصالات / فودافون / موبينيل',
                    '📦 الباقة — 3800',
                    '⚡ الحالة — متاح / محجوز / تالف',
                    '📞 آخر اتصال — 2026-07 أو يوليو',
                    '🗓 انتهاء العرض',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(t,
                          style: GoogleFonts.cairo(fontSize: 12.5, height: 1.4)),
                    ),
                  const Divider(height: 20),
                  Text('🧠 كلمات بتشتغل كفلتر لوحدها:',
                      style: GoogleFonts.cairo(
                          fontSize: 12.5, fontWeight: FontWeight.w900)),
                  Text('اتصالات · أورانج (موبينيل) · فودافون · وي\n'
                      'متاح · محجوز · تجديد · تالف\n'
                      'متأخر · محتاج',
                      style: GoogleFonts.cairo(
                          fontSize: 12, height: 1.6, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Text('مثال: اكتب «اتصالات متأخر» يطلعلك أرقام اتصالات '
                      'المتأخرة بس.',
                      style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          height: 1.5,
                          color: AppColors.blue2,
                          fontWeight: FontWeight.w700)),
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('تمام', style: GoogleFonts.cairo())),
          ],
        ),
      ),
    );
  }

  // ── عناصر صغيرة للشريط الجديد ───────────────────────────────
  Widget _sheetLabel(String t) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t,
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.muted)),
        ),
      );

  Widget _iconPill({
    required IconData icon,
    required VoidCallback onTap,
    int badge = 0,
    bool active = false,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: filled
                ? AppColors.blue2
                : (active ? AppColors.blue2 : AppColors.blueLight),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.blueMid),
          ),
          child: Icon(icon,
              size: 18,
              color: (filled || active) ? Colors.white : AppColors.blue2),
        ),
        if (badge > 0)
          Positioned(
            top: -3,
            left: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.red2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5)),
              child: Text('$badge',
                  style: GoogleFonts.cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ),
      ]),
    );
  }

  /// 🏢 زرار شركة في الهيدر: شكلها + اسمها + عدد خطوطها. دوسة = فلتر عليها،
  /// ودوسة تانية = رجّع الكل.
  Widget _provBtn({
    required String pkey,
    required String emoji,
    required String name,
    required int count,
    required Color color,
    required bool active,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => _set(() => _providerFilter =
            (pkey == 'all' || _providerFilter == pkey) ? 'all' : pkey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: color.withValues(alpha: active ? 1 : 0.35),
                width: active ? 1.6 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(name,
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : color)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.28)
                    : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('$count',
                  style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: active ? Colors.white : color)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statBtn(String txt, Color color,
      {required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: active ? 1 : 0.3)),
        ),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : color)),
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.only(right: 10, left: 4),
        decoration: BoxDecoration(
          color: AppColors.blue2,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 13, color: Colors.white70),
            ),
          ),
        ]),
      );

  // ── Card ──
  Widget _card(AppProvider prov, WorkNum w, List<WnHit> hits) {
    final remaining = prov.worknumDaysUntilDeactivation(w);
    final inWindow = prov.worknumNeedsReminder(w);
    final isOverdue = remaining != null && remaining <= 0;

    final statusColor = _statusColor[w.status] ?? AppColors.muted;
    final statusTxt = _statusLabel[w.status] ?? w.status;

    final provColor = MainLine.providerColors[w.provider ?? ''] ?? AppColors.blue;
    final provEmoji = MainLine.providerEmojis[w.provider ?? ''] ?? '📡';
    final provName = MainLine.providerNames[w.provider ?? ''] ?? '';

    final borderColor = isOverdue
        ? AppColors.red
        : (inWindow ? const Color(0xFFE65100) : AppColors.border);
    final borderWidth = (isOverdue || inWindow) ? 2.0 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(color: AppColors.blue2.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(children: [
        // ── 🏢 شريط الشركة: بلون الشركة على راس الكارت ──
        Container(
          width: double.infinity,
          color: w.provider == null ? AppColors.muted : provColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(children: [
            Text(provEmoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(w.provider == null ? 'شركة غير محددة' : provName,
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const Spacer(),
            if (w.packageSystem != null && w.packageSystem!.isNotEmpty)
              Text('📦 ${w.packageSystem}',
                  style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70)),
          ]),
        ),

        // ── Urgency banner ──
        if (isOverdue)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.red.withValues(alpha: 0.08),
            child: Text('🔴 متأخر! اتجاوز ${-remaining} يوم بعد التقفيل المتوقع',
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.red2)),
          )
        else if (inWindow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFFFFF3E0),
            child: Text('⚠️ اتصل قبل ما يتقفل خلال $remaining يوم',
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
          ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 🎯 لقاه فين — بيبان بس وانت بتدوّر والطابق مش الرقم نفسه
            _matchLine(hits),
            // Row: phone + badges
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: w.phone));
                    AppSnackbar.show(context, '✅ تم نسخ الرقم ${w.phone}');
                  },
                  child: Row(children: [
                    Flexible(
                      child: Text(w.phone,
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w900,
                              color: AppColors.blue2,
                              fontSize: 17)),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 13, color: AppColors.muted),
                  ]),
                ),
              ),
              _badge(statusTxt, statusColor.withValues(alpha: 0.12), statusColor),
            ]),
            // الاسم — الشركة والباقة بقوا فوق في شريط الراس
            if (w.label.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: _smallChip(w.label, AppColors.blueLight, AppColors.blue2),
              ),
            ],
            const SizedBox(height: 8),

            // ── عدّاد كبير: باقي كام يوم قبل التقفيل ──
            if (remaining != null) _countdownBar(remaining, isOverdue, inWindow),

            const SizedBox(height: 8),
            // Last contact + days + serial
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (w.lastContactDate != null) ...[
                    Text('📞 آخر اتصال: ${w.lastContactDate}',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.text)),
                    if (w.daysSinceContact != null)
                      Text('من ${w.daysSinceContact} يوم',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: isOverdue
                                  ? AppColors.red
                                  : (inWindow ? const Color(0xFFE65100) : AppColors.muted))),
                  ] else
                    Text('📞 لم يُسجَّل اتصال بعد',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  if (w.offerExpiryDate != null)
                    Text('🗓 ينتهي: ${w.offerExpiryDate}',
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                  if (w.previousOwner != null && w.previousOwner!.isNotEmpty)
                    Text('👤 سابقاً: ${w.previousOwner}',
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
                ]),
              ),
            ]),

            // ── السيريال في صندوق واضح مع زرار نسخ ──
            if (w.lastSerial != null && w.lastSerial!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _serialBox(context, w.lastSerial!),
            ],
            if (w.notes != null && w.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📝 ${w.notes}',
                  style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green2,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.call, size: 16),
                  label: Text('اتصل وسجّل',
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () => _callAndRecord(context, w),
                ),
              ),
              const SizedBox(width: 6),
              // تسجيل اتصال بدون مكالمة (لو اتصلت من تليفون تاني) —
              // النهاردة أو بتاريخ انت تختاره
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.green2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () => _showRecordSheet(w),
                child: Text('✔ سجّل',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green2)),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: AppColors.blue, size: 22),
                onPressed: () => _showModal(context, w),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.red, size: 22),
                onPressed: () => Provider.of<AppProvider>(context, listen: false).deleteWorkNum(w.id),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── عدّاد كبير: باقي كام يوم قبل التقفيل الجبري ──
  Widget _countdownBar(int remaining, bool isOverdue, bool inWindow) {
    final Color c;
    final String big;
    final String sub;
    if (isOverdue) {
      c = AppColors.red2;
      big = '${-remaining}';
      sub = 'يوم بعد موعد التقفيل! اتصل فوراً 🚨';
    } else if (inWindow) {
      c = const Color(0xFFE65100);
      big = '$remaining';
      sub = 'يوم باقي قبل التقفيل ⚠️';
    } else {
      c = AppColors.green2;
      big = '$remaining';
      sub = 'يوم باقي — لسه في أمان ✅';
    }
    // نسبة شريط التقدّم (افتراض 90 يوم كحد)
    final pct = ((remaining.clamp(0, 90)) / 90).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(big,
              style: GoogleFonts.cairo(
                  fontSize: 26, fontWeight: FontWeight.w900, color: c)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(sub,
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w700, color: c)),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: isOverdue ? 1.0 : (1 - pct),
            minHeight: 6,
            backgroundColor: c.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(c),
          ),
        ),
      ]),
    );
  }

  // ── صندوق السيريال مع زرار نسخ ──
  Widget _serialBox(BuildContext context, String serial) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCE93D8)),
      ),
      child: Row(children: [
        const Text('🔢', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text('سيريال:',
            style: GoogleFonts.cairo(
                fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF6A1B9A))),
        const SizedBox(width: 6),
        Expanded(
          child: SelectableText(serial,
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4A148C),
                  letterSpacing: 0.5)),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: serial));
            AppSnackbar.show(context, '✅ تم نسخ السيريال');
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.copy, size: 15, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  // ── Reusable widgets ──
  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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

  Widget _badge(String txt, Color bg, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _smallChip(String txt, Color bg, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(txt,
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );

  // ── اتصال مباشر + تسجيل الاتصال في نفس الوقت ──
  Future<void> _callAndRecord(BuildContext context, WorkNum w) async {
    final prov = context.read<AppProvider>();
    prov.recordWorkNumContact(w.id);
    final uri = Uri.parse('tel:${w.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      AppSnackbar.show(context, '✅ اتسجّل الاتصال (الاتصال مش متاح من الجهاز)');
    }
  }

  // ── تسجيل اتصال جماعي لكل المحتاج/المتأخر ──
  void _confirmBulkContact(AppProvider prov, int count) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('✅ تسجيل اتصال جماعي',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Text(
              'هيتسجّل اتصال النهارده لـ $count رقم (المحتاج اتصال + المتأخر). '
              'استخدمها بعد ما تتصل بيهم فعلاً. تمام؟',
              style: GoogleFonts.cairo(height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green2),
              onPressed: () {
                final n = prov.recordAllPendingWorkNumContacts();
                Navigator.pop(context);
                AppSnackbar.show(context, '✅ تم تسجيل اتصال لـ $n رقم');
              },
              child: Text('سجّل الكل',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── مشاركة قائمة المحتاج اتصال (نص للمراجعة/واتساب) ──
  void _sharePendingList(AppProvider prov) {
    final pending = prov.db.workNums.where((w) {
      final r = prov.worknumDaysUntilDeactivation(w);
      return prov.worknumNeedsReminder(w) || (r != null && r <= 0);
    }).toList()
      ..sort((a, b) => (prov.worknumDaysUntilDeactivation(a) ?? 9999)
          .compareTo(prov.worknumDaysUntilDeactivation(b) ?? 9999));
    if (pending.isEmpty) {
      AppSnackbar.show(context, 'مفيش أرقام محتاجة اتصال 👍');
      return;
    }
    final sb = StringBuffer('📋 أرقام عمل محتاجة اتصال (${pending.length}):\n');
    for (final w in pending) {
      final r = prov.worknumDaysUntilDeactivation(w);
      final tag = (r != null && r <= 0)
          ? '🔴 متأخر ${-r} يوم'
          : '⚠️ باقي ${r ?? '?'} يوم';
      sb.writeln('• ${w.phone}${w.label.isNotEmpty ? ' (${w.label})' : ''} — $tag');
    }
    Share.share(sb.toString());
  }

  // ── Reminder settings dialog ──
  void _showReminderSettings(AppProvider prov) {
    final deactCtrl = TextEditingController(text: '${prov.worknumDeactivationDays}');
    final reminCtrl = TextEditingController(text: '${prov.worknumReminderDays}');
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('⚙️ إعدادات التذكير',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.blueLight, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'الشركات بتقفل الخط جبري لو معدلش اتصالاً لمدة معينة. '
                'البرنامج هيذكّرك يومياً قبل الموعد ده.',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.blue2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deactCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'أيام التقفيل الجبري (افتراضي 90)',
                labelStyle: GoogleFonts.cairo(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reminCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'أيام التذكير قبل التقفيل (افتراضي 15)',
                labelStyle: GoogleFonts.cairo(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () {
                final d = int.tryParse(deactCtrl.text.trim()) ?? prov.worknumDeactivationDays;
                final r = int.tryParse(reminCtrl.text.trim()) ?? prov.worknumReminderDays;
                if (d > 0) prov.setWorknumDeactivationDays(d);
                if (r > 0) prov.setWorknumReminderDays(r);
                Navigator.pop(context);
                AppSnackbar.show(context, '✅ تم حفظ الإعدادات');
              },
              child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add/Edit modal ──
  void _showModal(BuildContext context, WorkNum? wn) {
    final phoneCtrl = TextEditingController(text: wn?.phone ?? '');
    final labelCtrl = TextEditingController(text: wn?.label ?? '');
    final notesCtrl = TextEditingController(text: wn?.notes ?? '');
    final serialCtrl = TextEditingController(text: wn?.lastSerial ?? '');
    final systemCtrl = TextEditingController(text: wn?.packageSystem ?? '');
    final ownerCtrl = TextEditingController(text: wn?.previousOwner ?? '');
    final overrideCtrl = TextEditingController(
        text: wn?.reminderDaysOverride != null ? '${wn!.reminderDaysOverride}' : '');
    String? provider = wn?.provider;
    String status = wn?.status ?? 'available';
    String? lastContact = wn?.lastContactDate;
    String? offerExpiry = wn?.offerExpiryDate;

    Future<String?> pickDate(String? init) async {
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(init ?? '') ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (d == null) return init;
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => ModalShell(
          title: wn == null ? '📋 إضافة رقم عمل' : '✏️ تعديل رقم عمل',
          actions: [
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () {
                if (phoneCtrl.text.trim().isEmpty) return;
                final prov = context.read<AppProvider>();
                final m = WorkNum(
                  id: wn?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  phone: phoneCtrl.text.trim(),
                  label: labelCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  provider: provider,
                  packageSystem: systemCtrl.text.trim().isEmpty ? null : systemCtrl.text.trim(),
                  lastContactDate: lastContact,
                  lastSerial: serialCtrl.text.trim().isEmpty ? null : serialCtrl.text.trim(),
                  status: status,
                  offerExpiryDate: offerExpiry,
                  previousOwner: ownerCtrl.text.trim().isEmpty ? null : ownerCtrl.text.trim(),
                  reminderDaysOverride: int.tryParse(overrideCtrl.text.trim()),
                );
                if (wn == null) {
                  prov.addWorkNum(m);
                } else {
                  prov.editWorkNum(m);
                }
                Navigator.pop(ctx);
              },
              child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
          children: [
            AppFormField(
                label: 'رقم الموبايل',
                controller: phoneCtrl,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            AppFormField(label: 'الاسم / التصنيف', controller: labelCtrl),
            const SizedBox(height: 10),

            // Provider dropdown
            DropdownButtonFormField<String?>(
              initialValue: provider,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'نوع الشركة',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— لم يحدّد —', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'etisalat',
                    child: Text('🟢 اتصالات', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'orange',
                    child: Text('🟠 أورانج', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'vodafone',
                    child: Text('🔴 فودافون', style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem<String?>(
                    value: 'we',
                    child: Text('🟣 WE', style: GoogleFonts.cairo(fontSize: 13))),
              ],
              onChanged: (v) => setS(() => provider = v),
            ),
            const SizedBox(height: 10),

            // System dropdown (مع خيار "أخرى" للكتابة اليدوية)
            DropdownButtonFormField<String>(
              initialValue: const ['3800', '4000', '1800', '1000', 'يدوي']
                      .contains(systemCtrl.text.trim())
                  ? systemCtrl.text.trim()
                  : (systemCtrl.text.trim().isEmpty ? null : 'أخرى'),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'الباقة / النظام',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                for (final s in ['3800', '4000', '1800', '1000', 'يدوي'])
                  DropdownMenuItem(
                      value: s, child: Text(s, style: GoogleFonts.cairo(fontSize: 13))),
                DropdownMenuItem(
                    value: 'أخرى',
                    child: Text('أخرى (اكتب يدوي)', style: GoogleFonts.cairo(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v == 'أخرى') {
                  setS(() => systemCtrl.text = '');
                } else {
                  setS(() => systemCtrl.text = v ?? '');
                }
              },
            ),
            const SizedBox(height: 8),
            // حقل يدوي يظهر دايماً لو عايز تعدّل النظام بحرية
            AppFormField(
                label: 'أو اكتب النظام يدوياً',
                controller: systemCtrl,
                textDirection: TextDirection.ltr),
            const SizedBox(height: 10),

            // Status
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'حالة الرقم',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                for (final s in _statusLabel.entries)
                  DropdownMenuItem(
                      value: s.key, child: Text(s.value, style: GoogleFonts.cairo(fontSize: 13))),
              ],
              onChanged: (v) => setS(() => status = v ?? 'available'),
            ),
            const SizedBox(height: 10),

            // Last contact date
            InkWell(
              onTap: () async {
                final d = await pickDate(lastContact);
                setS(() => lastContact = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '📞 آخر اتصال',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(children: [
                  Expanded(
                      child: Text(lastContact ?? 'اختر تاريخ',
                          style: GoogleFonts.cairo(fontSize: 13,
                              color: lastContact == null ? AppColors.muted : AppColors.text))),
                  if (lastContact != null)
                    GestureDetector(
                      onTap: () => setS(() => lastContact = null),
                      child: Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            AppFormField(label: '🔢 آخر سيريال', controller: serialCtrl, textDirection: TextDirection.ltr),
            const SizedBox(height: 10),

            // Offer expiry
            InkWell(
              onTap: () async {
                final d = await pickDate(offerExpiry);
                setS(() => offerExpiry = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '🗓 تاريخ انتهاء العرض/الخط',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(children: [
                  Expanded(
                      child: Text(offerExpiry ?? 'اختياري',
                          style: GoogleFonts.cairo(fontSize: 13,
                              color: offerExpiry == null ? AppColors.muted : AppColors.text))),
                  if (offerExpiry != null)
                    GestureDetector(
                      onTap: () => setS(() => offerExpiry = null),
                      child: Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            AppFormField(label: '👤 صاحبه السابق (اختياري)', controller: ownerCtrl),
            const SizedBox(height: 10),

            AppFormField(
                label: 'أيام التذكير لهذا الرقم (اختياري — يتجاوز الافتراضي)',
                controller: overrideCtrl,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),

            AppFormField(label: 'ملاحظات (اختياري)', controller: notesCtrl),
          ],
        ),
      ),
    );
  }
}
