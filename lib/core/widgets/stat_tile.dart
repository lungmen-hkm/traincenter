import 'package:flutter/material.dart';

/// A compact statistic tile used across the recording, summary and detail
/// screens.
///
/// Colours are taken exclusively from the ambient [ColorScheme].
class StatTile extends StatelessWidget {
  /// Creates a statistic tile.
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.emphasis = false,
  });

  /// Name of the statistic, e.g. "Distance".
  final String label;

  /// Formatted value, e.g. "12.42".
  final String value;

  /// Optional unit shown next to the value, e.g. "km".
  final String? unit;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the tile is rendered as a primary (highlighted) statistic.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final background = emphasis ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow;
    final foreground = emphasis ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final muted = emphasis ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: muted),
                const SizedBox(width: 6),
              ],
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
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
