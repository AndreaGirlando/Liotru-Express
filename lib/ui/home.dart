import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_state.dart';
import '../domain/gtfs_time.dart';
import '../domain/models.dart';
import 'settings.dart';
import 'stop_detail.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(this.state,{super.key});
  final AppState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('CataniaBus 🚌')),
    body:switch(index) {
      0 => StopList(widget.state,favorites:true,onSearch:()=>setState(()=>index=1)),
      1 => StopList(widget.state,favorites:false),
      _ => SettingsScreen(widget.state),
    },
    bottomNavigationBar:NavigationBar(selectedIndex:index,
      onDestinationSelected:(value)=>setState(()=>index=value),destinations:const [
        NavigationDestination(icon:Icon(Icons.star_outline),selectedIcon:Icon(Icons.star),label:'Preferiti'),
        NavigationDestination(icon:Icon(Icons.search),label:'Fermate'),
        NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Impostazioni'),
      ]),
  );
}

class StopList extends StatefulWidget {
  const StopList(this.state,{required this.favorites,this.onSearch,super.key});
  final AppState state;
  final bool favorites;
  final VoidCallback? onSearch;
  @override
  State<StopList> createState()=>_StopListState();
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
    if(oldWidget.favorites != widget.favorites) { controller.clear(); search(); }
  }
  void changed() { if(!widget.state.importing) search(); }
  Future<void> search() async {
    final token = ++generation;
    setState(()=>loading=true);
    try {
      final result = await widget.state.database.search(controller.text.trim(),
        ids:widget.favorites ? widget.state.preferences.favorites : null);
      if(mounted && token == generation) setState(() {stops=result;loading=false;error=null;});
    } catch (_) {
      if(mounted && token == generation) setState(() {loading=false;error='Ricerca non riuscita. Riprova.';});
    }
  }
  @override
  void dispose() { widget.state.removeListener(changed); debounce?.cancel(); controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final info = widget.state.feed;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,8,16,12),child:TextField(
        controller:controller,onChanged:(_) {debounce?.cancel();debounce=Timer(const Duration(milliseconds:250),search);},
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
          hintText:'Cerca nome o codice fermata',border:const OutlineInputBorder(),
          suffixIcon:IconButton(tooltip:'Cancella ricerca',icon:const Icon(Icons.clear),onPressed:(){controller.clear();search();})),
      )),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:4),child:Text(
        widget.favorites ? 'Le tue fermate' : 'Fermate AMTS',style:Theme.of(context).textTheme.titleLarge)),
      if(info != null) Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:4),
        child:Text('GTFS importato il ${displayDate(info.importedAt)} • ${info.stops} fermate',
          style:Theme.of(context).textTheme.bodySmall)),
      if(info != null && info.endDate.isNotEmpty && info.endDate.compareTo(serviceDate(tz.TZDateTime.from(DateTime.now(),rome))) < 0)
        const Padding(padding:EdgeInsets.all(16),child:Text('Il calendario GTFS è scaduto. Aggiorna i dati nelle impostazioni.')),
      Expanded(child:loading ? const Center(child:CircularProgressIndicator()) : error != null
        ? Center(child:TextButton(onPressed:search,child:Text(error!)))
        : stops.isEmpty ? Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            Icon(info == null ? Icons.download_outlined : Icons.directions_bus_outlined,size:56),
            const SizedBox(height:16),Text(info == null
              ? 'Importa un archivio GTFS AMTS dalle impostazioni per iniziare.'
              : widget.favorites && controller.text.isEmpty
                ? 'Salva le fermate con la stella: le ritroverai qui.' : 'Nessuna fermata trovata.',textAlign:TextAlign.center),
            if(widget.favorites && info != null) TextButton(onPressed:widget.onSearch,child:const Text('Cerca una fermata')),
          ],
        ))) : ListView.separated(itemCount:stops.length,separatorBuilder:(_,_)=>const Divider(height:1),
          itemBuilder:(context,i) { final stop=stops[i];final favorite=widget.state.preferences.favorites.contains(stop.id);
            return ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:20,vertical:8),
              leading:const Icon(Icons.directions_bus),title:Text(stop.name),
              subtitle:Text('${stop.code.isEmpty ? stop.id : stop.code}${stop.routes.isEmpty ? '' : '\nLinee ${stop.routes}'}'),
              trailing:IconButton(tooltip:favorite ? 'Rimuovi dai preferiti' : 'Salva nei preferiti',
                onPressed:()=>widget.state.toggle(stop.id),icon:Icon(favorite ? Icons.star : Icons.star_outline)),
              onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>StopDetail(widget.state,stop))));
          })),
    ]);
  }
}

String displayDate(DateTime date) {
  final d = tz.TZDateTime.from(date,rome);
  return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${clockTime(date)}';
}
