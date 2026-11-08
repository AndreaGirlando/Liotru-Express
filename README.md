# CataniaBus 🚌

App Android personale in Flutter, indipendente da AMTS: fermate, preferiti,
orari GTFS offline e TripUpdates JSON opzionali. Nessun account, server, Firebase
o servizio a pagamento. Tutta l’interfaccia è in italiano, con tema chiaro/scuro.

## Stato dei dati

Le fonti sono state verificate dalla rete GitHub Actions l’8 novembre 2026:
[GTFS ufficiale AMTS](https://www.amts.ct.it/GTFS/AMTCT.zip) e
[TripUpdates BusOne](https://proxy.busone.app/amts/gtfs-rt/trip-updates.json)
rispondono HTTP 200. Gli URL sono già compilati nelle impostazioni.
L’app si avvia senza dati: apri **Impostazioni → Scarica e aggiorna dati**.
Nella versione 2.0 il tempo reale è attivo per impostazione predefinita; il
selettore nelle impostazioni salva immediatamente la scelta. Gli utenti che
lo avevano disattivato mantengono la propria preferenza.
Consulta [la verifica delle fonti e le condizioni](docs/FONTI_DATI.md) e l’artefatto
`verifica-fonti` prodotto dal workflow nella scheda Actions della repository.

## Aprire e compilare il progetto

1. Installa [Flutter](https://docs.flutter.dev/get-started/install) stabile
   **3.35.7**, la versione usata dalla CI (include Dart 3.9).
2. Installa [Android Studio](https://developer.android.com/studio), Android SDK
   Platform 36, i command-line tools e Java 17. Da SDK Manager installa anche
   NDK 27.0.12077973 se richiesto da Flutter.
3. Clona questa repository, apri la cartella in Android Studio o VS Code e avvia
   un terminale nella cartella che contiene `pubspec.yaml`.
   Per la versione 2.1, finché la relativa pull request non è unita a `main`,
   seleziona `codex/search-bus` (`git switch codex/search-bus`).
4. Esegui:

```sh
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

L’APK universale è `build/app/outputs/flutter-apk/app-release.apk` e richiede
Android 7.0 / API 24 o successivo. Per avviare su telefono con debug USB:

```sh
flutter devices
flutter run
```

Su Linux i test SQLite richiedono la libreria di sistema `libsqlite3-0`.
Il wrapper Gradle è incluso; Flutter genera `android/local.properties` localmente.

## Ottenere l’APK da GitHub

Apri **Actions → Verifica e APK Android → esecuzione riuscita → Artifacts →
CataniaBus-APK**. Estrai lo ZIP scaricato: contiene `app-release.apk`.
Il workflow esegue prima analisi e test: l’artefatto APK viene caricato solo
se la compilazione termina correttamente. Gli artefatti scadono dopo 30 giorni;
puoi ricompilare dal PC o avviare nuovamente il workflow dopo il merge su main.

La build personale usa la chiave debug generata dall’SDK, anche in release.
Non è una firma per il Play Store. Runner nuovi possono usare chiavi diverse:
in tal caso per installare un nuovo APK occorre disinstallare prima il precedente,
perdendo database e preferiti. Per aggiornamenti quotidiani conviene compilare
sullo stesso PC, conservando la stessa chiave Android debug, oppure configurare
una propria firma release. Non aggiungere chiavi o password alla repository.

## Installare sul telefono

Trasferisci l’APK sul telefono via USB o tramite un tuo spazio file, aprilo
dall’app File e autorizza temporaneamente **Installa app sconosciute** per
quell’app quando Android lo richiede. Conferma l’installazione di CataniaBus.
In alternativa, con Android Platform Tools e debug USB:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Importare e aggiornare gli orari AMTS

La versione 1.0.1 corregge il blocco dell’importazione dal pulsante di download.
Gli errori restano visibili nella pagina e il download GTFS non dipende dalla
validità delle impostazioni del tempo reale.

1. In CataniaBus apri **Impostazioni → Scarica e aggiorna dati**: il link ufficiale è già inserito.
2. Se il download fallisce, apri [Open Data AMTS](https://www.amts.ct.it/open-data)
   nel browser e scarica l’archivio **GTFS ZIP**, senza estrarlo, sul telefono.
3. Usa **Impostazioni → Importa ZIP dal telefono** per importarlo manualmente.
4. Apri **Fermate**, cerca nome/codice e tocca una fermata per vedere gli arrivi.
5. Usa la stella per aggiungerla ai **Preferiti**.

Se AMTS cambia il link diretto HTTPS allo ZIP, puoi aggiornarlo nelle
impostazioni e usare **Scarica e aggiorna dati**. Non usare l’URL della pagina
HTML come se fosse l’archivio. L’importazione è manuale: nessun download in
background. Un aggiornamento non valido lascia intatti gli ultimi dati.

L’importatore richiede `agency.txt`, `stops.txt`, `routes.txt`, `trips.txt`,
`stop_times.txt` e almeno uno tra `calendar.txt` e `calendar_dates.txt`.
Supporta CSV UTF-8/BOM, campi quotati, LF/CRLF e file in sottocartelle dello ZIP.
Ignora shapes e altri file non necessari. Limiti: ZIP 100 MB, dati utili estratti
600 MB totali / 400 MB per file, orari fino a sette giorni dal giorno di servizio.
Feed a frequenza non supportati vengono rifiutati con un messaggio esplicito.

La ricerca e gli orari funzionano senza connessione dopo l’importazione.
I calendari sono valutati in `Europe/Rome`, con eccezioni incluse e orari
oltre 24:00 associati al giorno di servizio corretto. **Data e ora** permette
di consultare un altro momento (solo programmato). Gli arrivi coprono le
successive 24 ore; non vengono interpolate fermate senza orario pubblicato.
La vista principale mette in evidenza i prossimi 90 minuti. Le corse più
lontane sono raccolte in **Orari successivi**, con indicazioni come
**Domani 06:30**, anziché contatori di centinaia di minuti.

## Ricerca per autobus (2.1)

Apri la nuova scheda **Autobus** e cerca il numero o il nome della linea,
per esempio **156**, **BRT1** o **Metro Shuttle**. Aprendo una linea trovi:

- **Andata / Ritorno**, con partenza e destinazione esplicite;
- tutte le fermate in ordine per il verso scelto;
- eventuali varianti pubblicate nella stessa direzione;
- accesso agli arrivi e ai preferiti toccando una fermata.

I percorsi sono letti dal GTFS scaricato e funzionano offline. Non indicano
che la linea sia in servizio adesso: date e arrivi si consultano nelle fermate.
Le fermate ripetute di una circolare restano nell’elenco, così come quelle
senza un orario intermedio. Le corse con identica direzione e identica sequenza
di fermate vengono raggruppate; fermate diverse con lo stesso nome rimangono
distinte. I giorni di servizio non vengono usati per cancellare un percorso
dalla consultazione delle linee.

Lo schema SQLite 2 aggiunge `trips.direction_id` conservando i dati precedenti.
Per i database importati con la 2.0, aggiorna il GTFS per caricare le direzioni.
Se il fornitore omette `direction_id`, l’app distingue le varianti per percorso
e destinazione, senza inventare Andata e Ritorno. I valori GTFS 0 e 1 sono
presentati come Andata e Ritorno; il verso geografico è chiarito dai capolinea.

## Attivare il tempo reale

L’endpoint [BusOne](https://proxy.busone.app/amts/) verificato è già inserito:
il selettore **Tempo reale** si salva immediatamente. Le condizioni lette consentono l’uso personale
gratuito con attribuzione; non serve una chiave API. L’app invia gli header
richiesti `X-BusOne-Use: personal` e `X-BusOne-Client` con nome dell’app e
profilo GitHub pubblico del proprietario come contatto. Per un fork cambia
`UserPreferences.clientIdentity`. Le attribuzioni AMTS e BusOne sono nelle
impostazioni e nel dettaglio arrivi.

Puoi configurare un altro endpoint HTTPS GTFS-Realtime **TripUpdates JSON completo**.
Servizi che richiedono chiavi API non sono supportati. Non inserire credenziali nell’URL.

L’app usa `trip_id`, data/ora iniziale, `stop_sequence` e `stop_id` per collegare
le previsioni. Usa timestamp o ritardi dichiarati, cancella le corse annullate,
nasconde fermate saltate e interrompe la propagazione a `NO_DATA`.
Senza data del servizio non applica aggiornamenti ambigui tra giorni diversi.
Non ricava previsioni dal GPS. Un timestamp più vecchio di 3 minuti o oltre
30 secondi nel futuro viene scartato. Anche il timestamp individuale della corsa
viene controllato. Le stime con incertezza fra 2 e 15 minuti vengono mostrate
come **Stima BusOne**, con `~` e margine esplicito del fornitore; non sono orari
certi. Incertezze oltre 15 minuti o negative vengono scartate. Previsioni oltre
tre ore dal momento attuale o distanti oltre tre ore dal programma della corsa
non vengono presentate come aggiornate. Gli errori mostrano gli orari programmati.

**Tempo reale** è verde, **Stima BusOne** è ambra e **Programmato** è grigio.
Il pannello distingue una fonte non raggiungibile dall’assenza di previsioni
applicabili alla fermata: una risposta HTTP 200 non equivale a copertura live.
Gli orari SQLite vengono mostrati subito, anche mentre la rete risponde.
Il polling si ferma uscendo
dalla schermata o mettendo l’app in pausa. Anche il pulsante Aggiorna rispetta
il limite di una richiesta al minuto e gli header HTTP Retry-After. L’app non garantisce ritardi oltre tre ore
rispetto all’orario programmato.

## Codice, test e tracciabilità

| Responsabilità | File |
| --- | --- |
| Schema SQLite, ricerca, calendari e query arrivi | `lib/data/database.dart` |
| Importazione transazionale e CSV | `lib/data/gtfs_importer.dart` |
| Fuso orario, oltre mezzanotte e cambio ora | `lib/domain/gtfs_time.dart` |
| Associazione TripUpdates e cancellazioni | `lib/domain/realtime.dart` |
| Download, timeout e frequenza richieste | `lib/data/realtime_service.dart` |
| Preferiti, tema e fonti | `lib/data/preferences.dart` |
| Home, ricerca, dettaglio e impostazioni | `lib/ui/` |
| Ricerca linee, direzioni e fermate del percorso | `lib/ui/routes.dart`, `lib/data/database.dart` |
| Vista arrivi, caricamento offline immediato e copertura realtime | `lib/ui/arrivals_controller.dart` |
| Giorno/ora e contatori limitati agli arrivi vicini | `lib/domain/arrival_display.dart` |
| Verifica fonti e build Android | `tool/verify_sources.py`, `.github/workflows/android.yml` |

I test sotto `test/` usano esclusivamente dati **sintetici**, mai presentati
all’utente come dati AMTS. Coprono ZIP, rollback, ricerca, festività, date di
servizio, cambio ora, oltre mezzanotte, TripUpdates, errori rete e preferiti.
La verifica separata `test/official_feed_check.dart`, invocata esplicitamente
in CI, importa invece lo ZIP ufficiale appena scaricato e verifica un arrivo
pubblicato. Questo file non è incluso nella raccolta automatica dei test sintetici.

La CI confronta anche il feed TripUpdates catturato con il GTFS originale e
con il controller effettivo della schermata (`test/realtime_live_check.dart`).
L’artefatto `anteprime-interfaccia` contiene rendering Flutter chiaro/scuro con
fermate e previsioni del campione reale, non schermate da un telefono fisico.
Il carattere Manrope è incluso nell’APK con licenza OFL, senza download di font.
