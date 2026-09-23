import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/store.dart';
import 'package:pantry_pilot/main.dart';

/// In-memory controller — real dart:io file I/O doesn't play well with the
/// fake-async widget-test zone.
AppController makeController() => AppController(
      store: GroceryStore(inMemory: true),
      parser: const IngredientParser(),
    );

/// Pumps the app through its splash into the home dashboard.
///
/// The splash runs 1.5 s then a 450 ms fade, and the hero card repeats a float
/// animation forever, so tests must pump explicit durations — pumpAndSettle
/// would never settle.
///
/// The surface is deliberately tall (540×1500 logical): the dashboard stacks a
/// hero, stats strip, quick actions and a carousel above the shelf, so cards
/// have to be on screen for taps to land.
Future<void> pumpIntoHome(WidgetTester tester, RecipePilotApp app) async {
  tester.view.physicalSize = const Size(540, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Flush every pending entrance-stagger delay timer before the test ends.
/// fake_async fails any test that finishes with live timers, and the stagger
/// cascade (60ms × index + 420ms animation) builds more cards on a tall test
/// viewport than a phone would, so pumps tuned to phone math can leave
/// stragglers. Three generous seconds covers every cascade in the app.
Future<void> flushTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 100));
}
