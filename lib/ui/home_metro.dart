import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/metro_timetable.dart';
import '../domain/arrival_display.dart';
import '../domain/gtfs_time.dart';
import '../domain/metro.dart';
import 'design.dart';

class HomeMetroCard extends StatefulWidget {
  const HomeMetroCard(
    this.state, {
    this.onOpen,
    this.timetable,
    this.clock,
    super.key,
  });
  final AppState state;
  final VoidCallback? onOpen;
  final MetroTimetable? timetable;
  final DateTime Function()? clock;
  @override
  State<HomeMetroCard> createState() => _HomeMetroCardState();
}

class _HomeMetroCardState extends State<HomeMetroCard>
    with WidgetsBindingObserver {
  late Future<MetroTimetable> future;
  Timer? timer;
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
  Widget build(BuildContext context) => Container(
    key: const Key('home-metro'),
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff1b4052), BusDesign.ink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(29),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.subway_rounded, color: BusDesign.lime),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La tua metro',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              if (widget.onOpen != null)
                IconButton(
                  tooltip: 'Apri Metro',
                  onPressed: widget.onOpen,
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<MetroTimetable>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Orario Metro non disponibile.'),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: BusDesign.lime,
                      ),
                      onPressed: () => setState(() => future = load()),
                      child: const Text('Riprova'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Text('Prepariamo i prossimi passaggi…');
              }
              final data = snapshot.data!;
              return ListenableBuilder(
                listenable: widget.state,
                builder: (context, _) {
                  final station = data.stations.firstWhere(
                    (s) =>
                        s.id == widget.state.preferences.metroFavoriteStation,
                    orElse: () => data.stations.first,
                  );
                  final reference = (widget.clock ?? widget.state.clock)();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('favorite-metro-${station.id}'),
                        initialValue: station.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Stazione preferita',
                          prefixIcon: Icon(Icons.star_rounded),
                        ),
                        items: [
                          for (final item in data.stations)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                        ],
                        onChanged: (id) async {
                          if (id == null) return;
                          try {
                            await widget.state.favoriteMetro(id);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Non riesco a salvare la stazione preferita.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cards = [
                            for (final direction in MetroDirection.values)
                              _Direction(data, station, direction, reference),
                          ];
                          if (constraints.maxWidth < 280 ||
                              MediaQuery.textScalerOf(context).scale(14) > 20) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                cards.first,
                                const SizedBox(height: 14),
                                cards.last,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cards.first),
                              const SizedBox(width: 14),
                              Expanded(child: cards.last),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Passaggi stimati · orario FCE',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xffb6cbd0),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _Direction extends StatelessWidget {
  const _Direction(this.data, this.station, this.direction, this.reference);
  final MetroTimetable data;
  final MetroStation station;
  final MetroDirection direction;
  final DateTime reference;
  @override
  Widget build(BuildContext context) {
    final passages = data.upcoming(station, direction, reference, limit: 1);
    final terminal = data.isDestination(station, direction);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verso ${direction.destination}',
          style: const TextStyle(
            color: BusDesign.lime,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        if (terminal)
          const Text('Sei al capolinea', style: TextStyle(fontSize: 13))
        else if (passages.isEmpty)
          const Text(
            'Nessun passaggio disponibile',
            style: TextStyle(fontSize: 13),
          )
        else ...[
          Text(
            '${passages.first.estimated ? '~' : ''}${metroCountdown(passages.first.time, reference)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            arrivalWait(passages.first.time, reference),
            style: const TextStyle(fontSize: 12, color: Color(0xffb6cbd0)),
          ),
          const SizedBox(height: 4),
          Text(
            'Alle ${clockTime(passages.first.time)}',
            style: const TextStyle(fontSize: 12, color: Color(0xffb6cbd0)),
          ),
        ],
      ],
    );
  }
}
