// ALL fixtures in test/ are synthetic; they are not AMTS data.
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

Future<File> fixtureZip(
  Directory directory, {
  Map<String, String> override = const {},
  Set<String> omit = const {},
  String filename = 'synthetic.zip',
}) async {
  final files = <String, String>{
    'agency':
        'agency_name,agency_url,agency_timezone\nSynthetic Transit,https://example.invalid,Europe/Rome\n',
    'stops':
        'stop_id,stop_code,stop_name\nS1,001,"Piazza, Test"\nS2,002,Stazione Test\n',
    'routes': 'route_id,route_short_name,route_long_name\nR1,42,Centro Test\n',
    'trips':
        'route_id,service_id,trip_id,trip_headsign\nR1,DAILY,T1,Centro Test\nR1,DAILY,NIGHT,Notturno Test\nR1,EXTRA,T2,Festivo Test\n',
    'stop_times':
        'trip_id,arrival_time,departure_time,stop_id,stop_sequence\nT1,10:00:00,10:00:00,S1,1\nT1,10:10:00,10:10:00,S2,2\nNIGHT,25:15:00,25:15:00,S1,1\nT2,11:00:00,11:00:00,S1,1\n',
    'calendar':
        'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nDAILY,1,1,1,1,1,1,1,20260101,20261231\n',
    'calendar_dates':
        'service_id,date,exception_type\nDAILY,20261108,2\nEXTRA,20261108,1\n',
    ...override,
  };
  final archive = Archive();
  for (final entry in files.entries) {
    if (omit.contains(entry.key)) continue;
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile('${entry.key}.txt', bytes.length, bytes));
  }
  return File(
    '${directory.path}/$filename',
  ).writeAsBytes(ZipEncoder().encode(archive));
}
