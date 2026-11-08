import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:catania_bus/domain/models.dart';
import 'package:catania_bus/ui/stop_detail.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  final time=DateTime.utc(2026,11,8,9);
  Arrival arrival(bool realtime)=>Arrival(tripId:'SYNTHETIC',stopId:'S1',sequence:1,
    route:'42',destination:'Destinazione sintetica di prova',serviceDate:'20261108',
    tripStart:'10:00:00',scheduled:time.add(const Duration(minutes:5)),
    predicted:realtime ? time.add(const Duration(minutes:7)) : null);
  testWidgets('Italian arrivals distinguish real time from schedule',(tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ArrivalTile(arrival(true),reference:time))));
    expect(find.text('Tempo reale'),findsOneWidget);
    expect(find.text('tra 7 min'),findsOneWidget);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ArrivalTile(arrival(false),reference:time))));
    expect(find.text('Programmato'),findsOneWidget);
    expect(find.text('Tempo reale'),findsNothing);
  });
  testWidgets('narrow phone with large text renders without overflow',(tester) async {
    tester.view.physicalSize=const Size(320,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:MediaQuery(
      data:const MediaQueryData(textScaler:TextScaler.linear(2)),
      child:Scaffold(body:ListView(children:[ArrivalTile(arrival(false),reference:time)])))));
    expect(tester.takeException(),isNull);
  });
}
