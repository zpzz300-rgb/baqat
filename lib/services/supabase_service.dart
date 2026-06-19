// lib/services/supabase_service.dart
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/main_line.dart';

class SupabaseConfig {
  static String get url {
    final v = dotenv.env['SUPABASE_URL'];
    if (v == null || v.isEmpty) throw Exception('SUPABASE_URL not found in .env');
    return v;
  }

  static String get anonKey {
    final v = dotenv.env['SUPABASE_ANON_KEY'];
    if (v == null || v.isEmpty) throw Exception('SUPABASE_ANON_KEY not found in .env');
    return v;
  }

  static bool get isConfigured {
    try { return url.isNotEmpty && anonKey.isNotEmpty; } catch (_) { return false; }
  }
}

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.initialize(
      url:      SupabaseConfig.url,
      anonKey:  SupabaseConfig.anonKey,
    );
  }

  // ── User Data Sync ────────────────────────────────────────────
  static String? get userId => client.auth.currentUser?.id;

  // ── سياق الموظف (RBAC) ────────────────────────────────────────
  // لو المستخدم موظف: بياناته الفعّالة هي بيانات المالك (ownerId)،
  // مش بياناته هو. ده اللي بيخلّيه يشتغل على نفس داتا المحل.
  static String? _employeeOwnerId; // = owner_id لو موظف، غير كده null
  static String? employeeId;
  static String? employeeName;

  static bool get isEmployee => _employeeOwnerId != null;

  /// هوية البيانات الفعّالة: للموظف = المالك، للمالك = نفسه
  static String? get dataUserId => _employeeOwnerId ?? userId;

  /// استرجاع سياق الموظف من التخزين المحلي عند فتح التطبيق
  static Future<void> restoreEmployeeContext() async {
    final prefs = await SharedPreferences.getInstance();
    _employeeOwnerId = prefs.getString('emp_owner_id');
    employeeId       = prefs.getString('emp_id');
    employeeName     = prefs.getString('emp_name');
  }

  static Future<void> _persistEmployeeContext() async {
    final prefs = await SharedPreferences.getInstance();
    if (_employeeOwnerId == null) {
      await prefs.remove('emp_owner_id');
      await prefs.remove('emp_id');
      await prefs.remove('emp_name');
    } else {
      await prefs.setString('emp_owner_id', _employeeOwnerId!);
      if (employeeId != null)   await prefs.setString('emp_id', employeeId!);
      if (employeeName != null) await prefs.setString('emp_name', employeeName!);
    }
  }

  static Future<void> _clearEmployeeContext() async {
    _employeeOwnerId = null;
    employeeId = null;
    employeeName = null;
    await _persistEmployeeContext();
  }

  /// نتيجة محاولة الحفظ المحمي ضد التضارب.
  /// accepted=true: اتقبلت الكتابة، version = الإصدار الجديد.
  /// stale=true: السيرفر أحدث، الكتابة اترفضت، serverData = نسخة السيرفر للسحب.
  /// ok=false: فشل اتصال/صلاحية — منعمل حاجة (نحاول تاني بعدين).
  static Future<({bool ok, bool accepted, bool stale, int version, Map<String, dynamic>? serverData})>
      saveUserDataGuarded(Map<String, dynamic> data, int baseVersion) async {
    if (!SupabaseConfig.isConfigured) {
      return (ok: false, accepted: false, stale: false, version: baseVersion, serverData: null);
    }
    final uid = dataUserId;
    if (uid == null) {
      return (ok: false, accepted: false, stale: false, version: baseVersion, serverData: null);
    }
    try {
      final res = await client.rpc('save_user_data_guarded', params: {
        'p_user_id':      uid,
        'p_data':         data,
        'p_base_version': baseVersion,
      });
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      final accepted = m['accepted'] == true;
      final stale    = m['stale'] == true;
      final version  = (m['version'] as num?)?.toInt() ?? baseVersion;
      final serverData = m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : null;
      return (ok: true, accepted: accepted, stale: stale, version: version, serverData: serverData);
    } catch (_) {
      return (ok: false, accepted: false, stale: false, version: baseVersion, serverData: null);
    }
  }

  /// تحميل بيانات المالك + رقم الإصدار الحالي على السيرفر.
  static Future<({Map<String, dynamic>? data, int version})> loadUserData() async {
    if (!SupabaseConfig.isConfigured) return (data: null, version: 0);
    final uid = dataUserId;
    if (uid == null) return (data: null, version: 0);
    try {
      final row = await client
          .from('user_data')
          .select('data, version')
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return (data: null, version: 0);
      final d = row['data'];
      final v = (row['version'] as num?)?.toInt() ?? 0;
      return (data: d is Map<String, dynamic> ? d : null, version: v);
    } catch (_) { return (data: null, version: 0); }
  }

  // ── Audit Log (الصندوق الأسود — جدول مستقل Append-Only) ────────
  /// ترحيل دفعة من حركات السجل للسيرفر. يرجّع true لو نجح (عشان نمسحها من
  /// الطابور المحلي). أي فشل → نسيبها في الطابور ونحاول تاني وقت يتوفر نت.
  static Future<bool> pushAuditLogs(List<Map<String, dynamic>> rows) async {
    if (!SupabaseConfig.isConfigured) return false;
    if (rows.isEmpty) return true;
    final uid = dataUserId; // المحل (المالك) — سواء كان الفاعل مالك أو موظف
    if (uid == null) return false;
    final actorUid = userId;
    final userType = isEmployee ? 'موظف: ${employeeName ?? '—'}' : 'المالك';
    try {
      final payload = rows.map((r) => {
            'owner_id':    uid,
            'actor_uid':   actorUid,
            'user_type':   userType,
            'is_employee': isEmployee,
            'action_type': r['type'],
            'details':     r['desc'],
            'target_id':   r['targetId'],
            'target_type': r['targetType'],
            'client_ts':   r['ts'],
          }).toList();
      await client.from('shop_audit_logs').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// قراءة السجل الرسمي من السيرفر (الأحدث أولاً).
  static Future<List<Map<String, dynamic>>> fetchAuditLogs({int limit = 500}) async {
    if (!SupabaseConfig.isConfigured) return [];
    final uid = dataUserId;
    if (uid == null) return [];
    try {
      final rows = await client
          .from('shop_audit_logs')
          .select('action_type, details, user_type, is_employee, target_id, target_type, client_ts, created_at')
          .eq('owner_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Line Invoice Audit (Phase 3 — أرشيف فواتير الخطوط Append-Only) ──
  /// يضيف قيد تدقيق لفاتورة خط في الجدول الدائم (غير قابل للحذف).
  static Future<bool> addLineInvoiceHistory({
    required String groupId,
    required String month,
    double? expected,
    required double actual,
    bool hasOverage = false,
    String? note,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = dataUserId;
    if (uid == null) return false;
    try {
      await client.from('line_invoice_history').insert({
        'owner_id':    uid,
        'group_id':    groupId,
        'month':       month,
        'expected':    expected,
        'actual':      actual,
        'variance':    expected == null ? null : actual - expected,
        'has_overage': hasOverage,
        'note':        note,
        'actor_uid':   userId,
        'user_type':   isEmployee ? 'موظف: ${employeeName ?? '—'}' : 'المالك',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// أرشيف فواتير خط معيّن (الأحدث أولاً).
  static Future<List<Map<String, dynamic>>> fetchLineInvoiceHistory(
      String groupId, {int limit = 100}) async {
    if (!SupabaseConfig.isConfigured) return [];
    final uid = dataUserId;
    if (uid == null) return [];
    try {
      final rows = await client
          .from('line_invoice_history')
          .select('month, expected, actual, variance, has_overage, note, user_type, created_at')
          .eq('owner_id', uid)
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Telegram Bot Config (24/7 server bot) ─────────────────────
  /// Saves the customer's telegram config so the shared Edge Function
  /// can serve their private bot. Returns (url, error) — url is null on failure.
  static Future<({String? url, String? error})> saveTelegramConfig({
    required String botToken,
    required String ownerName,
    required bool enabled,
    String? chatId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return (url: null, error: 'لم يتم إعداد الاتصال بالسيرفر');
    }
    final uid = userId;
    if (uid == null) {
      return (url: null, error: 'سجّل دخول لحسابك أولاً ثم حاول');
    }
    try {
      await client.from('telegram_config').upsert({
        'user_id': uid,
        'bot_token': botToken.trim(),
        'owner_name': ownerName,
        'enabled': enabled,
        if (chatId != null && chatId.trim().isNotEmpty) 'chat_id': chatId.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      final base = SupabaseConfig.url.replaceAll(RegExp(r'/+$'), '');
      return (url: '$base/functions/v1/telegram-bot?uid=$uid', error: null);
    } catch (e) {
      return (url: null, error: 'فشل حفظ الإعدادات: ${e.toString()}');
    }
  }

  static Future<void> setTelegramConfigEnabled(bool enabled) async {
    if (!SupabaseConfig.isConfigured) return;
    final uid = userId;
    if (uid == null) return;
    try {
      await client.from('telegram_config').update({'enabled': enabled}).eq('user_id', uid);
    } catch (_) {}
  }

  // ── Auth ──────────────────────────────────────────────────────
  static Future<({bool ok, String msg})> signIn(String email, String pass) async {
    try {
      await client.auth.signInWithPassword(email: email, password: pass);
      return (ok: true, msg: '');
    } on AuthException catch (e) {
      return (ok: false, msg: _arabicError(e.message));
    } catch (_) {
      return (ok: false, msg: 'تعذّر الاتصال بالسيرفر');
    }
  }

  static Future<({bool ok, String msg})> signUp(String email, String pass) async {
    try {
      final r = await client.auth.signUp(email: email, password: pass);
      if (r.user != null) return (ok: true, msg: '');
      return (ok: false, msg: 'فشل إنشاء الحساب');
    } on AuthException catch (e) {
      return (ok: false, msg: _arabicError(e.message));
    } catch (_) {
      return (ok: false, msg: 'تعذّر الاتصال بالسيرفر');
    }
  }

  static Future<void> signOut() async {
    try { await client.auth.signOut(); } catch (_) {}
    await _clearEmployeeContext();
  }

  static bool get isLoggedIn => client.auth.currentUser != null;

  // ── Employee Auth (RBAC) ──────────────────────────────────────
  /// تسجيل موظف جديد — يرجع: ok=نجح وبقى pending | error=رسالة الخطأ
  static Future<({bool ok, String msg})> employeeRegister({
    required String shopCode,
    required String name,
    required String pin,
  }) async {
    try {
      final res = await client.functions.invoke('employee-auth', body: {
        'action': 'register',
        'shopCode': shopCode.trim(),
        'name': name.trim(),
        'pin': pin.trim(),
      });
      final data = res.data;
      if (data is Map && data['status'] == 'pending') {
        return (ok: true, msg: '');
      }
      final err = (data is Map ? data['error'] : null) ?? 'فشل التسجيل';
      return (ok: false, msg: err.toString());
    } on FunctionException catch (e) {
      return (ok: false, msg: _fnError(e));
    } catch (_) {
      return (ok: false, msg: 'تعذّر الاتصال بالسيرفر');
    }
  }

  /// استخراج رسالة الخطأ الحقيقية من رد الدالة (بدل رسالة الاتصال العامة)
  static String _fnError(FunctionException e) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'تعذّر الاتصال بالسيرفر';
  }

  /// دخول موظف — يرجع status: 'active' | 'pending' | 'disabled' | 'error'
  static Future<({String status, String msg})> employeeLogin({
    required String shopCode,
    required String name,
    required String pin,
  }) async {
    try {
      final res = await client.functions.invoke('employee-auth', body: {
        'action': 'login',
        'shopCode': shopCode.trim(),
        'name': name.trim(),
        'pin': pin.trim(),
      });
      final data = res.data;
      if (data is! Map) return (status: 'error', msg: 'رد غير متوقع');

      final status = data['status']?.toString();
      if (status == 'pending') return (status: 'pending', msg: '');
      if (status == 'disabled') return (status: 'disabled', msg: '');
      if (status == 'active') {
        final session = data['session'];
        final refresh = session is Map ? session['refresh_token']?.toString() : null;
        if (refresh == null) return (status: 'error', msg: 'فشل تجهيز الجلسة');
        // مهم: نظبط سياق الموظف ونحفظه قبل setSession، عشان حدث «تسجيل الدخول»
        // اللي بيطلقه setSession يلاقي isEmployee=true فيحمّل مجموعات الموظف بس
        // (مش يعامله كمالك ويوريه كل المجموعات).
        _employeeOwnerId = data['ownerId']?.toString();
        employeeId       = data['employeeId']?.toString();
        employeeName     = data['employeeName']?.toString() ?? name.trim();
        await _persistEmployeeContext();
        await client.auth.setSession(refresh);
        return (status: 'active', msg: '');
      }
      final err = data['error']?.toString() ?? 'فشل الدخول';
      return (status: 'error', msg: err);
    } on FunctionException catch (e) {
      return (status: 'error', msg: _fnError(e));
    } catch (_) {
      return (status: 'error', msg: 'تعذّر الاتصال بالسيرفر');
    }
  }

  // ── Owner Profile (shop code) ─────────────────────────────────
  static const String _shopCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String _genShopCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _shopCodeChars[r.nextInt(_shopCodeChars.length)]).join();
  }

  /// يتأكد إن المالك عنده ملف + كود محل، وينشئه لو مش موجود. يرجّع كود المحل.
  static Future<String?> ensureOwnerProfile({String? shopName}) async {
    if (!SupabaseConfig.isConfigured) return null;
    final uid = userId;
    if (uid == null) return null;
    try {
      final existing = await client
          .from('owner_profiles')
          .select('shop_code')
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null && existing['shop_code'] != null) {
        return existing['shop_code'].toString();
      }
      // إنشاء كود فريد (نعيد المحاولة لو حصل تضارب نادر)
      for (var attempt = 0; attempt < 5; attempt++) {
        final code = _genShopCode();
        try {
          await client.from('owner_profiles').insert({
            'user_id': uid,
            'shop_code': code,
            if (shopName != null) 'shop_name': shopName,
          });
          return code;
        } catch (_) {/* تضارب — جرّب كود تاني */}
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Employee Management (owner side) ──────────────────────────
  static Future<List<Map<String, dynamic>>> fetchEmployees() async {
    if (!SupabaseConfig.isConfigured) return [];
    final uid = userId;
    if (uid == null) return [];
    try {
      final rows = await client
          .from('employees')
          .select('id, name, status, created_at, approved_at')
          .eq('owner_id', uid)
          .order('created_at');
      return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> setEmployeeStatus(String employeeId, String status) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await client.from('employees').update({
        'status': status,
        if (status == 'active') 'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', employeeId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteEmployee(String employeeId) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await client.from('employees').delete().eq('id', employeeId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Line Assignments (Phase 4 — تقسيم المجموعات على الموظفين) ──
  /// كل تعيينات المالك: [{group_id, employee_id}].
  static Future<List<Map<String, dynamic>>> fetchAssignments() async {
    if (!SupabaseConfig.isConfigured) return [];
    final uid = userId; // المالك
    if (uid == null) return [];
    try {
      final rows = await client
          .from('line_assignments')
          .select('group_id, employee_id')
          .eq('owner_id', uid);
      return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// تعيين مجموعة لموظف (upsert على owner_id+group_id — كل مجموعة لموظف واحد).
  static Future<bool> setAssignment(String groupId, String employeeId) async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = userId;
    if (uid == null) return false;
    try {
      await client.from('line_assignments').upsert({
        'owner_id': uid,
        'group_id': groupId,
        'employee_id': employeeId,
      }, onConflict: 'owner_id,group_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// إلغاء تعيين مجموعة.
  static Future<bool> removeAssignment(String groupId) async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = userId;
    if (uid == null) return false;
    try {
      await client
          .from('line_assignments')
          .delete()
          .eq('owner_id', uid)
          .eq('group_id', groupId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// مجموعات الموظف الحالي (الـ group_ids الموكلة له).
  static Future<Set<String>> fetchMyAssignedGroupIds() async {
    if (!SupabaseConfig.isConfigured) return {};
    if (!isEmployee || employeeId == null) return {};
    try {
      final rows = await client
          .from('line_assignments')
          .select('group_id')
          .eq('employee_id', employeeId!);
      return (rows as List).map((e) => e['group_id'].toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  /// اشتراك لحظي على صف الموظف نفسه — بيستدعي [onChange] بالحالة الجديدة.
  /// بيُستخدم لقفل التطبيق فوراً لو المالك فصل الموظف.
  static RealtimeChannel? subscribeOwnEmployeeStatus(void Function(String status) onChange) {
    if (!isEmployee || employeeId == null) return null;
    final channel = client
        .channel('emp_status_$employeeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: employeeId,
          ),
          callback: (payload) {
            // الحذف = طرد كامل، نعامله زي الإيقاف
            if (payload.eventType == PostgresChangeEvent.delete) {
              onChange('deleted');
              return;
            }
            final status = payload.newRecord['status']?.toString();
            if (status != null) onChange(status);
          },
        )
        .subscribe();
    return channel;
  }

  static String _arabicError(String msg) {
    if (msg.contains('Invalid login'))        return 'البريد أو كلمة السر غلط';
    if (msg.contains('Email not confirmed'))  return 'تأكّد من بريدك الإلكتروني أولاً';
    if (msg.contains('already registered'))   return 'البريد مسجّل بالفعل';
    if (msg.contains('Password should'))      return 'كلمة السر 6 أحرف على الأقل';
    return msg;
  }

  // ── Main Lines CRUD ────────────────────────────────────────────

  static Future<List<MainLine>> fetchMainLines() async {
    if (!SupabaseConfig.isConfigured) return [];
    final rows = await client.from('main_lines').select().order('created_at');
    return (rows as List).map((r) => MainLine.fromJson(r)).toList();
  }

  static Future<void> upsertMainLine(MainLine line) async {
    if (!SupabaseConfig.isConfigured) return;
    final data = line.toSupabase();
    data['id'] = line.id;
    await client.from('main_lines').upsert(data);
  }

  static Future<void> deleteMainLine(String id) async {
    if (!SupabaseConfig.isConfigured) return;
    await client.from('main_lines').delete().eq('id', id);
  }
}

/* ──────────────────────────────────────────────────────────────────
   SQL — run once in Supabase Dashboard → SQL Editor:

   create table if not exists main_lines (
     id               text primary key,
     provider         text not null,
     phone            text not null,
     max_clients      int  default 0,
     points_monthly   int  default 0,
     point_price      numeric(10,2) default 0,
     extra_client_fee numeric(10,2) default 0,
     billing_cycle    text default 'cycle1',
     owner_name       text default '',
     id_photo_url     text,
     start_date       text,
     end_date         text,
     offer_duration   int,
     notes            text,
     opening_balance  numeric(10,2) default 0,
     created_at       timestamptz default now()
   );
   alter table main_lines enable row level security;
   create policy "Allow all" on main_lines for all using (true);
────────────────────────────────────────────────────────────────── */
