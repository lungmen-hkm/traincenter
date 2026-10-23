# TrainCenter — Known Issues & Delivery Plan

_Last updated: 23 October 2026_

Package: `com.previx.traincenter` · Platform: Flutter / Android (minSdk 24, targetSdk 36)
Storage: local SQLite only · No backend, account, sync, analytics or telemetry.

---

## 1. Status at a glance

| Item | Status |
| --- | --- |
| `flutter analyze` | **0 issues** |
| `flutter test` | **27/27 passing** |
| Runtime target | Android 16 / API 36 emulator (`emulator-5554`) |
| Screens tested | 1080×2400 px (411×914 dp) and 720×1280 px @ 320 dpi (360×640 dp) |
| Release APK | Rebuilt and installed with the latest fixes |
| Debug APK | Used for `run-as` database inspection; release APK is not debuggable |
| Remaining test data | 6 activities, 1 segment, 2 segment efforts, 1 gear (4.16 km) |

**Verified end-to-end on the emulator**

* Gear CRUD, default star, accumulated distance.
* Live GPS recording, live stats, polyline, follow mode, pause/resume.
* Slide-to-save, activity persistence, activity list and detail, route map.
* Segment creation from a recorded route, automatic effort/PR creation, a slower
  effort that is **not** a PR, PR badge on the segment and activity detail.
* Transparent PNG export: **1260×1560**, only route + distance + average speed +
  moving time, alpha-0 corners, ~97.6 % fully transparent pixels.
* Native Android share sheet (“Sharing image”, “My TrainCenter activity”).
* Background recording: foreground service stays alive after Home, points and
  distance continue to accumulate.
* Activity deletion: gear mileage is reduced again and the device DB returns to
  its previous total.
* Export sheet on a 360×640 dp screen: scrollable, no overflow, Save/Share
  reachable, captured PNG still 1260×1560.

---

## 2. Fixes completed during this debugging pass

| # | Problem found at runtime | Fix | Verification |
| --- | --- | --- | --- |
| 1 | Android fused location produced no fixes on the emulator / depends on Play Services | Force the native `LocationManager` (`forceLocationManager: true`) in `GeolocatorLocationService` | Live recording works offline on the emulator |
| 2 | Default gear was not visible until recording started | Preload the default gear in `ensureDefaultGear()` | Gear shown before Start; saved activity uses it |
| 3 | Live map did not follow the rider; segment editor kept the old camera | External `MapController`, follow mode, `ValueKey(activityId)` map reset | Follow mode and activity switching verified |
| 4 | Export sheet overflowed by 34 px; preview resized the capture boundary | Scrollable sheet + fixed 420×520 card scaled with `FittedBox` | No overflow on 360×640 dp; PNG 1260×1560 |
| 5 | Export stats floated above a large empty area | `Spacer()` pushes stats to the bottom of the fixed card | Stats bbox reaches y=1538 at 3× |
| 6 | Segments tab always said “No effort recorded yet” even though DB rows existed; tab did not refresh after a ride | `SegmentsController.load()` now loads every effort history; finish screen reloads activities/gear/segments; tabs refresh on selection | “PR 01:20 · 2 efforts” shown after saving |
| 7 | Elapsed time grew when the summary was dismissed and “Finish” was tapped again; Pause button was shown on a finished session | `stop()` is idempotent; finished state shows “Review summary” instead of Pause/Finish | Re-opening summary kept elapsed frozen at 00:22 |
| 8 | Untitled activities were indistinguishable in the segment source dropdown | Dropdown label now includes date/time and distance | Five entries distinguishable by time/distance |
| 9 | Deleting an activity did **not** reduce gear mileage | `GearRepository.subtractDistance()` (clamped at 0), called from `ActivitiesController.delete()` | Gear total 4156.63 → 4249.83 → 4156.63 after delete |
| 10 | Deleting the activity that held a segment PR left the next effort flagged as non-PR | `SegmentRepository.recalculatePersonalBests()` after activity deletion | Unit test promotes the 110 s effort correctly |
| 11 | A cached first GPS fix could create a phantom straight line (0.97 km on a 300 m test) | Buffer the first two fixes; keep both only if the pair is physically plausible, otherwise discard the cached one | 1.4 km stale fix rejected; summary showed 0.05 km |
| 12 | Max speed could be lower than average speed (reported speed 0 on the emulator) | Use `max(reportedSpeed, impliedSpeed)` for max speed | Summary 87.1 km/h max vs 83.8 km/h avg |
| 13 | Out-of-order / teleporting fixes could be appended | Reject non-positive time deltas and implausible jumps | Covered by filter logic and stale-fix regression test |
| 14 | Android cloud backup was enabled by default, contradicting the privacy promise | `android:allowBackup="false"` and `fullBackupContent="false"` | Manifest inspected after build |
| 15 | No UI to delete a segment | Delete action + confirmation in the segment editor | Delete icon and dialog verified; actual deletion path not executed at runtime |
| 16 | No regression test for the segments list / PR logic / stale first fix | 4 new tests (effort loading, PR comparison, PR promotion, first-fix buffer) | 27/27 tests pass |

