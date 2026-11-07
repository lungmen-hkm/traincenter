import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/activity_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/gear.dart';
import '../settings/app_settings.dart';
import 'gear_controller.dart';
import 'gear_form_sheet.dart';

/// Manages the bicycles and shoes used for recording.
class GearScreen extends StatelessWidget {
  /// Creates the gear screen.
  const GearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<GearController>();
    final settings = context.watch<AppSettings>();
    final units = settings.units;

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bicycles = controller.gear
        .where((item) => item.type == GearType.bicycle)
        .toList(growable: false);
    final shoes = controller.gear
        .where((item) => item.type == GearType.shoe)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_gear_fab',
        onPressed: () => GearFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add gear'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          if (controller.gear.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.pedal_bike_rounded,
                title: 'No gear yet',
                message:
                    'Add a bicycle or a pair of shoes to keep track of the '
                    'distance you cover with each of them.',
              ),
            )
          else ...<Widget>[
            if (bicycles.isNotEmpty) ...<Widget>[
              const SectionHeader(
                title: 'Bicycles',
                subtitle: 'Distance accumulates over every ride',
              ),
              ...bicycles.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GearCard(gear: item, units: units),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (shoes.isNotEmpty) ...<Widget>[
              const SectionHeader(
                title: 'Shoes',
                subtitle: 'Distance accumulates over every run',
              ),
              ...shoes.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GearCard(gear: item, units: units),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Gear data never leaves this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single piece of equipment.
class _GearCard extends StatelessWidget {
  const _GearCard({required this.gear, required this.units});

  final Gear gear;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.activityPalette;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => GearFormSheet.show(context, gear: gear),
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
                  gear.type == GearType.shoe
                      ? Icons.directions_run_rounded
                      : Icons.pedal_bike_rounded,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            gear.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (gear.isDefault) ...<Widget>[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: palette.personalBest,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${gear.subtitle} · ${Formatters.distance(gear.totalDistanceMeters, units)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _onMenuSelected(context, value),
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(
                    value: 'default',
                    child: Text('Set as default'),
                  ),
                  PopupMenuItem<String>(
                    value: 'reset',
                    child: Text('Reset distance'),
                  ),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles the overflow menu actions.
  Future<void> _onMenuSelected(BuildContext context, String value) async {
    final controller = context.read<GearController>();

    switch (value) {
      case 'edit':
        if (context.mounted) {
          await GearFormSheet.show(context, gear: gear);
        }

      case 'default':
        await controller.setDefault(gear);

      case 'reset':
        await controller.resetDistance(gear);

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete gear?'),
            content: const Text(
              'The gear will be removed. Activities recorded with it are kept.',
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
          await controller.delete(gear);
        }
    }
  }
}
