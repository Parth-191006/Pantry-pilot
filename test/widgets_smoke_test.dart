import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/models.dart';
import 'package:pantry_pilot/main.dart';
import 'package:pantry_pilot/screens/cook_along_screen.dart';
import 'package:pantry_pilot/ui/animations.dart';

import 'helpers.dart';

/// Pump helper for the cook-along screen: route transition + switcher settle.
Future<void> _pumpIntoCookAlong(
  WidgetTester tester,
  RecipePilotApp app, {
  required Recipe recipe,
}) async {
  await pumpIntoHome(tester, app);
  await tapAndSettleRoute(tester, find.text(recipe.title).first);
  await tapAndSettleRoute(tester, find.byKey(const ValueKey('cook_along')));
}

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
    await tapAndSettleRoute(tester, find.byIcon(Icons.settings_outlined));

    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Glow effects'), findsOneWidget);
    // Celebrations was removed as a toggle — confetti is simply always on —
    // so Dark mode and Glow effects are the only two switches here.
    expect(find.text('Celebrations'), findsNothing);
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
    await tapAndSettleRoute(tester, find.text('Garlic Butter Pasta').first);

    // Detail → generate list (220ms parse beat + 340ms shared-axis push).
    await tapAndSettleRoute(tester, find.text('Generate grocery list'));

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

  testWidgets('cook-along: timed step starts, runs, expires, and next works',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await _pumpIntoCookAlong(
      tester,
      RecipePilotApp(controller: controller),
      // First step of Garlic Butter Pasta is a 5-minute countdown.
      recipe: controller.recipes.firstWhere((r) => r.id == 'r_garlic_pasta'),
    );

    // Step 1 with its ring idle at the full duration (05:00).
    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Ready to start'), findsOneWidget);
    expect(
      find.byKey(CookAlongScreen.stepKey),
      findsOneWidget,
    ); // big text is on screen

    // Start → 1 s of cooking → ring reads 04:59.
    await tester.tap(find.text('Start timer'));
    await tester.pump(); // state tick
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:59'), findsOneWidget);
    expect(find.text('Cooking…'), findsOneWidget);

    // Pause freezes; resume continues from the frozen value.
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('04:59'), findsOneWidget); // frozen
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:58'), findsOneWidget);

    // Let the remaining ~4:58 run out: pump past the deadline so the 1 Hz
    // ticker crosses it and fires the expiry state exactly once.
    await tester.pump(const Duration(seconds: 299));
    expect(find.text("Time's up 🔔"), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);

    // Next step (untimed) resets the header and shows the stopwatch chip.
    await tester.tap(find.text('Next step'));
    await tester.pump(const Duration(milliseconds: 500)); // switcher + reset
    expect(find.text('Step 2 of 8'), findsOneWidget);
    expect(find.byKey(CookAlongScreen.stepKey), findsOneWidget);
    expect(find.text('Cook the pasta until just shy of al dente — it finishes in the sauce.'),
        findsOneWidget);

    // Back returns to step 1, timers fresh.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget); // fresh, idle again
    // The expiry SnackBar hides itself after 4 s — pump past it so the test
    // ends with no pending timers (fake_async forbids them).
    await tester.pump(const Duration(seconds: 5));
    await flushTimers(tester);
  });

  testWidgets('cook-along: finishing the last step celebrates', (tester) async {
    final controller = makeController();
    await controller.bootstrap();

    await _pumpIntoCookAlong(
      tester,
      RecipePilotApp(controller: controller),
      // Same proven-visible recipe as the other tests; its 8 steps mix timed
      // and untimed ones — neither kind blocks the Next-step walk.
      recipe: controller.recipes.firstWhere((r) => r.id == 'r_garlic_pasta'),
    );

    // Walk through all eight steps without touching the timers.
    for (var i = 1; i <= 8; i++) {
      expect(find.text('Step $i of 8'), findsOneWidget);
      await tester.tap(find.text(i == 8 ? 'Done cooking 🎉' : 'Next step'));
      await tester.pump(const Duration(milliseconds: 500)); // switcher beat
    }

    expect(find.byKey(const ValueKey('cook_done')), findsOneWidget);
    expect(find.text("You're done!"), findsOneWidget);
    await flushTimers(tester);
  });
}
