class BusStop {
  const BusStop(this.id, this.code, this.name, {this.routes = ''});
  final String id;
  final String code;
  final String name;
  final String routes;
}

class Arrival {
  const Arrival({
    required this.tripId,
    required this.stopId,
    required this.sequence,
    required this.route,
    required this.destination,
    required this.serviceDate,
    required this.tripStart,
    required this.scheduled,
    this.predicted,
    this.uncertaintySeconds,
  });
  final String tripId, stopId, route, destination, serviceDate, tripStart;
  final int sequence;
  final DateTime scheduled;
  final DateTime? predicted;
  final int? uncertaintySeconds;
  bool get isApproximate => isRealtime && (uncertaintySeconds ?? 0) > 120;
  DateTime get time => predicted ?? scheduled;
  bool get isRealtime => predicted != null;
  Arrival withPrediction(DateTime time, {int? uncertaintySeconds}) => Arrival(
    tripId: tripId,
    stopId: stopId,
    sequence: sequence,
    route: route,
    destination: destination,
    serviceDate: serviceDate,
    tripStart: tripStart,
    scheduled: scheduled,
    predicted: time,
    uncertaintySeconds: uncertaintySeconds,
  );
}

class FeedInfo {
  const FeedInfo({
    required this.importedAt,
    required this.source,
    required this.stops,
    required this.endDate,
  });
  final DateTime importedAt;
  final String source, endDate;
  final int stops;
}