---

## 3. Known issues and remediation plan

### P0 — release / privacy blockers

#### P0-1. Release build is signed with the Android debug keystore

* **Current state:** `android/app/build.gradle.kts` uses `signingConfigs.getByName("debug")` for release.
* **Impact:** Cannot distribute through Google Play or trust the APK as a production artifact; debug key is public.
* **Plan:**
  1. Generate an upload keystore (`keytool -genkeypair …`).
  2. Read it from `android/key.properties` (never commit it).
  3. Add a `release` signing config and switch `buildTypes.release.signingConfig`.
  4. Store the keystore and passwords in CI secrets.
* **Acceptance:** `apksigner verify --print-certs app-release.apk` shows the upload certificate; CI reproduces the signed APK.

#### P0-2. Background tracking is only verified on the emulator, in the foreground-to-Home case

* **Current state:** Home + 4 injected fixes produced 5 points / 0.19 km while the app was backgrounded; `GeolocatorLocationService` is `isForeground=true`, type `location`.
* **Not yet covered:** screen off/locked, Doze, OEM battery killers (Xiaomi/Samsung/Huawei), long rides, process death, Android 13+ notification permission, Bluetooth/GPS lost/reacquired.
* **Plan:** run a 30–60 minute real-device test with screen off; add “battery optimization” guidance; declare/request `POST_NOTIFICATIONS`; verify the foreground notification is visible on Android 13+; add a service-restart strategy if the stream dies.
* **Acceptance:** distance/time continue for 30+ minutes with the screen off and the app backgrounded; notification visible; documented OEM exceptions.

#### P0-3. Online OpenStreetMap tiles are unverified; the emulator has no DNS

* **Current state:** Emulator has IP connectivity but DNS resolution fails (`ping tiles.openstreetmap.org` → unknown host). The app is currently set to “No tiles (vector only)”.
* **Impact:** The online tile path is untested end-to-end; the “fully offline” claim needs qualification because `INTERNET` is declared.
* **Plan:**
  1. Test on a real network/device with the OSM source selected.
  2. Add a tile error/fallback state and a user-visible “tiles unavailable” hint.
  3. Set a proper `User-Agent` (`com.previx.traincenter`) and respect the OSM tile usage policy.
  4. Consider making online tiles **opt-in** and ship an offline-only build variant without `INTERNET`.
* **Acceptance:** online tiles render on a real network; offline/no-tile fallback is graceful; no route data is ever sent (only tile coordinates).

#### P0-4. The bundled-offline tile source is an empty placeholder

