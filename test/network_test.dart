import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:catania_bus/data/network.dart';

void main() {
  test('source URLs require HTTPS and no embedded credentials',() {
    expect(()=>httpsUrl('http://example.invalid/gtfs.zip'),throwsFormatException);
    expect(()=>httpsUrl('https://user:secret@example.invalid/'),throwsFormatException);
    expect(httpsUrl('https://example.invalid/gtfs.zip').scheme,'https');
  });
  test('bounded JSON download cancels oversized responses',() async {
    await expectLater(readJsonBody(Stream.value([1,2,3]),maxBytes:2),throwsFormatException);
    expect(await readJsonBody(Stream.value([1,2])),[1,2]);
  });
  test('total JSON timeout cancels a stalled stream',() async {
    final controller=StreamController<List<int>>();
    await expectLater(readJsonBody(controller.stream,timeout:const Duration(milliseconds:20)),throwsA(isA<TimeoutException>()));
    expect(controller.hasListener,isFalse);
    await controller.close();
  });
  test('GTFS downloads are bounded and HTTP errors surfaced',() async {
    final directory=await Directory.systemTemp.createTemp('download_test_');
    final file=File('${directory.path}/feed.zip');
    final client=MockClient((_) async=>http.Response.bytes([1,2,3],200));
    try {
      await expectLater(downloadFile(client,httpsUrl('https://example.invalid/'),file,maxBytes:2),throwsFormatException);
      await downloadFile(client,httpsUrl('https://example.invalid/'),file);
      expect(await file.readAsBytes(),[1,2,3]);
      final unavailable=MockClient((_) async=>http.Response('',503));
      try {
        await expectLater(downloadFile(unavailable,httpsUrl('https://example.invalid/'),file),throwsA(isA<HttpException>()));
      } finally {unavailable.close();}
    } finally {client.close();await directory.delete(recursive:true);}
  });
}
