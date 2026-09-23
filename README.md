# 🌿 Recipe Pilot — recipe library + Recipe → Grocery List (Flutter)

Offline-first cookbook and Recipe-to-Grocery-List converter: keep your recipes,
open one, and the offline parser turns its ingredient lines into categorized
aisle sections you can tick off in the store. Tactile check-off
micro-interactions, a shared-axis screen transition, glow-lit dark mode, and
Hive-backed persistence. **No network, no animation libraries** — Hive is the
only runtime dependency; every animation is hand-built on Flutter's own tools.

## Run it

The repo ships Dart sources only; `flutter create .` generates the Android
platform folder (Gradle wrapper, manifest, icons) on first setup.

```bash
flutter create . --platforms android   # one-time: generates android/
flutter pub get
dart run flutter_launcher_icons       # writes the launcher icons (Android)
flutter run                           # device/emulator
flutter build apk --release           # APK → build/app/outputs/flutter-apk/
```

## Build the APK without installing Flutter (GitHub Actions)

A workflow at `.github/workflows/build-apk.yml` builds the APK in the cloud:

1. Push this folder to a GitHub repository (`main` or `master` branch).
2. Open the repo's **Actions** tab → the **Build Android APK** run.
3. When it goes green, scroll to **Artifacts** → download
   `recipe-pilot-apk-*`, unzip, and sideload the APK onto your phone.

The workflow also **rebrands the Android shell**: it runs
`flutter_launcher_icons` (using the artwork in `assets/icon/`) and rewrites
`android:label` to `Recipe Pilot`, so the launcher shows the real logo and name
even though the platform folder is generated fresh in CI.

Trigger it anytime from **Actions → Build Android APK → Run workflow**.

Optionally verify logic + widgets locally:

```bash
flutter test
```

## Screen architecture

```
lib/
├── main.dart                  # bootstrap: Hive init → controller → MaterialApp
├── app_info.dart              # name/version/tagline/description constants
├── app_scope.dart             # InheritedNotifier DI (no provider package)
├── theme/
│   └── app_theme.dart         # Material 3, light+dark hand-tuned from one seed
├── data/
│   ├── models.dart            # Recipe / GroceryItem / GrocerySection / Category
│   ├── ingredient_parser.dart # offline rules → categorized, merged items
│   ├── emoji_suggest.dart     # offline title → cover-emoji keyword map
│   ├── seed_recipes.dart      # built-in recipes (works on first offline launch)
│   └── store.dart             # Hive persistence + AppController (ChangeNotifier)
├── ui/
│   ├── animations.dart        # ALL animation primitives (self-contained)
│   ├── logo.dart              # vector brand mark (leaf + check badge)
│   ├── glow.dart              # glow halos for dark mode (icons/emoji/tiles)
│   └── greeting.dart          # time-aware greeting + duration formatting
└── screens/
    ├── splash_screen.dart         # aurora + logo pulse + shiny wordmark → Home
    ├── home_screen.dart           # hero, stats, quick actions, carousel, shelf
    ├── add_recipe_screen.dart     # the add-recipe studio (paste/rows, preview)
    ├── recipe_detail_screen.dart  # raw recipe + "Generate grocery list" CTA
    ├── grocery_list_screen.dart   # the payoff: categories, check-off, confetti
    └── settings_screen.dart       # dark mode, glow, celebrations, About, data
tool/
└── generate_icons.py           # renders assets/icon/*.png (pure stdlib)
```

**Flow:** Splash → cross-fade → **Home** (photo hero with a shiny tagline and
Ken Burns drift → library stats → quick actions → “Ready in 30” carousel →
filter pills → the shelf) → shared-axis push → **Recipe Detail** → tap CTA →
parser runs → shared-axis push → **Grocery List** (live meter + ring,
staggered aisle entrance, confetti at 100%).

**Adding a recipe:** the beam-ringed `New recipe` action (or the tip card, or
the empty state) opens the **studio**, which does four things to make typing on
a phone painless:

- **Auto-emoji** — typing “Creamy Garlic Pasta” pre-selects 🍝 from an offline
  keyword map (tap the tile to override).
- **Paste a block → split into rows** — drop a messy ingredient list and one
  tap turns it into individual, editable lines.
- **Live aisle preview** — the *real* parser runs as you type, so each line
  shows the aisle it will land in before you save.
- **Time + tags** — optional chips that feed the “Ready in 30” shelf and the
  home filter pills.

User-created recipes carry a `user_…` id, show a small pencil on their card,
and are the only ones you can delete (built-ins are re-seeded on every launch,
so deleting one would resurrect it).

**Catalog:** 10 built-in recipes across Italian, Mexican, Asian, and
Mediterranean cuisines, each tagged (`Quick & Easy`, `Dinner`, `Vegetarian`,
`High Protein`, cuisine). Filter pills are derived live from the library, so
your own tags surface too. Seeds merge into storage on every launch: new
built-ins appear for existing installs, your recipes are never touched.

## Animation hookup guide

