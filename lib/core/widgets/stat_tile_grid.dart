import 'package:flutter/material.dart';

/// Arranges [StatTile]s in two columns, falling back to a single column when
/// large text or a narrow window would truncate their labels.
class StatTileGrid extends StatelessWidget {
  /// Creates a grid of statistic tiles.
  const StatTileGrid({super.key, required this.children, this.spacing = 12});

  /// The tiles, in display order.
  final List<Widget> children;

  /// Gap between rows and columns.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = textScale > 1.35 || constraints.maxWidth < 328;

        if (singleColumn) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) SizedBox(height: spacing),
                SizedBox(width: double.infinity, child: children[i]),
              ],
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < children.length; i += 2) ...<Widget>[
              if (i > 0) SizedBox(height: spacing),
              Row(
                children: <Widget>[
                  Expanded(child: children[i]),
                  if (i + 1 < children.length) ...<Widget>[
                    SizedBox(width: spacing),
                    Expanded(child: children[i + 1]),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
