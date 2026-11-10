import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/section_header.dart';
import 'trainercraft_controller.dart';

/// Material 3 dashboard for the TrainerCraft companion bridge.
///
/// The screen intentionally uses only colours from the ambient [ColorScheme],
/// so it follows TrainCenter's dynamic Material You palette automatically.
class TrainerCraftScreen extends StatefulWidget {
  /// Creates the TrainerCraft screen.
  const TrainerCraftScreen({super.key});

  @override
  State<TrainerCraftScreen> createState() => _TrainerCraftScreenState();
}

class _TrainerCraftScreenState extends State<TrainerCraftScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TrainerCraftController>().refreshMinecraftInstallation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainerCraftController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrainerCraft'),
        actions: <Widget>[
          if (controller.isRunning || controller.isScanning)
            IconButton(
              tooltip: 'Stop bridge',
              onPressed: controller.stop,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _BridgeCard(controller: controller),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Live telemetry',
            subtitle: 'Speed is sent to Minecraft five times per second',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  icon: Icons.speed_rounded,
                  label: 'Current speed',
                  value: controller.speedKmh.toStringAsFixed(1),
                  unit: 'km/h',
                  emphasis: controller.isRunning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.navigation_rounded,
                  label: 'Top speed',
                  value: controller.topSpeedKmh.toStringAsFixed(1),
                  unit: 'km/h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Connection',
            subtitle: 'Everything stays on your local network',
          ),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                _StatusRow(
                  icon: Icons.dns_outlined,
                  title: 'Bridge server',
                  value: controller.serverRunning
                      ? 'Listening on port 8000'
                      : 'Not running',
                  active: controller.serverRunning,
                ),
                const Divider(height: 1),
                _StatusRow(
                  icon: Icons.sports_esports_outlined,
                  title: 'Minecraft',
                  value: controller.gameConnected
                      ? 'Connected to the bridge'
                      : controller.serverRunning
                      ? 'Waiting for the game'
                      : 'Not connected',
                  active: controller.gameConnected,
                  pending: controller.serverRunning,
                ),
                const Divider(height: 1),
                _StatusRow(
                  icon: Icons.bluetooth_outlined,
                  title: 'Speed sensor',
                  value: controller.isRunning
                      ? 'Connected'
                      : controller.isScanning
                      ? 'Scanning for a sensor…'
                      : 'Not connected',
                  active: controller.isRunning,
                  pending: controller.isScanning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Wheel setup',
            subtitle: 'Circumference used for the speed calculation',
          ),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.adjust_rounded),
              title: const Text('Wheel circumference'),
              subtitle: Text(
                '${controller.tirePreset.label} · '
                '${controller.tirePreset.circumferenceMeters.toStringAsFixed(3)} m',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showTireSizePicker(context, controller),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Minecraft',
            subtitle: 'Bedrock Edition with the TrainerCraft add-on',
          ),
          _MinecraftCard(controller: controller),
          const SizedBox(height: 24),
          _PrivacyNote(colorScheme: Theme.of(context).colorScheme),
        ],
      ),
    );
  }

  Future<void> _showTireSizePicker(
    BuildContext context,
    TrainerCraftController controller,
  ) async {
    final selected = await showModalBottomSheet<TirePreset>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Wheel circumference',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              RadioGroup<TirePreset>(
                groupValue: controller.tirePreset,
                onChanged: (value) {
                  if (value != null) Navigator.of(sheetContext).pop(value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final preset in trainerCraftTirePresets)
                      RadioListTile<TirePreset>(
                        value: preset,
                        title: Text(preset.label),
                        subtitle: Text(
                          '${preset.circumferenceMeters.toStringAsFixed(3)} m',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) controller.setTirePreset(selected);
  }
}

/// Hero card with the bridge status and the start/stop action.
class _BridgeCard extends StatelessWidget {
  const _BridgeCard({required this.controller});

  final TrainerCraftController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isError = controller.phase == TrainerCraftPhase.error;
    final isRunning = controller.isRunning;
    final isScanning = controller.isScanning;

    final background = isError
        ? colorScheme.errorContainer
        : isRunning
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerLow;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : isRunning
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isRunning
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : isRunning
                        ? Icons.sensors_rounded
                        : isScanning
                        ? Icons.bluetooth_searching_rounded
                        : Icons.sports_esports_rounded,
                    color: isRunning
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _phaseTitle(controller),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _phaseMessage(controller),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isScanning || isRunning
                    ? controller.stop
                    : controller.start,
                icon: isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                label: Text(
                  isScanning
                      ? 'Cancel scan'
                      : isRunning
                      ? 'Stop bridge'
                      : 'Start bridge',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseTitle(TrainerCraftController controller) {
    return switch (controller.phase) {
      TrainerCraftPhase.idle => 'Bridge is idle',
      TrainerCraftPhase.scanning => 'Scanning for a speed sensor',
      TrainerCraftPhase.running => 'Bridge is live',
      TrainerCraftPhase.timeout => 'Sensor not found',
      TrainerCraftPhase.error => 'Bridge error',
    };
  }

  String _phaseMessage(TrainerCraftController controller) {
    return switch (controller.phase) {
      TrainerCraftPhase.idle =>
        'Start the bridge to pair a Bluetooth speed sensor and stream live '
            'speed into Minecraft.',
      TrainerCraftPhase.scanning =>
        'Keep the sensor awake and close to this phone.',
      TrainerCraftPhase.running =>
        controller.gameConnected
            ? 'Minecraft is connected. Live speed is being streamed.'
            : 'Sensor connected. Waiting for Minecraft to join the local server.',
      TrainerCraftPhase.timeout =>
        'No speed or cadence sensor answered within 10 seconds. Try again.',
      TrainerCraftPhase.error =>
        controller.errorMessage ?? 'Something went wrong.',
    };
  }
}

/// A compact speed statistic.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = emphasis
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerLow;
    final foreground = emphasis
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final muted = emphasis
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                children: <InlineSpan>[
                  TextSpan(
                    text: ' $unit',
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                ],
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the connection card.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.value,
    this.active = false,
    this.pending = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool active;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipBackground = active
        ? colorScheme.primaryContainer
        : pending
        ? colorScheme.tertiaryContainer
        : colorScheme.surfaceContainerHighest;
    final chipForeground = active
        ? colorScheme.onPrimaryContainer
        : pending
        ? colorScheme.onTertiaryContainer
        : colorScheme.onSurfaceVariant;

    return ListTile(
      leading: Icon(
        icon,
        color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text(value),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: chipBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          active
              ? 'Active'
              : pending
              ? 'Waiting'
              : 'Off',
          style: theme.textTheme.labelSmall?.copyWith(
            color: chipForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Minecraft installation status and launch action.
class _MinecraftCard extends StatelessWidget {
  const _MinecraftCard({required this.controller});

  final TrainerCraftController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final status = controller.checkingMinecraft
        ? 'Checking installation…'
        : switch (controller.minecraftInstalled) {
            true => 'Installed on this device',
            false => 'Not installed — the Play Store page will open',
            null => 'Installation status is unavailable on this platform',
          };

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.videogame_asset_outlined),
            title: const Text('Minecraft Bedrock'),
            subtitle: Text(status),
            trailing: controller.checkingMinecraft
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Refresh Minecraft status',
                    onPressed: controller.refreshMinecraftInstallation,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final opened = await controller.launchMinecraft();
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          controller.errorMessage ??
                              'Could not open Minecraft.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  controller.minecraftInstalled == false
                      ? 'Open Play Store'
                      : 'Open Minecraft',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Privacy reassurance at the bottom of the screen.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'TrainerCraft streams speed over a local WebSocket on port '
                '8000. No account, cloud service or analytics are involved.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
