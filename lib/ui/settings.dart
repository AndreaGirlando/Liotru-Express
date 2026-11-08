import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'home.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen(this.state,{super.key});
  final AppState state;
  @override
  State<SettingsScreen> createState()=>_SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  late final staticUrl = TextEditingController(text:widget.state.preferences.staticUrl);
  late final rtUrl = TextEditingController(text:widget.state.preferences.realtimeUrl);
  late bool enabled = widget.state.preferences.realtimeEnabled;
  void message(String text) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text))); }
  Future<void> save() async {
    await widget.state.sources(staticUrl.text,rtUrl.text,enabled);
  }
  Future<void> run(Future<void> Function() action) async {
    try { await action(); } catch(e) {
      message(e is FormatException ? e.message.toString() : 'Operazione non riuscita. Controlla il file o la connessione. I dati precedenti sono conservati.');
    }
  }
  @override
  void dispose() {staticUrl.dispose();rtUrl.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable:widget.state,builder:(context,_) {
    final busy=widget.state.importing;
    final info=widget.state.feed;
    return ListView(padding:const EdgeInsets.all(20),children:[
      Text('Impostazioni',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:16),
      DropdownButtonFormField<String>(initialValue:widget.state.preferences.theme,
        decoration:const InputDecoration(labelText:'Aspetto',border:OutlineInputBorder()),
        items:const [DropdownMenuItem(value:'system',child:Text('Tema del telefono')),
          DropdownMenuItem(value:'light',child:Text('Chiaro')),DropdownMenuItem(value:'dark',child:Text('Scuro'))],
        onChanged:(v) {if(v!=null) widget.state.setTheme(v);}),
      const SizedBox(height:24),Text('Dati degli autobus',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),
      const Text('Importa uno ZIP GTFS pubblicato da AMTS. La ricerca e gli orari resteranno disponibili offline. '
        'Il link diretto ufficiale non è stato verificato: nessun dato viene inventato o precaricato.'),
      const SizedBox(height:12),
      if(info!=null) Text('Ultima importazione: ${displayDate(info.importedAt)}\n${info.stops} fermate\nFonte: ${info.source}'),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:busy ? null : ()=>run(() async {
        final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['zip'],withData:false);
        if(result==null) return;
        final path=result.files.single.path;
        if(path==null) throw const FormatException('File non accessibile: salvalo sul telefono e riprova');
        await widget.state.import(localPath:path);
        message('Dati GTFS importati. Orari disponibili offline.');
      }),icon:const Icon(Icons.folder_open),label:const Text('Importa ZIP dal telefono')),
      const SizedBox(height:16),
      TextField(controller:staticUrl,enabled:!busy,keyboardType:TextInputType.url,
        decoration:const InputDecoration(labelText:'URL HTTPS dello ZIP GTFS',hintText:'Incolla il link diretto al file ZIP',border:OutlineInputBorder())),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:busy ? null : ()=>run(() async {await save();await widget.state.import();message('Dati GTFS aggiornati.');}),
        icon:const Icon(Icons.download),label:const Text('Scarica e aggiorna dati')),
      if(busy) ...[const SizedBox(height:12),const LinearProgressIndicator(),const SizedBox(height:8),Text(widget.state.progress)],
      const SizedBox(height:24),Text('Tempo reale opzionale',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),
      const Text('BusOne non è stato verificato in questo ambiente. Prima di attivarlo, verifica accesso, condizioni d’uso '
        'e intervallo minimo del fornitore. Sono supportati TripUpdates JSON GTFS-Realtime completi, senza chiave API. '
        'L’app effettua al massimo una richiesta al minuto, solo con gli arrivi aperti. '
        'Se il fornitore richiede intervalli maggiori, lascia il servizio disattivato.'),
      const SizedBox(height:12),
      TextField(controller:rtUrl,enabled:!busy,keyboardType:TextInputType.url,
        decoration:const InputDecoration(labelText:'URL HTTPS TripUpdates JSON',border:OutlineInputBorder())),
      SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,onChanged:busy ? null : (v)=>setState(()=>enabled=v),
        title:const Text('Attiva il tempo reale'),subtitle:const Text('Ho verificato le condizioni e la compatibilità del servizio')),
      FilledButton.tonal(onPressed:busy ? null : ()=>run(() async {await save();message('Preferenze salvate.');}),child:const Text('Salva fonti dati')),
      const SizedBox(height:24),
      const Text('Fonti da consultare:\nwww.amts.ct.it/open-data\nproxy.busone.app/amts/\n\n'
        'CataniaBus è un’app personale indipendente. Gli orari programmati non garantiscono il passaggio effettivo. '
        'Nessun account, pubblicità o rilevamento della posizione.'),
    ]);
  });
}
