// lib/widgets/app_search_bar.dart
// 🎛️ شريط البحث الموحّد — نفس الشكل ونفس السلوك في كل شاشات البرنامج.
//
// قبل كده كل شاشة كانت بتبني خانة بحث بشكل مختلف (١٩ خانة، ١٩ شكل).
// دلوقتي كلهم بينادوا AppSearchBar، فلو غيّرنا الشكل هنا بيتغيّر في كله.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_search.dart' show SearchField;
import '../services/app_theme.dart';
import '../services/breakpoints.dart';

/// خانة البحث + (اختياري) زرار فلاتر بعدّاد + أي زراير زيادة.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = '🔍 دوّر بأي حاجة…',
    this.onHelp,
    this.onFilter,
    this.filterBadge = 0,
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 0),
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  /// لو مبعوت، بيظهر ❓ جوه الخانة وهي فاضية.
  final VoidCallback? onHelp;

  /// لو مبعوت، بيظهر زرار ⚙️ جنب الخانة.
  final VoidCallback? onFilter;

  /// الرقم الأحمر على زرار الفلاتر = كام فلتر شغّال.
  final int filterBadge;

  final List<Widget> trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final empty = controller.text.isEmpty;
    // 📐 خانة البحث مالهاش لازمة تبقى بعرض ١٩٠٠ بكسل — انت بتكتب فيها كلمة
    // أو رقم، والباقي مساحة ضايعة والزراير بتبعد عنها لآخر الشاشة. على
    // الشاشة العريضة بتاخد ٥٢٠ بكسل والزراير بتفضل جنبها على طول.
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.cairo(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
        suffixIcon: empty
            ? (onHelp == null
                ? null
                : IconButton(
                    icon: Icon(Icons.help_outline,
                        size: 17, color: AppColors.muted),
                    tooltip: 'البحث بيدوّر في إيه؟',
                    onPressed: onHelp,
                  ))
            : IconButton(
                icon: const Icon(Icons.close, size: 17),
                tooltip: 'امسح البحث',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: _b(AppColors.border),
        enabledBorder: _b(AppColors.border),
        focusedBorder: _b(AppColors.blue),
      ),
    );

    return Padding(
      padding: padding,
      child: Row(children: [
        if (context.isWide)
          SizedBox(width: 520, child: field)
        else
          Expanded(child: field),
        if (onFilter != null) ...[
          const SizedBox(width: 6),
          AppIconPill(icon: Icons.tune, badge: filterBadge, onTap: onFilter!),
        ],
        for (final w in trailing) ...[const SizedBox(width: 6), w],
      ]),
    );
  }

  static OutlineInputBorder _b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

/// زرار أيقونة مربّع بحواف مدوّرة، مع عدّاد أحمر اختياري.
class AppIconPill extends StatelessWidget {
  const AppIconPill({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.active = false,
    this.filled = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final bool active;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pill = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (filled || active) ? AppColors.blue2 : AppColors.blueLight,
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
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

/// شريحة اختيار موحّدة (فلتر / تصنيف). نفس المقاس في كل مكان.
class AppChip extends StatelessWidget {
  const AppChip(this.label,
      {super.key,
      required this.selected,
      required this.onTap,
      this.color,
      this.count});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// لون الشريحة — الافتراضي أزرق البرنامج (بيتغيّر مع الوضع الليلي).
  final Color? color;

  /// رقم صغير جنب الاسم (عدد العناصر).
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.blue2;
    // 🖱 مؤشر إيد على الكمبيوتر — الشريحة دي مستعملة في كل الشاشات
    // تقريباً، فالتعديل هنا بيظهر في البرنامج كله مرة واحدة.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c : c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: c.withValues(alpha: selected ? 1 : 0.35),
                width: selected ? 1.6 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: selected ? AppColors.onAccent : c)),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.onAccent.withValues(alpha: 0.28)
                      : c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('$count',
                    style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: selected ? AppColors.onAccent : c)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// شريحة فلتر شغّال — بتبان تحت البحث ومعاها ✕ تشيلها.
class AppActiveChip extends StatelessWidget {
  const AppActiveChip(this.label, {super.key, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.only(right: 10, left: 4),
        decoration: BoxDecoration(
            color: AppColors.blue2, borderRadius: BorderRadius.circular(15)),
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
}

/// 🎯 «لقاه في: …» — بيوريّ المستخدم البند ظهر في البحث ليه.
/// بيختفي لوحده لو الطابق كان الحقول الواضحة اللي بايناها قدامه.
class AppMatchLine extends StatelessWidget {
  const AppMatchLine(this.hits, {super.key, this.hideLabels = const []});
  final List<SearchField> hits;

  /// عناوين حقول ظاهرة أصلاً في الكارت، فمالهاش لزمة تتقال.
  final List<String> hideLabels;

  @override
  Widget build(BuildContext context) {
    final shown = hits
        .where((h) => h.label.isNotEmpty && !hideLabels.contains(h.label))
        .toList();
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
      child: Text('لقاه في: ${shown.map((h) => h.label).join(' · ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8D6E00))),
    );
  }
}

/// 🚫 حالة «مفيش نتيجة» موحّدة مع زرار مسح.
class AppEmptyResult extends StatelessWidget {
  const AppEmptyResult({
    super.key,
    this.message = 'مفيش نتيجة مطابقة',
    this.onClear,
  });
  final String message;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message,
              style: GoogleFonts.cairo(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          if (onClear != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: Text('امسح البحث والفلاتر',
                  style: GoogleFonts.cairo(fontSize: 12)),
            ),
          ],
        ]),
      );
}
