// Real captured AMTS/BusOne data for explicit integration checks and previews.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:catania_bus/app_state.dart';
import 'package:catania_bus/data/database.dart';
import 'package:catania_bus/data/gtfs_importer.dart';
import 'package:catania_bus/data/preferences.dart';
import 'package:catania_bus/domain/models.dart';
import 'package:catania_bus/domain/realtime.dart';

class LiveSnapshotFixture {
  LiveSnapshotFixture(
    this.directory,
    this.state,
    this.stop,
    this.now,
    this.liveCount,
    this.candidateCount,
  );
  final Directory directory;
  final AppState state;
  final BusStop stop;
  final DateTime now;
  final int liveCount, candidateCount;
  Future<void> close() async {
    state.client.close();
    state.dispose();
    await state.database.db.close();
    await directory.delete(recursive: true);
  }
}

Future<LiveSnapshotFixture> loadLiveSnapshot() async {
  tz.initializeTimeZones();
  sqfliteFfiInit();
  final path = Platform.environment['CATANIABUS_REAL_GTFS']!;
  final body = await File(
    'source-verification/trip-updates.txt',
  ).readAsString();
  final json = jsonDecode(body) as Map<String, dynamic>;
  final now = DateTime.fromMillisecondsSinceEpoch(
    number(json['header']['timestamp'])! * 1000,
    isUtc: true,
  );
  final feed = RealtimeFeed.parse(json, now);
  final directory = await Directory.systemTemp.createTemp('live_snapshot_');
  final database = await TransitDatabase.open(
    '${directory.path}/live.db',
    factory: databaseFactoryFfiNoIsolate,
  );
  await GtfsImporter(database).importZip(
    path,
    source: UserPreferences.officialGtfsUrl,
    temporaryRoot: directory.path,
  );
  final candidates = <String>{};
  for (final update in feed.updates) {
    final stops = field(update, 'stopTimeUpdate', 'stop_time_update');
    if (stops is! List) continue;
    for (final value in stops) {
      final stop = object(value);
      if (stop == null) continue;
      final arrival = object(stop['arrival']);
      final timestamp = number(arrival?['time']);
      final uncertainty = number(arrival?['uncertainty']) ?? 0;
      final delay = number(arrival?['delay']);
      final id = field(stop, 'stopId', 'stop_id');
      if (id is String &&
          timestamp != null &&
          timestamp >= now.millisecondsSinceEpoch ~/ 1000 &&
          timestamp <= now.millisecondsSinceEpoch ~/ 1000 + 90 * 60 &&
          uncertainty >= 0 &&
          uncertainty <= RealtimeFeed.maxUncertaintySeconds &&
          (delay == null || delay.abs() <= 3 * 3600)) {
        candidates.add(id);
      }
    }
  }
  BusStop? chosen;
  var liveCount = 0;
  for (final id in candidates.take(50)) {
    final stops = await database.search('', ids: [id]);
    if (stops.isEmpty) continue;
    final schedule = await database.arrivals(
      id,
      now.subtract(const Duration(hours: 3)),
      horizon: const Duration(hours: 27),
    );
    final real = feed
        .apply(schedule, now)
        .where(
          (a) =>
              a.isRealtime &&
              !a.time.isBefore(now) &&
              a.time.difference(now) <= const Duration(minutes: 90),
        )
        .toList();
    if (real.isNotEmpty) {
      chosen = stops.first;
      liveCount = real.length;
      break;
    }
  }
  final selected = chosen ?? (await database.search('')).first;
  SharedPreferences.setMockInitialValues({'realtime_enabled': true});
  final prefs = UserPreferences(await SharedPreferences.getInstance());
  final favoriteIds = {
    selected.id,
    ...(await database.search('Stesicoro')).take(1).map((s) => s.id),
    ...(await database.search('Stazione')).take(1).map((s) => s.id),
  }.toList();
  await prefs.prefs.setStringList('favorites', favoriteIds);
  final app = AppState(
    database,
    prefs,
    MockClient((_) async => http.Response(body, 200)),
    cacheDirectory: () async => directory,
  );
  await app.load();
  return LiveSnapshotFixture(
    directory,
    app,
    selected,
    now,
    liveCount,
    candidates.length,
  );
}
