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
  _monthGuardTests();
  _profitBasisTests();
  _datingTests();
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
// ══════════════════════════════════════════════════════════════
// 📅 يوم النزول ≠ الفترة المغطّاة
//
// فاتورة ١/٥ نزلت يوم ١ شهر ٥ وبتغطي شهر ٤ كله.
// فاتورة ١٥/٥ نزلت يوم ١٥ وبتغطي من ١٥/٤ لـ ١٥/٥ — دي سيكل ٢.
void _datingTests() {
  AppDB dbWith(String cycle, String date, {String month = '2026-05'}) => AppDB()
    ..groups.add(Group(id: 'g1', phone: '01000000000', billingCycle: cycle))
    ..companyBills.add(CompanyBill(
      id: 'b1',
      groupId: 'g1',
      month: month,
      fixedAmount: 1000,
      actualAmount: 1000,
      date: date,
    ));

  group('📅 تأريخ الفاتورة', () {
    test('سيكل ١: فاتورة ١/٥ بتغطي شهر ٤ كله', () {
      final db = dbWith('cycle1', '1/5/2026');
      expect(db.billIssueLabel(db.companyBills[0]), 'فاتورة 1/5');
      expect(db.billCoveredPeriod(db.companyBills[0]), 'بتغطي شهر 4 كله');
    });

    test('سيكل ٢: فاتورة ١٥/٥ بتغطي من ١٥/٤ لـ ١٥/٥', () {
      final db = dbWith('cycle2', '15/5/2026');
      expect(db.billCoveredPeriod(db.companyBills[0]), 'بتغطي من 15/4 لـ 15/5');
    });

    test('⚠️ فاتورة يناير بتغطي ديسمبر اللي فات مش شهر صفر', () {
      final db = dbWith('cycle1', '1/1/2026', month: '2026-01');
      expect(db.billCoveredPeriod(db.companyBills[0]), 'بتغطي شهر 12 كله');
    });

    test('تاريخ مش مكتوب صح مايكسرش حاجة', () {
      final db = dbWith('cycle1', '');
      expect(db.billIssueLabel(db.companyBills[0]), 'فاتورة 2026-05');
      expect(db.billCoveredPeriod(db.companyBills[0]), 'بتغطي شهر 4 كله');
    });

    test('السيكل القديم (cycle=2) يتقرا سيكل ٢ لو billingCycle فاضي', () {
      final db = AppDB()
        ..groups.add(Group(id: 'g1', phone: '01000000000', cycle: '2'));
      expect(db.groupIsMidCycle(db.groups[0]), isTrue);
    });

    test('billingCycle الصريح بيغلب cycle القديم', () {
      final db = AppDB()
        ..groups.add(Group(
            id: 'g1', phone: '01000000000', cycle: '2', billingCycle: 'cycle1'));
      expect(db.groupIsMidCycle(db.groups[0]), isFalse);
    });
  });
}

// ══════════════════════════════════════════════════════════════
// 📊 أساس الربح مفصول عن السعر الخام
//
// فاتورة «شهر وشهر» بتنزل ٤٢٥٠ عشان بتغطي شهرين. لو حسبنا الربح عليها
// الشهر ده يبان خسران والشهر اللي بعده يبان مكسبان — وهو مش كده.
// عشان كده فيه رقمين: الخام (فلوس) وأساس الربح (تكلفة الشهر الواحد).
void _profitBasisTests() {
  Group g({double raw = 4250, double? profit, String system = 'bimonthly'}) =>
      Group(
        id: 'g1',
        phone: '01000000000',
        fixedBillAmount: raw,
        profitBillAmount: profit,
        billingSystem: system,
      );

  group('📊 أساس الربح', () {
    test('⚠️ ما اتكتبش → السلوك القديم بالظبط (الربح على الخام)', () {
      // ده أهم واحد: مفيش رقم ربح قديم بيتغيّر لوحده بعد الإضافة دي.
      expect(g().profitBasis, 4250);
    });

    test('اتكتب → الربح بيتحسب عليه هو', () {
      expect(g(profit: 2125).profitBasis, 2125);
    });

    test('السعر الخام مابيتغيّرش لما نكتب أساس الربح', () {
      final line = g(profit: 2125);
      expect(line.fixedBillAmount, 4250, reason: 'الخام للفلوس والمديونية');
    });

    test('الربح بيتحسب على أساس الربح مش على الفاتورة الكبيرة', () {
      final db = AppDB()
        ..groups.add(g(profit: 2125))
        ..members.addAll([
          _member(gid: 'g1', price: 1500),
          _member(gid: 'g1', price: 1500),
        ]);
      expect(db.groupProfit('g1'), 3000 - 2125);
    });

    test('تفصيل الربح لازم يطابق البادج', () {
      final db = AppDB()
        ..groups.add(g(profit: 2125))
        ..members.add(_member(gid: 'g1', price: 3000));
      final br = db.groupProfitBreakdown('g1', []);
      expect(br['fixedBill'], 2125, reason: 'التفصيل بيعرض أساس الربح');
      expect(br['rawBill'], 4250, reason: 'والخام جنبه للمقارنة');
      expect(br['net'], db.groupNetProfit('g1', []));
    });

    test('اقتراح ÷ ٢ لخط شهر وشهر بس', () {
      expect(g().suggestedProfitBasis, 2125);
      expect(g(system: 'fixed').suggestedProfitBasis, 4250,
          reason: 'الخط الثابت بينزل كل شهر — مفيش قسمة');
    });

    test('⚠️ الاقتراح مابيتطبّقش لوحده', () {
      // القسمة على ٢ مش قاعدة صحيحة في كل الخطوط، فلازم المستخدم يكتبها.
      expect(g().profitBasis, 4250, reason: 'لسه على الخام لحد ما يكتب');
      expect(g().needsProfitBasis, isTrue, reason: 'بس بننبّهه');
    });

    test('الخط الثابت مايتنبّهش على أساس الربح', () {
      expect(g(system: 'fixed').needsProfitBasis, isFalse);
    });

    test('profitCost بيقع على الفاتورة الفعلية لو مفيش أساس ولا خام', () {
      final line = Group(id: 'g1', phone: '01000000000', actualBillAmount: 900);
      expect(line.profitCost, 900);
    });

    test('⚠️ أساس الربح بينجو من الحفظ والقراءة', () {
      final j = g(profit: 2125).toJson();
      expect(Group.fromJson(j).profitBillAmount, 2125);
    });

    test('خط قديم متسجّل من غير الخانة دي بيقراها null', () {
      final j = g(profit: 2125).toJson()..remove('profitBillAmount');
      final line = Group.fromJson(j);
      expect(line.profitBillAmount, isNull);
      expect(line.profitBasis, 4250, reason: 'بيرجع للخام');
    });
  });
}

