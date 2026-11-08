import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catania_bus/ui/design.dart';
import 'package:catania_bus/ui/home.dart';
import 'package:catania_bus/ui/stop_detail.dart';
import 'package:catania_bus/ui/routes.dart';
import 'package:catania_bus/ui/metro.dart';
import 'package:catania_bus/data/metro_timetable.dart';
import 'package:catania_bus/domain/metro.dart';
import 'package:catania_bus/ui/app_chrome.dart';
import 'package:catania_bus/ui/initial_download.dart';
import 'live_snapshot_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LiveSnapshotFixture fixture;
  late MetroTimetable metroTimetable;
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    fixture = await loadLiveSnapshot();
    metroTimetable = await loadMetroTimetable();
  });
  tearDownAll(() async => fixture.close());
  for (final dark in [false, true]) {
    testWidgets(dark ? 'real stop dark preview' : 'favorites light preview', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: BusDesign.theme(dark ? Brightness.dark : Brightness.light),
          home: RepaintBoundary(
            key: const Key('preview'),
            child: dark
                ? StopDetail(
                    fixture.state,
                    fixture.stop,
                    clock: () => fixture.now,
                  )
                : HomeScreen(fixture.state),
          ),
        ),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('preview')),
        matchesGoldenFile(
          dark ? 'previews/stop-dark.png' : 'previews/home-light.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Metro Shuttle outbound and return real stop previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final routes = await tester.runAsync(
      () => fixture.state.database.searchRoutes('Metro Shuttle'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: BusDesign.theme(Brightness.light),
        home: RepaintBoundary(
          key: const Key('bus-preview'),
          child: RouteDetail(fixture.state, routes!.first),
        ),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ChoiceChip, 'Andata'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Ritorno'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('bus-preview')),
      matchesGoldenFile('previews/bus-andata.png'),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ritorno'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('bus-preview')),
      matchesGoldenFile('previews/bus-ritorno.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Metro Milo both directions official timetable preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: BusDesign.theme(Brightness.light),
        home: RepaintBoundary(
          key: const Key('metro-preview'),
          child: Scaffold(
            appBar: const AppTopBar(section: 'Metro FCE'),
            body: SafeArea(
              top: false,
              child: MetroScreen(
                fixture.state,
                timetable: metroTimetable,
                clock: () => DateTime.utc(2026, 11, 8, 11, 0),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Verso Stesicoro'), findsOneWidget);
    expect(find.text('Verso Monte Po'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('metro-preview')),
      matchesGoldenFile('previews/metro-milo.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('first AMTS download animation preview', (tester) async {
    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: BusDesign.theme(Brightness.light),
      home: RepaintBoundary(key: const Key('initial-preview'), child: Scaffold(
        appBar: const AppTopBar(section: 'Benvenuto a bordo'),
        body: InitialDownload(busy: true, progress: 'Scaricamento degli orari AMTS…', fraction: .46, onRetry: () {}, onContinue: () {}),
      )),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const Key('initial-preview')), matchesGoldenFile('previews/first-download.png'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
