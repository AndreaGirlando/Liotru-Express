import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:catania_bus/ui/arrivals_controller.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late TransitDatabase database;
  final now = DateTime.utc(2026, 11, 7, 8, 50);
  setUpAll(() {
    tz.initializeTimeZones();
    sqfliteFfiInit();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'realtime_enabled': true});
    dir = await Directory.systemTemp.createTemp('arrival_controller_');
    database = await TransitDatabase.open(
      '${dir.path}/test.db',
      factory: databaseFactoryFfi,
    );
    final zip = await fixtureZip(dir);
    await GtfsImporter(database).importZip(zip.path, source: 'SYNTHETIC');
  });
  tearDown(() async {
    await database.db.close();
    await dir.delete(recursive: true);
  });
  Future<AppState> state(http.Client client) async => AppState(
    database,
    UserPreferences(await SharedPreferences.getInstance()),
    client,
    cacheDirectory: () async => dir,
  );
  test(
    'SQLite arrivals are visible while a slow realtime request is pending',
    () async {
      final gate = Completer<http.Response>();
      final app = await state(MockClient((_) => gate.future));
      final view = ArrivalsController(
        app,
        const BusStop('S1', '001', 'Synthetic'),
        clock: () => now,
      );
      final visible = Completer<void>();
      view.addListener(() {
        if (!view.loading && view.refreshing && !visible.isCompleted) {
          visible.complete();
        }
      });
      final task = view.refresh();
      await visible.future;
      expect(view.nearby.single.isRealtime, isFalse);
      expect(view.status, ArrivalsStatus.checking);
      gate.complete(
        http.Response(
          jsonEncode({
            'header': {'timestamp': now.millisecondsSinceEpoch ~/ 1000},
            'entity': [
              {
                'id': 'test',
                'tripUpdate': {
                  'trip': {'tripId': 'T1', 'startDate': '20261107'},
                  'stopTimeUpdate': [
                    {
                      'stopSequence': 1,
                      'stopId': 'S1',
                      'arrival': {'delay': 120, 'uncertainty': 300},
                    },
                  ],
                },
              },
            ],
          }),
          200,
        ),
      );
      await task;
      expect(view.status, ArrivalsStatus.live);
      expect(view.nearby.single.isRealtime, isTrue);
      expect(view.nearby.single.isApproximate, isTrue);
      expect(view.later, isNotEmpty);
      view.dispose();
      app.client.close();
    },
  );
  test(
    'reachable feed without predictions for a stop is not advertised as live',
    () async {
      final app = await state(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'header': {'timestamp': now.millisecondsSinceEpoch ~/ 1000},
              'entity': [],
            }),
            200,
          ),
        ),
      );
      final view = ArrivalsController(
        app,
        const BusStop('S1', '001', 'Synthetic'),
        clock: () => now,
      );
      await view.refresh();
      expect(view.status, ArrivalsStatus.noCoverage);
      expect(view.message, contains('Nessuna previsione'));
      expect(view.nearby.single.isRealtime, isFalse);
      view.dispose();
      app.client.close();
    },
  );
}
