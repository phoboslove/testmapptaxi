import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api/api_client.dart';
import 'screens/day_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  runApp(DriverDiaryApp(api: ApiClient()));
}

class DriverDiaryApp extends StatelessWidget {
  const DriverDiaryApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFFB300); // warm amber, taxi-like
    return MaterialApp(
      title: 'Дневник смен',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: DayScreen(api: api),
    );
  }
}
