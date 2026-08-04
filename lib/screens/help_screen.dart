// lib/screens/help_screen.dart
// 📖 دليل الاستخدام — شرح كل حاجة في البرنامج، بالبحث وبزرار يفتحلك
// الشاشة اللي بتقرا عنها على طول.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/app_search.dart';
import '../services/help_content.dart';
import '../services/menu_catalog.dart';
import '../services/view_prefs.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/workspace_bar.dart' show kWorkspaceScreens;

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  /// المواضيع المفتوحة (بيتفتكروا)
  final Set<String> _open = {};
  final _viewPrefs = ViewPrefs('help');

  @override
  void initState() {
    super.initState();
    _viewPrefs.load().then((m) {
      if (!mounted || m.isEmpty) return;
      setState(() => _open
        ..clear()
        ..addAll(List<String>.from(m['open'] ?? const [])));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (!_open.remove(id)) _open.add(id);
    });
    _viewPrefs.save({'open': _open.toList()});
  }

  @override
  Widget build(BuildContext context) {
    final terms = searchTerms(_search);
    final searching = terms.isNotEmpty;

    final topics = searching
        ? kHelpTopics
            .where((t) => searchHitsOf(terms, helpHaystack(t)) != null)
            .toList()
        : kHelpTopics;

    // اتجمّع حسب القسم مع الحفاظ على الترتيب
    final bySection = <String, List<HelpTopic>>{};
    for (final t in topics) {
      bySection.putIfAbsent(t.section, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.blue2,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('📖 دليل الاستخدام',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900, color: Colors.white)),
      ),
      body: Column(children: [
        AppSearchBar(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          hint: '🔍 دوّر على أي حاجة… مثلاً: سيريال، ليلي، كفيل',
        ),
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('${topics.length} نتيجة',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted)),
            ),
          ),
        Expanded(
          child: topics.isEmpty
              ? AppEmptyResult(
                  message: 'مالقيتش حاجة بالكلام ده',
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                  children: [
                    if (!searching) _intro(),
                    for (final e in bySection.entries) ...[
                      _sectionTitle(e.key),
                      for (final t in e.value) _card(t, forceOpen: searching),
                    ],
                    const SizedBox(height: 12),
                    _footer(),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _intro() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blueMid),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('👋 أهلاً بيك',
              style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue2)),
          const SizedBox(height: 6),
          Text(
              'دوس على أي عنوان تحت عشان يفتحلك الشرح بتاعه. '
              'ولو مستعجل، اكتب اللي بتدوّر عليه في خانة البحث فوق.',
              style: GoogleFonts.cairo(
                  fontSize: 12, height: 1.6, color: AppColors.text)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.touch_app, size: 15, color: AppColors.blue2),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                  'الشرح اللي فيه زرار «افتحها دلوقتي» بيوديك للشاشة على طول.',
                  style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue3)),
            ),
          ]),
        ]),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Text(t,
            style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.blue2)),
      );

  Widget _card(HelpTopic t, {required bool forceOpen}) {
    final open = forceOpen || _open.contains(t.id);
    final canOpen = t.screen != null &&
        (t.screen == 'groups' || kWorkspaceScreens.containsKey(t.screen));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => _toggle(t.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Text(t.emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title,
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text(t.summary,
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: AppColors.muted, height: 1.4)),
                    ]),
              ),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  size: 22, color: AppColors.blue2),
            ]),
          ),
        ),
        if (open)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.steps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _label('👣 بتعملها إزاي'),
                    for (var i = 0; i < t.steps.length; i++)
                      _numbered(i + 1, t.steps[i]),
                  ],
                  if (t.tips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _label('💡 حاجات تفيدك'),
                    for (final tip in t.tips) _bullet(tip),
                  ],
                  if (canOpen) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue2,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text('افتحها دلوقتي',
                            style: GoogleFonts.cairo(
                                fontSize: 12, fontWeight: FontWeight.w900)),
                        onPressed: () => _openScreen(t.screen!),
                      ),
                    ),
                  ],
                ]),
          ),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.muted)),
      );

  Widget _numbered(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.blueMid)),
            child: Text('$n',
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.cairo(
                    fontSize: 12, height: 1.6, color: AppColors.text)),
          ),
        ]),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                  color: AppColors.orange, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: GoogleFonts.cairo(
                    fontSize: 11.5, height: 1.65, color: AppColors.text)),
          ),
        ]),
      );

  Widget _footer() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.green2.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Text('🛡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('بياناتك في أمان',
                      style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.green2)),
                  const SizedBox(height: 3),
                  Text(
                      'أي حاجة بتمسحها بتروح 🗑 المحذوفون وتقدر ترجّعها. '
                      'والبيانات بتتحفظ على النت تلقائي طول ما فيه إنترنت.',
                      style: GoogleFonts.cairo(
                          fontSize: 11, height: 1.6, color: AppColors.text)),
                ]),
          ),
        ]),
      );

  /// بيفتح الشاشة اللي الشرح بيتكلم عنها.
  void _openScreen(String key) {
    final prov = Provider.of<AppProvider>(context, listen: false);
    if (key == 'groups') {
      // المجموعات هي الشاشة الرئيسية نفسها — نقفل الدليل ونرجعله
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    final d = menuItemDef(key);
    prov.openWorkspaceTab(key,
        title: d?.title ?? key, emoji: d?.emoji ?? '📄');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
