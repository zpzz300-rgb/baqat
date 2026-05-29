// lib/models/main_line.dart
import 'package:flutter/material.dart';

class MainLine {
  String id;
  String provider;        // 'vodafone' | 'etisalat' | 'orange' | 'we'
  String phone;
  int    maxClients;      // عدد العملاء المتاحين
  int    pointsMonthly;   // عدد النقاط المنزلة شهرياً
  double pointPrice;      // سعر النقطة (جنيه)
  double extraClientFee;  // قيمة الزيادة لكل عميل إضافي
  String billingCycle;    // 'day1' | 'day4' | 'mid' | 'cycle1' | 'cycle2'
  String ownerName;
  String? idPhotoPath;    // local file path or remote URL
  String? startDate;      // YYYY-MM-DD
  String? endDate;        // YYYY-MM-DD  (auto from start + offerDuration)
  int?   offerDuration;   // months
  String? notes;
  double openingBalance;   // الرصيد الافتتاحي للخط (جنيه)

  MainLine({
    required this.id,
    required this.provider,
    required this.phone,
    this.maxClients      = 0,
    this.pointsMonthly   = 0,
    this.pointPrice      = 0,
    this.extraClientFee  = 0,
    this.billingCycle    = 'cycle1',
    this.ownerName       = '',
    this.idPhotoPath,
    this.startDate,
    this.endDate,
    this.offerDuration,
    this.notes,
    this.openingBalance  = 0,
  });

  // ── Supabase / JSON serialisation ─────────────────────────────
  factory MainLine.fromJson(Map<String, dynamic> j) => MainLine(
    id:             j['id']?.toString()                         ?? '',
    provider:       j['provider']?.toString()                   ?? 'vodafone',
    phone:          j['phone']?.toString()                      ?? '',
    maxClients:     (j['max_clients']    ?? j['maxClients']    ?? 0) as int,
    pointsMonthly:  (j['points_monthly'] ?? j['pointsMonthly'] ?? 0) as int,
    pointPrice:     (j['point_price']    ?? j['pointPrice']    ?? 0).toDouble(),
    extraClientFee: (j['extra_client_fee'] ?? j['extraClientFee'] ?? 0).toDouble(),
    billingCycle:   j['billing_cycle']   ?? j['billingCycle']  ?? 'cycle1',
    ownerName:      j['owner_name']      ?? j['ownerName']     ?? '',
    idPhotoPath:    j['id_photo_url']    ?? j['idPhotoPath'],
    startDate:      j['start_date']      ?? j['startDate'],
    endDate:        j['end_date']        ?? j['endDate'],
    offerDuration:   j['offer_duration']   ?? j['offerDuration'],
    notes:           j['notes'],
    openingBalance:  (j['opening_balance'] ?? j['openingBalance'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toSupabase() => {
    'provider':         provider,
    'phone':            phone,
    'max_clients':      maxClients,
    'points_monthly':   pointsMonthly,
    'point_price':      pointPrice,
    'extra_client_fee': extraClientFee,
    'billing_cycle':    billingCycle,
    'owner_name':       ownerName,
    'id_photo_url':     idPhotoPath,
    'start_date':       startDate,
    'end_date':         endDate,
    'offer_duration':   offerDuration,
    'notes':            notes,
    'opening_balance':  openingBalance,
  };

  // ── Auto-calculate end date ────────────────────────────────────
  static String? calcEndDate(String? startDate, int? months) {
    if (startDate == null || months == null || months <= 0) return null;
    final d = DateTime.tryParse(startDate);
    if (d == null) return null;
    final end = DateTime(d.year, d.month + months, d.day);
    return '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
  }

  // ── Provider meta ──────────────────────────────────────────────
  static const Map<String, String> providerNames = {
    'vodafone': 'فودافون',
    'etisalat': 'اتصالات',
    'orange':   'أورانج',
    'we':       'WE',
  };

  static const Map<String, String> providerEmojis = {
    'vodafone': '🔴',
    'etisalat': '🟢',
    'orange':   '🟠',
    'we':       '🟣',
  };

  static const Map<String, Color> providerColors = {
    'vodafone': Color(0xFFE60000),
    'etisalat': Color(0xFF00A651),
    'orange':   Color(0xFFFF6600),
    'we':       Color(0xFF7B2D8B),
  };

  static const Map<String, Color> providerBg = {
    'vodafone': Color(0xFFFFEBEB),
    'etisalat': Color(0xFFE8F5E9),
    'orange':   Color(0xFFFFF3E0),
    'we':       Color(0xFFF3E5F5),
  };

  // ── Billing cycle labels ───────────────────────────────────────
  static const Map<String, String> cycleLabels = {
    'day1':   'يوم 1',
    'day4':   'يوم 4',
    'mid':    'منتصف الشهر',
    'cycle1': 'Cycle 1',
    'cycle2': 'Cycle 2',
  };

  Color get color => providerColors[provider] ?? const Color(0xFF607D8B);
  Color get bg    => providerBg[provider]     ?? const Color(0xFFF5F5F5);
  String get name => providerNames[provider]  ?? provider;
  String get emoji => providerEmojis[provider] ?? '📡';
  String get cycleLabel => cycleLabels[billingCycle] ?? billingCycle;

  // Days until end
  int? get daysToEnd {
    if (endDate == null) return null;
    final end = DateTime.tryParse(endDate!);
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }
}
