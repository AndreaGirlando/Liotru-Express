import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catania_bus/ui/design.dart';
import 'package:catania_bus/ui/home.dart';
import 'package:catania_bus/ui/stop_detail.dart';
import 'live_snapshot_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LiveSnapshotFixture fixture;
  setUpAll(() async {
    final loader = FontLoader('Manrope')..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load(); fixture = await loadLiveSnapshot();
  });
  tearDownAll(() async => fixture.close());
  for (final dark in [false, true]) {
    testWidgets(dark ? 'real stop dark preview' : 'favorites light preview', (tester) async {
      tester.view.physicalSize = const Size(430, 960); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: BusDesign.theme(dark ? Brightness.dark : Brightness.light), home: RepaintBoundary(key: const Key('preview'), child: dark ? StopDetail(fixture.state, fixture.stop, clock: () => fixture.now) : HomeScreen(fixture.state))));
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('preview')), matchesGoldenFile(dark ? 'previews/stop-dark.png' : 'previews/home-light.png'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