Every animation lives in `lib/ui/animations.dart` and is a plain widget you can
drop into any screen — nothing is coupled to this app's state layer. Several are
Flutter ports of [React Bits](https://reactbits.dev) components.

| Want… | Use | Notes |
|---|---|---|
| Screen transition | `sharedAxisRoute(page: ...)` | Push with `Navigator.push(context, sharedAxisRoute(...))`. 340 ms shared-axis slide+fade+scale. |
| Tactile checkbox | `StrikeCheckbox(checked, onChanged)` | One controller orchestrates fill → checkmark sweep → pop → confetti micro-burst. Restores settled state when loaded from storage. |
| Checked-row dimming | `CheckedItemAnimator(checked, child)` | AnimatedContainer tint + 55% opacity dim, driven only when `checked` flips. |
| Strikethrough | `AnimatedStrikeText(checked, text)` | `AnimatedDefaultTextStyle` cross-fades the line through the text. |
| Shopping progress | `ProgressRing`, `LinearProgressMeter` | Implicit tweens; the meter glides to every new fraction (this is the CSS-style width transition). |
| Entrance cascade | `StaggeredEntrance(index: i, child: ...)` | 60 ms cascade slide+fade, cancellable timer (safe under dispose). |
| Completion moment | `SectionConfetti(playing: ...)` | Full-screen particle rain, fires once when the last item is checked. |
| Shiny text *(React Bits)* | `ShinyText(text: ...)` | Masked gradient sweeps across the glyphs; hold-and-sweep cycle. |
| Rolling numbers *(React Bits)* | `CountUp(value: ...)` | Implicitly animates from 0 (or the previous value) with no timers. |
| Running border beam *(React Bits)* | `BorderBeam(child: ...)` | Rotating sweep-gradient stroke + blurred halo around any child. |
| Aurora backdrop *(React Bits)* | `AuroraBackdrop(intensity: ...)` | Blurred colour field drifting behind the splash / empty states. |
| Press feedback | `PressableScale(onTap: ..., child: ...)` | Springy scale-down on touch, used by cards, pills and CTAs. |

To wire a new animated element: build it as a `StatefulWidget` with a single
`AnimationController`, expose inputs as plain constructor params (`checked`,
`progress`, `index`), drive via `didUpdateWidget`, and wrap in
`RepaintBoundary` so off-screen rows don't repaint. That's the entire pattern
used in this codebase.

## Dark mode, glow and the logo

- **Two hand-tuned palettes from one seed.** Light: cream canvas, charcoal ink,
  cards with a hairline edge. Dark: deep forest-charcoal plates (never pure
  black), a raised card tone, and a lighter sage primary.
- **Glow halos.** `GlowIcon` / `GlowEmoji` / `GlowTile` (in `ui/glow.dart`) paint
  a blurred copy behind the glyph plus a colored `BoxShadow`, so icons read like
  small lamps in dark mode. Light mode keeps them nearly flat, and
  **Settings → Glow effects** switches them off entirely.
- **One logo, three surfaces.** `lib/ui/logo.dart` draws the mark — a leaf with a
  terracotta check badge — as vector paths (app bar, splash, About).
  `tool/generate_icons.py` renders the same geometry to the launcher PNGs with
  plain `zlib` + `struct`, so the home-screen icon and the in-app logo can never
  drift apart. Re-run it after editing the mark:
  `python tool/generate_icons.py`.
- **Internal id stays `pantry_pilot`.** The *display* name is Recipe Pilot
  everywhere (launcher label, splash, About, store listing), but the Dart
  package name — and therefore the Android `applicationId` — is unchanged, so
  the app upgrades in place on your phone and keeps your saved recipes.

## Offline-first design

- **Storage:** Hive boxes (`recipes`, `grocery_list`, `settings`) hold plain
  maps — no codegen, no TypeAdapters. `GroceryStore` is the *only* file that
  touches Hive; swapping to MMKV or sqlite3 means rewriting one class.
- **State:** one `AppController extends ChangeNotifier` exposes recipes, the
  generated list, filters, and checked-state as data; screens subscribe via
  `InheritedNotifier` (`context.app`). Persistence writes are fire-and-forget so
  toggling a checkbox never awaits disk.
- **Parsing:** 100% rule-based, deterministic, and synchronous — identical input
  always yields identical sections, which keeps entrance animations stable
  across restarts. The studio reuses the same parser for its live preview.
- **Imagery:** the hero photograph is bundled at
  `assets/images/hero_produce.jpg` (fetched at build time, loaded from disk — the
  app never touches the network). Drop any produce photo there to rebrand;
  1600 px wide or larger recommended. `assets/icon/` is build-time only and is
  deliberately not bundled into the APK.
- **Checked state survives process death:** every toggle persists immediately;
  `bootstrap()` reloads it on next launch (checkboxes render already-settled, no
  replay of the burst).

## Performance notes

- One `AnimationController` per micro-interaction (no ticker stew); each
  animated row is a `RepaintBoundary`, and the looping decorations (hero drift,
  shiny text, border beam, aurora) are all shader/painter work inside their own
  boundaries.
- The heaviest thing here is a `CustomPainter` drawing ~70 circles for 1.6 s of
  confetti.
- No `setState` in build paths; state changes flow through `notifyListeners` and
  `InheritedNotifier`.
- Widget tests never call `pumpAndSettle` — the looping animations would not
  settle — so they pump explicit durations and flush stagger timers instead
  (see `test/helpers.dart`).
