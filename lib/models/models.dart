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
  String? accountEmail; // 📧 إيميل الحساب اللي بيتم الدخول بيه على الخط
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
  /// 💰 السعر الخام — اللي الشركة بتاخده فعلاً في الفاتورة.
  /// للخطوط «شهر وشهر» ده رقم الفاتورة الكبيرة (٤٢٥٠ مثلاً) اللي بتنزل
  /// كل شهرين، مش تكلفة الشهر الواحد. للفلوس والمديونية بس.
  double fixedBillAmount; // المبلغ الثابت الشهري للفاتورة
  /// 📊 أساس الربح — تكلفة **الشهر الواحد** اللي الربح بيتحسب عليها.
  ///
  /// ليه منفصل: فاتورة «شهر وشهر» بتنزل ٤٢٥٠ عشان هي بتغطي شهرين، فلو
  /// حسبنا الربح عليها الشهر ده يبان خسران والشهر اللي بعده يبان مكسبان
  /// وهو مش كده. الرقم ده انت اللي بتكتبه بإيدك (مش قسمة تلقائية على ٢،
  /// لأن القسمة مش قاعدة ثابتة في كل الخطوط).
  ///
  /// null = ما اتكتبش لسه → بنرجع لـ [fixedBillAmount] زي ما كان بالظبط،
  /// فمفيش رقم قديم بيتغيّر لوحده. شوف [profitBasis].
  double? profitBillAmount;
  // نظام الفوترة لمراجعة الفواتير فقط (لا علاقة له بحساب الأرباح):
  //   'fixed'     = ثابت: تنزل فاتورة كل شهر
  //   'bimonthly' = شهر وشهر: تنزل فاتورة شهر، والشهر اللي بعده ببلاش
  String billingSystem; // 'fixed' | 'bimonthly'

  /// 📌 مرساة الدورة — الشهر اللي انت مثبّت إن **فاتورة نزلت فيه** ('2026-07').
  ///
  /// دي العلامة الوحيدة اللي بتعلّمها بإيدك، **مرة واحدة بس**. منها البرنامج
  /// يحسب أي شهر — ماضي أو مستقبل — الخط ده دوره ولا لأ، بالتبادل قدّام
  /// ووراء لوحده: فرق زوجي من المرساة = دوره، فردي = ببلاش.
  ///
  /// null = ما اتعلّمش لسه → بنرجع للاستنتاج القديم من [BillingAccount]
  /// زي ما كان بالظبط، فمفيش خط قديم بيتغيّر سلوكه لوحده.
  String? billAnchorMonth;

  /// ⚠️ استثناءات غلطات الشركة — { '2026-08': 'billed' | 'free' }.
  ///
  /// لما الشركة تغلط وتنزّل فاتورتين ورا بعض وتقول لك «هنعوضك الشهر الجاي
  /// ببلاش»، بتعلّم الشهرين دول استثناء. الاستثناء بيغيّر **الشهر ده بس**
  /// وما بيمسّش [billAnchorMonth]، فالدورة الأصلية بترجع لوحدها بعده.
  Map<String, String> billMonthOverrides;

  /// 🔁 كل كام شهر تنزل فاتورة؟ الافتراضي ٢ = «شهر وشهر».
  ///
  /// في خطوط دورتها ٣ شهور أو ٤ (عروض الشركات بتختلف). الرقم ده بيخلّي
  /// نفس المرساة تشتغل مع أي طول دورة من غير منطق جديد.
  ///
  /// ⚠️ بيتحسب بس لما نظام الخط «شهر وشهر». الخط الثابت بينزل كل شهر
  /// مهما كان الرقم ده.
  int billCycleMonths;

  /// 🛑 آخر شهر بتنزل فيه فواتير على الخط ده ('2026-09') — الخط اتقفل بعده.
  ///
  /// من غيره الخط المقفول يفضل طالع في قايمة الفواتير للأبد وانت بتدوّر
  /// على فاتورته كل شهر ومش لاقيها، فتفتكر إن في فاتورة ضايعة.
  ///
  /// null = الخط شغّال عادي. الشهر ده **نفسه** لسه بتنزل فيه فاتورة —
  /// اللي بعده هو اللي بيقف.
  ///
  /// ⚠️ ما بيمسحش أي فاتورة قديمة متسجّلة — التاريخ زي ما هو.
  String? billEndMonth;

  /// ☎️ أرقام الأرضي والهوم 4G المربوطة بالحساب ده — ids العملاء.
  ///
  /// دي بتتختار بإيدك (تعلّم صح على اللي في الحساب من قايمة كل أرقام
  /// الأرضي والهوم 4G في البرنامج)، مش بتتحسب لوحدها، لأن الرقم ممكن يكون
  /// باسم نفس صاحب الخط بس في حساب تاني خالص.
  ///
  /// فايدتها: لما تراجع الفاتورة مع الشركة ويقولوا لك «الزيادة بسبب
  /// الأرضي»، تلاقي رقمه قدامك على طول من غير ما تدوّر.
  List<String> sideNumberIds;
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
  /// 📆 تاريخ آخر فاتورة قابلة للإلغاء — آخر فاتورة على الشركة تقدر تلغي عندها
  /// العرض/الخط (الفاتورة الـ 11 مثلاً). بيسبق [offerEndDate] عادةً وهو
  /// التاريخ العملي اللي بيتاخد عنده القرار.
  String? cancelDeadlineDate;
  double? actualBillAmount; // المبلغ الفعلي للفاتورة (لحساب الربح)
  LineType lineType; // home4g / adsl / guest / mobile

  // ── ملاحظة ثابتة (Sticky Note) ─────────────────────────────
  String? stickyNote;

  // ── آخر فاتورة + مفكرة الخط ────────────────────────────────
  double lastBillAmount; // قيمة آخر فاتورة من الشركة
  double billDebt; // إجمالي الفواتير غير المسددة للشركة
  double billCredit; // رصيد دائن من دفع زيادة — يُخصم من الفواتير الجاية
  List<Map<String, dynamic>> groupNotes; // [{text, date, type:'auto'/'manual'}]
  String? lastNotesMonth; // tracking key for auto-notes

  // ── ربح النقاط الشهري المعلق (لم يُضف للتقرير بعد) ─────────
  double pendingPointsProfit;
  String? lastGiftResetMonth; // YYYY-M — لتصفير giftProfit شهرياً
  String? manualDueDate; // YYYY-MM-DD — موعد سداد الفاتورة اليدوية
  String? parentGroupId; // ربط هذا الخط بخط رئيسي (parent-child linking)

  // ── دليل الخطوط الرئيسية (تصنيف/تشجير) ─────────────────────────
  String? folderId; // null = بدون تصنيف (في جذر الدليل)
  int directoryOrderIndex; // ترتيب الخط بين إخوته جوه نفس الفولدر

  // ── Master Line Refactor (Phase 2) ────────────────────────────
  String? ownerFullName;        // اسم صاحب الخط رباعي
  String? contractPhotoPath;    // مسار صورة العقد
  int mainLineAllocationGb;     // حصة الخط الرئيسي من السعة (للشريط الذكي)
  int totalMinutes;             // إجمالي دقائق الخط (12000 / 10000 حسب الـ tier)
  int totalInternational;       // إجمالي الدقائق الدولية للخط
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
  // قسائم/منح دورية على الخط الرئيسي (كل قسيمة: {id, name, value, dueDate, every, log})
  // every: '6m' | '1y' | 'once' ؛ log: [{date, amount, note}]
  List<Map<String, dynamic>> coupons;

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
    this.accountEmail,
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
    this.profitBillAmount,
    this.billingSystem = 'fixed',
    this.billAnchorMonth,
    Map<String, String>? billMonthOverrides,
    this.billCycleMonths = 2,
    this.billEndMonth,
    List<String>? sideNumberIds,
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
    this.cancelDeadlineDate,
    this.actualBillAmount,
    this.lineType = LineType.home4g,
    this.stickyNote,
    this.lastBillAmount = 0,
    this.billDebt = 0,
    this.billCredit = 0,
    List<Map<String, dynamic>>? groupNotes,
    this.lastNotesMonth,
    this.pendingPointsProfit = 0,
    this.lastGiftResetMonth,
    this.manualDueDate,
    this.parentGroupId,
    this.folderId,
    this.directoryOrderIndex = 0,
    this.ownerFullName,
    this.contractPhotoPath,
    this.mainLineAllocationGb = 0,
    this.totalMinutes = 0,
    this.totalInternational = 0,
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
    List<Map<String, dynamic>>? coupons,
  })  : complaints = complaints ?? [],
        gifts = gifts ?? [],
        pointsRedemptions = pointsRedemptions ?? [],
        groupNotes = groupNotes ?? [],
        extraBundles = extraBundles ?? [],
        coupons = coupons ?? [],
        billMonthOverrides = billMonthOverrides ?? {},
        sideNumberIds = sideNumberIds ?? [];

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
        accountEmail: j['accountEmail'],
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
        profitBillAmount: (j['profitBillAmount'] as num?)?.toDouble(),
        billingSystem: j['billingSystem'] ?? 'fixed',
        billAnchorMonth: j['billAnchorMonth'],
        billMonthOverrides:
            Map<String, String>.from(j['billMonthOverrides'] ?? {}),
        billCycleMonths: (j['billCycleMonths'] as num?)?.toInt() ?? 2,
        billEndMonth: j['billEndMonth'],
        sideNumberIds: List<String>.from(j['sideNumberIds'] ?? []),
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
        cancelDeadlineDate: j['cancelDeadlineDate'],
        actualBillAmount: (j['actualBillAmount'] as num?)?.toDouble(),
        lineType: LineTypeX.fromString(j['lineType']),
        stickyNote: j['stickyNote'],
        lastBillAmount: (j['lastBillAmount'] as num?)?.toDouble() ?? 0,
        billDebt: (j['billDebt'] as num?)?.toDouble() ?? 0,
        billCredit: (j['billCredit'] as num?)?.toDouble() ?? 0,
        groupNotes: List<Map<String, dynamic>>.from(j['groupNotes'] ?? []),
        lastNotesMonth: j['lastNotesMonth'],
        pendingPointsProfit: (j['pendingPointsProfit'] as num?)?.toDouble() ?? 0,
        lastGiftResetMonth: j['lastGiftResetMonth'],
        manualDueDate: j['manualDueDate'],
        parentGroupId: j['parentGroupId'],
        folderId: j['folderId'],
        directoryOrderIndex: (j['directoryOrderIndex'] ?? 0) as int,
        ownerFullName: j['ownerFullName'],
        contractPhotoPath: j['contractPhotoPath'],
        mainLineAllocationGb: (j['mainLineAllocationGb'] ?? 0) as int,
        totalMinutes: (j['totalMinutes'] ?? 0) as int,
        totalInternational: (j['totalInternational'] ?? 0) as int,
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
        coupons: List<Map<String, dynamic>>.from(j['coupons'] ?? []),
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
        'accountEmail': accountEmail,
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
        'profitBillAmount': profitBillAmount,
        'billingSystem': billingSystem,
        'billAnchorMonth': billAnchorMonth,
        'billMonthOverrides': billMonthOverrides,
        'billCycleMonths': billCycleMonths,
        'billEndMonth': billEndMonth,
        'sideNumberIds': sideNumberIds,
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
        'cancelDeadlineDate': cancelDeadlineDate,
        'actualBillAmount': actualBillAmount,
        'lineType': lineType.key,
        'stickyNote': stickyNote,
        'lastBillAmount': lastBillAmount,
        'billDebt': billDebt,
        'billCredit': billCredit,
        'groupNotes': groupNotes,
        'lastNotesMonth': lastNotesMonth,
        'pendingPointsProfit': pendingPointsProfit,
        'lastGiftResetMonth': lastGiftResetMonth,
        'manualDueDate': manualDueDate,
        'parentGroupId': parentGroupId,
        'folderId': folderId,
        'directoryOrderIndex': directoryOrderIndex,
        'ownerFullName': ownerFullName,
        'contractPhotoPath': contractPhotoPath,
        'mainLineAllocationGb': mainLineAllocationGb,
        'totalMinutes': totalMinutes,
        'totalInternational': totalInternational,
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
        'coupons': coupons,
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

  /// قيمة النقاط الشهرية الثابتة (عدد النقاط الشهري × سعر النقطة) — تُستخدم في
  /// حساب ربح المجموعة بدل المتراكم. صفر لو مش متحدد.
  double get monthlyPointsValue =>
      (pointsMonthly ?? 0) * (pointPrice ?? 0);

  /// عدد الأيام المتبقية لانتهاء العرض (null لو مفيش تاريخ)
  int? get daysUntilOfferEnd {
    final date = offerEndDate;
    if (date == null) return null;
    final end = DateTime.tryParse(date);
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }

  /// عدد الأيام المتبقية على آخر فاتورة قابلة للإلغاء (null لو مفيش تاريخ).
  /// سالب = التاريخ فات وبقيت مش قادر تلغي.
  int? get daysUntilCancelDeadline {
    final date = cancelDeadlineDate;
    if (date == null) return null;
    final end = DateTime.tryParse(date);
    if (end == null) return null;
    final now = DateTime.now();
    return end.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// هل إحنا جوه نافذة التنبيه بالإلغاء (آخر شهرين قبل التاريخ)؟
  bool get isCancelCountdownActive {
    final days = daysUntilCancelDeadline;
    return days != null && days <= 60 && days >= 0;
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

  /// هل الخط نظامه «شهر وشهر»؟ (فاتورة شهر، والشهر اللي بعده ببلاش)
  bool get isBimonthly => billingSystem == 'bimonthly';

  /// هل الخط ده متعلّم عليه دورة (فيه مرساة)؟
  bool get hasBillAnchor =>
      billAnchorMonth != null && billAnchorMonth!.isNotEmpty;

  /// 🔁 الشهر اللي الدورة بتتحسب منه فعلاً.
  ///
  /// الترتيب: المرساة اللي علّمتها بإيدك من قايمة الفواتير أولاً، وبعدها
  /// «تاريخ آخر فاتورة نزلت» اللي كاتبه في تعديل المجموعة. كده اللي
  /// بتظبطه في المجموعة يوصل للفواتير لوحده من غير ما تعلّمه مرتين.
  ///
  /// null = مفيش أي تاريخ نعرف منه، فالخط لسه «مش عارفينه».
  String? get effectiveBillAnchor =>
      hasBillAnchor ? billAnchorMonth : monthOf(lastBillDate);

  /// هل الدورة اتحسبت من تاريخ المجموعة مش من تعليم بإيدك؟
  bool get anchorFromGroupDate =>
      !hasBillAnchor && monthOf(lastBillDate) != null;

  /// 📅 يحوّل تاريخ مكتوب بأي شكل لشهر 'yyyy-mm' — بيقبل «2026-7» و
  /// «2026-07» و «2026-07-01». بيرجّع null لو مش مفهوم.
  static String? monthOf(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^\s*(\d{4})\s*-\s*(\d{1,2})').firstMatch(raw.trim());
    if (m == null) return null;
    final mm = int.tryParse(m.group(2)!);
    if (mm == null || mm < 1 || mm > 12) return null;
    return '${m.group(1)}-${mm.toString().padLeft(2, '0')}';
  }

  /// عدد الشهور بين شهرين بصيغة 'yyyy-mm' — null لو أي واحد فيهم شكله غلط.
  static int? monthsBetween(String from, String to) {
    final a = from.split('-'), b = to.split('-');
    if (a.length < 2 || b.length < 2) return null;
    final ay = int.tryParse(a[0]), am = int.tryParse(a[1]);
    final by = int.tryParse(b[0]), bm = int.tryParse(b[1]);
    if (ay == null || am == null || by == null || bm == null) return null;
    return (by - ay) * 12 + (bm - am);
  }

  /// 🔁 هل دور الخط ده ينزّل فاتورة في [month]؟
  ///
  /// الترتيب: الاستثناء اليدوي أولاً (غلطات الشركة)، بعده المرساة، وآخر
  /// حاجة null معناها «مش عارفين» → اللي بيسأل يرجع لطريقته القديمة.
  ///
  ///   * خط ثابت → دايماً true (بينزل كل شهر).
  ///   * شهر وشهر بمرساة → الفرق الزوجي عن المرساة = دوره.
  bool? isDueIn(String month) {
    final ov = billMonthOverrides[month];
    if (ov == 'billed') return true;
    if (ov == 'free') return false;
    // 🛑 الخط اتقفل → مفيش فواتير بعد كده، سواء ثابت أو شهر وشهر.
    //
    // ⚠️ بييجي **بعد** الاستثناء عن قصد: لو علّمت «نزلت غصب عني» على شهر
    // بعد القفل، يبقى الشركة فعلاً نزّلت فاتورة على خط مقفول — وده بالظبط
    // اللي انت عايز تشوفه، مش نخبّيه.
    if (isClosedIn(month)) return false;
    if (!isBimonthly) return true;
    // المرساة اللي علّمتها بإيدك أولاً، وبعدها «تاريخ آخر فاتورة نزلت» اللي
    // كاتبه في تعديل المجموعة — عشان اللي بتظبطه هناك يوصل للفواتير لوحده
    // من غير ما تعلّم نفس الحاجة مرتين.
    final anchor = effectiveBillAnchor;
    if (anchor == null) return null;
    final gap = monthsBetween(anchor, month);
    if (gap == null) return null;
    // كل [billCycleMonths] شهر تنزل فاتورة. الافتراضي ٢ («شهر وشهر»)،
    // والقسمة على الرقم ده بتشتغل مع أي طول دورة — ٣ شهور أو ٤.
    // بنستخدم `%` مع تصحيح للسالب عشان الحساب يمشي **ورا** كمان مش
    // قدّام بس (شهر قبل المرساة لازم يطلع صح).
    final n = billCycleMonths;
    return ((gap % n) + n) % n == 0;
  }

  /// 🛑 الخط كان مقفول في الشهر ده؟ (يعني بعد [billEndMonth]).
  ///
  /// شهر القفل نفسه **لسه بتنزل فيه فاتورة** — اللي بعده هو اللي بيقف.
  bool isClosedIn(String month) {
    final end = billEndMonth;
    if (end == null || end.isEmpty) return false;
    final gap = monthsBetween(end, month);
    return gap != null && gap > 0;
  }

  /// الخط مقفول خلاص (النهاردة بعد شهر القفل)؟
  bool get isClosedLine {
    final end = billEndMonth;
    if (end == null || end.isEmpty) return false;
    final now = DateTime.now();
    return isClosedIn('${now.year}-${now.month.toString().padLeft(2, '0')}');
  }

  /// 🎫 قيمة القسيمة موزّعة على **الشهر الواحد**.
  ///
  /// القسيمة بتنزل كل ٦ شهور أو كل سنة، مش كل شهر. فلو حسبناها كاملة في
  /// شهر واحد، الشهر ده يبان مكسبان بجد والباقي خسران — وهو نفس الفلوس.
  /// التوزيع بيدّي رقم تقدر تبني عليه.
  double get voucherMonthlyValue {
    if (voucherValue <= 0) return 0;
    final months = voucherPeriod == '1y' ? 12 : 6;
    return voucherValue / months;
  }

  /// هل الشهر ده متعدّل بإيدك بسبب غلطة من الشركة؟
  bool isOverriddenIn(String month) => billMonthOverrides.containsKey(month);

  /// 📊 التكلفة اللي الربح بيتحسب عليها — **تكلفة الشهر الواحد**.
  ///
  /// لو [profitBillAmount] متكتوب بنستخدمه. لو لأ بنرجع لـ
  /// [fixedBillAmount] زي السلوك القديم بالظبط، فمفيش رقم ربح قديم
  /// بيتغيّر لوحده لحد ما تدخل تكتب الأساس بنفسك.
  double get profitBasis => profitBillAmount ?? fixedBillAmount;

  /// تكلفة الخط في شاشات الربح والتقارير: أساس الربح، ولو مش متكتوب
  /// خالص بنقع على آخر فاتورة فعلية بدل ما نعرض صفر.
  double get profitCost =>
      profitBasis > 0 ? profitBasis : (actualBillAmount ?? 0);

  /// اقتراح أساس الربح لخط «شهر وشهر» = الفاتورة الكبيرة ÷ ٢.
  /// **اقتراح بس** — بيتعرض في زرار في شاشة التعديل ومابيتطبّقش لوحده،
  /// لأن القسمة على ٢ مش قاعدة صحيحة في كل الخطوط.
  double get suggestedProfitBasis =>
      isBimonthly ? fixedBillAmount / 2 : fixedBillAmount;

  /// هل الخط ده لسه محتاج تحدّدله أساس ربح؟ (شهر وشهر وما اتكتبش)
  /// بنستخدمها عشان نبيّن تنبيه: الربح دلوقتي بيتحسب على الفاتورة الكبيرة.
  bool get needsProfitBasis =>
      isBimonthly && profitBillAmount == null && fixedBillAmount > 0;
}

class Member {
  String id;
  String gid;
  String name;
  String? nickname; // كنية/نداء العميل في الرسائل (لو فاضي نستخدم name)
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
  int internationalAllocation; // الدقائق الدولية المخصصة لهذا العميل
  // سجل تذكيرات المديونية: كل عنصر {ts: epoch ms, ch: 'wa_debt'|'wa_statement'|'sms'|'manual'}
  List<Map<String, dynamic>> reminderLog;

  Member({
    required this.id,
    required this.gid,
    required this.name,
    this.nickname,
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
    this.internationalAllocation = 0,
    List<Map<String, dynamic>>? reminderLog,
  })  : log = log ?? [],
        files = files ?? [],
        invoiceLog = invoiceLog ?? [],
        reminderLog = reminderLog ?? [];

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'].toString(),
        gid: j['gid'].toString(),
        name: j['name'] ?? '',
        nickname: j['nickname'],
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
        internationalAllocation: (j['internationalAllocation'] ?? 0) as int,
        reminderLog: List<Map<String, dynamic>>.from(j['reminderLog'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'gid': gid,
        'name': name,
        'nickname': nickname,
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
        'internationalAllocation': internationalAllocation,
        'reminderLog': reminderLog,
      };

  /// عدد تذكيرات المديونية في الشهر الحالي (العداد بيتصفّر كل شهر)
  int get reminderCountThisMonth {
    final now = DateTime.now();
    return reminderLog.where((e) {
      final ts = (e['ts'] ?? 0) as int;
      if (ts == 0) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return d.year == now.year && d.month == now.month;
    }).length;
  }

  bool get hasDebt => balance < 0;
  bool get isClear => balance >= 0 && price > 0;
  bool get isZero => price == 0;

  /// دقائق العميل الفعّالة: لو محددة يدوياً نستخدمها، وإلا الافتراضي 1500 دقيقة.
  /// (الأرضي/الهوم 4G ملهمش دقائق من الباقة)
  int get effectiveMinutes {
    if (type == 'landline' || type == 'homeforgee') return 0;
    return minutesAllocation > 0 ? minutesAllocation : 1500;
  }

  /// نداء العميل في الرسائل: الكنية لو موجودة، وإلا الاسم.
  String get salutation =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname!.trim() : name;

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
  double? maxDebt;        // حد الكفالة الأقصى (لو null = بدون حد)
  String? lastRemindedAt; // آخر تذكير (ISO 8601)
  List<Map<String, dynamic>> log; // سجل الكفيل: مدفوعات/أحداث بالتاريخ

  Guarantor({
    required this.id,
    required this.name,
    required this.phone,
    this.phone2,
    this.type = 'personal',
    this.natId,
    this.notes,
    this.maxDebt,
    this.lastRemindedAt,
    List<Map<String, dynamic>>? log,
  }) : log = log ?? [];

  factory Guarantor.fromJson(Map<String, dynamic> j) => Guarantor(
        id: j['id'].toString(),
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        phone2: j['phone2'],
        type: j['type'] ?? 'personal',
        natId: j['natId'],
        notes: j['notes'],
        maxDebt: (j['maxDebt'] as num?)?.toDouble(),
        lastRemindedAt: j['lastRemindedAt'],
        log: (j['log'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'phone2': phone2,
        'type': type,
        'natId': natId,
        'notes': notes,
        'maxDebt': maxDebt,
        'lastRemindedAt': lastRemindedAt,
        'log': log,
      };

  /// إجمالي المدفوعات المسجّلة على الكفيل
  double get totalPaid => log
      .where((e) => e['type'] == 'payment')
      .fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

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
  String? deferralDate; // تأجيل الدفع حتى (YYYY-MM-DD)
  String? deferralNote; // سبب التأجيل

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
    this.deferralDate,
    this.deferralNote,
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
        deferralDate: j['deferralDate'],
        deferralNote: j['deferralNote'],
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
        'deferralDate': deferralDate,
        'deferralNote': deferralNote,
      };

  /// السعر الفعلي للباقة (يستخدم packagePrice إن وُجد، وإلا rent)
  double get effectivePrice => packagePrice > 0 ? packagePrice : rent;

  double get debt => balance < 0 ? -balance : 0;
  bool get hasDebt => balance < 0;
  bool get isDeferred => deferralDate != null;
  /// سدّد جزئي: عليه دين + عمل دفعة واحدة على الأقل في السجل
  bool get partlyPaid =>
      hasDebt && log.any((e) => (e['amount'] ?? 0).toDouble() > 0);
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
  String? time; // الساعة (HH:mm) — لتسجيل الدفعة الجزئية بالتاريخ والساعة
  String? note;

  BillPayment(
      {required this.id,
      required this.amount,
      required this.date,
      this.time,
      this.note});

  factory BillPayment.fromJson(Map<String, dynamic> j) => BillPayment(
        id: j['id'].toString(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: j['date'] ?? '',
        time: j['time'],
        note: j['note'],
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'date': date, 'time': time, 'note': note};
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
  String? deferDate;   // YYYY-MM-DD — ميعاد السماح المؤجَّل من الشركة
  String? deferNote;   // سبب/ملاحظة التأجيل
  // سجل تعديلات المبلغ: [{oldAmount, newAmount, reason, date}] — عشان تقدر
  // ترجع تشوف ليه اتغيّر رقم الفاتورة بعد ما كان متسجل.
  List<Map<String, dynamic>> editHistory;

  // ── 🧾 مطالبة على الشركة (اختيارية بالكامل) ────────────────────────
  /// المبلغ اللي انت شايف إن الشركة غلطانة فيه — المفروض ٥٠٠٠ ونزلت ٥٣٠٠
  /// يبقى ٣٠٠. بتكتبه بإيدك، وما لوش أي دعوة بحساب دور الشهر اللي بعده.
  double disputeAmount;
  /// سبب المطالبة بكلامك — «كلمت الشركة، قالوا هيعوضوني».
  String? disputeNote;
  /// اتقفلت خلاص (اترجعت أو اتعوّضت)؟
  bool disputeResolved;

  /// فيها مطالبة مفتوحة لسه؟
  bool get hasOpenDispute => disputeAmount > 0 && !disputeResolved;

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
    this.deferDate,
    this.deferNote,
    List<Map<String, dynamic>>? editHistory,
    this.disputeAmount = 0,
    this.disputeNote,
    this.disputeResolved = false,
  })  : payments = payments ?? [],
        editHistory = editHistory ?? [];

  /// مؤجَّلة فعلاً (فيها ميعاد سماح لسه ما عداش وغير مسددة)
  bool get isDeferred => deferDate != null && deferDate!.isNotEmpty && !isPaid;

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
        deferDate: j['deferDate'],
        deferNote: j['deferNote'],
        editHistory: List<Map<String, dynamic>>.from(j['editHistory'] ?? []),
        disputeAmount: (j['disputeAmount'] as num?)?.toDouble() ?? 0,
        disputeNote: j['disputeNote'],
        disputeResolved: j['disputeResolved'] ?? false,
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
        'deferDate': deferDate,
        'deferNote': deferNote,
        'editHistory': editHistory,
        'disputeAmount': disputeAmount,
        'disputeNote': disputeNote,
        'disputeResolved': disputeResolved,
      };
}

/// Phase 5: ملاحظة عامة للشغل — مستقلة عن الخطوط
class GeneralNote {
  String id;
  String content;
  DateTime createdAt;
  DateTime? reminderTime;
  bool isCompleted;
  bool archived;        // الحذف من الفقاعة = أرشفة (مش مسح نهائي)
  DateTime? archivedAt; // وقت الأرشفة
  bool pinned;          // 📌 مثبتة — تظهر أول القائمة
  String color;         // 🎨 'yellow' عادي | 'red' عاجل | 'green' شغل
  String? memberId;     // 👤 ربط بعميل — الضغط يفتح ملفه
  String? memberName;   // اسم العميل وقت الربط (للعرض السريع)
  String repeat;        // 🔁 'none' | 'daily' | 'weekly' | 'monthly'
  DateTime? completedAt; // وقت الإكمال — للأرشفة التلقائية بعد أسبوع

  GeneralNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.reminderTime,
    this.isCompleted = false,
    this.archived = false,
    this.archivedAt,
    this.pinned = false,
    this.color = 'yellow',
    this.memberId,
    this.memberName,
    this.repeat = 'none',
    this.completedAt,
  });

  /// التذكير فات معاده ولسه الملاحظة شغالة؟ (المتكرر مبيفوتش معاده)
  bool get isOverdue =>
      !isCompleted &&
      !archived &&
      repeat == 'none' &&
      reminderTime != null &&
      reminderTime!.isBefore(DateTime.now());

  /// عندها تذكير النهارده (لسه جاي)؟ — لنبض الفقاعة
  bool get isDueToday {
    if (isCompleted || archived || reminderTime == null) return false;
    final now = DateTime.now();
    final r = reminderTime!;
    if (repeat == 'daily') return true;
    if (repeat == 'weekly') return r.weekday == now.weekday;
    if (repeat == 'monthly') return r.day == now.day;
    return r.year == now.year && r.month == now.month && r.day == now.day;
  }

  factory GeneralNote.fromJson(Map<String, dynamic> j) => GeneralNote(
        id: j['id'].toString(),
        content: j['content'] ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        reminderTime: j['reminderTime'] != null
            ? DateTime.tryParse(j['reminderTime'])
            : null,
        isCompleted: j['isCompleted'] ?? false,
        archived: j['archived'] ?? false,
        archivedAt: j['archivedAt'] != null
            ? DateTime.tryParse(j['archivedAt'])
            : null,
        pinned: j['pinned'] ?? false,
        color: j['color'] ?? 'yellow',
        memberId: j['memberId'],
        memberName: j['memberName'],
        repeat: j['repeat'] ?? 'none',
        completedAt: j['completedAt'] != null
            ? DateTime.tryParse(j['completedAt'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'reminderTime': reminderTime?.toIso8601String(),
        'isCompleted': isCompleted,
        'archived': archived,
        'archivedAt': archivedAt?.toIso8601String(),
        'pinned': pinned,
        'color': color,
        'memberId': memberId,
        'memberName': memberName,
        'repeat': repeat,
        'completedAt': completedAt?.toIso8601String(),
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

// ── دليل الخطوط الرئيسية: فولدر/تصنيف قابل للتعشيش (تشجير) ──────────
class GroupFolder {
  String id;
  String name;
  String? parentFolderId; // null = فولدر جذر
  int orderIndex; // ترتيب الفولدر بين إخوته
  String? emoji;

  GroupFolder({
    required this.id,
    required this.name,
    this.parentFolderId,
    this.orderIndex = 0,
    this.emoji,
  });

  factory GroupFolder.fromJson(Map<String, dynamic> j) => GroupFolder(
        id: j['id'].toString(),
        name: j['name'] ?? '',
        parentFolderId: j['parentFolderId'],
        orderIndex: (j['orderIndex'] ?? 0) as int,
        emoji: j['emoji'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentFolderId': parentFolderId,
        'orderIndex': orderIndex,
        'emoji': emoji,
      };
}

// ── حساب فوترة: مجموعة خطوط بتتبادل نزول الفاتورة بينهم (شقّين) ──────
class BillingAccount {
  String id;
  String name;
  List<String> shiftA; // ids الخطوط في الشق الأول
  List<String> shiftB; // ids الخطوط في الشق التاني
  // مين الدور عليه لما مفيش تاريخ فواتير كفاية نحدد منه تلقائي (أول مرة)
  bool shiftAIsCurrent;
  int orderIndex;

  /// 📌 تثبيت الدور بإيدك — بيغلب الاستنتاج التلقائي.
  ///
  /// انت بتقول مرة واحدة «شهر ٨ الدور على الشق الأول» والبرنامج يكمّل
  /// بالتبادل قدّام وورا لوحده، فمش هتقعد تكتبه كل شهر. الاستنتاج من
  /// تاريخ الفواتير بيغلط لما شهر يعدّي من غير ما تسجّل فيه، وساعتها
  /// الدور بيتقلب غلط وميعادش يظبط لوحده — التثبيت هو اللي بيصلّحه.
  ///
  /// null = مفيش تثبيت، اشتغل بالاستنتاج زي الأول بالظبط.
  String? turnPinMonth; // '2026-08'
  bool turnPinIsShiftA; // الدور على الشق الأول في الشهر المثبّت

  BillingAccount({
    required this.id,
    required this.name,
    List<String>? shiftA,
    List<String>? shiftB,
    this.shiftAIsCurrent = true,
    this.orderIndex = 0,
    this.turnPinMonth,
    this.turnPinIsShiftA = true,
  })  : shiftA = shiftA ?? [],
        shiftB = shiftB ?? [];

  factory BillingAccount.fromJson(Map<String, dynamic> j) => BillingAccount(
        id: j['id'].toString(),
        name: j['name'] ?? '',
        shiftA: List<String>.from(j['shiftA'] ?? []),
        shiftB: List<String>.from(j['shiftB'] ?? []),
        shiftAIsCurrent: j['shiftAIsCurrent'] ?? true,
        orderIndex: (j['orderIndex'] ?? 0) as int,
        turnPinMonth: j['turnPinMonth'] as String?,
        turnPinIsShiftA: j['turnPinIsShiftA'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shiftA': shiftA,
        'shiftB': shiftB,
        'shiftAIsCurrent': shiftAIsCurrent,
        'orderIndex': orderIndex,
        'turnPinMonth': turnPinMonth,
        'turnPinIsShiftA': turnPinIsShiftA,
      };
}

class AppDB {
  List<Group> groups;
  List<GroupFolder> groupFolders;
  List<BillingAccount> billingAccounts;
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
  /// شهور مراجعة فواتير الشركات المقفولة بعد المراجعة الكاملة ('YYYY-MM')
  List<String> lockedBillMonths;
  /// أرشيف تلقائي لملخص كل شهر وقت ما اتقفل (متوقع/فعلي/ناقص)
  List<Map<String, dynamic>> billArchives;
  int gid;
  int mid;

  /// آخر وقت اتعدّلت فيه الداتا (epoch ms) — يُستخدم لحسم المزامنة بالوقت
  /// بدل العدد. أحدث نسخة زمنياً هي اللي تكسب.
  int updatedAt;

  AppDB({
    List<Group>? groups,
    List<GroupFolder>? groupFolders,
    List<BillingAccount>? billingAccounts,
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
    List<String>? lockedBillMonths,
    List<Map<String, dynamic>>? billArchives,
    this.gid = 1,
    this.mid = 1,
    this.updatedAt = 0,
  })  : groups = groups ?? [],
        groupFolders = groupFolders ?? [],
        billingAccounts = billingAccounts ?? [],
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
        billingLocks = billingLocks ?? {},
        lockedBillMonths = lockedBillMonths ?? [],
        billArchives = billArchives ?? [];

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
        groupFolders: (j['groupFolders'] as List? ?? [])
            .map((e) => GroupFolder.fromJson(e))
            .toList(),
        billingAccounts: (j['billingAccounts'] as List? ?? [])
            .map((e) => BillingAccount.fromJson(e))
            .toList(),
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
        lockedBillMonths: List<String>.from(j['lockedBillMonths'] ?? []),
        billArchives: List<Map<String, dynamic>>.from(j['billArchives'] ?? []),
        gid: j['gid'] ?? 1,
        mid: j['mid'] ?? 1,
        updatedAt: j['updatedAt'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'groups': groups.map((e) => e.toJson()).toList(),
        'groupFolders': groupFolders.map((e) => e.toJson()).toList(),
        'billingAccounts': billingAccounts.map((e) => e.toJson()).toList(),
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
        'lockedBillMonths': lockedBillMonths,
        'billArchives': billArchives,
        'gid': gid,
        'mid': mid,
        'updatedAt': updatedAt,
      };

  // ─── 📅 تأريخ الفاتورة: يوم النزول ≠ الفترة المغطّاة ──────────
  //
  // دول حاجتين مختلفين والبرنامج كان بيخلطهم في خانة واحدة:
  //   • فاتورة ١/٥ = نزلت يوم ١ شهر ٥، وبتغطي شهر ٤ **كله**.
  //   • فاتورة ١٥/٥ = نزلت يوم ١٥، وبتغطي من ١٥/٤ لـ ١٥/٥ — دي سيكل ٢.
  //
  // السيكل هو اللي بيحدد أنهي حالة، عشان كده الدالتين دول بيسألوا الخط.

  /// هل الخط سيكله في نص الشهر (يوم ١٥ = سيكل ٢)؟
  bool groupIsMidCycle(Group g) =>
      g.billingCycle == 'mid' ||
      g.billingCycle == 'cycle2' ||
      (g.billingCycle == null && g.cycle == '2');

  /// وسم النزول زي ما بتقوله بلسانك: «فاتورة 1/5».
  /// بيتاخد من `date` (تاريخ النزول الفعلي) مش من `month`.
  String billIssueLabel(CompanyBill b) {
    final p = b.date.split('/');
    if (p.length < 2) return 'فاتورة ${b.month}';
    return 'فاتورة ${p[0]}/${p[1]}';
  }

  /// الفترة اللي الفاتورة بتغطيها — الفاتورة دايماً بتغطي اللي **فات**.
  /// بيرجّع نص فاضي لو الشهر مش مقروء.
  String billCoveredPeriod(CompanyBill b) {
    final mp = b.month.split('-');
    if (mp.length < 2) return '';
    final y = int.tryParse(mp[0]);
    final m = int.tryParse(mp[1]);
    if (y == null || m == null) return '';
    final prev = DateTime(y, m - 1); // بيلف السنة لوحده لو الشهر ١
    final g = groups.firstWhere((x) => x.id == b.groupId,
        orElse: () => Group(id: '', phone: ''));
    if (groupIsMidCycle(g)) {
      // يوم النزول الحقيقي أدق من الافتراضي، فلو مكتوب نستخدمه
      final day = int.tryParse(b.date.split('/').first) ?? 15;
      return 'بتغطي من $day/${prev.month} لـ $day/$m';
    }
    return 'بتغطي شهر ${prev.month} كله';
  }

  // ─── حماية الشهور ────────────────────────────────────────────
  //
  // أرقام المجموعة (actualBillAmount / lastBillAmount) معناها «آخر فاتورة
  // نزلت». عشان كده تعديل فاتورة شهر قديم ما يصحّش يكتب عليها، وإلا البرنامج
  // يفتكر إن مبلغ شهر ٥ هو فاتورة النهاردة وتلاقي أرقام الشهر الحالي اتغيّرت.
  //
  // المديونية (billDebt) مستثناة عن قصد: لو صحّحت فاتورة قديمة من ١٠٠٠ لـ
  // ١٢٠٠ فانت فعلاً بقيت مدين بـ ٢٠٠ زيادة، والفرق ده لازم يتحسب مهما كان شهرها.

  /// أحدث شهر متسجّل فيه فاتورة للخط [gid]، مع تجاهل الفاتورة [exceptId].
  /// بيرجّع null لو مفيش فواتير. صيغة الشهر «2026-08» مضبوطة بصفر بادئ،
  /// فالمقارنة النصية بتدّي ترتيب زمني صحيح من غير ما نحلّل تواريخ.
  String? latestBillMonth(String gid, {String? exceptId}) {
    String? top;
    for (final b in companyBills) {
      if (b.groupId != gid) continue;
      if (exceptId != null && b.id == exceptId) continue;
      if (top == null || b.month.compareTo(top) > 0) top = b.month;
    }
    return top;
  }

  /// هل [bill] هي أحدث فاتورة لخطها؟ يعني تعديلها المفروض يتعكس على
  /// أرقام المجموعة. لو فاتورة شهر قديم → false ونسيب المجموعة زي ما هي.
  bool isLatestBill(CompanyBill bill) =>
      monthIsLatestFor(bill.groupId, bill.month, exceptId: bill.id);

  /// نفس الفكرة بالشهر بس — للاستخدام **قبل** ما الفاتورة تتضاف للّستة،
  /// وإلا الفاتورة الجديدة بتقارن نفسها بنفسها وتطلع دايماً «الأحدث».
  bool monthIsLatestFor(String gid, String month, {String? exceptId}) {
    final top = latestBillMonth(gid, exceptId: exceptId);
    return top == null || month.compareTo(top) >= 0;
  }

  // ─── Stats ───────────────────────────────────────────────────
  double get totalDebt =>
      members.fold(0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));

  // ═══════════════════════════════════════════════════════════════════
  // 🤝 توزيع دفعة الكفيل
  // ═══════════════════════════════════════════════════════════════════

  /// 🤝 يوزّع دفعة الكفيل على العملاء اللي تحته.
  ///
  /// **المشكلة اللي بيحلّها:** التوزيع القديم كان بيقسم المبلغ **بالتساوي**
  /// على كل الأعضاء — حتى اللي ماعليهوش حاجة. فلو تلاتة تحت الكفيل، واحد
  /// منهم مسدّد، ودفعت ١٦٥٠: الـ٥٥٠ بتاعته بتتحوّل **رصيد ليه** بدل ما
  /// تروح لدين حد تاني. يعني تدفع ٣٣٠٠ والدين ينزل ١٥٩٠ بس، والباقي
  /// يتحوّل أرصدة لناس ماعليهاش حاجة. ده اللي كان بيلخبط الحسابات.
  ///
  /// دلوقتي:
  ///   • **اللي ماعليهوش دين مابياخدش حاجة** — أول قاعدة.
  ///   • كل مدين بياخد **بنسبة دينه** من المبلغ.
  ///   • **محدش بياخد أكتر من اللي عليه** — الزيادة بترجع للباقي.
  ///   • لو فضلت زيادة بعد ما الكل خلص، بترجع في `leftover` عشان تفضل
  ///     عند الكفيل بدل ما تتحط رصيد لحد.
  ///
  /// [mode]:
  ///   `proportional` — بالتناسب مع الدين (الافتراضي)
  ///   `oldestFirst`  — يخلّص واحد واحد بالترتيب
  ///
  /// بيرجّع التوزيع لكل عميل + الزيادة. **مابيغيّرش أي حاجة** — الحساب بس،
  /// عشان تقدر تعرضه معاينة قبل ما تأكّد.
  ({Map<String, double> shares, double leftover}) splitGuarantorPayment(
    String guarantorPhone,
    double amount, {
    String mode = 'proportional',
  }) {
    if (amount <= 0) return (shares: <String, double>{}, leftover: 0);

    // المدينين بس — ترتيبهم بالأكبر ديناً عشان `oldestFirst` يبقى ثابت
    final debtors = members
        .where((m) => m.guarantorPhone == guarantorPhone && m.balance < 0)
        .toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));

    if (debtors.isEmpty) {
      return (shares: <String, double>{}, leftover: amount);
    }

    final debts = {for (final m in debtors) m.id: -m.balance};
    final totalDebt = debts.values.fold<double>(0, (s, v) => s + v);

    // المبلغ أكبر من الدين كله؟ كل واحد ياخد دينه والباقي يفضل عند الكفيل
    if (amount >= totalDebt) {
      return (shares: debts, leftover: amount - totalDebt);
    }

    final shares = <String, double>{};

    if (mode == 'oldestFirst') {
      var rest = amount;
      for (final m in debtors) {
        if (rest <= 0) break;
        final take = rest >= debts[m.id]! ? debts[m.id]! : rest;
        shares[m.id] = take;
        rest -= take;
      }
      return (shares: shares, leftover: 0);
    }

    // بالتناسب: كل واحد ياخد نسبة دينه من الإجمالي.
    //
    // ⚠️ آخر واحد بياخد **الباقي** بدل حصته المحسوبة. السبب: القسمة
    // بتسيب كسور (٣٣.٣٣٣...)، ولو جمعنا الحصص المقرّبة الناتج بيطلع
    // ناقص أو زايد قرش أو اتنين عن المبلغ اللي دفعته فعلاً — والفرق ده
    // بيفضل يتراكم مع كل دفعة لحد ما الأرقام تبقى مش مطابقة لأي حاجة.
    var assigned = 0.0;
    for (var i = 0; i < debtors.length; i++) {
      final m = debtors[i];
      final isLast = i == debtors.length - 1;
      final share = isLast
          ? amount - assigned
          : (debts[m.id]! / totalDebt) * amount;
      shares[m.id] = share;
      assigned += share;
    }
    return (shares: shares, leftover: 0);
  }

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
    // أرباح الهدايا + النقاط الشهرية الثابتة (نفس منطق ربح المجموعة عشان يطابق البادجات)
    final giftProfits   = groups.fold<double>(0, (s, g) => s + g.giftProfit);
    final pointsProfits = groups.fold<double>(0, (s, g) => s + g.monthlyPointsValue);
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

  // ⚡ فهرس العملاء حسب المجموعة.
  //
  // `membersOf` كانت بتلف على **كل** العملاء في كل نداء، وبتتنادى ٣١ مرة
  // في البرنامج — وفي رسمة واحدة للشاشة بتتنادى مرات كتير لكل خط (الديون
  // والربح والعدد). يعني عملاء × خطوط في كل رسمة.
  //
  // الفهرس بيتمسح مع كل `notifyListeners` (شوف AppProvider) — يعني أي
  // تعديل بيوصل للشاشة بيمسحه، فمستحيل يفضل قديم وانت شايف بيانات جديدة.
  Map<String, List<Member>>? _byGid;
  void invalidateMembersIndex() => _byGid = null;

  List<Member> membersOf(String gid) {
    final idx = _byGid ??= () {
      final m = <String, List<Member>>{};
      for (final x in members) {
        (m[x.gid] ??= <Member>[]).add(x);
      }
      return m;
    }();
    // نسخة جديدة كل مرة: في أماكن بتعمل `membersOf(id)..sort(...)` والترتيب
    // ده كان هيبوّظ الفهرس المشترك لو رجّعنا نفس اللستة.
    return List<Member>.of(idx[gid] ?? const <Member>[]);
  }
  double groupDebt(String gid) =>
      membersOf(gid).fold(0, (s, m) => s + (m.balance < 0 ? -m.balance : 0));
  double groupBalance(String gid) =>
      membersOf(gid).fold(0, (s, m) => s + m.balance);

  /// السعر الافتراضي للعميل الزيادة لو مش متحدد على الخط (125 ج لكل عميل)
  static const double defaultExtraClientFee = 125;

  /// عدد خطوط الزيادة القابلة للخصم حسب الحد الأقصى للأفراد ونوع الخط
  int groupExtraLines(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    // لازم يكون فيه حد أقصى للأفراد عشان نعرف مين «زيادة».
    // السعر مش شرط يكون متحدد — لو مش متحدد بنستخدم الافتراضي (125 ج).
    if (g.maxClients == null) return 0;
    if (g.lineType == LineType.home4g || g.lineType == LineType.adsl) {
      return 0;
    }
    // خطوط الأرضي (landline) والهوم 4G (homeforgee) مجانية من الشركة — تُحسب موبايل (regular) فقط
    final count = membersOf(gid).where((m) => m.type == 'regular').length;
    return count > g.maxClients! ? count - g.maxClients! : 0;
  }

  /// إجمالي رسوم الخطوط الإضافية القابلة للخصم (السعر المحدد أو 125 ج افتراضياً)
  double groupExtraLineFee(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final fee = (g.extraClientFee != null && g.extraClientFee! > 0)
        ? g.extraClientFee!
        : defaultExtraClientFee;
    return groupExtraLines(gid) * fee;
  }

  /// ربح مجموعة — يعتمد حصراً على [Group.profitBasis] (تكلفة الشهر الواحد).
  /// actualBillAmount هو للعرض والتذكير فقط ولا يدخل في حساب الربح أبداً.
  /// Phase 3: نخصم تكلفة الباقات الإضافية المؤقتة للشهر الحالي
  double groupProfit(String gid) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final income = membersOf(gid).fold<double>(0, (s, m) => s + m.price);
    // أساس الربح = تكلفة الشهر الواحد، مش رقم الفاتورة الكبيرة
    final cost = g.profitBasis;
    if (cost <= 0 && g.type != 'manual') return 0; // لا تكلفة محددة → لا ربح محسوب
    // سعر العميل الإضافي يُحسب حسب إعدادات الخط (الحد الأقصى + السعر)،
    // مش حسب نوع 3800/1800 — groupExtraLineFee بيرجّع صفر لو مفيش إعدادات.
    final extraFee = groupExtraLineFee(gid);
    // تكلفة الباقات الإضافية المؤقتة لهذا الشهر
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final extraBundleCost = g.extraCostThisMonth(month);
    return income - cost - extraFee - extraBundleCost;
  }

  /// 🧾 إجمالي المطالبات المفتوحة على الشركة — «الشركة عليها لك كام».
  ///
  /// دي الأرقام اللي انت سجّلتها بإيدك على الفواتير الغلط. لو مجمّعتش
  /// في رقم واحد، بتفضل متفرّقة على عشرين فاتورة ومحدش بيتابعها،
  /// فتضيع.
  double get totalOpenDisputes => companyBills
      .where((b) => b.hasOpenDispute)
      .fold<double>(0, (s, b) => s + b.disputeAmount);

  /// عدد الفواتير اللي لسه فيها مطالبة مفتوحة.
  int get openDisputeCount =>
      companyBills.where((b) => b.hasOpenDispute).length;

  /// 🧾 المطالبات المفتوحة لكل خط — مرتّبة بالأكبر.
  List<({Group group, double amount, int count})> disputesByLine() {
    final byGid = <String, ({double amount, int count})>{};
    for (final b in companyBills.where((b) => b.hasOpenDispute)) {
      final cur = byGid[b.groupId] ?? (amount: 0.0, count: 0);
      byGid[b.groupId] =
          (amount: cur.amount + b.disputeAmount, count: cur.count + 1);
    }
    final out = <({Group group, double amount, int count})>[];
    for (final e in byGid.entries) {
      final g = groups.where((x) => x.id == e.key).firstOrNull;
      if (g == null) continue;
      out.add((group: g, amount: e.value.amount, count: e.value.count));
    }
    out.sort((a, b) => b.amount.compareTo(a.amount));
    return out;
  }

  /// 📈 خطوط شكلها الشركة رفعت سعرها.
  ///
  /// الشرط: **آخر فاتورتين فعليتين** على الخط الاتنين أعلى من فاتورة
  /// الشركة المسجّلة، وبنفس الرقم تقريباً.
  ///
  /// ⚠️ فاتورة واحدة عالية = غلطة أو زيادة استهلاك، مش رفع سعر — عشان كده
  /// بنطلب اتنين ورا بعض. من غير الشرط ده التنبيه هيرنّ كل شهر على غلطات
  /// عادية، وهتتعوّد تتجاهله.
  ///
  /// [tolerance] = الفرق المسموح بيه بين الفاتورتين عشان نعتبرهم نفس الرقم.
  List<({Group group, double oldPrice, double newPrice})> priceIncreaseSuspects(
      {double tolerance = 5}) {
    final out = <({Group group, double oldPrice, double newPrice})>[];
    for (final g in groups) {
      if (g.fixedBillAmount <= 0) continue;
      final actual = companyBills
          .where((b) => b.groupId == g.id && b.isActual && b.actualAmount > 0)
          .toList()
        ..sort((a, b) => b.month.compareTo(a.month));
      if (actual.length < 2) continue;
      final a = actual[0].actualAmount, b = actual[1].actualAmount;
      // لازم الاتنين أعلى من المسجّل، وقريبين من بعض.
      if (a <= g.fixedBillAmount || b <= g.fixedBillAmount) continue;
      if ((a - b).abs() > tolerance) continue;
      out.add((group: g, oldPrice: g.fixedBillAmount, newPrice: a));
    }
    out.sort((x, y) => (y.newPrice - y.oldPrice).compareTo(x.newPrice - x.oldPrice));
    return out;
  }

  /// 🔮 ربح خط في شهر **معيّن** — نفس معادلة [groupProfit] بالظبط، بس
  /// بتاخد الشهر بدل ما تفترض النهاردة.
  ///
  /// اللي بيفرق من شهر للتاني: الباقات الإضافية المؤقتة (بتخلص)، والخط
  /// اللي اتقفل (بيبطّل يجيب دخل وتكلفة مع بعض).
  double groupProfitIn(String gid, String month) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    if (g.id.isEmpty) return 0;
    // الخط المقفول: مفيش فاتورة ومفيش عملاء بيدفعوا — الربح صفر.
    if (g.isClosedIn(month)) return 0;
    final income = membersOf(gid).fold<double>(0, (s, m) => s + m.price);
    final cost = g.profitBasis;
    if (cost <= 0 && g.type != 'manual') return 0;
    return income - cost - groupExtraLineFee(gid) - g.extraCostThisMonth(month);
  }

  /// 🔮 توقّع ربح الشهر [month] كله.
  ///
  /// ⚠️ **مش تخمين.** الربح بيتحسب أصلاً على [Group.profitBasis] — تكلفة
  /// الشهر الواحد — فهو أصلاً مستوي على طول الشهور، مابيقفزش مع دورة
  /// «شهر وشهر». اللي بيغيّره حاجتين بس:
  ///
  ///   * باقة إضافية مؤقتة بتخلص → التكلفة بتقل → الربح بيزيد
  ///   * خط بيتقفل → دخله وتكلفته بيروحوا مع بعض
  ///
  /// فالرقم ده هو ربحك الشهر ده **لو مافيش عميل جديد ولا خارج**.
  double profitForecast(String month, List<Rental> rentals) {
    final bills = groups.fold<double>(0, (s, g) => s + groupProfitIn(g.id, month));
    final rentalIncome = rentals
        .where((r) => r.status == 'active')
        .fold<double>(0, (s, r) => s + r.rent);
    final gifts = groups
        .where((g) => !g.isClosedIn(month))
        .fold<double>(0, (s, g) => s + g.giftProfit);
    final points = groups
        .where((g) => !g.isClosedIn(month))
        .fold<double>(0, (s, g) => s + g.monthlyPointsValue);
    return bills + rentalIncome + gifts + points;
  }

  /// ⚖️ الاعتراضات المفتوحة مجمّعة **لكل شركة**.
  ///
  /// الاعتراض بيتسجّل على فاتورة خط واحد، فبتفضل شايف «٣٠٠ ج هنا، ٢٠٠ ج
  /// هناك» ومش عارف انت مستحق كام من كل شركة. لما تروح تراجع مع الشركة
  /// محتاج رقم واحد مجمّع تقف بيه قدامهم.
  ///
  /// مرتّبة بالأكبر — الشركة اللي مستحق منها أكتر هي اللي تبدأ بيها.
  List<({String provider, double open, double resolved, int count})>
      disputesByProvider() {
    final open = <String, double>{};
    final resolved = <String, double>{};
    final count = <String, int>{};
    for (final b in companyBills) {
      if (b.disputeAmount <= 0) continue;
      final g = groups.where((x) => x.id == b.groupId).firstOrNull;
      final p = (g?.provider?.isNotEmpty ?? false) ? g!.provider! : 'غير محدد';
      if (b.disputeResolved) {
        resolved[p] = (resolved[p] ?? 0) + b.disputeAmount;
      } else {
        open[p] = (open[p] ?? 0) + b.disputeAmount;
        count[p] = (count[p] ?? 0) + 1;
      }
    }
    final all = {...open.keys, ...resolved.keys};
    final rows = all
        .map((p) => (
              provider: p,
              open: open[p] ?? 0,
              resolved: resolved[p] ?? 0,
              count: count[p] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.open.compareTo(a.open));
    return rows;
  }

  /// 📊 كشف حساب شركة: كل شهر بصفّه — المتوقع، اللي نزل، الفرق، والمعترض عليه.
  ///
  /// ده اللي بتقف بيه قدام الشركة. من غيره بتفتح كل فاتورة لوحدها وتجمع
  /// بالورقة والقلم، وأول ما تغلط في جمعة بتخسر حقك.
  ///
  /// [provider] فاضي = كل الشركات مع بعض.
  /// مرتّب من الأحدث للأقدم.
  List<
      ({
        String month,
        double expected,
        double actual,
        double diff,
        double dispute,
        int bills
      })> companyStatement(String? provider) {
    final ids = groups
        .where((g) =>
            provider == null ||
            provider.isEmpty ||
            (g.provider ?? '') == provider)
        .map((g) => g.id)
        .toSet();
    if (ids.isEmpty) return const [];

    final byMonth = <String, List<CompanyBill>>{};
    for (final b in companyBills) {
      if (!ids.contains(b.groupId)) continue;
      byMonth.putIfAbsent(b.month, () => []).add(b);
    }

    final rows = byMonth.entries.map((e) {
      final expected = e.value.fold<double>(0, (s, b) => s + b.fixedAmount);
      final actual = e.value.fold<double>(0, (s, b) => s + b.actualAmount);
      return (
        month: e.key,
        expected: expected,
        actual: actual,
        diff: actual - expected,
        dispute: e.value.fold<double>(0, (s, b) => s + b.disputeAmount),
        bills: e.value.length,
      );
    }).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
    return rows;
  }

  /// 🧾 كام خط دوره الشهر ده وما اتسجّلّوش فاتورة؟
  ///
  /// الخط اللي **مش دوره** مابيتحسبش ناقص — ده صح إنه فاضي. لو حسبناه،
  /// التذكير الأسبوعي كان هيقول لك «فيه ٣٠ فاتورة ناقصة» كل أسبوع وانت
  /// مظبوط، فتتعوّد تتجاهله وتضيّع النقص الحقيقي.
  int missingBillsCount(String month) {
    final added = companyBills
        .where((b) => b.month == month)
        .map((b) => b.groupId)
        .toSet();
    return groups.where((g) {
      if (g.parentGroupId?.isNotEmpty ?? false) return false;
      if (added.contains(g.id)) return false;
      if (g.isClosedIn(month)) return false;
      if (g.fixedBillAmount <= 0) return false;
      return g.isDueIn(month) ?? false;
    }).length;
  }

  /// 🏢 الشركات اللي عندك خطوط عليها فعلاً — للاختيار في التصدير.
  List<String> get activeProviders {
    final s = groups
        .map((g) => g.provider ?? '')
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return s;
  }

  /// ⚖️ إجمالي الاعتراضات المفتوحة في البرنامج كله.
  double get openDisputesTotal => companyBills
      .where((b) => b.hasOpenDispute)
      .fold<double>(0, (s, b) => s + b.disputeAmount);

  /// 📋 انسخ إعدادات الدورة من خط لخطوط تانية — بيرجّع عدد اللي اتغيّر.
  ///
  /// بينسخ حاجتين بس: **العلامة** (المرساة) و**طول الدورة**. يعني الخطوط
  /// دي هتنزل فواتيرها في نفس الشهور.
  ///
  /// ⚠️ **مش** بينسخ الاستثناءات (`billMonthOverrides`) ولا المبلغ. الاستثناء
  /// معناه «الشركة غلطت في الخط ده الشهر ده» — لو نسخناه لخط تاني نبقى
  /// اخترعنا غلطة ماحصلتش. والمبلغ بيختلف من خط للتاني بطبيعته.
  ///
  /// ⚠️ خط المصدر لو مالوش علامة أصلاً، مابننسخش حاجة — مسح علامات
  /// خطوط سليمة أسوأ بكتير من إن العملية ما تتنفّذش.
  int copyCycle(String srcGid, List<String> targetGids) {
    final src = groups.where((g) => g.id == srcGid).firstOrNull;
    if (src == null) return 0;
    final anchor = src.effectiveBillAnchor;
    if (anchor == null) return 0;
    var n = 0;
    for (final id in targetGids) {
      if (id == srcGid) continue;
      final g = groups.where((x) => x.id == id).firstOrNull;
      if (g == null) continue;
      if (g.billAnchorMonth == anchor &&
          g.billCycleMonths == src.billCycleMonths) {
        continue; // زي بعضه خلاص
      }
      g.billAnchorMonth = anchor;
      g.billCycleMonths = src.billCycleMonths;
      n++;
    }
    return n;
  }

  /// 💵 الربح **الحقيقي** = الربح المعروض + القسايم موزّعة على الشهور.
  ///
  /// ⚠️ رقم **زيادة**، مش بديل. الربح الأساسي في البرنامج كله لسه زي ما هو
  /// بالظبط — عمداً. لو غيّرناه، كل رقم في كل شاشة كان هيتحرّك من غير ما
  /// تعرف ليه، وساعتها مش هتثق في أي رقم منهم.
  ///
  /// القسيمة فلوس حقيقية بتيجي لك، بس بتنزل كل ٦ شهور أو سنة — فبتتوزّع
  /// على الشهور عشان الرقم يبقى قابل للبناء عليه.
  double realProfitForecast(String month, List<Rental> rentals) {
    final vouchers = groups
        .where((g) => !g.isClosedIn(month))
        .fold<double>(0, (s, g) => s + g.voucherMonthlyValue);
    return profitForecast(month, rentals) + vouchers;
  }

  /// 🎫 إجمالي القسايم الشهرية — الفرق بين الربح المعروض والحقيقي.
  double voucherMonthlyTotal(String month) => groups
      .where((g) => !g.isClosedIn(month))
      .fold<double>(0, (s, g) => s + g.voucherMonthlyValue);

  /// 👥 تكلفة الخط لكل عميل عليه.
  ///
  /// بتجاوب على «الخط ده بيكلفني كام لكل عميل، وانا باخد منه كام؟» — وهو
  /// السؤال اللي بيحدد تسعّر بكام وتقبل عميل جديد ولا لأ.
  ///
  /// [costPerClient] = أساس الربح ÷ عدد العملاء (تكلفة الشهر الواحد).
  /// [avgPrice] = متوسط اللي بتاخده من العميل.
  /// الفرق بينهم هو ربحك من كل عميل.
  ({double costPerClient, double avgPrice, int clients}) lineCostPerClient(
      String gid) {
    final g = groups.where((x) => x.id == gid).firstOrNull;
    if (g == null) return (costPerClient: 0, avgPrice: 0, clients: 0);
    final ms = membersOf(gid);
    if (ms.isEmpty) {
      // مفيش عملاء: التكلفة كلها عليك انت، ومفيش متوسط يتحسب.
      return (costPerClient: g.profitBasis, avgPrice: 0, clients: 0);
    }
    final income = ms.fold<double>(0, (s, m) => s + m.price);
    return (
      costPerClient: g.profitBasis / ms.length,
      avgPrice: income / ms.length,
      clients: ms.length,
    );
  }

  /// 📋 ليه الشهر الجاي مختلف عن الشهر ده؟ — سطر لكل سبب.
  ///
  /// من غير الأسباب دي الرقم بيبقى نبوءة معندهاش سبب، والمستخدم مش هيصدّقها
  /// ولا هيعرف يتصرّف بيها.
  List<({String reason, double delta})> profitForecastReasons(
      String fromMonth, String toMonth) {
    final out = <({String reason, double delta})>[];
    for (final g in groups) {
      final before = groupProfitIn(g.id, fromMonth);
      final after = groupProfitIn(g.id, toMonth);
      if ((after - before).abs() < 0.5) continue;
      final why = g.isClosedIn(toMonth) && !g.isClosedIn(fromMonth)
          ? 'الخط ${g.phone} بيتقفل'
          : 'باقة إضافية على ${g.phone} بتخلص';
      out.add((reason: why, delta: after - before));
    }
    out.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
    return out;
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
    // النقاط = القيمة الشهرية الثابتة (مش المتراكم) حسب اختيار المستخدم.
    return billProfit + g.giftProfit + rentalProfit + g.monthlyPointsValue;
  }

  /// تفصيل بنود ربح المجموعة (للعرض في نافذة «تفصيل الربح»).
  /// كل القيم بنفس منطق groupNetProfit عشان المجموع يطابق البادج بالظبط.
  Map<String, double> groupProfitBreakdown(String gid, List<Rental> rentals) {
    final g = groups.firstWhere((x) => x.id == gid,
        orElse: () => Group(id: '', phone: ''));
    final income = membersOf(gid).fold<double>(0, (s, m) => s + m.price);
    // لازم يبقى نفس اللي groupProfit بيستخدمه بالظبط، وإلا التفصيل
    // مايطابقش البادج. profitBasis = تكلفة الشهر الواحد.
    final fixedBill = g.profitBasis;
    final extraFee = groupExtraLineFee(gid);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final extraBundle = g.extraCostThisMonth(month);
    final rentalProfit = rentals
        .where((r) => r.gid == gid && r.status == 'active')
        .fold<double>(0, (s, r) => s + r.rent);
    // ربح الفاتورة = صفر لو الفاتورة الثابتة مش متكتوبة (نفس groupProfit)
    final hasFixed = fixedBill > 0 || g.type == 'manual';
    final billProfit = hasFixed ? (income - fixedBill - extraFee - extraBundle) : 0.0;
    return {
      'income': income,
      'fixedBill': fixedBill,
      // 💰 السعر الخام اللي الشركة بتاخده — للعرض جنب أساس الربح عشان
      // تشوف الفرق بعينك في الخطوط «شهر وشهر». مش داخل في المعادلة.
      'rawBill': g.fixedBillAmount,
      'isBimonthly': g.isBimonthly ? 1 : 0,
      'extraFee': extraFee,
      'extraBundle': extraBundle,
      'points': g.monthlyPointsValue,
      'gift': g.giftProfit,
      'rental': rentalProfit,
      'hasFixed': hasFixed ? 1 : 0,
      'net': billProfit + g.giftProfit + rentalProfit + g.monthlyPointsValue,
    };
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

  /// GB used by members (استهلاك العملاء فقط — مش بنضيف حصة الخط الرئيسي)
  int groupUsedGb(String gid) {
    final byMembers = membersOf(gid).fold<int>(0, (s, m) {
      // الخط الأرضي بياخد 10 جيجا ثابتة، Home 4G مايخصمش (شبكة منفصلة)
      if (m.type == 'landline') return s + 10;
      if (m.type == 'homeforgee') return s; // 0 GB
      return s + m.gb;
    });
    // ملاحظة: حصة الخط الرئيسي (mainLineAllocationGb) مش بتتضاف للمستخدَم عشان
    // كانت بتسبب مضاعفة الرقم (70→140 / 200→400). المستخدَم = استهلاك العملاء فقط.
    return byMembers;
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

  /// إجمالي الدقائق المستخدمة من قبل العملاء (افتراضي 1500 لكل عميل غير محدد)
  int groupUsedMinutes(String gid) =>
      membersOf(gid).fold<int>(0, (s, m) => s + m.effectiveMinutes);

  /// إجمالي الدقائق الدولية المستخدمة من قبل العملاء
  int groupUsedInternational(String gid) =>
      membersOf(gid).fold<int>(0, (s, m) => s + m.internationalAllocation);
}
