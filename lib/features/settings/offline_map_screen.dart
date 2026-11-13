import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/services/offline_map_tiles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/train_center_map.dart';
import 'app_settings.dart';
import 'offline_map_controller.dart';

/// Lets the user download the visible map area for offline use.
class OfflineMapScreen extends StatefulWidget {
  /// Creates the offline map download screen.
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<MapEvent>? _mapEvents;
  LatLngBounds? _bounds;
  LatLng? _pendingCenter;
  bool _mapReady = false;

  RangeValues _zoomRange = RangeValues(
    AppConstants.offlineMapDefaultMinZoom.toDouble(),
    AppConstants.offlineMapDefaultMaxZoom.toDouble(),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastKnownPosition());
  }

  @override
  void dispose() {
    _mapEvents?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadLastKnownPosition() async {
    try {
      final fix = await context.read<LocationService>().lastKnownPosition();
      if (!mounted || fix == null) return;
      _pendingCenter = LatLng(fix.latitude, fix.longitude);
      if (_mapReady) _applyPendingCenter();
    } on Object {
      // A missing permission or a platform without location support simply
      // leaves the map at the world view; the user can still pan to an area.
    }
  }

  void _onMapReady() {
    _mapReady = true;
    _mapEvents = _mapController.mapEventStream.listen((_) => _updateBounds());
    _applyPendingCenter();
    _updateBounds();
  }

  void _applyPendingCenter() {
    final center = _pendingCenter;
    if (center == null || !_mapReady) return;
    _pendingCenter = null;
    _mapController.move(center, AppConstants.offlineMapPreviewZoom.toDouble());
    _updateBounds();
  }

  void _updateBounds() {
    if (!mounted || !_mapReady) return;
    final bounds = _mapController.camera.visibleBounds;
    setState(() => _bounds = bounds);
  }

  /// Adds a margin so the taller record-screen map stays covered.
  LatLngBounds _downloadBounds(LatLngBounds visible) {
    final latitudeSpan = visible.north - visible.south;
    final longitudeSpan = visible.east - visible.west;
    final latitudeMargin = latitudeSpan * AppConstants.offlineMapDownloadMargin;
    final longitudeMargin =
        longitudeSpan * AppConstants.offlineMapDownloadMargin;

    final south = (visible.south - latitudeMargin).clamp(
      -SlippyMapTiles.maxMercatorLatitude,
      SlippyMapTiles.maxMercatorLatitude,
    );
    final north = (visible.north + latitudeMargin).clamp(
      -SlippyMapTiles.maxMercatorLatitude,
      SlippyMapTiles.maxMercatorLatitude,
    );
    final west = (visible.west - longitudeMargin).clamp(-180.0, 180.0);
    final east = (visible.east + longitudeMargin).clamp(-180.0, 180.0);

    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final visibleBounds = _bounds;
    final bounds = visibleBounds == null
        ? null
        : _downloadBounds(visibleBounds);
    final minZoom = _zoomRange.start.round();
    final maxZoom = _zoomRange.end.round();
    final estimatedTiles = bounds == null
        ? 0
        : SlippyMapTiles.tileCount(bounds, minZoom, maxZoom);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline maps')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          const SectionHeader(
            title: 'Download area',
            subtitle:
                'Pan and zoom the preview to frame the area you need; a small '
                'margin is added around it',
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 300,
              child: Semantics(
                label: 'Offline map area preview',
                container: true,
                child: TrainCenterMap(
                  mapController: _mapController,
                  routes: const <MapRoute>[],
                  tileSource: MapTileSource.openStreetMap,
                  initialZoom: 2,
                  fitToRoutes: false,
                  onMapReady: _onMapReady,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AreaCard(
            bounds: bounds,
            units: settings.units,
            zoomRange: _zoomRange,
            estimatedTiles: estimatedTiles,
            onZoomRangeChanged: (value) {
              setState(() => _zoomRange = value);
            },
          ),
          const SizedBox(height: 12),
          _DownloadCard(
            bounds: bounds,
            minZoom: minZoom,
            maxZoom: maxZoom,
            estimatedTiles: estimatedTiles,
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Storage'),
          const _StorageCard(),
          const SizedBox(height: 20),
          const SectionHeader(title: 'About offline maps'),
          const _AboutCard(),
        ],
      ),
    );
  }
}

