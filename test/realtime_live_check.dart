import 'package:flutter_test/flutter_test.dart';
import 'package:catania_bus/ui/arrivals_controller.dart';
import 'package:catania_bus/domain/arrival_display.dart';
import 'live_snapshot_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real BusOne forecasts reach the arrival screen with their uncertainty',
    () async {
      final fixture = await loadLiveSnapshot();
      try {
        if (fixture.candidateCount > 0) {
          expect(
            fixture.liveCount,
            greaterThan(0),
            reason:
                'The provider has usable predictions, but none reaches the app',
          );
          final view = ArrivalsController(
            fixture.state,
            fixture.stop,
            clock: () => fixture.now,
          );
          await view.refresh();
          expect(view.status, ArrivalsStatus.live);
          expect(view.nearby.any((a) => a.isRealtime), isTrue);
          expect(
            view.nearby.every(
              (a) =>
                  a.time.difference(fixture.now) <= const Duration(minutes: 90),
            ),
            isTrue,
          );
          // ignore: avoid_print
          print(
            'BusOne -> schermata arrivi verificato: ${view.nearby.where((a) => a.isRealtime).length} previsioni reali alla fermata ${fixture.stop.id} (${fixture.stop.name}); ${view.nearby.where((a) => a.isApproximate).length} con margine esplicito.',
          );
          view.dispose();
        } else {
          // ignore: avoid_print
          print(
            'Il campione BusOne non contiene previsioni correnti utilizzabili: il programma resta il fallback.',
          );
        }
        final milo = await fixture.state.database.search('', ids: ['1928']);
        if (milo.isNotEmpty) {
          final shuttle = ArrivalsController(
            fixture.state,
            milo.first,
            clock: () => fixture.now,
          );
          await shuttle.refresh();
          final published = shuttle.arrivals
              .where((a) => a.route == 'A-MS')
              .toList();
          if (published.isNotEmpty) {
            final first = published.first;
            final label = arrivalWait(first.time, fixture.now);
            if (first.time.difference(fixture.now) >
                ArrivalsController.nearbyWindow) {
              expect(label, isNot(contains(' min')));
              expect(shuttle.later, contains(first));
              expect(shuttle.nearby, isNot(contains(first)));
            }
            // ignore: avoid_print
            print(
              'Metro Shuttle a Stazione Milo: $label; live: ${first.isRealtime}.',
            );
          }
          shuttle.dispose();
        }
      } finally {
        await fixture.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
