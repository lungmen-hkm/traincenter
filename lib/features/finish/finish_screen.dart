import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme/activity_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/slide_to_confirm.dart';
import '../../core/widgets/stat_tile.dart';
import '../../core/widgets/stat_tile_grid.dart';
import '../../core/widgets/train_center_map.dart';
import '../../data/models/gear.dart';
import '../activities/activities_controller.dart';
import '../gear/gear_controller.dart';
import '../gear/gear_picker_sheet.dart';
import '../record/record_controller.dart';
import '../segments/segments_controller.dart';
import '../settings/app_settings.dart';

/// Summary screen shown after a recording has been stopped.
///
/// The activity is only written to the database once the user confirms with
/// the slide-to-save interaction.
class FinishScreen extends StatefulWidget {
  /// Creates the finish screen.
  const FinishScreen({super.key, required this.summary});

  /// The snapshot of the finished recording.
  final RecordingSummary summary;

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final recordController = context.read<RecordController>();
    final started = widget.summary.startedAt;
    final isRun = recordController.selectedGear?.type == GearType.shoe;
    final activityType = isRun ? 'Run' : 'Ride';
    _titleController.text =
        '$activityType · ${Formatters.shortDateTime(started)}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Persists the activity.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final recordController = context.read<RecordController>();
    final activitiesController = context.read<ActivitiesController>();
    final gearController = context.read<GearController>();
    final segmentsController = context.read<SegmentsController>();

    try {
      await recordController.save(
        title: _titleController.text,
        note: _noteController.text,
      );

      // Saving can create segment efforts and changes the gear mileage, so
      // every list that surfaces that data is refreshed before returning.
      await Future.wait(<Future<void>>[
        activitiesController.load(),
        gearController.load(),
        segmentsController.load(),
      ]);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Activity saved locally.')));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the activity: $error')),
      );
    }
  }

  /// Throws the recording away.
  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard activity?'),
        content: const Text(
          'The recording and its GPS track will be deleted. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    context.read<RecordController>().discard();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;
    final settings = context.watch<AppSettings>();
    final summary = widget.summary;
    final units = settings.units;

    final points = summary.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity summary'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _discard,
          tooltip: 'Discard',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          // --- Route preview -------------------------------------------------
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 240,
              child: Semantics(
                label: 'Recorded route map',
                container: true,
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
                  interactive: false,
                  showAttribution:
                      settings.mapTileSource == MapTileSource.openStreetMap,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Headline statistics -------------------------------------------
          StatTileGrid(
            children: <Widget>[
              StatTile(
                label: 'Distance',
                value: Formatters.distance(
                  summary.distanceMeters,
                  units,
                ).split(' ').first,
                unit: Formatters.distanceUnit(units),
                icon: Icons.route_rounded,
                emphasis: true,
              ),
              StatTile(
                label: 'Avg speed',
                value: Formatters.speed(
                  summary.avgSpeedMps,
                  units,
                ).split(' ').first,
                unit: Formatters.speed(
                  summary.avgSpeedMps,
                  units,
                ).split(' ').last,
                icon: Icons.speed_rounded,
              ),
              StatTile(
                label: 'Moving time',
                value: Formatters.duration(summary.movingTimeMs),
                icon: Icons.timer_outlined,
              ),
              StatTile(
                label: 'Elevation',
                value: Formatters.elevation(
                  summary.elevationGainMeters,
                  units,
                ).split(' ').first,
                unit: Formatters.elevation(
                  summary.elevationGainMeters,
                  units,
                ).split(' ').last,
                icon: Icons.trending_up_rounded,
              ),
              StatTile(
                label: 'Elapsed',
                value: Formatters.duration(summary.elapsedTimeMs),
                icon: Icons.hourglass_empty_rounded,
              ),
              StatTile(
                label: 'Max speed',
                value: Formatters.speed(
                  summary.maxSpeedMps,
                  units,
                ).split(' ').first,
                unit: Formatters.speed(
                  summary.maxSpeedMps,
                  units,
                ).split(' ').last,
                icon: Icons.flash_on_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Gear ----------------------------------------------------------
          Text(
            'Gear',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final gear = await GearPickerSheet.show(context);
              if (!context.mounted) return;
              if (gear != null) {
                context.read<RecordController>().selectGear(gear);
              }
            },
            icon: const Icon(Icons.pedal_bike_rounded),
            label: Text(
              context.read<RecordController>().selectedGear?.name ??
                  'Choose gear',
            ),
          ),
          const SizedBox(height: 20),

          // --- Title ---------------------------------------------------------
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Morning ride',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'How did it feel?',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 28),

          // --- Slide to save --------------------------------------------------
          SlideToConfirm(
            enabled: !_saving,
            label: 'Slide to save',
            confirmedLabel: 'Saving…',
            icon: Icons.arrow_forward_rounded,
            onConfirmed: _save,
          ),
          const SizedBox(height: 12),
          Text(
            'Everything stays on this device. Nothing is uploaded.',
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
