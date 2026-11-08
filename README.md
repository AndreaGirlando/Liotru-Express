# Liotru Express 🐘

App Android personale in Flutter, indipendente da AMTS: fermate, preferiti,
orari GTFS offline e TripUpdates JSON opzionali. Nessun account, server, Firebase
o servizio a pagamento. Tutta l’interfaccia è in italiano, con tema chiaro/scuro.

## Avvertenza e responsabilità

**Liotru Express è un progetto personale, sperimentale e non ufficiale,
interamente sviluppato con l’assistenza di strumenti di intelligenza artificiale
(«full vibecoded» / «full vibecodata»).** Il codice può contenere errori,
comportamenti imprevisti e vulnerabilità, anche in presenza di test automatici.
Non è un’app di AMTS, FCE o BusOne e non è approvata o garantita da tali soggetti.

L’app e il codice sono forniti **così come sono**, senza garanzie di correttezza,
completezza, disponibilità o idoneità a uno scopo particolare. Orari, attese e
previsioni sono indicativi: possono essere errati, scaduti o non disponibili.
La Metro mostra stime da orario, non la posizione dei treni né arrivi live.
Verifica sempre gli avvisi e gli orari degli operatori ufficiali prima di viaggiare.

**Nei limiti consentiti dalla legge, l’autore e gli eventuali contributori non
si assumono responsabilità per l’uso o l’impossibilità di usare l’app**, inclusi
errori negli orari, corse perse, ritardi, costi, perdita di dati o altri danni.
L’utente sceglie autonomamente come utilizzare le informazioni. Restano ferme
le responsabilità che la legge non consente di escludere: questo disclaimer
non costituisce un’esenzione assoluta da responsabilità
([art. 1229 del Codice civile](https://def.giustiziatributaria.gov.it/DocTribFrontend/executePrintArticolo.do?articolo=Articolo+1229&codiceOrdinamento=0000000000012290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000&id=%7B9E93F1BE-06AE-4F24-8E9D-B838F7E0C2E6%7D)).

## Pubblicazione e diritti di terzi

La pubblicazione della repository rende visibili anche la cronologia Git,
le Release e la cronologia/log delle Actions: prima di cambiare visibilità
verificare che non contengano credenziali o materiale privato
([documentazione GitHub](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)).
Le chiavi di firma, i database locali, i download e le configurazioni locali
sono esclusi dal versionamento.

La visibilità pubblica non sostituisce una licenza del codice e non concede
diritti aggiuntivi su dati, marchi o immagini di terzi. I dati AMTS sono
attribuiti ad AMTS con licenza IODL 2.0; l’uso di BusOne resta soggetto alle sue
condizioni, incluso l’uso personale e non commerciale. Per FCE restano valide
le condizioni delle fonti originali, collegate nelle impostazioni. I font
Manrope sono distribuiti con il testo della licenza OFL in `assets/fonts/OFL.txt`.
Il PNG dell’elefante fornito dal proprietario è conservato in `assets/Elefante_verde_su_sfondo_blu_notte-removebg-preview.png` e copiato senza modifiche in `assets/branding/liotru.png`. Prima della pubblicazione verificarne origine e licenza: l’averlo allegato al progetto non prova il diritto di ridistribuirlo.
Consultare [fonti e attribuzioni](docs/FONTI_DATI.md).

## Stato dei dati

Le fonti sono state verificate dalla rete GitHub Actions l’8 novembre 2026:
[GTFS ufficiale AMTS](https://www.amts.ct.it/GTFS/AMTCT.zip) e
[TripUpdates BusOne](https://proxy.busone.app/amts/gtfs-rt/trip-updates.json)
rispondono HTTP 200. Gli URL sono già compilati nelle impostazioni.
Al primo avvio l’app scarica automaticamente i dati AMTS. Il comando
**Impostazioni → Scarica e aggiorna dati** resta disponibile per un aggiornamento manuale.
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
   Per la versione 2.4, finché la relativa pull request non è unita a `main`,
   seleziona `codex/automatic-data-navigation` (`git switch codex/automatic-data-navigation`).
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

## Ottenere l’APK diretto da GitHub

Apri **Releases** e scarica **LiotruExpress-2.4.0.apk**: è già il file installabile,
non uno ZIP. La CI pubblica una release stabile `vX.Y.Z` dai push su `main`
o dalle esecuzioni manuali; le PR interne producono anteprime identificate dal
numero di esecuzione, collegate al commit compilato. Gli APK vengono pubblicati
solo dopo analisi, test, verifiche dei dati e compilazione riusciti.
È incluso il checksum SHA-256. I file «Source code» di GitHub sono il codice
sorgente, non l’APK da installare. Gli artefatti di Actions restano disponibili
per diagnosi e sono compressi automaticamente da GitHub.

La firma personale debug viene conservata nella cache Actions. La chiave è
generata e usata da Gradle nello stesso percorso esplicito, scelto tramite
`LIOTRU_DEBUG_KEYSTORE`; le build locali usano la firma debug Android normale.
La correzione 2.4 richiede una prima reinstallazione rispetto agli APK 2.3,
perché le loro chiavi non erano state conservate correttamente. La cache è
soggetta all’ambito dei rami e può essere eliminata da GitHub: per distribuzioni
stabili a lungo termine occorre una chiave release propria conservata nei
segreti della repository. La chiave non viene pubblicata negli artefatti né
aggiunta al codice. Una firma diversa da quella già installata richiede
reinstallazione, con perdita di dati locali e preferiti. Le release già
pubblicate non vengono sovrascritte da altri commit con la stessa versione.

## Installare sul telefono

Trasferisci l’APK sul telefono via USB o tramite un tuo spazio file, aprilo
dall’app File e autorizza temporaneamente **Installa app sconosciute** per
quell’app quando Android lo richiede. Conferma l’installazione di Liotru Express.
In alternativa, con Android Platform Tools e debug USB:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Nome e icona (2.4)

Il nome visualizzato è **Liotru Express**. Il PNG originale dell’elefante viene
usato nell’intestazione dell’app e come base delle icone Android, comprese
quelle adattive. Colori, font e stile delle schede restano gli stessi.
L’identificativo Android `it.personale.cataniabus` è mantenuto per conservare
la compatibilità degli aggiornamenti. Per rigenerare le icone alle diverse
densità, installare Pillow ed eseguire `python3 tool/prepare_icons.py`.

## Home e stazione Metro preferita (2.4)

La Home mostra i prossimi passaggi Metro verso **Stesicoro** e **Monte Po**
della **Stazione preferita**. Puoi cambiarla dal selettore nella Home oppure
selezionare una stazione nella scheda Metro e toccare la stella. La preferita
è salvata sul dispositivo e non cambia quando consulti altre stazioni Metro.
I contatori si aggiornano durante l’uso e alla ripresa dell’app; al capolinea
la direzione che termina lì è indicata senza inventare una corsa. Il dettaglio
delle stime e delle fonti resta nelle impostazioni.

## Avvio e aggiornamento automatico

Al primo avvio l’app scarica automaticamente i dati AMTS, con un’animazione
e l’avanzamento del download. È possibile continuare a usare l’app durante
la preparazione; in caso di errore sono disponibili Riprova e le impostazioni.

Quando il calendario scade, l’app avvisa e aggiorna i dati in background senza
mostrare l’animazione iniziale. Il controllo avviene all’apertura, alla ripresa
e ogni minuto mentre l’app è attiva, usando il giorno di Catania (Europe/Rome).
Non viene programmato un servizio Android a processo chiuso. La preparazione
avviene in un database separato: gli ultimi dati rimangono leggibili e vengono
sostituiti con una transazione atomica solo dopo la validazione. Preferiti e
preferenze non sono cancellati.

Dopo un errore di rete l’aggiornamento automatico riprova dopo 15 minuti. Se
AMTS pubblica ancora un calendario scaduto e non più recente di quello locale,
lo conserva e riprova dopo sei ore. La scadenza non viene estesa artificialmente.
L’utente può aggiornare manualmente in qualsiasi momento dalle impostazioni.
Le eccezioni che rimuovono un servizio non allungano la validità del calendario.

La navigazione principale è **Home / Bus / Metro**. Dentro **Bus** si sceglie
**Per fermata / Per linea**. L’ingranaggio dell’intestazione apre le impostazioni;
tutte le schermate condividono marchio e titolo di sezione. La spiegazione
completa delle stime Metro è in **Impostazioni → Come funzionano le stime Metro**.

## Importare e aggiornare gli orari AMTS

La versione 1.0.1 corregge il blocco dell’importazione dal pulsante di download.
Gli errori restano visibili nella pagina e il download GTFS non dipende dalla
validità delle impostazioni del tempo reale.

1. In Liotru Express apri **Impostazioni → Scarica e aggiorna dati**: il link ufficiale è già inserito.
2. Se il download fallisce, apri [Open Data AMTS](https://www.amts.ct.it/open-data)
   nel browser e scarica l’archivio **GTFS ZIP**, senza estrarlo, sul telefono.
3. Usa **Impostazioni → Importa ZIP dal telefono** per importarlo manualmente.
4. Apri **Bus → Per fermata**, cerca nome/codice e tocca una fermata per vedere gli arrivi.
5. Usa la stella per aggiungerla ai **Preferiti**.

Se AMTS cambia il link diretto HTTPS allo ZIP, puoi aggiornarlo nelle
impostazioni e usare **Scarica e aggiorna dati**. Non usare l’URL della pagina
HTML come se fosse l’archivio. Il download automatico segue le regole descritte sopra; resta disponibile anche
l’importazione manuale. Un aggiornamento non valido lascia intatti gli ultimi dati.

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

Apri **Bus → Per linea** e cerca il numero o il nome della linea,
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

## Metro FCE (2.2)

La nuova scheda **Metro** permette di scegliere una delle 12 stazioni e vedere
le prossime attese verso **Monte Po** e **Stesicoro**, contemporaneamente. La
stazione scelta resta salvata sul telefono. Il conto alla rovescia si aggiorna
ogni secondo, funziona offline e si ferma uscendo dalla scheda o sospendendo l’app.
Ai capolinea viene indicata la sola direzione utile per partire.

**Sono stime da orario, non dati live.** Nel codice pubblico di
[FCE Quando](https://github.com/sonobongo/fcequando_bot/tree/4301a301b5b2d5bf96f3a3bc332cd76cec6f2744)
non è stata trovata un’API di arrivi: il bot usa propri orari e misurazioni locali.
Nessun codice o dato di misurazione del bot è stato copiato.

Le partenze sono estratte dal [quadro orario ufficiale FCE](https://www.circumetnea.it/download/orario-metro/),
pubblicato il 3 settembre 2026 e verificato l’8 novembre. Alle stazioni intermedie
si aggiungono i tempi relativi del GTFS FCE pubblicato: il suo calendario è fermo
al **28 febbraio 2025**, nonostante il titolo della pagina indichi il 2028.
Il vecchio GTFS viene usato solo per le durate fra stazioni: i suoi calendari
non vengono estesi né usati per attivare corse attuali.
Questi tempi storici possono essere imprecisi: i passaggi restano indicati come
stimati nelle schede; i dettagli sono in **Impostazioni → Come funzionano le stime Metro**.
Non vengono rilevati ritardi, soppressioni o modifiche straordinarie. Il conto
alla rovescia non rappresenta la posizione di un treno. Eventi e festività locali
richiedono la consultazione degli avvisi FCE.

Il modello distingue lunedì–giovedì, venerdì, sabato, domenica e festività nazionali,
comprese Pasqua e Pasquetta. Le partenze oltre mezzanotte restano associate al
giorno di servizio precedente. Gli orari lontani mostrano giorno e ora.

I dati sono inclusi in `assets/metro/timetable.json` con URL e SHA-256 delle fonti.
La CI scarica PDF e GTFS dalla rete del runner e li confronta con i dati inclusi,
verificando tutte le partenze, i 20 minuti complessivi pubblicati e le 12 stazioni.
Il generatore `tool/prepare_metro_timetable.py` richiede `pypdf==6.10.0`; un PDF
con digest diverso richiede revisione del contenuto prima di aggiornare i dati.
Un aggiornamento dell’orario Metro viene distribuito con una nuova versione
APK; il pulsante di aggiornamento GTFS nelle impostazioni riguarda gli autobus.
Dopo 30 giorni dalla verifica, la scheda invita a controllare eventuali variazioni.
L’app è indipendente da FCE e FCE Quando. Non viene dichiarata una licenza aperta
per il GTFS FCE: l’app resta destinata all’uso personale.

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
| Attese Metro FCE e calendario | `lib/ui/metro.dart`, `lib/domain/metro.dart` |
| Vista arrivi, caricamento offline immediato e copertura realtime | `lib/ui/arrivals_controller.dart` |
| Giorno/ora e contatori limitati agli arrivi vicini | `lib/domain/arrival_display.dart` |
| Verifica fonti e build Android | `tool/verify_sources.py`, `.github/workflows/android.yml` |

I test sotto `test/` usano dati sintetici per i casi limite e verificano anche
il quadro orario FCE incluso nell’app. I dati sintetici non sono presentati
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
