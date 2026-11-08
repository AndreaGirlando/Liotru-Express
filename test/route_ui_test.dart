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
import 'package:catania_bus/ui/design.dart';
import 'package:catania_bus/ui/home.dart';
import 'package:catania_bus/ui/routes.dart';
import 'fixtures.dart';
import 'route_fixtures.dart';

Future<void> settleDatabase(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search a bus, switch return direction and open a stop', (
    tester,
  ) async {
    tz.initializeTimeZones();
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({'realtime_enabled': false});
    late Directory directory;
    late AppState state;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('route_ui_');
      final db = await TransitDatabase.open(
        '${directory.path}/ui.db',
        factory: databaseFactoryFfiNoIsolate,
      );
      final zip = await fixtureZip(directory, override: routeFixture);
      await GtfsImporter(db).importZip(zip.path, source: 'SYNTHETIC UI TEST');
      state = AppState(
        db,
        UserPreferences(await SharedPreferences.getInstance()),
        MockClient((_) async => http.Response('', 503)),
      );
      await state.load();
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
    await settleDatabase(tester);
    await tester.tap(find.text('Autobus'));
    await settleDatabase(tester);
    await tester.enterText(find.byType(TextField), 'metro');
    await tester.pump(const Duration(milliseconds: 300));
    await settleDatabase(tester);
    expect(find.byType(RouteCard), findsOneWidget);
    await tester.tap(find.byType(RouteCard));
    await settleDatabase(tester);
    expect(find.widgetWithText(ChoiceChip, 'Andata'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Ritorno'), findsOneWidget);
    expect(find.text('Variante del percorso'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ritorno'));
    await tester.pumpAndSettle();
    final stops = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((stops.first.title as Text).data, 'Policlinico Test');
    expect(find.text('Variante del percorso'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Policlinico Test'));
    await settleDatabase(tester);
    expect(find.text('Arrivi alla fermata'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
