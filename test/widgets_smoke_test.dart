import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/main.dart';
import 'package:pantry_pilot/ui/animations.dart';

import 'helpers.dart';

void main() {
  testWidgets('splashes into home, opens settings, toggles dark mode + glow',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await pumpIntoHome(tester, RecipePilotApp(controller: controller));

    // Home is showing the seeded library. Titles can legitimately appear twice
    // (the "Ready in 30" carousel mirrors the shelf), so match at least one.
    expect(find.text('Garlic Butter Pasta'), findsWidgets);
    expect(find.text('Your recipes'), findsOneWidget);

    // Settings corner → settings page.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Glow effects'), findsOneWidget);
    // Custom switch rows wrap a bare Material [Switch] (Semantics provides
    // the accessible label) — not the old SwitchListTile.
    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.darkMode, isTrue);

    // Second switch is the glow halos introduced with dark-mode polish.
    await tester.tap(find.byType(Switch).at(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.glowEffects, isFalse);
    await flushTimers(tester);
  });

  testWidgets('filter pills narrow the shelf and All restores it',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await pumpIntoHome(tester, RecipePilotApp(controller: controller));

    expect(controller.visibleRecipes.length, 10);

    // Tap the Vegetarian pill (visible below the hero).
    await tester.tap(find.text('Vegetarian').first);
    await tester.pump(const Duration(milliseconds: 600));

    // Controller filtered; a meaty recipe vanished from the shelf (and the
    // "Ready in 30" carousel hides itself while a filter is active).
    expect(controller.activeTag, 'Vegetarian');
    expect(controller.visibleRecipes.length, lessThan(10));
    expect(find.text('Chicken Fajita Bowl'), findsNothing);
    // Staggered cascade replays for the new set (60ms x index + 420ms).
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Garlic Butter Pasta'), findsOneWidget);

    // Back to All.
    await tester.tap(find.text('All'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.visibleRecipes.length, 10);
    await flushTimers(tester);
  });

  testWidgets('ingredient meter updates live as items are checked',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await pumpIntoHome(tester, RecipePilotApp(controller: controller));

    // Home → recipe detail (the carousel mirrors this recipe, use the first).
    await tester.tap(find.text('Garlic Butter Pasta').first);
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
    await flushTimers(tester);
  });
}
