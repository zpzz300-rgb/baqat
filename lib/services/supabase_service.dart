// lib/services/supabase_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  static Future<void> saveUserData(Map<String, dynamic> data) async {
    if (!SupabaseConfig.isConfigured) return;
    final uid = userId;
    if (uid == null) return;
    try {
      await client.from('user_data').upsert({
        'user_id':    uid,
        'data':       data,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadUserData() async {
    if (!SupabaseConfig.isConfigured) return null;
    final uid = userId;
    if (uid == null) return null;
    try {
      final row = await client.from('user_data').select('data').eq('user_id', uid).maybeSingle();
      if (row == null) return null;
      final d = row['data'];
      if (d is Map<String, dynamic>) return d;
      return null;
    } catch (_) { return null; }
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
  }

  static bool get isLoggedIn => client.auth.currentUser != null;

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
