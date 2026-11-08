import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/preferences.dart';
import 'design.dart';
import 'home.dart';
import 'app_chrome.dart';
import 'metro_info.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: const AppTopBar(section: 'Impostazioni', showBack: true), body: SafeArea(top: false, child: SettingsScreen(state)));
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen(this.state, {super.key});
  final AppState state;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final staticUrl = TextEditingController(
    text: widget.state.preferences.staticUrl,
  );
  late final rtUrl = TextEditingController(
    text: widget.state.preferences.realtimeUrl,
  );
  String? error;
  bool savingRealtime = false;
  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => error = null);
    try {
      await action();
    } catch (e) {
      final detail = switch (e) {
        FormatException() => e.message.toString(),
        HttpException() => e.message,
        TimeoutException() => 'Il server non ha risposto in tempo. Riprova.',
        HandshakeException() =>
          'Connessione sicura al server non riuscita. Puoi scaricare lo ZIP dal browser e importarlo dal telefono.',
        SocketException() =>
          'Impossibile raggiungere il server. Controlla la connessione e riprova.',
        FileSystemException() =>
          'Impossibile leggere o salvare l’archivio. Controlla lo spazio libero sul telefono.',
        _ =>
          'Aggiornamento non riuscito. Riprova o importa uno ZIP dal telefono.',
      };
      if (mounted) setState(() => error = detail);
      message(detail);
    }
  }

  Future<void> toggleRealtime(bool value) async {
    setState(() => savingRealtime = true);
    try {
      await run(() => widget.state.setRealtimeEnabled(value));
    } finally {
      if (mounted) setState(() => savingRealtime = false);
    }
  }

  @override
  void dispose() {
    staticUrl.dispose();
    rtUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final busy = widget.state.importing;
      final info = widget.state.feed;
      final colors = Theme.of(context).colorScheme;
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        children: [
          Text('Dati e preferenze', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text('Orari aggiornati, previsioni e un’app come piace a te.', style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 24),
          SurfaceCard(
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
                      child: const Icon(
                        Icons.sensors_rounded,
                        color: BusDesign.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tempo reale',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Switch(
                      value: widget.state.preferences.realtimeEnabled,
                      onChanged: busy || savingRealtime ? null : toggleRealtime,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.state.preferences.realtimeEnabled
                      ? 'Attivo. Le previsioni BusOne vengono cercate quando apri una fermata.'
                      : 'Disattivato. Vedrai gli orari ufficiali programmati da AMTS.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Se non c’è una previsione aggiornata per la tua fermata, l’app lo indica chiaramente.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.download_for_offline_outlined,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Orari sempre con te',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Fermate e orari AMTS si scaricano al primo avvio e si aggiornano automaticamente alla scadenza, senza interrompere l’uso dell’app.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SmallPill(
                        '${info.stops} fermate',
                        icon: Icons.directions_bus_outlined,
                      ),
                      const SmallPill(
                        'Disponibili offline',
                        icon: Icons.offline_pin_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aggiornati il ${displayDate(info.importedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await widget.state.downloadGtfs(staticUrl.text);
                          message('Dati GTFS aggiornati.');
                        }),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    busy
                        ? 'Aggiornamento in corso…'
                        : 'Scarica e aggiorna dati',
                  ),
                ),
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['zip'],
                            withData: false,
                          );
                          if (result == null) return;
                          final path = result.files.single.path;
                          if (path == null) {
                            throw const FormatException(
                              'File non accessibile: salvalo sul telefono e riprova',
                            );
                          }
                          await widget.state.import(localPath: path);
                          message(
                            'Dati GTFS importati. Orari disponibili offline.',
                          );
                        }),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Importa ZIP dal telefono'),
                ),
                if (busy && !(widget.state.automaticUpdating && info != null)) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(minHeight: 6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.state.progress,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SelectableText(
                  '$error\nGli eventuali dati già importati restano disponibili.',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Il tuo stile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: widget.state.preferences.theme,
                  decoration: const InputDecoration(labelText: 'Aspetto'),
                  items: const [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text('Tema del telefono'),
                    ),
                    DropdownMenuItem(value: 'light', child: Text('Chiaro')),
                    DropdownMenuItem(value: 'dark', child: Text('Scuro')),
                  ],
                  onChanged: (value) {
                    if (value != null) widget.state.setTheme(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const MetroInfoPanel(),
          const SizedBox(height: 18),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: const Icon(Icons.link_rounded),
              title: const Text(
                'Fonti dati',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Collegamenti e configurazione avanzata',
                style: TextStyle(fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: staticUrl,
                        enabled: !busy,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'URL HTTPS dello ZIP GTFS',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => staticUrl.text =
                                      UserPreferences.officialGtfsUrl,
                                ),
                          child: const Text('Ripristina link AMTS'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: rtUrl,
                        enabled: !busy,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'URL HTTPS TripUpdates JSON',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                await widget.state.sources(
                                  staticUrl.text,
                                  rtUrl.text,
                                  widget.state.preferences.realtimeEnabled,
                                );
                                message('Preferenze salvate.');
                              }),
                        child: const Text('Salva fonti dati'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Il servizio BusOne è gratuito per uso personale. Le richieste includono CataniaBus e il profilo GitHub AndreaGirlando come contatto pubblico.',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text(
                'Informazioni e attribuzioni',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    'Orari e fermate: AMTS – Azienda Metropolitana Trasporti e Sosta Catania S.p.A., licenza IODL 2.0.\nwww.amts.ct.it/open-data\n\nPrevisioni: BusOne (https://busone.app) e fonte originale AMTS.\nCondizioni: https://proxy.busone.app/amts/\n\nCataniaBus è un’app personale indipendente. Nessun account, pubblicità o rilevamento della posizione.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Fatto per muoversi a Catania.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      );
    },
  );
}
