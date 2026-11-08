import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:catania_bus/domain/models.dart';
import 'package:catania_bus/domain/realtime.dart';
import 'package:catania_bus/data/realtime_service.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8, 9);
  Arrival arrival({
    String date = '20261108',
    int sequence = 2,
    String stop = 'S2',
  }) => Arrival(
    tripId: 'T1',
    stopId: stop,
    sequence: sequence,
    route: '42',
    destination: 'Synthetic',
    serviceDate: date,
    tripStart: '10:00:00',
    scheduled: now.add(const Duration(minutes: 10)),
  );
  Map<String, dynamic> json(Map<String, dynamic> update) => {
    'header': {
      'gtfsRealtimeVersion': '2.0',
      'timestamp': '${now.millisecondsSinceEpoch ~/ 1000}',
    },
    'entity': [
      {
        'id': 'synthetic',
        'tripUpdate': {
          'trip': {'tripId': 'T1', 'startDate': '20261108'},
          ...update,
        },
      },
    ],
  };
  RealtimeFeed feed(Map<String, dynamic> update) =>
      RealtimeFeed.parse(json(update), now);
  test(
    'absolute timestamp and snake/camel fields match trip and stop sequence',
    () {
      final predicted = now.add(const Duration(minutes: 12));
      final f = feed({
        'stop_time_update': [
          {
            'stop_id': 'S2',
            'stop_sequence': 2,
            'arrival': {'time': '${predicted.millisecondsSinceEpoch ~/ 1000}'},
          },
        ],
      });
      expect(f.apply([arrival()], now).single.predicted, predicted);
    },
  );
  test('delay propagated, ordered and negative delay supported', () {
    final f = feed({
      'stopTimeUpdate': [
        {
          'stopSequence': 1,
          'departure': {'delay': -60},
        },
      ],
    });
    expect(
      f.apply([arrival()], now).single.time,
      now.add(const Duration(minutes: 9)),
    );
  });
  test('trip-level delay is applied', () {
    expect(
      feed({'delay': 120}).apply([arrival()], now).single.predicted,
      now.add(const Duration(minutes: 12)),
    );
  });
  test('high uncertainty cannot be shown as current realtime', () {
    final result = feed({
      'delay': 90,
      'stopTimeUpdate': [
        {
          'stopSequence': 2,
          'arrival': {'delay': 60, 'uncertainty': 300},
        },
      ],
    }).apply([arrival()], now);
    expect(result.single.isRealtime, isFalse);
  });
  test('canceled trip and skipped stop disappear', () {
    expect(
      feed({
        'trip': {'tripId': 'T1', 'scheduleRelationship': 'CANCELED'},
      }).apply([arrival()], now),
      isEmpty,
    );
    expect(
      feed({
        'stopTimeUpdate': [
          {'stopSequence': 2, 'scheduleRelationship': 1},
        ],
      }).apply([arrival()], now),
      isEmpty,
    );
  });
  test('NO_DATA stops propagated delays', () {
    final result = feed({
      'delay': 120,
      'stopTimeUpdate': [
        {'stopSequence': 2, 'scheduleRelationship': 'NO_DATA'},
      ],
    }).apply([arrival()], now);
    expect(result.single.isRealtime, isFalse);
  });
  test('other service day and mismatched stop do not get a prediction', () {
    expect(
      feed({
        'delay': 120,
      }).apply([arrival(date: '20261107')], now).single.isRealtime,
      isFalse,
    );
    expect(
      feed({
        'stopTimeUpdate': [
          {
            'stopSequence': 2,
            'stopId': 'WRONG',
            'arrival': {'delay': 60},
          },
        ],
      }).apply([arrival()], now).single.isRealtime,
      isFalse,
    );
  });
  test('ambiguous daily trip without startDate stays scheduled', () {
    final f = feed({
      'trip': {'tripId': 'T1'},
      'delay': 120,
    });
    expect(
      f
          .apply([arrival(), arrival(date: '20261107')], now)
          .every((a) => !a.isRealtime),
      isTrue,
    );
  });
  test('old feed, future feed and differential feed rejected', () {
    final j = json({});
    expect(
      () => RealtimeFeed.parse(j, now.add(const Duration(minutes: 4))),
      throwsFormatException,
    );
    expect(
      () => RealtimeFeed.parse(j, now.subtract(const Duration(minutes: 1))),
      throwsFormatException,
    );
    (j['header'] as Map)['incrementality'] = 'DIFFERENTIAL';
    expect(() => RealtimeFeed.parse(j, now), throwsFormatException);
  });
  test('stale individual update ignored and cache expires', () {
    final f = feed({
      'timestamp':
          now.subtract(const Duration(minutes: 4)).millisecondsSinceEpoch ~/
          1000,
      'delay': 90,
    });
    expect(f.apply([arrival()], now).single.isRealtime, isFalse);
    expect(
      feed({'delay': 90})
          .apply([arrival()], now.add(const Duration(minutes: 4)))
          .single
          .isRealtime,
      isFalse,
    );
    final cached = feed({
      'timestamp':
          now.subtract(const Duration(seconds: 170)).millisecondsSinceEpoch ~/
          1000,
      'delay': 90,
    });
    expect(
      cached
          .apply([arrival()], now.add(const Duration(seconds: 20)))
          .single
          .isRealtime,
      isFalse,
    );
  });
  test(
    'HTTP errors, malformed JSON and offline fall back to schedule',
    () async {
      for (final client in [
        MockClient((_) async => http.Response('no', 503)),
        MockClient((_) async => http.Response('{', 200)),
        MockClient((_) async => throw http.ClientException('offline')),
      ]) {
        final result = await RealtimeService(
          client,
        ).fetch('https://example.invalid/feed', now);
        expect(result.feed, isNull);
        expect(result.message, contains('programmati'));
        client.close();
      }
    },
  );
  test('requests coalesced and limited, failed refresh drops cache', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return calls == 1
          ? http.Response(jsonEncode(json({'delay': 90})), 200)
          : http.Response('down', 503);
    });
    final service = RealtimeService(client);
    expect(
      (await service.fetch('https://example.invalid/feed', now)).feed,
      isNotNull,
    );
    expect(
      (await service.fetch(
        'https://example.invalid/feed',
        now.add(const Duration(seconds: 30)),
      )).feed,
      isNotNull,
    );
    expect(calls, 1);
    expect(
      (await service.fetch(
        'https://example.invalid/feed',
        now.add(const Duration(minutes: 1)),
      )).feed,
      isNull,
    );
    expect(calls, 2);
    client.close();
  });
  test('full empty dataset replaces cached predictions', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        jsonEncode(
          calls == 1
              ? json({'delay': 90})
              : {
                  'header': {
                    'timestamp':
                        now
                            .add(const Duration(minutes: 1))
                            .millisecondsSinceEpoch ~/
                        1000,
                  },
                  'entity': [],
                },
        ),
        200,
      );
    });
    final service = RealtimeService(client);
    await service.fetch('https://example.invalid/feed', now);
    final result = await service.fetch(
      'https://example.invalid/feed',
      now.add(const Duration(minutes: 1)),
    );
    expect(
      result.feed!
          .apply([arrival()], now.add(const Duration(minutes: 1)))
          .single
          .isRealtime,
      isFalse,
    );
    client.close();
  });
  test('BusOne identification and Retry-After are honored', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['X-BusOne-Use'], 'personal');
      expect(request.headers['X-BusOne-Client'], contains('CataniaBus'));
      return http.Response('rate limit', 429, headers: {'retry-after': '300'});
    });
    final service = RealtimeService(client);
    await service.fetch('https://example.invalid/feed', now);
    await service.fetch(
      'https://example.invalid/feed',
      now.add(const Duration(minutes: 2)),
    );
    expect(calls, 1);
    await service.fetch(
      'https://example.invalid/feed',
      now.add(const Duration(minutes: 5)),
    );
    expect(calls, 2);
    client.close();
  });
}
