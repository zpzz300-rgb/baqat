// lib/models/models.dart
// نماذج البيانات - مطابقة لـ HTML app
import 'package:flutter/material.dart' show Color;
import 'main_line.dart';
export 'main_line.dart';

// ── LineType ─────────────────────────────────────────────────────
enum LineType {
  home4g, // هوم 4G
  adsl, // ADSL / فيبر
  guest, // ضيف عند تاجر
  mobile, // موبايل
}

extension LineTypeX on LineType {
  String get label {
    switch (this) {
      case LineType.home4g:
        return 'هوم 4G';
      case LineType.adsl:
        return 'ADSL/فيبر';
      case LineType.guest:
        return 'ضيف';
      case LineType.mobile:
        return 'موبايل';
    }
  }

  String get emoji {
    switch (this) {
      case LineType.home4g:
        return '📡';
      case LineType.adsl:
        return '🌐';
      case LineType.guest:
        return '🧳';
      case LineType.mobile:
        return '📱';
    }
  }

  Color get color {
    switch (this) {
      case LineType.home4g:
        return const Color(0xFF1565c0);
      case LineType.adsl:
        return const Color(0xFF00695c);
      case LineType.guest:
        return const Color(0xFFe65100);
      case LineType.mobile:
        return const Color(0xFF6a1b9a);
    }
  }

  Color get bg {
    switch (this) {
      case LineType.home4g:
        return const Color(0xFFe3f2fd);
      case LineType.adsl:
        return const Color(0xFFe0f2f1);
      case LineType.guest:
        return const Color(0xFFfff3e0);
      case LineType.mobile:
        return const Color(0xFFf3e5f5);
    }
  }

  static LineType fromString(String? s) {
    switch (s) {
      case 'home4g':
        return LineType.home4g;
      case 'adsl':
        return LineType.adsl;
      case 'guest':
        return LineType.guest;
      case 'mobile':
        return LineType.mobile;
      default:
        return LineType.home4g;
    }
  }

  String get key {
    switch (this) {
      case LineType.home4g:
        return 'home4g';
      case LineType.adsl:
        return 'adsl';
      case LineType.guest:
        return 'guest';
      case LineType.mobile:
        return 'mobile';
    }
  }
}

class Group {
  String id;
  String phone;
  String type; // '3800', '1800', or 'manual'
  String payer; // 'me' or 'company'
  String cycle; // '1' or '2'
  String? lastBilledMonth;
  String? lastBillDate;
  String? lastBillActualMonth;
  String? lastBillActual;
  String? ownerName;
  String? ownerNatId;
  String? ownerPhoto;
  String? notes;
  String? date;
  String? expiryDate; // تاريخ انتهاء الخط (YYYY-MM-DD)
  int rewardPoints; // نقاط المكافآت المتراكمة
  double
      pointsValue; // قيمة النقطة الواحدة بالجنيه (افتراضي: 0.04 — أي 1000 نقطة = 40 ج)
  List<Map<String, dynamic>> complaints;
  List<Map<String, dynamic>> gifts;
  double giftProfit;
  List<Map<String, dynamic>> pointsRedemptions;

  // ── بيانات مالية للمجموعة ─────────────────────────────────────
  String? groupInvoiceName; // اسم الفاتورة الرئيسي
  double fixedBillAmount; // المبلغ الثابت الشهري للفاتورة
  double voucherValue; // قيمة القسيمة
  String voucherPeriod; // '6m' / '1y'
  String? voucherStartDate; // تاريخ بدء القسيمة (YYYY-MM-DD)
  int orderIndex; // ترتيب السحب والإفلات

  // ── بيانات الخط الرئيسي ──────────────────────────────────────
  String? provider; // 'vodafone','etisalat','orange','we'
  int? maxClients;
  int? pointsMonthly;
  double? pointPrice;
  double? extraClientFee;
  String? billingCycle; // 'day1','day4','mid','cycle1','cycle2'
  int? offerDuration; // months
  String? offerStartDate;
  String? offerEndDate;
  double? actualBillAmount; // المبلغ الفعلي للفاتورة (لحساب الربح)
  LineType lineType; // home4g / adsl / guest / mobile

  // ── ملاحظة ثابتة (Sticky Note) ─────────────────────────────
  String? stickyNote;

  // ── آخر فاتورة + مفكرة الخط ────────────────────────────────
  double lastBillAmount; // قيمة آخر فاتورة من الشركة
  double billDebt; // إجمالي الفواتير غير المسددة للشركة
  List<Map<String, dynamic>> groupNotes; // [{text, date, type:'auto'/'manual'}]
  String? lastNotesMonth; // tracking key for auto-notes

  // ── ربح النقاط الشهري المعلق (لم يُضف للتقرير بعد) ─────────
  double pendingPointsProfit;
  String? lastGiftResetMonth; // YYYY-M — لتصفير giftProfit شهرياً
  String? manualDueDate; // YYYY-MM-DD — موعد سداد الفاتورة اليدوية
  String? parentGroupId; // ربط هذا الخط بخط رئيسي (parent-child linking)

  // ── Master Line Refactor (Phase 2) ────────────────────────────
  String? ownerFullName;        // اسم صاحب الخط رباعي
  String? contractPhotoPath;    // مسار صورة العقد
  int mainLineAllocationGb;     // حصة الخط الرئيسي من السعة (للشريط الذكي)
  int totalMinutes;             // إجمالي دقائق الخط (12000 / 10000 حسب الـ tier)
  String tier;                  // 'tier1_4250' | 'tier2_smaller' | ''

  // Etisalat-specific
  bool monthOnMeToggle;         // شهر عليا وشهر على الشركة
  bool fixedRateSystem;         // نظام ثابت
  double refundableInsurance;   // التأمين المسترد (0 = مفيش)
  String? insuranceClaimDate;   // تاريخ المطالبة بالتأمين (افتراضي بعد 6 شهور)
  int pointsResetDay;           // يوم تجديد النقاط (7 افتراضي)

  // WE-specific
  bool weCouponEnabled;         // قسيمة 5000
  String? weCouponDate;         // تاريخ نزول القسيمة

