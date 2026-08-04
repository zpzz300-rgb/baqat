// lib/services/view_prefs.dart
// 💾 كل شاشة بتفتكر الفلاتر وطريقة العرض اللي سبتها عليها.
//
// بيتخزّن في مفاتيح مستقلة تماماً (`view_<اسم الشاشة>`) — مالوش أي علاقة
// بقاعدة البيانات (`tcm_v3`)، فمستحيل يأثّر على بياناتك.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ViewPrefs {
  ViewPrefs(this.name);

  /// اسم الشاشة (مثلاً 'worknums' / 'consolidated').
  final String name;

  String get _key => 'view_$name';

  /// بيقرا آخر حالة متسجّلة. بيرجّع map فاضية لو أول مرة.
  Future<Map<String, dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      return m is Map ? Map<String, dynamic>.from(m) : {};
    } catch (_) {
      return {};
    }
  }

  /// بيحفظ الحالة الحالية. بننده عليها بعد أي تغيير فلتر.
  Future<void> save(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(data));
  }

  /// بيمسح حالة الشاشة دي بس (رجوع للافتراضي).
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
