# Offline map tiles

TrainCenter can render the map **completely offline** by reading the tiles
from this folder instead of downloading them.

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
* The tiles are addressed through the `flutter_map`
  `AssetTileProvider`, so they must be declared as assets in `pubspec.yaml`.

## Enabling the offline mode

1. Drop the tiles into this folder.
2. Make sure `pubspec.yaml` contains:

   ```yaml
   flutter:
     assets:
       - assets/maptiles/
   ```

3. Open **Settings → Map → Offline tiles (bundled)**.

## Notes

* This folder is intentionally empty in the repository: shipping a tile
  pyramid would add tens of megabytes to the app.
* When the folder is empty and the offline source is selected, `flutter_map`
  renders empty tiles; the recorded route is still drawn as vector geometry
  on top of the map.
* The "No tiles (vector only)" source works without any asset at all and is
  the recommended option for a 100 % silent, offline-only build.