* **Current state:** `assets/maptiles/` contains only `README.md`; selecting “Offline tiles (bundled)” renders a blank map.
* **Impact:** A selectable setting appears broken.
* **Plan:** bundle a small, licensed tile set (or a vector basemap), **or** hide/disable the option until assets exist and show an empty-state message.
* **Acceptance:** selecting offline tiles shows either real tiles or an explicit “no offline tiles bundled” state; no blank screen.

#### P0-5. Database is plaintext on disk

* **Current state:** SQLite file under `databases/traincenter.db`; cloud backup is now disabled, but a rooted device or a filesystem dump can read all activities.
* **Impact:** Privacy-first claim is partially weakened; acceptable for many users, but should be a conscious decision.
* **Plan:** decide the threat model; if encryption is required, adopt SQLCipher (`sqflite_sqlcipher`) with a key stored in the Android Keystore; otherwise document the limitation in the privacy notes.
* **Acceptance:** documented decision + threat model; if enabled, DB unreadable without the keystore key.

### P1 — functional gaps / test coverage

#### P1-1. Auto-pause and moving-time accuracy are untested on real hardware

* **Current state:** Auto-pause defaults off; implementation uses only `fix.speedMps` for standstill detection. The emulator reports 0 or unreliable speed, so the distance-derived speed can disagree.
* **Plan:** on a real device, test auto-pause at traffic lights and walking; consider using `max(reported, implied)` or a smoothed speed for the stationary timer; add a unit test with synthetic fixes.
* **Acceptance:** auto-pause triggers after the configured standstill, resumes on movement, and never pauses a moving rider.

#### P1-2. Integration/widget coverage is still thin around the new behavior

* **Current state:** 27 unit/widget tests, including the segment matcher, effort loading, PR promotion and first-fix buffer.
* **Missing:**
  * Widget test for “Segments tab reloads after save”.
  * Widget test for “Review summary does not reset elapsed”.
  * Golden/widget test for the export sheet at 320/360/411 dp and 200 % text scale.
  * Widget test for the segment source dropdown labels.
  * Integration test for background tracking + slide-to-save.
* **Plan:** add these to `test/` and a small `integration_test/` suite; run in CI.
* **Acceptance:** every bug fixed in this pass has an automated regression test.

#### P1-3. Segment matching edge cases

* **Current state:** matcher requires a contiguous pass covering ≥85 % of the segment, uses a 35 m corridor and 60 m endpoint radius, and interpolates crossing times.
* **Not yet covered:** multiple laps/passes, long GPS gaps, pauses inside a segment, routes that cross but do not follow the segment, start/end points within the same sample, segment shorter than the minimum, GPS drift at the endpoints.
* **Plan:** add synthetic matcher tests for forward/backward passes, out-and-back, gaps, and near-misses; validate corridor/radius tuning on real rides.
* **Acceptance:** false positives are rejected; valid PRs are detected on repeated laps; tests cover each case.

#### P1-4. Activity/gear editing and destructive-action messaging

* **Current state:** only the activity title can be edited after saving; gear assignment/notes cannot be changed; deleting an activity does not warn that its segment efforts/PRs will disappear; deleting a gear sets activities’ `gear_id` to NULL.
* **Plan:** add edit screens/actions for title, notes and gear; adjust gear mileage when gear changes; extend delete confirmations with “this also deletes X segment efforts/PRs”; add undo where practical.
* **Acceptance:** edit/delete flows keep gear totals and PR flags consistent; confirmation text explains side effects.

#### P1-5. Export file management

* **Current state:** every save writes a new file into `…/app_flutter/exports/`; names are timestamp-based; there is no gallery picker or cleanup.
* **Impact:** unbounded storage growth; duplicates; users cannot see past exports from inside the app.
* **Plan:** name files by activity + timestamp, add an “Exports” list/delete action, optionally write to the user-visible Pictures directory via MediaStore, and handle storage-full/share failures.
* **Acceptance:** export list works, old files can be deleted, failures show actionable messages.

#### P1-6. Backend/device support is Android-only

