import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../features/settings/app_settings.dart';
import '../services/offline_tile_provider.dart';

/// A map polyline with an optional label.
class MapRoute {
  /// Creates a map route.
  const MapRoute({
    required this.points,
    required this.color,
    this.borderColor,
    this.strokeWidth = 5,
    this.label,
  });

  /// Geometry of the route.
  final List<LatLng> points;

  /// Stroke colour.
  final Color color;

  /// Casing colour.
  final Color? borderColor;

  /// Stroke width.
  final double strokeWidth;

  /// Optional label rendered in the middle of the route.
  final String? label;
}

/// A marker shown on the map.
class MapMarker {
  /// Creates a map marker.
  const MapMarker({
    required this.point,
    required this.child,
    this.width = 32,
    this.height = 32,
    this.alignment = Alignment.center,
  });

  /// Position of the marker.
  final LatLng point;

  /// Widget rendered at the position.
  final Widget child;

  /// Width of the marker.
  final double width;

  /// Height of the marker.
  final double height;

  /// Alignment of the marker relative to its position.
  final Alignment alignment;
}

/// The shared map surface of TrainCenter.
///
/// The widget wraps `flutter_map` and isolates the *tile source* behind a
/// single switch, which is what allows the map to run completely offline:
///  * [MapTileSource.openStreetMap] downloads tiles from the public OSM
///    servers (tile coordinates and the device IP address are transmitted,
///    never any activity data).
///  * [MapTileSource.offline] reads tiles downloaded by the user from the
///    app-support directory, falling back to the bundled `assets/maptiles`
///    folder.
///  * [MapTileSource.none] renders no tiles at all and shows the recorded
///    route as pure vector geometry.
class TrainCenterMap extends StatefulWidget {
  /// Creates the map.
  const TrainCenterMap({
    super.key,
    required this.routes,
    this.markers = const <MapMarker>[],
    this.tileSource = MapTileSource.openStreetMap,
    this.offlineDirectoryPath,
    this.onTap,
    this.initialCenter,
    this.initialZoom = 14,
    this.fitToRoutes = true,
    this.interactive = true,
    this.showAttribution = true,
    this.onUserInteraction,
    this.onMapReady,
    this.padding = const EdgeInsets.all(24),
    this.mapController,
  });

  /// Routes rendered on the map.
  final List<MapRoute> routes;

  /// Markers rendered on the map.
  final List<MapMarker> markers;

  /// Where the tiles come from.
  final MapTileSource tileSource;

  /// Directory containing user-downloaded `{z}/{x}/{y}.png` tiles.
  ///
  /// Only used by [MapTileSource.offline]. When `null`, the bundled
  /// `assets/maptiles` pack is used instead.
  final String? offlineDirectoryPath;

  /// Called when the user taps the map.
  final void Function(TapPosition tapDetails, LatLng tapPosition)? onTap;

  /// Initial camera position. Ignored when [fitToRoutes] is `true` and at
  /// least one route is present.
  final LatLng? initialCenter;

  /// Initial zoom level.
  final double initialZoom;

  /// Whether the camera should frame the rendered routes.
  final bool fitToRoutes;

  /// Whether the user can pan / zoom the map.
  final bool interactive;

  /// Whether the map shows the tile provider attribution.
  final bool showAttribution;

  /// Called when the user pans, zooms or rotates the map by hand.
  ///
  /// The recording screen uses this to stop following the athlete as soon as
  /// the user takes control of the camera.
  final VoidCallback? onUserInteraction;

  /// Called once the map surface is ready to receive camera commands.
  final VoidCallback? onMapReady;

  /// Padding used when the camera frames the routes.
  final EdgeInsets padding;

  /// Optional external controller.
  ///
  /// The recording screen supplies its own controller so it can recentre the
  /// camera on every new GPS fix. When this is `null` the map owns an internal
  /// controller.
  final MapController? mapController;

  @override
  State<TrainCenterMap> createState() => _TrainCenterMapState();
}

class _TrainCenterMapState extends State<TrainCenterMap> {
  MapController? _internalController;
  bool _hasTileError = false;

