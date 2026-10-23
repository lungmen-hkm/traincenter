# TrainCenter

A **privacy-first, fully offline** activity tracker (a Strava-style app for bikes
and shoes) built with Flutter and Material Design 3.

* **Package name:** `com.previx.traincenter`
* **No account, no backend, no analytics, no telemetry.** Every activity, gear
  item and segment lives in a local SQLite database on the device.

---

## 1. Quick start

```bash
# 1. Bootstrap the project (create + dependencies + platform configuration)
./scripts/create_project.sh

# 2. Run it
flutter run

# 3. Quality gates
flutter analyze
flutter test
```

The script wraps the canonical command:

```bash
flutter create --org com.previx traincenter
```

---

## 2. Architecture

Feature-first layering with a strict dependency direction:

```
lib/
├── main.dart                  # bootstrap: opens the DB, then runApp
├── app.dart                   # MaterialApp + DynamicColorBuilder + providers
│
├── core/                      # cross-cutting infrastructure
│   ├── constants/             # tunable magic numbers (GPS thresholds, …)
│   ├── db/                    # sqflite schema + migrations
│   ├── services/              # platform services (GPS, background, export)
│   ├── theme/                 # Material 3 theme + semantic palette
│   ├── utils/                 # geo maths, unit formatting
│   └── widgets/               # shared widgets (slide-to-confirm, map, …)
│
├── data/                      # persistence
│   ├── models/                # Gear, Activity, TrackPoint, Segment, …
│   ├── repositories/          # local data access (SQL only)
│   └── services/              # application services over repositories
│
├── domain/                    # pure business logic (no Flutter, no DB)
│   └── services/              # SegmentMatcher — segment/PR computation
│
└── features/                  # UI + feature controllers
    ├── shell/                 # M3 NavigationBar shell
    ├── record/                # live recording screen + RecordController
    ├── finish/                # summary + slide-to-save
    ├── activities/            # history + detail
    ├── gear/                  # equipment management
    ├── segments/              # segment list + editor
    ├── export/                # transparent PNG card + share sheet
    └── settings/              # preferences + privacy
```

**State management:** `provider` + `ChangeNotifier`. One controller per
feature (`RecordController`, `ActivitiesController`, `GearController`,
`SegmentsController`, `AppSettings`), each owning exactly one
`ChangeNotifier` scope. Repositories are plain, `await`-friendly classes
injected through `MultiProvider`.

---

## 3. Theming — Material 3 + Dynamic Color

```dart
MaterialApp(
  themeMode: ThemeMode.system,
  theme: AppTheme.build(lightScheme),
  darkTheme: AppTheme.build(darkScheme),
)
```

* `dynamic_color` provides the wallpaper-derived `ColorScheme`
  (`DynamicColorBuilder` + `harmonized()`); a seeded fallback scheme is used
  on platforms without dynamic colours.
* **`useMaterial3: true`** everywhere.
* **Zero hard-coded colours in widgets.** Every widget colour comes from
  `Theme.of(context).colorScheme` (`primary`, `surface`, `onSurface`,
  `secondaryContainer`, …) or from the `ActivityPalette` theme extension.
* `ActivityPalette` (`lib/core/theme/activity_palette.dart`) provides the
  semantic colours the Material 3 scheme does not cover (fast / medium / slow
  effort, PR, route). Its values are **derived** from the active
  `ColorScheme` by rotating the hue of `primary` / `tertiary` — there is not a
  single hex literal in the project.

```dart
final palette = context.activityPalette;   // ThemeExtension<ActivityPalette>
```

---

## 4. Features

### 4.1 Gear management
`lib/features/gear/` — add / edit / delete bicycles and shoes with brand,
model, accumulated distance and a default-gear flag. The accumulated distance
is incremented automatically every time an activity is saved.

### 4.2 Recording & maps
* `flutter_map` + `latlong2` for the map surface.
* `geolocator` for the GPS stream, wrapped behind the `LocationService`
  abstraction so the domain never sees a plugin type. On Android the service
  deliberately sets **`forceLocationManager: true`**: fixes come from the
  platform `LocationManager` instead of Google Play Services. That keeps the
  app fully offline/privacy-preserving and avoids depending on the fused
  provider, which delivered no fixes on a bare emulator image.
* Live statistics: distance, current/avg speed, moving time, elapsed time,
  elevation gain, sample count.
* **Background tracking** through `BackgroundLocationService`. On Android the
  `geolocator` foreground-service configuration (`ForegroundNotificationConfig`)
  promotes the GPS stream to a real foreground service, which is the only
  mechanism Android offers for continuous location in the background.
  `ACCESS_BACKGROUND_LOCATION` and `FOREGROUND_SERVICE_LOCATION` are declared
  in the manifest.
* **Auto pause**: when the athlete has not moved for 20 s the moving time is
  automatically suspended (configurable in the settings).
* **Keep the screen awake**: implemented with a ~40 line method channel
  (`MainActivity.kt` → `FLAG_KEEP_SCREEN_ON`) so no extra plugin is needed.
* Noise filtering: fixes with an accuracy worse than 30 m, implausible jumps
  (> 110 m/s) and GPS jitter below 2 m are dropped.
* Panning the map takes control of the camera; a *recentre* button brings the
  follow mode back.

### 4.3 Finish & save — slide to confirm
`lib/core/widgets/slide_to_confirm.dart` is a custom, fully Material 3
`SlideToConfirm` widget: the thumb has to be dragged past 85 % of the track
before the action fires (with haptic feedback and a spring-back animation).
The activity is only written to the database after the gesture completes, so a
recording can never be saved by an accidental tap.

### 4.4 Segments & personal bests
* A segment is defined by two GPS points picked on a recorded route; the
  selection snaps to the closest recorded sample (`lib/features/segments/segment_editor_screen.dart`).
