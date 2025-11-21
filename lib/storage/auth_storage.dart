import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

class AuthStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _householdIdKey = 'household_id';
  static const String _userIdKey = 'user_id';
  static const String _darkModeKey = 'is_dark_mode';

  static Future<void> saveLogin({
    required String token,
    required String name,
    required String email,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
    if (userId != null) {
      await prefs.setString(_userIdKey, userId);
    }
  }

  static Future<void> setHouseholdId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_householdIdKey, id);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getHouseholdId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_householdIdKey);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_householdIdKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_darkModeKey);
    
    // Clear API cache when logging out
    ApiClient.clearAllCache();
  }

  static Future<void> saveTimezone(String timezone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('timezone', timezone);
  }

  static Future<String?> getTimezone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('timezone');
  }

  static Future<void> saveDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);
  }

  static Future<bool?> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey);
  }
}
