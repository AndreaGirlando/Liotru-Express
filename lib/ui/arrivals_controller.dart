import 'package:flutter/foundation.dart';
import '../app_state.dart';
import '../domain/models.dart';

enum ArrivalsStatus { checking, live, off, noCoverage, unavailable, selectedDate }

class ArrivalsController extends ChangeNotifier {
  ArrivalsController(this.state, this.stop, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final AppState state;
  final BusStop stop;
  final DateTime Function() clock;
  static const nearbyWindow = Duration(minutes: 90);
  List<Arrival> arrivals = [];
  bool loading = true, refreshing = false, active = true;
  bool _disposed = false, _again = false;
  DateTime? selected, checkedAt, feedStamp;
  String? error;
  String message = 'Caricamento degli orari AMTS…';
  ArrivalsStatus status = ArrivalsStatus.checking;
  DateTime get reference => selected ?? checkedAt ?? clock();
  List<Arrival> get nearby => arrivals.where((a) => !a.time.isBefore(reference) && a.time.difference(reference) <= nearbyWindow).toList();
  List<Arrival> get later => arrivals.where((a) => a.time.difference(reference) > nearbyWindow).toList();
  void publish() { if (!_disposed) notifyListeners(); }
  void select(DateTime? value) {
    selected = value; arrivals = []; loading = true; feedStamp = null; error = null;
    status = value == null ? ArrivalsStatus.checking : ArrivalsStatus.selectedDate;
    message = value == null ? 'Caricamento degli arrivi…' : 'Orari AMTS per la data selezionata.';
    publish();
    if (refreshing) { _again = true; } else { refresh(); }
  }
  List<Arrival> _upcoming(List<Arrival> rows, DateTime from) => rows.where((a) => !a.time.isBefore(from) && a.time.isBefore(from.add(const Duration(hours: 24)))).toList();

  Future<void> refresh() async {
    if (refreshing || _disposed || !active) return;
    refreshing = true; error = null; publish();
    final requested = selected;
    try {
      final now = clock();
      final from = requested ?? now;
      final scheduled = await state.database.arrivals(stop.id,
        from.subtract(requested == null ? const Duration(hours: 3) : Duration.zero),
        horizon: requested == null ? const Duration(hours: 27) : const Duration(hours: 24));
      if (_disposed || requested != selected) return;
      // Show SQLite immediately. Slow or unavailable network must never hide
      // the offline timetable behind a spinner.
      arrivals = _upcoming(scheduled, requested ?? clock());
      loading = false; checkedAt = clock(); feedStamp = null;
      status = requested != null ? ArrivalsStatus.selectedDate : state.preferences.realtimeEnabled ? ArrivalsStatus.checking : ArrivalsStatus.off;
      message = requested != null ? 'Orari AMTS per la data selezionata.' : state.preferences.realtimeEnabled ? 'Verifica delle previsioni BusOne…' : 'Tempo reale disattivato. Orari ufficiali AMTS.';
      publish();
      if (requested == null && state.preferences.realtimeEnabled && active) {
        final response = await state.realtime.fetch(state.preferences.realtimeUrl, clock());
        if (_disposed || requested != selected) return;
        final feed = response.feed;
        if (feed != null && feed.freshAt(clock())) {
          arrivals = _upcoming(feed.apply(scheduled, clock()), clock());
          feedStamp = feed.timestamp;
          final count = nearby.where((a) => a.isRealtime).length;
          status = count > 0 ? ArrivalsStatus.live : ArrivalsStatus.noCoverage;
          message = count > 0 ? '$count ${count == 1 ? 'previsione aggiornata' : 'previsioni aggiornate'} per questa fermata.' : 'Nessuna previsione aggiornata a breve per questa fermata. Mostriamo gli orari AMTS.';
        } else {
          arrivals = _upcoming(scheduled, clock());
          status = ArrivalsStatus.unavailable;
          message = response.message;
        }
        checkedAt = clock(); publish();
      }
    } catch (_) {
      if (!_disposed && requested == selected) {
        loading = false; error = 'Non riesco a leggere gli orari. Riprova.'; publish();
      }
    } finally {
      refreshing = false; publish();
      if (_again && !_disposed && active) { _again = false; refresh(); }
    }
  }
  @override
  void dispose() { _disposed = true; super.dispose(); }
}
