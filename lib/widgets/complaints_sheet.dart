// lib/widgets/complaints_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';

class ComplaintsSheet extends StatefulWidget {
  final Group group;
  const ComplaintsSheet({super.key, required this.group});

  @override
  State<ComplaintsSheet> createState() => _ComplaintsSheetState();
}

class _ComplaintsSheetState extends State<ComplaintsSheet> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final bool _recorderReady = true;
  final bool _playerReady = true;
  bool _isRecording = false;
  String? _playingId;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── RECORDING ────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) _snack('❌ تحتاج إذن الميكروفون');
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/complaint_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: _recordingPath!);
    setState(() => _isRecording = true);
  }

  Future<String?> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
    return _recordingPath;
  }

  // ── PLAYBACK ─────────────────────────────────────────────────
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

  void _snack(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo())));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final group = prov.db.groups.firstWhere(
      (g) => g.id == widget.group.id,
      orElse: () => widget.group,
    );
    final complaints = List<Map<String, dynamic>>.from(group.complaints)
      ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📝 شكاوى الخط',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        group.phone,
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${complaints.length} شكوى',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: complaints.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد شكاوى بعد',
                          style: GoogleFonts.cairo(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: complaints.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _complaintCard(complaints[i], prov, group),
                  ),
          ),
          // Add button
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddDialog(prov, group),
                icon: const Icon(Icons.add),
                label: Text(
                  'إضافة شكوى جديدة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> c, AppProvider prov, Group group) {
    final id = c['id'] as String? ?? '';
    final titleCtrl = TextEditingController(text: c['title'] as String? ?? '');
    final textCtrl = TextEditingController(text: c['text'] as String? ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✏️ تعديل الشكوى', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('العنوان', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            TextField(
              controller: titleCtrl,
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            if (c['type'] != 'voice' && c['type'] != 'photo') ...[
              const SizedBox(height: 10),
              Text('التفاصيل', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (c['resolved'] != true)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () {
                    Navigator.pop(context);
                    prov.resolveComplaint(group.id, id);
                    _snack('✅ تم تحديد الشكوى كمحلولة');
                  },
                  child: Text('✅ تحديد كمحلولة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue2, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              final updated = Map<String, dynamic>.from(c)
                ..['title'] = titleCtrl.text.trim()
                ..['text'] = textCtrl.text.trim();
              prov.updateComplaint(group.id, id, updated);
              _snack('✅ تم تحديث الشكوى');
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _complaintCard(Map<String, dynamic> c, AppProvider prov, Group group) {
    final type = c['type'] as String? ?? 'text';
    final isVoice = type == 'voice';
    final isPhoto = type == 'photo';
    final id = c['id'] as String? ?? '';
    final audio = c['audioPath'] as String?;
    final imagePath = c['imagePath'] as String?;
    final isPlaying = _playingId == id;

    Color cardBg = Colors.white;
    Color cardBorder = AppColors.border;
    if (isVoice) {
      cardBg = AppColors.blueLight;
      cardBorder = AppColors.blueMid;
    }
    if (isPhoto) {
      cardBg = const Color(0xFFF3E5F5);
      cardBorder = const Color(0xFFCE93D8);
    }

    return GestureDetector(
      onTap: () => _showEditDialog(c, prov, group),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isVoice
                      ? AppColors.blue2
                      : isPhoto
                      ? const Color(0xFF7B1FA2)
                      : AppColors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isVoice
                      ? '🎙 صوتية'
                      : isPhoto
                      ? '📷 صورة'
                      : '📝 نصية',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                c['date'] ?? '',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(width: 8),
              if (c['resolved'] != true)
                GestureDetector(
                  onTap: () { prov.resolveComplaint(group.id, id); _snack('✅ تم حل الشكوى'); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(6)),
                    child: Text('حُلّت', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green2)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(6)),
                  child: Text('✅ محلولة', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green2)),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _deleteComplaint(prov, group, id),
                child: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
              ),
            ],
          ),
          if ((c['title'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              c['title'] as String,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          if (type == 'text' && (c['text'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              c['text'] as String,
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.text),
            ),
          ],
          if (isVoice && audio != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _playerReady ? () => _togglePlay(id, audio) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isPlaying ? AppColors.blue2 : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.blue2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.stop : Icons.play_arrow,
                      color: isPlaying ? Colors.white : AppColors.blue2,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPlaying ? 'إيقاف' : 'تشغيل التسجيل',
                      style: GoogleFonts.cairo(
                        color: isPlaying ? Colors.white : AppColors.blue2,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (isPhoto && imagePath != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Builder(
                builder: (_) {
                  try {
                    return Image.file(
                      File(imagePath),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  } catch (_) {
                    return Container(
                      height: 60,
                      color: AppColors.border,
                      child: Center(
                        child: Text(
                          '⚠️ تعذر تحميل الصورة',
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    ),  // GestureDetector
    );
  }

  void _deleteComplaint(AppProvider prov, Group group, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف الشكوى',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        content: Text('هل تريد حذف هذه الشكوى؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(context);
              prov.deleteComplaint(group.id, id);
            },
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── ADD DIALOG ───────────────────────────────────────────────
  void _showAddDialog(AppProvider prov, Group group) {
    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddComplaintSheet(
        group: group,
        prov: prov,
        recorderReady: _recorderReady,
        isRecording: _isRecording,
        onStartRecording: _startRecording,
        onStopRecording: _stopRecording,
        onRecordingStateChanged: (v) => setState(() => _isRecording = v),
      ),
    );
  }
}

// ── ADD COMPLAINT SHEET ──────────────────────────────────────────
class _AddComplaintSheet extends StatefulWidget {
  final Group group;
  final AppProvider prov;
  final bool recorderReady;
  final bool isRecording;
  final Future<void> Function() onStartRecording;
  final Future<String?> Function() onStopRecording;
  final void Function(bool) onRecordingStateChanged;

  const _AddComplaintSheet({
    required this.group,
    required this.prov,
    required this.recorderReady,
    required this.isRecording,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onRecordingStateChanged,
  });

  @override
  State<_AddComplaintSheet> createState() => _AddComplaintSheetState();
}

class _AddComplaintSheetState extends State<_AddComplaintSheet> {
  String _type = 'text';
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  String? _audioPath;
  String? _imagePath;
  bool _isRec = false;
  final _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '📝 شكوى جديدة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.blue2,
                ),
              ),
              const SizedBox(height: 14),

              // Type selector
              Row(
                children: [
                  Expanded(child: _typeBtn('text', '📝 نصية')),
                  const SizedBox(width: 8),
                  Expanded(child: _typeBtn('voice', '🎙 صوتية')),
                  const SizedBox(width: 8),
                  Expanded(child: _typeBtn('photo', '📷 صور')),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'العنوان (اختياري)',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _titleCtrl,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'وصف مختصر للشكوى',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (_type == 'text') ...[
                Text(
                  'نص الشكوى',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: _textCtrl,
                  maxLines: 4,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'اكتب تفاصيل الشكوى...',
                    hintStyle: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else if (_type == 'voice') ...[
                // Voice options
                Text(
                  'التسجيل الصوتي',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                // Record button
                GestureDetector(
                  onTap: () async {
                    if (_isRec) {
                      final path = await widget.onStopRecording();
                      setState(() {
                        _isRec = false;
                        _audioPath = path;
                      });
                      widget.onRecordingStateChanged(false);
                    } else {
                      await widget.onStartRecording();
                      setState(() {
                        _isRec = true;
                        _audioPath = null;
                      });
                      widget.onRecordingStateChanged(true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isRec
                          ? const Color(0xFFffebee)
                          : AppColors.blueLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isRec ? AppColors.red : AppColors.blueMid,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRec ? Icons.stop_circle : Icons.mic,
                          color: _isRec ? AppColors.red : AppColors.blue2,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRec ? '⏹ إيقاف التسجيل' : '🎙 بدء التسجيل',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _isRec ? AppColors.red : AppColors.blue2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_audioPath != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'تم التسجيل بنجاح ✅',
                        style: GoogleFonts.cairo(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Upload audio file
                GestureDetector(
                  onTap: _pickAudioFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFCE93D8),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.upload_file,
                          color: Color(0xFF7B1FA2),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '📁 رفع ملف صوتي',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF7B1FA2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_type == 'photo') ...[
                // ── Photo options ──────────────────────────────
                Text(
                  'الصورة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickImage(ImageSource.camera),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.blueMid,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.camera_alt,
                                color: AppColors.blue2,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '📷 كاميرا',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.blue2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFCE93D8),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.photo_library,
                                color: Color(0xFF7B1FA2),
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🖼 المعرض',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: const Color(0xFF7B1FA2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_imagePath != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_imagePath!),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'تم اختيار الصورة ✅',
                        style: GoogleFonts.cairo(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _imagePath = null),
                        child: Text(
                          'حذف',
                          style: GoogleFonts.cairo(
                            color: AppColors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('إلغاء', style: GoogleFonts.cairo()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue2,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'حفظ الشكوى',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSave {
    if (_isRec) return false;
    if (_type == 'text') {
      return _textCtrl.text.trim().isNotEmpty ||
          _titleCtrl.text.trim().isNotEmpty;
    }
    if (_type == 'voice') return _audioPath != null;
    if (_type == 'photo') return _imagePath != null;
    return false;
  }

  Widget _typeBtn(String val, String label) {
    final active = _type == val;
    return GestureDetector(
      onTap: () => setState(() => _type = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? AppColors.headerGradient : null,
          color: active ? null : const Color(0xFFf0f4f8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.blue2 : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _imagePath = picked.path);
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null) return;
    final f = result.files.single;
    final ext = (f.name.split('.').last).toLowerCase();
    if (!['mp3', 'aac', 'wav', 'm4a', 'ogg', 'opus', 'flac'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ اختر ملف صوتي (mp3, aac, wav, m4a...)',
              style: GoogleFonts.cairo(),
            ),
          ),
        );
      }
      return;
    }
    setState(() => _audioPath = f.path ?? f.name);
  }

  void _save() {
    if (!_canSave) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final complaint = <String, dynamic>{
      'id': id,
      'date': DateTime.now().toString().substring(0, 10),
      'type': _type,
      'title': _titleCtrl.text.trim(),
      if (_type == 'text') 'text': _textCtrl.text.trim(),
      if (_type == 'voice' && _audioPath != null) 'audioPath': _audioPath,
      if (_type == 'photo' && _imagePath != null) 'imagePath': _imagePath,
    };
    widget.prov.addComplaint(widget.group.id, complaint);
    Navigator.pop(context);
  }
}
