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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:telecom_app/models/models.dart';
import 'package:telecom_app/services/app_search.dart'
    show extractPhones, phoneKey;

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
  _billCycleTests();
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

// ══════════════════════════════════════════════════════════════════
// 🔁 دورة «شهر وشهر» بالمرساة
//
// المرساة = الشهر اللي انت مثبّت إن فاتورة نزلت فيه. منها البرنامج
// بيعرف أي شهر — ماضي أو مستقبل — الخط ده دوره ولا لأ: فرق زوجي عن
// المرساة = دوره، فردي = ببلاش. علامة واحدة تكفي للأبد.
// ══════════════════════════════════════════════════════════════════
void _billCycleTests() {
  /// خط «شهر وشهر» بسعره ومرساته.
  Group bi(String id, double amount, {String? anchor}) => Group(
        id: id,
        phone: '0100000$id',
        fixedBillAmount: amount,
        billingSystem: 'bimonthly',
        billAnchorMonth: anchor,
      );

  /// فاتورة الحساب المتوقعة = مجموع الخطوط اللي دورها الشهر ده بس.
  /// نفس اللي `AppProvider.expectedAccountAmount` بيعمله.
  double expected(List<Group> lines, String month) => lines
      .where((g) => g.isDueIn(month) == true)
      .fold<double>(0, (s, g) => s + g.fixedBillAmount);

  group('🔁 دورة شهر وشهر — المرساة', () {
    test('شهر المرساة نفسه = دوره', () {
      expect(bi('a', 4250, anchor: '2026-07').isDueIn('2026-07'), isTrue);
    });

    test('الشهر اللي بعد المرساة = ببلاش', () {
      expect(bi('a', 4250, anchor: '2026-07').isDueIn('2026-08'), isFalse);
    });

    test('بعدها بشهرين = تنزل تاني', () {
      expect(bi('a', 4250, anchor: '2026-07').isDueIn('2026-09'), isTrue);
    });

    test('بتحسب ورا كمان مش قدّام بس', () {
      final g = bi('a', 4250, anchor: '2026-07');
      expect(g.isDueIn('2026-06'), isFalse, reason: 'فرق ١ = ببلاش');
      expect(g.isDueIn('2026-05'), isTrue, reason: 'فرق ٢ = نزلت');
    });

    test('⚠️ بتعدّي رأس السنة صح', () {
      final g = bi('a', 4250, anchor: '2026-12');
      expect(g.isDueIn('2027-01'), isFalse, reason: 'ديسمبر → يناير = شهر واحد');
      expect(g.isDueIn('2027-02'), isTrue);
    });

    test('الخط الثابت دايماً دوره — مالوش دورة أصلاً', () {
      final g = Group(id: 'f', phone: '01000000000', fixedBillAmount: 1150);
      expect(g.isDueIn('2026-08'), isTrue);
      expect(g.isDueIn('2026-09'), isTrue);
    });

    test('⚠️ خط شهر وشهر من غير مرساة = «مش عارفين» مش «ببلاش»', () {
      // null معناها ارجع للاستنتاج القديم — عشان الخطوط القديمة
      // مايتغيّرش سلوكها لوحدها قبل ما تعلّم عليها.
      expect(bi('a', 4250).isDueIn('2026-08'), isNull);
    });
  });

  group('⚠️ التوقّع لازم يتحسب بطريقة واحدة في كل مكان', () {
    // الباج اللي اتصلّح: كان في دالة صح بتجمع «اللي دورهم بس»، و٥ أماكن
    // تانية لسه بتجمع **كل** خطوط الحساب. النتيجة إن الكارت يقول ٣٠٠٠
    // والتقديرية تسجّل ٥٠٠٠ والملخص يقول ٥٠٠٠ — تلات أرقام لنفس الشهر.
    //
    // التستات دي بتقفل الفرق ده: أي كود جديد بيجمع كل الخطوط من غير ما
    // يبص على الدور هيفشل هنا.

    /// حساب فيه ٣ خطوط: ٢٠٠٠ دوره يوليو، و٢٠٠٠ + ١٠٠٠ دورهم أغسطس.
    List<Group> account() => [
          Group(
              id: 'head',
              phone: '01000000001',
              fixedBillAmount: 2000,
              billingSystem: 'bimonthly',
              billAnchorMonth: '2026-07'),
          Group(
              id: 'k1',
              phone: '01000000002',
              fixedBillAmount: 2000,
              billingSystem: 'bimonthly',
              billAnchorMonth: '2026-08',
              parentGroupId: 'head'),
          Group(
              id: 'k2',
              phone: '01000000003',
              fixedBillAmount: 1000,
              billingSystem: 'bimonthly',
              billAnchorMonth: '2026-08',
              parentGroupId: 'head'),
        ];

    /// اللي **دورهم** بس — زي `AppProvider.expectedAccountAmount`.
    double dueTotal(List<Group> lines, String month) => lines
        .where((g) => g.isDueIn(month) == true)
        .fold<double>(0, (s, g) => s + g.fixedBillAmount);

    /// الجمع القديم الغلط — كل الخطوط مهما كان دورهم.
    double allTotal(List<Group> lines) =>
        lines.fold<double>(0, (s, g) => s + g.fixedBillAmount);

    test('⚠️ الجمع القديم بيدّي رقم أعلى من الحقيقة', () {
      // ده التوثيق للباج نفسه: لو الرقمين اتساووا يبقى التست مش بيختبر حاجة.
      expect(allTotal(account()), 5000);
      expect(dueTotal(account(), '2026-08'), 3000);
      expect(allTotal(account()) == dueTotal(account(), '2026-08'), isFalse,
          reason: 'لازم يفضلوا مختلفين وإلا التست مالوش معنى');
    });

    test('أغسطس = ٣٠٠٠ (الخط اللي نزل في يوليو مش دوره)', () {
      expect(dueTotal(account(), '2026-08'), 3000);
    });

    test('سبتمبر = ٢٠٠٠ (العكس)', () {
      expect(dueTotal(account(), '2026-09'), 2000);
    });

    test('⚠️ شهر محدّش دوره فيه = صفر مش المجموع الكامل', () {
      final lines = [
        Group(
            id: 'a',
            phone: '01000000001',
            fixedBillAmount: 4250,
            billingSystem: 'bimonthly',
            billAnchorMonth: '2026-08'),
      ];
      expect(dueTotal(lines, '2026-09'), 0,
          reason: 'ما ينفعش نسجّل تقديرية في شهر مفيش فيه فاتورة');
    });

    test('حد تحذير «المبلغ أعلى من المتفق» يتحسب على الدور', () {
      // الحد ١٫١٥ × المتوقع. على ٣٠٠٠ الحد ٣٤٥٠، وعلى ٥٠٠٠ يبقى ٥٧٥٠ —
      // يعني فاتورة ٤٥٠٠ غلط كانت هتعدّي من غير تحذير خالص.
      final expected = dueTotal(account(), '2026-08');
      expect(4500 > expected * 1.15, isTrue, reason: 'المفروض تضرب تحذير');
      expect(4500 > allTotal(account()) * 1.15, isFalse,
          reason: 'بالجمع القديم كانت هتعدّي بالسلامة');
    });

    test('الخط الثابت جوّه الحساب بيتحسب كل شهر', () {
      final lines = [
        ...account(),
        Group(id: 'f', phone: '01000000004', fixedBillAmount: 1150),
      ];
      expect(dueTotal(lines, '2026-08'), 4150);
      expect(dueTotal(lines, '2026-09'), 3150);
    });
  });

  group('💰 تعديل السعر — الربح يتحرك امتى ويثبت امتى', () {
    // الباج اللي اتصلّح: خانة المبلغ الجديدة كانت بتثبّت أساس الربح لأي
    // خط. للخط «شهر وشهر» ده صح (بيحمي الربح وقت تصليح الرقم المنصّف)،
    // لكن للخط **الثابت** ده كان بيجمّد ربحه على السعر القديم للأبد.

    test('الثابت: تعديل السعر لازم يحرّك الربح', () {
      final g = Group(id: 'f', phone: '01000000000', fixedBillAmount: 1150);
      expect(g.profitBasis, 1150);
      // التعديل الصح: الخام بس، من غير تثبيت
      g.fixedBillAmount = 1250;
      expect(g.profitBasis, 1250, reason: 'الربح لازم يمشي مع السعر الجديد');
    });

    test('⚠️ لو ثبّتنا الثابت بالغلط الربح بيتجمّد', () {
      // ده اللي كان بيحصل — التست موجود عشان لو حد رجّع السلوك يفشل.
      final g = Group(id: 'f', phone: '01000000000', fixedBillAmount: 1150)
        ..profitBillAmount = 1150
        ..fixedBillAmount = 1250;
      expect(g.profitBasis, 1150, reason: 'اتجمّد على القديم — ده الغلط');
    });

    test('شهر وشهر: التثبيت مطلوب عشان الربح ما يتضاعفش', () {
      final g = Group(
          id: 'b',
          phone: '01000000000',
          fixedBillAmount: 2250,
          billingSystem: 'bimonthly');
      expect(g.profitBasis, 2250);
      g
        ..profitBillAmount = 2250
        ..fixedBillAmount = 4250;
      expect(g.profitBasis, 2250, reason: 'الربح زي ما هو — ده المطلوب هنا');
    });
  });

  group('🛡 كشف الفواتير في شهرين ورا بعض', () {
    // الغلط اللي بتخاف منه: الشركة تنزّل فاتورتين ورا بعض على خط شهر وشهر.
    // البرنامج بيمسكها من تاريخ الفواتير المسجّل من غير ما تدوّر انت.

    /// نفس شرط `AppProvider.consecutiveBillMonths`.
    List<String> bad(Group g, List<String> billedMonths) {
      if (!g.isBimonthly) return const [];
      final months = billedMonths.toSet().toList()..sort();
      final out = <String>[];
      for (var i = 1; i < months.length; i++) {
        if (g.isOverriddenIn(months[i])) continue;
        if (Group.monthsBetween(months[i - 1], months[i]) == 1) {
          out.add(months[i]);
        }
      }
      return out;
    }

    Group bi() => Group(
        id: 'g',
        phone: '01000000000',
        fixedBillAmount: 4250,
        billingSystem: 'bimonthly',
        billAnchorMonth: '2026-07');

    test('شهرين ورا بعض = إنذار', () {
      expect(bad(bi(), ['2026-07', '2026-08']), ['2026-08']);
    });

    test('شهر وشهر بالتبادل = مفيش إنذار', () {
      expect(bad(bi(), ['2026-07', '2026-09', '2026-11']), isEmpty);
    });

    test('⚠️ الشهر اللي علّمته استثناء مايضربش إنذار', () {
      // انت عارف إن الشركة غلطت وعلّمت الشهر ده — مالوش لازمة تفكّرك بيه.
      final g = bi()..billMonthOverrides['2026-08'] = 'billed';
      expect(bad(g, ['2026-07', '2026-08']), isEmpty);
    });

    test('الخط الثابت مالوش إنذار — بينزل كل شهر أصلاً', () {
      final g = Group(id: 'f', phone: '01000000000', fixedBillAmount: 1150);
      expect(bad(g, ['2026-07', '2026-08', '2026-09']), isEmpty);
    });

    test('⚠️ بيعدّي رأس السنة صح', () {
      expect(bad(bi(), ['2026-12', '2027-01']), ['2027-01']);
      expect(bad(bi(), ['2026-12', '2027-02']), isEmpty);
    });

    test('تلات شهور ورا بعض = إنذارين', () {
      expect(bad(bi(), ['2026-06', '2026-07', '2026-08']).length, 2);
    });
  });

  group('🔙 التراجع عن التصليح الجماعي', () {
    // التصليح الجماعي بيلمس عشرات الخطوط. التراجع لازم يرجّع **الرقمين**
    // (الخام وأساس الربح) بالظبط، مش الخام بس — وإلا الربح يفضل متجمّد.

    test('التراجع بيرجّع الخام وأساس الربح مع بعض', () {
      final g = Group(
          id: 'g',
          phone: '01000000000',
          type: '3800',
          fixedBillAmount: 2250,
          billingSystem: 'bimonthly');
      // صورة قبل التصليح
      final rawBefore = g.fixedBillAmount;
      final profitBefore = g.profitBillAmount;
      // التصليح
      g
        ..profitBillAmount = rawBefore
        ..fixedBillAmount = 4250;
      expect(g.fixedBillAmount, 4250);
      expect(g.profitBillAmount, 2250);
      // التراجع
      g
        ..fixedBillAmount = rawBefore
        ..profitBillAmount = profitBefore;
      expect(g.fixedBillAmount, 2250);
      expect(g.profitBillAmount, isNull, reason: 'رجع فاضي زي ما كان');
      expect(g.profitBasis, 2250, reason: 'الربح زي ما كان بالظبط');
    });
  });

  group('🌿 قواعد ضم الخطوط في حساب واحد', () {
    // الحساب مستوى واحد بس: خط رئيسي + خطوط مضمومة عليه. من غير القواعد
    // دي ممكن يحصل خط في حسابين، أو شجرة على تلات مستويات، وساعتها مجموع
    // الفاتورة يطلع ناقص أو مكرّر.
    List<Group> tree() => [
          Group(id: 'head', phone: '01000000001', fixedBillAmount: 4250),
          Group(id: 'kid', phone: '01000000002', fixedBillAmount: 2150,
              parentGroupId: 'head'),
          Group(id: 'free', phone: '01000000003', fixedBillAmount: 2150),
          Group(id: 'other', phone: '01000000004', fixedBillAmount: 4250),
          Group(id: 'otherKid', phone: '01000000005', fixedBillAmount: 2150,
              parentGroupId: 'other'),
        ];

    /// نفس شرط `AppProvider.linkCandidatesFor` بالظبط.
    List<Group> candidates(List<Group> gs, String head) => gs.where((g) {
          if (g.id == head) return false;
          final pid = g.parentGroupId;
          if (pid != null && pid.isNotEmpty && pid != head) return false;
          if (gs.any((x) => x.parentGroupId == g.id)) return false;
          return true;
        }).toList();

    test('الخط الحر ينفع يتضم', () {
      expect(candidates(tree(), 'head').map((g) => g.id), contains('free'));
    });

    test('الخط المضموم على الحساب ده بيفضل ظاهر (عشان تشيله)', () {
      expect(candidates(tree(), 'head').map((g) => g.id), contains('kid'));
    });

    test('⚠️ خط مضموم على حساب تاني مايظهرش — مايبقاش في حسابين', () {
      expect(candidates(tree(), 'head').map((g) => g.id),
          isNot(contains('otherKid')));
    });

    test('⚠️ خط ضامّ خطوط تحته مايظهرش — مفيش تلات مستويات', () {
      expect(candidates(tree(), 'head').map((g) => g.id),
          isNot(contains('other')));
    });

    test('⚠️ الخط مايضمّش نفسه', () {
      expect(candidates(tree(), 'head').map((g) => g.id),
          isNot(contains('head')));
    });
  });

  group('🔧 تصليح الرقم المنصّف — الربح مايتحركش', () {
    // قبل ما «السعر الخام» و«أساس الربح» ينفصلوا كان في حقل واحد،
    // والناس كتبت فيه **نص** الفاتورة عشان الربح يطلع صح. التصليح بيرجّع
    // الخام لسعر الباقة وبيحط الرقم القديم في أساس الربح — والربح لازم
    // يفضل هو هو بالمليم، وإلا يبقى التصليح بوّظ حسابات قديمة.

    /// الخط زي ما هو قبل التصليح: الخام فيه النص وأساس الربح فاضي.
    Group before() => Group(
          id: 'g',
          phone: '01287240240',
          type: '3800', // باقة ٤٢٥٠
          fixedBillAmount: 2250, // النص، قاعد في خانة الخام بالغلط
          billingSystem: 'bimonthly',
          billAnchorMonth: '2026-07',
        );

    /// نفس الخط بعد التصليح.
    Group after() => before()
      ..profitBillAmount = 2250
      ..fixedBillAmount = 4250;

    test('⚠️ الربح قبل وبعد التصليح واحد بالظبط', () {
      expect(before().profitBasis, 2250);
      expect(after().profitBasis, 2250, reason: 'ده شرط التصليح كله');
    });

    test('التوقّع بيتصلّح — من النص للفاتورة الكاملة', () {
      expect(before().fixedBillAmount, 2250);
      expect(after().fixedBillAmount, 4250);
    });

    test('الدورة ما بتتلمسش', () {
      expect(after().isDueIn('2026-07'), isTrue);
      expect(after().isDueIn('2026-08'), isFalse);
      expect(after().billAnchorMonth, '2026-07');
    });

    test('بعد التصليح مابقاش محتاج أساس ربح', () {
      expect(before().needsProfitBasis, isTrue);
      expect(after().needsProfitBasis, isFalse);
    });

    test('⚠️ خط الخام فيه الرقم الصح مايتلمسش', () {
      // ٤٢٥٠ في خانة الخام = مظبوط، مايتحسبش منصّف.
      final ok = before()..fixedBillAmount = 4250;
      expect(ok.fixedBillAmount >= 4250 * 0.75, isTrue,
          reason: 'مش تحت حد الشك، فمالوش تصليح');
    });
  });

  group('🔁 الدورة من تاريخ المجموعة', () {
    // «تاريخ آخر فاتورة نزلت» في تعديل المجموعة بيشتغل مرساة لوحده،
    // فاللي بتظبطه هناك يوصل لقايمة الفواتير من غير ما تعلّمه مرتين.
    Group withDate(String? d) => Group(
          id: 'g',
          phone: '01287240240',
          fixedBillAmount: 4250,
          billingSystem: 'bimonthly',
          lastBillDate: d,
        );

    test('تاريخ المجموعة بيشتغل مرساة لو مفيش تعليم', () {
      final g = withDate('2026-07');
      expect(g.isDueIn('2026-07'), isTrue);
      expect(g.isDueIn('2026-08'), isFalse);
      expect(g.isDueIn('2026-09'), isTrue);
    });

    test('بيقبل الشهر من غير صفر ومن تاريخ كامل', () {
      expect(Group.monthOf('2026-7'), '2026-07');
      expect(Group.monthOf('2026-07'), '2026-07');
      expect(Group.monthOf('2026-07-01'), '2026-07');
    });

    test('⚠️ تاريخ مش مفهوم مابيبوّظش حاجة', () {
      expect(Group.monthOf('كلام'), isNull);
      expect(Group.monthOf('2026-13'), isNull, reason: 'مفيش شهر ١٣');
      expect(Group.monthOf(null), isNull);
      expect(withDate('كلام').isDueIn('2026-08'), isNull);
    });

    test('التعليم بإيدك بيغلب تاريخ المجموعة', () {
      final g = withDate('2026-07')..billAnchorMonth = '2026-08';
      expect(g.isDueIn('2026-08'), isTrue, reason: 'التعليم هو اللي يمشي');
      expect(g.anchorFromGroupDate, isFalse);
    });

    test('من غير تعليم بيقول إن الدورة جت من المجموعة', () {
      expect(withDate('2026-07').anchorFromGroupDate, isTrue);
      expect(withDate(null).anchorFromGroupDate, isFalse);
    });
  });

  group('🔁 دورات أطول من شهرين', () {
    // في خطوط دورتها ٣ شهور أو ٤ حسب عرض الشركة. نفس المرساة بتشتغل
    // معاهم — بنقسم على طول الدورة بدل ما نسأل «زوجي ولا فردي».

    Group every(int n, {String anchor = '2026-07'}) => Group(
          id: 'g',
          phone: '01000000000',
          fixedBillAmount: 4250,
          billingSystem: 'bimonthly',
          billAnchorMonth: anchor,
          billCycleMonths: n,
        );

    test('كل ٣ شهور: يوليو ✓ • أغسطس ✗ • سبتمبر ✗ • أكتوبر ✓', () {
      final g = every(3);
      expect(g.isDueIn('2026-07'), isTrue);
      expect(g.isDueIn('2026-08'), isFalse);
      expect(g.isDueIn('2026-09'), isFalse);
      expect(g.isDueIn('2026-10'), isTrue);
    });

    test('كل ٤ شهور', () {
      final g = every(4);
      expect(g.isDueIn('2026-07'), isTrue);
      expect(g.isDueIn('2026-10'), isFalse);
      expect(g.isDueIn('2026-11'), isTrue);
    });

    test('⚠️ الحساب بيمشي ورا كمان مش قدّام بس', () {
      // ده اللي بيكسر لو حد استخدم `%` من غير تصحيح السالب: شهر قبل
      // المرساة بيدّي باقي بالسالب والمقارنة بصفر بتفشل.
      final g = every(3);
      expect(g.isDueIn('2026-04'), isTrue, reason: 'قبلها بـ٣ شهور');
      expect(g.isDueIn('2026-05'), isFalse);
      expect(g.isDueIn('2026-06'), isFalse);
    });

    test('الافتراضي لسه ٢ — الخطوط القديمة ما تتغيّرش', () {
      final g = Group(
          id: 'g',
          phone: '01000000000',
          fixedBillAmount: 4250,
          billingSystem: 'bimonthly',
          billAnchorMonth: '2026-07');
      expect(g.billCycleMonths, 2);
      expect(g.isDueIn('2026-09'), isTrue);
    });

    test('⚠️ الخط الثابت بينزل كل شهر مهما كان طول الدورة', () {
      final g = Group(
          id: 'f',
          phone: '01000000000',
          fixedBillAmount: 1150,
          billCycleMonths: 3);
      expect(g.isDueIn('2026-08'), isTrue);
      expect(g.isDueIn('2026-09'), isTrue);
    });
  });

  group('🧾 عدّاد الفواتير الناقصة (التذكير الأسبوعي)', () {
    Group due(String id, {String anchor = '2026-08', double amt = 1000}) =>
        Group(
          id: id,
          phone: '0100$id',
          billingSystem: 'bimonthly',
          billAnchorMonth: anchor,
          fixedBillAmount: amt,
        );

    test('الخط اللي دوره وما اتسجّلش بيتحسب', () {
      final db = AppDB(
          groups: [due('a'), due('b')], members: [], companyBills: []);
      expect(db.missingBillsCount('2026-08'), 2);
    });

    test('⚠️ الخط اللي مش دوره مابيتحسبش ناقص', () {
      // ده أهم اختبار هنا: لو حسبناه، التذكير هيقول «ناقص» كل أسبوع
      // وانت مظبوط — فتتعوّد تتجاهله ويضيع النقص الحقيقي.
      final db = AppDB(
          groups: [due('a')], members: [], companyBills: []);
      expect(db.missingBillsCount('2026-09'), 0, reason: 'شهر ببلاش');
    });

    test('اللي اتسجّل مابيتحسبش', () {
      final db = AppDB(
        groups: [due('a'), due('b')],
        members: [],
        companyBills: [
          CompanyBill(
              id: '1',
              groupId: 'a',
              month: '2026-08',
              date: '1/8/2026',
              actualAmount: 1000),
        ],
      );
      expect(db.missingBillsCount('2026-08'), 1);
    });

    test('⚠️ الخط المقفول مابيتحسبش', () {
      final db = AppDB(
        groups: [due('a')..billEndMonth = '2026-06'],
        members: [],
        companyBills: [],
      );
      expect(db.missingBillsCount('2026-08'), 0);
    });

    test('الخط من غير سعر مابيتحسبش — لسه ما اتظبطش', () {
      final db = AppDB(
          groups: [due('a', amt: 0)], members: [], companyBills: []);
      expect(db.missingBillsCount('2026-08'), 0);
    });

    test('الخط المضموم على حساب تاني مابيتحسبش لوحده', () {
      final db = AppDB(
        groups: [due('a'), due('b')..parentGroupId = 'a'],
        members: [],
        companyBills: [],
      );
      expect(db.missingBillsCount('2026-08'), 1);
    });
  });

  group('📊 كشف حساب الشركة', () {
    CompanyBill b(String id, String gid, String month,
            {double fixed = 1000, double actual = 1000, double disp = 0}) =>
        CompanyBill(
          id: id,
          groupId: gid,
          month: month,
          date: '1/1/2026',
          fixedAmount: fixed,
          actualAmount: actual,
          disputeAmount: disp,
        );

    AppDB dbOf(List<CompanyBill> bills) => AppDB(
          groups: [
            Group(id: 'a', phone: '0100', provider: 'vodafone'),
            Group(id: 'c', phone: '0102', provider: 'we'),
          ],
          members: [],
          companyBills: bills,
        );

    test('الشهور بتتجمّع والفرق بيتحسب', () {
      final rows = dbOf([
        b('1', 'a', '2026-08', fixed: 1000, actual: 1300),
        b('2', 'a', '2026-08', fixed: 500, actual: 500),
        b('3', 'a', '2026-07', fixed: 1000, actual: 900),
      ]).companyStatement('vodafone');
      expect(rows.length, 2);
      expect(rows.first.month, '2026-08', reason: 'الأحدث الأول');
      expect(rows.first.expected, 1500);
      expect(rows.first.actual, 1800);
      expect(rows.first.diff, 300);
      expect(rows.first.bills, 2);
      expect(rows.last.diff, -100, reason: 'نزلت أقل من المتوقع');
    });

    test('⚠️ فواتير شركة تانية مابتدخلش في كشفها', () {
      final rows = dbOf([
        b('1', 'a', '2026-08', fixed: 1000, actual: 1000),
        b('2', 'c', '2026-08', fixed: 9999, actual: 9999),
      ]).companyStatement('vodafone');
      expect(rows.single.expected, 1000);
    });

    test('null = كل الشركات مع بعض', () {
      final rows = dbOf([
        b('1', 'a', '2026-08', fixed: 1000, actual: 1000),
        b('2', 'c', '2026-08', fixed: 500, actual: 500),
      ]).companyStatement(null);
      expect(rows.single.expected, 1500);
    });

    test('شركة مالهاش خطوط = كشف فاضي مش خطأ', () {
      expect(dbOf([b('1', 'a', '2026-08')]).companyStatement('orange'), isEmpty);
    });

    test('الشركات النشطة مرتّبة ومن غير تكرار', () {
      expect(dbOf([]).activeProviders, ['vodafone', 'we']);
    });
  });

  group('⚖️ الاعتراضات لكل شركة', () {
    AppDB dbOf(List<CompanyBill> bills) => AppDB(
          groups: [
            Group(id: 'a', phone: '0100', provider: 'vodafone'),
            Group(id: 'b', phone: '0101', provider: 'vodafone'),
            Group(id: 'c', phone: '0102', provider: 'we'),
            Group(id: 'd', phone: '0103'), // من غير شركة
          ],
          members: [],
          companyBills: bills,
        );

    CompanyBill bill(String id, String gid, double d, {bool done = false}) =>
        CompanyBill(
          id: id,
          groupId: gid,
          month: '2026-08',
          date: '1/8/2026',
          actualAmount: 0,
          disputeAmount: d,
          disputeResolved: done,
        );

    test('بتتجمّع لكل شركة ومرتّبة بالأكبر', () {
      final rows = dbOf([
        bill('1', 'a', 300),
        bill('2', 'b', 200),
        bill('3', 'c', 1000),
      ]).disputesByProvider();
      expect(rows.first.provider, 'we', reason: 'الأكبر الأول');
      expect(rows.first.open, 1000);
      final voda = rows.firstWhere((r) => r.provider == 'vodafone');
      expect(voda.open, 500, reason: '300 + 200');
      expect(voda.count, 2);
    });

    test('⚠️ اللي اتحلّ مابيتحسبش في المفتوح', () {
      final rows = dbOf([
        bill('1', 'a', 300),
        bill('2', 'b', 200, done: true),
      ]).disputesByProvider();
      expect(rows.first.open, 300);
      expect(rows.first.resolved, 200);
      expect(rows.first.count, 1, reason: 'العدد للمفتوح بس');
    });

    test('خط من غير شركة بيتحط تحت «غير محدد» مش بيضيع', () {
      final rows = dbOf([bill('1', 'd', 400)]).disputesByProvider();
      expect(rows.single.provider, 'غير محدد');
      expect(rows.single.open, 400);
    });

    test('الإجمالي = المفتوح بس', () {
      final db = dbOf([
        bill('1', 'a', 300),
        bill('2', 'c', 500, done: true),
      ]);
      expect(db.openDisputesTotal, 300);
    });

    test('مفيش اعتراضات = لستة فاضية', () {
      expect(dbOf([bill('1', 'a', 0)]).disputesByProvider(), isEmpty);
      expect(dbOf([]).openDisputesTotal, 0);
    });
  });

  group('📋 نسخ الدورة من خط لخط', () {
    Group line(String id, {String? anchor, int cycle = 2}) => Group(
          id: id,
          phone: '0100000000$id',
          billingSystem: 'bimonthly',
          billAnchorMonth: anchor,
          billCycleMonths: cycle,
        );

    test('العلامة وطول الدورة بيتنسخوا', () {
      final p = AppDB(companyBills: [], members: [], groups: [
        line('a', anchor: '2026-07', cycle: 3),
        line('b'),
        line('c'),
      ]);
      expect(p.copyCycle('a', ['b', 'c']), 2);
      final b = p.groups.firstWhere((g) => g.id == 'b');
      expect(b.billAnchorMonth, '2026-07');
      expect(b.billCycleMonths, 3);
    });

    test('⚠️ الاستثناءات مابتتنسخش — غلطة الشركة خاصة بخط واحد', () {
      final src = line("a", anchor: "2026-07")
        ..billMonthOverrides['2026-08'] = 'billed';
      final p = AppDB(companyBills: [], members: [], groups: [src, line('b')]);
      p.copyCycle('a', ['b']);
      expect(p.groups.firstWhere((g) => g.id == 'b').billMonthOverrides,
          isEmpty, reason: 'ما ينفعش نخترع غلطة ماحصلتش');
    });

    test('اللي زي بعضه مابيتحسبش', () {
      final p = AppDB(companyBills: [], members: [], groups: [line('a', anchor: '2026-07'), line('b', anchor: '2026-07')]);
      expect(p.copyCycle('a', ['b']), 0);
    });

    test('⚠️ خط من غير علامة مابينسخش حاجة', () {
      final p = AppDB(companyBills: [], members: [], groups: [line('a'), line('b', anchor: '2026-07')]);
      expect(p.copyCycle('a', ['b']), 0);
      expect(p.groups.firstWhere((g) => g.id == 'b').billAnchorMonth,
          '2026-07', reason: 'الخط السليم مابيتمسحش');
    });

    test('الخط المصدر مابينسخش على نفسه', () {
      final p = AppDB(companyBills: [], members: [], groups: [line('a', anchor: '2026-07')]);
      expect(p.copyCycle('a', ['a']), 0);
    });
  });

  group('🎫 القسايم والربح الحقيقي', () {
    test('القسيمة بتتوزّع على شهور المدة مش على شهر واحد', () {
      final g = Group(id: 'g', phone: '01000000000', voucherValue: 600);
      expect(g.voucherMonthlyValue, 100, reason: '600 على 6 شهور');
      g.voucherPeriod = '1y';
      expect(g.voucherMonthlyValue, 50, reason: '600 على 12 شهر');
    });

    test('مفيش قسيمة = صفر', () {
      expect(Group(id: 'g', phone: '01000000000').voucherMonthlyValue, 0);
    });

    test('⚠️ الربح الأساسي مابيتغيّرش — الحقيقي رقم زيادة', () {
      // ده الأهم: لو القسيمة اتحطت جوّه الربح الأساسي، كل رقم في كل شاشة
      // كان هيتحرّك من غير سبب ظاهر.
      final g = Group(
          id: 'g',
          phone: '01000000000',
          fixedBillAmount: 1150,
          voucherValue: 600);
      final db = AppDB(
        groups: [g],
        members: [
          Member(id: 'm', gid: 'g', name: 'ع', phone: '0111', price: 1500)
        ],
        companyBills: [],
      );
      expect(db.profitForecast('2026-08', []), 350, reason: 'من غير قسيمة');
      expect(db.realProfitForecast('2026-08', []), 450, reason: '+100 قسيمة');
      expect(db.voucherMonthlyTotal('2026-08'), 100);
    });
  });

  group('👥 تكلفة الخط لكل عميل', () {
    AppDB dbOf(List<Member> ms, {double basis = 2000}) => AppDB(
          groups: [
            Group(
                id: 'g',
                phone: '01000000000',
                fixedBillAmount: 4000,
                profitBillAmount: basis)
          ],
          members: ms,
          companyBills: [],
        );

    Member m(String id, double price) =>
        Member(id: id, gid: 'g', name: 'ع$id', phone: '0111$id', price: price);

    test('التكلفة بتتقسم على العملاء', () {
      final c = dbOf([m('1', 700), m('2', 700), m('3', 700), m('4', 700)])
          .lineCostPerClient('g');
      expect(c.clients, 4);
      expect(c.costPerClient, 500, reason: '2000 على 4');
      expect(c.avgPrice, 700);
    });

    test('⚠️ خط من غير عملاء: التكلفة كلها عليك', () {
      final c = dbOf([]).lineCostPerClient('g');
      expect(c.clients, 0);
      expect(c.costPerClient, 2000);
      expect(c.avgPrice, 0, reason: 'مفيش قسمة على صفر');
    });

    test('الخط بيخسر لو العميل بيدفع أقل من تكلفته', () {
      final c = dbOf([m('1', 400), m('2', 400)]).lineCostPerClient('g');
      expect(c.costPerClient, 1000);
      expect(c.avgPrice, 400);
      expect(c.avgPrice - c.costPerClient, -600);
    });

    test('خط مش موجود = أصفار مش خطأ', () {
      final c = dbOf([]).lineCostPerClient('مش-موجود');
      expect(c.clients, 0);
      expect(c.costPerClient, 0);
    });
  });

  group('📈 الشركة رفعت السعر؟', () {
    // التنبيه ده لازم يرنّ **بس** لما يبقى رفع سعر حقيقي. لو رنّ على كل
    // غلطة، المستخدم هيتعوّد يتجاهله والتنبيه الحقيقي هيضيع وسطهم.

    Group line() =>
        Group(id: 'g', phone: '01000000000', fixedBillAmount: 4250);

    CompanyBill act(String month, double amount) => CompanyBill(
        id: 'b$month',
        groupId: 'g',
        month: month,
        actualAmount: amount,
        isActual: true,
        date: '01/$month');

    AppDB db(List<CompanyBill> bills) =>
        AppDB(groups: [line()], members: [], companyBills: bills);

    test('فاتورتين ورا بعض أعلى بنفس الرقم = رفع سعر', () {
      final r = db([act('2026-07', 4500), act('2026-08', 4500)])
          .priceIncreaseSuspects();
      expect(r.length, 1);
      expect(r.first.oldPrice, 4250);
      expect(r.first.newPrice, 4500);
    });

    test('⚠️ فاتورة واحدة عالية = مش رفع سعر', () {
      // ممكن تبقى زيادة استهلاك أو غلطة — مايستاهلش تنبيه.
      final r = db([act('2026-07', 4250), act('2026-08', 4900)])
          .priceIncreaseSuspects();
      expect(r, isEmpty);
    });

    test('⚠️ فاتورتين عاليين بأرقام مختلفة خالص = مش رفع سعر', () {
      final r = db([act('2026-07', 4900), act('2026-08', 5600)])
          .priceIncreaseSuspects();
      expect(r, isEmpty);
    });

    test('الفواتير المطابقة للمسجّل مافيهاش تنبيه', () {
      final r = db([act('2026-07', 4250), act('2026-08', 4250)])
          .priceIncreaseSuspects();
      expect(r, isEmpty);
    });

    test('فاتورة واحدة بس مش كفاية للحكم', () {
      expect(db([act('2026-08', 4500)]).priceIncreaseSuspects(), isEmpty);
    });
  });

  group('🧾 المطالبات على الشركة', () {
    CompanyBill withDispute(String id, double amount, {bool resolved = false}) =>
        CompanyBill(
          id: id,
          groupId: 'g',
          month: '2026-08',
          actualAmount: 5300,
          isActual: true,
          date: '01/08/2026',
          disputeAmount: amount,
          disputeResolved: resolved,
        );

    AppDB db(List<CompanyBill> bills) => AppDB(
        groups: [Group(id: 'g', phone: '01000000000', fixedBillAmount: 5000)],
        members: [],
        companyBills: bills);

    test('المجموع = كل المطالبات المفتوحة', () {
      expect(db([withDispute('a', 300), withDispute('b', 200)])
          .totalOpenDisputes, 500);
    });

    test('⚠️ المطالبة اللي اتقفلت ماتتحسبش', () {
      final d = db([withDispute('a', 300), withDispute('b', 200, resolved: true)]);
      expect(d.totalOpenDisputes, 300);
      expect(d.openDisputeCount, 1);
    });

    test('مفيش مطالبات = صفر مش خطأ', () {
      expect(db([]).totalOpenDisputes, 0);
      expect(db([]).disputesByLine(), isEmpty);
    });

    test('التفصيل بيجمّع المطالبات على الخط', () {
      final r = db([withDispute('a', 300), withDispute('b', 200)])
          .disputesByLine();
      expect(r.length, 1);
      expect(r.first.amount, 500);
      expect(r.first.count, 2);
    });
  });

  group('🔮 توقّع الربح', () {
    // الربح بيتحسب على «أساس الربح» (تكلفة الشهر الواحد)، فهو مستوي على
    // طول الشهور. اللي بيغيّره: باقة مؤقتة بتخلص، أو خط بيتقفل.

    AppDB dbWith(Group g, List<Member> ms) => AppDB(
          groups: [g],
          members: ms,
          companyBills: [],
        );

    Member client(String id, double price, String gid) => Member(
        id: id, name: 'ع$id', phone: '0111$id', price: price, gid: gid);

    test('⚠️ دورة «شهر وشهر» ماتخليش الربح يقفز من شهر للتاني', () {
      // ده أهم واحد: الفاتورة بتنزل شهر وشهر لأ، بس التكلفة موزّعة، فالربح
      // لازم يبقى نفس الرقم في الشهرين.
      final g = Group(
        id: 'g',
        phone: '01000000000',
        fixedBillAmount: 4250,
        profitBillAmount: 2125,
        billingSystem: 'bimonthly',
        billAnchorMonth: '2026-07',
      );
      final db = dbWith(g, [client('m1', 3000, 'g')]);
      expect(db.profitForecast('2026-07', []), 875);
      expect(db.profitForecast('2026-08', []), 875, reason: 'شهر الببلاش');
    });

    test('الخط المقفول ربحه صفر بعد شهر القفل', () {
      final g = Group(
        id: 'g',
        phone: '01000000000',
        fixedBillAmount: 1150,
        billEndMonth: '2026-09',
      );
      final db = dbWith(g, [client('m1', 1500, 'g')]);
      expect(db.profitForecast('2026-09', []), 350);
      expect(db.profitForecast('2026-10', []), 0);
    });

    test('سبب الفرق بيتقال بالاسم', () {
      final g = Group(
        id: 'g',
        phone: '01099999999',
        fixedBillAmount: 1150,
        billEndMonth: '2026-09',
      );
      final db = dbWith(g, [client('m1', 1500, 'g')]);
      final r = db.profitForecastReasons('2026-09', '2026-10');
      expect(r.length, 1);
      expect(r.first.reason, contains('01099999999'));
      expect(r.first.delta, -350);
    });

    test('مفيش حاجة بتتغيّر = مفيش أسباب', () {
      final g = Group(id: 'g', phone: '01000000000', fixedBillAmount: 1150);
      final db = dbWith(g, [client('m1', 1500, 'g')]);
      expect(db.profitForecastReasons('2026-09', '2026-10'), isEmpty);
    });

    test('باقة إضافية مؤقتة بتخلص → الربح بيزيد الشهر اللي بعده', () {
      final g = Group(id: 'g', phone: '01000000000', fixedBillAmount: 1150)
        ..extraBundles.add({'month': '2026-09', 'gb': 10, 'cost': 200});
      final db = dbWith(g, [client('m1', 1500, 'g')]);
      expect(db.profitForecast('2026-09', []), 150, reason: '350 ناقص 200');
      expect(db.profitForecast('2026-10', []), 350, reason: 'الباقة خلصت');
      final r = db.profitForecastReasons('2026-09', '2026-10');
      expect(r.first.delta, 200);
    });
  });

  group('📥 قراءة الأرقام من كشف الشركة', () {
    // الاستيراد بيعلّم دورة عشرات الخطوط مرة واحدة، فلو قرا رقم غلط
    // بيبوّظ خط سليم. دي أخطر جزئية فيه.

    test('رقم عادي', () {
      expect(extractPhones('01001234567'), ['01001234567']);
    });

    test('⚠️ رقمين ورا بعض مايتلزقوش في رقم واحد', () {
      // ده اللي بيكسر لو حد شال المسافات من النص قبل ما يدوّر.
      final r = extractPhones('01001234567\n01009876543');
      expect(r.length, 2);
      expect(r, containsAll(['01001234567', '01009876543']));
    });

    test('الكلام اللي حوالين الرقم مش بيأثر', () {
      final r = extractPhones('العميل أحمد 01001234567 المبلغ 4250 جنيه');
      expect(r, ['01001234567']);
    });

    test('⚠️ المبالغ ماتتقراش كأرقام تليفونات', () {
      // ٤٢٥٠ و١١٥٠ أقصر من ١٠ أرقام فمابيتمسكوش.
      expect(extractPhones('4250 1150 2000'), isEmpty);
    });

    test('الأرقام العربية بتتقرا', () {
      expect(extractPhones('٠١٠٠١٢٣٤٥٦٧'), isNotEmpty);
      expect(phoneKey('٠١٠٠١٢٣٤٥٦٧'), phoneKey('01001234567'));
    });

    test('نفس الخط بأشكاله المختلفة = مفتاح واحد', () {
      const k = '001234567';
      expect(phoneKey('01001234567'), k);
      expect(phoneKey('+201001234567'), k);
      expect(phoneKey('00201001234567'), k);
    });

    test('الرقم المكرر في الكشف بيتحسب مرة واحدة', () {
      expect(extractPhones('01001234567 و 01001234567').length, 1);
    });

    test('كلام من غير أرقام = لستة فاضية', () {
      expect(extractPhones('مفيش فواتير الشهر ده'), isEmpty);
      expect(extractPhones(''), isEmpty);
    });

    test('كشف بأعمدة (منسوخ من جدول)', () {
      const sheet = '''
الرقم	المبلغ	الحالة
01001234567	4250	مدفوعة
01009876543	2150	مدفوعة
01551112222	1150	متأخرة''';
      final r = extractPhones(sheet);
      expect(r.length, 3);
    });
  });

  group('🛑 الخط المقفول', () {
    // الخط اللي الشركة قفلته لازم يبطّل يتحسب في التقدير، من غير ما
    // يلمس ولا فاتورة قديمة.

    test('شهر القفل نفسه لسه بتنزل فيه فاتورة', () {
      final g = bi('a', 4250, anchor: '2026-07')..billEndMonth = '2026-09';
      expect(g.isDueIn('2026-09'), isTrue, reason: 'ده آخر شهر نزلت فيه');
    });

    test('اللي بعد شهر القفل ببلاش — حتى لو دوره في الدورة', () {
      final g = bi('a', 4250, anchor: '2026-07')..billEndMonth = '2026-09';
      expect(g.isDueIn('2026-11'), isFalse, reason: 'الدورة كانت هتقول تنزل');
      expect(g.isDueIn('2027-01'), isFalse);
    });

    test('الشهور اللي قبل القفل ماتأثرتش', () {
      final g = bi('a', 4250, anchor: '2026-07')..billEndMonth = '2026-09';
      expect(g.isDueIn('2026-07'), isTrue);
      expect(g.isDueIn('2026-08'), isFalse, reason: 'ببلاش بالدورة مش بالقفل');
      expect(g.isDueIn('2026-05'), isTrue);
    });

    test('الخط الثابت بيتقفل برضه', () {
      final g = Group(id: 'f', phone: '01000000000', fixedBillAmount: 1150)
        ..billEndMonth = '2026-09';
      expect(g.isDueIn('2026-09'), isTrue);
      expect(g.isDueIn('2026-10'), isFalse);
    });

    test('⚠️ فاتورة نزلت غصب عني بعد القفل لازم تبان — مش تتخبّى', () {
      // لو الشركة نزّلت على خط مقفول، ده بالظبط اللي عايز تشوفه.
      final g = bi('a', 4250, anchor: '2026-07')
        ..billEndMonth = '2026-09'
        ..billMonthOverrides['2026-12'] = 'billed';
      expect(g.isDueIn('2026-12'), isTrue);
    });

    test('من غير قفل مفيش حاجة اتغيّرت', () {
      final g = bi('a', 4250, anchor: '2026-07');
      expect(g.billEndMonth, isNull);
      expect(g.isDueIn('2030-01'), isTrue);
    });

    test('القفل بيتحفظ ويترجع من JSON', () {
      final g = bi('a', 4250, anchor: '2026-07')..billEndMonth = '2026-09';
      final back = Group.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect(back.billEndMonth, '2026-09');
      expect(back.isDueIn('2026-11'), isFalse);
    });
  });

  group('🔁 غلطات الشركة — الاستثناء اليدوي', () {
    test('«نزلت غصب» بتغلب المرساة في الشهر ده', () {
      final g = bi('a', 4250, anchor: '2026-07')
        ..billMonthOverrides['2026-08'] = 'billed';
      expect(g.isDueIn('2026-08'), isTrue, reason: 'المرساة كانت هتقول ببلاش');
    });

    test('«ببلاش تعويض» بتغلب المرساة في الشهر ده', () {
      final g = bi('a', 4250, anchor: '2026-07')
        ..billMonthOverrides['2026-09'] = 'free';
      expect(g.isDueIn('2026-09'), isFalse, reason: 'المرساة كانت هتقول تنزل');
    });

    test('⚠️ الاستثناء مابيلخبطش الشهور اللي بعده', () {
      // أهم تست في الجروب ده: الشركة بتغلط شهر، والدورة الأصلية
      // لازم ترجع لوحدها بعده من غير ما تعيد التعليم.
      final g = bi('a', 4250, anchor: '2026-07')
        ..billMonthOverrides['2026-08'] = 'billed';
      expect(g.isDueIn('2026-09'), isTrue, reason: 'الدورة الأصلية زي ما هي');
      expect(g.isDueIn('2026-10'), isFalse);
      expect(g.billAnchorMonth, '2026-07', reason: 'المرساة ما اتغيّرتش');
    });

    test('شيل الاستثناء يرجّع الشهر لدورته', () {
      final g = bi('a', 4250, anchor: '2026-07')
        ..billMonthOverrides['2026-08'] = 'billed';
      g.billMonthOverrides.remove('2026-08');
      expect(g.isDueIn('2026-08'), isFalse);
    });
  });

  group('🔁 فاتورة الحساب — مجموع اللي دورهم بس', () {
    // مثال الحساب اللي فيه ٣ خطوط: ٢٠٠٠ + ٢٠٠٠ + ١٠٠٠.
    // خط الـ٢٠٠٠ الأول نزلت له في يوليو، والتانين في أغسطس.
    List<Group> account() => [
          bi('a', 2000, anchor: '2026-07'),
          bi('b', 2000, anchor: '2026-08'),
          bi('c', 1000, anchor: '2026-08'),
        ];

    test('أغسطس = ٢٠٠٠ + ١٠٠٠ = ٣٠٠٠', () {
      expect(expected(account(), '2026-08'), 3000);
    });

    test('سبتمبر = ٢٠٠٠ (اللي ما نزلش بس)', () {
      expect(expected(account(), '2026-09'), 2000);
    });

    test('أكتوبر بترجع ٣٠٠٠ تاني — الدورة بتتبادل لوحدها', () {
      expect(expected(account(), '2026-10'), 3000);
    });

    test('التلاتة في نفس الدور → شهر كامل وشهر صفر', () {
      final lines = [
        bi('a', 2000, anchor: '2026-08'),
        bi('b', 2000, anchor: '2026-08'),
        bi('c', 1000, anchor: '2026-08'),
      ];
      expect(expected(lines, '2026-08'), 5000);
      expect(expected(lines, '2026-09'), 0, reason: 'مفيش فاتورة خالص');
      expect(expected(lines, '2026-10'), 5000);
    });

    test('⚠️ صفر معناها «مفيش فاتورة» — فلو نزلت يبقى في غلط', () {
      final lines = [bi('a', 4250, anchor: '2026-08')];
      expect(expected(lines, '2026-09'), 0);
    });

    test('الخط الثابت بيتحسب كل شهر جوه الحساب', () {
      final lines = [
        bi('a', 2000, anchor: '2026-08'),
        Group(id: 'f', phone: '01000000000', fixedBillAmount: 1150),
      ];
      expect(expected(lines, '2026-08'), 3150, reason: 'المتغيّر + الثابت');
      expect(expected(lines, '2026-09'), 1150, reason: 'الثابت لوحده');
    });
  });

  group('🧾 المطالبة على الشركة', () {
    CompanyBill withDispute({double amount = 0, bool resolved = false}) =>
        CompanyBill(
          id: 'b1',
          groupId: 'g1',
          month: '2026-08',
          fixedAmount: 5000,
          actualAmount: 5300,
          isActual: true,
          date: '01/08/2026',
          disputeAmount: amount,
          disputeResolved: resolved,
        );

    test('مطالبة مفتوحة لما يبقى فيه مبلغ ومتقفلش', () {
      expect(withDispute(amount: 300).hasOpenDispute, isTrue);
    });

    test('اتقفلت → مابقاش عليها مطالبة', () {
      expect(withDispute(amount: 300, resolved: true).hasOpenDispute, isFalse);
    });

    test('⚠️ مفيش مطالبة افتراضياً — الحقل اختياري', () {
      expect(withDispute().hasOpenDispute, isFalse);
      expect(withDispute().disputeAmount, 0);
    });

    test('⚠️ المطالبة مالهاش دعوة بالمتبقي على الفاتورة', () {
      // الفرق بيتسجّل عندك للمتابعة بس — مابيغيّرش الفلوس المستحقة.
      final b = withDispute(amount: 300);
      expect(b.remaining, 5300, reason: 'المتبقي زي ما هو');
    });
  });
}
