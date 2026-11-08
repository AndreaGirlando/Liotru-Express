// Synthetic data only: not the published FCE timetable.
import 'package:catania_bus/domain/metro.dart';

MetroTimetable syntheticMetro() => MetroTimetable(
  stations: const [
    MetroStation('A', 'Monte Po Test', 0, 1200),
    MetroStation('B', 'Milo Test', 600, 600),
    MetroStation('C', 'Stesicoro Test', 1200, 0),
  ],
  days: {
    for (final key in [
      'weekday',
      'friday',
      'saturday',
      'sunday',
      'holiday_weekday',
      'holiday_late',
    ])
      key: {
        'stesicoro': [
          6 * 3600,
          6 * 3600 + 600,
          if (key == 'friday') 24 * 3600 + 1800,
        ],
        'montepo': [
          6 * 3600 + 300,
          6 * 3600 + 900,
          if (key == 'friday') 24 * 3600 + 1800,
        ],
      },
  },
  published: DateTime.utc(2026, 9, 3),
  checked: DateTime.utc(2026, 11, 8),
  offsetsValidUntil: '20250228',
  sourceUrl: 'https://example.invalid/official-metro',
  offsetsUrl: 'https://example.invalid/old-gtfs',
);
