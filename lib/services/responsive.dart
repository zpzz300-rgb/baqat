// lib/services/responsive.dart
//
// 📐 أدوات الشاشة العريضة — تاب وكمبيوتر.
//
// `breakpoints.dart` بيقول لك **انت على إيه** (كام عمود، كام مسافة).
// الملف ده بيديك **الأدوات** اللي بتنفّذ بيها: قايمة بتتقسم أعمدة، وشيت
// بيتحوّل نافذة على الكمبيوتر.
//
// ليه اتعملوا: البرنامج كله متبني للموبايل — عمود واحد وكل حاجة مفرودة
// بعرض الشاشة. على شاشة ١٩٢٠ بكسل الكارت بيتمدّ من أول الشاشة لآخرها،
// فالاسم في ناحية والمبلغ في الناحية التانية وعينك بتلف عليهم. الحل مش
// إننا نحدّ العرض ونسيب الباقي فاضي — الحل إننا **نملا** المساحة ببيانات
// أكتر في نفس النظرة.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'breakpoints.dart';

// ══════════════════════════════════════════════════════════════════════════
// 🗂 قايمة كروت بتتقسم أعمدة
// ══════════════════════════════════════════════════════════════════════════

/// قايمة كروت بتتوزّع على أعمدة حسب مقاس الشاشة.
///
/// كل عمود `ListView` لوحده، فالكروت اللي برّه الشاشة **مابتتبنيش أصلاً**
/// والتمرير بيفضل خفيف مهما زاد العدد.
///
/// التوزيع بالتبادل (١،٢،٣ | ٤،٥،٦ …) مش نص ونص، عشان الترتيب اللي انت
/// شايفه من الشمال لليمين يفضل هو ترتيب القايمة الحقيقي.
///
/// ⚠️ الأعمدة بتطول كل واحد لوحده — ده مقصود، لأن الكروت مش نفس الطول
/// (المفتوح أطول من المقفول) ولو ربطناهم هيبقى في فراغ تحت الأقصر.
class ResponsiveCards extends StatelessWidget {
  const ResponsiveCards({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.columns,
    this.controller,
    this.emptyState,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;

  /// عدد الأعمدة بالإيد — لو null بياخده من مقاس الشاشة.
  final int? columns;

  /// بيشتغل في وضع العمود الواحد بس (الأعمدة كل واحد ليه تمريره).
  final ScrollController? controller;

  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return emptyState ?? const SizedBox.shrink();

    final cols = columns ?? context.listCols;
    final pad = padding ??
        EdgeInsets.fromLTRB(context.gutter, 8, context.gutter, 90);

    if (cols <= 1 || itemCount < 2) {
      return ListView.builder(
        controller: controller,
        padding: pad,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }

    // توزيع بالتبادل على الأعمدة
    final buckets = List.generate(cols, (_) => <int>[]);
    for (var i = 0; i < itemCount; i++) {
      buckets[i % cols].add(i);
    }

    final gap = context.gutter / 2;
    final outer = pad.resolve(Directionality.of(context));
    return Padding(
      padding: EdgeInsets.only(left: outer.left, right: outer.right),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < cols; c++) ...[
            if (c > 0) SizedBox(width: gap),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(top: outer.top, bottom: outer.bottom),
                itemCount: buckets[c].length,
                itemBuilder: (ctx, i) => itemBuilder(ctx, buckets[c][i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// نفس فكرة [ResponsiveCards] بس للـ widgets الجاهزة (مش builder).
/// بتستخدمها جوّه `Column` أو `ListView` موجودة — مش بتعمل تمرير لوحدها.
class ResponsiveRowGroup extends StatelessWidget {
  const ResponsiveRowGroup({super.key, required this.children, this.columns});

  final List<Widget> children;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? context.listCols;
    if (cols <= 1 || children.length < 2) {
      return Column(children: children);
    }
    final buckets = List.generate(cols, (_) => <Widget>[]);
    for (var i = 0; i < children.length; i++) {
      buckets[i % cols].add(children[i]);
    }
    final gap = context.gutter / 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < cols; c++) ...[
          if (c > 0) SizedBox(width: gap),
          Expanded(child: Column(children: buckets[c])),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 🪟 شيت بيتحوّل نافذة على الكمبيوتر
// ══════════════════════════════════════════════════════════════════════════

/// بديل `showModalBottomSheet` بيراعي مقاس الشاشة.
///
/// * موبايل وتاب → ورقة بتطلع من تحت زي ما هي (الإصبع بيوصلها).
/// * كمبيوتر → **نافذة في نص الشاشة**. الورقة اللي بتطلع من تحت على شاشة
///   ١٠٨٠ بكسل بتخلّي المحتوى في آخر الشاشة وعينك لازم تنزل لتحت، والماوس
///   مالوش «إصبع» يوصل بيه بسرعة زي الموبايل.
///
/// نفس بارامترات `showModalBottomSheet` عشان يبقى بديل مباشر.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  Color? barrierColor,
  ShapeBorder? shape,
  double? maxDialogWidth,
}) {
  if (!context.sheetsAsDialogs) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor ?? Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      barrierColor: barrierColor,
      shape: shape,
      builder: builder,
    );
  }

  final size = MediaQuery.sizeOf(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: barrierColor,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      clipBehavior: Clip.antiAlias,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth ?? 720,
          maxHeight: size.height * 0.88,
        ),
        // الشيتات متكتوبة على إنها في آخر الشاشة، فبنلفّها في Material
        // عشان الخلفية والحواف يبانوا صح جوّه النافذة.
        child: Material(
          color: AppColors.surface,
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// 🖱 سلوك التمرير على الكمبيوتر
// ══════════════════════════════════════════════════════════════════════════

/// بيخلّي **الماوس يسحب** أي قايمة زي الصباع بالظبط.
///
/// فلاتر بتتزحلق يمين وشمال (شريط الشركات، أعمدة الشهور في الجدول) على
/// الموبايل بتسحبها بصباعك عادي. على الكمبيوتر فلاتر بتاعة Flutter بتمنع
/// السحب بالماوس افتراضياً، فالشريط بيبان زي ما هو مقفول — انت شايف إن فيه
/// حاجة على الجنب ومش عارف توصلها.
///
/// وبيضيف عجلة أفقية: العجلة العادية بتزحلق الجداول الأفقية كمان.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

// ══════════════════════════════════════════════════════════════════════════
// 🧩 لمسات الكمبيوتر
// ══════════════════════════════════════════════════════════════════════════

/// بيحط مؤشر «إيد» وتظليل خفيف عند مرور الماوس.
///
/// على الموبايل مالوش أي أثر (مفيش ماوس). على الكمبيوتر بيفرق كتير: من
/// غيره مش باين إيه اللي بيتدوس وإيه اللي للعرض بس.
class HoverTap extends StatefulWidget {
  const HoverTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 10,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final String? tooltip;

  @override
  State<HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<HoverTap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    Widget w = MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover && widget.onTap != null
                ? AppColors.blue.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
    if (widget.tooltip != null) {
      w = Tooltip(message: widget.tooltip!, child: w);
    }
    return w;
  }
}

/// Enter يحفظ و Esc يقفل — في أي مودال أو نافذة.
///
/// على الموبايل مفيش كيبورد فيزيائي فمالهاش أثر؛ على الكمبيوتر دي الفرق
/// بين إنك تكتب رقم وتدوس Enter، وبين إنك تسيب الكيبورد وتمسك الماوس
/// وتدوّر على زرار الحفظ.
class SheetShortcuts extends StatelessWidget {
  const SheetShortcuts({
    super.key,
    required this.child,
    this.onSave,
    this.onClose,
  });

  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (onSave != null)
          const SingleActivator(LogicalKeyboardKey.enter): onSave!,
        const SingleActivator(LogicalKeyboardKey.escape):
            onClose ?? () => Navigator.maybePop(context),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
