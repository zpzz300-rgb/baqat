// lib/services/demo_data.dart
// 🎭 بيانات ديمو وهمية بالكامل — للعرض والتصوير فقط.
// كل الأسماء والأرقام هنا افتراضية ولا تخص أي شخص حقيقي.
// تشتغل مع build بـ: flutter build apk --dart-define=DEMO=true
import '../models/models.dart';

AppDB buildDemoDb() {
  final now = DateTime.now();
  String iso(int y, int m, int d) =>
      '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  String dmy(int d, int m, int y) => '$d/$m/$y';
  final curMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final lastMonth = now.month == 1
      ? '${now.year - 1}-12'
      : '${now.year}-${(now.month - 1).toString().padLeft(2, '0')}';

  int mid = 0;
  Member m({
    required String gid,
    required String name,
    required String phone,
    int gb = 20,
    double price = 150,
    double balance = 0,
    String type = 'regular',
    String? date,
    String? flag,
    String? gName,
    String? gPhone,
    String? deferral,
    int reminders = 0,
    List<Map<String, dynamic>>? log,
  }) {
    mid++;
    return Member(
      id: 'dm$mid',
      gid: gid,
      name: name,
      phone: phone,
      package: gb > 0 ? '$gb جيجا' : '',
      gb: gb,
      price: price,
      balance: balance,
      type: type,
      date: date ?? iso(2025, (mid % 12) + 1, (mid % 27) + 1),
      paymentFlag: flag,
      guarantorName: gName,
      guarantorPhone: gPhone,
      deferralDate: deferral,
      deferralNote: deferral != null ? 'ظروف سفر' : null,
      reminderLog: [
        for (int i = 0; i < reminders; i++)
          {'ts': now.millisecondsSinceEpoch - i * 86400000, 'ch': 'wa_debt'},
      ],
      log: log ??
          [
            {'date': dmy(1, now.month, now.year), 'desc': '💳 اشتراك شهر ${now.month}', 'amount': -price, 'type': 'bill'},
            {'date': dmy(28, now.month - 1 == 0 ? 12 : now.month - 1, now.year), 'desc': '💰 دفعة', 'amount': price, 'type': 'pay'},
          ],
    );
  }

  final groups = [
    Group(
      id: 'dg1', phone: '01000000011', ownerName: 'محمد عبد السلام',
      provider: 'etisalat', cycle: '1', fixedBillAmount: 2150,
      maxClients: 9, mainLineAllocationGb: 20,
      stickyNote: 'الخط ده عليه عرض لغاية أكتوبر',
      date: iso(2024, 3, 10),
    ),
    Group(
      id: 'dg2', phone: '01100000022', ownerName: 'أحمد سمير',
      provider: 'vodafone', cycle: '1', fixedBillAmount: 1750,
      billingSystem: 'bimonthly', maxClients: 8,
      date: iso(2024, 7, 1),
    ),
    Group(
      id: 'dg3', phone: '01200000033', ownerName: 'خالد فتحي',
      provider: 'orange', cycle: '2', fixedBillAmount: 1400,
      maxClients: 8, date: iso(2025, 1, 15),
    ),
    Group(
      id: 'dg4', phone: '01500000044', ownerName: 'مصطفى كامل',
      provider: 'we', cycle: '1', fixedBillAmount: 1200,
      maxClients: 6, date: iso(2025, 5, 20),
    ),
    Group(
      id: 'dg5', phone: '01000000055', ownerName: 'ياسر النجار',
      provider: 'etisalat', cycle: '2', fixedBillAmount: 2100,
      maxClients: 9, date: iso(2024, 11, 5),
    ),
  ];

  final members = <Member>[
    // ── المجموعة 1 ──
    m(gid: 'dg1', name: 'حسن إبراهيم', phone: '01011111101', gb: 50, price: 300, balance: -600, flag: 'red', gName: 'الحاج سعيد أبو أحمد', gPhone: '01055555501', reminders: 3),
    m(gid: 'dg1', name: 'كريم فوزي', phone: '01011111102', gb: 40, price: 250, balance: 0, flag: 'green'),
    m(gid: 'dg1', name: 'سامي رشاد', phone: '01011111103', gb: 20, price: 150, balance: -150, flag: 'yellow', deferral: iso(now.year, now.month, 25)),
    m(gid: 'dg1', name: 'طارق منير', phone: '01011111104', gb: 20, price: 150, balance: 0),
    m(gid: 'dg1', name: 'شريف عادل', phone: '01011111105', gb: 15, price: 120, balance: -240, gName: 'الحاج سعيد أبو أحمد', gPhone: '01055555501', reminders: 1),
    m(gid: 'dg1', name: 'وليد سعد', phone: '01011111106', gb: 10, price: 100, balance: 0, flag: 'green'),
    m(gid: 'dg1', name: 'خط أرضي — منزل', phone: '0233334444', gb: 0, price: 90, type: 'landline'),
    m(gid: 'dg1', name: 'هوم 4G — مكتب', phone: '01011111108', gb: 0, price: 200, type: 'homeforgee'),
    // ── المجموعة 2 ──
    m(gid: 'dg2', name: 'عمرو حلمي', phone: '01122222201', gb: 50, price: 290, balance: -290, flag: 'yellow', gName: 'شركة النور للتوريدات', gPhone: '01199999902', reminders: 2),
    m(gid: 'dg2', name: 'مينا نبيل', phone: '01122222202', gb: 40, price: 240, balance: 0, flag: 'green'),
    m(gid: 'dg2', name: 'إسلام قدري', phone: '01122222203', gb: 20, price: 150, balance: -450, flag: 'red', gName: 'شركة النور للتوريدات', gPhone: '01199999902', reminders: 4),
    m(gid: 'dg2', name: 'باسم ثروت', phone: '01122222204', gb: 20, price: 150, balance: 0),
    m(gid: 'dg2', name: 'رامي صبري', phone: '01122222205', gb: 15, price: 120, balance: 0, flag: 'green'),
    m(gid: 'dg2', name: 'هاني مجدي', phone: '01122222206', gb: 10, price: 100, balance: -100),
    // ── المجموعة 3 ──
    m(gid: 'dg3', name: 'فادي وحيد', phone: '01233333301', gb: 50, price: 280, balance: 0, flag: 'green'),
    m(gid: 'dg3', name: 'عادل شكري', phone: '01233333302', gb: 40, price: 230, balance: -230, gName: 'عم صابر أبو خليل', gPhone: '01266666603', reminders: 1),
    m(gid: 'dg3', name: 'نادر لطفي', phone: '01233333303', gb: 20, price: 145, balance: 0),
    m(gid: 'dg3', name: 'سيف الدين حمدي', phone: '01233333304', gb: 15, price: 115, balance: -345, flag: 'red', gName: 'عم صابر أبو خليل', gPhone: '01266666603', reminders: 2),
    m(gid: 'dg3', name: 'يوسف عصام', phone: '01233333305', gb: 10, price: 95, balance: 0, flag: 'green'),
    // ── المجموعة 4 ──
    m(gid: 'dg4', name: 'مروان فؤاد', phone: '01544444401', gb: 50, price: 275, balance: -825, flag: 'red', reminders: 5),
    m(gid: 'dg4', name: 'زياد حسام', phone: '01544444402', gb: 20, price: 140, balance: 0, flag: 'green'),
    m(gid: 'dg4', name: 'عمر الشاذلي', phone: '01544444403', gb: 20, price: 140, balance: -140, deferral: iso(now.year, now.month + 1 > 12 ? 1 : now.month + 1, 5)),
    m(gid: 'dg4', name: 'محمود جلال', phone: '01544444404', gb: 15, price: 110, balance: 0),
    // ── المجموعة 5 ──
    m(gid: 'dg5', name: 'إيهاب فاروق', phone: '01055555511', gb: 50, price: 295, balance: 0, flag: 'green'),
    m(gid: 'dg5', name: 'حاتم رجب', phone: '01055555512', gb: 40, price: 245, balance: -245, gName: 'الحاج سعيد أبو أحمد', gPhone: '01055555501'),
    m(gid: 'dg5', name: 'صلاح الدين نور', phone: '01055555513', gb: 20, price: 150, balance: 0),
    m(gid: 'dg5', name: 'أكرم بشير', phone: '01055555514', gb: 20, price: 150, balance: -300, flag: 'yellow', reminders: 2),
    m(gid: 'dg5', name: 'جمال عبد الفتاح', phone: '01055555515', gb: 15, price: 120, balance: 0),
    m(gid: 'dg5', name: 'هوم 4G — شركة', phone: '01055555516', gb: 0, price: 220, type: 'homeforgee'),
  ];

  final guarantors = [
    Guarantor(
      id: 'dgr1', name: 'الحاج سعيد أبو أحمد', phone: '01055555501',
      type: 'personal', maxDebt: 2000,
      log: [
        {'date': dmy(now.day, now.month, now.year), 'desc': '💰 دفعة عن حسن إبراهيم', 'amount': 300.0, 'type': 'payment'},
        {'date': dmy(15, now.month - 1 == 0 ? 12 : now.month - 1, now.year), 'desc': '💰 دفعة عن شريف عادل', 'amount': 240.0, 'type': 'payment'},
        {'date': dmy(2, now.month - 1 == 0 ? 12 : now.month - 1, now.year), 'desc': '📤 تم إرسال تذكير للكفيل', 'amount': 0.0, 'type': 'reminder'},
      ],
    ),
    Guarantor(
      id: 'dgr2', name: 'شركة النور للتوريدات', phone: '01199999902',
      type: 'company', phone2: '01199999912',
      log: [
        {'date': dmy(20, now.month - 1 == 0 ? 12 : now.month - 1, now.year), 'desc': '💰 دفعة عن إسلام قدري', 'amount': 450.0, 'type': 'payment'},
      ],
    ),
    Guarantor(
      id: 'dgr3', name: 'عم صابر أبو خليل', phone: '01266666603',
      type: 'relative', maxDebt: 1000,
    ),
  ];

  final bills = <CompanyBill>[
    // فاتورة الشهر الحالي — لسه متدفعتش (العداد الأخضر)
    CompanyBill(id: 'db1', groupId: 'dg1', month: curMonth, fixedAmount: 2150, actualAmount: 2150, date: dmy(now.day <= 3 ? 1 : now.day - 2, now.month, now.year)),
    // فاتورة متأخرة (نزلت من 40 يوم)
    CompanyBill(id: 'db2', groupId: 'dg4', month: lastMonth, fixedAmount: 1200, actualAmount: 1240, isActual: true, date: dmy(1, now.month - 1 == 0 ? 12 : now.month - 1, now.year)),
    // فاتورة مدفوعة بالكامل
    CompanyBill(
      id: 'db3', groupId: 'dg2', month: lastMonth, fixedAmount: 1750, actualAmount: 1750, isActual: true,
      date: dmy(5, now.month - 1 == 0 ? 12 : now.month - 1, now.year),
      payments: [BillPayment(id: 'dp1', amount: 1750, date: dmy(18, now.month - 1 == 0 ? 12 : now.month - 1, now.year))],
    ),
    // فاتورة مدفوع منها جزء
    CompanyBill(
      id: 'db4', groupId: 'dg5', month: curMonth, fixedAmount: 2100, actualAmount: 2100,
      date: dmy(2, now.month, now.year),
      payments: [BillPayment(id: 'dp2', amount: 1000, date: dmy(now.day, now.month, now.year))],
    ),
    CompanyBill(id: 'db5', groupId: 'dg3', month: curMonth, fixedAmount: 1400, actualAmount: 1400, date: dmy(1, now.month, now.year)),
  ];

  return AppDB(
    groups: groups,
    members: members,
    guarantors: guarantors,
    companyBills: bills,
    giftTypes: [
      {'id': 'gt1', 'name': 'شوب 100', 'price': 100},
      {'id': 'gt2', 'name': 'نولا 100', 'price': 100},
      {'id': 'gt3', 'name': 'سبريسوا 50', 'price': 50},
    ],
    activityLog: [
      {'date': dmy(now.day, now.month, now.year), 'desc': '💰 دفعة من كريم فوزي — 250 ج'},
      {'date': dmy(now.day, now.month, now.year), 'desc': '➕ إضافة عميل جديد: جمال عبد الفتاح'},
    ],
    gid: 100,
    mid: 100,
  );
}
