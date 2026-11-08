# CataniaBus 🚌

App Android personale in Flutter, indipendente da AMTS: fermate, preferiti,
orari GTFS offline e TripUpdates JSON opzionali. Nessun account, server, Firebase
o servizio a pagamento. Tutta l’interfaccia è in italiano, con tema chiaro/scuro.

## Stato dei dati

Le fonti AMTS e BusOne sono bloccate dal proxy dell’ambiente di sviluppo.
**Non sono disponibili dati AMTS precaricati o un endpoint realtime verificato.**
L’app si avvia senza dati e permette l’importazione di uno ZIP GTFS reale.
Consulta [la verifica delle fonti](docs/FONTI_DATI.md) e l’artefatto
`verifica-fonti` prodotto dal workflow nella scheda Actions della repository.

## Aprire e compilare il progetto

1. Installa [Flutter](https://docs.flutter.dev/get-started/install) stabile
   **3.35.7**, la versione usata dalla CI (include Dart 3.9).
2. Installa [Android Studio](https://developer.android.com/studio), Android SDK
   Platform 36, i command-line tools e Java 17. Da SDK Manager installa anche
   NDK 27.0.12077973 se richiesto da Flutter.
3. Clona questa repository, apri la cartella in Android Studio o VS Code e avvia
   un terminale nella cartella che contiene `pubspec.yaml`.
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

1. Apri [Open Data AMTS](https://www.amts.ct.it/open-data) nel browser.
2. Scarica l’archivio **GTFS ZIP**, senza estrarlo, sul telefono.
3. In CataniaBus apri **Impostazioni → Importa ZIP dal telefono** e scegli il file.
4. Apri **Fermate**, cerca nome/codice e tocca una fermata per vedere gli arrivi.
5. Usa la stella per aggiungerla ai **Preferiti**.

Se trovi un link diretto HTTPS funzionante allo ZIP, puoi salvarlo nelle
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

## Attivare il tempo reale

Consulta prima [BusOne](https://proxy.busone.app/amts/): accesso, condizioni
d’uso, eventuali chiavi e frequenza ammessa devono essere verificati.
Il possibile endpoint indicato nel requisito non è assunto come valido.
Inserisci un URL HTTPS che restituisca GTFS-Realtime **TripUpdates JSON completo**,
attiva il servizio e salva. Servizi che richiedono chiavi API non sono supportati
da questa versione. Non inserire credenziali nell’URL.

L’app usa `trip_id`, data/ora iniziale, `stop_sequence` e `stop_id` per collegare
le previsioni. Usa timestamp o ritardi dichiarati, cancella le corse annullate,
nasconde fermate saltate e interrompe la propagazione a `NO_DATA`.
Senza data del servizio non applica aggiornamenti ambigui tra giorni diversi.
Non ricava previsioni dal GPS. Un timestamp più vecchio di 3 minuti o oltre
30 secondi nel futuro viene scartato. Gli errori mostrano gli orari programmati.

**Tempo reale** è verde; **Programmato** è grigio. Il polling si ferma uscendo
dalla schermata o mettendo l’app in pausa. Anche il pulsante Aggiorna rispetta
il limite di una richiesta al minuto. Se il fornitore richiede intervalli più
lunghi, lascia il servizio spento. L’app non garantisce ritardi oltre tre ore
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
| Verifica fonti e build Android | `tool/verify_sources.py`, `.github/workflows/android.yml` |

I test sotto `test/` usano esclusivamente dati **sintetici**, mai presentati
all’utente come dati AMTS. Coprono ZIP, rollback, ricerca, festività, date di
servizio, cambio ora, oltre mezzanotte, TripUpdates, errori rete e preferiti.
