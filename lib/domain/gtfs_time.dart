import 'package:timezone/timezone.dart' as tz;

final rome = tz.getLocation('Europe/Rome');

int gtfsSeconds(String value) {
  final m = RegExp(r'^(\d{1,3}):([0-5]\d):([0-5]\d)$').firstMatch(value);
  if (m == null) throw FormatException('Orario GTFS non valido: $value');
  final seconds = int.parse(m[1]!) * 3600 +
      int.parse(m[2]!) * 60 + int.parse(m[3]!);
  if (seconds > 7 * 86400) {
    throw const FormatException('Orario GTFS superiore a sette giorni');
  }
  return seconds;
}

DateTime parseServiceDate(String text) {
  if (!RegExp(r'^\d{8}$').hasMatch(text)) {
    throw FormatException('Data GTFS non valida: $text');
  }
  final d = DateTime.utc(int.parse(text.substring(0, 4)),
      int.parse(text.substring(4, 6)), int.parse(text.substring(6, 8)));
  if (serviceDate(d) != text) throw FormatException('Data non valida: $text');
  return d;
}

String serviceDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

// GTFS: seconds from "noon minus 12h", including on DST transition days.
DateTime serviceInstant(DateTime date, int seconds) {
  final local = tz.TZDateTime(rome, date.year, date.month, date.day, 12)
      .subtract(const Duration(hours: 12)).add(Duration(seconds: seconds));
  // Keep model instants as ordinary UTC DateTime values. TZDateTime equality
  // also compares the location, which differs from DateTime's equality rules.
  return DateTime.fromMillisecondsSinceEpoch(local.millisecondsSinceEpoch,isUtc:true);
}

String clockTime(DateTime d) {
  final local = tz.TZDateTime.from(d, rome);
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
