// lib/screens/gifts_screen.dart
// 🎁 لوحة الهدايا — جدول صف واحد لكل خط رئيسي.
// المخزن فوق فيه هديتين ثابتتين (كل الخطوط بتاخد نفس الهدايا).
// قدام كل خط: علامة صح لهدية ١، علامة صح لهدية ٢، وعلامة «تم البيع»
// اللي بتضيف الكاش لربح المجموعة أوتوماتيك (group.giftProfit).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelStyle:
                GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
            labelColor: AppColors.blue2,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.blue2,
            tabs: const [
              Tab(text: '🎁 توزيع الهدايا'),
              Tab(text: '📋 سجل الهدايا'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildDashboardTab(),
              _buildLogTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB 1: DASHBOARD ───────────────────────────────────────────
  Widget _buildDashboardTab() {
    return Consumer<AppProvider>(builder: (ctx, p, _) {
      final g1 = p.globalGift(0);
      final g2 = p.globalGift(1);

      final groups = p.db.groups.where((g) {
        if (_filterText.isEmpty) return true;
        return g.phone.contains(_filterText) ||
            (g.ownerName?.contains(_filterText) ?? false);
      }).toList();

      // إحصائيات
      final soldCount = p.db.groups.where((g) => p.giftSold(g.id)).length;
      final totalProfit =
          p.db.groups.fold<double>(0, (s, g) => s + g.giftProfit);

      return Column(
        children: [
          _buildStore(p, g1, g2),
          // عدّاد + بحث
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(children: [
              Row(children: [
                _chip('👥 خطوط: ${p.db.groups.length}', AppColors.purple),
                const SizedBox(width: 6),
                _chip('✅ تم بيعها: $soldCount', AppColors.green2),
                const SizedBox(width: 6),
                _chip('💰 الأرباح: ${totalProfit.toStringAsFixed(0)}ج',
                    AppColors.green),
              ]),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => _filterText = v),
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'بحث بالرقم أو اسم المالك...',
                  hintStyle:
                      GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: AppColors.muted),
                  filled: true,
                  fillColor: const Color(0xFFf5f7fa),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ]),
          ),
          // رأس الجدول
          _tableHeader(g1, g2),
          const Divider(height: 1),
          Expanded(
            child: (g1 == null && g2 == null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '⬆️ عرّف هدايا المخزن من فوق الأول\nعشان تقدر تعلّم عليها قدام الخطوط',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(color: AppColors.muted),
                      ),
                    ),
                  )
                : groups.isEmpty
                    ? Center(
                        child: Text('لا توجد مجموعات',
                            style: GoogleFonts.cairo(color: AppColors.muted)))
                    : ListView.separated(
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _groupRow(p, groups[i], g1, g2),
                      ),
          ),
        ],
      );
    });
  }

  // ── المخزن (هديتين) ────────────────────────────────────────────
  Widget _buildStore(
      AppProvider p, Map<String, dynamic>? g1, Map<String, dynamic>? g2) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFe8f4fd),
        border: Border(bottom: BorderSide(color: AppColors.blueMid)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🏪', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text('مخزن الهدايا',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue2,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _storeSlot(p, 0, g1)),
            const SizedBox(width: 8),
            Expanded(child: _storeSlot(p, 1, g2)),
          ]),
        ],
      ),
    );
  }

  Widget _storeSlot(AppProvider p, int slot, Map<String, dynamic>? gift) {
    final defined = gift != null;
    return InkWell(
      onTap: () => _editStoreSlot(p, slot, gift),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: defined ? AppColors.green.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(children: [
          Text('🎁 هدية ${slot + 1}',
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.muted)),
          const SizedBox(width: 6),
          Expanded(
            child: defined
                ? Text(
                    '${gift['name']} • ${(gift['price'] as num).toStringAsFixed(0)}ج',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue2),
                  )
                : Text('اضغط للتعريف',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.muted)),
          ),
          const Icon(Icons.edit, size: 14, color: AppColors.muted),
        ]),
      ),
    );
  }

  void _editStoreSlot(
      AppProvider p, int slot, Map<String, dynamic>? gift) {
    final nameCtrl =
        TextEditingController(text: gift?['name'] as String? ?? '');
    final priceCtrl = TextEditingController(
        text: gift != null ? (gift['price'] as num).toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('🎁 هدية ${slot + 1}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
                labelText: 'اسم الهدية', labelStyle: GoogleFonts.cairo()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
                labelText: 'السعر (ج)', labelStyle: GoogleFonts.cairo()),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
              if (name.isEmpty || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('⚠️ اكتب اسم وسعر الهدية',
                        style: GoogleFonts.cairo())));
                return;
              }
              p.setGlobalGift(slot, name, price);
              Navigator.pop(context);
            },
            child: Text('حفظ',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── رأس الجدول ─────────────────────────────────────────────────
  Widget _tableHeader(Map<String, dynamic>? g1, Map<String, dynamic>? g2) {
    return Container(
      color: const Color(0xFFf5f7fa),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(flex: 4, child: _headCell('🔢 الخط الرئيسي')),
        Expanded(
            flex: 3,
            child: _headCell('🎁 ${g1?['name'] ?? 'هدية ١'}',
                center: true)),
        Expanded(
            flex: 3,
            child: _headCell('🎁 ${g2?['name'] ?? 'هدية ٢'}',
                center: true)),
        Expanded(flex: 3, child: _headCell('💰 تم البيع', center: true)),
      ]),
    );
  }

  Widget _headCell(String t, {bool center = false}) => Text(t,
      textAlign: center ? TextAlign.center : TextAlign.start,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.cairo(
          fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.muted));

  // ── صف خط ──────────────────────────────────────────────────────
  Widget _groupRow(AppProvider p, Group g, Map<String, dynamic>? g1,
      Map<String, dynamic>? g2) {
    final r1 = p.giftReceived(g.id, 0);
    final r2 = p.giftReceived(g.id, 1);
    final sold = p.giftSold(g.id);
    final anyReceived = r1 || r2;

    return Container(
      color: sold ? AppColors.greenLight : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        // الخط الرئيسي
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.phone,
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppColors.text)),
              if ((g.ownerName ?? '').isNotEmpty)
                Text(g.ownerName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 10, color: AppColors.muted)),
              if (g.giftProfit > 0)
                Text('ربح: ${g.giftProfit.toStringAsFixed(0)}ج',
                    style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green)),
            ],
          ),
        ),
        // هدية ١
        Expanded(
          flex: 3,
          child: _checkCell(
            checked: r1,
            enabled: g1 != null,
            color: AppColors.green2,
            onTap: () => p.toggleGiftReceived(g.id, 0),
          ),
        ),
        // هدية ٢
        Expanded(
          flex: 3,
          child: _checkCell(
            checked: r2,
            enabled: g2 != null,
            color: AppColors.green2,
            onTap: () => p.toggleGiftReceived(g.id, 1),
          ),
        ),
        // تم البيع
        Expanded(
          flex: 3,
          child: _checkCell(
            checked: sold,
            enabled: anyReceived,
            color: AppColors.orange,
            label: sold ? 'تم ✅' : null,
            onTap: () {
              if (!anyReceived) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('⚠️ علّم هدية الأول قبل تأكيد البيع',
                        style: GoogleFonts.cairo())));
                return;
              }
              p.toggleGiftSold(g.id);
            },
          ),
        ),
      ]),
    );
  }

  Widget _checkCell({
    required bool checked,
    required bool enabled,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return Center(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: label != null ? null : 34,
          height: 34,
          padding: label != null
              ? const EdgeInsets.symmetric(horizontal: 8)
              : EdgeInsets.zero,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: checked
                ? color
                : (enabled ? Colors.white : const Color(0xFFf0f0f0)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: checked
                    ? color
                    : (enabled ? AppColors.border : const Color(0xFFe0e0e0)),
                width: 1.5),
          ),
          child: label != null
              ? Text(label,
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white))
              : Icon(
                  checked ? Icons.check : null,
                  size: 20,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, color: color, fontSize: 11)),
      );

  // ── TAB 2: LOG (كما هو) ────────────────────────────────────────
  Widget _buildLogTab() {
    return Consumer<AppProvider>(builder: (ctx, p, _) {
      final log = p.db.giftLog;

      if (log.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📋', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('لا يوجد سجل بعد',
                  style:
                      GoogleFonts.cairo(color: AppColors.muted, fontSize: 14)),
            ],
          ),
        );
      }

      final Map<String, List<Map<String, dynamic>>> byMonth = {};
      for (final entry in log) {
        final month = entry['month'] as String? ?? 'غير معروف';
        byMonth.putIfAbsent(month, () => []).add(entry);
      }
      final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: months.length,
        itemBuilder: (ctx, i) {
          final month = months[i];
          final entries = byMonth[month]!;
          final totalGifts =
              entries.fold(0, (s, e) => s + (e['gifts'] as List).length);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFe8f4fd), Color(0xFFdbeeff)]),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: AppColors.blueMid)),
                ),
                child: Row(children: [
                  Text('📅 $month',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue2,
                          fontSize: 14)),
                  const Spacer(),
                  Text('$totalGifts هدية • ${entries.length} مجموعة',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.blue2,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              ...entries.map((e) {
                final gifts =
                    (e['gifts'] as List).cast<Map<String, dynamic>>();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['phone'] as String? ?? '',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.blue2),
                          textDirection: TextDirection.ltr),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: gifts
                              .map((g) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.greenLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                        '${g['name']} • ${g['price']}ج',
                                        style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: AppColors.green,
                                            fontWeight: FontWeight.w700)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
            ]),
          );
        },
      );
    });
  }
}
