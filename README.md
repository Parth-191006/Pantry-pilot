<div align="center">

<img src="assets/icon/app_icon.png" width="120" alt="Recipe Pilot logo" />

# Recipe Pilot

**Plan it. Shop it. Cook it.** — an offline-first recipe library that turns any
recipe into a tidy, aisle-by-aisle grocery list in one tap.

[![Build APK](https://github.com/Parth-191006/Pantry-pilot/actions/workflows/build-apk.yml/badge.svg)](https://github.com/Parth-191006/Pantry-pilot/actions/workflows/build-apk.yml)
[![Latest release](https://img.shields.io/github/v/release/Parth-191006/Pantry-pilot?label=APK&sort=semver)](https://github.com/Parth-191006/Pantry-pilot/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android-green)](#-install-on-your-phone)
[![Offline](https://img.shields.io/badge/offline-100%25-success)](#-offlinefirst-design)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</div>

---

## 📲 Install on your phone

> **No Flutter, no Android Studio, no building.** Every push to `main` produces
> a ready-to-install APK and attaches it to a permanent release.

1. **[Download the latest APK →](https://github.com/Parth-191006/Pantry-pilot/releases/latest)**
   (<https://github.com/Parth-191006/Pantry-pilot/releases/latest> — look for
   `Recipe-Pilot-v*.apk` under *Assets*)
2. Copy it to your phone (or just open the link on your phone) and tap it.
3. Android will ask to allow installs from your browser — allow it once.
4. **If Play Protect shows a "scanning" or "unknown app" prompt:** tap
   **More details → Install anyway**. That warning appears for *any* app
   installed outside the Play Store; Recipe Pilot is open-source, has
   **no ads, no tracking, and never touches the network**, so there is
   nothing for it to scan for.
5. That's it. Updates install over the old version and keep all your recipes.

Prefer to build it yourself? [Build from source](#-build-from-source) below.

## ✨ What it does

| | |
|---|---|
| 📖 **Library** | 10 built-in recipes across Italian, Mexican, Asian and Mediterranean cuisines — plus unlimited recipes of your own. |
| 🧠 **Offline parser** | Type or paste `2 cups spinach, chopped` and the rule-based parser extracts amount, unit and name, merges synonyms (*green onions → Scallions*), and files it under 🥬 **Produce**. |
| 🛒 **Smart list** | One tap converts any recipe into categorized aisle sections — Produce, Dairy & Eggs, Pantry, Spices… — with a live progress meter. Lines too messy to split safely ("2 cups flour and 1 cup sugar") land in a **Needs review** bucket, shown verbatim instead of guessed. |
| ✅ **Tactile check-off** | Checkboxes pop with a confetti micro-burst, rows dim and strike through, and finishing the list triggers a full celebration. |
| ➕ **Add-recipe studio** | Auto-suggested emoji, paste-a-block → split into rows, and a *live aisle preview* that runs the real parser as you type. |
| ⏱ **Cook-along mode** | One step at a time in huge kitchen-readable text, with a per-step countdown ring (start / pause / resume), a stopwatch for untimed steps, and screen keep-awake so nothing sleeps mid-simmer. Add steps like “Simmer the sauce, 10 min” and the timer builds itself. |
| 🌙 **Night kitchen** | Hand-tuned dark mode with soft glowing icons (toggleable), a cartoon kitchen hero that switches to a night scene, and aurora-lighted splash. |
| 🔒 **Private by design** | Everything lives in Hive boxes on your device. Zero network calls, zero analytics, zero ads. |

## 🎬 The flow

```
Splash ──▶ Home ──▶ Recipe Detail ──▶ Grocery List
             │              │              │
             │  cartoon hero·│ cook along ─▶│  aisle sections · live meter ·
             │  stats ·      │ step-by-step │  check-off micro-interactions ·
             │  quick actions│ + timers     │  confetti at 100%
             │  carousel ·   │              │
             │  filter pills │              │
             └──▶ Add-Recipe Studio ───────┘
```

Every transition is a 340 ms shared-axis slide+fade+scale; every card
stagger-cascades into place; filter pills replay the cascade for the new set.

## 🧩 Screen architecture

```
lib/
├── main.dart                  # bootstrap: Hive init → controller → MaterialApp
├── app_info.dart              # name/version/tagline/description constants
├── app_scope.dart             # InheritedNotifier DI (no provider package)
├── theme/
│   └── app_theme.dart         # Material 3, light+dark hand-tuned from one seed
├── data/
│   ├── models.dart            # Recipe / RecipeStep / GroceryItem / Section / Category
│   ├── ingredient_parser.dart # offline rules → categorized, merged items
│   ├── emoji_suggest.dart     # offline title → cover-emoji keyword map
│   ├── seed_recipes.dart      # built-in recipes with timed cook-along steps
│   └── store.dart             # Hive persistence + AppController (ChangeNotifier)
├── ui/
│   ├── animations.dart        # ALL animation primitives (self-contained)
│   ├── logo.dart              # vector brand mark (minimalist leaf)
│   ├── glow.dart              # glow halos for dark mode (icons/emoji/tiles)
│   └── greeting.dart          # time-aware greeting + duration formatting
└── screens/
    ├── splash_screen.dart         # aurora + logo pulse + shiny wordmark → Home
    ├── home_screen.dart           # cartoon hero, stats, quick actions, shelf
    ├── add_recipe_screen.dart     # the add-recipe studio (paste/rows, steps, preview)
    ├── recipe_detail_screen.dart  # ingredients + steps + two CTAs
    ├── cook_along_screen.dart     # one-step-at-a-time cooking with timers + keep-awake
    ├── grocery_list_screen.dart   # the payoff: categories, check-off, confetti
    └── settings_screen.dart       # dark mode, glow, About, data controls
tool/
├── generate_icons.py           # renders assets/icon/*.png (pure stdlib)
└── patch_gradle_signing.py     # wires release signing into the generated build
```

**One logo, three surfaces.** `lib/ui/logo.dart` draws the mark — a single
minimalist leaf — as vector paths (app bar, splash, About, empty states).
`tool/generate_icons.py` renders the same geometry to the launcher PNGs with
plain `zlib` + `struct`, so the home-screen icon and the in-app logo can never
drift apart.

## 🏗 Build from source

```bash
flutter create . --platforms android   # one-time: generates android/
flutter pub get
python tool/generate_icons.py          # regenerate launcher art after logo edits
python tool/patch_gradle_signing.py    # wire release signing (generated folder)
dart run flutter_launcher_icons        # write launcher icons
flutter run                            # device/emulator
flutter build apk --release            # APK → build/app/outputs/flutter-apk/
flutter test                           # logic + widget tests
```

## 🧠 Offline-first design

- **Storage:** Hive boxes (`recipes`, `grocery_list`, `settings`) hold plain
  maps — no codegen, no TypeAdapters. `GroceryStore` is the *only* file that
  touches Hive; swapping to MMKV or sqlite3 means rewriting one class.
- **State:** one `AppController extends ChangeNotifier` exposes recipes, the
  generated list, filters and checked-state as data; screens subscribe via
  `InheritedNotifier` (`context.app`). Persistence writes are fire-and-forget so
  toggling a checkbox never awaits disk.
- **Parsing:** 100% rule-based, deterministic, and synchronous — identical input
  always yields identical sections, which keeps entrance animations stable
  across restarts.
- **Cook-along timers:** wall-clock deadlines driven by a single 1 Hz ticker —
  pausing can't accumulate drift, and the screen is held awake with
  `wakelock_plus` (one platform-channel flag, no permissions).
- **Imagery:** the hero is a `CustomPainter` cartoon scene and the logo is
  vector paths — the APK ships **zero image assets**, and the app makes **zero
  network calls**.
- **Survives everything:** checked state persists on every toggle; seeds merge
  on every launch so new built-ins appear for existing installs without
  touching your recipes.

## ✨ Animation hookup guide

Every animation lives in `lib/ui/animations.dart` and is a plain widget you can
drop into any screen — nothing is coupled to this app's state layer. Several are
Flutter ports of [React Bits](https://reactbits.dev) components.

| Want… | Use | Notes |
|---|---|---|
| Screen transition | `sharedAxisRoute(page: ...)` | Push with `Navigator.push(context, sharedAxisRoute(...))`. 340 ms shared-axis slide+fade+scale. |
| Tactile checkbox | `StrikeCheckbox(checked, onChanged)` | One controller orchestrates fill → checkmark sweep → pop → confetti micro-burst. Restores settled state when loaded from storage. |
| Checked-row dimming | `CheckedItemAnimator(checked, child)` | AnimatedContainer tint + 55% opacity dim, driven only when `checked` flips. |
| Strikethrough | `AnimatedStrikeText(checked, text)` | `AnimatedDefaultTextStyle` cross-fades the line through the text. |
| Shopping progress | `ProgressRing`, `LinearProgressMeter` | Implicit tweens; the meter glides to every new fraction (the CSS-style width transition). |
| Entrance cascade | `StaggeredEntrance(index: i, child: ...)` | 60 ms cascade slide+fade, cancellable timer (safe under dispose). |
| Completion moment | `SectionConfetti(playing: ...)` | Full-screen particle rain, fires once when the last item is checked. |
| Shiny text *(React Bits)* | `ShinyText(text: ...)` | Masked gradient sweeps across the glyphs on a loop. |
| Rolling numbers *(React Bits)* | `CountUp(value: ...)` | Implicitly animates from 0 (or the previous value) with no timers. |
| Running border beam *(React Bits)* | `BorderBeam(child: ...)` | Rotating sweep-gradient stroke + blurred halo around any child. |
| Aurora backdrop *(React Bits)* | `AuroraBackdrop(intensity: ...)` | Blurred colour field drifting behind the splash / empty states. |
| Press feedback | `PressableScale(onTap: ..., child: ...)` | Springy scale-down on touch, with cursor + semantics for desktop and screen readers. |

To wire a new animated element: build it as a `StatefulWidget` with a single
`AnimationController`, expose inputs as plain constructor params (`checked`,
`progress`, `index`), drive via `didUpdateWidget`, and wrap in
`RepaintBoundary` so off-screen rows don't repaint. That's the entire pattern
used in this codebase.

## ⚡ Performance notes

- One `AnimationController` per micro-interaction (no ticker stew); each
  animated row is a `RepaintBoundary`, and the looping decorations (steam,
  shiny text, border beam, aurora) are painter work inside their own boundaries.
- The heaviest thing here is a `CustomPainter` drawing ~70 circles for 1.6 s of
  confetti.
- Widget tests never call `pumpAndSettle` — the looping animations would not
  settle — so they pump explicit durations and flush stagger timers instead
  (see `test/helpers.dart`).

## 📄 License

[MIT](LICENSE) — cook, fork, ship.
