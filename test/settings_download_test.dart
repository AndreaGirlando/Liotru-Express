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
import 'package:catania_bus/data/preferences.dart';
import 'package:catania_bus/ui/settings.dart';
import 'fixtures.dart';

void main() {
  testWidgets('download button imports GTFS with a mounted settings screen', (
    tester,
  ) async {
    tz.initializeTimeZones();
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
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
        return http.Response.bytes(bytes, 200);
      });
      state = AppState(
        database,
        UserPreferences(await SharedPreferences.getInstance()),
        client,
        cacheDirectory: () async => directory,
      );
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
    expect(state.feed?.stops, 2);
    expect(find.text('Dati GTFS aggiornati.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.removeListener(watch);
    await tester.runAsync(() async {
      state.client.close();
      await state.database.db.close();
      state.dispose();
      await directory.delete(recursive: true);
    });
  });
}