  // Vodafone-specific
  String? vodafoneRateType;     // 'variable' | 'fixed'

  // باقات إضافية مؤقتة (Phase 3)
  List<Map<String, dynamic>> extraBundles; // [{month, gb, cost, date}]

  Group({
    required this.id,
    required this.phone,
    this.type = '3800',
    this.payer = 'me',
    this.cycle = '1',
    this.lastBilledMonth,
    this.lastBillDate,
    this.lastBillActualMonth,
    this.lastBillActual,
    this.ownerName,
    this.ownerNatId,
    this.ownerPhoto,
    this.notes,
    this.date,
    this.expiryDate,
    this.rewardPoints = 0,
    this.pointsValue = 0.04,
    List<Map<String, dynamic>>? complaints,
    List<Map<String, dynamic>>? gifts,
    this.giftProfit = 0,
    List<Map<String, dynamic>>? pointsRedemptions,
    this.groupInvoiceName,
    this.fixedBillAmount = 0,
    this.voucherValue = 0,
    this.voucherPeriod = '6m',
    this.voucherStartDate,
    this.orderIndex = 0,
    this.provider,
    this.maxClients,
    this.pointsMonthly,
    this.pointPrice,
    this.extraClientFee,
    this.billingCycle,
    this.offerDuration,
    this.offerStartDate,
    this.offerEndDate,
    this.actualBillAmount,
    this.lineType = LineType.home4g,
    this.stickyNote,
    this.lastBillAmount = 0,
    this.billDebt = 0,
    List<Map<String, dynamic>>? groupNotes,
    this.lastNotesMonth,
    this.pendingPointsProfit = 0,
    this.lastGiftResetMonth,
    this.manualDueDate,
    this.parentGroupId,
    this.ownerFullName,
    this.contractPhotoPath,
    this.mainLineAllocationGb = 0,
    this.totalMinutes = 0,
    this.tier = '',
    this.monthOnMeToggle = false,
    this.fixedRateSystem = false,
    this.refundableInsurance = 0,
    this.insuranceClaimDate,
    this.pointsResetDay = 7,
    this.weCouponEnabled = false,
    this.weCouponDate,
    this.vodafoneRateType,
    List<Map<String, dynamic>>? extraBundles,
  })  : complaints = complaints ?? [],
        gifts = gifts ?? [],
        pointsRedemptions = pointsRedemptions ?? [],
        groupNotes = groupNotes ?? [],
        extraBundles = extraBundles ?? [];

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'].toString(),
        phone: j['phone'] ?? '',
        type: j['type'] ?? '3800',
        payer: j['payer'] ?? 'me',
        cycle: j['cycle']?.toString() ?? '1',
        lastBilledMonth: j['lastBilledMonth'],
        lastBillDate: j['lastBillDate'],
        lastBillActualMonth: j['lastBillActualMonth'],
        lastBillActual: j['lastBillActual'],
        ownerName: j['ownerName'],
        ownerNatId: j['ownerNatId'],
        ownerPhoto: j['ownerPhoto'],
        notes: j['notes'],
        date: j['date'],
        expiryDate: j['expiryDate'],
        rewardPoints: (j['rewardPoints'] ?? 0) as int,
        pointsValue: (j['pointsValue'] ?? 0.04).toDouble(),
        complaints: List<Map<String, dynamic>>.from(j['complaints'] ?? []),
        gifts: List<Map<String, dynamic>>.from(j['gifts'] ?? []),
        giftProfit: (j['giftProfit'] ?? 0).toDouble(),
        pointsRedemptions:
            List<Map<String, dynamic>>.from(j['pointsRedemptions'] ?? []),
        groupInvoiceName: j['groupInvoiceName'],
        fixedBillAmount: (j['fixedBillAmount'] ?? 0).toDouble(),
        voucherValue: (j['voucherValue'] ?? 0).toDouble(),
        voucherPeriod: j['voucherPeriod'] ?? '6m',
        voucherStartDate: j['voucherStartDate'],
        orderIndex: (j['orderIndex'] ?? 0) as int,
        provider: j['provider'],
        maxClients: j['maxClients'] as int?,
        pointsMonthly: j['pointsMonthly'] as int?,
        pointPrice: (j['pointPrice'] as num?)?.toDouble(),
        extraClientFee: (j['extraClientFee'] as num?)?.toDouble(),
        billingCycle: j['billingCycle'],
        offerDuration: j['offerDuration'] as int?,
        offerStartDate: j['offerStartDate'],
        offerEndDate: j['offerEndDate'],
        actualBillAmount: (j['actualBillAmount'] as num?)?.toDouble(),
        lineType: LineTypeX.fromString(j['lineType']),
        stickyNote: j['stickyNote'],
        lastBillAmount: (j['lastBillAmount'] as num?)?.toDouble() ?? 0,
        billDebt: (j['billDebt'] as num?)?.toDouble() ?? 0,
        groupNotes: List<Map<String, dynamic>>.from(j['groupNotes'] ?? []),
        lastNotesMonth: j['lastNotesMonth'],
        pendingPointsProfit: (j['pendingPointsProfit'] as num?)?.toDouble() ?? 0,
        lastGiftResetMonth: j['lastGiftResetMonth'],
        manualDueDate: j['manualDueDate'],
        parentGroupId: j['parentGroupId'],
        ownerFullName: j['ownerFullName'],
        contractPhotoPath: j['contractPhotoPath'],
        mainLineAllocationGb: (j['mainLineAllocationGb'] ?? 0) as int,
        totalMinutes: (j['totalMinutes'] ?? 0) as int,
        tier: j['tier'] ?? '',
        monthOnMeToggle: j['monthOnMeToggle'] ?? false,
        fixedRateSystem: j['fixedRateSystem'] ?? false,
        refundableInsurance: (j['refundableInsurance'] ?? 0).toDouble(),
        insuranceClaimDate: j['insuranceClaimDate'],
        pointsResetDay: (j['pointsResetDay'] ?? 7) as int,
        weCouponEnabled: j['weCouponEnabled'] ?? false,
        weCouponDate: j['weCouponDate'],
        vodafoneRateType: j['vodafoneRateType'],
        extraBundles:
            List<Map<String, dynamic>>.from(j['extraBundles'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'type': type,
        'payer': payer,
        'cycle': cycle,
        'lastBilledMonth': lastBilledMonth,
        'lastBillDate': lastBillDate,
        'lastBillActualMonth': lastBillActualMonth,
        'lastBillActual': lastBillActual,
        'ownerName': ownerName,
        'ownerNatId': ownerNatId,
        'ownerPhoto': ownerPhoto,
        'notes': notes,
        'date': date,
        'expiryDate': expiryDate,
        'rewardPoints': rewardPoints,
        'pointsValue': pointsValue,
        'complaints': complaints,
        'gifts': gifts,
        'giftProfit': giftProfit,
        'pointsRedemptions': pointsRedemptions,
        'groupInvoiceName': groupInvoiceName,
        'fixedBillAmount': fixedBillAmount,
        'voucherValue': voucherValue,
        'voucherPeriod': voucherPeriod,
        'voucherStartDate': voucherStartDate,
        'orderIndex': orderIndex,
        'provider': provider,
        'maxClients': maxClients,
        'pointsMonthly': pointsMonthly,
        'pointPrice': pointPrice,
        'extraClientFee': extraClientFee,
        'billingCycle': billingCycle,
        'offerDuration': offerDuration,
        'offerStartDate': offerStartDate,
        'offerEndDate': offerEndDate,
        'actualBillAmount': actualBillAmount,
        'lineType': lineType.key,
        'stickyNote': stickyNote,
        'lastBillAmount': lastBillAmount,
        'billDebt': billDebt,
        'groupNotes': groupNotes,
        'lastNotesMonth': lastNotesMonth,
        'pendingPointsProfit': pendingPointsProfit,
        'lastGiftResetMonth': lastGiftResetMonth,
        'manualDueDate': manualDueDate,
        'parentGroupId': parentGroupId,
        'ownerFullName': ownerFullName,
        'contractPhotoPath': contractPhotoPath,
        'mainLineAllocationGb': mainLineAllocationGb,
        'totalMinutes': totalMinutes,
        'tier': tier,
        'monthOnMeToggle': monthOnMeToggle,
        'fixedRateSystem': fixedRateSystem,
        'refundableInsurance': refundableInsurance,
        'insuranceClaimDate': insuranceClaimDate,
        'pointsResetDay': pointsResetDay,
        'weCouponEnabled': weCouponEnabled,
        'weCouponDate': weCouponDate,
        'vodafoneRateType': vodafoneRateType,
        'extraBundles': extraBundles,
      };

  int get defaultPrice => type == '3800' ? 260 : 190;

  // ── Phase 2: Tier & Master Line Helpers ──────────────────────
  /// السعة الأساسية للعملاء حسب الـ tier
  int get tierBaseCapacity {
    if (tier == 'tier1_4250') return 7;
    if (tier == 'tier2_smaller') return 5;
    return maxClients ?? 0;
  }

  /// إجمالي السعة (الأساسية + 1 exception + 2 زيادة)
  int get tierMaxCapacity {
    if (tier.isEmpty) return maxClients ?? 0;
    return tierBaseCapacity + 1 + 2; // أساسي + exception + extra
  }

  /// سعر العميل الإضافي (الـ 8 أو 9 أو 10)
  double get extraCustomerFee => extraClientFee ?? 125;

  /// عدد الأيام المتبقية لانتهاء العرض (null لو مفيش تاريخ)
  int? get daysUntilOfferEnd {
    final date = offerEndDate;
    if (date == null) return null;
    final end = DateTime.tryParse(date);
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }

  /// هل التطبيق دلوقتي في فترة العداد التنازلي (آخر 75 يوم)؟
  bool get isOfferCountdownActive {
    final days = daysUntilOfferEnd;
    return days != null && days <= 75 && days >= 0;
  }

  /// شدّة التغميق في الهيدر بناءً على قرب نهاية العرض (0 = لا تغميق، 1 = أقصى تغميق)
  double get offerWarningIntensity {
    final days = daysUntilOfferEnd;
    if (days == null || days < 0 || days > 75) return 0;
    return (75 - days) / 75; // كل ما يقل الوقت، التغميق يزيد
  }

  /// تاريخ المطالبة بالتأمين (افتراضي 6 شهور من بداية العرض)
  String? get computedInsuranceClaimDate {
    if (insuranceClaimDate != null) return insuranceClaimDate;
    if (refundableInsurance <= 0) return null;
    final start = offerStartDate ?? date;
    if (start == null) return null;
    final d = DateTime.tryParse(start);
    if (d == null) return null;
    final claim = DateTime(d.year, d.month + 6, d.day);
    return '${claim.year}-${claim.month.toString().padLeft(2, '0')}-${claim.day.toString().padLeft(2, '0')}';
  }

  /// أيام متبقية للمطالبة بالتأمين
  int? get daysUntilInsuranceClaim {
    final c = computedInsuranceClaimDate;
    if (c == null) return null;
    final d = DateTime.tryParse(c);
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  }

  /// أيام متبقية لقسيمة WE 5000
  int? get daysUntilWeCoupon {
    if (!weCouponEnabled || weCouponDate == null) return null;
    final d = DateTime.tryParse(weCouponDate!);
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  }

  /// إجمالي السعة الإضافية الشهرية (مجموع الباقات الإضافية للشهر الحالي)
  int extraGbThisMonth(String month) {
    return extraBundles
        .where((b) => b['month'] == month)
        .fold<int>(0, (s, b) => s + ((b['gb'] as num?)?.toInt() ?? 0));
  }

  /// إجمالي تكلفة الباقات الإضافية للشهر (لخصمها من الربح)
  double extraCostThisMonth(String month) {
    return extraBundles
        .where((b) => b['month'] == month)
        .fold<double>(0, (s, b) => s + ((b['cost'] as num?)?.toDouble() ?? 0));
  }
}

class Member {
  String id;
  String gid;
  String name;
  String phone;
  String? phone2; // secondary number
  bool waPhone2; // true = use phone2 for WhatsApp
  String package;
  int gb; // GB allocated from group pool
  double price;
  double balance;
  String type; // 'regular', 'landline', 'homeforgee'
  String? date;
  String? natId;
  String? address; // عنوان العميل
  String? notes;
  String? guarantorName;
  String? guarantorPhone;
  // New Fields
  String? invoiceName;
  String? lineType;
  double fixedMonthlyAmount;
  String? lastInvoiceDate;

