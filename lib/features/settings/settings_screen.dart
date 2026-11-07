import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/db/app_database.dart';
import '../../core/services/offline_tiles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/adaptive_segmented_button.dart';
import '../../core/widgets/section_header.dart';
import '../activities/activities_controller.dart';
import '../gear/gear_controller.dart';
import '../record/record_controller.dart';
import '../segments/segments_controller.dart';
import 'app_settings.dart';

/// Application preferences and privacy information.
class SettingsScreen extends StatelessWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  /// Cached result of the asset-manifest check for the settings session.
  static final Future<bool> _offlineTilesAvailable = OfflineTiles.isAvailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<AppSettings>();
    final isRecordingActive = context.watch<RecordController>().status.isActive;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          // --- Appearance ----------------------------------------------------
          const SectionHeader(
            title: 'Appearance',
            subtitle: 'Light, dark, or follow the system',
          ),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Theme',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdaptiveSegmentedButton<AppThemeMode>(
                    key: const Key('theme-mode-selector'),
                    segments: <ButtonSegment<AppThemeMode>>[
                      for (final value in AppThemeMode.values)
                        ButtonSegment<AppThemeMode>(
                          value: value,
                          label: Text(value.label),
                        ),
                    ],
                    selected: <AppThemeMode>{settings.themeMode},
                    onSelectionChanged: (selection) =>
                        settings.setThemeMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Units -------------------------------------------------------
          const SectionHeader(title: 'Units'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Measurement system',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdaptiveSegmentedButton<UnitSystem>(
                    segments: <ButtonSegment<UnitSystem>>[
                      for (final value in UnitSystem.values)
                        ButtonSegment<UnitSystem>(
                          value: value,
                          label: Text(value.label),
                        ),
                    ],
                    selected: <UnitSystem>{settings.units},
                    onSelectionChanged: (selection) =>
                        settings.setUnits(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Map ---------------------------------------------------------
          const SectionHeader(
            title: 'Map',
            subtitle: 'Choose where the map tiles come from',
          ),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: RadioGroup<MapTileSource>(
              groupValue: settings.mapTileSource,
              onChanged: (value) {
                if (value != null) settings.setMapTileSource(value);
              },
              child: Column(
                children: <Widget>[
                  for (final source in MapTileSource.values)
                    if (source != MapTileSource.offline)
                      RadioListTile<MapTileSource>(
                        value: source,
                        title: Text(source.label),
                        subtitle: Text(_tileDescription(source)),
                      )
                    else
                      FutureBuilder<bool>(
                        future: _offlineTilesAvailable,
                        builder: (context, snapshot) {
                          // Treat a manifest-read failure like a missing pack
                          // instead of leaving the option stuck on "Checking".
                          final available = snapshot.hasError
                              ? false
                              : snapshot.data;
                          return RadioListTile<MapTileSource>(
                            value: source,
                            enabled: available ?? false,
                            title: Text(source.label),
                            subtitle: Text(switch (available) {
                              true => _tileDescription(source),
                              false => 'No offline tile pack is installed in this build.',
                              null => 'Checking for bundled offline tiles…',
                            }),
                          );
                        },
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Recording ----------------------------------------------------
          const SectionHeader(title: 'Recording'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: settings.backgroundTracking,
                  onChanged: settings.setBackgroundTracking,
                  title: const Text('Background tracking'),
                  subtitle: const Text(
                    'Keeps the GPS running through a foreground service when '
                    'the app is not in the foreground.',
                  ),
                  secondary: const Icon(Icons.phonelink_lock_rounded),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: settings.autoPause,
                  onChanged: settings.setAutoPause,
                  title: const Text('Auto pause'),
                  subtitle: const Text(
                    'Pauses the moving time automatically when you stop moving.',
                  ),
                  secondary: const Icon(Icons.pause_circle_outline_rounded),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: settings.keepScreenOn,
                  onChanged: settings.setKeepScreenOn,
                  title: const Text('Keep the screen awake'),
                  subtitle: const Text('While a recording is running.'),
                  secondary: const Icon(Icons.brightness_high_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Export --------------------------------------------------------
          const SectionHeader(
            title: 'Export',
            subtitle: 'Appearance of the transparent PNG card',
          ),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AdaptiveSegmentedButton<ExportBrightness>(
                    segments: <ButtonSegment<ExportBrightness>>[
                      for (final value in ExportBrightness.values)
                        ButtonSegment<ExportBrightness>(
                          value: value,
                          label: Text(value.label),
                        ),
                    ],
                    selected: <ExportBrightness>{settings.exportBrightness},
                    onSelectionChanged: (selection) =>
                        settings.setExportBrightness(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Privacy --------------------------------------------------------
          const SectionHeader(title: 'Privacy'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.shield_outlined, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        '100% on-device',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TrainCenter has no account, no analytics and no backend. '
                    'Every activity, gear and segment is stored in a local '
                    'SQLite database on this device only.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The only network request the app can ever make is the '
                    'download of map tiles when "Online map" is selected. '
                    'Switch the map to "No map tiles" for a completely silent app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Data -----------------------------------------------------------
          const SectionHeader(title: 'Data'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_rounded,
                color: isRecordingActive
                    ? colorScheme.outline
                    : colorScheme.error,
              ),
              title: const Text('Erase all local data'),
              subtitle: Text(
                isRecordingActive
                    ? 'Finish or discard your active recording first.'
                    : 'Removes every activity, gear and segment.',
              ),
              enabled: !isRecordingActive,
              onTap: isRecordingActive ? null : () => _confirmWipe(context),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppConstants.appName} · ${AppConstants.packageName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Describes a tile source.
  String _tileDescription(MapTileSource source) => switch (source) {
    MapTileSource.openStreetMap =>
      'Downloads public OSM tiles. Sends tile coordinates and your IP, '
          'never your routes.',
    MapTileSource.offline =>
      'Reads the offline tile pack bundled in this build, so no network '
          'is used.',
    MapTileSource.none =>
      'No tiles at all: routes are drawn as pure vector geometry.',
  };

  /// Wipes the local database after a confirmation.
  Future<void> _confirmWipe(BuildContext context) async {
    final recordController = context.read<RecordController>();
    if (recordController.status.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish or discard your active recording first.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text(
          'Every activity, gear and segment stored on this device will be '
          'permanently deleted. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Resolve every dependency *before* the first await so the context is
    // never used across an async gap.
    final database = context.read<AppDatabase>();
    final activities = context.read<ActivitiesController>();
    final gear = context.read<GearController>();
    final segments = context.read<SegmentsController>();

    await database.wipe();

    // Reload every list so the UI reflects the empty database.
    await Future.wait(<Future<void>>[
      activities.load(),
      gear.load(),
      segments.load(),
    ]);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All local data has been erased.')),
    );
  }
}
