import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_state.dart';
import '../domain/gtfs_time.dart';
import '../domain/models.dart';
import 'design.dart';
import 'settings.dart';
import 'routes.dart';
import 'metro.dart';
import 'stop_detail.dart';
import 'app_chrome.dart';
import 'initial_download.dart';
import 'home_metro.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(this.state, {this.autoRefresh = true, super.key});
  final AppState state;
  final bool autoRefresh;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int index = 0;
  bool continueWithoutData = false;
  Timer? expiryCheck;
  void checkData() {
    if (widget.autoRefresh) unawaited(widget.state.refreshScheduleIfNeeded());
  }

  void startChecks() {
    expiryCheck?.cancel();
    if (widget.autoRefresh) {
      expiryCheck = Timer.periodic(
        const Duration(minutes: 1),
        (_) => checkData(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startChecks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkData();
      startChecks();
    } else {
      expiryCheck?.cancel();
    }
  }

  @override
  void dispose() {
    expiryCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void settings() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => SettingsPage(widget.state)),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final initial =
          widget.autoRefresh &&
          widget.state.feed == null &&
          !continueWithoutData;
      return Scaffold(
        appBar: AppTopBar(
          section: initial
              ? 'Benvenuto a bordo'
              : [
                  'I tuoi preferiti',
                  'Bus · fermate e linee',
                  'Metro FCE',
                ][index],
          onSettings: settings,
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: initial
              ? InitialDownload(
                  busy: widget.state.importing,
                  progress: widget.state.progress,
                  fraction: widget.state.downloadProgress,
                  error: widget.state.automaticFailed
                      ? widget.state.automaticMessage
                      : null,
                  onRetry: () => unawaited(
                    widget.state.refreshScheduleIfNeeded(force: true),
                  ),
                  onContinue: () => setState(() => continueWithoutData = true),
                )
              : Column(
                  children: [
                    if (widget.state.automaticMessage != null)
                      DataUpdateNotice(widget.state),
                    Expanded(
                      child: switch (index) {
                        0 => StopList(
                          widget.state,
                          favorites: true,
                          onSearch: () => setState(() => index = 1),
                          onMetro: () async {
                            await widget.state.preferences.setMetroStation(
                              widget.state.preferences.metroFavoriteStation,
                            );
                            if (mounted) setState(() => index = 2);
                          },
                          onSettings: settings,
                        ),
                        1 => ExploreScreen(widget.state, onSettings: settings),
                        _ => MetroScreen(widget.state),
                      },
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: initial
            ? null
            : Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search_rounded),
                      label: 'Bus',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.subway_outlined),
                      selectedIcon: Icon(Icons.subway_rounded),
                      label: 'Metro',
                    ),
                  ],
                ),
              ),
      );
    },
  );
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen(this.state, {this.onSettings, super.key});
  final AppState state;
  final VoidCallback? onSettings;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool lines = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Per fermata'),
                icon: Icon(Icons.location_on_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Per linea'),
                icon: Icon(Icons.alt_route_rounded),
              ),
            ],
            selected: {lines},
            onSelectionChanged: (value) => setState(() => lines = value.single),
          ),
        ),
      ),
      Expanded(
        child: lines
            ? RouteList(
                widget.state,
                compact: true,
                onSettings: widget.onSettings,
              )
            : StopList(
                widget.state,
                favorites: false,
                compact: true,
                onSettings: widget.onSettings,
              ),
      ),
    ],
  );
}

class DataUpdateNotice extends StatelessWidget {
  const DataUpdateNotice(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const Key('data-update-notice'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      color: state.automaticFailed || state.feedExpired
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primary.withValues(alpha: .07),
      child: Row(
        children: [
          Icon(
            state.automaticUpdating
                ? Icons.sync_rounded
                : state.automaticFailed
                ? Icons.cloud_off_outlined
                : Icons.info_outline_rounded,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.automaticMessage!,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (state.automaticFailed && !state.importing)
            IconButton(
              tooltip: 'Riprova aggiornamento',
              onPressed: () =>
                  unawaited(state.refreshScheduleIfNeeded(force: true)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            tooltip: 'Chiudi avviso',
            onPressed: state.dismissAutomaticMessage,
            icon: const Icon(Icons.close_rounded),
            iconSize: 18,
          ),
        ],
      ),
    ),
  );
}

class StopList extends StatefulWidget {
  const StopList(
    this.state, {
    required this.favorites,
    this.onSearch,
    this.onMetro,
    this.onSettings,
    this.compact = false,
    super.key,
  });
  final AppState state;
  final bool favorites;
  final bool compact;
  final VoidCallback? onSearch, onMetro, onSettings;
  @override
  State<StopList> createState() => _StopListState();
}

class _StopListState extends State<StopList> {
  final controller = TextEditingController();
  Timer? debounce;
  List<BusStop> stops = [];
  bool loading = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.state.addListener(changed);
    search();
  }

  @override
  void didUpdateWidget(covariant StopList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favorites != widget.favorites) {
      controller.clear();
      search();
    }
  }

