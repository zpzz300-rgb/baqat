// lib/screens/neumorphic_demo_screen.dart
// معاينة تصميم Neumorphism (ستايل ناعم بالظلال) + قائمة جانبية
// شاشة عرض مستقلة لا تؤثر على باقي التطبيق.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';

// ── ألوان النيومورفيزم ───────────────────────────────────────────
class _Neu {
  static const bg = Color(0xFFE0E5EC);        // الخلفية الأساسية
  static const light = Color(0xFFFFFFFF);      // ظل فاتح (أعلى يسار)
  static const dark = Color(0xFFA3B1C6);       // ظل غامق (أسفل يمين)
  static const text = Color(0xFF4A5568);       // النص الأساسي
  static const muted = Color(0xFF8A97A8);      // نص ثانوي
  static const accent = Color(0xFF1565C0);     // لون مميز (أزرق الهوية)
  static const green = Color(0xFF2E7D32);
  static const red = Color(0xFFC62828);

  /// ظلال عنصر بارز (مرفوع)
  static List<BoxShadow> raised({double blur = 10, double dist = 5}) => [
        BoxShadow(color: dark, offset: Offset(dist, dist), blurRadius: blur),
        BoxShadow(color: light, offset: Offset(-dist, -dist), blurRadius: blur),
      ];
}

// ── حاوية نيومورفيزم بارزة ───────────────────────────────────────
class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _Neu.bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _Neu.raised(),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, child: box);
  }
}

// ── زر دائري نيومورفيزم ──────────────────────────────────────────
class NeuIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  const NeuIconButton(
      {super.key, required this.icon, required this.onTap, this.color, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _Neu.bg,
          shape: BoxShape.circle,
          boxShadow: _Neu.raised(blur: 8, dist: 4),
        ),
        child: Icon(icon, color: color ?? _Neu.text, size: size * 0.45),
      ),
    );
  }
}

class NeumorphicDemoScreen extends StatelessWidget {
  const NeumorphicDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final db = prov.db;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _Neu.bg,
        drawer: const _NeuDrawer(),
        body: SafeArea(
          child: Builder(
            builder: (ctx) => ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                // ── Top bar ──
                Row(children: [
                  NeuIconButton(
                      icon: Icons.menu,
                      onTap: () => Scaffold.of(ctx).openDrawer()),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('باقات الاتصالات',
                        style: GoogleFonts.cairo(
                            fontSize: 17, fontWeight: FontWeight.w900, color: _Neu.text)),
                    Text('لوحة التحكم',
                        style: GoogleFonts.cairo(fontSize: 11, color: _Neu.muted)),
                  ]),
                  const SizedBox(width: 12),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _Neu.bg,
                      shape: BoxShape.circle,
                      boxShadow: _Neu.raised(blur: 8, dist: 4),
                    ),
                    child: const Icon(Icons.person, color: _Neu.accent, size: 24),
                  ),
                ]),
                const SizedBox(height: 22),

                // ── Search (inset look) ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: _Neu.bg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: _Neu.dark, offset: Offset(2, 2), blurRadius: 5),
                      BoxShadow(color: _Neu.light, offset: Offset(-2, -2), blurRadius: 5),
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.search, color: _Neu.muted, size: 20),
                    const SizedBox(width: 10),
                    Text('ابحث عن عميل أو خط...',
                        style: GoogleFonts.cairo(fontSize: 13, color: _Neu.muted)),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── Stats grid ──
                Row(children: [
                  Expanded(child: _statCard('💰 الأرباح',
                      '${db.totalProfit.toStringAsFixed(0)} ج', _Neu.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('👥 العملاء',
                      '${db.members.length}', _Neu.accent)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _statCard('🏘️ المجموعات',
                      '${db.groups.length}', const Color(0xFF6A1B9A))),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('📋 الديون',
                      '${db.totalDebt.toStringAsFixed(0)} ج', _Neu.red)),
                ]),
                const SizedBox(height: 22),

                // ── Net profit hero card ──
                NeuCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    Text('صافي الربح',
                        style: GoogleFonts.cairo(fontSize: 14, color: _Neu.muted)),
                    const SizedBox(height: 8),
                    Text('${(db.financialSummary['netProfit'] ?? 0).toStringAsFixed(0)} ج',
                        style: GoogleFonts.cairo(
                            fontSize: 32, fontWeight: FontWeight.w900, color: _Neu.accent)),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── Quick actions ──
                Text('إجراءات سريعة',
                    style: GoogleFonts.cairo(
                        fontSize: 14, fontWeight: FontWeight.w800, color: _Neu.text)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _action(Icons.person_add, 'عميل'),
                  _action(Icons.add_business, 'مجموعة'),
                  _action(Icons.receipt_long, 'فاتورة'),
                  _action(Icons.chat, 'واتساب'),
                ]),
                const SizedBox(height: 24),

                // ── Pay button (big) ──
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _Neu.bg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _Neu.raised(),
                    ),
                    child: Center(
                      child: Text('📊 عرض التقرير الشامل',
                          style: GoogleFonts.cairo(
                              fontSize: 15, fontWeight: FontWeight.w800, color: _Neu.accent)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color accent) {
    return NeuCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 12, color: _Neu.muted)),
        const SizedBox(height: 10),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
                fontSize: 20, fontWeight: FontWeight.w900, color: accent)),
      ]),
    );
  }

  Widget _action(IconData icon, String label) {
    return Column(children: [
      NeuIconButton(icon: icon, onTap: () {}, color: _Neu.accent, size: 56),
      const SizedBox(height: 8),
      Text(label, style: GoogleFonts.cairo(fontSize: 11, color: _Neu.text)),
    ]);
  }
}

// ── القائمة الجانبية (Drawer) ────────────────────────────────────
class _NeuDrawer extends StatelessWidget {
  const _NeuDrawer();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'الرئيسية'),
      (Icons.groups_rounded, 'المجموعات والعملاء'),
      (Icons.receipt_long_rounded, 'فواتير الشركات'),
      (Icons.bar_chart_rounded, 'التقارير والأرباح'),
      (Icons.hourglass_bottom_rounded, 'قائمة الانتظار'),
      (Icons.card_giftcard_rounded, 'الهدايا والنقاط'),
      (Icons.settings_rounded, 'الإعدادات'),
    ];
    return Drawer(
      backgroundColor: _Neu.bg,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 24),
          // Logo / header
          Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _Neu.bg,
                shape: BoxShape.circle,
                boxShadow: _Neu.raised(blur: 12, dist: 6),
              ),
              child: const Icon(Icons.satellite_alt, color: _Neu.accent, size: 38),
            ),
          ),
          const SizedBox(height: 14),
          Text('باقات الاتصالات',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 16, fontWeight: FontWeight.w900, color: _Neu.text)),
          Text('Pro Ledger',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 11, color: _Neu.muted)),
          const SizedBox(height: 26),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _Neu.bg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _Neu.raised(blur: 7, dist: 3.5),
                  ),
                  child: Row(children: [
                    Icon(items[i].$1, color: _Neu.accent, size: 22),
                    const SizedBox(width: 14),
                    Text(items[i].$2,
                        style: GoogleFonts.cairo(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _Neu.text)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ]),
      ),
    );
  }
}
