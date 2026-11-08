import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'data/database.dart';
import 'data/gtfs_importer.dart';
import 'data/network.dart';
import 'data/preferences.dart';
import 'data/realtime_service.dart';
import 'domain/models.dart';

class AppState extends ChangeNotifier {
  AppState(this.database, this.preferences, this.client)
      : realtime = RealtimeService(client);
  final TransitDatabase database;
  final UserPreferences preferences;
  final http.Client client;
  final RealtimeService realtime;
  FeedInfo? feed;
  bool importing = false;
  String progress = '';
  ThemeMode get theme => switch(preferences.theme) {
    'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system,
  };
  Future<void> load() async { feed = await database.info(); notifyListeners(); }
  Future<void> toggle(String id) async { await preferences.toggleFavorite(id); notifyListeners(); }
  Future<void> setTheme(String theme) async { await preferences.setTheme(theme); notifyListeners(); }
  Future<void> sources(String static, String rt, bool enabled) async {
    if (static.trim().isNotEmpty) httpsUrl(static);
    if (rt.trim().isNotEmpty) httpsUrl(rt);
    if (enabled && rt.trim().isEmpty) throw const FormatException('Inserisci l’URL TripUpdates JSON');
    await preferences.setSources(static.trim(), rt.trim(), enabled);
    notifyListeners();
  }
  Future<void> import({String? localPath}) async {
    if (importing) return;
    importing = true; progress = 'Preparazione importazione…'; notifyListeners();
    Directory? temp;
    try {
      var path = localPath;
      final source = path == null ? preferences.staticUrl : 'Importazione manuale: ${p.basename(path)}';
      if (path == null) {
        final uri = httpsUrl(preferences.staticUrl);
        temp = await (await getTemporaryDirectory()).createTemp('gtfs_download_');
        path = p.join(temp.path, 'feed.zip');
        progress = 'Download archivio GTFS…'; notifyListeners();
        await downloadFile(client, uri, File(path));
      }
      await GtfsImporter(database).importZip(path,source:source,progress:(message) {
        progress = message; notifyListeners();
      });
      feed = await database.info();
    } finally {
      if (temp != null) await temp.delete(recursive:true);
      importing = false; notifyListeners();
    }
  }
}
