// lib/providers/main_line_provider.dart
import 'package:flutter/material.dart';
import '../models/main_line.dart';
import '../services/supabase_service.dart';

class MainLineProvider extends ChangeNotifier {
  List<MainLine> _lines = [];
  bool   _loading = false;
  String? _error;

  List<MainLine> get lines   => _lines;
  bool           get loading => _loading;
  String?        get error   => _error;

  // ── Fetch all ─────────────────────────────────────────────────
  Future<void> fetchAll() async {
    if (!SupabaseConfig.isConfigured) {
      _error = 'notConfigured';
      notifyListeners();
      return;
    }
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await SupabaseService.client
          .from('main_lines')
          .select()
          .order('created_at', ascending: false);
      _lines = (data as List).map((j) => MainLine.fromJson(j)).toList();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  // ── Add ───────────────────────────────────────────────────────
  Future<bool> add(MainLine line) async {
    try {
      final res = await SupabaseService.client
          .from('main_lines')
          .insert(line.toSupabase())
          .select()
          .single();
      _lines.insert(0, MainLine.fromJson(res));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Update ────────────────────────────────────────────────────
  Future<bool> update(MainLine line) async {
    try {
      await SupabaseService.client
          .from('main_lines')
          .update(line.toSupabase())
          .eq('id', line.id);
      final i = _lines.indexWhere((l) => l.id == line.id);
      if (i >= 0) _lines[i] = line;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Delete ────────────────────────────────────────────────────
  Future<bool> delete(String id) async {
    try {
      await SupabaseService.client
          .from('main_lines')
          .delete()
          .eq('id', id);
      _lines.removeWhere((l) => l.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Local-only methods (for when Supabase not configured) ──────
  void addLocal(MainLine line) {
    _lines.insert(0, line);
    notifyListeners();
  }

  void updateLocal(MainLine line) {
    final i = _lines.indexWhere((l) => l.id == line.id);
    if (i >= 0) { _lines[i] = line; notifyListeners(); }
  }

  void deleteLocal(String id) {
    _lines.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}
