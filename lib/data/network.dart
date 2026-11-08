import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

Uri httpsUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Inserisci un indirizzo HTTPS valido, senza credenziali',
    );
  }
  return uri;
}

// Total transfer deadline as well as request timeout; bounded ZIP/JSON sizes.
Future<void> downloadFile(
  http.Client client,
  Uri url,
  File file, {
  int maxBytes = 100 * 1024 * 1024,
  void Function(int received, int? total)? onProgress,
}) async {
  final request = http.Request('GET', url);
  final response = await client
      .send(request)
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    await response.stream.listen((_) {}).cancel();
    throw HttpException('Download non riuscito (HTTP ${response.statusCode})');
  }
  if ((response.contentLength ?? 0) > maxBytes) {
    await response.stream.listen((_) {}).cancel();
    throw const FormatException('Risposta troppo grande');
  }
  final output = await file.open(mode: FileMode.write);
  final iterator = StreamIterator<List<int>>(response.stream);
  final watch = Stopwatch()..start();
  var length = 0;
  try {
    while (true) {
      final remaining = const Duration(seconds: 90) - watch.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Download GTFS scaduto');
      }
      if (!await iterator.moveNext().timeout(remaining)) break;
      final chunk = iterator.current;
      length += chunk.length;
      if (length > maxBytes) {
        throw const FormatException('Risposta troppo grande');
      }
      await output.writeFrom(chunk);
      onProgress?.call(length, response.contentLength);
    }
    await output.flush();
  } finally {
    await iterator.cancel();
    await output.close();
  }
}

Future<List<int>> readJsonBody(
  Stream<List<int>> stream, {
  int maxBytes = 10 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final iterator = StreamIterator<List<int>>(stream);
  final watch = Stopwatch()..start();
  final bytes = <int>[];
  try {
    while (true) {
      final remaining = timeout - watch.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Download realtime scaduto');
      }
      if (!await iterator.moveNext().timeout(remaining)) break;
      if (bytes.length + iterator.current.length > maxBytes) {
        throw const FormatException('Risposta troppo grande');
      }
      bytes.addAll(iterator.current);
    }
    return bytes;
  } finally {
    await iterator.cancel();
  }
}