  String? paymentFlag; // null / 'green' / 'yellow' / 'red'
  int orderIndex;
  List<Map<String, dynamic>> log;
  List<String> files;
  // سجل الفواتير الشهرية: [{amount, notes, dueDate, isPaid, paidDate}]
  List<Map<String, dynamic>> invoiceLog;
  String? natIdPhotoPath; // مسار صورة البطاقة
  // تأجيل الدفع
  String? deferralDate; // YYYY-MM-DD
  String? deferralNote; // سبب التأجيل
  // Phase 2 — توزيع الدقائق على العملاء
  int minutesAllocation; // الدقائق المخصصة لهذا العميل من إجمالي دقائق الخط

  Member({
    required this.id,
    required this.gid,
    required this.name,
    required this.phone,
    this.phone2,
    this.waPhone2 = false,
    this.package = '',
    this.gb = 0,
    this.price = 0,
    this.balance = 0,
    this.type = 'regular',
    this.date,
    this.natId,
    this.address,
    this.notes,
    this.guarantorName,
    this.guarantorPhone,
    this.invoiceName,
    this.lineType,
    this.fixedMonthlyAmount = 0,
    this.lastInvoiceDate,
    this.paymentFlag,
    this.orderIndex = 0,
    List<Map<String, dynamic>>? log,
    List<String>? files,
    List<Map<String, dynamic>>? invoiceLog,
    this.natIdPhotoPath,
    this.deferralDate,
    this.deferralNote,
    this.minutesAllocation = 0,
  })  : log = log ?? [],
        files = files ?? [],
        invoiceLog = invoiceLog ?? [];

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'].toString(),
        gid: j['gid'].toString(),
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        phone2: j['phone2'],
        waPhone2: j['waPhone2'] ?? false,
        package: j['package'] ?? '',
        gb: (j['gb'] ?? 0) as int,
        price: (j['price'] ?? 0).toDouble(),
        balance: (j['balance'] ?? 0).toDouble(),
        type: j['type'] ?? 'regular',
        date: j['date'],
        natId: j['natId'],
        address: j['address'],
        notes: j['notes'],
        guarantorName: j['guarantorName'],
        guarantorPhone: j['guarantorPhone'],
        invoiceName: j['invoiceName'],
        lineType: j['lineType'],
        fixedMonthlyAmount: (j['fixedMonthlyAmount'] ?? 0).toDouble(),
        lastInvoiceDate: j['lastInvoiceDate'],
        paymentFlag: j['paymentFlag'],
        orderIndex: (j['orderIndex'] ?? 0) as int,
        log: List<Map<String, dynamic>>.from(j['log'] ?? []),
        files: List<String>.from(j['files'] ?? []),
        invoiceLog: List<Map<String, dynamic>>.from(j['invoiceLog'] ?? []),
        natIdPhotoPath: j['natIdPhotoPath'],
        deferralDate: j['deferralDate'],
        deferralNote: j['deferralNote'],
        minutesAllocation: (j['minutesAllocation'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'gid': gid,
        'name': name,
        'phone': phone,
        'phone2': phone2,
        'waPhone2': waPhone2,
        'package': package,
        'gb': gb,
        'price': price,
        'balance': balance,
        'type': type,
        'date': date,
        'natId': natId,
        'address': address,
        'notes': notes,
        'guarantorName': guarantorName,
        'guarantorPhone': guarantorPhone,
        'invoiceName': invoiceName,
        'lineType': lineType,
        'fixedMonthlyAmount': fixedMonthlyAmount,
        'lastInvoiceDate': lastInvoiceDate,
        'paymentFlag': paymentFlag,
        'orderIndex': orderIndex,
        'log': log,
        'files': files,
        'invoiceLog': invoiceLog,
        'natIdPhotoPath': natIdPhotoPath,
        'deferralDate': deferralDate,
        'deferralNote': deferralNote,
        'minutesAllocation': minutesAllocation,
      };

  bool get hasDebt => balance < 0;
  bool get isClear => balance >= 0 && price > 0;
  bool get isZero => price == 0;

  /// رقم الواتساب المحدد (الافتراضي أو الثانوي)
  String get waPhone =>
      (waPhone2 && phone2 != null && phone2!.isNotEmpty) ? phone2! : phone;

  String get typeIcon {
    switch (type) {
      case 'landline':
        return '☎️';
      case 'homeforgee':
        return '🏠';
      default:
        return '👤';
    }
  }
}

class Guarantor {
  String id;
  String name;
  String phone;
  String? phone2;
  String type; // 'personal', 'company', 'relative'
  String? natId;
  String? notes;

