import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
import 'package:catania_bus/ui/settings.dart';
import 'fixtures.dart';

void main() {
  for (final invalidRealtime in [false, true]) {
    testWidgets('download button imports with mounted UI, invalid RT: $invalidRealtime', (tester) async {
      await checkDownload(tester, invalidRealtime: invalidRealtime);
    });
  }
  testWidgets('HTTP failure remains visible and keeps previous GTFS usable', (tester) async {
    await checkDownload(tester, failHttp: true);
  });
}

Future<void> checkDownload(
  WidgetTester tester, {
  bool invalidRealtime = false,
  bool failHttp = false,
}) async {
  tz.initializeTimeZones();
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues({
    if (invalidRealtime) 'realtime_url': 'invalid-disabled-realtime-url',
  });
  late Directory directory;
  late AppState state;
  var requests = 0;
  await tester.runAsync(() async {
    directory = await Directory.systemTemp.createTemp('settings_download_');
    final database = await TransitDatabase.open(
      '${directory.path}/settings.db',
      factory: databaseFactoryFfi,
    );
    final zip = await fixtureZip(directory);
    final bytes = await zip.readAsBytes();
    final client = MockClient((request) async {
      requests++;
      expect(request.url.toString(), UserPreferences.officialGtfsUrl);
      return failHttp ? http.Response('', 503) : http.Response.bytes(bytes, 200);
    });
    state = AppState(
      database,
      UserPreferences(await SharedPreferences.getInstance()),
      client,
      cacheDirectory: () async => directory,
    );
    if (failHttp) {
      await GtfsImporter(database).importZip(zip.path, source: 'PREVIOUS VALID GTFS');
      await state.load();
    }
  });
  final completed = Completer<void>();
  var started = false;
  void watch() {
    started = started || state.importing;
    if (started && !state.importing && !completed.isCompleted) {
      completed.complete();
    }
  }
  state.addListener(watch);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    state.removeListener(watch);
    await tester.runAsync(() async {
      state.client.close();
      await state.database.db.close();
      state.dispose();
      await directory.delete(recursive: true);
    });
  });
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SettingsScreen(state))),
  );
  final button = find.text('Scarica e aggiorna dati');
  await tester.ensureVisible(button);
  await tester.runAsync(() async {
    await tester.tap(button);
    await completed.future.timeout(const Duration(seconds: 20));
  });
  await tester.pumpAndSettle();
  expect(requests, 1);
  expect(state.importing, isFalse);
  expect(state.feed?.stops, 2);
  if (failHttp) {
    expect(state.feed!.source, 'PREVIOUS VALID GTFS');
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, contains('HTTP 503'));
    final stops = await tester.runAsync(() => state.database.search('001'));
    expect(stops!.single.id, 'S1');
  } else {
    expect(find.text('Dati GTFS aggiornati.'), findsOneWidget);
  }
}
