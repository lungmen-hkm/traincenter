# TrainCenter — store listing kit

This file contains the copy and declarations needed to publish TrainCenter on
Google Play. Replace the values in `<angle brackets>` before uploading. The
store listing is for version **1.0.0 (1)**.

## App identity

| Field | Value |
| --- | --- |
| App name | **TrainCenter** |
| Package | `com.previx.traincenter` |
| Version | `1.0.0` (version code `1`) |
| Category | Health & Fitness / Sports |
| Price | Free |
| Contains ads | No |
| In-app purchases | No |
| Account required | No |
| Minimum Android | 7.0 (API 24) |
| Supported orientation | Portrait only in this release |

## Short description (80 characters max)

```text
Privacy-first ride and shoe tracker. Local GPS, segments and PNG exports.
```

Character count: 75.

Alternative:

```text
Offline bike and shoe tracker. No account, no ads, no telemetry.
```

Character count: 64.

## Full description

```text
TrainCenter is a privacy-first activity tracker for bicycles and shoes. It
records your rides, keeps your history on your phone and never asks for an
account.

YOUR DATA STAYS YOURS
• No account, no sign-up, no cloud sync, no ads and no analytics.
• Activities, GPS tracks, gear, segments and settings live in a local database
  on your device.
• Android cloud backup is disabled.
• No data is sold, rented or sent to a TrainCenter server.

RECORD AND REVIEW
• Live distance, speed, moving time, elapsed time and elevation.
• Background recording with an Android foreground-service notification.
• Automatic pause when you stop moving, and automatic resume when you ride on.
• Review the route, statistics and matched segments after every activity.

SEGMENTS AND PERSONAL BESTS
• Create a segment from any recorded route.
• TrainCenter matches later passes automatically and keeps your local PR.
• See every effort and the current personal best on the segments screen.

BIKE AND SHOE GARAGES
• Track bicycles and shoes separately.
• Set a default gear item and keep accumulated distance in sync when activities
  are added or deleted.

SHARE A CLEAN PNG
• Export a transparent PNG card with distance, average speed, moving time and a
  sharp vector route — no third-party map imagery.
• Save it directly to your public Downloads folder or send it through the
  Android share sheet.

MAPS ON YOUR TERMS
• Online map: load OpenStreetMap tiles. Tile coordinates and your IP address
  leave the device, never your route history.
• Offline map: use a bundled tile pack when one is present in the build.
• No map tiles: draw the route as pure vector geometry with no network requests.

DESIGNED TO BE USABLE
• Material 3 light and dark themes, with System / Light / Dark control.
• Responsive layouts for small phones and large system text.
• Meaningful accessibility labels for maps and key controls.
• Portrait layout tuned for one-handed recording.

PRIVACY BY DEFAULT
Read the full policy: <privacy-policy-url>

TrainCenter does not collect personal data. Location is processed on-device.
Optional online map tiles are the only network feature and can be switched off.
```

## What's new — 1.0.0

```text
First public release.

• Local GPS recording with live statistics and background tracking
• Segments, automatic effort matching and personal bests
• Bicycle and shoe garages with accumulated distance
• Transparent PNG export to the Android share sheet or Downloads
• Light and dark Material 3 themes
• Small-screen and large-text accessibility improvements
• No account, ads, analytics or telemetry
```

## Screenshot plan

All screenshots are 1080 × 1920 PNG (9:16, 24-bit RGB, no alpha), captured on
an Android 16 emulator with clean demo-mode status icons. They live in
[`docs/screenshots/`](screenshots/).

| # | File | Suggested Play caption |
| --- | --- | --- |
| 1 | `01_record.png` | Record a ride with live distance, speed and elevation. |
| 2 | `02_activities.png` | Every activity stays on your device. Review totals and history. |
| 3 | `03_activity_detail.png` | See the route and full statistics after each ride. |
| 4 | `04_segments.png` | Create segments and track your local personal bests. |
| 5 | `05_gear.png` | Keep bicycles and shoes organised with their own mileage. |
| 6 | `06_settings.png` | Choose appearance, units and how map tiles load. |
| 7 | `07_export.png` | Save or share a clean, transparent PNG route card. |
| 8 | `08_dark_record.png` | A full Material 3 dark theme for night rides. |

