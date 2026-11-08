import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  UserPreferences(this.prefs);
  final SharedPreferences prefs;
  List<String> get favorites => prefs.getStringList('favorites') ?? [];
  String get theme => prefs.getString('theme') ?? 'system';
  static const officialGtfsUrl = 'https://www.amts.ct.it/GTFS/AMTCT.zip';
  static const busoneUrl =
      'https://proxy.busone.app/amts/gtfs-rt/trip-updates.json';
  static const clientIdentity =
      'CataniaBus/2.2; https://github.com/AndreaGirlando';
  String get staticUrl => prefs.getString('static_url') ?? officialGtfsUrl;
  String get realtimeUrl => prefs.getString('realtime_url') ?? busoneUrl;
  String get metroStation => prefs.getString('metro_station') ?? '1663';
  Future<void> setMetroStation(String id) async { await prefs.setString('metro_station', id); }
  bool get realtimeEnabled => prefs.getBool('realtime_enabled') ?? true;
  Future<void> setRealtimeEnabled(bool value) async {
    await prefs.setBool('realtime_enabled', value);
  }

  Future<void> toggleFavorite(String id) async {
    final ids = favorites;
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    await prefs.setStringList('favorites', ids);
  }

  Future<void> setTheme(String value) async {
    await prefs.setString('theme', value);
  }

  Future<void> setStaticUrl(String value) async {
    await prefs.setString('static_url', value);
  }

  Future<void> setSources(String staticUrl, String rtUrl, bool enabled) async {
    await prefs.setString('static_url', staticUrl);
    await prefs.setString('realtime_url', rtUrl);
    await prefs.setBool('realtime_enabled', enabled);
  }
}
