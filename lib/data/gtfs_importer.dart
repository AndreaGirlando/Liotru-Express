import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/gtfs_time.dart';
import 'database.dart';

// Keep the worker closure outside importZip's shared scope. Only file paths
// may cross the isolate boundary, never progress callbacks or the widget tree.
Future<String> _extractArchive(String path, String root) =>
    Isolate.run(() => GtfsImporter.extract(path, root));

class GtfsImporter {
  GtfsImporter(this.store);
  final TransitDatabase store;
  static const tables = [
    'stops',
    'routes',
    'trips',
    'stop_times',
    'calendar',
    'calendar_dates',
  ];
  static const requiredColumns = {
    'stops': ['stop_id', 'stop_name'],
    'routes': ['route_id'],
    'trips': ['route_id', 'service_id', 'trip_id'],
    'stop_times': [
      'trip_id',
      'stop_id',
      'stop_sequence',
      'arrival_time',
      'departure_time',
    ],
    'calendar': [
      'service_id',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
      'start_date',
      'end_date',
    ],
    'calendar_dates': ['service_id', 'date', 'exception_type'],
    'agency': ['agency_timezone'],
  };

  // ZIP extraction stays off the UI isolate; only the six useful tables are
  // extracted. File-backed decoding avoids retaining stop_times in memory.
  static String extract(String zipPath, String temporaryRoot) {
    final dir = Directory(temporaryRoot).createTempSync('cataniabus_gtfs_');
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var total = 0;
      final seen = <String>{};
      for (final entry in archive) {
        final name = p.posix.basename(entry.name.replaceAll('\\', '/'));
        if (!requiredColumns.containsKey(
              name.replaceFirst(RegExp(r'\.txt$'), ''),
            ) ||
            !name.endsWith('.txt')) {
          continue;
        }
        if (!entry.isFile || entry.isSymbolicLink || !seen.add(name)) {
          throw const FormatException('File GTFS duplicato o non regolare');
        }
        total += entry.size;
        if (entry.size > 400 * 1024 * 1024 || total > 600 * 1024 * 1024) {
          throw const FormatException('Archivio GTFS troppo grande');
        }
        final output = OutputFileStream(p.join(dir.path, name));
        try {
          entry.writeContent(output);
        } finally {
          output.closeSync();
        }
      }
      for (final name in ['agency', 'stops', 'routes', 'trips', 'stop_times']) {
        if (!seen.contains('$name.txt')) {
          throw FormatException('Manca $name.txt');
        }
      }
      if (!seen.contains('calendar.txt') &&
          !seen.contains('calendar_dates.txt')) {
        throw const FormatException('Mancano entrambi i calendari GTFS');
      }
      // Frequencies require expansion; fail visibly instead of silently showing
      // only the template trips as if they were the published timetable.
      if (archive.any(
        (f) => p.posix.basename(f.name) == 'frequencies.txt' && f.size > 0,
      )) {
        throw const FormatException(
          'Feed a frequenza non supportato (frequencies.txt)',
        );
      }
      return dir.path;
    } catch (_) {
      dir.deleteSync(recursive: true);
      rethrow;
    } finally {
      input.closeSync();
    }
  }

  static Stream<Map<String, String>> rows(File file, String table) async* {
    List<String>? header;
    // RFC4180 quoted fields, embedded newlines, UTF-8 BOM and CRLF are supported.
    final stream = file
        .openRead()
        .transform(utf8.decoder)
        .transform(
          const CsvToListConverter(
            shouldParseNumbers: false,
            allowInvalid: false,
            csvSettingsDetector: FirstOccurrenceSettingsDetector(
              eols: ['\r\n', '\n'],
            ),
          ),
        );
    await for (final values in stream) {
      if (values.every((v) => v.toString().trim().isEmpty)) continue;
      if (header == null) {
        header = values
            .map((v) => v.toString().replaceFirst('\uFEFF', '').trim())
            .toList();
        if (header.toSet().length != header.length ||
            !requiredColumns[table]!.every(header.contains)) {
          throw FormatException('Intestazione non valida in $table.txt');
        }
      } else {
        if (values.length != header.length) {
          throw FormatException('Riga incompleta in $table.txt');
        }
        yield {
          for (var i = 0; i < header.length; i++)
            header[i]: values[i].toString().trim(),
        };
      }
    }
    if (header == null) throw FormatException('$table.txt vuoto');
  }

  Future<void> importZip(
    String path, {
    required String source,
    String? temporaryRoot,
    void Function(String)? progress,
  }) async {
    if (await File(path).length() > 100 * 1024 * 1024) {
      throw const FormatException('ZIP superiore a 100 MB');
    }
    progress?.call('Estrazione e controllo archivio…');
    final root = temporaryRoot ?? Directory.systemTemp.path;
    final directory = await _extractArchive(path, root);
    try {
      var agencyCount = 0;
      await for (final row in rows(
        File(p.join(directory, 'agency.txt')),
        'agency',
      )) {
        agencyCount++;
        if (row['agency_timezone'] != 'Europe/Rome') {
          throw const FormatException('Il feed deve usare il fuso Europe/Rome');
        }
      }
      if (agencyCount == 0) {
        throw const FormatException('Nessuna agenzia nel feed');
      }
      await store.db.transaction((txn) async {
        for (final table in [...tables, 'metadata']) {
          await txn.delete(table);
        }
        var maxSeconds = 0;
        var endDate = '';
        for (final table in tables) {
          final file = File(p.join(directory, '$table.txt'));
          if (!await file.exists()) continue;
          var count = 0;
          var batch = txn.batch();
          await for (final row in rows(file, table)) {
            final data = convert(table, row);
            if (table == 'stop_times') {
              for (final key in ['arrival_secs', 'departure_secs']) {
                final n = data[key] as int?;
                if (n != null && n > maxSeconds) maxSeconds = n;
              }
            }
            final end = (data['end_date'] ?? data['date']) as String?;
            if (end != null && end.compareTo(endDate) > 0) endDate = end;
            batch.insert(table, data);
            count++;
            if (count % 500 == 0) {
              await batch.commit(noResult: true);
              batch = txn.batch();
              progress?.call('Importazione GTFS: $count righe…');
            }
          }
          await batch.commit(noResult: true);
          if (count == 0 && !['calendar', 'calendar_dates'].contains(table)) {
            throw FormatException('Nessun dato in $table.txt');
          }
        }
        for (final sql in [
          'SELECT count(*) FROM trips t LEFT JOIN routes r ON r.route_id=t.route_id WHERE r.route_id IS NULL',
          'SELECT count(*) FROM stop_times s LEFT JOIN trips t ON t.trip_id=s.trip_id LEFT JOIN stops p ON p.stop_id=s.stop_id WHERE t.trip_id IS NULL OR p.stop_id IS NULL',
          'SELECT count(*) FROM trips t WHERE NOT EXISTS (SELECT 1 FROM calendar c WHERE c.service_id=t.service_id) AND NOT EXISTS (SELECT 1 FROM calendar_dates d WHERE d.service_id=t.service_id AND d.exception_type=1)',
        ]) {
          if ((Sqflite.firstIntValue(await txn.rawQuery(sql)) ?? 0) > 0) {
            throw const FormatException(
              'Riferimenti GTFS mancanti: importazione annullata',
            );
          }
        }
        if (maxSeconds == 0) {
          throw const FormatException('Nessun orario utilizzabile');
        }
        for (final entry in {
          'source': source,
          'imported_at': DateTime.now().toUtc().toIso8601String(),
          'max_seconds': '$maxSeconds',
          'end_date': endDate,
        }.entries) {
          await txn.insert('metadata', {
            'key': entry.key,
            'value': entry.value,
          });
        }
      });
    } finally {
      await Directory(directory).delete(recursive: true);
    }
  }

  static Map<String, Object?> convert(String table, Map<String, String> row) {
    String need(String k) {
      final value = row[k] ?? '';
      if (value.isEmpty) throw FormatException('$k mancante in $table.txt');
      return value;
    }

    String text(String k) => row[k] ?? '';
    int? time(String k) => text(k).isEmpty ? null : gtfsSeconds(text(k));
    String date(String k) {
      final value = need(k);
      parseServiceDate(value);
      return value;
    }

    switch (table) {
      case 'stops':
        return {
          'stop_id': need('stop_id'),
          'stop_code': text('stop_code'),
          'stop_name': need('stop_name'),
          'location_type': text('location_type'),
        };
      case 'routes':
        if (text('route_short_name').isEmpty &&
            text('route_long_name').isEmpty) {
          throw const FormatException('Linea senza nome');
        }
        return {
          'route_id': need('route_id'),
          'route_short_name': text('route_short_name'),
          'route_long_name': text('route_long_name'),
        };
      case 'trips':
        return {
          'trip_id': need('trip_id'),
          'route_id': need('route_id'),
          'service_id': need('service_id'),
          'trip_headsign': text('trip_headsign'),
        };
      case 'stop_times':
        final seq = int.tryParse(need('stop_sequence'));
        if (seq == null || seq < 0) {
          throw const FormatException('stop_sequence non valido');
        }
        final arrival = time('arrival_time'),
            departure = time('departure_time');
        if (arrival != null && departure != null && departure < arrival) {
          throw const FormatException('Partenza precedente all’arrivo');
        }
        return {
          'trip_id': need('trip_id'),
          'stop_id': need('stop_id'),
          'stop_sequence': seq,
          'arrival_secs': arrival,
          'departure_secs': departure,
          'pickup_type': text('pickup_type'),
        };
      case 'calendar':
        final start = date('start_date'), end = date('end_date');
        if (start.compareTo(end) > 0) {
          throw const FormatException('Calendario invertito');
        }
        final days = <String, Object?>{};
        for (final k in [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ]) {
          if (!['0', '1'].contains(need(k))) {
            throw const FormatException('Giorno calendario non valido');
          }
          days[k] = int.parse(need(k));
        }
        return {
          'service_id': need('service_id'),
          ...days,
          'start_date': start,
          'end_date': end,
        };
      case 'calendar_dates':
        final type = int.tryParse(need('exception_type'));
        if (type != 1 && type != 2) {
          throw const FormatException('Eccezione non valida');
        }
        return {
          'service_id': need('service_id'),
          'date': date('date'),
          'exception_type': type,
        };
      default:
        throw FormatException('Tabella non supportata: $table');
    }
  }
}
