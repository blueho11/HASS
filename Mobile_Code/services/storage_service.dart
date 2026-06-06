import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _themeKey     = 'hass_dark_mode';
  static const String _schedulesKey = 'hass_schedules';
  static const String _timersKey    = 'hass_timers';
  static const String _ifThenKey    = 'hass_if_then';

  // ── Theme ─────────────────────────────────────────────────────────────────
  // Saved locally — theme is a phone preference, not per-user on Firebase
  static Future<bool> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }

  static Future<void> saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  // ── Schedules ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_schedulesKey);
      if (raw == null || raw.isEmpty) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSchedules(
      List<Map<String, dynamic>> schedules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_schedulesKey, jsonEncode(schedules));
    } catch (_) {}
  }

  // ── Timers ────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> loadTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_timersKey);
      if (raw == null || raw.isEmpty) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTimers(List<Map<String, dynamic>> timers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_timersKey, jsonEncode(timers));
    } catch (_) {}
  }

  // ── If-Then rules ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> loadIfThen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_ifThenKey);
      if (raw == null || raw.isEmpty) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveIfThen(List<Map<String, dynamic>> rules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ifThenKey, jsonEncode(rules));
    } catch (_) {}
  }
}