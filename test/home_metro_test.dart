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
import 'package:catania_bus/ui/design.dart';
import 'package:catania_bus/ui/home_metro.dart';
import 'metro_fixtures.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    sqfliteFfiInit();
  });
  late AppState state;
  late Directory directory;
  var requests = 0;
  var now = DateTime.utc(2026, 11, 9, 5, 5);
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'metro_station': 'A',
      'metro_favorite_station': 'B',
    });
    directory = await Directory.systemTemp.createTemp('home_metro_');
    final db = await TransitDatabase.open('${directory.path}/app.db', factory: databaseFactoryFfiNoIsolate);
    requests = 0;
    now = DateTime.utc(2026, 11, 9, 5, 5);
    state = AppState(db, UserPreferences(await SharedPreferences.getInstance()), MockClient((_) async {
      requests++;
      return http.Response('', 503);
    }), clock: () => now);
  });
  tearDown(() async {
    state.client.close();
    state.dispose();
    await state.database.db.close();
    await directory.delete(recursive: true);
  });

  Future<void> show(WidgetTester tester, {double width = 430, double textScale = 1}) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: BusDesign.theme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: ListView(padding: const EdgeInsets.all(22), children: [HomeMetroCard(state, timetable: syntheticMetro())])),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Home shows both favorite station directions offline and persists a new favorite', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester);
    expect(find.text('Milo Test'), findsOneWidget);
    expect(find.text('Verso Stesicoro'), findsOneWidget);
    expect(find.text('Verso Monte Po'), findsOneWidget);
    expect(find.text('~5:00'), findsOneWidget);
    expect(find.text('~10:00'), findsOneWidget);
    expect(requests, 0);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monte Po Test').last);
    await tester.pumpAndSettle();
    expect(state.preferences.metroFavoriteStation, 'A');
    expect(state.preferences.prefs.getString('metro_favorite_station'), 'A');
    expect(find.text('Sei al capolinea'), findsOneWidget);
    // Browsing another station must not silently replace the Home favorite.
    await state.preferences.setMetroStation('C');
    expect(state.preferences.metroFavoriteStation, 'A');
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester);
    expect(find.text('Monte Po Test'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('countdowns recover from pause and switch to day and clock overnight', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('~4:00'), findsOneWidget);
    now = DateTime.utc(2026, 11, 9, 22);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Domani'), findsNWidgets(2));
    expect(find.text('~06:10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Home metro remains readable on a narrow phone with large text', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, width: 320, textScale: 2);
    expect(find.text('Verso Stesicoro'), findsOneWidget);
    expect(find.text('Verso Monte Po'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
