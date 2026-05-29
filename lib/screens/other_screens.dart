// lib/screens/deleted_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class DeletedScreen extends StatelessWidget {
  const DeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final deleted = prov.db.deleted;

    if (deleted.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🗑', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('لا يوجد عملاء محذوفون', style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: deleted.length,
      itemBuilder: (_, i) {
        final m = deleted[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                    Text(
                      'رصيد: ${m.balance.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: m.balance < 0 ? AppColors.red2 : AppColors.green),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => prov.restoreMember(m.id),
                    child: Text('↩️ استعادة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('حذف نهائي', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
                          content: Text('حذف ${m.name} نهائياً؟ لا يمكن التراجع.', style: GoogleFonts.cairo()),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red2),
                              onPressed: () {
                                prov.db.deleted.removeWhere((x) => x.id == m.id);
                                prov.save();
                                Navigator.pop(context);
                              },
                              child: Text('حذف نهائي', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text('🗑 حذف نهائي', style: GoogleFonts.cairo(color: AppColors.red2, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────

// lib/screens/reminders_screen.dart
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final debtors = prov.db.members.where((m) => m.balance < 0).toList()
      ..sort((a, b) => a.balance.compareTo(b.balance)); // worst debt first

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Text('🔔 التذكيرات والمتأخرات', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15)),
        ),
        if (debtors.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('لا يوجد متأخرات!', style: GoogleFonts.cairo(color: AppColors.green, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('كل العملاء مسددون 👍', style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: debtors.length,
              itemBuilder: (_, i) {
                final m = debtors[i];
                final debt = -m.balance;
                final g = prov.db.groups.firstWhere((x) => x.id == m.gid, orElse: () => Group(id: '', phone: '—'));

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.06), blurRadius: 12)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
                            Text('${m.phone} · مجموعة: ${g.phone}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _sendWA(m.phone, m.name, debt),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.waGreen, borderRadius: BorderRadius.circular(20)),
                                child: Text('💬 تذكير واتساب', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          '${debt.toStringAsFixed(0)} ج',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.red2, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _sendWA(String phone, String name, double debt) async {
    final p = phone.replaceFirst(RegExp(r'^0'), '20');
    final msg = Uri.encodeComponent('السلام عليكم $name 👋\nإجمالي مديونيتك: ${debt.toStringAsFixed(0)} ج\nيرجى السداد 🙏');
    final url = 'https://wa.me/$p?text=$msg';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}

// ─────────────────────────────────────────────────────────────────

// lib/screens/worknums_screen.dart
class WorkNumsScreen extends StatefulWidget {
  const WorkNumsScreen({super.key});
  @override
  State<WorkNumsScreen> createState() => _WorkNumsScreenState();
}

class _WorkNumsScreenState extends State<WorkNumsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final nums = _search.isEmpty
        ? prov.db.workNums
        : prov.db.workNums.where((w) =>
            w.phone.contains(_search) ||
            w.label.toLowerCase().contains(_search.toLowerCase())).toList();

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
                    Text('📋 أرقام العمل', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 15)),
                    Text('أرقام جاهزة تحت الطلب مع بيانات الشريحة', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showAddModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1565c0), Color(0xFF2196f3)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('+ إضافة رقم', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: '🔍 بحث برقم أو اسم...',
              hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.muted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // List
        Expanded(
          child: nums.isEmpty
              ? Center(child: Text('لا توجد أرقام', style: GoogleFonts.cairo(color: AppColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: nums.length,
                  itemBuilder: (_, i) {
                    final w = nums[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.phone, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppColors.blue2, fontSize: 16), textDirection: TextDirection.ltr),
                                if (w.label.isNotEmpty)
                                  Text(w.label, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted)),
                                if (w.notes != null && w.notes!.isNotEmpty)
                                  Text(w.notes!, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.blue, size: 20), onPressed: () => _showEditModal(context, w)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
                                onPressed: () => prov.deleteWorkNum(w.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddModal(BuildContext context) => _showModal(context, null);
  void _showEditModal(BuildContext context, workNum) => _showModal(context, workNum);

  void _showModal(BuildContext context, workNum) {
    final phoneCtrl = TextEditingController(text: workNum?.phone ?? '');
    final labelCtrl = TextEditingController(text: workNum?.label ?? '');
    final notesCtrl = TextEditingController(text: workNum?.notes ?? '');

    showModalBottomSheet(useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalShell(
        title: workNum == null ? '📋 إضافة رقم عمل' : '✏️ تعديل رقم عمل',
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              if (phoneCtrl.text.trim().isEmpty) return;
              final prov = context.read<AppProvider>();
              if (workNum == null) {
                prov.addWorkNum(WorkNum(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  phone: phoneCtrl.text.trim(),
                  label: labelCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                ));
              } else {
                prov.editWorkNum(WorkNum(
                  id: workNum.id,
                  phone: phoneCtrl.text.trim(),
                  label: labelCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                ));
              }
              Navigator.pop(context);
            },
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
        children: [
          AppFormField(label: 'رقم الموبايل', controller: phoneCtrl, textDirection: TextDirection.ltr, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          AppFormField(label: 'الاسم / التصنيف', controller: labelCtrl),
          const SizedBox(height: 12),
          AppFormField(label: 'ملاحظات (سيريال، تاريخ انتهاء...)', controller: notesCtrl),
        ],
      ),
    );
  }
}

