import 'models.dart';

dynamic field(Map<String,dynamic> map, String camel, String snake) => map[camel] ?? map[snake];
int? number(dynamic value) => value is int ? value : int.tryParse('$value');
Map<String,dynamic>? object(dynamic value) => value is Map<String,dynamic> ? value : null;
bool relation(dynamic value, String name, int code) => value == name || number(value) == code;

class RealtimeFeed {
  RealtimeFeed(this.timestamp, this.updates);
  final DateTime timestamp;
  final List<Map<String,dynamic>> updates;
  static const maxAge = Duration(minutes: 3);

  factory RealtimeFeed.parse(dynamic json, DateTime now) {
    final root = object(json);
    if (root == null) throw const FormatException('JSON realtime non valido');
    final header = object(root['header']);
    final stamp = number(header?['timestamp']);
    if (header == null || stamp == null) throw const FormatException('Timestamp realtime mancante');
    if (relation(header['incrementality'], 'DIFFERENTIAL', 1)) {
      throw const FormatException('Feed incrementale non supportato');
    }
    final time = DateTime.fromMillisecondsSinceEpoch(stamp * 1000, isUtc:true);
    if (!_fresh(time, now)) throw const FormatException('Dati realtime scaduti o con data futura');
    final entities = root['entity'];
    if (entities is! List) throw const FormatException('Elenco realtime mancante');
    final updates = <Map<String,dynamic>>[];
    for (final entity in entities) {
      final e = object(entity);
      if (e == null || field(e,'isDeleted','is_deleted') == true) continue;
      final u = object(field(e, 'tripUpdate','trip_update'));
      if (u == null) continue; // VehiclePositions are not arrival predictions.
      final stamp = number(u['timestamp']);
      if (stamp != null && !_fresh(DateTime.fromMillisecondsSinceEpoch(stamp*1000, isUtc:true), now)) continue;
      updates.add(u);
    }
    return RealtimeFeed(time, updates);
  }

  static bool _fresh(DateTime stamp, DateTime now) =>
      now.difference(stamp) <= maxAge && stamp.difference(now) <= const Duration(seconds:30);
  bool freshAt(DateTime now) => _fresh(timestamp, now);

  List<Arrival> apply(List<Arrival> scheduled, DateTime now) {
    if (!freshAt(now)) return scheduled;
    final result = <Arrival>[];
    for (final arrival in scheduled) {
      final matches = updates.where((u) {
        final trip = object(u['trip']);
        if (trip == null || field(trip,'tripId','trip_id') != arrival.tripId) return false;
        final date = field(trip,'startDate','start_date');
        final start = field(trip,'startTime','start_time');
        if (date != null && date != arrival.serviceDate) return false;
        if (start != null && start != arrival.tripStart) return false;
        // Without a service date, reject ambiguous trip instances across days.
        if (date == null && scheduled.where((a) => a.tripId == arrival.tripId)
            .map((a)=>a.serviceDate).toSet().length != 1) { return false; }
        return true;
      }).toList();
      if (matches.length != 1) { result.add(arrival); continue; }
      final update = matches.single;
      final trip = object(update['trip'])!;
      final status = field(trip,'scheduleRelationship','schedule_relationship');
      if (relation(status,'CANCELED',3) || relation(status,'DELETED',7)) continue;
      if (status != null && !relation(status,'SCHEDULED',0)) {
        result.add(arrival); continue;
      }
      final stops = field(update,'stopTimeUpdate','stop_time_update');
      int? delay = number(update['delay']);
      DateTime? prediction;
      var skipped = false;
      if (stops is List) {
        final items = stops.map(object).whereType<Map<String,dynamic>>().toList();
        items.sort((a,b) => (number(field(a,'stopSequence','stop_sequence')) ?? 2147483647)
            .compareTo(number(field(b,'stopSequence','stop_sequence')) ?? 2147483647));
        for (final stop in items) {
          final seq = number(field(stop,'stopSequence','stop_sequence'));
          final id = field(stop,'stopId','stop_id');
          final exact = seq != null ? seq == arrival.sequence && (id == null || id == arrival.stopId)
              : id == arrival.stopId && scheduled.where((a)=>a.tripId==arrival.tripId &&
                a.serviceDate==arrival.serviceDate && a.stopId==arrival.stopId).length==1;
          if(seq==null && !exact) continue;
          if (seq != null && seq > arrival.sequence) continue;
          final relationship = field(stop,'scheduleRelationship','schedule_relationship');
          if (exact && relation(relationship,'SKIPPED',1)) { skipped = true; break; }
          if (relation(relationship,'NO_DATA',2)) {
            delay = null;
            if (exact) prediction = null;
            continue;
          }
          final event = object(stop['arrival']);
          final departure = object(stop['departure']);
          if (exact) {
            final seconds = number(event?['time']);
            final eventDelay = number(event?['delay']);
            if (seconds != null) {
              prediction = DateTime.fromMillisecondsSinceEpoch(seconds*1000,isUtc:true);
            } else if (eventDelay != null || delay != null) {
              prediction = arrival.scheduled.add(Duration(seconds:eventDelay ?? delay!));
            }
          }
          // Delay propagation follows stop sequence. Absolute upstream times
          // alone cannot be converted to delays without that stop's schedule.
          if (seq != null && seq < arrival.sequence) {
            final nextDelay = number(departure?['delay']) ?? number(event?['delay']);
            if (nextDelay != null) { delay = nextDelay; }
            else if (event?['time'] != null || departure?['time'] != null) { delay = null; }
          }
        }
      }
      if (skipped) continue;
      prediction ??= delay == null ? null : arrival.scheduled.add(Duration(seconds:delay));
      result.add(prediction == null ? arrival : arrival.withPrediction(prediction));
    }
    result.sort((a,b) => a.time.compareTo(b.time));
    return result;
  }
}
