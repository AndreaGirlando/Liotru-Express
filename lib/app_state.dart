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
import 'domain/gtfs_time.dart';
import 'package:timezone/timezone.dart' as tz;

class AppState extends ChangeNotifier {
  AppState(
    this.database,
    this.preferences,
    this.client, {
    Future<Directory> Function()? cacheDirectory,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       realtime = RealtimeService(client);
  final DateTime Function() clock;
  final TransitDatabase database;
  final UserPreferences preferences;
  final http.Client client;
  final RealtimeService realtime;
  final Future<Directory> Function() cacheDirectory;
  FeedInfo? feed;
  bool importing = false;
  String progress = '';
  double? downloadProgress;
  bool automaticUpdating = false;
  String? automaticMessage;
  bool automaticFailed = false;
  Future<void>? _automaticTask;
  bool _automaticStarted = false;
  DateTime? _nextAttempt;
  bool get feedExpired =>
      feed != null &&
      (feed!.endDate.isEmpty ||
          feed!.endDate.compareTo(
                serviceDate(tz.TZDateTime.from(clock(), rome)),
              ) <
              0);

  void dismissAutomaticMessage() {
    automaticMessage = null;
    notifyListeners();
  }

  Future<void> refreshScheduleIfNeeded({bool force = false}) {
    if (_automaticTask != null) return _automaticTask!;
    if (importing || (!force && feed != null && !feedExpired)) {
      return Future.value();
    }
    final now = clock().toUtc();
    final retry = _nextAttempt ?? preferences.nextAutomaticUpdate;
    if (!force && _automaticStarted && retry != null && now.isBefore(retry)) {
      return Future.value();
    }
    if (!force && feed != null && retry != null && now.isBefore(retry)) {
      return Future.value();
    }
    _automaticStarted = true;
    final task = _refreshAutomatically();
    _automaticTask = task;
    return task.whenComplete(() => _automaticTask = null);
  }

  Future<void> _refreshAutomatically() async {
    automaticUpdating = true;
    automaticFailed = false;
    automaticMessage = feed == null
        ? null
        : 'Gli orari AMTS sono scaduti. Li aggiorniamo in background.';
    notifyListeners();
    try {
      await import(keepNewerCalendar: true);
      automaticMessage = feedExpired
          ? 'AMTS non ha ancora pubblicato un calendario valido per oggi. Riproveremo automaticamente.'
          : 'Orari AMTS aggiornati.';
      _nextAttempt = clock().toUtc().add(
        feedExpired ? const Duration(hours: 6) : Duration.zero,
      );
    } catch (error) {
      automaticFailed = true;
      automaticMessage = error is HttpException
          ? '${error.message}. Riproveremo automaticamente.'
          : error is FormatException
          ? '${error.message}. Riprova o importa uno ZIP dalle impostazioni.'
          : 'Aggiornamento AMTS non riuscito. Controlla la connessione: riproveremo automaticamente.';
      _nextAttempt = clock().toUtc().add(const Duration(minutes: 15));
    } finally {
      automaticUpdating = false;
      // Retry persistence is a convenience, never a reason to lose downloaded data.
      try {
        await preferences.setNextAutomaticUpdate(_nextAttempt!);
      } catch (_) {
        /* Keep the in-memory retry deadline. */
      }
      notifyListeners();
    }
  }

  ThemeMode get theme => switch (preferences.theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  Future<void> load() async {
    await preferences.migrateMetroFavorite();
    feed = await database.info();
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    await preferences.toggleFavorite(id);
    notifyListeners();
  }

  Future<void> favoriteMetro(String id) async {
    await preferences.setMetroFavoriteStation(id);
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    await preferences.setTheme(theme);
    notifyListeners();
  }

  Future<void> sources(String static, String rt, bool enabled) async {
    if (static.trim().isNotEmpty) httpsUrl(static);
    if (rt.trim().isNotEmpty) httpsUrl(rt);
    if (enabled && rt.trim().isEmpty) {
      throw const FormatException('Inserisci l’URL TripUpdates JSON');
    }
    await preferences.setSources(static.trim(), rt.trim(), enabled);
    notifyListeners();
  }

  Future<void> downloadGtfs(String url) async {
    httpsUrl(url);
    await preferences.setStaticUrl(url.trim());
    await import();
  }

  Future<void> setRealtimeEnabled(bool value) async {
    if (value) httpsUrl(preferences.realtimeUrl);
    await preferences.setRealtimeEnabled(value);
    notifyListeners();
  }

  Future<void> import({
    String? localPath,
    bool keepNewerCalendar = false,
  }) async {
    if (importing) return;
    importing = true;
    downloadProgress = null;
    progress = 'Preparazione importazione…';
    notifyListeners();
    Directory? temp;
    TransitDatabase? staging;
    final updates = Stopwatch()..start();
    void report(String text, {double? fraction}) {
      progress = text;
      downloadProgress = fraction;
      if (updates.elapsedMilliseconds >= 150) {
        updates.reset();
        notifyListeners();
      }
    }

    try {
      final cache = await cacheDirectory();
      temp = await cache.createTemp('gtfs_update_');
      var path = localPath;
      final source = path == null
          ? preferences.staticUrl
          : 'Importazione manuale: ${p.basename(path)}';
      if (path == null) {
        final uri = httpsUrl(preferences.staticUrl);
        path = p.join(temp.path, 'feed.zip');
        progress = 'Scaricamento degli orari AMTS…';
        notifyListeners();
        await downloadFile(
          client,
          uri,
          File(path),
          onProgress: (received, total) {
            final fraction = total != null && total > 0
                ? (received / total).clamp(0.0, 1.0).toDouble()
                : null;
            report('Scaricamento degli orari AMTS…', fraction: fraction);
          },
        );
      }
      downloadProgress = null;
      progress = 'Preparazione delle fermate e degli orari…';
      notifyListeners();
      final stagingPath = p.join(temp.path, 'incoming.db');
      staging = await TransitDatabase.open(
        stagingPath,
        factory: database.factory,
      );
      await GtfsImporter(staging).importZip(
        path,
        source: source,
        temporaryRoot: temp.path,
        progress: (message) => report(
          message.startsWith('Importazione GTFS')
              ? 'Organizziamo linee e fermate…'
              : 'Prepariamo gli orari per usarli offline…',
        ),
      );
      final candidate = (await staging.info())!;
      await staging.db.close();
      staging = null;
      final today = serviceDate(tz.TZDateTime.from(clock(), rome));
      if (keepNewerCalendar &&
          feed != null &&
          candidate.endDate.compareTo(today) < 0 &&
          candidate.endDate.compareTo(feed!.endDate) <= 0) {
        return;
      }
      await database.replaceFrom(stagingPath);
      feed = await database.info();
    } finally {
      try {
        if (staging != null) await staging.db.close();
        if (temp != null && await temp.exists()) {
          await temp.delete(recursive: true);
        }
      } finally {
        importing = false;
        downloadProgress = null;
        notifyListeners();
      }
    }
  }
}