  Guarantor({
    required this.id,
    required this.name,
    required this.phone,
    this.phone2,
    this.type = 'personal',
    this.natId,
    this.notes,
  });

  factory Guarantor.fromJson(Map<String, dynamic> j) => Guarantor(
        id: j['id'].toString(),
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        phone2: j['phone2'],
        type: j['type'] ?? 'personal',
        natId: j['natId'],
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'phone2': phone2,
        'type': type,
        'natId': natId,
        'notes': notes,
      };

  String get typeLabel {
    switch (type) {
      case 'company':
        return '🏢 شركة';
      case 'relative':
        return '👨‍👩‍👦 قريب';
      default:
        return '👤 شخصي';
    }
  }
}

class Rental {
  String id;
  String gid;
  String name;
  double rent;
  double balance;
  String? wa;
  String? wa2;
  String? msg;
  String? date;
  String status; // 'active', 'paused', 'ended'
  String? notes;
  List<Map<String, dynamic>> log;
  // Phase 6: تفاصيل الباقة (للرسالة الديناميكية والفوترة الآلية)
  String? packageSize; // "20 جيجا"
  double packagePrice; // السعر الشهري للباقة
  String? lastBilledMonth; // YYYY-MM — لمنع تكرار الفوترة

  Rental({
    required this.id,
    required this.gid,
    required this.name,
    this.rent = 0,
    this.balance = 0,
    this.wa,
    this.wa2,
    this.msg,
    this.date,
    this.status = 'active',
    this.notes,
    List<Map<String, dynamic>>? log,
    this.packageSize,
    this.packagePrice = 0,
    this.lastBilledMonth,
  }) : log = log ?? [];