* **Current state:** iOS permissions and the share path are configured, but no iOS device/simulator test was possible; desktop/web are not targets.
* **Plan:** run the iOS build on a Mac/simulator, verify background location modes, share sheet, and dynamic color fallback; explicitly document supported platforms.
* **Acceptance:** iOS smoke test passes or the platform is marked unsupported.

### P2 — UX, accessibility and polish

#### P2-1. Permission UX / notification permission

* **Current state:** location/background permissions are requested via `geolocator`; `POST_NOTIFICATIONS` is not declared or requested. Background location requires the user to choose “Allow all the time” in system settings.
* **Plan:** add a first-run rationale screen, a “background permission missing” card, a link to app settings, and the Android 13 notification permission request.
* **Acceptance:** users understand why each permission is needed; recording still works with “while in use” (foreground only) and explains the limitation.

#### P2-2. Small-screen / accessibility layout

* **Current state:** export works at 360×640 dp; “Follow app theme” wraps to three lines in the segmented control. Text scale, landscape, tablets and split-screen are untested.
* **Plan:** run `flutter test` with 200 % text scale; test 320 dp width, landscape, tablets; shorten labels (“System” instead of “Follow app theme”), allow the sheet to expand, and add semantics labels.
* **Acceptance:** no overflow at 320 dp / 200 % text; all controls reachable; TalkBack labels are meaningful.

#### P2-3. Activity naming and metadata discoverability

* **Current state:** title is optional and below the fold on the summary; untitled activities display as “Activity”. The segment dropdown is now distinguishable, but the activity list is not.
* **Plan:** prompt for a title (or auto-name by time/type), default to “Ride · 23 Oct, 08:56”, show notes snippets, and keep the title field visible before the slide-to-save control.
* **Acceptance:** every activity has a useful display name without requiring extra typing.

#### P2-4. Localization and units

* **Current state:** UI strings are hardcoded English; metric/imperial units and locale-aware formatting are supported by `intl`.
* **Plan:** extract strings to ARB files, add at least English + one locale, test right-to-left layout, and verify unit changes across all screens/exports.
* **Acceptance:** `flutter gen-l10n` pipeline; no hardcoded user-facing strings; units consistent everywhere.

#### P2-5. App icon, splash, store assets, documentation

* **Current state:** default Flutter launcher icon/splash; README covers architecture but there is no changelog/store listing.
* **Plan:** add adaptive icon, splash, screenshots, feature graphic, changelog, and a privacy note (“location and activities stay on device; optional OSM tile requests”).
* **Acceptance:** store-ready visual assets and documented privacy behavior.

#### P2-6. OSM tile policy and optional network permission

* **Current state:** `INTERNET`/`ACCESS_NETWORK_STATE` are always declared; the OSM source is available.
* **Plan:** add a build flavor (`offline` vs `online`) or manifest placeholder; add attribution/usage-policy notes; ensure no request is made in “No tiles” mode.
* **Acceptance:** offline flavor has no `INTERNET` permission; online flavor follows OSM policy.

### P3 — engineering hygiene / performance

#### P3-1. No git repository or CI

* **Current state:** the workspace is not a git repo; no automated pipeline.
* **Plan:** initialize git, add a `.gitignore` (build/, .dart_tool/, key.properties, keystores, exports), make an initial commit, add CI running `flutter analyze`, `flutter test` and a debug build.
* **Acceptance:** reproducible clean checkout + green CI.

#### P3-2. N+1 effort queries / full PR recomputation

* **Current state:** `SegmentsController.load()` issues one effort query per segment; activity deletion recomputes PR flags for every effort.
* **Impact:** negligible at current scale, but O(segments) queries and a full-table update can grow.
* **Plan:** batch effort loading with a single join/group query; recompute only affected segments on delete.
* **Acceptance:** load time stays <100 ms with 500 segments/efforts on a mid-range device.

#### P3-3. Database migrations and restore path

