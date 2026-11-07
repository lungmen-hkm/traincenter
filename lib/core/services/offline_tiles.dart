import 'package:flutter/services.dart';

/// Detects whether the optional bundled tile pack is present in this build.
///
/// The offline source is only useful when `assets/maptiles/` actually contains
/// PNG tiles. This helper keeps the Settings option honest instead of letting
/// users pick a source that can never load.
abstract final class OfflineTiles {
  /// Prefix of the assets declared in `pubspec.yaml`.
  static const String assetPrefix = 'assets/maptiles/';

  /// Whether [assetPaths] contains at least one offline map tile.
  static bool containsTiles(Iterable<String> assetPaths) {
    return assetPaths.any(
      (path) => path.startsWith(assetPrefix) && path.endsWith('.png'),
    );
  }

  /// Reads the asset manifest of the running app.
  static Future<bool> isAvailable() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return containsTiles(manifest.listAssets());
  }
}
