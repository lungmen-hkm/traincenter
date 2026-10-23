import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme/activity_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_tile.dart';
import '../../core/widgets/train_center_map.dart';
import '../../data/models/activity.dart';
import '../../data/models/segment_effort.dart';
import '../../data/models/track_point.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/segment_repository.dart';
import '../export/export_sheet.dart';
import '../settings/app_settings.dart';
import 'activities_controller.dart';

/// Detail view of a single recorded activity.
class ActivityDetailScreen extends StatefulWidget {
  /// Creates the detail screen.
  const ActivityDetailScreen({super.key, required this.activityId});

  /// Identifier of the activity to display.
  final int activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  Activity? _activity;
  List<TrackPoint> _points = const <TrackPoint>[];
  List<SegmentEffort> _efforts = const <SegmentEffort>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the activity, its GPS track and its segment efforts.
  Future<void> _load() async {
    final activityRepository = context.read<ActivityRepository>();
    final segmentRepository = context.read<SegmentRepository>();

    final activity = await activityRepository.findById(widget.activityId);
    final points = await activityRepository.trackPoints(widget.activityId);

    // Efforts are stored per segment, so they are gathered per segment below.
    final segments = await segmentRepository.listSegments();
    final allEfforts = <SegmentEffort>[];
    for (final segment in segments) {
      allEfforts.addAll(await segmentRepository.effortsFor(segment.id!));
    }

    if (!mounted) return;
    setState(() {
      _activity = activity;
      _points = points;
      _efforts = allEfforts
          .where((effort) => effort.activityId == widget.activityId)
          .toList(growable: false);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;
    final settings = context.watch<AppSettings>();
    final units = settings.units;

    final activity = _activity;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: const Center(child: Text('This activity no longer exists.')),
      );
    }

    final points = _points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(activity.displayTitle),
        actions: <Widget>[
          IconButton(
            tooltip: 'Export PNG',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => ActivityExportSheet.show(
              context,
              activity: activity,
              points: points,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _onMenuSelected(value, activity),
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit_rounded),
                  title: Text('Rename'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          // --- Route ---------------------------------------------------------
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 260,
              child: TrainCenterMap(
                routes: <MapRoute>[
                  if (points.isNotEmpty)
                    MapRoute(
                      points: points,
                      color: palette.route,
                      borderColor: colorScheme.surface,
                      strokeWidth: 6,
                    ),
                ],
                tileSource: settings.mapTileSource,
                showAttribution: settings.mapTileSource == MapTileSource.openStreetMap,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Distance',
                  value:
                      Formatters.distance(activity.distanceMeters, units).split(' ').first,
                  unit: Formatters.distanceUnit(units),
                  icon: Icons.route_rounded,
                  emphasis: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Avg speed',
                  value:
                      Formatters.speed(activity.avgSpeedMps, units).split(' ').first,
                  unit: Formatters.speed(activity.avgSpeedMps, units).split(' ').last,
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Moving time',
                  value: Formatters.duration(activity.movingTimeMs),
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Elapsed',
                  value: Formatters.duration(activity.elapsedTimeMs),
                  icon: Icons.hourglass_empty_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Elevation',
                  value: Formatters.elevation(activity.elevationGainMeters, units)
                      .split(' ')
                      .first,
                  unit: Formatters.elevation(activity.elevationGainMeters, units)
                      .split(' ')
                      .last,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Max speed',
                  value:
                      Formatters.speed(activity.maxSpeedMps, units).split(' ').first,
                  unit: Formatters.speed(activity.maxSpeedMps, units).split(' ').last,
                  icon: Icons.flash_on_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Details -------------------------------------------------------
          const SectionHeader(title: 'Details'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: Formatters.dateTime(activity.startedAt),
                ),
                const Divider(height: 1),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Duration',
                  value: Formatters.durationLong(activity.elapsedTimeMs),
                ),
                const Divider(height: 1),
                _DetailRow(
                  icon: Icons.straighten_rounded,
                  label: 'Samples',
                  value: '${_points.length}',
                ),
                const Divider(height: 1),
                _DetailRow(
                  icon: Icons.bolt_rounded,
                  label: 'Average pace',
                  value: Formatters.pace(activity.avgSpeedMps, units),
                ),
                if (activity.note != null && activity.note!.isNotEmpty) ...<Widget>[
                  const Divider(height: 1),
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: activity.note!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Segment efforts -----------------------------------------------
          if (_efforts.isNotEmpty) ...<Widget>[
            const SectionHeader(
              title: 'Segments',
              subtitle: 'Local comparisons against your segments',
            ),
            ..._efforts.map((effort) => _EffortTile(effort: effort)),
            const SizedBox(height: 16),
          ],

          // --- Export ---------------------------------------------------------
          FilledButton.tonalIcon(
            onPressed: () => ActivityExportSheet.show(
              context,
              activity: activity,
              points: points,
            ),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Export transparent PNG'),
          ),
          const SizedBox(height: 8),
          Text(
            'Creates a transparent PNG with the distance, the average speed, '
            'the moving time and the route geometry.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Handles the overflow menu actions.
  Future<void> _onMenuSelected(String value, Activity activity) async {
    switch (value) {
      case 'rename':
        final controller = TextEditingController(text: activity.title);
        final title = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rename activity'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        );

        if (title != null && mounted) {
          await context
              .read<ActivitiesController>()
              .update(activity.copyWith(title: title));
          await _load();
        }

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete activity?'),
            content: const Text(
              'The activity and its GPS track will be removed from this device.',
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

        if (confirmed == true && mounted) {
          await context.read<ActivitiesController>().delete(activity);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }
}

/// A label / value row inside the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A segment effort recorded during the activity.
class _EffortTile extends StatelessWidget {
  const _EffortTile({required this.effort});

  final SegmentEffort effort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;
    final settings = context.watch<AppSettings>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: effort.isPersonalBest
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              effort.isPersonalBest ? Icons.emoji_events_rounded : Icons.timer_rounded,
              size: 18,
              color: effort.isPersonalBest
                  ? colorScheme.onSecondaryContainer
                  : palette.medium,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                effort.isPersonalBest ? 'New personal best' : 'Segment effort',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: effort.isPersonalBest
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              Formatters.duration(effort.timeMs),
              style: theme.textTheme.labelLarge?.copyWith(
                color: effort.isPersonalBest
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              Formatters.speed(effort.avgSpeedMps, settings.units),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
