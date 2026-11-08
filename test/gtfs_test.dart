import 'dart:io';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:catania_bus/data/database.dart';
import 'package:catania_bus/data/gtfs_importer.dart';
import 'package:catania_bus/domain/gtfs_time.dart';
import 'fixtures.dart';

void main() {
  late Directory directory;
  late TransitDatabase database;
  setUpAll(() {
    tz.initializeTimeZones();
    sqfliteFfiInit();
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gtfs_test_');
    database = await TransitDatabase.open(
      '${directory.path}/test.db',
      factory: databaseFactoryFfi,
    );
    final zip = await fixtureZip(directory);
    final importer = GtfsImporter(database);
    await importer.importZip(
      zip.path,
      source: 'SYNTHETIC TEST DATA',
      temporaryRoot: directory.path,
    );
  });
  tearDown(() async {
    await database.db.close();
    await directory.delete(recursive: true);
  });

  test('progress callback stays in the UI isolate during extraction', () async {
    final port = ReceivePort();
    final messages = <String>[];
    final zip = await fixtureZip(directory);
    try {
      await GtfsImporter(database).importZip(
        zip.path,
        source: 'SYNTHETIC CALLBACK TEST',
        temporaryRoot: directory.path,
        progress: (message) {
          port.sendPort.send(message);
          messages.add(message);
        },
      );
      expect(messages, contains('Estrazione e controllo archivio…'));
      expect((await database.info())!.stops, 2);
    } finally {
      port.close();
    }
  });

  test(
    'ZIP import, quoted CSV, offline name/code and literal wildcard search',
    () async {
      expect((await database.info())!.stops, 2);
      expect((await database.search('piazza')).single.name, 'Piazza, Test');
      expect((await database.search('001')).single.id, 'S1');
      expect((await database.search('S1')).single.routes, '42');
      expect(await database.search('%'), isEmpty);
      expect(await database.search('Test', ids: ['S2']), hasLength(1));
    },
  );
  test('only valid service day, removal and holiday addition', () async {
    final now = DateTime.utc(2026, 11, 8, 8); // 09:00 Rome
    final arrivals = await database.arrivals(
      'S1',
      now,
      horizon: const Duration(hours: 4),
    );
    expect(arrivals.map((a) => a.tripId), ['T2']);
  });
  test('beyond midnight belongs to previous service day', () async {
    final arrivals = await database.arrivals(
      'S1',
      DateTime.utc(2026, 11, 7, 23),
      horizon: const Duration(hours: 2),
    );
    expect(arrivals.single.tripId, 'NIGHT');
    expect(arrivals.single.serviceDate, '20261107');
    expect(arrivals.single.scheduled, DateTime.utc(2026, 11, 8, 0, 15));
  });
  test(
    'cancelled previous service day cannot reappear after midnight',
    () async {
      final arrivals = await database.arrivals(
        'S1',
        DateTime.utc(2026, 11, 8, 23),
        horizon: const Duration(hours: 2),
      );
      expect(arrivals, isEmpty);
    },
  );
  test('arrivals sorted and expired calendars produce no trips', () async {
    final arrivals = await database.arrivals(
      'S1',
      DateTime.utc(2026, 11, 6, 8),
    );
    expect(arrivals.first.tripId, 'T1');
    expect(arrivals.last.tripId, 'NIGHT');
    expect(await database.arrivals('S1', DateTime.utc(2027, 2, 1)), isEmpty);
  });
  test('invalid new ZIP rolls back all changes and metadata', () async {
    final before = await database.metadata();
    final zip = await fixtureZip(
      directory,
      override: {
        'stop_times':
            'trip_id,arrival_time,departure_time,stop_id,stop_sequence\nT1,10:00:00,10:00:00,MISSING,1\n',
      },
    );
    await expectLater(
      GtfsImporter(database).importZip(zip.path, source: 'BAD'),
      throwsFormatException,
    );
    expect(await database.metadata(), before);
    expect(await database.search(''), hasLength(2));
  });
  test('missing required table does not destroy previous data', () async {
    final zip = await fixtureZip(directory, omit: {'stops'});
    await expectLater(
      GtfsImporter(database).importZip(zip.path, source: 'BAD'),
      throwsFormatException,
    );
    expect((await database.info())!.source, 'SYNTHETIC TEST DATA');
  });
  test('calendar_dates-only feeds are accepted', () async {
    final zip = await fixtureZip(
      directory,
      omit: {'calendar'},
      override: {
        'calendar_dates':
            'service_id,date,exception_type\nDAILY,20261109,1\nEXTRA,20261108,1\n',
      },
    );
    await GtfsImporter(database).importZip(zip.path, source: 'SYNTHETIC');
    expect(
      (await database.arrivals(
        'S1',
        DateTime.utc(2026, 11, 9, 8),
        horizon: const Duration(hours: 3),
      )).single.tripId,
      'T1',
    );
  });
  test('CRLF, BOM and multiline quoted stop names', () async {
    final zip = await fixtureZip(
      directory,
      override: {
        'stops':
            '\uFEFFstop_id,stop_code,stop_name\r\nS1,001,"Piazza\r\nTest"\r\nS2,002,Stazione Test\r\n',
      },
    );
    await GtfsImporter(database).importZip(zip.path, source: 'SYNTHETIC');
    expect((await database.search('001')).single.name, contains('Test'));
  });
  test(
    'frequencies fail visibly instead of displaying template schedule',
    () async {
      final zip = await fixtureZip(
        directory,
        override: {
          'frequencies':
              'trip_id,start_time,end_time,headway_secs\nT1,08:00:00,20:00:00,600\n',
        },
      );
      await expectLater(
        GtfsImporter(database).importZip(zip.path, source: 'BAD'),
        throwsFormatException,
      );
    },
  );
  test('wrong timezone is rejected', () async {
    final zip = await fixtureZip(
      directory,
      override: {'agency': 'agency_timezone\nAmerica/New_York\n'},
    );
    await expectLater(
      GtfsImporter(database).importZip(zip.path, source: 'BAD'),
      throwsFormatException,
    );
  });
  test('GTFS time validation and calendar date validation', () {
    expect(gtfsSeconds('25:15:00'), 90900);
    expect(() => gtfsSeconds('12:70:00'), throwsFormatException);
    expect(() => parseServiceDate('20260230'), throwsFormatException);
  });
  test('DST uses GTFS noon minus twelve hours, Rome timezone', () {
    expect(
      serviceInstant(DateTime.utc(2026, 3, 29), 3 * 3600),
      DateTime.utc(2026, 3, 29, 1),
    );
    expect(
      serviceInstant(DateTime.utc(2026, 10, 25), 3 * 3600),
      DateTime.utc(2026, 10, 25, 2),
    );
    expect(clockTime(DateTime.utc(2026, 7, 1, 10)), '12:00');
  });
}
