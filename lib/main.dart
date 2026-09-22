import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/ingredient_parser.dart';
import 'data/store.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hive init happens in bootstrap; everything is local — no network calls.
  final controller = AppController(store: GroceryStore(), parser: const IngredientParser());
  await controller.bootstrap();

  runApp(PantryPilotApp(controller: controller));
}

class PantryPilotApp extends StatelessWidget {
  const PantryPilotApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'Pantry Pilot',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
