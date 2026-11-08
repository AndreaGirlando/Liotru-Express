import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:catania_bus/domain/arrival_display.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  final now = DateTime.utc(2026, 11, 8, 9);
  test('tomorrow is a date and clock time, never a thousand minute counter', () {
    final label = arrivalWait(now.add(const Duration(minutes: 1000)), now);
    expect(label, 'Domani 02:40');
    expect(label, isNot(contains('1000')));
  });
  test('nearby arrivals retain minutes even across midnight', () {
    final late = DateTime.utc(2026, 11, 8, 22, 55);
    expect(arrivalWait(late.add(const Duration(minutes: 15)), late), 'tra 15 min');
    expect(arrivalWait(now.add(const Duration(hours: 3)), now), 'Oggi 13:00');
  });
}
