// Live integration check, separate from synthetic automatic unit fixtures.
// Invoked explicitly in CI only when an official AMTS ZIP was downloaded.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:catania_bus/data/database.dart';
import 'package:catania_bus/data/gtfs_importer.dart';
import 'package:catania_bus/domain/gtfs_time.dart';

void main() {
  test(
    'import actual official AMTS feed and find a published arrival',
    () async {
      final source = Platform.environment['CATANIABUS_REAL_GTFS'];
      expect(
        source,
        isNotNull,
        reason: 'This check requires the official ZIP snapshot',
      );
      tz.initializeTimeZones();
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'official_check_',
      );
      final db = await TransitDatabase.open(
        '${directory.path}/official.db',
        factory: databaseFactoryFfi,
      );
      try {
        await GtfsImporter(
          db,
        ).importZip(source!, source: 'AMTS official live integration check');
        final info = (await db.info())!;
        expect(info.stops, greaterThan(0));
        final row = (await db.db.rawQuery(
          '''SELECT st.stop_id, st.arrival_secs, cd.date
        FROM stop_times st JOIN trips t ON st.trip_id=t.trip_id
        JOIN calendar_dates cd ON cd.service_id=t.service_id
        WHERE cd.exception_type=1 AND st.arrival_secs IS NOT NULL AND st.pickup_type!='1' LIMIT 1''',
        )).single;
        final when = serviceInstant(
          parseServiceDate(row['date'] as String),
          row['arrival_secs'] as int,
        );
        final arrivals = await db.arrivals(
          row['stop_id'] as String,
          when.subtract(const Duration(seconds: 1)),
        );
        expect(arrivals, isNotEmpty);
        expect(arrivals.any((a) => a.scheduled == when), isTrue);
        final routes = await db.searchRoutes('');
        expect(routes, isNotEmpty);
        for (final query in ['Metro Shuttle', '156', 'BRT1']) {
          final route = (await db.searchRoutes(query)).first;
          final patterns = await db.routePatterns(route.id);
          expect(patterns, isNotEmpty);
          expect(
            patterns.map((p) => p.directionId).toSet(),
            containsAll(['0', '1']),
          );
          final publishedStops = await db.db.rawQuery(
            'SELECT DISTINCT st.stop_id FROM stop_times st JOIN trips t ON t.trip_id=st.trip_id WHERE t.route_id=?',
            [route.id],
          );
          expect(
            patterns.expand((p) => p.stops).map((s) => s.id).toSet(),
            publishedStops.map((r) => r['stop_id']).toSet(),
          );
          for (final pattern in patterns) {
            final original = await db.db.rawQuery(
              'SELECT stop_id FROM stop_times WHERE trip_id=? ORDER BY stop_sequence',
              [pattern.tripId],
            );
            expect(
              pattern.stops.map((s) => s.id),
              original.map((r) => r['stop_id']),
            );
          }
          // ignore: avoid_print
          print(
            'Autobus ${route.label}: ${patterns.map((p) => '${p.directionLabel} ${p.stops.length} fermate').join('; ')}; ordine e completezza verificati.',
          );
        }
        // ignore: avoid_print
        print(
          'AMTS verificato: ${info.stops} fermate, calendario fino a ${info.endDate}; '
          '${arrivals.length} arrivi per la fermata ${row['stop_id']} nella finestra verificata.',
        );
      } finally {
        await db.db.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