  void changed() {
    if (!widget.state.importing) search();
  }

  Future<void> search() async {
    final token = ++generation;
    setState(() => loading = true);
    try {
      final result = await widget.state.database.search(
        controller.text.trim(),
        ids: widget.favorites ? widget.state.preferences.favorites : null,
      );
      if (mounted && token == generation) {
        setState(() {
          stops = result;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          loading = false;
          error = 'Ricerca non riuscita. Riprova.';
        });
      }
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(changed);
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.state.feed;
    final expired =
        info != null &&
        info.endDate.isNotEmpty &&
        info.endDate.compareTo(
              serviceDate(tz.TZDateTime.from(DateTime.now(), rome)),
            ) <
            0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.favorites) ...[
                  HomeMetroCard(widget.state, onOpen: widget.onMetro),
                ] else ...[
                  if (!widget.compact) ...[
                    Text(
                      'Trova la tua\nfermata.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Cerca per nome o codice. Anche senza rete.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  TextField(
                    controller: controller,
                    onChanged: (_) {
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 250),
                        search,
                      );
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Nome o codice fermata',
                      suffixIcon: IconButton(
                        tooltip: 'Cancella ricerca',
                        onPressed: () {
                          controller.clear();
                          search();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                SectionTitle(
                  widget.favorites ? 'Le tue fermate' : 'Fermate AMTS',
                  trailing: info == null
                      ? null
                      : SmallPill(
                          widget.favorites
                              ? '${widget.state.preferences.favorites.length} salvate'
                              : '${info.stops} fermate',
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.favorites
                      ? 'I tuoi punti di partenza, sempre qui.'
                      : 'Tocca una fermata per vedere gli arrivi.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                if (expired && widget.state.automaticMessage == null) ...[
                  const SizedBox(height: 14),
                  _DataNotice(onTap: widget.onSettings),
                ],
              ],
            ),
          ),
        ),
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: EmptyPanel(
                title: 'Un momento…',
                message: error!,
                action: TextButton(
                  onPressed: search,
                  child: const Text('Riprova'),
                ),
              ),
            ),
          )
        else if (stops.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: EmptyPanel(
                icon: info == null
                    ? Icons.download_rounded
                    : widget.favorites
                    ? Icons.bookmark_border_rounded
                    : Icons.search_off_rounded,
                title: info == null
                    ? 'Partiamo dagli orari.'
                    : widget.favorites
                    ? 'I tuoi posti, a un tocco.'
                    : 'Nessuna fermata trovata',
                message: info == null
                    ? 'Scarica i dati ufficiali AMTS per cercare fermate e consultare gli orari offline.'
                    : widget.favorites
                    ? 'Cerca una fermata e salvala con la stella. Qui ritroverai subito i suoi arrivi.'
                    : 'Prova un altro nome o il codice della fermata.',
                action: info == null
                    ? FilledButton.icon(
                        onPressed: widget.onSettings,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Carica gli orari AMTS'),
                      )
                    : widget.favorites
                    ? FilledButton.icon(
                        onPressed: widget.onSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Cerca una fermata'),
                      )
                    : null,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            sliver: SliverList.builder(
              itemCount: stops.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StopCard(widget.state, stops[i]),
              ),
            ),
          ),
        if (info != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: Text(
                'Orari ufficiali AMTS · aggiornati il ${displayDate(info.importedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class StopCard extends StatelessWidget {
  const StopCard(this.state, this.stop, {super.key});
  final AppState state;
  final BusStop stop;
  @override
  Widget build(BuildContext context) {
    final favorite = state.preferences.favorites.contains(stop.id);
    final routes = stop.routes.split(', ').where((r) => r.isNotEmpty).toList();
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(23),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => StopDetail(state, stop)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.directions_bus_outlined, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FERMATA ${stop.code.isEmpty ? stop.id : stop.code}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          stop.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: favorite
                        ? 'Rimuovi dai preferiti'
                        : 'Salva nei preferiti',
                    onPressed: () => state.toggle(stop.id),
                    icon: Icon(
                      favorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: favorite
                          ? BusDesign.teal
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (routes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final route in routes.take(5)) SmallPill(route),
                    if (routes.length > 5) SmallPill('+${routes.length - 5}'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DataNotice extends StatelessWidget {
  const _DataNotice({this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      onTap: onTap,
      leading: const Icon(Icons.event_busy_rounded),
      title: const Text('Gli orari AMTS sono da aggiornare'),
      subtitle: const Text('Il calendario scaricato è scaduto.'),
      trailing: const Icon(Icons.arrow_forward_rounded),
    ),
  );
}

String displayDate(DateTime date) {
  final d = tz.TZDateTime.from(date, rome);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${clockTime(date)}';
}
