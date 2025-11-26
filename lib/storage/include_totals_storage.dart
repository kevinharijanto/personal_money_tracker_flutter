import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class IncludeTotalsStorage {
  static const _prefsKey = 'include_totals_overrides';

  static Future<Map<String, bool>> getOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return {};
    }
    try {
      final Map<String, dynamic> raw = jsonDecode(jsonStr);
      return raw.map((key, value) => MapEntry(key, value == true));
    } catch (_) {
      return {};
    }
  }

  static Future<bool?> getOverride(String accountId) async {
    final overrides = await getOverrides();
    return overrides[accountId];
  }

  static Future<void> setOverride(String accountId, bool include) async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = await getOverrides();
    overrides[accountId] = include;
    await prefs.setString(_prefsKey, jsonEncode(overrides));
  }

  static Future<void> removeOverride(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = await getOverrides();
    if (overrides.remove(accountId) != null) {
      await prefs.setString(_prefsKey, jsonEncode(overrides));
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
