import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/store.dart';
import 'package:pantry_pilot/main.dart';

void main() {
  testWidgets('splashes into home, shows recipes, dark mode via settings',
      (tester) async {
    // In-memory store: no dart:io inside the fake-async widget-test zone.
    final controller = AppController(
      store: GroceryStore(inMemory: true),
      parser: const IngredientParser(),
    );
    await controller.bootstrap();

    await tester.pumpWidget(PantryPilotApp(controller: controller));

    // Splash animates for 1.5s, then a 450ms fade into Home. The hero card
    // repeats a float animation forever, so we must pump explicit durations
    // instead of pumpAndSettle (which would never settle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    // Home is showing the seeded library.
    expect(find.text('Pantry Pilot'), findsWidgets);
    expect(find.text('Garlic Butter Pasta'), findsOneWidget);
    expect(find.text('Your recipes'), findsOneWidget);

    // Settings corner → dark mode switch.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dark mode'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.darkMode, isTrue);
  });
}
