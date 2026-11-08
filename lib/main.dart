import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app_state.dart';
import 'data/database.dart';
import 'data/preferences.dart';
import 'ui/home.dart';
import 'ui/design.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try {
    final database = await TransitDatabase.open(
      p.join(await getDatabasesPath(), 'catania_bus.db'),
    );
    final preferences = UserPreferences(await SharedPreferences.getInstance());
    final state = AppState(database, preferences, http.Client());
    await state.load();
    runApp(LiotruExpress(state));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Impossibile aprire il database locale. '
                  'Libera spazio sul telefono e riavvia Liotru Express.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiotruExpress extends StatelessWidget {
  const LiotruExpress(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => MaterialApp(
      title: 'Liotru Express',
      debugShowCheckedModeBanner: false,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: state.theme,
      theme: BusDesign.theme(Brightness.light),
      darkTheme: BusDesign.theme(Brightness.dark),
      home: HomeScreen(state),
    ),
  );
}
