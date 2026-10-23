import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/activity_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_tile.dart';
import '../../data/models/activity.dart';
import '../settings/app_settings.dart';
import 'activities_controller.dart';
import 'activity_detail_screen.dart';

/// Lists every activity stored on the device.
class ActivitiesScreen extends StatelessWidget {
  /// Creates the activities screen.
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<ActivitiesController>();
    final settings = context.watch<AppSettings>();
    final units = settings.units;

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.activities.isEmpty) {
      return const EmptyState(
        icon: Icons.directions_bike_rounded,
        title: 'No activities yet',
        message: 'Record your first ride or run — it will be stored locally '
            'on this device.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        // --- Totals ---------------------------------------------------------
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Total distance',
                value: Formatters.distance(controller.totalDistanceMeters, units)
                    .split(' ')
                    .first,
                unit: Formatters.distanceUnit(units),
                icon: Icons.route_rounded,
                emphasis: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Moving time',
                value: Formatters.duration(controller.totalMovingTimeMs),
                icon: Icons.timer_outlined,
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
                value:
                    Formatters.elevation(controller.totalElevationGainMeters, units)
                        .split(' ')
                        .first,
                unit:
                    Formatters.elevation(controller.totalElevationGainMeters, units)
                        .split(' ')
                        .last,
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Activities',
                value: '${controller.activities.length}',
                icon: Icons.list_alt_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'History'),
        ...controller.activities.map(
          (activity) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ActivityCard(activity: activity),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All activities are stored in the local database of this device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A single activity row.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;
    final settings = context.watch<AppSettings>();
    final units = settings.units;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityDetailScreen(activityId: activity.id!),
          ),
        ),
        onLongPress: () => _confirmDelete(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.directions_bike_rounded,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      activity.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.dateTime(activity.startedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: <Widget>[
                        _InlineStat(
                          icon: Icons.route_rounded,
                          label: Formatters.distance(activity.distanceMeters, units),
                          color: palette.route,
                        ),
                        _InlineStat(
                          icon: Icons.timer_outlined,
                          label: Formatters.duration(activity.movingTimeMs),
                          color: colorScheme.onSurfaceVariant,
                        ),
                        _InlineStat(
                          icon: Icons.speed_rounded,
                          label: Formatters.speed(activity.avgSpeedMps, units),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Asks the user to confirm the deletion of an activity.
  Future<void> _confirmDelete(BuildContext context) async {
    final controller = context.read<ActivitiesController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: const Text(
          'The activity, its GPS track and any associated segment efforts will be permanently removed.',
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

    if (confirmed == true) {
      await controller.delete(activity);
    }
  }
}

/// A small statistic rendered inline inside an activity row.
class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
