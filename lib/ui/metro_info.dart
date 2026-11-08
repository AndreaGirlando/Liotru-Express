import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/metro_timetable.dart';
import '../domain/metro.dart';
import '../domain/gtfs_time.dart';
import 'design.dart';

class MetroInfoPanel extends StatelessWidget {
  const MetroInfoPanel({super.key});
  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      leading: const Icon(Icons.subway_outlined),
      title: const Text(
        'Come funzionano le stime Metro',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Fonti, aggiornamento e limiti',
        style: TextStyle(fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: const [MetroSourceDetails()],
    ),
  );
}

class MetroSourceDetails extends StatefulWidget {
  const MetroSourceDetails({super.key});
  @override
  State<MetroSourceDetails> createState() => _MetroSourceDetailsState();
}

class _MetroSourceDetailsState extends State<MetroSourceDetails> {
  late final future = loadMetroTimetable();
  @override
  Widget build(BuildContext context) => FutureBuilder<MetroTimetable>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Text(
          'I passaggi Metro sono stime da orario, non posizioni live dei treni. Ritardi e soppressioni non vengono rilevati.',
        );
      }
      final data = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Le partenze seguono il quadro orario FCE pubblicato il ${metroDate(data.published)}, verificato il ${metroDate(data.checked)}. Alle stazioni intermedie aggiungiamo le durate pubblicate nel GTFS FCE: il suo calendario termina il ${metroDate(parseServiceDate(data.offsetsValidUntil))}, quindi questi tempi storici possono essere imprecisi.',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Il conto alla rovescia usa l’orologio del telefono e si aggiorna ogni secondo. Non rappresenta la posizione effettiva dei treni: ritardi, soppressioni e modifiche straordinarie non vengono rilevati.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Sono distinti giorni feriali, venerdì, sabato, domenica e festività nazionali. Eventi e festività locali richiedono la verifica degli avvisi FCE. Gli orari Metro inclusi si aggiornano con una nuova versione dell’app.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Fonte: Ferrovia Circumetnea. App indipendente da FCE e FCE Quando.',
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data.sourceUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link dell’orario FCE copiato.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copia link orario ufficiale FCE'),
          ),
        ],
      );
    },
  );
}
