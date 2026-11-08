// Live check of the same HTTP -> ZIP -> SQLite pipeline used by the button.
// Invoked explicitly in CI, separate from the synthetic test suite.
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:catania_bus/app_state.dart';
import 'package:catania_bus/data/database.dart';
import 'package:catania_bus/data/preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('official GTFS downloads and imports through AppState', () async {
    tz.initializeTimeZones();
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('official_http_');
    final database = await TransitDatabase.open(
      '${directory.path}/official.db',
      factory: databaseFactoryFfi,
    );
    final state = AppState(
      database,
      UserPreferences(await SharedPreferences.getInstance()),
      http.Client(),
      cacheDirectory: () async => directory,
    );
    final port = ReceivePort();
    state.addListener(() => port.sendPort.send(state.progress));
    try {
      await state.downloadGtfs(UserPreferences.officialGtfsUrl);
      expect(state.importing, isFalse);
      expect(state.feed!.stops, greaterThan(0));
      expect(state.feed!.source, UserPreferences.officialGtfsUrl);
      expect(await database.search(''), isNotEmpty);
      // ignore: avoid_print
      print('Pulsante GTFS verificato con HTTP Dart reale: '
          '${state.feed!.stops} fermate importate e ricercabili offline.');
    } finally {
      port.close();
      state.client.close();
      state.dispose();
      await database.db.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
