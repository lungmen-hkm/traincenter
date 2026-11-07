# TrainCenter privacy policy

**Effective date:** 7 November 2026

**App:** TrainCenter (`com.previx.traincenter`)

TrainCenter is a local-first activity tracker for bicycles and shoes. It has no
account system, no backend, no advertising, no analytics and no telemetry. This
policy explains exactly what stays on your device and the one optional network
feature in the app.

## The short version

* Your activities, GPS tracks, gear, segments and settings are stored only on
  your device.
* We do not collect, sell, rent or share personal data.
* The app has no account, login, cloud sync or crash-reporting SDK.
* Online map tiles are optional. If you choose **Online map**, the app requests
  map tiles from OpenStreetMap servers; those requests contain the tile
  coordinates and your IP address, never your activity or route history.
* Choose **No map tiles** for a build that makes no network requests at all.
* Android cloud backup is disabled.

## What TrainCenter stores on your device

The local SQLite database can contain:

* activity titles, start/end times, distance, speed, moving time, elapsed time
  and elevation gain;
* recorded GPS samples (latitude, longitude, altitude, speed, accuracy and
  timestamp);
* gear names, brands, models, types, default selection and accumulated
  distance;
* segment definitions and segment efforts, including personal-best flags;
* app settings such as appearance, units and map source.

PNG exports are written to the public **Downloads** folder when you tap
**Save PNG** (MediaStore on Android 10+, public Downloads with the legacy
storage permission on Android 9 and older). A private temporary copy is kept in
the app sandbox while using the system share sheet.

The app does not request access to contacts, calendars, photos, the camera, the
microphone, SMS or call logs.

## Network access

TrainCenter declares the Android `INTERNET` and `ACCESS_NETWORK_STATE`
permissions because the map can optionally load tiles.

| Map setting | Network behaviour |
| --- | --- |
| **Online map** | Requests map tiles from the public OpenStreetMap tile servers. The request contains the tile coordinates, a TrainCenter/Flutter user agent and your IP address. It does not contain your activity history, route, account or a persistent identifier. |
| **Offline map** | Reads a PNG tile pack bundled in the app. No network request is made. The current public build does not include a tile pack, so this option is disabled and the reason is shown in Settings. |
| **No map tiles** | No tile requests at all. Routes are drawn as vector lines on a neutral canvas. |

OpenStreetMap is operated by the OpenStreetMap Foundation. Its own privacy
policy applies to tile requests:
<https://osmfoundation.org/wiki/Privacy_Policy>.

The app does not use HTTP cookies, advertising identifiers, fingerprinting or
third-party analytics. Map tiles are the only external network resource.

## Permissions and why they are needed

| Permission | Purpose |
| --- | --- |
| Precise/approximate location | Record the route and live statistics. |
| Background location | Keep recording while the screen is off or the app is in the background. |
| Foreground service (location) | Show the ongoing tracking notification and keep the GPS stream alive. |
| Notifications (Android 13+) | Display the foreground-service notification. Denying it does not block recording; Android simply hides the notification. |
| Wake lock | Keep the screen on during an active recording, when enabled. |
| Internet / network state | Optional online map tiles only. |
| Storage (Android 9 and older only) | Write the PNG to the public Downloads folder. Newer Android versions use MediaStore without this permission. |

## Sharing and exports

When you tap **Share**, Android's system share sheet lets you send the PNG to an
app you choose. That app receives the image and handles it under its own privacy
policy. TrainCenter does not upload the image anywhere itself.

When you tap **Save PNG**, the file is written to your device's public Downloads
folder. It remains there until you delete it.

## Retention and deletion

* Data stays on the device until you delete it.
* **Settings → Data → Erase all local data** deletes all activities, tracks,
  gear, segments, efforts and settings.
* Uninstalling the app removes its private database and temporary exports.
* Files you saved manually to Downloads are not removed by uninstalling the app;
  delete them with your file manager.
* Private temporary share copies are kept in the app sandbox. They are removed
  when the app is uninstalled; automatic cleanup of old share copies is still on
  the roadmap.

## Security and limitations

The local database is currently **not encrypted at rest**. It relies on the
Android app sandbox and the device's own storage encryption. A rooted device, a
debuggable build, or a full filesystem dump could read the database. Android
cloud backup is disabled, and the app does not upload the database anywhere.
Users who need at-rest encryption should treat this as a known limitation until
database encryption is added.

## Children

TrainCenter is a general fitness tool and is not directed at children under 13.
The app does not collect personal data from anyone, including children.

## Changes to this policy

If the app's data practices change, this document will be updated in the
project repository and the effective date above will change. Material changes
will also be noted in the app's release notes.

## Contact

Use the developer support contact shown on TrainCenter's Google Play listing.
For reproducible privacy questions, include the app version and Android version;
do not send a copy of your database or your GPS tracks.

## Google Play Data safety summary

| Question | Answer |
| --- | --- |
| Does the app collect or share any required user data types? | No. |
| Is location collected? | Location is processed on-device for recording and is never transmitted to the developer. Online OSM tile requests contain tile coordinates, the app user agent and the device IP address, not the recorded route. |
| Is data encrypted in transit? | Not applicable: the app does not transmit user data to the developer. OSM tile requests use HTTPS. |
| Can users request data deletion? | Yes: in-app erase and uninstall. |
| Is data sold? | No. |
| Are there ads or analytics? | No. |
