import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../domain/models.dart';
import 'design.dart';
import 'stop_detail.dart';

class RouteList extends StatefulWidget {
  const RouteList(this.state, {this.onSettings, super.key});
  final AppState state;
  final VoidCallback? onSettings;
  @override
  State<RouteList> createState() => _RouteListState();
}

class _RouteListState extends State<RouteList> {
  final input = TextEditingController();
  Timer? debounce;
  List<BusRoute> routes = [];
  bool loading = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.state.addListener(changed);
    search();
  }

  void changed() {
    if (!widget.state.importing) search();
  }

  Future<void> search() async {
    final token = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final found = await widget.state.database.searchRoutes(input.text);
      if (mounted && token == generation) {
        setState(() {
          routes = found;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          error = 'Non riesco a leggere le linee. Riprova.';
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    widget.state.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SmallPill(
                'RICERCA PER AUTOBUS',
                icon: Icons.directions_bus_rounded,
              ),
              const SizedBox(height: 20),
              Text(
                'Dove passa\nil tuo bus?',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Scegli la linea e scopri tutte le fermate, all’andata e al ritorno.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: input,
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 250), search);
                  setState(() {});
                },
                onSubmitted: (_) {
                  debounce?.cancel();
                  search();
                },
                decoration: InputDecoration(
                  labelText: 'Numero o nome della linea',
                  hintText: 'BRT1, 156, Metro Shuttle…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: input.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Cancella ricerca',
                          onPressed: () {
                            debounce?.cancel();
                            input.clear();
                            search();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              SectionTitle(
                'Le linee AMTS',
                trailing: SmallPill('${routes.length} trovate'),
              ),
            ],
          ),
        ),
      ),
      if (loading)
        const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()),
        )
      else if (error != null || routes.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          sliver: SliverToBoxAdapter(
            child: EmptyPanel(
              title: error != null
                  ? 'Un momento…'
                  : widget.state.feed == null
                  ? 'Carica le linee AMTS'
                  : 'Nessuna linea trovata',
              message:
                  error ??
                  (widget.state.feed == null
                      ? 'Scarica gli orari per cercare gli autobus e i loro percorsi anche offline.'
                      : 'Prova il numero della linea o una parte del suo nome.'),
              action: error != null
                  ? TextButton(onPressed: search, child: const Text('Riprova'))
                  : widget.state.feed == null
                  ? FilledButton(
                      onPressed: widget.onSettings,
                      child: const Text('Carica gli orari AMTS'),
                    )
                  : null,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          sliver: SliverList.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RouteCard(widget.state, routes[index]),
            ),
          ),
        ),
    ],
  );
}

class RouteCard extends StatelessWidget {
  const RouteCard(this.state, this.route, {super.key});
  final AppState state;
  final BusRoute route;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(23),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      title: Text(route.label, style: Theme.of(context).textTheme.titleLarge),
      subtitle: route.longName.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(route.longName),
            ),
      leading: const Icon(Icons.directions_bus_rounded),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => RouteDetail(state, route)),
      ),
    ),
  );
}

class RouteDetail extends StatefulWidget {
  const RouteDetail(this.state, this.route, {super.key});
  final AppState state;
  final BusRoute route;
  @override
  State<RouteDetail> createState() => _RouteDetailState();
}

class _RouteDetailState extends State<RouteDetail> {
  late Future<List<RoutePattern>> future = widget.state.database.routePatterns(
    widget.route.id,
  );
  String? selectedDirection;
  int variant = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fermate dell’autobus')),
    body: FutureBuilder<List<RoutePattern>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data!.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              EmptyPanel(
                title: 'Percorso non disponibile',
                message: snapshot.hasError
                    ? 'Non riesco a leggere le fermate. Riprova.'
                    : 'Non ci sono fermate pubblicate per questa linea nei dati scaricati.',
                action: TextButton(
                  onPressed: () => setState(() {
                    future = widget.state.database.routePatterns(
                      widget.route.id,
                    );
                  }),
                  child: const Text('Riprova'),
                ),
              ),
            ],
          );
        }
        final patterns = snapshot.data!;
        final directions = patterns.map((p) => p.directionId).toSet().toList();
        final direction = directions.contains(selectedDirection)
            ? selectedDirection!
            : directions.first;
        final variants = patterns
            .where((p) => p.directionId == direction)
            .toList();
        final index = variant < variants.length ? variant : 0;
        final pattern = variants[index];
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmallPill(
                      'LINEA ${widget.route.label}',
                      icon: Icons.directions_bus_rounded,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.route.longName.isEmpty
                          ? widget.route.label
                          : widget.route.longName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (directions.length > 1 || direction.isNotEmpty) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final id in directions)
                            ChoiceChip(
                              label: Text(
                                patterns
                                    .firstWhere((p) => p.directionId == id)
                                    .directionLabel,
                              ),
                              selected: id == direction,
                              onSelected: (_) => setState(() {
                                selectedDirection = id;
                                variant = 0;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DA',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            pattern.stops.first.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'VERSO',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            pattern.stops.last.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    if (variants.length > 1) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: index,
                        key: ValueKey(direction),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Variante del percorso',
                        ),
                        items: [
                          for (var i = 0; i < variants.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                'Variante ${i + 1} · ${variants[i].stops.length} fermate',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => variant = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Percorsi del calendario scaricato. La linea potrebbe non essere in servizio adesso. Tocca una fermata per consultarne gli arrivi.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (directions.contains('')) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Se mancano Andata e Ritorno, aggiorna i dati AMTS. Quando la fonte non indica la direzione, distingui i percorsi dalla destinazione.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 22),
                    SectionTitle(
                      'Tutte le fermate',
                      trailing: SmallPill('${pattern.stops.length} in ordine'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              sliver: SliverList.builder(
                itemCount: pattern.stops.length,
                itemBuilder: (context, i) {
                  final stop = pattern.stops[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: BusDesign.lime,
                          foregroundColor: BusDesign.ink,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          stop.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          'Fermata ${stop.code.isEmpty ? stop.id : stop.code}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => StopDetail(widget.state, stop),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
