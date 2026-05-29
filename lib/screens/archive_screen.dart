// lib/screens/archive_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String _tab = 'members';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.blue2.withValues(alpha: 0.08), blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📦 أرشيف المحذوفات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.blue2, fontSize: 14)),
                  Text('كل العملاء والإيجارات المحذوفة محفوظة هنا', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _tabBtn('members', '👤 عملاء محذوفون'),
                      _tabBtn('rentals', '🏠 إيجارات محذوفة'),
                      _tabBtn('gifts', '🎁 سجل الهدايا'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_tab == 'members') _buildDeletedMembers(prov),
            if (_tab == 'rentals') _buildDeletedRentals(prov),
            if (_tab == 'gifts') _buildGiftsLog(prov),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String val, String label) {
    final active = _tab == val;
    return GestureDetector(
      onTap: () => setState(() => _tab = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? AppColors.headerGradient : null,
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: active ? null : Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(label, style: GoogleFonts.cairo(color: active ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  Widget _buildDeletedMembers(AppProvider prov) {
    if (prov.db.deleted.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('لا يوجد عملاء محذوفون', style: GoogleFonts.cairo(color: AppColors.muted)),
      );
    }
    return Column(
      children: prov.db.deleted.map((m) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFbbdefb)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('${m.phone} · ${m.package}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                  Text('رصيد: ${m.balance.toStringAsFixed(0)} ج', style: GoogleFonts.cairo(fontSize: 11, color: m.balance < 0 ? AppColors.red2 : AppColors.green, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => prov.restoreMember(m.id),
              child: Text('استعادة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildDeletedRentals(AppProvider prov) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text('لا توجد إيجارات محذوفة', style: GoogleFonts.cairo(color: AppColors.muted)),
    );
  }

  Widget _buildGiftsLog(AppProvider prov) {
    final allGifts = prov.db.groups.expand((g) => g.gifts.map((gift) => {...gift, 'groupPhone': g.phone})).toList();
    if (allGifts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('لا يوجد سجل هدايا', style: GoogleFonts.cairo(color: AppColors.muted)),
      );
    }
    return Column(
      children: allGifts.map((gift) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${gift['memberName']}', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${gift['date']}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      )).toList(),
    );
  }
}
