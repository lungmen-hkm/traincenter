import 'package:flutter/material.dart';

/// Semantic colours used by TrainCenter that are not part of the standard
/// Material 3 [ColorScheme].
///
/// Every value is *derived* from the active [ColorScheme] (no literal colour
/// constants are used), which keeps the palette perfectly in sync with the
/// dynamic / wallpaper based Material You colours.
///
/// Widgets must never read these colours directly; they should go through
/// `Theme.of(context).extension<ActivityPalette>()!` so that the palette
/// automatically follows theme changes.
@immutable
class ActivityPalette extends ThemeExtension<ActivityPalette> {
  /// Colour used for a fast segment effort / high average speed.
  final Color fast;

  /// Colour used for a medium segment effort / average speed.
  final Color medium;

  /// Colour used for a slow segment effort / low average speed.
  final Color slow;

  /// Colour used to visualise elevation gains.
  final Color elevation;

  /// Colour used to highlight a personal best (PR).
  final Color personalBest;

  /// Colour of the recorded route polyline.
  final Color route;

  /// Border / casing colour of the recorded route polyline.
  final Color routeBorder;

  /// Builds a palette derived from [scheme].
  factory ActivityPalette.from(ColorScheme scheme) {
    return ActivityPalette(
      fast: _rotateHue(scheme.primary, -120, saturationBoost: 0.08),
      medium: _rotateHue(scheme.primary, -55),
      slow: _rotateHue(scheme.primary, 120, saturationBoost: 0.08),
      elevation: _rotateHue(scheme.tertiary, 0),
      personalBest: scheme.secondary,
      route: scheme.primary,
      routeBorder: scheme.surface,
    );
  }

  /// Rotates the hue of [base] by [degrees] while keeping the saturation and
  /// lightness of the original colour.
  ///
  /// This is how "fast / medium / slow" colours are produced without ever
  /// hard-coding a hex value: the hues stay anchored to the user's dynamic
  /// primary colour.
  static Color _rotateHue(Color base, double degrees, {double saturationBoost = 0}) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withHue((hsl.hue + degrees) % 360)
        .withSaturation((hsl.saturation + saturationBoost).clamp(0.0, 1.0))
        .toColor();
  }

  const ActivityPalette({
    required this.fast,
    required this.medium,
    required this.slow,
    required this.elevation,
    required this.personalBest,
    required this.route,
    required this.routeBorder,
  });

  @override
  ActivityPalette copyWith({
    Color? fast,
    Color? medium,
    Color? slow,
    Color? elevation,
    Color? personalBest,
    Color? route,
    Color? routeBorder,
  }) {
    return ActivityPalette(
      fast: fast ?? this.fast,
      medium: medium ?? this.medium,
      slow: slow ?? this.slow,
      elevation: elevation ?? this.elevation,
      personalBest: personalBest ?? this.personalBest,
      route: route ?? this.route,
      routeBorder: routeBorder ?? this.routeBorder,
    );
  }

  @override
  ActivityPalette lerp(ThemeExtension<ActivityPalette>? other, double t) {
    if (other is! ActivityPalette) return this;
    return ActivityPalette(
      fast: Color.lerp(fast, other.fast, t)!,
      medium: Color.lerp(medium, other.medium, t)!,
      slow: Color.lerp(slow, other.slow, t)!,
      elevation: Color.lerp(elevation, other.elevation, t)!,
      personalBest: Color.lerp(personalBest, other.personalBest, t)!,
      route: Color.lerp(route, other.route, t)!,
      routeBorder: Color.lerp(routeBorder, other.routeBorder, t)!,
    );
  }
}

/// Convenience accessor for the [ActivityPalette] attached to the current
/// [ThemeData].
extension ActivityPaletteContext on BuildContext {
  ActivityPalette get activityPalette =>
      Theme.of(this).extension<ActivityPalette>() ??
      ActivityPalette.from(Theme.of(this).colorScheme);
}
