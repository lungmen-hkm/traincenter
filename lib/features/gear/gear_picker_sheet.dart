import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/empty_state.dart';
import '../../data/models/gear.dart';
import 'gear_controller.dart';

/// Modal sheet that lets the user pick the gear used for a recording.
class GearPickerSheet extends StatelessWidget {
  /// Creates the gear picker.
  const GearPickerSheet({super.key});

  /// Shows the picker and returns the selected gear.
  static Future<Gear?> show(BuildContext context) {
    return showModalBottomSheet<Gear>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const GearPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<GearController>();
    final gear = controller.gear;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Select gear',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (gear.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.pedal_bike_rounded,
                  title: 'No gear yet',
                  message: 'Add a bicycle or a pair of shoes in the Gear tab '
                      'to attribute your activities to them.',
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: gear.length,
                  itemBuilder: (context, index) {
                    final item = gear[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.secondaryContainer,
                        foregroundColor: colorScheme.onSecondaryContainer,
                        child: Icon(
                          item.type == GearType.shoe
                              ? Icons.directions_run_rounded
                              : Icons.pedal_bike_rounded,
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: Text(item.subtitle),
                      trailing: item.isDefault
                          ? Icon(
                              Icons.star_rounded,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
