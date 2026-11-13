# TrainCenter

A **privacy-first, local-first** activity tracker (a Strava-style app for bikes
and shoes) built with Flutter and Material Design 3.

* **Package name:** `com.previx.traincenter`
* **No account, no backend, no analytics, no telemetry.** Every activity, gear
  item and segment lives in a local SQLite database on the device.
* **Platform:** Android 7.0+ (API 24), portrait phone layout. iOS, desktop and
  web are not supported targets in this release.

**Documentation:** [Privacy policy](docs/privacy.md) ·
[Screenshots](docs/screenshots/)

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
    ├── trainercraft/          # TrainerCraft bridge (BLE → local WebSocket)
    └── settings/              # preferences + privacy
```

**State management:** `provider` + `ChangeNotifier`. One controller per
feature (`RecordController`, `ActivitiesController`, `GearController`,
`SegmentsController`, `TrainerCraftController`, `AppSettings`), each owning
exactly one `ChangeNotifier` scope. Repositories are plain, `await`-friendly
classes injected through `MultiProvider`.

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
* Live statistics: distance, current speed, average speed for bicycles or pace
  for shoes, moving time, elapsed time, elevation gain, sample count.
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
    across screen sizes. The card is rendered at **1× text scale**, so a large
    system font cannot change the exported layout. The three statistics are
    anchored to the bottom of the card; the route fills the space above them.
  * **Save PNG** writes to the public **Downloads** folder — MediaStore on
    Android 10+, direct write with legacy storage permission on Android 9 and
    older — so the file is visible in Files without root.
  * **Share** uses the native Android share sheet through `share_plus` and a
    timestamped private copy in `…/app_flutter/exports/`.

### 4.6 Appearance, accessibility and orientation
* Settings → Appearance offers **System / Light / Dark**; the choice is stored
  in the local `settings` table and wired to `MaterialApp.themeMode`. This
  matters on devices such as MIUI on Android 9 that do not forward system dark
  mode to apps.
* At large text sizes the app switches segmented controls to radio lists,
  statistics to a single column, export actions to stacked buttons and the
  Record mini stats to full-width rows. The 320 × 640 dp / 200 % text layout is
  covered by a widget test.
* Maps expose meaningful TalkBack labels; icon buttons use tooltips.
* The app is intentionally **portrait-only** in this release. Landscape made
  the record panel cover the map and clip its own header; a dedicated
  side-by-side layout is required before re-enabling it.

### 4.7 TrainerCraft bridge
`lib/features/trainercraft/` — the former standalone TrainerCraft app bridge is
now a first-class TrainCenter feature, reachable from the game-pad button in
the top app bar.

* **Bluetooth LE speed sensor:** scans for the Cycling Speed and Cadence (CSC)
  service, decodes wheel revolutions and turns them into km/h. The wheel
  circumference can be picked from the usual 700c / MTB presets.
* **Local WebSocket server:** once the sensor is connected, the app listens on
  port 8000 and streams `scriptevent trainercraft:set_speed <km/h>` commands to
  Minecraft Bedrock five times per second. Nothing leaves the local network.
* **Minecraft shortcuts:** the screen detects whether Minecraft Bedrock is
  installed and can open the game (or its Play Store page) through a small
  Android method channel in `MainActivity.kt`.
* **Keeps running across tabs:** the controller lives at the application root,
  so switching back to Record / Activities / Segments / Gear does not stop the
  bridge. A small dot on the app-bar button shows when it is live.
* **Fully theme-derived:** the screen uses only `ColorScheme` roles, so it
  follows TrainCenter's dynamic Material You palette (including the wallpaper
  colours on Android 12+) and the System / Light / Dark setting automatically.

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
| `flutter_blue_plus` | Bluetooth LE speed sensor for the TrainerCraft bridge |

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
| `Online map` | Downloads tiles from the public OSM servers. Tile coordinates and your IP address leave the device — never a route. |
| `Offline map` | Reads tiles downloaded in **Settings → Map → Download offline maps**, falling back to `assets/maptiles/{z}/{x}/{y}.png` when a bundled pack exists. |
| `No map tiles` | No tile request at all. The route is drawn as pure vector geometry. |

### Downloading an area

**Settings → Map → Download offline maps** opens a preview map. Pan and zoom
to frame the area, choose the zoom range (10–17), then download. A 25 % margin
is added around the preview so the taller full-screen record map stays covered.
The screen shows the tile count and an approximate size before starting,
reports progress, and lets the download be cancelled or the stored tiles
cleared later. Tiles are written atomically to the app-support directory as
`offline_maps/{z}/{x}/{y}.png`.

A single download is capped at **1,500 tiles**. The downloader uses a small
number of parallel requests, identifies itself with a TrainCenter user agent,
and sends only the selected tile coordinates plus the device IP address. The
map shows OSM attribution for downloaded tiles as well. Bulk OpenStreetMap
tiles are deliberately not bundled, and the cap plus the visible area preview
keep the feature within the OSM tile usage policy.

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
flutter analyze
flutter test
```

