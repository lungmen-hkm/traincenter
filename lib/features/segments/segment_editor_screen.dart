import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/activity_palette.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/train_center_map.dart';
import '../../data/models/segment.dart';
import '../../data/models/track_point.dart';
import '../../data/repositories/activity_repository.dart';
import '../activities/activities_controller.dart';
import '../settings/app_settings.dart';
import 'segments_controller.dart';

/// Which endpoint of the segment is currently being placed.
enum SegmentEndpointTarget {
  /// The start of the segment.
  start,

  /// The end of the segment.
  end,
}

/// Editor used to create or adjust a segment.
///
/// A segment is defined by two GPS points picked on one of the recorded
/// routes. The selection snaps to the closest recorded sample so the segment
/// always matches the exact geometry that was ridden.
class SegmentEditorScreen extends StatefulWidget {
  /// Creates the editor.
  const SegmentEditorScreen({super.key, this.segment});

  /// The segment being edited. `null` when a new one is created.
  final Segment? segment;

  @override
  State<SegmentEditorScreen> createState() => _SegmentEditorScreenState();
}

class _SegmentEditorScreenState extends State<SegmentEditorScreen> {
  final TextEditingController _nameController = TextEditingController();

  int? _activityId;
  List<TrackPoint> _points = const <TrackPoint>[];