  factory Rental.fromJson(Map<String, dynamic> j) => Rental(
        id: j['id'].toString(),
        gid: j['gid'].toString(),
        name: j['name'] ?? '',
        rent: (j['rent'] ?? 0).toDouble(),
        balance: (j['balance'] ?? 0).toDouble(),
        wa: j['wa'],
        wa2: j['wa2'],
        msg: j['msg'],
        date: j['date'],
        status: j['status'] ?? 'active',
        notes: j['notes'],
        log: List<Map<String, dynamic>>.from(j['log'] ?? []),
        packageSize: j['packageSize'],
        packagePrice: (j['packagePrice'] ?? 0).toDouble(),
        lastBilledMonth: j['lastBilledMonth'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'gid': gid,
        'name': name,
        'rent': rent,
        'balance': balance,
        'wa': wa,
        'wa2': wa2,
        'msg': msg,
        'date': date,
        'status': status,
        'notes': notes,
        'log': log,
        'packageSize': packageSize,
        'packagePrice': packagePrice,
        'lastBilledMonth': lastBilledMonth,
      };

  /// السعر الفعلي للباقة (يستخدم packagePrice إن وُجد، وإلا rent)
  double get effectivePrice => packagePrice > 0 ? packagePrice : rent;
}

class WorkNum {
  String id;
  String phone;
  String label;
  String? notes;
  // ── حقول مخزون الأرقام (لتجنب التقفيل الجبري من الشركة) ──
  String? provider;          // 'etisalat'/'orange'/'vodafone'/'we'
  String? packageSystem;     // 3800 / 4000 / يدوي ...
  String? lastContactDate;   // ISO yyyy-MM-dd — آخر اتصال/تفعيل
  String? lastSerial;        // رقم سيريال الشريحة الأخير
  String status;             // 'available' / 'reserved' / 'needsRenewal' / 'damaged'
  String? offerExpiryDate;   // ISO — تاريخ انتهاء العرض/الخط
  String? previousOwner;     // اسم/رقم صاحب الخط السابق
  int? reminderDaysOverride; // override لمدة التذكير قبل التقفيل

  WorkNum({
    required this.id,
    required this.phone,
    this.label = '',
    this.notes,
    this.provider,
    this.packageSystem,
    this.lastContactDate,
    this.lastSerial,
    this.status = 'available',
    this.offerExpiryDate,
    this.previousOwner,
    this.reminderDaysOverride,
  });

  /// عدد الأيام منذ آخر اتصال — null لو مفيش تاريخ مسجّل
  int? get daysSinceContact {
    if (lastContactDate == null) return null;
    final d = DateTime.tryParse(lastContactDate!);
    if (d == null) return null;
    return DateTime.now().difference(d).inDays;
  }

  factory WorkNum.fromJson(Map<String, dynamic> j) => WorkNum(
        id: j['id'].toString(),
        phone: j['phone'] ?? '',
        label: j['label'] ?? '',
        notes: j['notes'],
        provider: j['provider'],
        packageSystem: j['packageSystem'],
        lastContactDate: j['lastContactDate'],
        lastSerial: j['lastSerial'],
        status: j['status'] ?? 'available',
        offerExpiryDate: j['offerExpiryDate'],
        previousOwner: j['previousOwner'],
        reminderDaysOverride: j['reminderDaysOverride'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'label': label,
        'notes': notes,
        'provider': provider,
        'packageSystem': packageSystem,
        'lastContactDate': lastContactDate,
        'lastSerial': lastSerial,
        'status': status,
        'offerExpiryDate': offerExpiryDate,
        'previousOwner': previousOwner,
        'reminderDaysOverride': reminderDaysOverride,
      };
}

class WaitlistEntry {
  int id;
  String name;
  String phone;
  String? phone2;
  String packageType; // 'any', '1500', '2000'
  String? package;
  double price;
  String? date;
  String? notes;
  String status; // 'waiting', 'contacted', 'assigned'

  WaitlistEntry({
    required this.id,
    required this.name,
    required this.phone,
    this.phone2,
    this.packageType = 'any',
    this.package,
    this.price = 0,
    this.date,
    this.notes,
    this.status = 'waiting',
  });

