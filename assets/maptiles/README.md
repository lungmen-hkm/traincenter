# Offline map tiles

TrainCenter can render the map **completely offline** by reading tiles from
this folder. This is the optional *bundled* fallback; tiles downloaded in
**Settings → Map → Download offline maps** are stored in the app-support
directory and are preferred when both are present.

## Expected structure

The file name must follow the `{z}/{x}/{y}.png` scheme used by the slippy
map tile convention, for example:

```
assets/maptiles/
├── 10/
│   ├── 512/
│   │   ├── 362.png
│   │   └── 363.png
│   └── ...
├── 11/
└── ...
```

* `{z}` is the zoom level (integer).
* `{x}` is the column, `{y}` is the row (integer), using the Web Mercator
  (`EPSG:3857`) projection — the same projection OpenStreetMap uses.
* The tiles are addressed through TrainCenter's `OfflineTileProvider`, which
  reads a downloaded file first and falls back to the matching asset, so they
  must be declared as assets in `pubspec.yaml`.

## Enabling the offline mode

1. Drop the tiles into this folder.
2. Make sure `pubspec.yaml` contains:

   ```yaml
   flutter:
     assets:
       - assets/maptiles/
   ```

3. Open **Settings → Map → Offline map**.

You can also leave this folder empty and use **Download offline maps** in
Settings to save a selected area from OpenStreetMap at runtime.

## Notes

* This folder is intentionally empty in the repository: shipping a tile
  pyramid would add tens of megabytes to the app.
* When neither a downloaded tile nor a bundled tile exists, the recorded route
  is still drawn as vector geometry on top of the map, and the map shows an
  “Offline tiles missing · Vector mode” badge.
* The "No map tiles" source works without any asset at all and is the
  recommended option for a 100 % silent, offline-only build.
