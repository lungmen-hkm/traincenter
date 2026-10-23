#!/usr/bin/env bash
#
# TrainCenter — project bootstrap script
# ---------------------------------------
# Creates the Flutter project skeleton with the correct organisation id and
# package name, applies the dependency set and regenerates the platform
# folders.
#
# Usage:
#   ./scripts/create_project.sh            # create the project in ./traincenter
#   ./scripts/create_project.sh <target>   # create it in another directory
#
set -euo pipefail

TARGET_DIR="${1:-traincenter}"
ORG="com.previx"
PROJECT_NAME="traincenter"
PACKAGE_NAME="$ORG.$PROJECT_NAME"

echo "==> Creating $PACKAGE_NAME in '$TARGET_DIR'"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: the Flutter SDK is not on PATH." >&2
  echo "       Install it from https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

flutter --version

# ---------------------------------------------------------------------------
# 1. Scaffold the project
# ---------------------------------------------------------------------------
if [ -d "$TARGET_DIR/lib" ] && [ -f "$TARGET_DIR/pubspec.yaml" ]; then
  echo "==> '$TARGET_DIR' already contains a Flutter project, skipping create."
else
  flutter create \
    --org "$ORG" \
    --project-name "$PROJECT_NAME" \
    --platforms=android,ios,web \
    "$TARGET_DIR"
fi

cd "$TARGET_DIR"

# ---------------------------------------------------------------------------
# 2. Dependencies
# ---------------------------------------------------------------------------
echo "==> Adding dependencies"
flutter pub add \
  dynamic_color:^1.7.0 \
  provider \
  sqflite \
  path \
  path_provider \
  geolocator \
  flutter_map \
  latlong2 \
  widgets_to_image \
  share_plus \
  cross_file \
  intl \
  uuid

# ---------------------------------------------------------------------------
# 3. Platform configuration
# ---------------------------------------------------------------------------
echo "==> Configuring Android"
ANDROID_MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$ANDROID_MANIFEST" ]; then
  python3 - "$ANDROID_MANIFEST" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    manifest = handle.read()

permissions = [
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.WAKE_LOCK",
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
]

for permission in permissions:
    declaration = f'<uses-permission android:name="{permission}" />'
    if declaration not in manifest:
        manifest = manifest.replace(
            "<application",
            f"{declaration}\n\n    <application",
            1,
        )

manifest = manifest.replace('android:label="traincenter"', 'android:label="TrainCenter"')

with open(path, "w", encoding="utf-8") as handle:
    handle.write(manifest)
print("    permissions added")
PY
fi

echo "==> Configuring iOS"
PLIST="ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  python3 - "$PLIST" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    plist = handle.read()

entries = {
    "NSLocationWhenInUseUsageDescription":
        "TrainCenter records your route, distance and speed while you ride or run.",
    "NSLocationAlwaysAndWhenInUseUsageDescription":
        "TrainCenter keeps recording your route in the background so a long ride is not cut short.",
    "NSMotionUsageDescription":
        "TrainCenter uses motion data to improve the accuracy of your recorded speed.",
}

for key, value in entries.items():
    if f"<key>{key}</key>" not in plist:
        plist = plist.replace(
            "<key>LSRequiresIPhoneOS</key>",
            f"\t<key>{key}</key>\n\t<string>{value}</string>\n"
            "\t<key>LSRequiresIPhoneOS</key>",
            1,
        )

plist = plist.replace("<string>Traincenter</string>", "<string>TrainCenter</string>")

with open(path, "w", encoding="utf-8") as handle:
    handle.write(plist)
print("    usage descriptions added")
PY
fi

# ---------------------------------------------------------------------------
# 4. Offline map tile folder
# ---------------------------------------------------------------------------
echo "==> Preparing the offline tile folder"
mkdir -p assets/maptiles

# ---------------------------------------------------------------------------
# 5. Verify
# ---------------------------------------------------------------------------
echo "==> Running the analyzer and the tests"
flutter pub get
flutter analyze
flutter test

cat <<EOF

TrainCenter is ready.

  cd $TARGET_DIR
  flutter run

Everything is stored locally: no account, no backend, no analytics.
EOF
