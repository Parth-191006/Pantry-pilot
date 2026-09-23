# 🥬 Pantry Pilot — Recipe → Grocery List (Flutter)

Offline-first, zero-animation-library demo of the Recipe-to-Grocery-List
converter: parse ingredient lines into categorized aisle sections, with
tactile check-off micro-interactions, a shared-axis screen transition, and
Hive-backed persistence. **No network, no heavy packages** — Hive is the only
dependency.

## Run it

The repo ships Dart sources only; `flutter create .` generates the Android
platform folder (Gradle wrapper, manifest, launcher icons) on first setup.

```bash
flutter create . --platforms android   # one-time: generates android/
flutter pub get
flutter run                            # device/emulator
flutter build apk --release            # APK → build/app/outputs/flutter-apk/
```

## Build the APK without installing Flutter (GitHub Actions)

A workflow at `.github/workflows/build-apk.yml` builds the APK in the cloud:

1. Push this folder to a GitHub repository (`main` or `master` branch).
2. Open the repo's **Actions** tab → the **Build Android APK** run.
3. When it goes green (~5 min), scroll to **Artifacts** → download
   `pantry-pilot-apk-*`, unzip, and sideload the APK onto your phone.

You can also trigger it anytime from **Actions → Build Android APK → Run
workflow**. To change the app id from the default `com.example.pantry_pilot`,
add `--org dev.yourname` to the `flutter create .` step in the workflow (and
locally) before the first release build.

Optionally verify logic + widgets:

```bash
flutter test
```

## Screen architecture

```
lib/
├── main.dart                  # bootstrap: Hive init → controller → MaterialApp
├── app_info.dart              # name/version/description constants
├── app_scope.dart             # InheritedNotifier DI (no provider package)
├── theme/
│   └── app_theme.dart         # Material 3, light+dark from ONE seed color
├── data/
│   ├── models.dart            # Recipe / GroceryItem / GrocerySection / Category
│   ├── ingredient_parser.dart # offline rules → categorized, merged items
│   ├── seed_recipes.dart      # built-in recipes (works on first offline launch)
│   └── store.dart             # Hive persistence + AppController (ChangeNotifier)
├── ui/
│   └── animations.dart        # ALL animation primitives (self-contained)
└── screens/
    ├── splash_screen.dart         # animated brand splash → fades into Home
    ├── home_screen.dart           # hero + recipe library + paste-a-recipe sheet
    ├── recipe_detail_screen.dart  # raw recipe + "Generate grocery list" CTA
    ├── grocery_list_screen.dart   # the payoff: categories, check-off, confetti
    └── settings_screen.dart       # dark mode, About, data controls
```

**Flow:** Splash (logo/tagline animation) → fade → Home (photo hero — bundled
produce image under a dark scrim, time-aware greeting, Ken Burns drift, CTA —
plus category filter pills and the recipe library) → (shared-axis push) →
Recipe Detail → tap CTA → parser runs → (shared-axis push) → Grocery List
(live progress meter + ring, staggered section entrance). Settings (⚙️ corner
on Home) holds dark mode, celebrations, the About text, and data controls.

**Catalog:** 10 built-in recipes across Italian, Mexican, Asian, and
Mediterranean cuisines, each tagged (`Quick & Easy`, `Dinner`, `Vegetarian`,
`High Protein`, cuisine). Filter pills are derived live from the library, so
user-pasted tags would surface too. Seeds merge into storage on every launch:
new built-ins appear for existing installs, user recipes are never touched.

## Animation hookup guide

Every animation lives in `lib/ui/animations.dart` and is a plain widget you
can drop into any screen — nothing is coupled to this app's state layer.

| Want… | Use | Notes |
|---|---|---|
| Screen transition | `sharedAxisRoute(page: ...)` | Push with `Navigator.push(context, sharedAxisRoute(...))`. 340 ms shared-axis slide+fade+scale. |
| Tactile checkbox | `StrikeCheckbox(checked, onChanged)` | Single `AnimationController` orchestrates fill → checkmark sweep → pop → confetti micro-burst. Restores settled state when loaded from storage. |
| Checked-row dimming | `CheckedItemAnimator(checked, child)` | AnimatedContainer tint + 55% opacity dim, driven only when `checked` flips. |
| Strikethrough | `AnimatedStrikeText(checked, text)` | `AnimatedDefaultTextStyle` cross-fades the line through the text. |
| Shopping progress | `ProgressRing(progress: ...)` | TweenAnimationBuilder arc that springs to 100% and swaps to 🎉. |
| List entrance | `StaggeredEntrance(index: i, child: ...)` | 60 ms cascade slide+fade. Set `baseDelay` to sequence after another element. |
| Completion moment | `SectionConfetti(playing: ...)` | Full-screen particle rain, fires once when the last item is checked. |

To wire a new animated element: build it as a `StatefulWidget` with a single
`AnimationController`, expose inputs as plain constructor params (`checked`,
`progress`, `index`), drive via `didUpdateWidget`, and wrap in
`RepaintBoundary` so off-screen rows don't repaint. That's the entire pattern
used in this codebase.

## Offline-first design

- **Storage:** Hive boxes (`recipes`, `grocery_list`, `settings`) hold plain
  maps — no codegen, no TypeAdapters. `GroceryStore` is the *only* file that
  touches Hive; swapping to MMKV or sqlite3 means rewriting one class.
- **State:** one `AppController extends ChangeNotifier` exposes recipes, the
  generated list, and checked-state as data; screens subscribe via
  `InheritedNotifier` (`context.app`). Persistence writes are fire-and-forget
  so toggling a checkbox never awaits disk.
- **Parsing:** 100% rule-based, deterministic (`Random(seed)` in painters),
  and synchronous — identical input always yields identical sections, which
  keeps entrance animations stable across restarts.
- **Imagery:** the hero photograph is bundled at
  `assets/images/hero_produce.jpg` (fetched at build time, loaded from disk —
  the app never touches the network). Drop any produce photo there to
  rebrand; 1600 px wide or larger recommended.
- **Checked state survives process death:** every toggle persists
  immediately; `bootstrap()` reloads it on next launch (checkboxes render
  already-settled, no replay of the burst).

## Performance notes

- One `AnimationController` per micro-interaction (no ticker stew); each
  animated row is a `RepaintBoundary`.
- Animations use only implicit animations + a handful of controllers — the
  heaviest thing here is a `CustomPainter` drawing ~70 circles for 1.6 s.
- No `setState` in build paths; state changes flow through `notifyListeners`
  and `InheritedNotifier`.
