import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  UserPreferences(this.prefs);
  final SharedPreferences prefs;
  List<String> get favorites => prefs.getStringList('favorites') ?? [];
  String get theme => prefs.getString('theme') ?? 'system';
  String get staticUrl => prefs.getString('static_url') ?? '';
  String get realtimeUrl => prefs.getString('realtime_url') ?? '';
  bool get realtimeEnabled => prefs.getBool('realtime_enabled') ?? false;
  Future<void> toggleFavorite(String id) async {
    final ids = favorites;
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    await prefs.setStringList('favorites', ids);
  }
  Future<void> setTheme(String value) async { await prefs.setString('theme', value); }
  Future<void> setSources(String staticUrl, String rtUrl, bool enabled) async {
    await prefs.setString('static_url',staticUrl);
    await prefs.setString('realtime_url',rtUrl);
    await prefs.setBool('realtime_enabled',enabled);
  }
}
