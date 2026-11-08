import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import '../domain/gtfs_time.dart';
import '../domain/models.dart';

class TransitDatabase {
  TransitDatabase(this.db);
  final Database db;

  static Future<TransitDatabase> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final statement in schema) {
            await db.execute(statement);
          }
        },
      ),
    );
    return TransitDatabase(db);
  }

  static const schema = [
    'CREATE TABLE stops(stop_id TEXT PRIMARY KEY, stop_code TEXT NOT NULL, stop_name TEXT NOT NULL, location_type TEXT NOT NULL)',
    'CREATE TABLE routes(route_id TEXT PRIMARY KEY, route_short_name TEXT NOT NULL, route_long_name TEXT NOT NULL)',
    'CREATE TABLE trips(trip_id TEXT PRIMARY KEY, route_id TEXT NOT NULL, service_id TEXT NOT NULL, trip_headsign TEXT NOT NULL)',
    'CREATE TABLE stop_times(trip_id TEXT NOT NULL, stop_id TEXT NOT NULL, stop_sequence INTEGER NOT NULL, arrival_secs INTEGER, departure_secs INTEGER, pickup_type TEXT NOT NULL, PRIMARY KEY(trip_id,stop_sequence))',
    'CREATE TABLE calendar(service_id TEXT PRIMARY KEY, monday INTEGER, tuesday INTEGER, wednesday INTEGER, thursday INTEGER, friday INTEGER, saturday INTEGER, sunday INTEGER, start_date TEXT, end_date TEXT)',
    'CREATE TABLE calendar_dates(service_id TEXT, date TEXT, exception_type INTEGER, PRIMARY KEY(service_id,date))',
    'CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    'CREATE INDEX stop_arrival ON stop_times(stop_id,arrival_secs)',
    'CREATE INDEX arrival_time ON stop_times(arrival_secs)',
    'CREATE INDEX trips_route ON trips(route_id)',
    'CREATE INDEX trips_service ON trips(service_id)',
    'CREATE INDEX exception_date ON calendar_dates(date,service_id)',
    'CREATE INDEX stop_name ON stops(stop_name COLLATE NOCASE)',
    'CREATE INDEX stop_code ON stops(stop_code COLLATE NOCASE)',
  ];

  Future<Map<String, String>> metadata() async => {
    for (final row in await db.query('metadata'))
      row['key'] as String: row['value'] as String,
  };

  Future<FeedInfo?> info() async {
    final m = await metadata();
    if (m['imported_at'] == null) return null;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT count(*) FROM stops'),
        ) ??
        0;
    return FeedInfo(
      importedAt: DateTime.parse(m['imported_at']!),
      source: m['source'] ?? '',
      stops: count,
      endDate: m['end_date'] ?? '',
    );
  }

  Future<List<BusStop>> search(String query, {List<String>? ids}) async {
    if (ids != null && ids.isEmpty) return [];
    final escaped = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await db.rawQuery(
      '''
      SELECT s.*,
      (SELECT group_concat(label, ', ') FROM
        (SELECT DISTINCT coalesce(nullif(r.route_short_name,''),r.route_long_name) AS label
         FROM stop_times st JOIN trips t ON st.trip_id=t.trip_id
         JOIN routes r ON r.route_id=t.route_id WHERE st.stop_id=s.stop_id
         ORDER BY label)) AS route_labels
      FROM stops s WHERE location_type IN ('','0') AND
      (stop_name LIKE ? ESCAPE '\\' OR stop_code LIKE ? ESCAPE '\\' OR stop_id = ?)
      ${ids == null ? '' : 'AND s.stop_id IN (${List.filled(ids.length, '?').join(',')})'}
      ORDER BY stop_name COLLATE NOCASE LIMIT 100
      ''',
      ['%$escaped%', '%$escaped%', query, ...?ids],
    );
    return rows
        .map(
          (r) => BusStop(
            r['stop_id'] as String,
            r['stop_code'] as String,
            r['stop_name'] as String,
            routes: r['route_labels'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<List<Arrival>> arrivals(
    String stopId,
    DateTime from, {
    Duration horizon = const Duration(hours: 24),
  }) async {
    final m = await metadata();
    if (m.isEmpty) return [];
    final local = tz.TZDateTime.from(from, rome);
    final day = DateTime.utc(local.year, local.month, local.day);
    final maxSeconds = int.tryParse(m['max_seconds'] ?? '') ?? 86400;
    final until = from.add(horizon);
    final result = <Arrival>[];
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    // Include earlier service days for trips such as 25:15 and later dates
    // for arrivals after midnight in the requested window.
    for (
      var offset = -(maxSeconds ~/ 86400) - 1;
      offset <= horizon.inDays + 1;
      offset++
    ) {
      final date = day.add(Duration(days: offset));
      final key = serviceDate(date);
      final origin = serviceInstant(date, 0);
      final lo = from.difference(origin).inSeconds;
      final hi = until.difference(origin).inSeconds;
      if (hi < 0 || lo > maxSeconds) continue;
      final rows = await db.rawQuery(
        '''
        SELECT st.*, t.trip_headsign, t.trip_id, r.route_short_name, r.route_long_name,
        (SELECT terminal.stop_name FROM stop_times last
          JOIN stops terminal ON terminal.stop_id=last.stop_id
          WHERE last.trip_id=t.trip_id ORDER BY last.stop_sequence DESC LIMIT 1) AS terminal_name,
        (SELECT min(coalesce(departure_secs,arrival_secs)) FROM stop_times first
          WHERE first.trip_id=t.trip_id) AS trip_start
        FROM stop_times st JOIN trips t ON t.trip_id=st.trip_id
        JOIN routes r ON r.route_id=t.route_id
        WHERE st.stop_id=? AND st.arrival_secs BETWEEN ? AND ?
        AND st.pickup_type != '1' AND
        (EXISTS (SELECT 1 FROM calendar_dates cd WHERE cd.service_id=t.service_id
          AND cd.date=? AND cd.exception_type=1)
         OR (EXISTS (SELECT 1 FROM calendar c WHERE c.service_id=t.service_id
          AND c.${days[date.weekday - 1]}=1 AND c.start_date<=? AND c.end_date>=?)
          AND NOT EXISTS (SELECT 1 FROM calendar_dates cd WHERE cd.service_id=t.service_id
            AND cd.date=? AND cd.exception_type=2)))
        ORDER BY st.arrival_secs
      ''',
        [stopId, lo, hi, key, key, key, key],
      );
      for (final row in rows) {
        final seconds = row['trip_start'] as int? ?? 0;
        final start =
            '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
            '${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}:'
            '${(seconds % 60).toString().padLeft(2, '0')}';
        result.add(
          Arrival(
            tripId: row['trip_id'] as String,
            stopId: stopId,
            sequence: row['stop_sequence'] as int,
            route: (row['route_short_name'] as String).isNotEmpty
                ? row['route_short_name'] as String
                : row['route_long_name'] as String,
            destination: (row['trip_headsign'] as String).isNotEmpty
                ? row['trip_headsign'] as String
                : (row['terminal_name'] as String? ??
                      row['route_long_name'] as String),
            serviceDate: key,
            tripStart: start,
            scheduled: serviceInstant(date, row['arrival_secs'] as int),
          ),
        );
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }
}
