// lib/screens/complaints_screen.dart
// 📣 قسم الشكاوى الموحّد — يجمع كل الشكاوى من كل الخطوط في مكان واحد
// مع فلاتر بالحالة: الكل / لسه / شغّالة / تمت.
// أي شكوى تتضاف على أي خط من الهيدر بتاعه تظهر هنا تلقائياً.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  String _filter = 'all'; // all / pending / inProgress / resolved
  String _search = '';
  final _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String id, String path) async {
    if (_playingId == id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      setState(() => _playingId = id);
    }
  }

  static const _statusInfo = {
    'pending': {'label': '🔴 لسه', 'color': AppColors.red2},
    'inProgress': {'label': '🟡 شغّالة', 'color': AppColors.orange},
    'resolved': {'label': '🟢 تمت', 'color': AppColors.green2},
  };

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    var complaints = prov.allComplaints();

    // فلتر الحالة
    if (_filter != 'all') {
      complaints = complaints.where((c) => c['_status'] == _filter).toList();
    }
    // بحث
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      complaints = complaints.where((c) {
        return (c['_groupPhone'] ?? '').toString().contains(_search) ||
            (c['_groupOwner'] ?? '').toString().toLowerCase().contains(q) ||
            (c['title'] ?? '').toString().toLowerCase().contains(q) ||
            (c['text'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }

    // إحصائيات
    final all = prov.allComplaints();
    final pending = all.where((c) => c['_status'] == 'pending').length;
    final inProgress = all.where((c) => c['_status'] == 'inProgress').length;
    final resolved = all.where((c) => c['_status'] == 'resolved').length;

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Row(children: [
          const Text('📣', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('كل الشكاوى',
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              Text('من كل الخطوط في مكان واحد',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Text('${all.length}',
              style: GoogleFonts.cairo(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
        ]),
      ),
      // عدّادات + بحث + فلاتر
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: GoogleFonts.cairo(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'بحث بالخط أو الاسم أو نص الشكوى...',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
              filled: true,
              fillColor: const Color(0xFFf5f7fa),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('الكل (${all.length})', _filter == 'all',
                  () => setState(() => _filter = 'all')),
              _filterChip('🔴 لسه ($pending)', _filter == 'pending',
                  () => setState(() => _filter = 'pending')),
              _filterChip('🟡 شغّالة ($inProgress)', _filter == 'inProgress',
                  () => setState(() => _filter = 'inProgress')),
              _filterChip('🟢 تمت ($resolved)', _filter == 'resolved',
                  () => setState(() => _filter = 'resolved')),
            ]),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: complaints.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('📭', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 8),
                  Text(
                      _filter == 'all'
                          ? 'لا توجد شكاوى على أي خط'
                          : 'لا توجد شكاوى بهذه الحالة',
                      style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: complaints.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _complaintCard(prov, complaints[i]),
              ),
      ),
    ]);
  }

  Widget _complaintCard(AppProvider prov, Map<String, dynamic> c) {
    final type = (c['type'] ?? 'text').toString();
    final status = (c['_status'] ?? 'pending').toString();
    final gid = (c['_gid'] ?? '').toString();
    final id = (c['id'] ?? '').toString();
    final info = _statusInfo[status]!;
    final statusColor = info['color'] as Color;
    final audio = c['audioPath'] as String?;
    final imagePath = c['imagePath'] as String?;
    final isPlaying = _playingId == id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // شريط علوي: الخط + الحالة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            const Icon(Icons.router, size: 15, color: AppColors.blue2),
            const SizedBox(width: 5),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['_groupPhone'] ?? '',
                    textDirection: TextDirection.ltr,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.blue2)),
                if ((c['_groupOwner'] ?? '').toString().isNotEmpty)
                  Text(c['_groupOwner'],
                      style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
              ]),
            ),
            Text(c['date'] ?? '',
                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.muted)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: type == 'voice'
                      ? AppColors.blue2
                      : type == 'photo'
                          ? const Color(0xFF7B1FA2)
                          : AppColors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    type == 'voice' ? '🎙 صوتية' : type == 'photo' ? '📷 صورة' : '📝 نصية',
                    style: GoogleFonts.cairo(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => prov.deleteComplaint(gid, id),
                child: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
              ),
            ]),
            if ((c['title'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(c['title'],
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
            if (type == 'text' && (c['text'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(c['text'],
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.text)),
            ],
            if (type == 'voice' && audio != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _togglePlay(id, audio),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isPlaying ? AppColors.blue2 : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.blue2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                        color: isPlaying ? Colors.white : AppColors.blue2, size: 18),
                    const SizedBox(width: 6),
                    Text(isPlaying ? 'إيقاف' : 'تشغيل التسجيل',
                        style: GoogleFonts.cairo(
                            color: isPlaying ? Colors.white : AppColors.blue2,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ]),
                ),
              ),
            ],
            if (type == 'photo' && imagePath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Builder(builder: (_) {
                  try {
                    return Image.file(File(imagePath),
                        height: 140, width: double.infinity, fit: BoxFit.cover);
                  } catch (_) {
                    return Container(
                      height: 50,
                      color: AppColors.border,
                      child: Center(
                          child: Text('⚠️ تعذر تحميل الصورة',
                              style: GoogleFonts.cairo(fontSize: 12))),
                    );
                  }
                }),
              ),
            ],
            const SizedBox(height: 10),
            // أزرار تغيير الحالة
            Row(children: [
              _statusBtn(prov, gid, id, 'pending', '🔴 لسه', status),
              const SizedBox(width: 6),
              _statusBtn(prov, gid, id, 'inProgress', '🟡 شغّالة', status),
              const SizedBox(width: 6),
              _statusBtn(prov, gid, id, 'resolved', '🟢 تمت', status),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _statusBtn(AppProvider prov, String gid, String id, String value,
      String label, String current) {
    final active = current == value;
    final color = (_statusInfo[value]!['color'] as Color);
    return Expanded(
      child: GestureDetector(
        onTap: () => prov.setComplaintStatus(gid, id, value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color : AppColors.border),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.muted)),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
}
