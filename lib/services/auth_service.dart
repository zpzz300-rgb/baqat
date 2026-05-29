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
      return AppStatus.activated;
    }

    // 2. Trial check
    final startEnc = prefs.getString(_kTrialStart);
    if (startEnc == null) {
      await prefs.setString(_kTrialStart, _enc(DateTime.now().toIso8601String()));
      return AppStatus.trial;
    }
    final start = DateTime.tryParse(_dec(startEnc));
    if (start == null) return AppStatus.trial;
    final days = DateTime.now().difference(start).inDays;
    return days < _trialDays ? AppStatus.trial : AppStatus.expired;
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
      // Check expiry
      final expiry = row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'].toString()) : null;
      if (expiry != null && DateTime.now().isAfter(expiry)) {
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

      // Check expiry
      final expiry = row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'].toString()) : null;
      if (expiry != null && DateTime.now().isAfter(expiry)) {
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
    final rows = await _db
        .from('subscriptions')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> revokeSubscription(String id) async {
    await _db.from('subscriptions').update({'is_active': false, 'device_id': null}).eq('id', id);
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
