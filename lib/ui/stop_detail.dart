import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_state.dart';
import '../domain/arrival_display.dart';
import '../domain/gtfs_time.dart';
import '../domain/models.dart';
import 'arrivals_controller.dart';
import 'design.dart';

class StopDetail extends StatefulWidget {
  const StopDetail(this.state, this.stop, {this.clock, super.key});
  final AppState state;
  final BusStop stop;
  final DateTime Function()? clock;
  @override
  State<StopDetail> createState() => _StopDetailState();
}

class _StopDetailState extends State<StopDetail> with WidgetsBindingObserver {
  late final view = ArrivalsController(
    widget.state,
    widget.stop,
    clock: widget.clock,
  );
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    view.refresh();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (view.active &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          view.selected == null) {
        view.refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    view.active = state == AppLifecycleState.resumed;
    if (view.active) {
      view.refresh();
      startTimer();
    } else {
      timer?.cancel();
    }
  }

  Future<void> selectDate() async {
    final now = tz.TZDateTime.from(view.reference, rome);
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time != null && mounted) {
      view.select(
        tz.TZDateTime(
          rome,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Arrivi alla fermata',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      actions: [
        ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final favorite = widget.state.preferences.favorites.contains(
              widget.stop.id,
            );
            return IconButton(
              tooltip: favorite
                  ? 'Rimuovi dai preferiti'
                  : 'Salva nei preferiti',
              onPressed: () => widget.state.toggle(widget.stop.id),
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
            );
          },
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: ListenableBuilder(
      listenable: view,
      builder: (context, _) => RefreshIndicator(
        onRefresh: view.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmallPill(
                      'FERMATA ${widget.stop.code.isEmpty ? widget.stop.id : widget.stop.code}',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.stop.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (widget.stop.routes.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        'Linee ${widget.stop.routes}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    RealtimePanel(
                      view,
                      onEnable: () async {
                        await widget.state.setRealtimeEnabled(true);
                        view.refresh();
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            view.selected == null
                                ? 'PROSSIMI 90 MINUTI'
                                : 'ORARI SELEZIONATI',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Data e ora',
                          onPressed: selectDate,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 21,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aggiorna arrivi',
                          onPressed: view.refreshing ? null : view.refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    if (view.selected != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          children: [
                            SmallPill(
                              '${arrivalDay(view.selected!, DateTime.now())} ${clockTime(view.selected!)} · Europe/Rome',
                            ),
                            TextButton(
                              onPressed: () => view.select(null),
                              child: const Text('Torna ad adesso'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (view.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (view.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: EmptyPanel(
                    title: 'Riproviamo?',
                    message: view.error!,
                    action: FilledButton(
                      onPressed: view.refresh,
                      child: const Text('Riprova'),
                    ),
                  ),
                ),
              )
            else ...[
              if (view.nearby.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: EmptyPanel(
                      icon: Icons.schedule_rounded,
                      title: 'Nessun arrivo a breve',
                      message: view.later.isEmpty
                          ? 'Non risultano corse programmate nelle prossime 24 ore. Controlla il calendario AMTS nelle impostazioni.'
                          : 'Non ci sono passaggi previsti nei prossimi 90 minuti. Trovi le corse successive qui sotto.',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverList.builder(
                  itemCount: view.nearby.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ArrivalTile(
                      view.nearby[i],
                      reference: view.reference,
                      prominent: i == 0,
                    ),
                  ),
                ),
              ),
              if (view.later.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                    child: SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        title: const Text(
                          'Orari successivi',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${view.later.length} corse · ${arrivalWait(view.later.first.time, view.reference)}',
                        ),
                        children: [
                          for (final arrival in view.later)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              child: ArrivalTile(
                                arrival,
                                reference: view.reference,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Orari: AMTS · Previsioni: BusOne (busone.app) e fonte AMTS.\nGli orari programmati non confermano il passaggio effettivo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RealtimePanel extends StatelessWidget {
  const RealtimePanel(this.view, {required this.onEnable, super.key});
  final ArrivalsController view;
  final VoidCallback onEnable;
  @override
  Widget build(BuildContext context) {
    final live = view.status == ArrivalsStatus.live;
    final title = switch (view.status) {
      ArrivalsStatus.live => 'Previsioni in tempo reale',
      ArrivalsStatus.checking => 'Cerco le previsioni…',
      ArrivalsStatus.off => 'Vuoi gli arrivi in tempo reale?',
      ArrivalsStatus.noCoverage => 'Nessuna previsione a breve',
      ArrivalsStatus.unavailable => 'Solo orari programmati',
      ArrivalsStatus.selectedDate => 'Stai consultando il programma',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: BusDesign.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: live ? BusDesign.lime : const Color(0xff2c4657),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  live ? Icons.sensors_rounded : Icons.schedule_rounded,
                  color: live ? BusDesign.ink : const Color(0xffd6e8e6),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
              if (view.status == ArrivalsStatus.checking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BusDesign.lime,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            view.message,
            style: const TextStyle(
              color: Color(0xffb9cdd1),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (view.feedStamp != null) ...[
            const SizedBox(height: 9),
            Text(
              'Feed BusOne delle ${clockTime(view.feedStamp!)}',
              style: const TextStyle(color: Color(0xff99b6be), fontSize: 11),
            ),
          ],
          if (view.status == ArrivalsStatus.off) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BusDesign.lime,
                foregroundColor: BusDesign.ink,
              ),
              onPressed: onEnable,
              icon: const Icon(Icons.sensors_rounded),
              label: const Text('Attiva il tempo reale'),
            ),
          ],
        ],
      ),
    );
  }
}

class ArrivalTile extends StatelessWidget {
  const ArrivalTile(
    this.arrival, {
    required this.reference,
    this.prominent = false,
    super.key,
  });
  final Arrival arrival;
  final DateTime reference;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shortWait =
        arrival.time.difference(reference) <= const Duration(minutes: 90);
    final minutes = (arrival.time.difference(reference).inSeconds / 60).ceil();
    final liveColor = arrival.isApproximate
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xffffd37b)
              : const Color(0xff8b5a0b))
        : Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff9ce0b8)
        : BusDesign.teal;
    return SurfaceCard(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: prominent
                      ? BusDesign.lime
                      : colors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  arrival.route,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: prominent ? BusDesign.ink : colors.onSurface,
                  ),
                ),
              ),
              Text(
                arrival.destination,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              if (shortWait)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      minutes <= 0
                          ? 'Ora'
                          : '${arrival.isApproximate ? '~' : ''}$minutes',
                      style: TextStyle(
                        fontSize: prominent ? 52 : 38,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -1.8,
                        color: colors.onSurface,
                      ),
                    ),
                    if (minutes > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 4),
                        child: Text(
                          'min',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                )
              else
                Text(
                  clockTime(arrival.time),
                  style: TextStyle(
                    fontSize: 33,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: colors.onSurface,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arrivalWait(arrival.time, reference),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        arrival.isRealtime
                            ? Icons.sensors_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: arrival.isRealtime
                            ? liveColor
                            : colors.onSurfaceVariant,
                      ),
                      Text(
                        arrival.isApproximate
                            ? 'Stima BusOne'
                            : arrival.isRealtime
                            ? 'Tempo reale'
                            : 'Programmato',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: arrival.isRealtime
                              ? liveColor
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (shortWait)
                Text(
                  clockTime(arrival.time),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (arrival.isApproximate) ...[
            const SizedBox(height: 12),
            SmallPill(
              'Margine del fornitore ±${((arrival.uncertaintySeconds ?? 0) / 60).ceil()} min',
              color: liveColor,
              background: liveColor.withValues(alpha: .08),
            ),
          ],
          if (arrival.isRealtime) ...[
            const SizedBox(height: 14),
            Text(
              'Orario AMTS ${clockTime(arrival.scheduled)} · aggiornato da BusOne',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
