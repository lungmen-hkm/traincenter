import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:traincenter/core/services/offline_map_downloader.dart';
import 'package:traincenter/core/services/offline_map_store.dart';
import 'package:traincenter/core/services/offline_map_tiles.dart';

void main() {
  final bounds = LatLngBounds(const LatLng(-1, -1), const LatLng(1, 1));

  test('tile maths covers the expected slippy-map tiles', () {
    expect(SlippyMapTiles.tileCount(bounds, 1, 2), 8);
    expect(SlippyMapTiles.tiles(bounds, 1, 2).length, 8);
    expect(
      SlippyMapTiles.tiles(bounds, 1, 1).map((tile) => tile.relativePath),
      containsAll(<String>['1/0/0.png', '1/0/1.png', '1/1/0.png', '1/1/1.png']),
    );
  });

  test('downloader writes tiles and skips them on a second run', () async {
    final root = await Directory.systemTemp.createTemp(
      'traincenter_offline_map_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final store = OfflineMapStore(root: root);
    var requests = 0;
    final downloader = OfflineMapDownloader(
      store: store,
      fetchTile: (uri) async {
        requests++;
        return Uint8List.fromList(<int>[137, 80, 78, 71]);
      },
    );

    final progress = <OfflineMapDownloadProgress>[];
    final first = await downloader.downloadArea(
      bounds: bounds,
      minZoom: 1,
      maxZoom: 2,
      token: OfflineMapDownloadToken(),
      onProgress: progress.add,
    );

    expect(first.total, 8);
    expect(first.downloaded, 8);
    expect(first.skipped, 0);
    expect(first.cancelled, isFalse);
    expect(requests, 8);
    expect(progress.last.completed, 8);
    expect(progress.last.fraction, 1.0);

    final summary = await store.summary();
    expect(summary.tileCount, 8);
    expect(summary.bytes, greaterThan(0));

    final second = await downloader.downloadArea(
      bounds: bounds,
      minZoom: 1,
      maxZoom: 2,
      token: OfflineMapDownloadToken(),
    );
    expect(second.downloaded, 0);
    expect(second.skipped, 8);
    expect(requests, 8);

    await store.clear();
    expect((await store.summary()).tileCount, 0);
  });

  test('a cancelled token stops before any tile is requested', () async {
    final root = await Directory.systemTemp.createTemp(
      'traincenter_offline_cancel_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final store = OfflineMapStore(root: root);
    var requests = 0;
    final downloader = OfflineMapDownloader(
      store: store,
      fetchTile: (uri) async {
        requests++;
        return Uint8List.fromList(<int>[1, 2, 3]);
      },
    );

    final token = OfflineMapDownloadToken()..cancel();
    final result = await downloader.downloadArea(
      bounds: bounds,
      minZoom: 1,
      maxZoom: 2,
      token: token,
    );

    expect(result.cancelled, isTrue);
    expect(result.downloaded, 0);
    expect(requests, 0);
  });
}
