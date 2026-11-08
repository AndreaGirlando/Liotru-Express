import 'dart:math' as math;
import 'package:timezone/timezone.dart' as tz;
import 'gtfs_time.dart';

enum MetroDirection {
  stesicoro('stesicoro', 'Stesicoro'),
  montePo('montepo', 'Monte Po');

  const MetroDirection(this.key, this.destination);
  final String key, destination;
}

class MetroStation {
  const MetroStation(this.id, this.name, this.toStesicoro, this.toMontePo);
  final String id, name;
  final int toStesicoro, toMontePo;
  int offset(MetroDirection direction) => direction == MetroDirection.stesicoro ? toStesicoro : toMontePo;
}

class MetroPassage {
  const MetroPassage(this.time, this.departure, this.estimated);
  final DateTime time, departure;
  final bool estimated;
}

class MetroTimetable {
  MetroTimetable({required this.stations, required this.days, required this.published, required this.checked, required this.offsetsValidUntil, required this.sourceUrl, required this.offsetsUrl});
  final List<MetroStation> stations;
  final Map<String, Map<String, List<int>>> days;
  final DateTime published, checked;
  final String offsetsValidUntil, sourceUrl, offsetsUrl;

  factory MetroTimetable.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1) throw const FormatException('Orario Metro non supportato');
    final stations = (json['stations'] as List).map((s) => MetroStation(s['id'] as String, s['name'] as String, s['stesicoro'] as int, s['montepo'] as int)).toList();
    if (stations.length < 2 || stations.map((s) => s.id).toSet().length != stations.length) {
      throw const FormatException('Stazioni Metro non valide');
    }
    final days = <String, Map<String, List<int>>>{};
    for (final key in ['weekday', 'friday', 'saturday', 'sunday', 'holiday_weekday', 'holiday_late']) {
      days[key] = {};
      for (final direction in MetroDirection.values) {
        final times = List<int>.from(json['days'][key][direction.key] as List);
        if (times.isEmpty || times.any((s) => s < 0 || s >= 48 * 3600)) throw const FormatException('Partenze Metro non valide');
        for (var i = 1; i < times.length; i++) {
          if (times[i] <= times[i - 1]) throw const FormatException('Partenze Metro non ordinate');
        }
        days[key]![direction.key] = times;
      }
    }
    return MetroTimetable(stations: stations, days: days, published: DateTime.parse(json['published_date'] as String), checked: DateTime.parse(json['checked_date'] as String), offsetsValidUntil: json['offsets_valid_until'] as String, sourceUrl: json['pdf_url'] as String, offsetsUrl: json['gtfs_url'] as String);
  }

  bool isDestination(MetroStation station, MetroDirection direction) => station.id == (direction == MetroDirection.stesicoro ? stations.last.id : stations.first.id);

  List<MetroPassage> upcoming(MetroStation station, MetroDirection direction, DateTime now, {int limit = 3}) {
    if (isDestination(station, direction)) return [];
    final local = tz.TZDateTime.from(now, rome);
    final day = DateTime.utc(local.year, local.month, local.day);
    final result = <MetroPassage>[];
    for (var delta = -1; delta <= 2; delta++) {
      final date = day.add(Duration(days: delta));
      for (final seconds in days[dayType(date)]![direction.key]!) {
        final departure = serviceInstant(date, seconds);
        final arrival = serviceInstant(date, seconds + station.offset(direction));
        if (!arrival.isBefore(now)) result.add(MetroPassage(arrival, departure, station.offset(direction) > 0));
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result.take(limit).toList();
  }

  static String dayType(DateTime date) {
    if (date.weekday == DateTime.sunday) return 'sunday';
    if (isNationalHoliday(date)) return date.weekday == DateTime.friday || date.weekday == DateTime.saturday ? 'holiday_late' : 'holiday_weekday';
    return switch (date.weekday) {
      DateTime.friday => 'friday',
      DateTime.saturday => 'saturday',
      _ => 'weekday',
    };
  }

  static bool isNationalHoliday(DateTime date) {
    final key = '${date.month}-${date.day}';
    if (['1-1', '1-6', '4-25', '5-1', '6-2', '8-15', '11-1', '12-8', '12-25', '12-26'].contains(key)) return true;
    // Gregorian Easter; Easter Monday uses calendar dates, not local 24h jumps.
    final y = date.year;
    final a = y % 19, b = y ~/ 100, c = y % 100;
    final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4, k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = (h + l - 7 * m + 114) % 31 + 1;
    final easter = DateTime.utc(y, month, day);
    final monday = DateTime.utc(y, month, day + 1);
    return (date.month == easter.month && date.day == easter.day) || (date.month == monday.month && date.day == monday.day);
  }
}

String metroCountdown(DateTime arrival, DateTime now) {
  final seconds = math.max(0, arrival.difference(now).inSeconds);
  if (seconds == 0) return 'Ora';
  if (seconds >= 90 * 60) return clockTime(arrival);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
