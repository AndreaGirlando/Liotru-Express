import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catania_bus/data/preferences.dart';

void main() {
  test(
    'favorites persist and realtime changes are saved immediately',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = UserPreferences(
        await SharedPreferences.getInstance(),
      );
      expect(preferences.realtimeEnabled, isTrue);
      await preferences.setRealtimeEnabled(false);
      await preferences.toggleFavorite('S1');
      final reopened = UserPreferences(await SharedPreferences.getInstance());
      expect(reopened.realtimeEnabled, isFalse);
      expect(reopened.favorites, ['S1']);
      await reopened.toggleFavorite('S1');
      expect(preferences.favorites, isEmpty);
      await reopened.setTheme('dark');
      expect(preferences.theme, 'dark');
    },
  );
}
