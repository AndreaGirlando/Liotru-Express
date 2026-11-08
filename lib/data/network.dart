import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

Uri httpsUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const FormatException('Inserisci un indirizzo HTTPS valido, senza credenziali');
  }
  return uri;
}

// Total transfer deadline as well as request timeout; bounded ZIP/JSON sizes.
Future<void> downloadFile(http.Client client, Uri url, File file,
    {int maxBytes = 100 * 1024 * 1024}) async {
  final request = http.Request('GET', url);
  final response = await client.send(request).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    await response.stream.listen((_) {}).cancel();
    throw HttpException('Download non riuscito (HTTP ${response.statusCode})');
  }
  if ((response.contentLength ?? 0) > maxBytes) {
    await response.stream.listen((_) {}).cancel();
    throw const FormatException('Risposta troppo grande');
  }
  final sink = file.openWrite();
  var length = 0;
  final subscription = response.stream.listen((chunk) {
    length += chunk.length;
    if (length <= maxBytes) sink.add(chunk);
  });
  try {
    await subscription.asFuture<void>().timeout(const Duration(seconds: 90));
    if (length > maxBytes) throw const FormatException('Risposta troppo grande');
    await sink.flush();
  } finally {
    await subscription.cancel();
    await sink.close();
  }
}
