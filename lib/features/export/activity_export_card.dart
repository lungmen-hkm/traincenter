import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/widgets/route_painter.dart';

/// The shareable activity card.
///
/// The card is rendered on a **fully transparent** background and contains
/// exactly the three statistics required by the product spec plus the route
/// geometry:
///
///  * distance
///  * average speed
///  * moving time
///
/// The route is drawn as a *vector* polyline (see [RoutePainter]) instead of a
/// map screenshot, which means the exported PNG stays razor sharp at any
/// resolution and never contains third party map imagery.
///
/// The optional [activityLabel] is opt-in so that the default export really
/// contains *only* the four elements above.
class ActivityExportCard extends StatelessWidget {
  /// Creates the export card.
  const ActivityExportCard({
    super.key,
    required this.points,
    required this.distanceValue,
    required this.distanceUnit,
    required this.speedValue,
    required this.speedUnit,
    required this.durationValue,
    this.activityLabel,
    this.routeColor,
    this.routeBorderColor,
    this.textColor,
    this.mutedColor,
    this.width = 420,
    this.height = 520,
  });

  /// Geometry of the recorded route.
  final List<LatLng> points;

  /// Formatted distance, e.g. "42.18".
  final String distanceValue;

  /// Distance unit, e.g. "km".
  final String distanceUnit;

  /// Formatted average speed, e.g. "28.4".
  final String speedValue;

  /// Speed unit, e.g. "km/h".
  final String speedUnit;

  /// Formatted duration, e.g. "1:12:30".
  final String durationValue;

  /// Optional caption rendered above the statistics.
  final String? activityLabel;

  /// Colour of the route stroke.
  final Color? routeColor;

  /// Colour of the route casing.
  final Color? routeBorderColor;

  /// Colour of the primary text.
  final Color? textColor;

  /// Colour of the secondary text.
  final Color? mutedColor;

  /// Logical width of the card.
  final double width;

  /// Logical height of the card.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The card is rendered on a transparent background on purpose: the
    // exported PNG can be placed on any surface.
    final primary = textColor ?? colorScheme.onSurface;
    final secondary = mutedColor ?? colorScheme.onSurfaceVariant;
    final stroke = routeColor ?? colorScheme.primary;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // --- Route (vector) ------------------------------------------------
          SizedBox(
            width: width,
            height: height * 0.58,
            child: CustomPaint(
              painter: RoutePainter(
                points: points,
                color: stroke,
                borderColor: routeBorderColor,
                strokeWidth: 7,
                borderStrokeWidth: 2,
                // The spec allows only the polyline: no start/end dots.
                showEndpoints: false,
                padding: 28,
              ),
            ),
          ),

          // Push the statistics to the bottom of the card.
          const Spacer(),

          // --- Caption -------------------------------------------------------
          if (activityLabel != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              activityLabel!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: secondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // --- Statistics ----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _ExportStat(
                  label: 'Distance',
                  value: distanceValue,
                  unit: distanceUnit,
                  valueColor: primary,
                  labelColor: secondary,
                ),
              ),
              Expanded(
                child: _ExportStat(
                  label: 'Avg speed',
                  value: speedValue,
                  unit: speedUnit,
                  valueColor: primary,
                  labelColor: secondary,
                ),
              ),
              Expanded(
                child: _ExportStat(
                  label: 'Moving time',
                  value: durationValue,
                  unit: null,
                  valueColor: primary,
                  labelColor: secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single statistic of the export card.
class _ExportStat extends StatelessWidget {
  const _ExportStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final String? unit;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: theme.textTheme.labelMedium?.copyWith(color: labelColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
