import 'package:timezone/timezone.dart' as tz;
import 'gtfs_time.dart';

String arrivalDay(DateTime time, DateTime reference) {
  final local = tz.TZDateTime.from(time, rome);
  final current = tz.TZDateTime.from(reference, rome);
  final days = DateTime.utc(local.year, local.month, local.day).difference(DateTime.utc(current.year, current.month, current.day)).inDays;
  if (days == 0) return 'Oggi';
  if (days == 1) return 'Domani';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}

String arrivalWait(DateTime time, DateTime reference) {
  final minutes = (time.difference(reference).inSeconds / 60).ceil();
  if (minutes <= 0) return 'In arrivo';
  if (minutes <= 90) return 'tra $minutes min';
  return '${arrivalDay(time, reference)} ${clockTime(time)}';
}