* `SegmentMatcher` (`lib/domain/services/segment_matcher.dart`) projects every
  recorded sample onto the segment line, splits the track into contiguous
  passes, interpolates the exact crossing times and derives the average
  speed.
* `SegmentEffortService` persists the effort and maintains the **local
  personal best** flags. Matching runs automatically after every saved
  activity.

### 4.5 Activity detail & transparent PNG export
* The detail screen shows distance, average speed, moving/elapsed time,
  elevation, max speed, pace, the route map and the matched segment efforts.
* **Transparent PNG export** (`lib/features/export/`):
  * The card is rendered on a **fully transparent** background.
  * It contains **only** the distance, the average speed, the moving time and
    the route drawn as a **vector polyline** (`RoutePainter`, a `CustomPainter`
    — *not* a map screenshot, so the image stays sharp at any resolution and
    contains no third-party map imagery).
  * `widgets_to_image` captures a fixed **420 × 520 logical-pixel** card at
    **3×** pixel ratio, producing a deterministic **1260 × 1560** PNG. The
    export sheet only *scales the preview* with a `FittedBox`; it never
    resizes the capture boundary, so the saved image stays sharp and identical
    across screen sizes. The three statistics are anchored to the bottom of
    the card; the route fills the space above them.
  * The PNG is written to the app documents directory (`…/exports/`) and can be
    pushed to the **native share sheet** through `share_plus`.

---

## 5. Dependencies

| Package | Purpose |
| --- | --- |
| `dynamic_color` | Material You (wallpaper) colour scheme |
| `provider` | State management (`ChangeNotifier`) |
| `sqflite` + `path` | Local SQLite database |
| `path_provider` | App directories (exports) |
| `geolocator` | GPS + Android foreground-service background tracking |
| `flutter_map` + `latlong2` | Map surface, polylines, markers |
| `widgets_to_image` | Transparent PNG rendering |
| `share_plus` + `cross_file` | Native share sheet |
| `intl` | Locale-aware date/number formatting |
| `uuid` | Stable identifiers |

### Three deliberate deviations from the initial brief

1. **`dynamic_color: ^1.7.0` instead of `^2.1.0`.**
   `dynamic_color` 2.x depends on the standalone `material_ui` package, whose
   `ColorScheme` is a **different Dart type** from `package:flutter/material.dart`'s
   `ColorScheme`. Since Flutter 3.47 still ships the Material library inside
   the SDK, only the 1.7.x line produces a scheme that can be handed to
   `MaterialApp(theme: ...)`.

2. **No `flutter_background_service`.**
   `flutter_background_service_android` 6.x still builds against Android Gradle
   Plugin 7.4.2 and uses the `lintOptions` DSL that was removed in AGP 9 —
   it does not compile with the AGP 9.1 toolchain this project targets.
   Instead, background tracking is implemented on top of the foreground service
   that already ships with `geolocator`
   (`AndroidSettings.foregroundNotificationConfig`), which is native, needs no
   extra dependency and no duplicated isolate plumbing.
   The `BackgroundLocationService` abstraction keeps the door open: a
   `flutter_background_service` isolate can be dropped in later without
   touching the recording code.

3. **The slide-to-save control is hand-written** instead of using
   `flutter_sliding_box`. That package is a bottom-sheet-style container and
   does not ship a `SlideAction`; a bespoke widget gives the required
   gesture semantics and keeps the control 100 % theme-derived.

---

## 6. Offline map tiles

The map tile source is switchable in **Settings → Map**:

| Source | Behaviour |
| --- | --- |
| `OpenStreetMap (online)` | Downloads tiles from the public OSM servers. Only tile coordinates leave the device — never a route. |
| `Offline tiles (bundled)` | Reads `assets/maptiles/{z}/{x}/{y}.png`. See `assets/maptiles/README.md`. |
| `No tiles (vector only)` | No tile request at all. The route is drawn as pure vector geometry. |

---

## 7. Data model

```sql
gears           (id, name, brand, model, type, total_distance_meters,
                 is_default, created_at, updated_at)
activities      (id, title, gear_id, started_at, ended_at, distance_meters,
                 moving_time_ms, elapsed_time_ms, avg_speed_mps, max_speed_mps,
                 elevation_gain_meters, note, created_at)
track_points    (id, activity_id, seq, lat, lng, altitude, speed, accuracy,
                 timestamp)
segments        (id, name, activity_id, start_lat/lng/altitude,
                 end_lat/lng/altitude, distance_meters, created_at)
segment_efforts (id, segment_id, activity_id, time_ms, avg_speed_mps, is_pr,
                 achieved_at)
settings        (key, value)
```

Foreign keys are enabled (`PRAGMA foreign_keys = ON`) so deleting an activity
removes its GPS track and its segment efforts.

---

## 8. Testing

```bash
flutter test
```

* `test/widget_test.dart` — geo maths (haversine, segment projection,
  nearest-sample lookup) and the unit formatters.
* `test/segment_matcher_test.dart` — segment matching and the personal-best
  logic (match / no match / slower effort / faster effort).
* `test/app_test.dart` — boots the **whole application** against a real
  SQLite database (`sqflite_common_ffi` in-memory FFI), checks the four
  navigation destinations, the empty states, the repositories and the
  slide-to-confirm gesture semantics.

---

## 9. Privacy summary

* No `http` client, no API layer, no analytics SDK in the dependency tree.
* The only network capability is the optional OSM tile download, which can be
  switched off entirely.
* **Settings → Data → Erase all local data** wipes every table in one go.
* The app declares only the permissions it needs: location, foreground
  service, wake lock and (optional) internet access for map tiles.
