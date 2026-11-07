# Store screenshots

These are the eight phone screenshots for the Google Play listing. All images
are **1080 × 1920 PNG (9:16, 24-bit RGB, no alpha)** and were captured on the
Android 16 / API 36 emulator (`emulator-5554`) at 420 dpi with demo-mode status
icons.

| # | File | Screen | Suggested caption |
| --- | --- | --- | --- |
| 1 | `01_record.png` | Record | Record a ride with live distance, speed and elevation. |
| 2 | `02_activities.png` | Activities | Every activity stays on your device. Review totals and history. |
| 3 | `03_activity_detail.png` | Activity detail | See the route and full statistics after each ride. |
| 4 | `04_segments.png` | Segments | Create segments and track your local personal bests. |
| 5 | `05_gear.png` | Gear | Keep bicycles and shoes organised with their own mileage. |
| 6 | `06_settings.png` | Settings | Choose appearance, units and how map tiles load. |
| 7 | `07_export.png` | Export sheet | Save or share a clean, transparent PNG route card. |
| 8 | `08_dark_record.png` | Dark Record | A full Material 3 dark theme for night rides. |

## Reproducing the capture

The emulator must have the sample activities, the “Diagonal Sprint” segment and
the “Gravel Bike” gear already present (see the runtime data in `workplan.md`).

```bash
adb shell wm size 1080x1920
adb shell wm density 420
adb shell settings put system user_rotation 0
adb shell settings put system font_scale 1.0
adb shell cmd uimode night no

# Clean status bar (Android demo mode)
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e level 4 -e datatype none
```

Then open each screen and capture:

```bash
adb exec-out screencap -p > docs/screenshots/01_record.png
```

`adb screencap` writes RGBA PNGs, while Google Play requires 24-bit screenshots
without an alpha channel. Strip the alpha channel after capturing:

```bash
python3 - <<'PY'
from pathlib import Path
from PIL import Image

for path in Path('docs/screenshots').glob('*.png'):
    Image.open(path).convert('RGB').save(path, optimize=True)
PY
```

For the export shot, scroll the bottom sheet until the Save/Share buttons are
visible. For the dark shot:

```bash
adb shell cmd uimode night yes
# open Record, wait for the theme to rebuild, then capture
adb shell cmd uimode night no
```

Finish with:

```bash
adb shell am broadcast -a com.android.systemui.demo -e command exit
adb shell wm size reset
adb shell wm density reset
```

The images are intentionally stored in the repository; `.gitignore` has
explicit exceptions for `docs/screenshots/*.png` and `docs/store/*.png` because
the general rule ignores local test PNGs.
