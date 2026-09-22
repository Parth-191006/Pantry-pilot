import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/store.dart';
import 'package:pantry_pilot/main.dart';

void main() {
  testWidgets('bootstraps, shows seeded recipes, toggles dark mode', (tester) async {
    final controller =
        AppController(store: GroceryStore(), parser: const IngredientParser());
    await controller.bootstrap(
      storagePath: Directory.systemTemp.createTempSync('pantry_test').path,
    );

    await tester.pumpWidget(PantryPilotApp(controller: controller));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Pantry Pilot'), findsOneWidget);
    expect(find.text('Garlic Butter Pasta'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();

    expect(controller.darkMode, isTrue);
  });
}
