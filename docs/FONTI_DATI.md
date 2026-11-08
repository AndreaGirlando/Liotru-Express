# Verifica delle fonti dati

Prima verifica: 8 novembre 2026.

| Fonte | Risultato nell’ambiente Codex |
| --- | --- |
| https://www.amts.ct.it/open-data | Tunnel HTTPS negato dal proxy dell’ambiente (403 CONNECT). Non è una risposta del server AMTS. |
| https://proxy.busone.app/amts/gtfs-rt/trip-updates.json | Tunnel HTTPS negato dal proxy dell’ambiente (403 CONNECT). Endpoint e disponibilità non verificati. |
| https://proxy.busone.app/amts/ | Documentazione non raggiungibile dalla rete configurata. Condizioni, chiavi API e frequenza ammessa non verificate. |

Non sono stati incorporati orari AMTS, link ZIP presunti o previsioni simulate.
L’utente può scaricare lo ZIP pubblicato da AMTS e importarlo dal telefono.
È disponibile anche l’aggiornamento da un URL HTTPS configurato dall’utente.

Il workflow GitHub Actions esegue `python3 tool/verify_sources.py` dalla rete del
runner e conserva l’esito e le risposte nell’artefatto `verifica-fonti`.
Il rapporto distingue errori HTTP, errori di rete, ZIP validi e JSON realtime.
La riuscita di una richiesta non dimostra da sola il diritto di utilizzare un
servizio: consultare le condizioni del fornitore.

Il realtime resta disattivato fino a configurazione esplicita. Sono supportati
TripUpdates JSON completi, in camelCase e snake_case, con timestamp del feed.
Non sono supportati API con credenziali, protobuf binario, feed incrementali,
corse aggiunte non presenti nel GTFS o previsioni ricavate da VehiclePositions.
Il polling è limitato a una richiesta ogni 60 secondi a schermata aperta.
Il fornitore deve consentire questo intervallo; altrimenti lasciare disattivato.

I feed a frequenza (`frequencies.txt`) vengono rifiutati esplicitamente.
Gli orari intermedi vuoti non sono interpolati e non diventano arrivi inventati.
