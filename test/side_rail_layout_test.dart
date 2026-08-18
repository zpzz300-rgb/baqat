// test/side_rail_layout_test.dart
// 🔍 عزل سبب «الشاشة السودا» في القايمة الجانبية الثابتة.
//
// القصة: على التاب بالعرض، لما القايمة كانت ثابتة على الجنب (يعني القايمة
// والمحتوى جوّه `Row`)، أول ما تفتح أي تاب الشاشة كانت تطلع سودا.
// اتجرّب حلّين قبل كده والمشكلة فضلت، فالميزة اتقفلت (`hasSideRail = false`).
//
// الاختبار ده بيعيد بناء **نفس التركيب** بأصغر شكل ممكن — من غير Supabase
// ولا Provider — عشان نعرف هل التركيب نفسه سليم ولا لأ، بدل ما نخمّن.
//
// التركيب الحقيقي: Row → Expanded → Stack → Positioned.fill → Column →
//                  Expanded → IndexedStack → Navigator
//
// النقطة الحرجة: `Navigator` **ملوش مقاس طبيعي** — بياخد مقاسه من اللي
// فوقه. لو أي حلقة في السلسلة دي سابته من غير حدود، بيطلع بعرض صفر —
// وشاشة عرضها صفر = شاشة سودا.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// نفس تركيب `WorkspaceTabHost` — Navigator عريان.
Widget _tabHost(String label) => Navigator(
      onGenerateInitialRoutes: (nav, initial) => [
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text(label, key: Key('body_$label'))),
          ),
        ),
      ],
    );

/// نفس تركيب الشاشة الرئيسية لما يكون فيه تاب مفتوح.
Widget _content({required int activeIndex}) => Column(
      children: [
        Container(color: const Color(0xFF0D1B3E), height: 24),
        const SizedBox(height: 38), // WorkspaceBar
        Expanded(
          child: IndexedStack(
            index: activeIndex,
            children: [
              const Center(child: Text('الرئيسية')),
              _tabHost('tab1'),
            ],
          ),
        ),
      ],
    );

Widget _stack({required int activeIndex}) => Stack(
      children: [
        Positioned.fill(child: _content(activeIndex: activeIndex)),
        // الودجتين دول مش Positioned — الـ Stack بتحسب مقاسها منهم
        const Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(width: 56, height: 56),
        ),
      ],
    );

/// النسخة اللي بالقايمة الجانبية الثابتة (اللي كانت بتسوّد).
Widget _withRail({required int activeIndex}) => MaterialApp(
      home: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 290, child: Container(color: Colors.white)),
            Expanded(child: _stack(activeIndex: activeIndex)),
          ],
        ),
      ),
    );

/// النسخة الشغّالة دلوقتي (من غير Row).
Widget _withoutRail({required int activeIndex}) => MaterialApp(
      home: Scaffold(body: _stack(activeIndex: activeIndex)),
    );

void main() {
  const wide = Size(1280, 800);

  Future<void> pumpAt(WidgetTester t, Widget w) async {
    t.view.physicalSize = wide;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(w);
    await t.pumpAndSettle();
  }

  group('🖥 تخطيط القايمة الجانبية الثابتة', () {
    testWidgets('من غير قايمة جانبية: التاب بياخد عرض كامل', (t) async {
      await pumpAt(t, _withoutRail(activeIndex: 1));
      final box = t.getSize(find.byKey(const Key('body_tab1')));
      expect(box.width, greaterThan(0), reason: 'الشاشة مش سودا');
    });

    testWidgets('⚠️ بالقايمة الجانبية: التاب لازم ياخد الباقي مش صفر',
        (t) async {
      await pumpAt(t, _withRail(activeIndex: 1));
      // لو التركيب بايظ، ده بيرمي استثناء تخطيط أو بيدّي عرض صفر
      expect(layoutException(), isNull,
          reason: 'مفيش استثناء تخطيط في الـ Row');
      final rect = t.getRect(find.byType(IndexedStack));
      expect(rect.width, greaterThan(0), reason: 'الـ IndexedStack ليها عرض');
      expect(rect.width, closeTo(1280 - 290, 1),
          reason: 'واخدة الباقي بعد القايمة بالظبط');
      expect(rect.height, greaterThan(0));
    });

    testWidgets('بالقايمة الجانبية: الرئيسية (مش تاب) شغّالة برضه', (t) async {
      await pumpAt(t, _withRail(activeIndex: 0));
      expect(find.text('الرئيسية'), findsOneWidget);
      final rect = t.getRect(find.byType(IndexedStack));
      expect(rect.width, closeTo(1280 - 290, 1));
    });
  });
}

/// أي استثناء تخطيط اتسجّل في الإطار ده؟
Object? layoutException() {
  final d = TestWidgetsFlutterBinding.instance.takeException();
  return d;
}
