import 'dart:async';
import 'dart:io';
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
import 'fixtures.dart';

void main() {
  late Directory directory;
  late TransitDatabase database;
  late AppState state;
  late List<int> oldBytes, newBytes;
  var requests = 0;
  var now = DateTime.utc(2027, 1, 1, 10);
  late Future<http.Response> Function() response;
  late Completer<void> requestStarted;
  setUpAll(() {
    tz.initializeTimeZones();
    sqfliteFfiInit();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'favorites': ['S1'],
    });
    directory = await Directory.systemTemp.createTemp('auto_update_');
    database = await TransitDatabase.open(
      '${directory.path}/live.db',
      factory: databaseFactoryFfiNoIsolate,
    );
    oldBytes = await (await fixtureZip(directory)).readAsBytes();
    newBytes = await (await fixtureZip(
      directory,
      filename: 'new.zip',
      override: {
        'stops':
            'stop_id,stop_code,stop_name\nS1,001,Nuova Piazza Test\nS2,002,Stazione Test\n',
        'calendar':
            'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nDAILY,1,1,1,1,1,1,1,20270101,20270331\n',
        'calendar_dates': 'service_id,date,exception_type\nEXTRA,20270101,1\n',
      },
    )).readAsBytes();
    now = DateTime.utc(2027, 1, 1, 10);
    requests = 0;
    requestStarted = Completer<void>();
    response = () async => http.Response.bytes(newBytes, 200);
    state = AppState(
      database,
      UserPreferences(await SharedPreferences.getInstance()),
      MockClient((_) {
        requests++;
        if (!requestStarted.isCompleted) requestStarted.complete();
        return response();
      }),
      cacheDirectory: () async => directory,
      clock: () => now,
    );
    await state.load();
  });
  tearDown(() async {
    state.client.close();
    state.dispose();
    await database.db.close();
    await directory.delete(recursive: true);
  });

  Future<void> importOld() async {
    final file = await File('${directory.path}/old.zip').writeAsBytes(oldBytes);
    await GtfsImporter(database).importZip(file.path, source: 'PREVIOUS');
    await state.load();
  }

  test(
    'first use downloads automatically and coalesces repeated checks',
    () async {
      final pending = Completer<http.Response>();
      response = () => pending.future;
      final first = state.refreshScheduleIfNeeded();
      final second = state.refreshScheduleIfNeeded();
      await requestStarted.future;
      expect(requests, 1);
      expect(state.automaticUpdating, isTrue);
      pending.complete(http.Response.bytes(newBytes, 200));
      await Future.wait([first, second]);
      expect(state.feed?.stops, 2);
      expect(state.feedExpired, isFalse);
      expect(state.preferences.favorites, ['S1']);
      await state.refreshScheduleIfNeeded();
      expect(requests, 1);
    },
  );

  test(
    'expired feed stays readable while downloading and swaps only after validation',
    () async {
      await importOld();
      expect(state.feedExpired, isTrue);
      final pending = Completer<http.Response>();
      response = () => pending.future;
      final task = state.refreshScheduleIfNeeded();
      expect((await database.search('001')).single.name, 'Piazza, Test');
      expect(state.feed?.source, 'PREVIOUS');
      expect(state.automaticMessage, contains('background'));
      pending.complete(http.Response.bytes(newBytes, 200));
      await task;
      expect((await database.search('001')).single.name, 'Nuova Piazza Test');
      expect(state.feed?.endDate, '20270331');
      expect(state.importing, isFalse);
    },
  );

  test(
    'network failures preserve the cache and rate-limit automatic retries',
    () async {
      await importOld();
      response = () async => http.Response('', 503);
      await state.refreshScheduleIfNeeded();
      expect(state.automaticFailed, isTrue);
      expect(state.automaticMessage, contains('503'));
      expect(state.feed?.source, 'PREVIOUS');
      expect((await database.search('001')).single.id, 'S1');
      await state.refreshScheduleIfNeeded();
      expect(requests, 1);
      now = now.add(const Duration(minutes: 16));
      response = () async => http.Response.bytes(newBytes, 200);
      await state.refreshScheduleIfNeeded();
      expect(requests, 2);
      expect(state.feedExpired, isFalse);
    },
  );

  test(
    'an unchanged expired publication keeps previous data and backs off for six hours',
    () async {
      await importOld();
      final oldStamp = state.feed!.importedAt;
      response = () async => http.Response.bytes(oldBytes, 200);
      await state.refreshScheduleIfNeeded();
      expect(state.feed!.importedAt, oldStamp);
      expect(state.automaticMessage, contains('non ha ancora pubblicato'));
      now = now.add(const Duration(hours: 1));
      await state.refreshScheduleIfNeeded();
      expect(requests, 1);
      now = now.add(const Duration(hours: 6));
      await state.refreshScheduleIfNeeded();
      expect(requests, 2);
    },
  );

  test(
    'Rome midnight determines expiry even when the device clock is UTC',
    () async {
      await importOld();
      now = DateTime.utc(2026, 12, 31, 22, 59); // 23:59 Rome
      expect(state.feedExpired, isFalse);
      await state.refreshScheduleIfNeeded();
      expect(requests, 0);
      now = DateTime.utc(2026, 12, 31, 23, 0); // 1 January in Rome
      expect(state.feedExpired, isTrue);
      await state.refreshScheduleIfNeeded();
      expect(requests, 1);
    },
  );

  test('a failed atomic publish rolls back every live table', () async {
    await importOld();
    final path = '${directory.path}/broken.db';
    final candidate = await TransitDatabase.open(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    await GtfsImporter(
      candidate,
    ).importZip('${directory.path}/new.zip', source: 'BROKEN');
    await candidate.db.execute('DROP TABLE metadata');
    await candidate.db.close();
    await expectLater(
      database.replaceFrom(path),
      throwsA(isA<DatabaseException>()),
    );
    expect((await database.search('001')).single.name, 'Piazza, Test');
    expect((await database.info())!.source, 'PREVIOUS');
  });
}
