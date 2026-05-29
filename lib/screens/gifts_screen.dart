// lib/screens/gifts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../utils/phone_utils.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _warehouseExpanded = true;
  String _filterText = '';
  final _nameCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
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
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
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
              _buildDistributionTab(),
              _buildLogTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB 1: DISTRIBUTION ────────────────────────────────────────
  Widget _buildDistributionTab() {
    return Consumer<AppProvider>(builder: (ctx, p, _) {
      final groups = p.db.groups.where((g) {
        if (_filterText.isEmpty) return true;
        return g.phone.contains(_filterText) ||
            (g.ownerName?.contains(_filterText) ?? false);
      }).toList();

      return Column(
        children: [
          _buildWarehouseHeader(p),
          _buildStatsAndFilter(p),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Text('لا توجد مجموعات',
                        style: GoogleFonts.cairo(color: AppColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
                    itemCount: groups.length,
                    itemBuilder: (ctx, i) => _GroupCard(
                      key: ValueKey(groups[i].id),
                      group: groups[i],
                      giftTypes: p.db.giftTypes,
                      onAssign: (gid, gt) => p.assignGiftToGroup(gid, gt),
                      onRemove: (gid, idx, profit) =>
                          p.removeGiftFromGroup(gid, idx, addProfit: profit),
                      onUpdate: (gid, idx, gt) =>
                          p.updateGiftInGroup(gid, idx, gt),
                      onArchive: (gid) => p.archiveAndClearGroupGifts(gid),
                    ),
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildWarehouseHeader(AppProvider p) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFe8f4fd),
        border: Border(bottom: BorderSide(color: AppColors.blueMid)),
      ),
      child: Column(
        children: [
          // Toggle bar
          InkWell(
            onTap: () => setState(() => _warehouseExpanded = !_warehouseExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  const Text('🏪', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Text(
                    'مخزن الهدايا (${p.db.giftTypes.length})',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900,
                        color: AppColors.blue2,
                        fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(
                    _warehouseExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.blue2,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_warehouseExpanded) ...[
            // Add form
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameCtrl,
                    style: GoogleFonts.cairo(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'اسم الهدية (مثلاً: كنساس)',
                      hintStyle: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.muted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [PhoneInputFormatter()],
                    style: GoogleFonts.cairo(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'السعر ج',
                      hintStyle: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.muted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () => _addGiftType(p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue2,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('إضافة',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ]),
            ),

            // Gift type chips
            if (p.db.giftTypes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: p.db.giftTypes.map((gt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.blueMid),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🎁', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(gt['name'] as String,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.blue2)),
                        const SizedBox(width: 4),
                        Text('${gt['price']}ج',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.green,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _confirmDeleteGiftType(
                              p, gt['id'] as String, gt['name'] as String),
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.muted),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  'لا توجد هدايا في المخزن بعد — أضف من الأعلى',
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: AppColors.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsAndFilter(AppProvider p) {
    final totalGifts =
        p.db.groups.fold(0, (s, g) => s + g.gifts.length);
    final totalProfit =
        p.db.groups.fold(0.0, (s, g) => s + g.giftProfit);
    final totalGroups = p.db.groups.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(children: [
        TextField(
          onChanged: (v) => setState(() => _filterText = v),
          style: GoogleFonts.cairo(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'بحث بالرقم أو اسم المالك...',
            hintStyle:
                GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
            prefixIcon:
                const Icon(Icons.search, size: 18, color: AppColors.muted),
            filled: true,
            fillColor: const Color(0xFFf5f7fa),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _chip('🎁 موزّع: $totalGifts', AppColors.blue2),
          const SizedBox(width: 6),
          _chip('👥 مجموعات: $totalGroups', AppColors.purple),
          const SizedBox(width: 6),
          _chip('💰 أرباح: ${totalProfit.toStringAsFixed(0)}ج',
              AppColors.green),
        ]),
      ]),
    );
  }

  // ── TAB 2: LOG ────────────────────────────────────────────────
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
                  style: GoogleFonts.cairo(
                      color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 6),
              Text('اضغط "🗂️ أرشفة" في أي مجموعة لحفظ الهدايا هنا',
                  style: GoogleFonts.cairo(
                      color: AppColors.muted, fontSize: 12)),
            ],
          ),
        );
      }

      // Group by month descending
      final Map<String, List<Map<String, dynamic>>> byMonth = {};
      for (final entry in log) {
        final month = entry['month'] as String? ?? 'غير معروف';
        byMonth.putIfAbsent(month, () => []).add(entry);
      }
      final months = byMonth.keys.toList()
        ..sort((a, b) => b.compareTo(a));

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
              boxShadow: [
                BoxShadow(
                    color: AppColors.blue2.withValues(alpha: 0.06),
                    blurRadius: 10)
              ],
            ),
            child: Column(children: [
              // Month header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFe8f4fd), Color(0xFFdbeeff)]),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                  border:
                      Border(bottom: BorderSide(color: AppColors.blueMid)),
                ),
                child: Row(children: [
                  Text('📅 $month',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue2,
                          fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        '$totalGifts هدية  •  ${entries.length} مجموعة',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.blue2,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              // Entries
              ...entries.map((e) {
                final gifts = (e['gifts'] as List).cast<Map<String, dynamic>>();
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
                                      borderRadius:
                                          BorderRadius.circular(8),
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

  // ── HELPERS ───────────────────────────────────────────────────
  void _addGiftType(AppProvider p) {
    final name  = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ أدخل اسم وسعر الهدية',
              style: GoogleFonts.cairo())));
      return;
    }
    p.addGiftType({
      'id': 'gt_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'price': price,
    });
    _nameCtrl.clear();
    _priceCtrl.clear();
  }

  void _confirmDeleteGiftType(AppProvider p, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الهدية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('هل تريد حذف "$name" من المخزن؟',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(context);
              p.deleteGiftType(id);
            },
            child: Text('حذف',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 11)),
      );
}

// ── GROUP CARD ──────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Group group;
  final List<Map<String, dynamic>> giftTypes;
  final void Function(String gid, Map<String, dynamic> gt) onAssign;
  final void Function(String gid, int idx, bool profit) onRemove;
  final void Function(String gid, int idx, Map<String, dynamic> gt) onUpdate;
  final void Function(String gid) onArchive;

  const _GroupCard({
    super.key,
    required this.group,
    required this.giftTypes,
    required this.onAssign,
    required this.onRemove,
    required this.onUpdate,
    required this.onArchive,
  });

  void _editProfit(BuildContext context) {
    final ctrl = TextEditingController(
        text: group.giftProfit > 0 ? group.giftProfit.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✏️ تعديل ربح الهدايا',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'الربح (ج)',
            labelStyle: GoogleFonts.cairo(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green2, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(context);
              context.read<AppProvider>().setGroupGiftProfit(group.id, val);
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.07), blurRadius: 12)],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFe8f4fd), Color(0xFFdbeeff)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: AppColors.blueMid, width: 1.5)),
          ),
          child: Row(children: [
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.phone,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 14),
                    textDirection: TextDirection.ltr,
                    overflow: TextOverflow.ellipsis),
                if (group.ownerName != null)
                  Text(group.ownerName!,
                      style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Spacer(),
            // Profit badge — always visible + edit button
            GestureDetector(
              onTap: () => _editProfit(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: group.giftProfit > 0 ? AppColors.greenLight : const Color(0xFFf5f5f5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: group.giftProfit > 0
                          ? AppColors.green.withValues(alpha: 0.4)
                          : AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    group.giftProfit > 0
                        ? '💰 ربح: ${group.giftProfit.toStringAsFixed(0)}ج'
                        : '💰 ربح: 0ج',
                    style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: group.giftProfit > 0 ? AppColors.green : AppColors.muted),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 11,
                      color: group.giftProfit > 0 ? AppColors.green : AppColors.muted),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            if (group.gifts.isNotEmpty)
              GestureDetector(
                onTap: () => onArchive(group.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfff8e1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFffcc80)),
                  ),
                  child: Text('🗂️ أرشفة',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.orange)),
                ),
              ),
          ]),
        ),

        // 2 gift slots — VERTICAL
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            _GiftSlot(
              slotIndex: 0, group: group, giftTypes: giftTypes,
              onAssign: onAssign, onRemove: onRemove, onUpdate: onUpdate,
            ),
            const SizedBox(height: 8),
            _GiftSlot(
              slotIndex: 1, group: group, giftTypes: giftTypes,
              onAssign: onAssign, onRemove: onRemove, onUpdate: onUpdate,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── GIFT SLOT ──────────────────────────────────────────────────
class _GiftSlot extends StatefulWidget {
  final int slotIndex;
  final Group group;
  final List<Map<String, dynamic>> giftTypes;
  final void Function(String gid, Map<String, dynamic> gt) onAssign;
  final void Function(String gid, int idx, bool profit) onRemove;
  final void Function(String gid, int idx, Map<String, dynamic> gt) onUpdate;

  const _GiftSlot({
    required this.slotIndex,
    required this.group,
    required this.giftTypes,
    required this.onAssign,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_GiftSlot> createState() => _GiftSlotState();
}

class _GiftSlotState extends State<_GiftSlot> {
  bool _editing = false;

  static const _stepLabels = {
    'branch': 'من الفرع',
    'renter': 'من المستأجر',
    'used':   'تم الاستخدام',
  };
  static const _stepIcons = {
    'branch': '🏪',
    'renter': '🏠',
    'used':   '📱',
  };
  static const _stepColors = {
    'branch': Color(0xFF1565C0),
    'renter': Color(0xFF6A1B9A),
    'used':   Color(0xFF2E7D32),
  };

  String _stepLabel(String? step) {
    if (step == null || !_stepLabels.containsKey(step)) return 'لم تُسجل بعد';
    return _stepLabels[step]!;
  }

  @override
  void didUpdateWidget(_GiftSlot old) {
    super.didUpdateWidget(old);
    if (_editing && widget.slotIndex >= widget.group.gifts.length) {
      _editing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gifts    = widget.group.gifts;
    final assigned = widget.slotIndex < gifts.length ? gifts[widget.slotIndex] : null;
    final label    = 'هدية ${widget.slotIndex + 1}';
    final step     = assigned?['step'] as String?;

    final otherIdx    = widget.slotIndex == 0 ? 1 : 0;
    final otherTypeId = otherIdx < gifts.length ? gifts[otherIdx]['giftTypeId'] : null;
    final available   = widget.giftTypes.where((gt) => gt['id'] != otherTypeId).toList();

    // ── Header row ──────────────────────────────────────────────
    final headerBg = assigned == null
        ? const Color(0xFFf5f5f5)
        : step == 'used'
            ? const Color(0xFFE8F5E9)
            : step == 'renter'
                ? const Color(0xFFF3E5F5)
                : const Color(0xFFE3F2FD);
    final headerBorder = assigned == null
        ? AppColors.border
        : (step == 'used'
            ? const Color(0xFFA5D6A7)
            : step == 'renter'
                ? const Color(0xFFCE93D8)
                : AppColors.blueMid);

    return Container(
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerBorder, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Row(children: [
            Text('🎁 $label',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 13,
                    color: assigned == null ? AppColors.muted : AppColors.blue2)),
            const SizedBox(width: 6),
            if (assigned != null) ...[
              Expanded(
                child: Text(assigned['name'] as String? ?? '',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blue2),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${assigned['price']}ج',
                  style: GoogleFonts.cairo(
                      fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.green)),
            ] else
              Expanded(
                child: Text('لم تُسجل بعد',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
              ),
            if (assigned != null) ...[
              const SizedBox(width: 6),
              // تغيير نوع الهدية
              GestureDetector(
                onTap: () => setState(() => _editing = !_editing),
                child: const Icon(Icons.swap_horiz, size: 16, color: AppColors.muted),
              ),
              const SizedBox(width: 4),
              // حذف
              GestureDetector(
                onTap: () => widget.onRemove(widget.group.id, widget.slotIndex, false),
                child: const Icon(Icons.close, size: 16, color: AppColors.muted),
              ),
            ],
          ]),
        ),

        // ── Step badge ──────────────────────────────────────────
        if (assigned != null && step != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_stepColors[step] ?? AppColors.muted).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_stepIcons[step] ?? "📌"} ${_stepLabel(step)}',
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _stepColors[step] ?? AppColors.muted),
              ),
            ),
          ),

        // ── Assign dropdown (when no gift or editing) ────────────
        if (assigned == null || _editing) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: available.isEmpty
                ? Text('لا توجد هدايا في المخزن',
                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted))
                : DropdownButtonFormField<String>(
                    initialValue: null,
                    decoration: InputDecoration(
                      hintText: 'اختر هدية...',
                      hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    ),
                    isExpanded: true,
                    items: available.map((gt) => DropdownMenuItem<String>(
                      value: gt['id'] as String,
                      child: Row(children: [
                        Flexible(child: Text(gt['name'] as String,
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        Text('${gt['price']}ج',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.green)),
                      ]),
                    )).toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final gt = widget.giftTypes.firstWhere((x) => x['id'] == id);
                      if (assigned != null && _editing) {
                        widget.onUpdate(widget.group.id, widget.slotIndex, gt);
                      } else {
                        widget.onAssign(widget.group.id, gt);
                      }
                      setState(() => _editing = false);
                    },
                  ),
          ),
        ],

        // ── 3 step buttons ────────────────────────────────────────
        if (assigned != null && !_editing)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(children: [
              _stepBtn(context, 'branch', step, '🏪 من الفرع'),
              const SizedBox(width: 6),
              _stepBtn(context, 'renter', step, '🏠 من المستأجر'),
              const SizedBox(width: 6),
              _stepBtn(context, 'used', step, '📱 تم الاستخدام'),
            ]),
          ),
      ]),
    );
  }

  Widget _stepBtn(BuildContext ctx, String thisStep, String? currentStep, String label) {
    final active = currentStep == thisStep;
    final color  = _stepColors[thisStep] ?? AppColors.muted;
    return Expanded(
      child: GestureDetector(
        onTap: () => ctx.read<AppProvider>()
            .updateGiftStep(widget.group.id, widget.slotIndex, thisStep),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color : AppColors.border, width: active ? 1.5 : 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.muted),
          ),
        ),
      ),
    );
  }
}
