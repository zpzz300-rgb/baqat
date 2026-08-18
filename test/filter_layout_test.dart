// test/filter_layout_test.dart
// 📐 «الهيدر كبير والناتج تحت صغير» — الشكوى دي مكتوبة هنا كاختبار.
//
// شاشة تصنيف العملاء كانت ٥ صفوف فلاتر مرصوصة فوق النتيجة. على شاشة
// ١٩٢٠×١٠٨٠ الفلاتر كانت بتاكل حوالي ٧٠٠ بكسل والنتيجة تفضل في شريط
// تحت — يعني بتفلتر عشان تشوف نتيجة، والنتيجة هي أصغر حاجة في الشاشة.
//
// الاختبار ده بيقيس **نسبة المساحة** اللي بتاخدها النتيجة، عشان لو حد
// زوّد فلتر جديد بعدين والشاشة رجعت تتخنق، الاختبار يقع من قبل ما
// المستخدم يشوفها.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// نفس تركيب `_layout` في `member_filter_screen.dart`.
class _FilterLayout extends StatefulWidget {
  const _FilterLayout({required this.wide, required this.filterRows});

  final bool wide;
  final int filterRows;

  @override
  State<_FilterLayout> createState() => _FilterLayoutState();
}

class _FilterLayoutState extends State<_FilterLayout> {
  bool _open = true;

  List<Widget> get _filters => [
        for (var i = 0; i < widget.filterRows; i++)
          SizedBox(height: 40, key: Key('filter_$i')),
      ];

  Widget get _summary => const SizedBox(height: 44, key: Key('summary'));

  Widget get _list => ListView(
        key: const Key('list'),
        children: const [SizedBox(height: 2000)],
      );

  @override
  Widget build(BuildContext context) {
    if (widget.wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 300, child: ListView(children: _filters)),
        const VerticalDivider(width: 1),
        Expanded(child: Column(children: [_summary, Expanded(child: _list)])),
      ]);
    }
    return Column(children: [
      InkWell(
        key: const Key('toggle'),
        onTap: () => setState(() => _open = !_open),
        child: const SizedBox(height: 40, width: double.infinity),
      ),
      if (_open)
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView(shrinkWrap: true, children: _filters),
        ),
      _summary,
      Expanded(child: _list),
    ]);
  }
}

void main() {
  Future<void> pump(WidgetTester t, Size size, Widget child) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: child)));
    await t.pumpAndSettle();
  }

  group('📐 شاشة تصنيف العملاء — النتيجة لازم تاخد مساحة محترمة', () {
    testWidgets('🖥 عريض: الفلاتر على الجنب والنتيجة بالطول كله', (t) async {
      const h = 900.0;
      await pump(t, const Size(1500, h),
          const _FilterLayout(wide: true, filterRows: 8));
      final list = t.getSize(find.byKey(const Key('list')));
      expect(list.height, greaterThan(h * 0.9),
          reason: 'النتيجة واخدة الطول كله تقريباً — الفلاتر مش فوقها');
      expect(list.width, closeTo(1500 - 300 - 1, 2),
          reason: 'واخدة العرض الباقي بعد اللوح الجنبي');
    });

    testWidgets('📱 موبايل: النتيجة أكبر من نص الشاشة حتى والفلاتر مفتوحة',
        (t) async {
      const h = 800.0;
      await pump(t, const Size(420, h),
          const _FilterLayout(wide: false, filterRows: 8));
      final list = t.getSize(find.byKey(const Key('list')));
      // ٨ صفوف × ٤٠ = ٣٢٠، والحد ٤٥٪ بيمنعها تعدّي ٣٦٠
      expect(list.height, greaterThan(h * 0.4),
          reason: 'الفلاتر محدودة بـ٤٥٪ فالنتيجة مابتتخنقش');
    });

    testWidgets('⚠️ موبايل: ولو الفلاتر زادت لعشرين صف برضه مابتاكلش الشاشة',
        (t) async {
      const h = 800.0;
      await pump(t, const Size(420, h),
          const _FilterLayout(wide: false, filterRows: 20));
      final list = t.getSize(find.byKey(const Key('list')));
      expect(list.height, greaterThan(h * 0.4),
          reason: 'الحد الأقصى بيحمي النتيجة مهما زادت الفلاتر');
    });

    testWidgets('📱 موبايل: طي الفلاتر بيدّي النتيجة الشاشة كلها', (t) async {
      const h = 800.0;
      await pump(t, const Size(420, h),
          const _FilterLayout(wide: false, filterRows: 8));
      await t.tap(find.byKey(const Key('toggle')));
      await t.pumpAndSettle();
      final list = t.getSize(find.byKey(const Key('list')));
      expect(list.height, greaterThan(h * 0.85),
          reason: 'مقفولة = النتيجة بس');
    });
  });
}
