import 'package:shared_preferences/shared_preferences.dart';

class ChildSessionStorage {
  static const _selectedChildKey = 'selected_child_profile_id';
  static const _selectedChildLocaleKey = 'selected_child_profile_locale';

  Future<int?> readSelectedChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedChildKey);
  }

  Future<String?> readSelectedChildLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_selectedChildLocaleKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveSelectedChildId(
    int id, {
    String? localeCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedChildKey, id);

    final normalizedLocale = localeCode?.trim().toLowerCase();
    if (normalizedLocale != null && normalizedLocale.isNotEmpty) {
      await prefs.setString(_selectedChildLocaleKey, normalizedLocale);
    }
  }

  Future<void> saveSelectedChildLocale(String? localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedLocale = localeCode?.trim().toLowerCase();
    if (normalizedLocale == null || normalizedLocale.isEmpty) {
      await prefs.remove(_selectedChildLocaleKey);
      return;
    }
    await prefs.setString(_selectedChildLocaleKey, normalizedLocale);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedChildKey);
    await prefs.remove(_selectedChildLocaleKey);
  }
}
