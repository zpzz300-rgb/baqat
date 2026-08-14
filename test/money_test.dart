// test/money_test.dart
// 🧮 اختبارات حسابات الفلوس.
//
// دي شبكة أمان: أي تعديل جاي على معادلات الربح أو المديونية أو
// الفواتير، لو كسر واحدة من دي التست بيفشل قبل ما البرنامج يوصلك.
//
// شغّلها بـ:  flutter test
//
// ملحوظة: الملف ده بيختبر الحسابات في models.dart بس — مافيش فيه
// أي اتصال بقاعدة بيانات ولا بالنت، ومابيلمسش بيانات حقيقية خالص.

import 'package:flutter_test/flutter_test.dart';
import 'package:telecom_app/models/models.dart';

/// دفعة على فاتورة — `paidAmount` بيتحسب من الدفعات مش بيتكتب بالإيد.
BillPayment _pay(double amount) =>
    BillPayment(id: 'p$amount', amount: amount, date: '01/08/2026');

/// عميل جاهز للاختبار.
Member _member({
  required String gid,
  double price = 0,
  double balance = 0,
  String type = 'regular',
  String name = 'عميل',
}) =>
    Member(
      id: 'm${DateTime.now().microsecondsSinceEpoch}${price.hashCode}',
      gid: gid,
      name: name,
      phone: '01000000000',
      package: '10',
      gb: 10,
      price: price,
      balance: balance,
      type: type,
    );

