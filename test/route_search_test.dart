import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catania_bus/data/database.dart';
import 'package:catania_bus/data/gtfs_importer.dart';
import 'fixtures.dart';

import 'route_fixtures.dart';

void main() {
  late Directory directory;
  late TransitDatabase database;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('route_search_');
    database = await TransitDatabase.open(
      '${directory.path}/routes.db',
      factory: databaseFactoryFfiNoIsolate,
    );
    final zip = await fixtureZip(directory, override: routeFixture);
    await GtfsImporter(
      database,
    ).importZip(zip.path, source: 'SYNTHETIC ROUTE TEST');
  });
  tearDown(() async {
    await database.db.close();
    await directory.delete(recursive: true);
  });

  test(
    'find a bus by number or name and treat wildcard input literally',
    () async {
      expect((await database.searchRoutes(' metro ')).single.id, 'R1');
      expect((await database.searchRoutes('a-ms')).single.id, 'R1');
      expect((await database.searchRoutes('156')).single.id, 'R2');
      expect((await database.searchRoutes('%')).single.id, 'R3');
      expect((await database.searchRoutes('_')).single.id, 'R3');
      expect(await database.searchRoutes('unknown'), isEmpty);
      expect(await database.searchRoutes(''), hasLength(3));
    },
  );

  test(
    'keep directions, short variants, repeated stops and untimed stops',
    () async {
      final patterns = await database.routePatterns('R1');
      expect(patterns, hasLength(4));
      expect(patterns.first.stops.map((s) => s.id), ['A', 'B', 'C']);
      expect(patterns.first.tripCount, 2);
      expect(patterns.first.directionLabel, 'Andata');
      final back = patterns.singleWhere((p) => p.directionId == '1');
      expect(back.directionLabel, 'Ritorno');
      expect(back.stops.map((s) => s.id), ['C', 'B', 'A']);
      expect(
        patterns.any((p) => p.stops.map((s) => s.id).join(',') == 'A,B,A'),
        isTrue,
      );
      expect(
        patterns.any((p) => p.stops.map((s) => s.id).join(',') == 'A,C'),
        isTrue,
      );
      expect(
        (await database.routePatterns('R2')).single.stops.map((s) => s.id),
        ['B', 'D'],
      );
      expect(await database.routePatterns('missing'), isEmpty);
    },
  );

  test('version one databases migrate without losing imported data', () async {
    final path = '${directory.path}/legacy.db';
    final old = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE trips(trip_id TEXT PRIMARY KEY, route_id TEXT NOT NULL, service_id TEXT NOT NULL, trip_headsign TEXT NOT NULL)',
          );
          await db.insert('trips', {
            'trip_id': 'OLD',
            'route_id': 'R1',
            'service_id': 'DAILY',
            'trip_headsign': 'Old destination',
          });
        },
      ),
    );
    await old.close();
    final migrated = await TransitDatabase.open(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    try {
      final row = (await migrated.db.query('trips')).single;
      expect(row['trip_id'], 'OLD');
      expect(row['direction_id'], '');
      expect(row['trip_headsign'], 'Old destination');
    } finally {
      await migrated.db.close();
    }
  });
}