// ══════════════════════════════════════════════════════════════
// 📅 حماية الشهور
//
// أرقام المجموعة معناها «آخر فاتورة نزلت». قبل الإصلاح ده، تعديل فاتورة
// شهر ٥ وانت في شهر ٨ كان بيكتب مبلغ شهر ٥ على المجموعة، فتلاقي أرقام
// الشهر الحالي اتغيّرت من غير سبب. التستات دي بتقفل الباب ده.
void _monthGuardTests() {
  CompanyBill b(String id, String month, {String gid = 'g1'}) => CompanyBill(
        id: id,
        groupId: gid,
        month: month,
        fixedAmount: 1000,
        actualAmount: 1000,
        date: '01/08/2026',
      );

  // 🌿 الفاتورة الواحدة اللي بتغطي خط رئيسي + خطوطه المضمومة
  group('🌿 التشجير — إجمالي الفاتورة المجمّعة', () {
    AppDB tree() => AppDB()
      ..groups.addAll([
        Group(id: 'p', phone: '01555055531', fixedBillAmount: 4250),
        Group(
            id: 'c1',
            phone: '01111170851',
            fixedBillAmount: 4250,
            parentGroupId: 'p'),
        Group(
            id: 'c2',
            phone: '01009937666',
            fixedBillAmount: 4250,
            parentGroupId: 'p'),
      ]);

    double combined(AppDB db, String gid) {
      final g = db.groups.firstWhere((x) => x.id == gid);
      return g.fixedBillAmount +
          db.groups
              .where((x) => x.parentGroupId == gid)
              .fold<double>(0, (s, c) => s + c.fixedBillAmount);
    }

    test('الإجمالي = الرئيسي + المضمومين', () {
      expect(combined(tree(), 'p'), 12750);
    });

    test('⚠️ خط من غير مضمومين إجماليه هو نفسه', () {
      final db = AppDB()
        ..groups.add(Group(id: 'p', phone: '01000000000', fixedBillAmount: 2150));
      expect(combined(db, 'p'), 2150);
    });

    test('الخط المضموم مايحسبش المضمومين بتوع غيره', () {
      expect(combined(tree(), 'c1'), 4250);
    });
  });

  group('📅 حماية الشهور', () {
    test('أول فاتورة للخط تعتبر الأحدث', () {
      final db = AppDB();
      expect(db.monthIsLatestFor('g1', '2026-08'), isTrue);
      expect(db.latestBillMonth('g1'), isNull);
    });

    test('فاتورة شهر قديم مش الأحدث', () {
      final db = AppDB()..companyBills.addAll([b('b1', '2026-05'), b('b2', '2026-08')]);
      expect(db.isLatestBill(db.companyBills[0]), isFalse, reason: 'شهر ٥ ورا شهر ٨');
      expect(db.isLatestBill(db.companyBills[1]), isTrue);
    });

    test('⚠️ الفاتورة ما تقارنش نفسها بنفسها', () {
      // من غير exceptId كانت كل فاتورة تطلع «الأحدث» لأنها موجودة في اللستة.
      final db = AppDB()..companyBills.addAll([b('b1', '2026-05'), b('b2', '2026-08')]);
      expect(db.latestBillMonth('g1', exceptId: 'b2'), '2026-05');
    });

    test('فاتورة الخط ما تتأثرش بفواتير خط تاني', () {
      final db = AppDB()
        ..companyBills.addAll([b('b1', '2026-05'), b('b2', '2026-12', gid: 'g2')]);
      expect(db.isLatestBill(db.companyBills[0]), isTrue, reason: 'g2 مالهاش دعوة بـ g1');
    });

    test('فاتورة تانية لنفس الشهر تفضل الأحدث', () {
      // بيحصل لما تسجّل فاتورة تصحيحية في نفس الشهر — المفروض تتحدّث عادي.
      final db = AppDB()..companyBills.add(b('b1', '2026-08'));
      expect(db.monthIsLatestFor('g1', '2026-08'), isTrue);
    });

    test('ترتيب السنين بيتقارن صح مش أبجدي غلط', () {
      final db = AppDB()..companyBills.add(b('b1', '2026-01'));
      expect(db.monthIsLatestFor('g1', '2025-12'), isFalse, reason: '١٢/٢٠٢٥ قبل ١/٢٠٢٦');
    });
  });
}

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
