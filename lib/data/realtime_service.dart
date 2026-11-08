import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/realtime.dart';
import 'network.dart';

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
  Future<RealtimeResult>? _pending;

  // All screens share this rate limit. Manual refresh cannot bypass it.
  Future<RealtimeResult> fetch(String url, DateTime now) async {
    if (url != _url) { _cache = null; _lastAttempt = null; _url = url; }
    if (_pending != null) return _pending!;
    if (_lastAttempt != null && now.difference(_lastAttempt!) < const Duration(seconds:60)) {
      final valid = _cache?.freshAt(now) ?? false;
      return RealtimeResult(valid ? _cache : null,
        valid ? 'Dati realtime disponibili' : 'Tempo reale non disponibile: orari programmati');
    }
    _lastAttempt = now;
    final pending = _download(url, now);
    _pending = pending;
    try { return await pending; } finally { _pending = null; }
  }

  Future<RealtimeResult> _download(String url, DateTime now) async {
    try {
      final response = await client.send(http.Request('GET', httpsUrl(url)))
          .timeout(const Duration(seconds:12));
      if (response.statusCode != 200) {
        await response.stream.listen((_){}).cancel();
        throw FormatException('HTTP ${response.statusCode}');
      }
      if ((response.contentLength ?? 0) > 10*1024*1024) {
        await response.stream.listen((_){}).cancel();
        throw const FormatException('Risposta troppo grande');
      }
      var size = 0;
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(const Duration(seconds:12))) {
        size += chunk.length;
        if (size > 10*1024*1024) throw const FormatException('Risposta troppo grande');
        bytes.addAll(chunk);
      }
      final feed = RealtimeFeed.parse(jsonDecode(utf8.decode(bytes)), now);
      _cache = feed;
      return RealtimeResult(feed, 'Dati realtime disponibili');
    } catch (_) {
      // Never continue displaying a successful previous result after a failed
      // request. A fresh empty FULL_DATASET likewise replaces the old cache.
      _cache = null;
      return const RealtimeResult(null, 'Tempo reale non disponibile: orari programmati');
    }
  }
}