/// Shows the visible area and lets the user choose a zoom range.
class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.bounds,
    required this.units,
    required this.zoomRange,
    required this.estimatedTiles,
    required this.onZoomRangeChanged,
  });

  final LatLngBounds? bounds;
  final UnitSystem units;
  final RangeValues zoomRange;
  final int estimatedTiles;
  final ValueChanged<RangeValues> onZoomRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final minZoom = zoomRange.start.round();
    final maxZoom = zoomRange.end.round();
    final tooMany = estimatedTiles > AppConstants.offlineMapMaxTiles;
    final estimatedBytes =
        estimatedTiles * AppConstants.offlineMapEstimatedTileBytes;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.crop_free_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Download area',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (bounds != null)
                  Text(
                    _areaLabel(bounds!, units),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Zoom levels $minZoom–$maxZoom',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            RangeSlider(
              values: zoomRange,
              min: AppConstants.offlineMapMinZoom.toDouble(),
              max: AppConstants.offlineMapMaxZoom.toDouble(),
              divisions:
                  AppConstants.offlineMapMaxZoom -
                  AppConstants.offlineMapMinZoom,
              labels: RangeLabels('$minZoom', '$maxZoom'),
              onChanged: onZoomRangeChanged,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    estimatedTiles == 0
                        ? 'Move the map to choose an area.'
                        : tooMany
                        ? 'More than ${AppConstants.offlineMapMaxTiles} tiles'
                        : '$estimatedTiles tiles · about '
                              '${Formatters.fileSize(estimatedBytes)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tooMany
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (tooMany) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'That is more than the '
                '${AppConstants.offlineMapMaxTiles}-tile limit. Zoom in or '
                'reduce the maximum zoom level.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Includes a '
                '${(AppConstants.offlineMapDownloadMargin * 100).round()}% '
                'margin around the preview so the full-screen map stays '
                'covered.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _areaLabel(LatLngBounds bounds, UnitSystem units) {
    final width = GeoUtils.distanceMeters(
      lat1: bounds.south,
      lon1: bounds.west,
      lat2: bounds.south,
      lon2: bounds.east,
    );
    final height = GeoUtils.distanceMeters(
      lat1: bounds.south,
      lon1: bounds.west,
      lat2: bounds.north,
      lon2: bounds.west,
    );
    return '${Formatters.distance(width, units, decimals: 1)} × '
        '${Formatters.distance(height, units, decimals: 1)}';
  }
}

/// The primary download button / progress display.
class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.estimatedTiles,
  });

  final LatLngBounds? bounds;
  final int minZoom;
  final int maxZoom;
  final int estimatedTiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<OfflineMapController>();
    final tooMany = estimatedTiles > AppConstants.offlineMapMaxTiles;
    final canDownload =
        bounds != null &&
        estimatedTiles > 0 &&
        !tooMany &&
        !controller.isDownloading;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: controller.isDownloading
            ? _buildProgress(context, controller)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: canDownload
                        ? () => _startDownload(context, controller)
                        : null,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download this area'),
                  ),
                  if (controller.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      controller.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Tiles are © OpenStreetMap contributors. Only the selected '
                    'area and its margin are requested; your activity data '
                    'never leaves the device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context, OfflineMapController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = controller.progress;
    final total = progress?.total ?? 0;
    final completed = progress?.completed ?? 0;
    final downloaded = progress?.downloaded ?? 0;
    final skipped = progress?.skipped ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(
          value: total == 0 ? null : progress?.fraction,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),
        Text(
          total == 0
              ? 'Preparing download…'
              : 'Downloading $completed of $total tiles',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$downloaded downloaded · $skipped already saved',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: controller.cancelDownload,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancel download'),
        ),
      ],
    );
  }

  Future<void> _startDownload(
    BuildContext context,
    OfflineMapController controller,
  ) async {
    final area = bounds;
    if (area == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<AppSettings>();
    await controller.downloadArea(
      bounds: area,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    if (!context.mounted) return;

    final error = controller.errorMessage;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final result = controller.lastResult;
    if (result == null) return;

    if (result.cancelled) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Download cancelled. ${result.downloaded} tiles were saved.',
          ),
        ),
      );
      return;
    }

    if (result.downloaded == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.skipped > 0
                ? 'This area is already downloaded '
                      '(${result.skipped} tiles).'
                : 'There were no tiles to download.',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('${result.downloaded} tiles downloaded.'),
        action: SnackBarAction(
          label: 'Use offline map',
          onPressed: () => settings.setMapTileSource(MapTileSource.offline),
        ),
      ),
    );
  }
}

/// Shows storage usage and offers to clear downloaded tiles.
class _StorageCard extends StatelessWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<OfflineMapController>();
    final summary = controller.summary;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('Downloaded maps'),
            subtitle: Text(
              controller.isLoading
                  ? 'Checking downloaded tiles…'
                  : summary.hasTiles
                  ? '${summary.tileCount} tiles · ${summary.sizeLabel}'
                  : 'No offline maps downloaded yet.',
            ),
          ),
          if (summary.hasTiles) ...<Widget>[
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: controller.isDownloading
                    ? colorScheme.outline
                    : colorScheme.error,
              ),
              title: const Text('Clear downloaded maps'),
              subtitle: const Text(
                'Frees the storage used by downloaded offline tiles.',
              ),
              enabled: !controller.isDownloading,
              onTap: controller.isDownloading
                  ? null
                  : () => _confirmClear(context, controller),
            ),
          ],
          if (controller.isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    OfflineMapController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear downloaded maps?'),
        content: const Text(
          'Every downloaded offline tile will be deleted. Activities and '
          'routes are not affected.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await controller.clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloaded offline maps cleared.')),
    );
  }
}

/// Explains what offline maps are and what the download does.
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.public_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'OpenStreetMap tiles',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Downloading sends the selected tile coordinates and your IP '
              'address to the OpenStreetMap tile servers. The tiles are stored '
              'only on this device, and the app never uploads your routes. '
              'Download only the areas you actually need; one download is '
              'limited to ${AppConstants.offlineMapMaxTiles} tiles.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
