# Verifica delle fonti dati

Verifica: 8 novembre 2026, 10:50 CET, tramite GitHub Actions.

| Fonte | Risultato dal runner GitHub |
| --- | --- |
| https://www.amts.ct.it/open-data | HTTP 200, pagina ufficiale con link GTFS e dichiarazione IODL 2.0. |
| https://www.amts.ct.it/GTFS/AMTCT.zip | HTTP 200, application/zip, 3.173.161 byte al momento della verifica. Include agency, routes, trips, stops, stop_times, calendar_dates e shapes. Nessun calendar.txt: le date sono definite dalle eccezioni aggiuntive. Fuso Europe/Rome. |
| https://proxy.busone.app/amts/ | HTTP 200, documentazione e condizioni lette dall’HTML scaricato. |
| https://proxy.busone.app/amts/gtfs-rt/trip-updates.json | HTTP 200, JSON GTFS-Realtime 2.0, FULL_DATASET, snake_case, 95 entità nel campione. Nessuna chiave API. |

Evidenza riproducibile: [esecuzione iniziale con rapporto e risposte](https://github.com/AndreaGirlando/CataniaAMTS/actions/runs/42468872060).
L’ambiente Codex locale blocca questi domini con 403 CONNECT del proxy; la
verifica è stata effettuata dalla rete del runner, senza aggirare il proxy locale.
Gli URL verificati sono precompilati nelle impostazioni. Non vengono incorporati
dati di prova o previsioni simulate. Lo ZIP viene scaricato su richiesta dell’utente;
è sempre disponibile l’importazione manuale come fallback.

Il campione ufficiale scaricato contiene 1.418 fermate, 53 linee, 15.769 corse
e 386.071 passaggi alle fermate. Le 27 righe `calendar_dates` coprono date dal
20 ottobre al 15 novembre 2026: fuori da questo calendario l’app non inventa
giorni di servizio. Occorre aggiornare lo ZIP quando AMTS pubblica nuove date.

Un secondo campione BusOne contiene 99 TripUpdates: tutti i `trip_id` e gli
orari iniziali corrispondono allo statico AMTS; tutte le 2.728 coppie
`stop_sequence`/`stop_id` corrispondono alle corse dichiarate. Alla data del
campione 49 aggiornamenti individuali rientrano nei tre minuti di freschezza:
la sola intestazione recente non rende affidabili tutti gli aggiornamenti.

Il workflow GitHub Actions esegue `python3 tool/verify_sources.py` dalla rete del
runner e conserva l’esito e le risposte nell’artefatto `verifica-fonti`.
Il rapporto distingue errori HTTP, errori di rete, ZIP validi e JSON realtime.
La riuscita di una richiesta non dimostra da sola il diritto di utilizzare un
servizio: consultare le condizioni del fornitore.

Nella versione 2.0 il realtime è attivo per impostazione predefinita; il
selettore salva immediatamente la scelta. Sono supportati
TripUpdates JSON completi, in camelCase e snake_case, con timestamp del feed.
Non sono supportati API con credenziali, protobuf binario, feed incrementali,
corse aggiunte non presenti nel GTFS o previsioni ricavate da VehiclePositions.
Il polling è limitato a una richiesta ogni 60 secondi a schermata aperta.
La documentazione indica un limite anonimo iniziale di 120 richieste per IP,
poi cinque al secondo: il polling dell’app è molto più conservativo. L’app
rispetta anche Retry-After nelle risposte HTTP. Non fa richieste in background.

## Condizioni e qualità BusOne

La pagina consente l’accesso gratuito per uso personale e non commerciale,
con attribuzione “BusOne (https://busone.app) e fonte originale”. L’app mostra
questa attribuzione insieme ad AMTS, fonte dello statico (IODL 2.0).
L’accessibilità del realtime non estende automaticamente la licenza IODL ai
dati realtime delle fonti originali. Il servizio non è ufficiale AMTS e non
garantisce disponibilità o completezza.

I client automatici devono inviare `X-BusOne-Client` (applicazione e contatto)
e `X-BusOne-Use`. CataniaBus invia `personal` e
`CataniaBus/2.1; https://github.com/AndreaGirlando`, il contatto GitHub pubblico
del proprietario della repository; nessun indirizzo email o segreto è incluso.
Per riusare il progetto con un altro account cambiare `clientIdentity`.

Le previsioni pubbliche sono elaborate dal middleware ORACLE di BusOne.
Non sono previsioni GPS inventate dall’app. Il timestamp di pubblicazione non
rinnova il timestamp del riscontro della corsa: l’app scarta anche TripUpdates
individuali scaduti. Nel campione delle 12:13 UTC dell’8 novembre 2026 tutte
le 474 previsioni future di corse con timestamp fresco avevano incertezza oltre
120 secondi: la precedente soglia scartava quindi tutte quelle previsioni.
La versione 2.0 conserva le stime con margine fino a 15 minuti, indicandolo
esplicitamente con `~`, colore ambra e **Stima BusOne**. Le previsioni con
incertezza maggiore o negativa restano escluse. Timestamp di arrivo incoerenti
con la corsa o oltre tre ore nel futuro non diventano previsioni live.
Le VehiclePositions sono documentate
ma non vengono usate dall’app per ricavare arrivi.

La variante statica BusOne può estendere provvisoriamente un calendario scaduto;
l’app usa per impostazione predefinita il **GTFS originale AMTS**, mantenendo
soltanto i giorni effettivamente pubblicati dall’operatore.

I feed a frequenza (`frequencies.txt`) vengono rifiutati esplicitamente.
Gli orari intermedi vuoti non sono interpolati e non diventano arrivi inventati.

## Caso Metro Shuttle segnalato dall’utente

Nel GTFS ufficiale scaricato l’8 novembre 2026 alle 14:50 UTC, la linea
`A-MS` (AMTS Metro Shuttle) ha 566 corse associate ai calendari feriali e
sabato; non ci sono servizi per domenica 8 novembre. La prima partenza
pubblicata da `1928` (Stazione Milo) è lunedì 9 novembre alle 06:25.
Il campione BusOne della stessa verifica non contiene TripUpdates per `A-MS`.
Un’attesa di centinaia di minuti in questo caso era il programma del giorno
successivo, non un arrivo live. La nuova schermata lo raggruppa negli orari
successivi con giorno e ora. Il controllo reale in CI verifica anche questa
fermata, usando il calendario e il feed effettivamente scaricati.