  factory WaitlistEntry.fromJson(Map<String, dynamic> j) => WaitlistEntry(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        phone2: j['phone2'],
        packageType: j['packageType'] ?? 'any',
        package: j['package'],
        price: (j['price'] ?? 0).toDouble(),
        date: j['date'],
        notes: j['notes'],
        status: j['status'] ?? 'waiting',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'phone2': phone2,
        'packageType': packageType,
        'package': package,
        'price': price,
        'date': date,
        'notes': notes,
        'status': status,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
/// عميل مؤقت عند تاجر آخر ريثما يتوفر مكان
class GuestUser {
  String id;
  String clientName; // اسم العميل
  String clientPhone; // رقم العميل
  String? dealerName; // اسم التاجر المستضيف
  String? dealerPhone; // رقم التاجر
  double clientAmount; // المبلغ المحصَّل من العميل
  double dealerCost; // المبلغ المدفوع للتاجر
  bool isCollected; // تم تحصيل المبلغ من العميل؟
  bool isPaid; // تم الدفع للتاجر؟
  String? startDate;
  String? notes;

  GuestUser({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    this.dealerName,
    this.dealerPhone,
    this.clientAmount = 0,
    this.dealerCost = 0,
    this.isCollected = false,
    this.isPaid = false,
    this.startDate,
    this.notes,
  });

  factory GuestUser.fromJson(Map<String, dynamic> j) => GuestUser(
        id: j['id'].toString(),
        clientName: j['clientName'] ?? j['name'] ?? '',
        clientPhone: j['clientPhone'] ?? j['phone'] ?? '',
        dealerName: j['dealerName'],
        dealerPhone: j['dealerPhone'],
        clientAmount: (j['clientAmount'] ?? j['amount'] ?? 0).toDouble(),
        dealerCost: (j['dealerCost'] ?? 0).toDouble(),
        isCollected: j['isCollected'] ?? j['isCollectedFromClient'] ?? false,
        isPaid: j['isPaid'] ?? j['isPaidToOwner'] ?? false,
        startDate: j['startDate'] ?? j['joinDate'],
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'dealerName': dealerName,
        'dealerPhone': dealerPhone,
        'clientAmount': clientAmount,
        'dealerCost': dealerCost,
        'isCollected': isCollected,
        'isPaid': isPaid,
        'startDate': startDate,
        'notes': notes,
      };

  double get profit => clientAmount - dealerCost;
}

// ── Bill Payment ──────────────────────────────────────────────────────────────
class BillPayment {
  String id;
  double amount;
  String date;
  String? note;

  BillPayment({required this.id, required this.amount, required this.date, this.note});

  factory BillPayment.fromJson(Map<String, dynamic> j) => BillPayment(
        id: j['id'].toString(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: j['date'] ?? '',
        note: j['note'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'date': date, 'note': note};
}

// ── Company Bill (فاتورة شركة الاتصالات) ─────────────────────────────────────
class CompanyBill {
  String id;
  String groupId;
  String month;        // "2025-05"
  double fixedAmount;  // المبلغ الثابت من إعدادات الخط
  double actualAmount; // الفاتورة الفعلية من الشركة
  bool isActual;       // false = تقديرية، true = فعلية من الشركة
  List<BillPayment> payments;
  String? note;
  String date;         // تاريخ الإضافة dd/mm/yyyy

  CompanyBill({
    required this.id,
    required this.groupId,
    required this.month,
    this.fixedAmount = 0,
    required this.actualAmount,
    this.isActual = false,
    List<BillPayment>? payments,
    this.note,
    required this.date,
  }) : payments = payments ?? [];

  double get paidAmount  => payments.fold(0.0, (s, p) => s + p.amount);
  double get remaining   => (actualAmount - paidAmount).clamp(0, double.infinity);
  bool   get isPaid      => remaining <= 0;
  bool   get isPartial   => paidAmount > 0 && !isPaid;

  String get status {
    if (isPaid)    return 'paid';
    if (isPartial) return 'partial';
    return 'unpaid';
  }

  factory CompanyBill.fromJson(Map<String, dynamic> j) => CompanyBill(
        id: j['id'].toString(),
        groupId: j['groupId'].toString(),
        month: j['month'] ?? '',
        fixedAmount: (j['fixedAmount'] as num?)?.toDouble() ?? 0,
        actualAmount: (j['actualAmount'] as num?)?.toDouble() ?? 0,
        isActual: j['isActual'] ?? false,
        payments: (j['payments'] as List? ?? [])
            .map((e) => BillPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: j['note'],
        date: j['date'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'month': month,
        'fixedAmount': fixedAmount,
        'actualAmount': actualAmount,
        'isActual': isActual,
        'payments': payments.map((p) => p.toJson()).toList(),
        'note': note,
        'date': date,
      };
}

/// Phase 5: ملاحظة عامة للشغل — مستقلة عن الخطوط
class GeneralNote {
  String id;
  String content;
  DateTime createdAt;
  DateTime? reminderTime;
  bool isCompleted;

  GeneralNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.reminderTime,
    this.isCompleted = false,
  });

  factory GeneralNote.fromJson(Map<String, dynamic> j) => GeneralNote(
        id: j['id'].toString(),
        content: j['content'] ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        reminderTime: j['reminderTime'] != null
            ? DateTime.tryParse(j['reminderTime'])
            : null,
        isCompleted: j['isCompleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'reminderTime': reminderTime?.toIso8601String(),
        'isCompleted': isCompleted,
      };
}

/// Default packages (built-in, always available)
/// label = اسم وصفي اختياري للباقة (مثلاً "نظام خاص"، "عرض قديم")
const kDefaultPackages = [
  {'name': '10 جيجا', 'gb': 10, 'price': 190, 'label': ''},
  {'name': '20 جيجا', 'gb': 20, 'price': 260, 'label': ''},
  {'name': '30 جيجا', 'gb': 30, 'price': 320, 'label': ''},
  {'name': '40 جيجا', 'gb': 40, 'price': 400, 'label': ''},
  {'name': '50 جيجا', 'gb': 50, 'price': 475, 'label': ''},
];

/// يبني اسم باقة موحَّد: لو فيه label يضاف ليه بين أقواس عشان تكون فريدة
/// مثال: "10 جيجا — 220 ج (نظام خاص)"
String buildPackageName(int gb, double price, String? label) {
  final base = '$gb جيجا — ${price.toStringAsFixed(0)} ج';
  if (label == null || label.trim().isEmpty) return base;
  return '$base (${label.trim()})';
}

class AppDB {
  List<Group> groups;
  List<Member> members;
  List<Member> deleted;
  List<Rental> rentals;
  List<WorkNum> workNums;
  List<Map<String, dynamic>> activityLog;
  List<WaitlistEntry> waitlist;
  List<Map<String, dynamic>> customPackages; // {name, gb, price, label}
  List<Map<String, dynamic>> giftTypes; // {id, name, price}
  List<Map<String, dynamic>> giftLog; // {month, archivedAt, gid, phone, gifts}
  List<Guarantor> guarantors;
  List<GuestUser> guestUsers;
  List<MainLine> mainLines;
  List<CompanyBill> companyBills; // سجل فواتير شركات الاتصالات
  List<GeneralNote> generalNotes; // Phase 5: ملاحظات عامة للشغل
  /// قفل الفوترة الشهري: key = 'cycle1'/'cycle2'/'cycle4'/'all', value = 'YYYY-MM'
  Map<String, String> billingLocks;
  int gid;
  int mid;

  AppDB({
    List<Group>? groups,
    List<Member>? members,
    List<Member>? deleted,
    List<Rental>? rentals,
    List<WorkNum>? workNums,
    List<Map<String, dynamic>>? activityLog,
    List<WaitlistEntry>? waitlist,
    List<Map<String, dynamic>>? customPackages,
    List<Map<String, dynamic>>? giftTypes,
    List<Map<String, dynamic>>? giftLog,
    List<Guarantor>? guarantors,
    List<GuestUser>? guestUsers,
    List<MainLine>? mainLines,
    List<CompanyBill>? companyBills,
    List<GeneralNote>? generalNotes,
    Map<String, String>? billingLocks,
    this.gid = 1,
    this.mid = 1,
  })  : groups = groups ?? [],
        members = members ?? [],
        deleted = deleted ?? [],
        rentals = rentals ?? [],
        workNums = workNums ?? [],
        activityLog = activityLog ?? [],
        waitlist = waitlist ?? [],
        customPackages = customPackages ?? [],
        giftTypes = giftTypes ?? [],
        giftLog = giftLog ?? [],
        guarantors = guarantors ?? [],
        guestUsers = guestUsers ?? [],
        mainLines = mainLines ?? [],
        companyBills = companyBills ?? [],
        generalNotes = generalNotes ?? [],
        billingLocks = billingLocks ?? {};

  /// All packages = defaults merged with custom overrides
  /// If a custom package has the same name as a default, it overrides it.
  List<Map<String, dynamic>> get allPackages {
    final result = <Map<String, dynamic>>[
      for (final d in kDefaultPackages) Map<String, dynamic>.from(d),
    ];
    for (final cp in customPackages) {
      final idx = result.indexWhere((p) => p['name'] == cp['name']);
      if (idx >= 0) {
        result[idx] = Map<String, dynamic>.from(cp);
      } else {
        result.add(Map<String, dynamic>.from(cp));
      }
    }
    return result;
  }

  factory AppDB.fromJson(Map<String, dynamic> j) => AppDB(
        groups:
            (j['groups'] as List? ?? []).map((e) => Group.fromJson(e)).toList(),
        members: (j['members'] as List? ?? [])
            .map((e) => Member.fromJson(e))
            .toList(),
        deleted: (j['deleted'] as List? ?? [])
            .map((e) => Member.fromJson(e))
            .toList(),
        rentals: (j['rentals'] as List? ?? [])
            .map((e) => Rental.fromJson(e))
            .toList(),
        workNums: (j['workNums'] as List? ?? [])
            .map((e) => WorkNum.fromJson(e))
            .toList(),
        activityLog: List<Map<String, dynamic>>.from(j['activityLog'] ?? []),
        waitlist: (j['waitlist'] as List? ?? [])
            .map((e) => WaitlistEntry.fromJson(e))
            .toList(),
        customPackages:
            List<Map<String, dynamic>>.from(j['customPackages'] ?? []),
        giftTypes: List<Map<String, dynamic>>.from(j['giftTypes'] ?? []),
        giftLog: List<Map<String, dynamic>>.from(j['giftLog'] ?? []),
        guarantors: (j['guarantors'] as List? ?? [])
            .map((e) => Guarantor.fromJson(e))
            .toList(),
        guestUsers: (j['guestUsers'] as List? ?? [])
            .map((e) => GuestUser.fromJson(e))
            .toList(),
        mainLines: (j['mainLines'] as List? ?? [])
            .map((e) => MainLine.fromJson(e))
            .toList(),
        companyBills: (j['companyBills'] as List? ?? [])
            .map((e) => CompanyBill.fromJson(e as Map<String, dynamic>))
            .toList(),
        generalNotes: (j['generalNotes'] as List? ?? [])
            .map((e) => GeneralNote.fromJson(e as Map<String, dynamic>))
            .toList(),
        billingLocks: Map<String, String>.from(j['billingLocks'] ?? {}),
        gid: j['gid'] ?? 1,
        mid: j['mid'] ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'groups': groups.map((e) => e.toJson()).toList(),
        'members': members.map((e) => e.toJson()).toList(),
        'deleted': deleted.map((e) => e.toJson()).toList(),
        'rentals': rentals.map((e) => e.toJson()).toList(),
        'workNums': workNums.map((e) => e.toJson()).toList(),
        'activityLog': activityLog,
        'waitlist': waitlist.map((e) => e.toJson()).toList(),
        'customPackages': customPackages,
        'giftTypes': giftTypes,
        'giftLog': giftLog,
        'guarantors': guarantors.map((e) => e.toJson()).toList(),
        'guestUsers': guestUsers.map((e) => e.toJson()).toList(),
        'mainLines':
            mainLines.map((e) => e.toSupabase()..['id'] = e.id).toList(),
        'companyBills': companyBills.map((e) => e.toJson()).toList(),
        'generalNotes': generalNotes.map((e) => e.toJson()).toList(),
        'billingLocks': billingLocks,
        'gid': gid,
        'mid': mid,
      };

  // ─── Stats ───────────────────────────────────────────────────
  double get totalDebt =>
      members.fold(0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));

  /// إجمالي المديونية لشركات الاتصالات:
  /// النظام الجديد: مجموع المتبقي من CompanyBills
  /// + الميراث: مجموعات بدون CompanyBills تستخدم billDebt
  double get totalBillsOwed {
    if (companyBills.isEmpty) {
      return groups.fold(0.0, (s, g) => s + g.billDebt);
    }
    final fromBills = companyBills.fold(0.0, (s, b) => s + b.remaining);
    final groupsWithBills = companyBills.map((b) => b.groupId).toSet();
    final legacy = groups
        .where((g) => !groupsWithBills.contains(g.id))
        .fold(0.0, (s, g) => s + g.billDebt);
    return fromBills + legacy;
  }

  double get totalProfit =>
      members.fold(0, (s, m) => s + (m.balance > 0 ? m.balance : 0));
  int get debtorCount => members.where((m) => m.balance < 0).length;

  Map<String, double> get financialSummary {
    // ليا كام: إجمالي ما يدين به العملاء (أرصدة سالبة)
    final receivables =
        members.fold<double>(0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));
    // عليا كام: إجمالي فواتير شركات الاتصالات غير المسددة (للتذكير فقط — لا تدخل في الربح)
    final payables = totalBillsOwed;
    // مستحق للتجار: تكلفة الضيوف غير المدفوعة (منفصل)
    final guestDebt =
        guestUsers.fold<double>(0, (s, g) => g.isPaid ? s : s + g.dealerCost);
    // دخل الإيجارات النشطة
    final rentalIncome = rentals
        .where((r) => r.status == 'active')
        .fold<double>(0, (s, r) => s + r.rent);
    // أرباح الهدايا + النقاط المعلقة (لا علاقة لها بفواتير الشركة)
    final giftProfits   = groups.fold<double>(0, (s, g) => s + g.giftProfit);
    final pointsProfits = groups.fold<double>(0, (s, g) => s + g.pendingPointsProfit);
    // صافي الربح = (دخل العملاء - fixedBillAmount - رسوم زيادة) + إيجارات + هدايا + نقاط
    // الفواتير الفعلية (actualBillAmount / companyBills) لا تدخل في هذه المعادلة
    final netProfit = totalBillingProfit + rentalIncome + giftProfits + pointsProfits;
    return {
      'receivables': receivables,
      'payables': payables,         // = فواتير الشركة (عليا كام) — للتذكير فقط
      'guestDebt': guestDebt,       // = مستحق للتجار (منفصل)
      'difference': receivables - guestDebt,
      'netProfit': netProfit,
    };
  }

  List<Member> membersOf(String gid) =>
      members.where((m) => m.gid == gid).toList();
  double groupDebt(String gid) =>
      membersOf(gid).fold(0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));
  double groupBalance(String gid) =>
      membersOf(gid).fold(0, (s, m) => s + m.balance);

  /// عدد خطوط الزيادة القابلة للخصم حسب الحد الأقصى للأفراد ونوع الخط
  int groupExtraLines(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    if (g.maxClients == null ||
        g.extraClientFee == null ||
        g.extraClientFee! <= 0) {
      return 0;
    }
    if (g.lineType == LineType.home4g || g.lineType == LineType.adsl) {
      return 0;
    }
    // خطوط الأرضي (landline) والهوم 4G (homeforgee) مجانية من الشركة — تُحسب موبايل (regular) فقط
    final count = membersOf(gid).where((m) => m.type == 'regular').length;
    return count > g.maxClients! ? count - g.maxClients! : 0;
  }

  /// إجمالي رسوم الخطوط الإضافية القابلة للخصم
  double groupExtraLineFee(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    return groupExtraLines(gid) * (g.extraClientFee ?? 0);
  }

  /// ربح مجموعة — يعتمد حصراً على fixedBillAmount (المبلغ الثابت المتفق عليه).
  /// actualBillAmount هو للعرض والتذكير فقط ولا يدخل في حساب الربح أبداً.
  /// Phase 3: نخصم تكلفة الباقات الإضافية المؤقتة للشهر الحالي
  double groupProfit(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final income = membersOf(gid).fold<double>(0, (s, m) => s + m.price);
    // fixedBillAmount هو التكلفة الوحيدة المعتمدة في الربح
    final cost = g.fixedBillAmount;
    if (cost <= 0 && g.type != 'manual') return 0; // لا تكلفة محددة → لا ربح محسوب
    final extraFee = g.type == 'manual' ? 0.0 : groupExtraLineFee(gid);
    // تكلفة الباقات الإضافية المؤقتة لهذا الشهر
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final extraBundleCost = g.extraCostThisMonth(month);
    return income - cost - extraFee - extraBundleCost;
  }

  /// فواتير مجموعة مرتبة من الأحدث للأقدم
  List<CompanyBill> companyBillsOf(String gid) =>
      companyBills.where((b) => b.groupId == gid).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// إجمالي ربح الفواتير = مجموع (دخل العملاء - fixedBillAmount - رسوم إضافية) لكل مجموعة
  double get totalBillingProfit =>
      groups.fold<double>(0, (s, g) => s + groupProfit(g.id));

  /// إجمالي الدخل الشهري من العملاء
  double get totalMonthlyIncome =>
      members.fold<double>(0, (s, m) => s + m.price);

  /// صافي ربح مجموعة = ربح الفاتورة + ربح الهدايا + ربح الإيجار + قيمة النقاط الشهرية
  /// المعادلة: (نقاط) + (فرق فواتير) + (هدايا) + (اشتراكات يدوية) − (فاتورة الشركة)
  /// كل هذا مضمّن في: groupProfit (يطرح الفاتورة) + giftProfit + pendingPointsProfit
  double groupNetProfit(String gid, List<Rental> rentals) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final billProfit = groupProfit(gid);
    final rentalProfit = rentals
        .where((r) => r.gid == gid && r.status == 'active')
        .fold<double>(0, (s, r) => s + r.rent);
    return billProfit + g.giftProfit + rentalProfit + g.pendingPointsProfit;
  }

  /// Total GB pool for a group based on type + extra bundles لهذا الشهر
  int groupTotalGb(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final base = g.type == '3800' ? 200 : 70;
    final now = DateTime.now();
    final month =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return base + g.extraGbThisMonth(month);
  }

  /// GB used by members + main line allocation
  int groupUsedGb(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final byMembers = membersOf(gid).fold<int>(0, (s, m) {
      // الخط الأرضي بياخد 10 جيجا ثابتة، Home 4G مايخصمش (شبكة منفصلة)
      if (m.type == 'landline') return s + 10;
      if (m.type == 'homeforgee') return s; // 0 GB
      return s + m.gb;
    });
    return byMembers + g.mainLineAllocationGb;
  }

  /// Remaining GB (لا يقل عن 0)
  int groupRemainingGb(String gid) {
    final r = groupTotalGb(gid) - groupUsedGb(gid);
    return r < 0 ? 0 : r;
  }

  /// نسبة الـ free GB (0..1) — تستخدم لتحديد لون الشريط
  double groupFreeFraction(String gid) {
    final total = groupTotalGb(gid);
    if (total <= 0) return 0;
    return (groupRemainingGb(gid) / total).clamp(0.0, 1.0);
  }

  /// إجمالي الدقائق المستخدمة من قبل العملاء
  int groupUsedMinutes(String gid) =>
      membersOf(gid).fold<int>(0, (s, m) => s + m.minutesAllocation);
}