The suite currently has **50 passing tests**:

* `test/widget_test.dart` — geo maths (haversine, segment projection,
  nearest-sample lookup) and the unit formatters.
* `test/formatters_test.dart` — pace rounding, unit suffixes and file sizes.
* `test/offline_map_test.dart` — slippy-map tile maths, atomic download,
  skip-existing resume behaviour, cancellation and storage clearing.
* `test/segment_matcher_test.dart` — segment matching and the personal-best
  logic (match / no match / slower effort / faster effort).
* `test/app_test.dart` — boots the **whole application** against a real
  SQLite database (`sqflite_common_ffi` in-memory FFI), checks navigation,
  empty states, repositories, theme persistence, the export card, the
  slide-to-confirm gesture and opening the TrainerCraft bridge from the app
  bar. It also navigates the main screens and TrainerCraft at
  **320 × 640 dp / 200 % text** to catch layout overflows.
* `test/app_settings_test.dart` — theme and unit preference persistence.
* `test/notification_permission_test.dart` — Android 13+ notification
  permission grant, denial and missing-channel fallbacks.
* `test/export_service_test.dart` — Downloads save channel and failure mapping.
* `test/offline_tiles_test.dart` — bundled tile-pack detection.
* `test/segments_test.dart` — grouped effort loading, PR promotion and segment
  repository behaviour.

The Android emulator run covered API 36; the real-device (Redmi Note 5,
Android 9) screen-off/Doze path remains tracked in `workplan.md`.

---

## 9. Privacy summary

* No API layer, no analytics SDK and no telemetry. The app-level HTTP client is
  used only to download offline map tiles on request; the map dependency uses
  HTTP only for the optional OSM tile requests.
* The only network capability is optional OSM map traffic: online map display
  or a user-initiated offline download. Both can be avoided entirely with
  **No map tiles** and no downloads. The TrainerCraft bridge opens a WebSocket
  server bound to the local network only (port 8000) so Minecraft on the same
  device or LAN can read live speed; it never contacts the internet.
* **Settings → Data → Erase all local data** wipes every table in one go.
* The app declares only the permissions it needs: location, foreground
  service, notifications, wake lock, optional internet access for map tiles,
  Bluetooth scan/connect for the TrainerCraft speed sensor and legacy storage
  access for PNG exports on Android 9 and older.
* Android cloud backup is disabled.
* Known limitation: the SQLite database is not encrypted at rest; see the
  [privacy policy](docs/privacy.md) for the threat model.

The canonical, store-facing version of this summary is
[`docs/privacy.md`](docs/privacy.md).

---

## 10. License

Distributed under the **GNU General Public License v3.0** (GPLv3). See [`LICENSE`](LICENSE.md) for the full license text.

```text
TrainCenter Copyright (C) 2026 lungmen-hkm

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.