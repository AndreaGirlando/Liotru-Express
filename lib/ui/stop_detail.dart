import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_state.dart';
import '../domain/gtfs_time.dart';
import '../domain/models.dart';

class StopDetail extends StatefulWidget {
  const StopDetail(this.state,this.stop,{super.key});
  final AppState state;
  final BusStop stop;
  @override
  State<StopDetail> createState()=>_StopDetailState();
}
class _StopDetailState extends State<StopDetail> with WidgetsBindingObserver {
  Timer? timer;
  bool active=true, loading=true, refreshing=false;
  List<Arrival> arrivals=[];
  DateTime? updated, feedStamp, selected;
  String status='Orari programmati';
  String? error;
  @override
  void initState() {
    super.initState();WidgetsBinding.instance.addObserver(this);
    refresh();startTimer();
  }
  void startTimer() {
    timer?.cancel();
    timer=Timer.periodic(const Duration(seconds:30),(_) {
      if(active && (ModalRoute.of(context)?.isCurrent ?? false) && selected==null) refresh();
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active=state==AppLifecycleState.resumed;
    if(active) {refresh();startTimer();} else {timer?.cancel();}
  }
  Future<void> refresh() async {
    if(refreshing) return;
    refreshing=true;
    final requested=selected;
    if(mounted) setState(()=>loading=arrivals.isEmpty);
    try {
      final now=DateTime.now();
      final from=requested ?? now;
      // Include recently departed scheduled trips so a delayed bus is retained.
      final scheduled=await widget.state.database.arrivals(widget.stop.id,
        from.subtract(requested==null ? const Duration(hours:3) : Duration.zero),
        horizon:requested==null ? const Duration(hours:27) : const Duration(hours:24));
      List<Arrival> result=scheduled;
      String message='Orari programmati';
      DateTime? stamp;
      if(requested==null && widget.state.preferences.realtimeEnabled && active) {
        final response=await widget.state.realtime.fetch(widget.state.preferences.realtimeUrl,now);
        message=response.message;
        if(response.feed!=null) {result=response.feed!.apply(scheduled,DateTime.now());stamp=response.feed!.timestamp;}
      }
      result=result.where((a)=>!a.time.isBefore(from) && a.time.isBefore(from.add(const Duration(hours:24)))).toList();
      if(mounted && requested==selected) setState(() {arrivals=result;status=message;updated=DateTime.now();feedStamp=stamp;error=null;loading=false;});
    } catch(_) {
      if(mounted) setState(() {error='Impossibile leggere gli orari. Riprova.';arrivals=[];loading=false;});
    } finally {refreshing=false;}
    if(mounted && requested!=selected) refresh();
  }
  Future<void> selectDate() async {
    final now=tz.TZDateTime.from(DateTime.now(),rome);
    final date=await showDatePicker(context:context,initialDate:selected ?? now,
      firstDate:DateTime(now.year-1),lastDate:DateTime(now.year+2));
    if(date==null || !mounted) return;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(selected ?? now));
    if(time==null || !mounted) return;
    setState(()=>selected=tz.TZDateTime(rome,date.year,date.month,date.day,time.hour,time.minute));
    await refresh();
  }
  @override
  void dispose() {timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:Text(widget.stop.name),actions:[
      ListenableBuilder(listenable:widget.state,builder:(context,_) {
        final favorite=widget.state.preferences.favorites.contains(widget.stop.id);
        return IconButton(tooltip:favorite ? 'Rimuovi dai preferiti' : 'Salva nei preferiti',
          onPressed:()=>widget.state.toggle(widget.stop.id),icon:Icon(favorite ? Icons.star : Icons.star_outline));
      }),
    ]),
    body:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Fermata ${widget.stop.code.isEmpty ? widget.stop.id : widget.stop.code}',style:Theme.of(context).textTheme.titleMedium),
        if(widget.stop.routes.isNotEmpty) Text('Linee ${widget.stop.routes}'),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:[
          FilledButton.tonalIcon(onPressed:refreshing ? null : refresh,icon:const Icon(Icons.refresh),label:const Text('Aggiorna arrivi')),
          OutlinedButton.icon(onPressed:selectDate,icon:const Icon(Icons.event),label:const Text('Data e ora')),
          if(selected!=null) TextButton(onPressed:(){setState(()=>selected=null);refresh();},child:const Text('Torna ad adesso')),
        ]),
        if(selected!=null) Text('Orari dal ${selected!.day}/${selected!.month}/${selected!.year} alle ${clockTime(selected!)} • Europe/Rome'),
        const SizedBox(height:8),Text(status),
        if(widget.state.preferences.realtimeEnabled) Text('Previsioni: BusOne (busone.app) e fonte AMTS',style:Theme.of(context).textTheme.bodySmall),
        if(updated!=null) Text('Ultimo controllo: ${clockTime(updated!)}${feedStamp==null ? '' : ' • Feed realtime: ${clockTime(feedStamp!)}'}',style:Theme.of(context).textTheme.bodySmall),
      ])),
      Expanded(child:loading ? const Center(child:CircularProgressIndicator()) : error!=null
        ? Center(child:TextButton(onPressed:refresh,child:Text(error!)))
        : RefreshIndicator(onRefresh:refresh,child:ListView.builder(
          physics:const AlwaysScrollableScrollPhysics(),itemCount:arrivals.isEmpty ? 1 : arrivals.length,
          itemBuilder:(context,i) => arrivals.isEmpty ? const Padding(padding:EdgeInsets.all(24),child:Text(
            'Nessuna corsa programmata nelle prossime 24 ore. Verifica che il calendario GTFS sia aggiornato.'))
            : ArrivalTile(arrivals[i],reference:selected ?? DateTime.now()),
        ))),
    ]),
  );
}

class ArrivalTile extends StatelessWidget {
  const ArrivalTile(this.arrival,{required this.reference,super.key});
  final Arrival arrival;
  final DateTime reference;
  @override
  Widget build(BuildContext context) {
    final minutes=(arrival.time.difference(reference).inSeconds/60).ceil();
    final color=arrival.isRealtime ? (Theme.of(context).brightness==Brightness.dark ? Colors.greenAccent : Colors.green.shade800)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(margin:const EdgeInsets.symmetric(horizontal:16,vertical:6),child:Padding(
      padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
            decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(12)),
            child:Text(arrival.route,style:Theme.of(context).textTheme.titleLarge)),
          Text(arrival.destination,style:Theme.of(context).textTheme.titleMedium),
        ]),
        const SizedBox(height:12),
        Wrap(spacing:16,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          Text(clockTime(arrival.time),style:Theme.of(context).textTheme.headlineSmall),
          Text(minutes<=0 ? 'In arrivo' : 'tra $minutes min',style:Theme.of(context).textTheme.titleMedium),
          Text.rich(TextSpan(children:[WidgetSpan(child:Icon(Icons.circle,size:9,color:color)),
            TextSpan(text:arrival.isRealtime ? ' Tempo reale' : ' Programmato')]),style:TextStyle(color:color)),
        ]),
        if(arrival.isRealtime) Text('Programmato: ${clockTime(arrival.scheduled)}',style:Theme.of(context).textTheme.bodySmall),
      ]),
    ));
  }
}
