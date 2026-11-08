import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:catania_bus/domain/metro.dart';
import 'package:catania_bus/data/metro_timetable.dart';
import 'metro_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz.initializeTimeZones);
  test('station estimates follow both terminal departures and distinct offsets', () {
    final data = syntheticMetro();
    final now = DateTime.utc(2026, 11, 9, 5, 5); // 06:05 Rome
    final out = data.upcoming(data.stations[1], MetroDirection.stesicoro, now);
    final back = data.upcoming(data.stations[1], MetroDirection.montePo, now);
    expect(out.first.time, DateTime.utc(2026, 11, 9, 5, 10));
    expect(back.first.time, DateTime.utc(2026, 11, 9, 5, 15));
    expect(out.first.estimated, isTrue);
    expect(data.upcoming(data.stations.first, MetroDirection.montePo, now), isEmpty);
    expect(data.upcoming(data.stations.first, MetroDirection.stesicoro, now).first.estimated, isFalse);
  });
  test('late Friday trains remain on Friday service after Saturday midnight', () {
    final data = syntheticMetro();
    final now = DateTime.utc(2026, 11, 6, 23, 25); // Saturday 00:25 Rome
    final next = data.upcoming(data.stations[1], MetroDirection.stesicoro, now).first;
    expect(next.departure, DateTime.utc(2026, 11, 6, 23, 30));
    expect(next.time, DateTime.utc(2026, 11, 6, 23, 40));
    expect(metroCountdown(next.time, now), '15:00');
  });
  test('day types distinguish national holidays and Easter Monday', () {
    expect(MetroTimetable.dayType(DateTime.utc(2026, 11, 9)), 'weekday');
    expect(MetroTimetable.dayType(DateTime.utc(2026, 11, 6)), 'friday');
    expect(MetroTimetable.dayType(DateTime.utc(2026, 11, 7)), 'saturday');
    expect(MetroTimetable.dayType(DateTime.utc(2026, 11, 8)), 'sunday');
    expect(MetroTimetable.dayType(DateTime.utc(2026, 4, 6)), 'holiday_weekday');
    expect(MetroTimetable.dayType(DateTime.utc(2026, 5, 1)), 'holiday_late');
  });
  test('next morning uses an hour instead of a huge minute countdown', () {
    final data = syntheticMetro();
    final now = DateTime.utc(2026, 11, 9, 21);
    final next = data.upcoming(data.stations[1], MetroDirection.stesicoro, now).first;
    expect(metroCountdown(next.time, now), '06:10');
    expect(next.time, DateTime.utc(2026, 11, 10, 5, 10));
  });
  test('bundled official departures retain provenance and twelve station offsets', () async {
    final data = await loadMetroTimetable();
    expect(data.stations, hasLength(12));
    final milo = data.stations.singleWhere((s) => s.name == 'Milo');
    expect(milo.toStesicoro, 540);
    expect(milo.toMontePo, 660);
    expect(data.offsetsValidUntil, '20250228');
    expect(data.days['weekday']!['stesicoro']!.first, 6 * 3600);
    expect(data.days['sunday']!['stesicoro']!.first, 7 * 3600);
    expect(data.days['friday']!['montepo']!.last, 25 * 3600);
    expect(data.sourceUrl, contains('circumetnea.it'));
  });
}
