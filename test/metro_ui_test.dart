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
import 'package:catania_bus/data/metro_timetable.dart';
import 'package:catania_bus/data/preferences.dart';
import 'package:catania_bus/ui/design.dart';
import 'package:catania_bus/ui/home.dart';
import 'package:catania_bus/ui/metro.dart';
import 'package:catania_bus/domain/metro.dart';
import 'metro_fixtures.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets(
    'Metro tab works offline, labels estimates and persists station',
    (tester) async {
      sqfliteFfiInit();
      SharedPreferences.setMockInitialValues({});
      late Directory directory;
      late AppState state;
      var requests = 0;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('metro_ui_');
        final db = await TransitDatabase.open(
          '${directory.path}/metro-test.db',
          factory: databaseFactoryFfiNoIsolate,
        );
        state = AppState(
          db,
          UserPreferences(await SharedPreferences.getInstance()),
          MockClient((_) async {
            requests++;
            return http.Response('', 503);
          }),
        );
        await state.load();
        await loadMetroTimetable();
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          state.client.close();
          state.dispose();
          await state.database.db.close();
          await directory.delete(recursive: true);
        });
      });
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: BusDesign.theme(Brightness.light),
          home: HomeScreen(state),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Metro'));
      await tester.pumpAndSettle();
      expect(find.text('Verso Stesicoro'), findsOneWidget);
      expect(find.text('Verso Monte Po'), findsOneWidget);
      expect(find.textContaining('Nessun dato live'), findsOneWidget);
      expect(find.textContaining('febbraio 2025'), findsOneWidget);
      expect(requests, 0);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stesicoro').last);
      await tester.pumpAndSettle();
      expect(find.text('Sei al capolinea'), findsOneWidget);
      expect(state.preferences.metroStation, '1657');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Metro estimate card supports a narrow phone and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = syntheticMetro();
    await tester.pumpWidget(
      MaterialApp(
        theme: BusDesign.theme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                MetroArrivalCard(
                  data,
                  data.stations[1],
                  MetroDirection.stesicoro,
                  DateTime.utc(2026, 11, 9, 5, 5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
