import 'package:flutter/material.dart';
import 'design.dart';

class InitialDownload extends StatefulWidget {
  const InitialDownload({required this.busy, required this.progress, required this.onRetry, required this.onContinue, this.fraction, this.error, super.key});
  final bool busy;
  final String progress;
  final double? fraction;
  final String? error;
  final VoidCallback onRetry, onContinue;
  @override
  State<InitialDownload> createState() => _InitialDownloadState();
}

class _InitialDownloadState extends State<InitialDownload> with SingleTickerProviderStateMixin {
  late final animation = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  void updateAnimation() {
    if (widget.busy && !MediaQuery.disableAnimationsOf(context)) {
      animation.repeat(reverse: true);
    } else {
      animation.stop();
    }
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); updateAnimation(); }
  @override
  void didUpdateWidget(covariant InitialDownload oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.busy != widget.busy) updateAnimation(); }
  @override
  void dispose() { animation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SmallPill('SI PARTE DA CATANIA', icon: Icons.location_on_outlined),
      const SizedBox(height: 26),
      Text('Prepariamo\ni tuoi viaggi.', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 14),
      Text('Scarichiamo fermate, linee e orari AMTS. Poi li avrai sempre con te, anche senza connessione.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
      const SizedBox(height: 32),
      LayoutBuilder(builder: (context, constraints) => SizedBox(height: 78, child: Stack(alignment: Alignment.centerLeft, children: [
        Container(height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(3))),
        Align(alignment: Alignment.centerLeft, child: Icon(Icons.trip_origin_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Align(alignment: Alignment.centerRight, child: Icon(Icons.location_on_rounded, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        AnimatedBuilder(animation: animation, builder: (context, _) => Transform.translate(offset: Offset((constraints.maxWidth - 56) * Curves.easeInOut.transform(animation.value), 0), child: Container(key: const Key('download-bus'), width: 56, height: 56, decoration: BoxDecoration(color: BusDesign.lime, borderRadius: BorderRadius.circular(18)), child: Icon(widget.error == null ? Icons.directions_bus_rounded : Icons.cloud_off_rounded, color: BusDesign.ink, size: 30)))),
      ]))),
      const SizedBox(height: 22),
      if (widget.busy) ...[
        LinearProgressIndicator(value: widget.fraction, minHeight: 5, borderRadius: BorderRadius.circular(5)),
        const SizedBox(height: 14),
        Text(widget.progress, textAlign: TextAlign.center),
        if (widget.fraction != null) Text('${(widget.fraction! * 100).round()}%', textAlign: TextAlign.center),
      ] else ...[
        if (widget.error != null) Text(widget.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: widget.onRetry, icon: const Icon(Icons.download_rounded), label: Text(widget.error == null ? 'Scarica gli orari' : 'Riprova il download')),
      ],
      const SizedBox(height: 16),
      TextButton(onPressed: widget.onContinue, child: const Text('Continua intanto nell’app')),
    ],
  )));
}
