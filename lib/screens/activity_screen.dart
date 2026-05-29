// lib/screens/activity_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'all';

  final _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'add', 'label': '➕ إضافة'},
    {'key': 'edit', 'label': '✏️ تعديل'},
    {'key': 'pay', 'label': '💰 دفع'},
    {'key': 'delete', 'label': '🗑 حذف'},
    {'key': 'bill', 'label': '📅 اشتراك'},
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final log = _filter == 'all'
        ? prov.db.activityLog
        : prov.db.activityLog.where((e) => e['type'] == _filter).toList();

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
                    Text('📋 سجل النشاط الكامل', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15)),
                    Text('كل حركة في البرنامج مسجلة هنا', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('مسح السجل', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
                      content: Text('هل تريد مسح كل سجل النشاط؟', style: GoogleFonts.cairo()),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                          onPressed: () { prov.clearActivityLog(); Navigator.pop(context); },
                          child: Text('مسح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFef9a9a)),
                  ),
                  child: Text('🗑 مسح السجل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.red2, fontSize: 12)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.headerGradient : null,
                      color: active ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: active ? null : Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Text(f['label']!, style: GoogleFonts.cairo(color: active ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Log list
        Expanded(
          child: log.isEmpty
              ? Center(child: Text('لا يوجد نشاط', style: GoogleFonts.cairo(color: AppColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: log.length,
                  itemBuilder: (_, i) {
                    final entry = log[i];
                    final type = entry['type'] ?? '';
                    Color dotColor;
                    switch (type) {
                      case 'add': dotColor = AppColors.green; break;
                      case 'pay': dotColor = AppColors.blue; break;
                      case 'delete': dotColor = AppColors.red; break;
                      case 'bill': dotColor = AppColors.orange; break;
                      default: dotColor = AppColors.muted;
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry['desc'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                                if (entry['member'] != null)
                                  Text(entry['member'], style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Text(entry['date'] ?? '', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