  TrackPoint? _start;
  TrackPoint? _end;
  SegmentEndpointTarget _target = SegmentEndpointTarget.start;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.segment?.name ?? '';
    _loadInitial();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Loads the segment being edited or the list of activities.
  Future<void> _loadInitial() async {
    final segment = widget.segment;

    if (segment != null) {
      _activityId = segment.activityId;
      _start = TrackPoint(
        seq: 0,
        latitude: segment.startLatitude,
        longitude: segment.startLongitude,
        altitude: segment.startAltitude,
        timestamp: segment.createdAt,
      );
      _end = TrackPoint(
        seq: 0,
        latitude: segment.endLatitude,
        longitude: segment.endLongitude,
        altitude: segment.endAltitude,
        timestamp: segment.createdAt,
      );
      await _loadTrack();
      return;
    }

    // No segment yet: pick the most recent activity automatically so the
    // user can start right away.
    final activities = context.read<ActivitiesController>().activities;
    if (activities.isNotEmpty) {
      _activityId = activities.first.id;
      await _loadTrack();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Loads the GPS track of the selected activity.
  Future<void> _loadTrack() async {
    final activityId = _activityId;
    if (activityId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final repository = context.read<ActivityRepository>();
    final points = await repository.trackPoints(activityId);

    if (!mounted) return;
    setState(() {
      _points = points;
      _loading = false;
    });
  }

  /// Handles a tap on the map: snaps to the closest recorded sample.
  void _handleTap(TapPosition details, LatLng position) {
    if (_points.isEmpty) return;

    final closest = GeoUtils.closestPoint(
      points: _points
          .map((point) => (lat: point.latitude, lon: point.longitude))
          .toList(growable: false),
      lat: position.latitude,
      lon: position.longitude,
    );

    if (closest == null) return;

    final sample = _points[closest.index];

    setState(() {
      if (_target == SegmentEndpointTarget.start) {
        _start = sample;
        _target = SegmentEndpointTarget.end;
      } else {
        _end = sample;
      }
    });
  }

  /// Length of the currently selected segment.
  double get _length => (_start != null && _end != null)
      ? GeoUtils.distanceMeters(
          lat1: _start!.latitude,
          lon1: _start!.longitude,
          lat2: _end!.latitude,
          lon2: _end!.longitude,
        )
      : 0;

  /// Stores the segment.
  Future<void> _save() async {
    final start = _start;
    final end = _end;

    if (start == null || end == null) {
      _showMessage('Pick a start and an end point on the route.');
      return;
    }

    if (_length < AppConstants.minSegmentLengthMeters) {
      _showMessage(
        'The segment is too short (min '
        '${AppConstants.minSegmentLengthMeters.round()} m).',
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please give the segment a name.');
      return;
    }

    setState(() => _saving = true);

    final controller = context.read<SegmentsController>();
    final existing = widget.segment;

    final segment = Segment(
      id: existing?.id,
      name: name,
      activityId: _activityId,
      startLatitude: start.latitude,
      startLongitude: start.longitude,
      startAltitude: start.altitude,
      endLatitude: end.latitude,
      endLongitude: end.longitude,
      endAltitude: end.altitude,
      distanceMeters: _length,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    await controller.save(segment);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Deletes the segment being edited, after confirmation.
  Future<void> _delete() async {
    final segment = widget.segment;
    if (segment == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete segment?'),
        content: const Text(
          'The segment and its locally stored efforts and personal bests '
          'will be removed. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<SegmentsController>().delete(segment);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;
    final settings = context.watch<AppSettings>();
    final units = settings.units;

    final activities = context.watch<ActivitiesController>().activities;
    final route = _points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    final markers = <MapMarker>[
      if (_start != null)
        MapMarker(
          point: LatLng(_start!.latitude, _start!.longitude),
          child: MapPin(
            color: palette.fast,
            icon: Icons.play_arrow_rounded,
            onSurfaceColor: colorScheme.onPrimary,
          ),
        ),
      if (_end != null)
        MapMarker(
          point: LatLng(_end!.latitude, _end!.longitude),
          child: MapPin(
            color: palette.slow,
            icon: Icons.stop_rounded,
            onSurfaceColor: colorScheme.onPrimary,
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.segment == null ? 'New segment' : 'Edit segment'),
        actions: <Widget>[
          if (widget.segment != null)
            IconButton(
              onPressed: _saving ? null : _delete,
              tooltip: 'Delete segment',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: <Widget>[
                // --- Activity picker ------------------------------------------
                const SectionHeader(title: 'Source activity'),
                DropdownButtonFormField<int>(
                  initialValue: _activityId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_bike_rounded),
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (final activity in activities)
                      DropdownMenuItem<int>(
                        value: activity.id,
                        child: Text(
                          '${activity.displayTitle} · '
                          '${Formatters.dateTime(activity.startedAt)} · '
                          '${Formatters.distance(activity.distanceMeters, units)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _activityId = value;
                      _start = null;
                      _end = null;
                      _target = SegmentEndpointTarget.start;
                    });
                    _loadTrack();
                  },
                ),
                const SizedBox(height: 16),

                // --- Map -------------------------------------------------------
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 300,
                    child: TrainCenterMap(
                      // Rebuild the camera when the source activity changes.
                      key: ValueKey<int?>(_activityId),
                      routes: <MapRoute>[
                        if (route.isNotEmpty)
                          MapRoute(
                            points: route,
                            color: palette.route.withValues(alpha: 0.45),
                            strokeWidth: 5,
                          ),
                        if (_start != null && _end != null)
                          MapRoute(
                            points: <LatLng>[
                              LatLng(_start!.latitude, _start!.longitude),
                              LatLng(_end!.latitude, _end!.longitude),
                            ],
                            color: palette.personalBest,
                            strokeWidth: 5,
                          ),
                      ],
                      markers: markers,
                      tileSource: settings.mapTileSource,
                      onTap: _handleTap,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- Endpoint selection --------------------------------------
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _EndpointCard(
                        title: 'Start',
                        subtitle: _start == null
                            ? 'Tap the map to set the start'
                            : '${_start!.latitude.toStringAsFixed(5)}, '
                                '${_start!.longitude.toStringAsFixed(5)}',
                        color: palette.fast,
                        selected: _target == SegmentEndpointTarget.start,
                        onTap: () => setState(() => _target = SegmentEndpointTarget.start),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EndpointCard(
                        title: 'End',
                        subtitle: _end == null
                            ? 'Tap the map to set the end'
                            : '${_end!.latitude.toStringAsFixed(5)}, '
                                '${_end!.longitude.toStringAsFixed(5)}',
                        color: palette.slow,
                        selected: _target == SegmentEndpointTarget.end,
                        onTap: () => setState(() => _target = SegmentEndpointTarget.end),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_start != null && _end != null)
                  Card(
                    color: colorScheme.surfaceContainerLow,
                    child: ListTile(
                      leading: const Icon(Icons.straighten_rounded),
                      title: const Text('Segment length'),
                      trailing: Text(
                        Formatters.distance(_length, units),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // --- Name ------------------------------------------------------
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Segment name',
                    hintText: 'Col de la Croix',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save segment'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Personal bests are computed locally on every new recording.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

/// A card describing one endpoint of the segment.
class _EndpointCard extends StatelessWidget {
  const _EndpointCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
