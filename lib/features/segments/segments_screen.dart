import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/activity_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/segment.dart';
import '../../data/models/segment_effort.dart';
import '../settings/app_settings.dart';
import 'segment_editor_screen.dart';
import 'segments_controller.dart';

/// Lists the locally defined segments and their personal bests.
class SegmentsScreen extends StatelessWidget {
  /// Creates the segments screen.
  const SegmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<SegmentsController>();
    final settings = context.watch<AppSettings>();
    final units = settings.units;

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SegmentEditorScreen()),
        ),
        icon: const Icon(Icons.add_road_rounded),
        label: const Text('Create segment'),
      ),
      body: controller.segments.isEmpty
          ? const EmptyState(
              icon: Icons.add_road_rounded,
              title: 'No segments yet',
              message: 'Pick a start and an end point on one of your recorded '
                  'routes to create a segment and start chasing personal bests.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                const SectionHeader(
                  title: 'Your segments',
                  subtitle: 'Personal bests are computed on this device only',
                ),
                ...controller.segments.map(
                  (segment) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SegmentCard(segment: segment, units: units),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Segments are compared against your future activities '
                  'automatically.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

/// A single segment row.
class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment, required this.units});

  final Segment segment;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;
    final controller = context.watch<SegmentsController>();

    final SegmentEffort? best = controller.personalBest(segment.id!);
    final history = controller.effortsFor(segment.id!);

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SegmentEditorScreen(segment: segment),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      segment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.straighten_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.distance(segment.distanceMeters, units),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (best == null)
                Text(
                  'No effort recorded yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: palette.personalBest,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PR ${Formatters.duration(best.timeMs)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${Formatters.speed(best.avgSpeedMps, units)} · '
                      '${history.length} effort${history.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
