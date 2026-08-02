// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

enum AppStatus { loading, trial, activated, expired }

class ActivationResult {
  final bool ok;
  final bool needsMigration;   // true = key bound to another device
  final String msg;
  final Map<String, dynamic>? row; // raw Supabase row (for migration confirmation)
  const ActivationResult({
    required this.ok,
    this.needsMigration = false,
    required this.msg,
    this.row,
  });
}

class AuthService {
  static const _kTrialStart  = 'tstart_v2';
  static const _kActivated   = 'activ_v2';
  static const _kKeyCode     = 'kcode_v2';
  static const _kDeviceId    = 'devid_v2';
  static const _kPhoneLinked = 'phone_linked_v1';
  // الرقم اللي المستخدم كتبه وقت إنشاء الحساب، بنحتفظ بيه لحد ما الجلسة تبدأ
  // فعلاً (لو التأكيد بالإيميل مفعّل الجلسة مبتبدأش على طول) وساعتها بنحفظه
  // على الحساب من غير ما نسأله تاني.
  static const _kPendingPhone = 'pending_phone_v1';
  static const _trialDays    = 30;
  static const _xorSeed      = 0x5F;

  static SupabaseClient get _db => SupabaseService.client;

  // ── Device ID ─────────────────────────────────────────────────
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kDeviceId);
    if (cached != null) return _dec(cached);

    String id = 'dev_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final di = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        id = (await di.androidInfo).id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        id = (await di.iosInfo).identifierForVendor ?? id;
      }
    } catch (_) {}

    await prefs.setString(_kDeviceId, _enc(id));
    return id;
  }

  // ── App status check (runs at startup) ────────────────────────
  static Future<AppStatus> checkStatus() async {
    // 1. Local fast-path
    final prefs = await SharedPreferences.getInstance();
    final actEnc = prefs.getString(_kActivated);
    if (actEnc != null && _dec(actEnc) == 'yes') {
      // Verify in background (non-blocking)
      _verifyOnlineInBackground(prefs);
      final keyEnc = prefs.getString(_kKeyCode);
      _reportInstallation(keyCode: keyEnc != null ? _dec(keyEnc) : null);
      return AppStatus.activated;
    }

    // 1.5 استرجاع التفعيل من السيرفر — لو الجهاز ده مربوط باشتراك شغّال
    // بالفعل، نفعّل تلقائي من غير ما نطلب الكود تاني. ده بيمنع إن إعادة
    // تنزيل البرنامج (أو مسح بياناته) تقفل على المستخدم وهو مشترك فعلاً.
    if (await _restoreActivationFromServer(prefs)) {
      final keyEnc = prefs.getString(_kKeyCode);
      _reportInstallation(keyCode: keyEnc != null ? _dec(keyEnc) : null);
      return AppStatus.activated;
    }

    // 2. Trial check
    final startEnc = prefs.getString(_kTrialStart);
    if (startEnc == null) {
      await prefs.setString(_kTrialStart, _enc(DateTime.now().toIso8601String()));
      _reportInstallation();
      return AppStatus.trial;
    }
    final start = DateTime.tryParse(_dec(startEnc));
    if (start == null) {
      _reportInstallation();
      return AppStatus.trial;
    }
    final days = DateTime.now().difference(start).inDays;
    _reportInstallation();
    return days < _trialDays ? AppStatus.trial : AppStatus.expired;
  }

  /// بيدوّر على اشتراك شغّال مربوط بالجهاز ده على السيرفر، ولو لقاه بيرجّع
  /// التفعيل محلياً من غير ما يطلب الكود من المستخدم تاني.
  ///
  /// الفايدة: لو التطبيق اتمسح واتنزّل تاني (أو بياناته اتمسحت)، المستخدم
  /// المشترك فعلاً مايتقفلش عليه في شاشة «انتهت الفترة التجريبية».
  /// أي فشل (أوفلاين مثلاً) بيرجّع false ونكمّل بالمسار العادي.
  static Future<bool> _restoreActivationFromServer(
      SharedPreferences prefs) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      final deviceId = await getDeviceId();
      final row = await _db
          .from('subscriptions')
          .select()
          .eq('device_id', deviceId)
          .maybeSingle();
      if (row == null) return false;
      if (row['is_active'] == false) return false;

      // نفس فحص الصلاحية المستخدم في التفعيل العادي
      final expiry = row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'].toString())
          : null;
      final graceDays = (row['grace_days'] as num?)?.toInt() ?? 0;
      if (expiry != null &&
          DateTime.now().isAfter(expiry.add(Duration(days: graceDays)))) {
        return false;
      }

      final keyCode = row['key_code']?.toString();
      if (keyCode == null || keyCode.isEmpty) return false;

      await prefs.setString(_kActivated, _enc('yes'));
      await prefs.setString(_kKeyCode, _enc(keyCode));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// يبلّغ لوحة الإدارة بوجود الجهاز ده (تجريبي أو مفعّل) — عشان صاحب
  /// البرنامج يقدر يشوف كل اللي نزّلوا البرنامج حتى لو لسه ماشتروش كود.
  /// Fire-and-forget: أي فشل (أوفلاين مثلاً) بيتجاهَل من غير ما يأثر على التطبيق.
  static void _reportInstallation({String? keyCode}) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final deviceId = await getDeviceId();
      final userId = _db.auth.currentUser?.id;
      await _db.from('app_installations').upsert({
        'device_id': deviceId,
        'last_seen': DateTime.now().toIso8601String(),
        if (keyCode != null) 'key_code': keyCode,
        if (userId != null) 'user_id': userId,
      }, onConflict: 'device_id');
    } catch (_) {}
  }

  /// يسجّل **هوية** الجهاز بعد تسجيل الدخول: مالك ولا موظف، واسم الموظف،
  /// والحساب اللي بيشتغل عليه. لازم تتنادى بعد الدخول مش قبله.
  ///
  /// من غير ده الجهاز بيفضل ظاهر «بدون اسم» في لوحة الإدارة، لأن التسجيل
  /// الأول بيحصل وقت فتح البرنامج قبل ما حد يسجّل دخول.
  ///
  /// الجهاز بيكتب عن نفسه بس — مفيش قراءة لبيانات عملاء أو موظفين تانيين.
  static Future<void> reportIdentity() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return;
      final isEmp = SupabaseService.isEmployee;

      final data = <String, dynamic>{
        'device_id': await getDeviceId(),
        'last_seen': DateTime.now().toIso8601String(),
        'user_id': userId,
        'account_type': isEmp ? 'employee' : 'owner',
        // للموظف: حساب المحل اللي شغّال عليه. للمالك: حسابه هو.
        'owner_user_id': SupabaseService.dataUserId ?? userId,
      };
      if (isEmp) {
        data['employee_name'] = SupabaseService.employeeName;
      } else {
        data['login_email'] = SupabaseService.userEmail;
        // رقم المالك من حسابه (بيقرا صفّه هو بس)
        final phone = await accountPhone();
        if (phone != null) data['customer_phone'] = phone;
      }

      await _db
          .from('app_installations')
          .upsert(data, onConflict: 'device_id');
    } catch (_) {}
  }

  /// يربط رقم موبايل صاحب المحل بـ **الحساب** (owner_profiles) — وده المصدر
  /// الأساسي من دلوقتي — وكمان بالجهاز الحالي عشان لوحة الإدارة.
  /// طالما الرقم اتحفظ على الحساب، أي جهاز تاني يدخل بنفس الإيميل مش هيتسأل
  /// عن الرقم تاني خالص.
  static Future<bool> linkPhoneToDevice(String phone) async {
    if (!SupabaseConfig.isConfigured) return false;
    final prefs = await SharedPreferences.getInstance();
    final userId = _db.auth.currentUser?.id;

    // لسه مفيش جلسة (تسجيل جديد بانتظار تأكيد الإيميل) — احفظه محلياً
    // وهيتربط بالحساب أول ما يدخل.
    if (userId == null) {
      await prefs.setString(_kPendingPhone, _enc(phone));
      return true;
    }

    var saved = false;

    // 1) الحساب — المصدر الأساسي
    try {
      await _db
          .from('owner_profiles')
          .update({'customer_phone': phone}).eq('user_id', userId);
      saved = true;
    } catch (_) {}

    // 2) الجهاز — للوحة الإدارة. بنجرّب من غير user_id لو العمود لسه مش
    //    موجود على السيرفر، عشان الحفظ ينجح على أي حال ومايعلّقش المستخدم.
    try {
      final deviceId = await getDeviceId();
      final base = {
        'device_id': deviceId,
        'last_seen': DateTime.now().toIso8601String(),
        'customer_phone': phone,
      };
      try {
        await _db
            .from('app_installations')
            .upsert({...base, 'user_id': userId}, onConflict: 'device_id');
      } catch (_) {
        await _db
            .from('app_installations')
            .upsert(base, onConflict: 'device_id');
      }
      saved = true;
    } catch (_) {}

    if (saved) {
      await prefs.setBool(_kPhoneLinked, true);
      await prefs.remove(_kPendingPhone);
    }
    return saved;
  }

  /// رقم الموبايل المسجّل على الحساب الحالي (null = مفيش).
  static Future<String?> accountPhone() async {
    if (!SupabaseConfig.isConfigured) return null;
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _db
          .from('owner_profiles')
          .select('customer_phone')
          .eq('user_id', userId)
          .maybeSingle();
      final p = (row?['customer_phone'] as String?)?.trim();
      return (p == null || p.isEmpty) ? null : p;
    } catch (_) {
      return null;
    }
  }

  /// هل الحساب الحالي عنده رقم موبايل خلاص؟ لو أيوه، البرنامج **مايسألش**.
  /// بيدوّر بالترتيب ده:
  ///   1. علامة محلية (من غير نت أصلاً)
  ///   2. رقم كتبه وقت إنشاء الحساب ولسه ما اتربطش (الجلسة كانت لسه ما بدأتش)
  ///   3. رقم الحساب في owner_profiles ← المصدر الأساسي
  ///   4. أرقام قديمة متسجّلة على الجهاز (حسابات قديمة) — بيرقّيها للحساب
  /// وبيرجّع true لو حصل أي خطأ/أوفلاين عشان مانضايقش المستخدم بالغلط.
  static Future<bool> accountHasPhone() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPhoneLinked) == true) return true;
    if (!SupabaseConfig.isConfigured) return true;
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return true; // مفيش جلسة — مش وقته

    try {
      // 2) رقم مستنّي من وقت إنشاء الحساب
      final pendingEnc = prefs.getString(_kPendingPhone);
      if (pendingEnc != null) {
        final pending = _dec(pendingEnc);
        if (pending.isNotEmpty && await linkPhoneToDevice(pending)) return true;
      }

      // 3) رقم الحساب
      if (await accountPhone() != null) {
        await prefs.setBool(_kPhoneLinked, true);
        return true;
      }

      // 4) أرقام قديمة على الأجهزة — بس اللي تخص نفس الحساب أو جهاز
      //    لسه مش مربوط بحساب (عشان مناخدش رقم حد تاني بالغلط)
      final legacy = await _legacyDevicePhone(userId);
      if (legacy != null) return await linkPhoneToDevice(legacy);

      return false;
    } catch (_) {
      return true; // أوفلاين/خطأ مؤقت — هنتأكد تاني المرة الجاية
    }
  }

  /// يدوّر على رقم قديم متسجّل في جدول الأجهزة يخص نفس الحساب، أو متسجّل على
  /// الجهاز الحالي وهو لسه مش مربوط بأي حساب.
  static Future<String?> _legacyDevicePhone(String userId) async {
    try {
      final rows = await _db
          .from('app_installations')
          .select('customer_phone')
          .eq('user_id', userId);
      for (final r in rows) {
        final p = (r['customer_phone'] as String?)?.trim();
        if (p != null && p.isNotEmpty) return p;
      }
    } catch (_) {}
    try {
      final deviceId = await getDeviceId();
      final row = await _db
          .from('app_installations')
          .select('customer_phone, user_id')
          .eq('device_id', deviceId)
          .maybeSingle();
      final owner = row?['user_id'] as String?;
      if (owner != null && owner != userId) return null; // جهاز لحساب تاني
      final p = (row?['customer_phone'] as String?)?.trim();
      if (p != null && p.isNotEmpty) return p;
    } catch (_) {}
    return null;
  }

  static void _verifyOnlineInBackground(SharedPreferences prefs) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final keyEnc = prefs.getString(_kKeyCode);
      if (keyEnc == null) return;
      final keyCode  = _dec(keyEnc);
      final deviceId = await getDeviceId();
      final row = await _db.from('subscriptions').select()
          .eq('key_code', keyCode).maybeSingle();
      if (row == null) { await _revokeLocal(prefs); return; }
      // Frozen or revoked من لوحة الإدارة
      if (row['is_active'] == false) {
        await _revokeLocal(prefs);
        return;
      }
      // Check expiry (+ فترة سماح لو متسجلة)
      final expiry = row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'].toString()) : null;
      final graceDays = (row['grace_days'] as num?)?.toInt() ?? 0;
      if (expiry != null &&
          DateTime.now().isAfter(expiry.add(Duration(days: graceDays)))) {
        await _revokeLocal(prefs);
      }
      // Check device binding
      if (row['device_id'] != null && row['device_id'] != deviceId) {
        await _revokeLocal(prefs);
      }
    } catch (_) {} // offline? stay activated
  }

  static Future<void> _revokeLocal(SharedPreferences prefs) async {
    await prefs.remove(_kActivated);
    await prefs.remove(_kKeyCode);
  }

  // ── Days left in trial ────────────────────────────────────────
  static Future<int> trialDaysLeft() async {
    final prefs = await SharedPreferences.getInstance();
    final enc = prefs.getString(_kTrialStart);
    if (enc == null) return _trialDays;
    final start = DateTime.tryParse(_dec(enc));
    if (start == null) return _trialDays;
    return (_trialDays - DateTime.now().difference(start).inDays).clamp(0, _trialDays);
  }

  // ── Activate key (first pass — may return needsMigration) ─────
  static Future<ActivationResult> activate(String keyCode) async {
    keyCode = keyCode.trim().toUpperCase();
    if (keyCode.isEmpty) return const ActivationResult(ok: false, msg: 'أدخل رمز التفعيل');
    if (!SupabaseConfig.isConfigured) {
      return const ActivationResult(ok: false, msg: 'لا يوجد اتصال بالسيرفر');
    }

    final deviceId = await getDeviceId();

    try {
      final row = await _db.from('subscriptions').select()
          .eq('key_code', keyCode).maybeSingle();

      if (row == null) return const ActivationResult(ok: false, msg: '❌ رمز التفعيل غير صحيح');
      if (row['is_active'] == false) return const ActivationResult(ok: false, msg: '❌ هذا الرمز معطّل');

      // Check expiry (+ فترة سماح لو متسجلة)
      final expiry = row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'].toString()) : null;
      final graceDays = (row['grace_days'] as num?)?.toInt() ?? 0;
      if (expiry != null &&
          DateTime.now().isAfter(expiry.add(Duration(days: graceDays)))) {
        return const ActivationResult(ok: false, msg: '❌ رمز التفعيل منتهي الصلاحية');
      }

      final boundDevice = row['device_id'] as String?;

      // Case 1: New key or same device
      if (boundDevice == null || boundDevice == deviceId) {
        return await _doActivate(keyCode, deviceId, row);
      }

      // Case 2: Bound to another device → ask user
      return ActivationResult(
        ok: false,
        needsMigration: true,
        msg: 'هذا الرمز مفعّل على جهاز آخر.\nهل تريد نقله لهذا الجهاز وإلغاء الجهاز القديم؟',
        row: Map<String, dynamic>.from(row),
      );
    } catch (e) {
      return ActivationResult(ok: false, msg: 'خطأ في الاتصال: ${e.toString().substring(0, 60)}');
    }
  }

  // ── Confirm migration (user agreed to move key to new device) ─
  static Future<ActivationResult> confirmMigration(String keyCode) async {
    final deviceId = await getDeviceId();
    try {
      final row = await _db.from('subscriptions').select()
          .eq('key_code', keyCode.toUpperCase()).maybeSingle();
      if (row == null) return const ActivationResult(ok: false, msg: 'الرمز غير موجود');
      return await _doActivate(keyCode.toUpperCase(), deviceId, row);
    } catch (e) {
      return ActivationResult(ok: false, msg: 'حدث خطأ: $e');
    }
  }

  static Future<ActivationResult> _doActivate(
      String keyCode, String deviceId, Map<String, dynamic> row) async {
    await _db.from('subscriptions').update({
      'device_id': deviceId,
      'last_activation_date': DateTime.now().toIso8601String(),
    }).eq('key_code', keyCode);
    _reportInstallation(keyCode: keyCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActivated, _enc('yes'));
    await prefs.setString(_kKeyCode, _enc(keyCode));

    final name = row['customer_name'] as String? ?? '';
    return ActivationResult(
        ok: true, msg: 'تم التفعيل بنجاح${name.isNotEmpty ? " يا $name 🎉" : " 🎉"}');
  }

  // ── Revoke (for testing / logout) ─────────────────────────────
  static Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await _revokeLocal(prefs);
  }

  // ── Admin: generate key ───────────────────────────────────────
  static String generateKeyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    String part() => List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${part()}-${part()}-${part()}';
  }

  static Future<({bool ok, String key, String msg})> createSubscription({
    required String customerName,
    required String customerPhone,
    required String durationType, // 'month','year','forever'
    String? notes,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return (ok: false, key: '', msg: 'لا يوجد اتصال');
    }
    final key = generateKeyCode();
    DateTime? expiry;
    if (durationType == 'month') expiry = DateTime.now().add(const Duration(days: 30));
    if (durationType == 'year')  expiry = DateTime.now().add(const Duration(days: 365));
    // 'forever' → expiry stays null

    try {
      await _db.from('subscriptions').insert({
        'key_code':      key,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'duration_type': durationType,
        'expiry_date':   expiry?.toIso8601String(),
        'notes':         notes,
      });
      return (ok: true, key: key, msg: 'تم الإنشاء');
    } catch (e) {
      return (ok: false, key: '', msg: 'خطأ: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    if (!SupabaseConfig.isConfigured) return [];
    try {
      final rows = await _db
          .from('subscriptions')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// إلغاء الربط الكامل (يمسح الجهاز المرتبط كمان) — للاستخدام لما تحب تفصل
  /// الكود عن جهاز العميل تمامًا، مش مجرد إيقافه مؤقتًا.
  static Future<void> revokeSubscription(String id) async {
    await _db.from('subscriptions').update({'is_active': false, 'device_id': null}).eq('id', id);
    await _addSubscriptionHistory(id, '🚫 إلغاء الربط بالجهاز');
  }

  // ── سجل تاريخي (Timeline) لكل اشتراك ───────────────────────────
  static Future<void> _addSubscriptionHistory(String id, String event) async {
    try {
      final row = await _db.from('subscriptions').select('history').eq('id', id).maybeSingle();
      final history = row?['history'] is List ? List.from(row!['history']) : [];
      history.insert(0, {'event': event, 'date': DateTime.now().toIso8601String()});
      await _db.from('subscriptions').update({'history': history}).eq('id', id);
    } catch (_) {}
  }

  /// تمديد/تقصير مدة الاشتراك بعدد أيام (سالب = تقصير). بيتجاهل الاشتراك
  /// الدائم (expiry_date = null) لأن مفيش تاريخ يتعدّل عليه.
  static Future<bool> adjustSubscriptionDays(String id, int days) async {
    try {
      final row = await _db.from('subscriptions').select('expiry_date').eq('id', id).maybeSingle();
      final expiryStr = row?['expiry_date']?.toString();
      if (expiryStr == null || expiryStr.isEmpty) return false; // اشتراك دائم
      final current = DateTime.tryParse(expiryStr);
      if (current == null) return false;
      final updated = current.add(Duration(days: days));
      await _db.from('subscriptions').update({'expiry_date': updated.toIso8601String()}).eq('id', id);
      await _addSubscriptionHistory(
          id, days >= 0 ? '⏳ تمديد $days يوم' : '⏳ تقصير ${-days} يوم');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setSubscriptionVip(String id, bool vip) async {
    try {
      await _db.from('subscriptions').update({'is_vip': vip}).eq('id', id);
      await _addSubscriptionHistory(id, vip ? '⭐ اتضاف لـ VIP' : '⭐ اتشال من VIP');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setSubscriptionGraceDays(String id, int days) async {
    try {
      await _db.from('subscriptions').update({'grace_days': days}).eq('id', id);
      await _addSubscriptionHistory(id, '🕊️ فترة سماح: $days يوم');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// تجميد مؤقت — بيوقف الاشتراك من غير ما يمسح ربط الجهاز، عشان لو فتحت
  /// تاني يرجع يشتغل على نفس الجهاز مباشرة من غير إعادة تفعيل.
  static Future<bool> freezeSubscription(String id) async {
    try {
      await _db.from('subscriptions').update({'is_active': false}).eq('id', id);
      await _addSubscriptionHistory(id, '⏸️ تجميد الحساب');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unfreezeSubscription(String id) async {
    try {
      await _db.from('subscriptions').update({'is_active': true}).eq('id', id);
      await _addSubscriptionHistory(id, '▶️ إلغاء التجميد');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateSubscriptionNotes(String id, String notes) async {
    try {
      await _db.from('subscriptions').update({'notes': notes}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Admin: كل الأجهزة اللي فتحت البرنامج (تجريبي + مفعّل) ─────
  static Future<List<Map<String, dynamic>>> fetchInstallations() async {
    if (!SupabaseConfig.isConfigured) return [];
    try {
      final rows = await _db
          .from('app_installations')
          .select()
          .order('last_seen', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// تعديل بيانات جهاز (اسم/تليفون/ملاحظة) — يدوي من لوحة الإدارة. لو اتغيّر
  /// الاسم أو الرقم، بينشرهم كمان على أي جهاز تاني واضح إنه لنفس الشخص
  /// (نفس رقم الموبايل، أو نفس حساب الدخول لو متسجل) عشان الأجهزة تفضل
  /// متزامنة مع بعضها بدل ما كل جهاز يتعدّل لوحده.
  static Future<bool> updateInstallation(
    String deviceId, {
    String? name,
    String? phone,
    String? notes,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await _db.from('app_installations').update({
        if (name != null) 'customer_name': name,
        if (phone != null) 'customer_phone': phone,
        if (notes != null) 'notes': notes,
      }).eq('device_id', deviceId);

      if (name != null || phone != null) {
        final updates = {
          if (name != null) 'customer_name': name,
          if (phone != null) 'customer_phone': phone,
        };
        final row = await _db
            .from('app_installations')
            .select('user_id, customer_phone')
            .eq('device_id', deviceId)
            .maybeSingle();
        final userId = row?['user_id'] as String?;
        final matchPhone = phone ?? (row?['customer_phone'] as String?);

        if (userId != null) {
          await _db.from('app_installations').update(updates).eq('user_id', userId);
        }
        if (matchPhone != null && matchPhone.isNotEmpty) {
          await _db.from('app_installations').update(updates).eq('customer_phone', matchPhone);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Admin password check ──────────────────────────────────────
  static bool checkAdminPassword(String input) {
    return input == '0100100Aa@';
  }

  // ── XOR obfuscation ──────────────────────────────────────────
  static String _enc(String s) {
    final b = utf8.encode(s).map((x) => x ^ _xorSeed).toList();
    return base64.encode(b);
  }

  static String _dec(String s) {
    try {
      final b = base64.decode(s).map((x) => x ^ _xorSeed).toList();
      return utf8.decode(b);
    } catch (_) { return ''; }
  }
}
