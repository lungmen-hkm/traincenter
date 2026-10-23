import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/services/screen_wake_lock.dart';
import '../../core/theme/activity_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/train_center_map.dart';
import '../../data/models/gear.dart';
import '../finish/finish_screen.dart';
import '../gear/gear_picker_sheet.dart';
import '../settings/app_settings.dart';
import 'record_controller.dart';

/// Live recording screen: map, live statistics and the recording controls.
class RecordScreen extends StatefulWidget {
  /// Creates the record screen.
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final MapController _mapController = MapController();
  bool _follow = true;
  int _lastPointCount = 0;
  LatLng? _lastCenter;

  /// Cached so the listener can be detached without touching the context
  /// while the widget is being disposed.
  RecordController? _recordController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<RecordController>();
    if (identical(controller, _recordController)) return;
    _recordController?.removeListener(_onRecordingChanged);
    _recordController = controller..addListener(_onRecordingChanged);

    // Show the default gear before the recording even starts.
    unawaited(controller.ensureDefaultGear());
  }

  @override
  void dispose() {
    _recordController?.removeListener(_onRecordingChanged);
    _recordController = null;
    ScreenWakeLock.setEnabled(false);
    _mapController.dispose();
    super.dispose();
  }

  /// Keeps the camera centred on the athlete while recording.
  void _onRecordingChanged() {
    final controller = _recordController;
    if (controller == null) return;

    _syncWakeLock(controller.status);

    final fix = controller.currentFix;
    if (fix == null || !_follow) return;

    final center = LatLng(fix.latitude, fix.longitude);
    if (center == _lastCenter) return;
    _lastCenter = center;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(center, _mapController.camera.zoom);
    });
  }

  /// Keeps the screen awake while a recording is running.
  Future<void> _syncWakeLock(RecordingStatus status) async {
    final settings = context.read<AppSettings>();
    final shouldKeepAwake = settings.keepScreenOn && status.isActive;
    await ScreenWakeLock.setEnabled(shouldKeepAwake);
  }

  /// Starts the recording.
  Future<void> _start() async {
    final settings = context.read<AppSettings>();
    final controller = context.read<RecordController>();

    final started = await controller.start(
      allowBackground: settings.backgroundTracking,
      autoPause: settings.autoPause,
    );

    if (!started && mounted && controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage!)),
      );
      controller.clearError();
    }
  }

  /// Stops the recording and opens the summary screen.
  Future<void> _stop() async {
    final controller = context.read<RecordController>();
    final summary = controller.stop();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinishScreen(summary: summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;
    final controller = context.watch<RecordController>();
    final settings = context.watch<AppSettings>();

    final points = controller.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    final currentPosition = controller.currentFix;

    // Keep the map in sync with newly recorded points.
    if (points.length != _lastPointCount) {
      _lastPointCount = points.length;
      if (_follow && points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.move(points.last, _mapController.camera.zoom);
        });
      }
    }

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: TrainCenterMap(
              mapController: _mapController,
              routes: <MapRoute>[
                if (points.isNotEmpty)
                  MapRoute(
                    points: points,
                    color: palette.route,
                    borderColor: colorScheme.surface,
                    strokeWidth: 6,
                  ),
              ],
              markers: <MapMarker>[
                if (currentPosition != null)
                  MapMarker(
                    point: LatLng(currentPosition.latitude, currentPosition.longitude),
                    child: MapPin(color: colorScheme.primary),
                  ),
              ],
              tileSource: settings.mapTileSource,
              interactive: true,
              fitToRoutes: false,
              onUserInteraction: () => setState(() => _follow = false),
              initialCenter: points.isNotEmpty ? points.last : null,
            ),
          ),

          // --- Top overlay --------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TopBar(
                  status: controller.status,
                  isAutoPaused: controller.isAutoPaused,
                  gear: controller.selectedGear,
                  onPickGear: _pickGear,
                ),
              ),
            ),
          ),

          // --- Recenter button -----------------------------------------------
          if (!_follow && currentPosition != null)
            Positioned(
              right: 16,
              bottom: 240,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                tooltip: 'Centre on my position',
                onPressed: () {
                  setState(() => _follow = true);
                  final fix = controller.currentFix;
                  if (fix == null) return;
                  _mapController.move(
                    LatLng(fix.latitude, fix.longitude),
                    _mapController.camera.zoom,
                  );
                },
                child: const Icon(Icons.my_location_rounded),
              ),
            ),

          // --- Bottom controls ----------------------------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ControlPanel(
              controller: controller,
              settings: settings,
              onStart: _start,
              onStop: _stop,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the gear picker.
  Future<void> _pickGear() async {
    final gear = await GearPickerSheet.show(context);
    if (gear == null || !mounted) return;
    context.read<RecordController>().selectGear(gear);
  }
}

/// The status bar shown on top of the map.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.status,
    required this.isAutoPaused,
    required this.gear,
    required this.onPickGear,
  });

  final RecordingStatus status;
  final bool isAutoPaused;
  final Gear? gear;
  final VoidCallback onPickGear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: status.isActive ? null : onPickGear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      gear?.type == GearType.shoe
                          ? Icons.directions_run_rounded
                          : Icons.pedal_bike_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        gear?.name ?? 'No gear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: status.isActive ? colorScheme.errorContainer : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (status.isActive)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PulsingDot(color: colorScheme.error),
                ),
              Text(
                switch (status) {
                  RecordingStatus.idle => 'Ready',
                  RecordingStatus.acquiring => 'Acquiring GPS',
                  RecordingStatus.recording => 'Recording',
                  RecordingStatus.paused => isAutoPaused ? 'Auto-paused' : 'Paused',
                  RecordingStatus.finished => 'Finished',
                },
                style: theme.textTheme.labelLarge?.copyWith(
                  color: status.isActive ? colorScheme.onErrorContainer : colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small animated dot used as a "recording" indicator.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// The bottom control panel with the live statistics.
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.controller,
    required this.settings,
    required this.onStart,
    required this.onStop,
  });

  final RecordController controller;
  final AppSettings settings;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = settings.units;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // --- Primary statistic --------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Distance',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      Formatters.distance(controller.distanceMeters, units),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.duration(controller.elapsedTimeMs),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Secondary statistics -----------------------------------------
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  icon: Icons.speed_rounded,
                  label: 'Avg',
                  value: Formatters.speed(controller.avgSpeedMps, units),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  icon: Icons.trending_up_rounded,
                  label: 'Elev',
                  value: Formatters.elevation(
                    controller.elevationGainMeters,
                    units,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Points',
                  value: '${controller.sampleCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Controls ------------------------------------------------------
          Row(
            children: <Widget>[
              if (controller.status == RecordingStatus.idle)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start recording'),
                  ),
                )
              else if (controller.status == RecordingStatus.finished)
                // The summary can be dismissed with the system back gesture;
                // this gives the user a way back to the slide-to-save sheet
                // without re-stopping (and therefore re-timing) the ride.
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.summarize_rounded),
                    label: const Text('Review summary'),
                  ),
                )
              else ...<Widget>[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: controller.isPaused ? controller.resume : controller.pause,
                    icon: Icon(
                      controller.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(controller.isPaused ? 'Resume' : 'Pause'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStop,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Finish'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A small statistic inside the control panel.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
