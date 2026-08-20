// test/guarantor_pay_test.dart
// 🤝 توزيع دفعة الكفيل على العملاء اللي تحته.
//
// الاختبارات دي مبنية على حالة حقيقية اتلخبطت: كفيل تحته تلات خطوط،
// واحد منهم مسدّد وليه رصيد، والتوزيع القديم كان بيدّيه فلوس برضه —
// فالفلوس بتتحوّل أرصدة لناس ماعليهاش حاجة والدين مابينزلش.

import 'package:flutter_test/flutter_test.dart';
import 'package:telecom_app/models/models.dart';

const kG = '01100046285';

Member mem(String id, double balance, {String phone = kG}) => Member(
      id: id,
      gid: 'g1',
      name: 'عميل $id',
      phone: '0111$id',
      guarantorPhone: phone,
      balance: balance,
    );

AppDB dbOf(List<Member> ms) =>
    AppDB(groups: [], members: ms, companyBills: []);

void main() {
  group('🤝 توزيع دفعة الكفيل — بالتناسب', () {
    test('⚠️ اللي ماعليهوش دين مابياخدش ولا جنيه', () {
      // دي الغلطة الأصلية: التوزيع المتساوي كان بيدّي للمسدّد برضه.
      final db = dbOf([
        mem('a', 60), // مسدّد وليه رصيد
        mem('b', -490),
        mem('c', -2090),
      ]);
      final r = db.splitGuarantorPayment(kG, 1650);
      expect(r.shares.containsKey('a'), isFalse,
          reason: 'المسدّد مالوش نصيب');
      expect(r.shares.length, 2);
    });

    test('الحالة الحقيقية: ٣٣٠٠ على دين ٢٥٨٠', () {
      final db = dbOf([mem('a', 60), mem('b', -490), mem('c', -2090)]);
      final r = db.splitGuarantorPayment(kG, 3300);
      // الدين كله ٢٥٨٠ — كل واحد ياخد دينه بالظبط
      expect(r.shares['b'], 490);
      expect(r.shares['c'], 2090);
      // والزيادة تفضل عند الكفيل، ما تتحطش رصيد لحد
      expect(r.leftover, 720,
          reason: 'الزيادة للكفيل مش رصيد لناس ماعليهاش حاجة');
    });

    test('كل واحد ينزل بنفس النسبة من دينه', () {
      final db = dbOf([mem('a', -4000), mem('b', -2000), mem('c', -1000)]);
      final r = db.splitGuarantorPayment(kG, 5500); // ٧٨.٥٧٪
      expect(r.shares['a']!, closeTo(3142.86, 0.01));
      expect(r.shares['b']!, closeTo(1571.43, 0.01));
      expect(r.shares['c']!, closeTo(785.71, 0.01));
      expect(r.leftover, 0);
    });

    test('⚠️ مجموع الحصص = المبلغ بالظبط (مفيش قرش ضايع)', () {
      // القسمة بتسيب كسور؛ لو الحصص المقرّبة مجموعها مش المبلغ، الفرق
      // بيتراكم مع كل دفعة لحد ما الأرقام تبقى مش مطابقة لأي حاجة.
      final db = dbOf([mem('a', -1000), mem('b', -1000), mem('c', -1000)]);
      final r = db.splitGuarantorPayment(kG, 1000);
      final sum = r.shares.values.fold<double>(0, (s, v) => s + v);
      expect(sum, closeTo(1000, 0.0001));
    });

    test('محدش بياخد أكتر من اللي عليه', () {
      final db = dbOf([mem('a', -100), mem('b', -5000)]);
      final r = db.splitGuarantorPayment(kG, 5100);
      expect(r.shares['a'], 100, reason: 'مش أكتر من دينه');
      expect(r.shares['b'], 5000);
    });

    test('عملاء كفيل تاني مالهمش دعوة', () {
      final db = dbOf([
        mem('a', -1000),
        mem('x', -9999, phone: '01000000000'),
      ]);
      final r = db.splitGuarantorPayment(kG, 500);
      expect(r.shares.keys, ['a']);
    });

    test('مفيش مدينين = المبلغ كله يفضل عند الكفيل', () {
      final db = dbOf([mem('a', 60), mem('b', 0)]);
      final r = db.splitGuarantorPayment(kG, 1000);
      expect(r.shares, isEmpty);
      expect(r.leftover, 1000);
    });

    test('مبلغ صفر أو بالسالب مابيعملش حاجة', () {
      final db = dbOf([mem('a', -1000)]);
      expect(db.splitGuarantorPayment(kG, 0).shares, isEmpty);
      expect(db.splitGuarantorPayment(kG, -50).shares, isEmpty);
    });
  });

  group('🤝 توزيع دفعة الكفيل — الأقدم أولاً', () {
    test('يخلّص الأكبر ديناً وبعدين اللي بعده', () {
      final db = dbOf([mem('a', -4000), mem('b', -2000), mem('c', -1000)]);
      final r = db.splitGuarantorPayment(kG, 5500, mode: 'oldestFirst');
      expect(r.shares['a'], 4000, reason: 'خلص');
      expect(r.shares['b'], 1500, reason: 'الباقي');
      expect(r.shares.containsKey('c'), isFalse, reason: 'ماوصلوش دور');
    });

    test('مجموع الحصص = المبلغ', () {
      final db = dbOf([mem('a', -4000), mem('b', -2000)]);
      final r = db.splitGuarantorPayment(kG, 5500, mode: 'oldestFirst');
      expect(r.shares.values.fold<double>(0, (s, v) => s + v), 5500);
    });
  });
}
