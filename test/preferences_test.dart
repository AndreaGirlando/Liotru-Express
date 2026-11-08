import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catania_bus/data/preferences.dart';

void main() {
  test('favorites persist and can be removed, realtime disabled initially',() async {
    SharedPreferences.setMockInitialValues({});
    final preferences=UserPreferences(await SharedPreferences.getInstance());
    expect(preferences.realtimeEnabled,isFalse);
    await preferences.toggleFavorite('S1');
    final reopened=UserPreferences(await SharedPreferences.getInstance());
    expect(reopened.favorites,['S1']);
    await reopened.toggleFavorite('S1');
    expect(preferences.favorites,isEmpty);
    await reopened.setTheme('dark');
    expect(preferences.theme,'dark');
  });
}