* **Current state:** schema version 1, no migration tests, no import/restore.
* **Plan:** add migration tests from every released version; define backup/restore (encrypted file export) if desired; keep destructive wipe behind confirmation.
* **Acceptance:** upgrade preserves data; migration tests pass.

#### P3-4. Settings/wipe safety during recording

* **Current state:** “Erase all local data” is reachable from the app bar even while a recording is active.
* **Plan:** disable destructive settings while recording, or stop/discard with an explicit confirmation first.
* **Acceptance:** no data wipe can run while a session is active without an explicit stop/discard.

---

## 4. Test matrix to close the gaps

| Layer | Cases |
| --- | --- |
| Unit | `SegmentMatcher` (forward, reverse, out-and-back, gaps, near-miss), formatters, PR promotion, gear subtraction, first-fix buffer |
| Widget | navigation, gear CRUD, default gear, segment dropdown labels, segments reload, review-summary elapsed, export sheet at 320/360/411 dp, 200 % text scale |
| Integration | record → pause → resume → finish → slide-to-save → detail → export → share; background recording with screen off; kill/restart; permission denial/revocation |
| Devices | API 24 minimum, API 31/33/34/36, small/large phone, tablet, landscape; one OEM with aggressive battery management |
| Network | online OSM, DNS failure, slow/interrupted tiles, no network, offline tiles present/missing |
| Storage | full disk, export failure, share target absent, large track (10k points) |

**Commands**

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

**Suggested CI gate:** analyze + tests + debug build on every PR; release build on tags.

---

## 5. Release checklist

- [x] `flutter analyze` clean
- [x] `flutter test` green (27/27)
- [x] Runtime smoke test on Android 16 emulator
- [x] Transparent PNG dimensions/alpha verified
- [x] Native share sheet verified
- [x] Background foreground service verified (Home)
- [x] Android backup disabled
- [x] Release APK rebuilt with latest fixes
- [ ] Release keystore / signing config
- [ ] Real-device background + screen-off test
- [ ] Real-network online-tile test
- [ ] Offline tile assets (or option disabled)
- [ ] Notification permission flow (Android 13+)
- [ ] Accessibility / large-text / landscape pass
- [ ] Store listing, screenshots, privacy note
- [ ] Git repository + CI pipeline

---

## 6. Recommended order for the next iteration

1. **Release signing + CI** (unblocks distributable builds and repeatable tests).
2. **Real-device background/auto-pause matrix** (the highest-risk untested runtime path).
3. **Map tiles**: verify online, ship or disable offline tiles, add fallback UX.
4. **Automate the regressions fixed here** (segments reload, review summary, export sheet, first fix).
5. **Editing/destructive-action UX** (activity gear/notes, delete warnings, export cleanup).
6. **Accessibility + localization + store assets**.
7. **At-rest encryption decision** and migrations/restore.

---

## 7. Reproduction notes for the next tester

* GPS simulator: the user-provided `./debug.py` sends `adb emu geo fix`; stop it with
  `pkill -f '[d]ebug[.]py'` (the bracket avoids killing the invoking shell).
* Record a segment pass:
  1. Create a segment from an existing activity (Segments → Create segment →
     pick source → tap start/end on the map → name → save).
  2. Record a new ride along the same line; finish and slide to save.
  3. Segments should show `PR …`; activity detail should show
     “New personal best”. A slower pass should show “Segment effort”.
* Inspect the DB on a **debug** build (release is not debuggable):
  ```bash
  adb exec-out run-as com.previx.traincenter cat databases/traincenter.db > /tmp/traincenter.db
  sqlite3 /tmp/traincenter.db "select * from segment_efforts;"
  ```
* Export path: `/data/user/0/com.previx.traincenter/app_flutter/exports/`.
* Online OSM testing requires working DNS; the current emulator cannot resolve
  `tiles.openstreetmap.org`, so the app is intentionally set to “No tiles”.

---

_This document is the single source of truth for the remaining work. Update the
status column and checkboxes as items are closed._
