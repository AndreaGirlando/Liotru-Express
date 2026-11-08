import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../domain/realtime.dart';
import 'network.dart';
import 'preferences.dart';

class RealtimeResult {
  const RealtimeResult(this.feed, this.message);
  final RealtimeFeed? feed;
  final String message;
}

class RealtimeService {
  RealtimeService(this.client);
  final http.Client client;
  RealtimeFeed? _cache;
  String? _url;
  DateTime? _lastAttempt;
  DateTime? _retryAfter;
  Future<RealtimeResult>? _pending;
  String _lastFailure = 'Tempo reale non disponibile. Orari programmati AMTS.';

  // All screens share this rate limit. Manual refresh cannot bypass it.
  Future<RealtimeResult> fetch(String url, DateTime now) async {
    while (_pending != null) {
      final pending = _pending!;
      if (url == _url) return pending;
      await pending;
    }
    if (url != _url) {
      _cache = null;
      _lastAttempt = null;
      _retryAfter = null;
      _url = url;
      _lastFailure = 'Tempo reale non disponibile. Orari programmati AMTS.';
    }
    if ((_retryAfter != null && now.isBefore(_retryAfter!)) ||
        (_lastAttempt != null &&
            now.difference(_lastAttempt!) < const Duration(seconds: 60))) {
      final valid = _cache?.freshAt(now) ?? false;
      return RealtimeResult(
        valid ? _cache : null,
        valid
            ? 'Previsioni ricevute da BusOne'
            : _lastFailure,
      );
    }
    _lastAttempt = now;
    final pending = _download(url, now);
    _pending = pending;
    try {
      return await pending;
    } finally {
      _pending = null;
    }
  }

  Future<RealtimeResult> _download(String url, DateTime now) async {
    try {
      final request = http.Request('GET', httpsUrl(url));
      request.headers.addAll({
        'X-BusOne-Client': UserPreferences.clientIdentity,
        'X-BusOne-Use': 'personal',
        'Accept': 'application/json',
      });
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        final retry = response.headers['retry-after'];
        if (retry != null) {
          final seconds = int.tryParse(retry);
          if (seconds != null && seconds > 0) {
            _retryAfter = now.add(Duration(seconds: seconds));
          } else {
            try {
              _retryAfter = HttpDate.parse(retry);
            } catch (_) {
              /* Invalid HTTP date. */
            }
          }
        }
        await response.stream.listen((_) {}).cancel();
        throw FormatException('HTTP ${response.statusCode}');
      }
      if ((response.contentLength ?? 0) > 10 * 1024 * 1024) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException('Risposta troppo grande');
      }
      final bytes = await readJsonBody(response.stream);
      final feed = RealtimeFeed.parse(jsonDecode(utf8.decode(bytes)), now);
      _cache = feed;
      return RealtimeResult(feed, 'Previsioni ricevute da BusOne');
    } catch (e) {
      // Never continue displaying a successful previous result after a failed
      // request. A fresh empty FULL_DATASET likewise replaces the old cache.
      _cache = null;
      _lastFailure = switch (e) {
        TimeoutException() => 'BusOne non risponde in tempo. Orari programmati AMTS.',
        HandshakeException() => 'Connessione sicura a BusOne non riuscita. Orari programmati AMTS.',
        SocketException() => 'Impossibile contattare BusOne. Orari programmati AMTS.',
        http.ClientException() => 'Connessione a BusOne non disponibile. Orari programmati AMTS.',
        FormatException() when e.message.startsWith('HTTP ') => 'BusOne non disponibile (${e.message}). Orari programmati AMTS.',
        FormatException() when e.message.contains('scaduti') => 'Le previsioni ricevute non sono aggiornate. Verifica anche data e ora del telefono. Orari programmati AMTS.',
        FormatException() => 'Risposta BusOne non valida o non supportata. Orari programmati AMTS.',
        _ => 'Tempo reale non disponibile. Orari programmati AMTS.',
      };
      return RealtimeResult(
        null,
        _lastFailure,
      );
    }
  }
}