  /// The controller used by the map, creating the internal one on demand.
  MapController get _mapController =>
      widget.mapController ?? (_internalController ??= MapController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrainCenterMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tileSource != widget.tileSource) {
      _hasTileError = false;
    }
    if (oldWidget.fitToRoutes != widget.fitToRoutes) {
      _fitToRoutes();
    }
  }

  /// Moves the camera so that every route is visible.
  void _fitToRoutes() {
    if (!widget.fitToRoutes) return;

    final points = <LatLng>[
      for (final route in widget.routes) ...route.points,
      for (final marker in widget.markers) marker.point,
    ];

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, widget.initialZoom);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: widget.padding,
        maxZoom: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final initialCenter =
        widget.initialCenter ??
        (widget.routes.isNotEmpty && widget.routes.first.points.isNotEmpty
            ? widget.routes.first.points.first
            : const LatLng(0, 0));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: widget.initialZoom,
        backgroundColor: colorScheme.surfaceContainerLow,
        onMapReady: () {
          _fitToRoutes();
          widget.onMapReady?.call();
        },
        onTap: widget.onTap,
        onMapEvent: (event) {
          // Only a gesture issued by the user disables the follow mode; the
          // programmatic camera moves of the recording screen keep it active.
          const userSources = <MapEventSource>{
            MapEventSource.dragStart,
            MapEventSource.onDrag,
            MapEventSource.dragEnd,
            MapEventSource.multiFingerGestureStart,
            MapEventSource.onMultiFinger,
            MapEventSource.flingAnimationController,
            MapEventSource.doubleTapZoomAnimationController,
          };
          if (!userSources.contains(event.source)) return;
          widget.onUserInteraction?.call();
        },
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: <Widget>[
        if (widget.tileSource != MapTileSource.none)
          TileLayer(
            urlTemplate: _urlTemplateFor(widget.tileSource),
            tileProvider: widget.tileSource == MapTileSource.offline
                ? OfflineTileProvider(
                    directoryPath: widget.offlineDirectoryPath,
                  )
                : NetworkTileProvider(),
            userAgentPackageName: 'com.previx.traincenter',
            maxNativeZoom: 19,
            errorTileCallback: (tile, error, stackTrace) {
              if (!_hasTileError && mounted) {
                setState(() => _hasTileError = true);
              }
            },
          ),
        PolylineLayer(
          polylines: <Polyline>[
            for (final route in widget.routes)
              Polyline(
                points: route.points,
                color: route.color,
                borderColor: route.borderColor ?? colorScheme.surface,
                borderStrokeWidth: route.borderColor == null ? 0 : 2,
                strokeWidth: route.strokeWidth,
              ),
          ],
        ),
        MarkerLayer(
          markers: <Marker>[
            for (final marker in widget.markers)
              Marker(
                point: marker.point,
                width: marker.width,
                height: marker.height,
                alignment: marker.alignment,
                child: marker.child,
              ),
          ],
        ),
        if (widget.showAttribution && widget.tileSource != MapTileSource.none)
          const RichAttributionWidget(
            attributions: <SourceAttribution>[
              TextSourceAttribution('OpenStreetMap contributors', onTap: null),
            ],
          ),
        if (_hasTileError && widget.tileSource == MapTileSource.offline)
          const RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: <SourceAttribution>[
              TextSourceAttribution(
                'Offline tiles missing · Vector mode',
                onTap: null,
              ),
            ],
          ),
        if (_hasTileError && widget.tileSource == MapTileSource.openStreetMap)
          const RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: <SourceAttribution>[
              TextSourceAttribution(
                'Map tiles unavailable · Vector mode',
                onTap: null,
              ),
            ],
          ),
      ],
    );
  }

  /// Returns the URL template for the given [source].
  String _urlTemplateFor(MapTileSource source) => switch (source) {
    MapTileSource.openStreetMap =>
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapTileSource.offline =>
      widget.offlineDirectoryPath == null
          ? 'assets/maptiles/{z}/{x}/{y}.png'
          : 'offline://{z}/{x}/{y}.png',
    MapTileSource.none => '',
  };
}

/// A circular map pin used to mark the start / end of a route.
class MapPin extends StatelessWidget {
  /// Creates a map pin.
  const MapPin({
    super.key,
    required this.color,
    this.onSurfaceColor,
    this.icon = Icons.circle,
    this.size = 28,
  });

  /// Fill colour of the pin.
  final Color color;

  /// Colour of the icon inside the pin.
  final Color? onSurfaceColor;

  /// Icon rendered inside the pin.
  final IconData icon;

  /// Diameter of the pin.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.surface, width: 2),
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: onSurfaceColor ?? colorScheme.onPrimary,
      ),
    );
  }
}
