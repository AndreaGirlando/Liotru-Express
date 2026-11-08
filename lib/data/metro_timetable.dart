import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/metro.dart';

Future<MetroTimetable> loadMetroTimetable() async => MetroTimetable.fromJson(
  jsonDecode(await rootBundle.loadString('assets/metro/timetable.json'))
      as Map<String, dynamic>,
);
