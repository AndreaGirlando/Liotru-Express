import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_state.dart';
import '../domain/gtfs_time.dart';
import '../domain/models.dart';
import 'design.dart';
import 'settings.dart';
import 'stop_detail.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(this.state, {super.key});
  final AppState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(bottom: false, child: switch (index) {
      0 => StopList(widget.state, favorites: true, onSearch: () => setState(() => index = 1), onSettings: () => setState(() => index = 2)),
      1 => StopList(widget.state, favorites: false, onSettings: () => setState(() => index = 2)),
      _ => SettingsScreen(widget.state),
    }),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
      child: NavigationBar(selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value), destinations: const [
        NavigationDestination(icon: Icon(Icons.bookmark_outline_rounded), selectedIcon: Icon(Icons.bookmark_rounded), label: 'Preferiti'),
        NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Fermate'),
        NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Impostazioni'),
      ]),
    ),
  );
}

class StopList extends StatefulWidget {
  const StopList(this.state, {required this.favorites, this.onSearch, this.onSettings, super.key});
  final AppState state;
  final bool favorites;
  final VoidCallback? onSearch, onSettings;
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
  void initState() { super.initState(); widget.state.addListener(changed); search(); }
  @override
  void didUpdateWidget(covariant StopList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favorites != widget.favorites) { controller.clear(); search(); }
  }
  void changed() { if (!widget.state.importing) search(); }
  Future<void> search() async {
    final token = ++generation;
    setState(() => loading = true);
    try {
      final result = await widget.state.database.search(controller.text.trim(), ids: widget.favorites ? widget.state.preferences.favorites : null);
      if (mounted && token == generation) setState(() { stops = result; loading = false; error = null; });
    } catch (_) {
      if (mounted && token == generation) setState(() { loading = false; error = 'Ricerca non riuscita. Riprova.'; });
    }
  }
  @override
  void dispose() { widget.state.removeListener(changed); debounce?.cancel(); controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final info = widget.state.feed;
    final expired = info != null && info.endDate.isNotEmpty && info.endDate.compareTo(serviceDate(tz.TZDateTime.from(DateTime.now(), rome))) < 0;
    return CustomScrollView(slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 16), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 39, height: 39, decoration: BoxDecoration(color: BusDesign.ink, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.directions_bus_rounded, color: BusDesign.lime, size: 24)),
          const SizedBox(width: 10),
          Expanded(child: Text.rich(TextSpan(children: [const TextSpan(text: 'catania'), const TextSpan(text: 'bus', style: TextStyle(color: BusDesign.teal))]), style: Theme.of(context).textTheme.titleLarge)),
          if (MediaQuery.sizeOf(context).width > 390 && MediaQuery.textScalerOf(context).scale(12) < 18) const SmallPill('AMTS CATANIA', icon: Icons.location_on_outlined),
        ]),
        const SizedBox(height: 25),
        if (widget.favorites) ...[
          Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff1b4052), BusDesign.ink], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(29)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SmallPill('LA TUA CITTÀ, OGNI GIORNO', color: BusDesign.lime, background: Color(0xff2c4b54)),
            const SizedBox(height: 18),
            Text('Il tuo prossimo\nbus a Catania.', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Le fermate che usi. Gli arrivi che ti servono.', style: TextStyle(color: Color(0xffb6cbd0), height: 1.5)),
            const SizedBox(height: 22),
            Material(color: Colors.white, borderRadius: BorderRadius.circular(17), child: InkWell(borderRadius: BorderRadius.circular(17), onTap: widget.onSearch, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 17), child: Row(children: [Icon(Icons.search_rounded, color: BusDesign.ink), SizedBox(width: 11), Expanded(child: Text('Cerca una fermata', style: TextStyle(color: BusDesign.ink, fontWeight: FontWeight.w700))), Icon(Icons.arrow_forward_rounded, size: 20, color: BusDesign.ink)])))),
          ])),
        ] else ...[
          Text('Trova la tua\nfermata.', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text('Cerca per nome o codice. Anche senza rete.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          TextField(controller: controller, onChanged: (_) { debounce?.cancel(); debounce = Timer(const Duration(milliseconds: 250), search); }, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Nome o codice fermata', suffixIcon: IconButton(tooltip: 'Cancella ricerca', onPressed: () { controller.clear(); search(); }, icon: const Icon(Icons.close_rounded)))),
        ],
        const SizedBox(height: 26),
        SectionTitle(widget.favorites ? 'Le tue fermate' : 'Fermate AMTS', trailing: info == null ? null : SmallPill(widget.favorites ? '${widget.state.preferences.favorites.length} salvate' : '${info.stops} fermate')),
        const SizedBox(height: 8),
        Text(widget.favorites ? 'I tuoi punti di partenza, sempre qui.' : 'Tocca una fermata per vedere gli arrivi.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        if (expired) ...[const SizedBox(height: 14), _DataNotice(onTap: widget.onSettings)],
      ]))),
      if (loading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
      else if (error != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(22), child: EmptyPanel(title: 'Un momento…', message: error!, action: TextButton(onPressed: search, child: const Text('Riprova')))))
      else if (stops.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 24), child: EmptyPanel(
        icon: info == null ? Icons.download_rounded : widget.favorites ? Icons.bookmark_border_rounded : Icons.search_off_rounded,
        title: info == null ? 'Partiamo dagli orari.' : widget.favorites ? 'I tuoi posti, a un tocco.' : 'Nessuna fermata trovata',
        message: info == null ? 'Scarica i dati ufficiali AMTS per cercare fermate e consultare gli orari offline.' : widget.favorites ? 'Cerca una fermata e salvala con la stella. Qui ritroverai subito i suoi arrivi.' : 'Prova un altro nome o il codice della fermata.',
        action: info == null ? FilledButton.icon(onPressed: widget.onSettings, icon: const Icon(Icons.download_rounded), label: const Text('Carica gli orari AMTS')) : widget.favorites ? FilledButton.icon(onPressed: widget.onSearch, icon: const Icon(Icons.search), label: const Text('Cerca una fermata')) : null,
      )))
      else SliverPadding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 24), sliver: SliverList.builder(itemCount: stops.length, itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: StopCard(widget.state, stops[i])))),
      if (info != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 22), child: Text('Orari ufficiali AMTS · aggiornati il ${displayDate(info.importedAt)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)))),
    ]);
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
    return Material(color: colors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23), side: BorderSide(color: colors.outlineVariant)), clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StopDetail(state, stop))), child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 10, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: colors.primary.withValues(alpha: .06), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.directions_bus_outlined, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FERMATA ${stop.code.isEmpty ? stop.id : stop.code}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 5), Text(stop.name, style: Theme.of(context).textTheme.titleMedium),
        ])),
        IconButton(tooltip: favorite ? 'Rimuovi dai preferiti' : 'Salva nei preferiti', onPressed: () => state.toggle(stop.id), icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded, color: favorite ? BusDesign.teal : colors.onSurfaceVariant)),
      ]),
      if (routes.isNotEmpty) ...[const SizedBox(height: 16), Wrap(spacing: 6, runSpacing: 6, children: [for (final route in routes.take(5)) SmallPill(route), if (routes.length > 5) SmallPill('+${routes.length - 5}')])],
    ]))));
  }
}

class _DataNotice extends StatelessWidget {
  const _DataNotice({this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(16), child: ListTile(onTap: onTap, leading: const Icon(Icons.event_busy_rounded), title: const Text('Gli orari AMTS sono da aggiornare'), subtitle: const Text('Il calendario scaricato è scaduto.'), trailing: const Icon(Icons.arrow_forward_rounded)));
}

String displayDate(DateTime date) {
  final d = tz.TZDateTime.from(date, rome);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${clockTime(date)}';
}
