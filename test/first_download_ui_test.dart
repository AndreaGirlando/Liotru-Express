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
import 'package:catania_bus/ui/home.dart';
import 'package:catania_bus/ui/initial_download.dart';
import 'package:catania_bus/ui/design.dart';
import 'fixtures.dart';

Future<void> pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 1000; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  fail('The automatic update did not reach its expected UI state');
}

void main() {
  for (final background in [false, true]) {
    testWidgets(background ? 'expired data refresh without blocking the home or showing the welcome animation' : 'first use downloads with animation and opens Home automatically', (tester) async {
      tz.initializeTimeZones();
      sqfliteFfiInit();
      SharedPreferences.setMockInitialValues({'favorites': ['S1']});
      late Directory directory;
      late AppState state;
      late List<int> bytes;
      final pending = Completer<http.Response>();
      var requests = 0;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('first_download_ui_');
        final db = await TransitDatabase.open('${directory.path}/app.db', factory: databaseFactoryFfiNoIsolate);
        final zip = await fixtureZip(directory);
        bytes = await zip.readAsBytes();
        if (background) await GtfsImporter(db).importZip(zip.path, source: 'OLD');
        state = AppState(db, UserPreferences(await SharedPreferences.getInstance()), MockClient((_) { requests++; return pending.future; }), cacheDirectory: () async => directory, clock: () => DateTime.utc(background ? 2027 : 2026, 11, 8, 11));
        await state.load();
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!pending.isCompleted) pending.complete(http.Response('', 503));
        await tester.runAsync(() async { await state.refreshScheduleIfNeeded(); state.client.close(); state.dispose(); await state.database.db.close(); await directory.delete(recursive: true); });
      });
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: BusDesign.theme(Brightness.light), home: HomeScreen(state)));
      await pumpUntil(tester, () => requests == 1);
      expect(state.importing, isTrue);
      if (background) {
        expect(find.byType(InitialDownload), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.textContaining('background'), findsOneWidget);
        expect(find.text('Bus'), findsOneWidget);
        expect((await tester.runAsync(() => state.database.search('001')))!.single.id, 'S1');
      } else {
        expect(find.byType(InitialDownload), findsOneWidget);
        expect(find.byKey(const Key('download-bus')), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      }
      pending.complete(http.Response.bytes(bytes, 200));
      await pumpUntil(tester, () => !state.importing && !state.automaticUpdating && find.byType(CircularProgressIndicator).evaluate().isEmpty);
      expect(find.byType(InitialDownload), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(state.feed?.stops, 2);
      expect(requests, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