void main() {
  _indexTests();
  // ══════════════════════════════════════════════════════════════
  group('🧾 الفاتورة — المتبقي والحالة', () {
    CompanyBill bill({double actual = 0, double paid = 0}) => CompanyBill(
          id: 'b1',
          groupId: 'g1',
          month: '2026-08',
          fixedAmount: 1000,
          actualAmount: actual,
          payments: paid > 0 ? [_pay(paid)] : [],
          date: '01/08/2026',
        );

    test('مادفعش حاجة → المتبقي = المبلغ كله وحالتها «غير مسدد»', () {
      final b = bill(actual: 1000);
      expect(b.remaining, 1000);
      expect(b.isPaid, isFalse);
      expect(b.isPartial, isFalse);
      expect(b.status, 'unpaid');
    });

    test('دفع جزء → المتبقي = الفرق وحالتها «جزئي»', () {
      final b = bill(actual: 1000, paid: 400);
      expect(b.remaining, 600);
      expect(b.isPartial, isTrue);
      expect(b.status, 'partial');
    });

    test('دفع الكل → المتبقي صفر وحالتها «مسدد»', () {
      final b = bill(actual: 1000, paid: 1000);
      expect(b.remaining, 0);
      expect(b.isPaid, isTrue);
      expect(b.status, 'paid');
    });

    test('⚠️ دفع أكتر من المطلوب → المتبقي صفر، مايبقاش بالسالب', () {
      final b = bill(actual: 1000, paid: 1500);
      expect(b.remaining, 0, reason: 'المتبقي ماينفعش يبقى سالب');
      expect(b.isPaid, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  group('💰 ربح المجموعة', () {
    AppDB dbWith(Group g, List<Member> members) => AppDB()
      ..groups.add(g)
      ..members.addAll(members);

    test('دخل العملاء ناقص الفاتورة الثابتة', () {
      final g = Group(id: 'g1', phone: '0100', fixedBillAmount: 500);
      final db = dbWith(g, [
        _member(gid: 'g1', price: 200),
        _member(gid: 'g1', price: 300),
        _member(gid: 'g1', price: 250),
      ]);
      // 750 دخل − 500 فاتورة = 250
      expect(db.groupProfit('g1'), 250);
    });

    test('⚠️ مفيش فاتورة ثابتة متحددة → الربح صفر (مش دخل العملاء كله)', () {
      final g = Group(id: 'g1', phone: '0100'); // fixedBillAmount = 0
      final db = dbWith(g, [_member(gid: 'g1', price: 300)]);
      expect(db.groupProfit('g1'), 0,
          reason: 'من غير تكلفة معروفة مينفعش نحسب ربح');
    });

    test('عملاء زيادة عن الحد → بيتخصم رسم عن كل واحد', () {
      final g = Group(
        id: 'g1',
        phone: '0100',
        fixedBillAmount: 500,
        maxClients: 2,
        extraClientFee: 100,
        lineType: LineType.mobile, // الموبايل بس هو اللي عليه رسوم زيادة
      );
      final db = dbWith(g, [
        _member(gid: 'g1', price: 300),
        _member(gid: 'g1', price: 300),
        _member(gid: 'g1', price: 300), // التالت زيادة
        _member(gid: 'g1', price: 300), // والرابع زيادة
      ]);
      expect(db.groupExtraLines('g1'), 2);
      expect(db.groupExtraLineFee('g1'), 200);
      // 1200 دخل − 500 فاتورة − 200 زيادة = 500
      expect(db.groupProfit('g1'), 500);
    });

    test('سعر الزيادة مش متحدد → بيستخدم الافتراضي 125', () {
      final g = Group(
        id: 'g1',
        phone: '0100',
        fixedBillAmount: 500,
        maxClients: 1,
        lineType: LineType.mobile,
      );
      final db = dbWith(g, [
        _member(gid: 'g1', price: 400),
        _member(gid: 'g1', price: 400), // زيادة واحد
      ]);
      expect(db.groupExtraLineFee('g1'), AppDB.defaultExtraClientFee);
      expect(db.groupProfit('g1'), 800 - 500 - 125);
    });

    test('⚠️ الأرضي والهوم مابيتحسبوش زيادة (مجانيين من الشركة)', () {
      final g = Group(
        id: 'g1',
        phone: '0100',
        fixedBillAmount: 500,
        maxClients: 1,
        extraClientFee: 100,
        lineType: LineType.mobile,
      );
      final db = dbWith(g, [
        _member(gid: 'g1', price: 300),
        _member(gid: 'g1', price: 300, type: 'landline'),
        _member(gid: 'g1', price: 300, type: 'homeforgee'),
      ]);
      expect(db.groupExtraLines('g1'), 0,
          reason: 'موبايل واحد بس، والحد 1 → مفيش زيادة');
    });

    test('⚠️ الخط الافتراضي «هوم 4G» مالوش رسوم زيادة أصلاً', () {
      // مهم تعرفه: أي خط جديد بيتعمل نوعه «هوم 4G»، ودي مالهاش رسوم
      // زيادة. لازم تغيّر نوع الخط لـ «موبايل» عشان الرسوم تشتغل.
      final g = Group(
        id: 'g1',
        phone: '0100',
        fixedBillAmount: 500,
        maxClients: 1,
        extraClientFee: 100,
      );
      expect(g.lineType, LineType.home4g, reason: 'ده النوع الافتراضي');
      final db = dbWith(g, [
        _member(gid: 'g1', price: 300),
        _member(gid: 'g1', price: 300),
        _member(gid: 'g1', price: 300),
      ]);
      expect(db.groupExtraLineFee('g1'), 0);
    });

    test('مفيش حد أقصى متحدد → مفيش رسوم زيادة', () {
      final g = Group(id: 'g1', phone: '0100', fixedBillAmount: 500);
      final db = dbWith(g, [
        for (var i = 0; i < 10; i++) _member(gid: 'g1', price: 100),
      ]);
      expect(db.groupExtraLines('g1'), 0);
      expect(db.groupProfit('g1'), 1000 - 500);
    });

    test('عملاء مجموعة تانية مابيدخلوش في حسابها', () {
      final db = AppDB()
        ..groups.addAll([
          Group(id: 'g1', phone: '0100', fixedBillAmount: 500),
          Group(id: 'g2', phone: '0111', fixedBillAmount: 500),
        ])
        ..members.addAll([
          _member(gid: 'g1', price: 600),
          _member(gid: 'g2', price: 900),
        ]);
      expect(db.groupProfit('g1'), 100);
      expect(db.groupProfit('g2'), 400);
    });
  });

  // ══════════════════════════════════════════════════════════════
  group('🎯 النقاط', () {
    test('قيمة النقاط الشهرية = عدد النقاط × سعر النقطة', () {
      final g = Group(
          id: 'g1', phone: '0100', pointsMonthly: 30, pointPrice: 12.5);
      expect(g.monthlyPointsValue, 375);
    });

    test('⚠️ النقاط فاضية → القيمة صفر مش خطأ', () {
      final g = Group(id: 'g1', phone: '0100');
      expect(g.monthlyPointsValue, 0);
    });

    test('سعر النقطة متحدد والعدد لأ → القيمة صفر', () {
      final g = Group(id: 'g1', phone: '0100', pointPrice: 12.5);
      expect(g.monthlyPointsValue, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════
  group('🧳 الضيوف', () {
    test('الربح = اللي من العميل ناقص اللي للتاجر', () {
      final g = GuestUser(
        id: 'x1',
        clientName: 'عميل',
        clientPhone: '0100',
        clientAmount: 500,
        dealerCost: 380,
      );
      expect(g.profit, 120);
    });

    test('⚠️ التاجر أغلى من العميل → الربح بالسالب (خسارة)', () {
      final g = GuestUser(
        id: 'x1',
        clientName: 'عميل',
        clientPhone: '0100',
        clientAmount: 300,
        dealerCost: 400,
      );
      expect(g.profit, -100);
    });
  });

  // ══════════════════════════════════════════════════════════════
  group('📊 الملخص المالي', () {
    test('«ليا كام» = مجموع الأرصدة السالبة بس', () {
      final db = AppDB()
        ..groups.add(Group(id: 'g1', phone: '0100'))
        ..members.addAll([
          _member(gid: 'g1', balance: -300), // عليه 300
          _member(gid: 'g1', balance: -200), // عليه 200
          _member(gid: 'g1', balance: 150),  // ليه 150 (مايتحسبش)
        ]);
      expect(db.financialSummary['receivables'], 500);
    });

    test('عدد المديونين = اللي رصيدهم سالب', () {
      final db = AppDB()
        ..groups.add(Group(id: 'g1', phone: '0100'))
        ..members.addAll([
          _member(gid: 'g1', balance: -300),
          _member(gid: 'g1', balance: 0),
          _member(gid: 'g1', balance: 50),
          _member(gid: 'g1', balance: -1),
        ]);
      expect(db.debtorCount, 2);
    });

    test('مديونية الكفيل = مجموع اللي على عملاءه', () {
      final db = AppDB()
        ..groups.add(Group(id: 'g1', phone: '0100'))
        ..members.addAll([
          _member(gid: 'g1', balance: -300),
          _member(gid: 'g1', balance: -700),
          _member(gid: 'g1', balance: 500), // الموجب مايقلّلش الدين
        ]);
      expect(db.totalDebt, 1000);
    });

    test('⚠️ الضيوف المدفوعين مايتحسبوش في المستحق للتجار', () {
      final db = AppDB()
        ..guestUsers.addAll([
          GuestUser(
              id: 'x1',
              clientName: 'أ',
              clientPhone: '01',
              dealerCost: 200,
              isPaid: false),
          GuestUser(
              id: 'x2',
              clientName: 'ب',
              clientPhone: '02',
              dealerCost: 300,
              isPaid: true),
        ]);
      expect(db.financialSummary['guestDebt'], 200);
    });

    test('إجمالي الدخل الشهري = مجموع أسعار العملاء', () {
      final db = AppDB()
        ..groups.add(Group(id: 'g1', phone: '0100'))
        ..members.addAll([
          _member(gid: 'g1', price: 250),
          _member(gid: 'g1', price: 300),
        ]);
      expect(db.totalMonthlyIncome, 550);
    });
  });

  // ══════════════════════════════════════════════════════════════
  group('🏦 فواتير الشركات — الإجمالي', () {
    test('المستحق = مجموع المتبقي من كل الفواتير', () {
      final db = AppDB()
        ..groups.add(Group(id: 'g1', phone: '0100'))
        ..companyBills.addAll([
          CompanyBill(
              id: 'b1',
              groupId: 'g1',
              month: '2026-07',
              actualAmount: 1000,
              payments: [_pay(400)],
              date: '01/07/2026'),
          CompanyBill(
              id: 'b2',
              groupId: 'g1',
              month: '2026-08',
              actualAmount: 800,
              payments: [_pay(800)],
              date: '01/08/2026'),
        ]);
      expect(db.totalBillsOwed, 600);
    });
  });
}

// ══════════════════════════════════════════════════════════════
// ⚡ فهرس العملاء (كاش السرعة) — لازم يتمسح مع أي تعديل
//
// `membersOf` بقت بتستخدم فهرس محفوظ عشان السرعة. الخطر إن الفهرس
// يفضل قديم بعد ما تضيف أو تحذف عميل، فتشوف بيانات غلط. التستات دي
// بتتأكد إن ده مايحصلش.
void _indexTests() {
  group('⚡ فهرس العملاء', () {
    test('بيرجّع عملاء المجموعة الصح', () {
      final db = AppDB()
        ..members.addAll([
          _member(gid: 'g1', name: 'أ'),
          _member(gid: 'g2', name: 'ب'),
          _member(gid: 'g1', name: 'ج'),
        ]);
      expect(db.membersOf('g1').length, 2);
      expect(db.membersOf('g2').length, 1);
      expect(db.membersOf('g3'), isEmpty);
    });

    test('إضافة عميل بعد قراءة الفهرس لازم تبان بعد المسح', () {
      final db = AppDB()..members.add(_member(gid: 'g1'));
      expect(db.membersOf('g1').length, 1); // بنى الفهرس
      db.members.add(_member(gid: 'g1', price: 50));
      db.invalidateMembersIndex();
      expect(db.membersOf('g1').length, 2);
    });

    test('حذف عميل لازم يبان بعد المسح', () {
      final db = AppDB()
        ..members.addAll([_member(gid: 'g1'), _member(gid: 'g1', price: 7)]);
      expect(db.membersOf('g1').length, 2);
      db.members.removeWhere((m) => m.price == 7);
      db.invalidateMembersIndex();
      expect(db.membersOf('g1').length, 1);
    });

    test('نقل عميل لمجموعة تانية لازم يبان بعد المسح', () {
      final db = AppDB()..members.add(_member(gid: 'g1'));
      expect(db.membersOf('g1').length, 1);
      db.members[0].gid = 'g2';
      db.invalidateMembersIndex();
      expect(db.membersOf('g1'), isEmpty);
      expect(db.membersOf('g2').length, 1);
    });

    test('⚠️ ترتيب اللستة الراجعة ما يبوّظش الفهرس', () {
      final db = AppDB()
        ..members.addAll([
          _member(gid: 'g1', name: 'ب', price: 2),
          _member(gid: 'g1', name: 'أ', price: 1),
        ]);
      // في أماكن في البرنامج بتعمل membersOf(id)..sort(...) — لو رجّعنا
      // نفس اللستة المحفوظة كان الترتيب ده هيعدّل على الفهرس نفسه.
      db.membersOf('g1').sort((a, b) => a.name.compareTo(b.name));
      final after = db.membersOf('g1');
      expect(after[0].price, 2, reason: 'الفهرس اتغيّر من برّه');
    });
  });
}
