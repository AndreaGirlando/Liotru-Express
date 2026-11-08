import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/metro_timetable.dart';
import '../domain/arrival_display.dart';
import '../domain/gtfs_time.dart';
import '../domain/metro.dart';
import 'design.dart';

class MetroScreen extends StatefulWidget {
  const MetroScreen(this.state, {this.timetable, this.clock, super.key});
  final AppState state;
  final MetroTimetable? timetable;
  final DateTime Function()? clock;
  @override
  State<MetroScreen> createState() => _MetroScreenState();
}

class _MetroScreenState extends State<MetroScreen> with WidgetsBindingObserver {
  late Future<MetroTimetable> future;
  late String stationId = widget.state.preferences.metroStation;
  Timer? timer;
  DateTime get now => (widget.clock ?? DateTime.now)();
  Future<MetroTimetable> load() => widget.timetable == null
      ? loadMetroTimetable()
      : Future.value(widget.timetable!);
  @override
  void initState() {
    super.initState();
    future = load();
    WidgetsBinding.instance.addObserver(this);
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startTimer();
      setState(() {});
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MetroTimetable>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            EmptyPanel(
              title: 'Orario Metro non disponibile',
              message: 'Non riesco a caricare l’orario incluso nell’app.',
              action: TextButton(
                onPressed: () => setState(() => future = load()),
                child: const Text('Riprova'),
              ),
            ),
          ],
        );
      }
      final data = snapshot.data!;
      final selected = data.stations.firstWhere(
        (s) => s.id == stationId,
        orElse: () => data.stations.first,
      );
      final reference = now;
      final colors = Theme.of(context).colorScheme;
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: SmallPill('METROPOLITANA FCE', icon: Icons.subway_rounded),
          ),
          const SizedBox(height: 20),
          Text(
            'Quando passa\nla metro?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'La tua stazione. Tutte e due le direzioni.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
            initialValue: selected.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Stazione',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: [
              for (final station in data.stations)
                DropdownMenuItem(value: station.id, child: Text(station.name)),
            ],
            onChanged: (id) async {
              if (id == null) return;
              setState(() => stationId = id);
              try {
                await widget.state.preferences.setMetroStation(id);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Non riesco a salvare la stazione scelta.'),
                    ),
                  );
                }
              }
            },
          ),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: widget.state,
                builder: (context, _) {
                  final favorite =
                      widget.state.preferences.metroFavoriteStation == selected.id;
                  return IconButton(
                    tooltip: favorite
                        ? 'Stazione preferita della Home'
                        : 'Usa questa stazione nella Home',
                    onPressed: favorite ? null : () async {
                      try {
                        await widget.state.favoriteMetro(selected.id);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Non riesco a salvare la stazione preferita.')),
                          );
                        }
                      }
                    },
                    icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final direction in MetroDirection.values) ...[
            MetroArrivalCard(data, selected, direction, reference),
            const SizedBox(height: 14),
          ],
          if (reference.toUtc().difference(data.checked).inDays > 30) ...[
            const SizedBox(height: 16),
            SurfaceCard(
              child: Text(
                'Il quadro orario è stato verificato il ${metroDate(data.checked)}. Consulta FCE per eventuali variazioni.',
              ),
            ),
          ],
        ],
      );
    },
  );
}

class MetroArrivalCard extends StatelessWidget {
  const MetroArrivalCard(
    this.data,
    this.station,
    this.direction,
    this.reference, {
    super.key,
  });
  final MetroTimetable data;
  final MetroStation station;
  final MetroDirection direction;
  final DateTime reference;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final terminal = data.isDestination(station, direction);
    final arrivals = data.upcoming(station, direction, reference);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: BusDesign.lime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.subway_rounded, color: BusDesign.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verso ${direction.destination}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (terminal) ...[
            Text(
              'Sei al capolinea',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Per partire scegli la direzione opposta.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ] else if (arrivals.isEmpty)
            const Text('Nessun passaggio nell’orario disponibile.')
          else ...[
            Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  '${arrivals.first.estimated ? '~' : ''}${metroCountdown(arrivals.first.time, reference)}',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1.1,
                    color: colors.onSurface,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    arrivalWait(arrivals.first.time, reference),
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${arrivals.first.estimated ? 'Passaggio stimato' : 'Partenza programmata'} alle ${clockTime(arrivals.first.time)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            Text(
              arrivals.first.estimated
                  ? 'Stima da orario FCE · può variare'
                  : 'Orario FCE · ritardi non disponibili',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            if (arrivals.length > 1) ...[
              const SizedBox(height: 16),
              Text(
                'Poi: ${arrivals.skip(1).map((a) => arrivalWait(a.time, reference)).join(' · ')}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