Play Console order: upload them in the numbered order above.

## Store graphics

| Asset | Size | File |
| --- | --- | --- |
| App icon | 512 × 512 PNG, 32-bit | [`docs/store/icon-512.png`](store/icon-512.png) |
| Feature graphic | 1024 × 500 PNG/JPEG | [`docs/store/feature-graphic.png`](store/feature-graphic.png) |
| Phone screenshots | 1080 × 1920 PNG (24-bit, no alpha) | [`docs/screenshots/`](screenshots/) |

The Android launcher uses the matching adaptive icon and a branded splash
background in `android/app/src/main/res/`.

## Privacy policy URL

Publish [`docs/privacy.md`](privacy.md) at a stable public HTTPS URL — for
example GitHub Pages, the repository's rendered Markdown or the project
website — and paste that URL into:

* Play Console → App content → Privacy policy;
* the full description placeholder `<privacy-policy-url>`.

The policy must remain publicly reachable without a login.

## Play Console declarations

### App access

No login, account or restricted content. Select **All functionality is
available without special access**.

### Ads

No ads.

### Content rating questionnaire

* Category: Health & Fitness / Sports.
* No violence, sexual content, profanity, drugs, gambling or user-generated
  content.
* Location is used for the core fitness functionality and is not shared.
* Expected rating: Everyone / PEGI 3.

### Target audience

13+ (or the equivalent general audience setting). TrainCenter is not designed
for children and does not collect data from anyone.

### Data safety

| Section | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| Is all user data encrypted in transit? | Not applicable — no user data is transmitted to the developer |
| Do you provide a way for users to request data deletion? | Yes — Settings → Erase all local data, or uninstall |
| Is data sold? | No |
| Are ads or analytics SDKs present? | No |

Location is processed on-device for recording. If the reviewer asks about map
tiles: OSM tile coordinates, the app's user agent and the device IP address
reach the tile server, and the feature can be disabled with **No map tiles**.

### Permissions declaration

| Permission | User-facing reason |
| --- | --- |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Record the route and live statistics. |
| `ACCESS_BACKGROUND_LOCATION` | Continue recording with the screen off or the app backgrounded. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | Keep the GPS stream alive with an ongoing notification. |
| `POST_NOTIFICATIONS` | Show the foreground-service notification on Android 13+. Denial does not block recording. |
| `WAKE_LOCK` | Optional keep-screen-on during recording. |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Optional online OpenStreetMap tiles. |
| `WRITE_EXTERNAL_STORAGE` (maxSdk 28) | Save PNGs to public Downloads on Android 9 and older. |

## Release notes checklist

- [ ] Privacy policy published at a public HTTPS URL and added to Play Console.
- [ ] `docs/store/icon-512.png` uploaded as the store icon.
- [ ] `docs/store/feature-graphic.png` uploaded.
- [ ] Eight phone screenshots uploaded in order.
- [ ] Short description, full description and What's new pasted.
- [ ] Data safety form matches the table above.
- [ ] Content rating questionnaire completed.
- [ ] Target audience set to 13+.
- [ ] Internal testing track installed from Play and smoke-tested.
- [ ] Version code bumped for every subsequent upload.
- [ ] Real-device screen-off/Doze run completed (tracked in `workplan.md`).

## Known limitations to disclose honestly in support replies

* Landscape is intentionally disabled in this release; the app is portrait-only.
* The public build does not bundle an offline tile pack, so **Offline map** is
  disabled. **No map tiles** works fully offline.
* The local database is not encrypted at rest yet; see the privacy policy.
* The screen-off/Doze test is still pending on a physical device.
