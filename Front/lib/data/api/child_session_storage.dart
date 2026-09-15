import 'package:shared_preferences/shared_preferences.dart';

class ChildSessionStorage {
  static const _selectedChildKey = 'selected_child_profile_id';

  Future<int?> readSelectedChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedChildKey);
  }

  Future<void> saveSelectedChildId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedChildKey, id);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedChildKey);
  }
}
