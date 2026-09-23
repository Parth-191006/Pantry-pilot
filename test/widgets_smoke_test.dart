import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/store.dart';
import 'package:pantry_pilot/main.dart';
import 'package:pantry_pilot/ui/animations.dart';

/// Splash runs 1.5s, then a 450ms fade into Home. The hero card repeats a
/// float animation forever, so tests must pump explicit durations —
/// pumpAndSettle would never settle.
Future<void> pumpIntoHome(WidgetTester tester, PantryPilotApp app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
}

AppController makeController() => AppController(
      store: GroceryStore(inMemory: true),
      parser: const IngredientParser(),
    );

void main() {
  testWidgets('splashes into home, opens settings, toggles dark mode',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await pumpIntoHome(tester, PantryPilotApp(controller: controller));

    // Home is showing the seeded library.
    expect(find.text('Garlic Butter Pasta'), findsOneWidget);
    expect(find.text('Your recipes'), findsOneWidget);

    // Settings corner → redesigned settings page.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dark mode'), findsOneWidget);
    // Custom switch rows wrap a bare Material [Switch] (Semantics provides
    // the accessible label) — not the old SwitchListTile.
    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.darkMode, isTrue);
  });

  testWidgets('filter pills narrow the shelf and All restores it',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await pumpIntoHome(tester, PantryPilotApp(controller: controller));

    expect(controller.visibleRecipes.length, 10);

    // Tap the Vegetarian pill (visible below the hero).
    await tester.tap(find.text('Vegetarian').first);
    await tester.pump(const Duration(milliseconds: 600));

    // Controller filtered; a meaty recipe vanished from the shelf.
    expect(controller.activeTag, 'Vegetarian');
    expect(controller.visibleRecipes.length, lessThan(10));
    expect(find.text('Chicken Fajita Bowl'), findsNothing);
    // Staggered cascade replays for the new set (60ms x index + 420ms).
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Garlic Butter Pasta'), findsOneWidget);

    // Back to All. Pump past the full cascade (60ms × 10 cards + 420ms
    // animation) so no StaggeredEntrance timers are pending at test end.
    await tester.tap(find.text('All'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.visibleRecipes.length, 10);
  });

  testWidgets('ingredient meter updates live as items are checked',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await pumpIntoHome(tester, PantryPilotApp(controller: controller));

    // Home → recipe detail.
    await tester.tap(find.text('Garlic Butter Pasta'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));

    // Detail → generate list (220ms parse beat + 340ms shared-axis push).
    await tester.tap(find.text('Generate grocery list'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));

    expect(controller.totalCount, greaterThan(0));
    expect(controller.checkedCount, 0);

    // The meter header exposes its current progress as a ValueKey, so the
    // test can assert the *visual* state, not just the model.
    ValueKey<String> meterKey(int checked) =>
        ValueKey('meter-$checked-of-${controller.totalCount}');
    expect(find.byKey(meterKey(0)), findsOneWidget);

    // Check the first item via its StrikeCheckbox.
    await tester.tap(find.byType(StrikeCheckbox).first);
    await tester.pump(const Duration(milliseconds: 500)); // meter tween 450ms
    await tester.pump(const Duration(milliseconds: 100));

    // State synced instantly AND the meter re-rendered at the new fraction.
    expect(controller.checkedCount, 1);
    expect(find.byKey(meterKey(1)), findsOneWidget);
    expect(find.byKey(meterKey(0)), findsNothing);

    // Uncheck: meter animates back down just as smoothly.
    await tester.tap(find.byType(StrikeCheckbox).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.checkedCount, 0);
    expect(find.byKey(meterKey(0)), findsOneWidget);
    expect(find.byKey(meterKey(1)), findsNothing);
  });
}
