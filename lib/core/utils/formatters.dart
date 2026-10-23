import 'package:intl/intl.dart';

/// Unit system used to display distances, speeds and elevation.
enum UnitSystem {
  /// Kilometres, metres, km/h.
  metric,

  /// Miles, feet, mph.
  imperial;

  /// Label used in the settings UI.
  String get label => switch (this) {
        UnitSystem.metric => 'Metric (km)',
        UnitSystem.imperial => 'Imperial (mi)',
      };
}

/// Stateless helpers that turn raw SI values into human readable strings.
///
/// All formatting is locale aware through [intl] and the unit system is
/// supplied by the caller so the same helper works for both metric and
/// imperial users.
abstract final class Formatters {
  static final NumberFormat _oneDecimal = NumberFormat('#,##0.0');
  static final NumberFormat _twoDecimals = NumberFormat('#,##0.00');
  static final NumberFormat _integer = NumberFormat('#,##0');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _time = DateFormat('HH:mm:ss');

  /// Formats a distance in metres using the requested [units].
  ///
  /// Metric uses kilometres, imperial uses miles.
  static String distance(double meters, UnitSystem units, {int decimals = 2}) {
    final value = switch (units) {
      UnitSystem.metric => meters / 1000.0,
      UnitSystem.imperial => meters / 1609.344,
    };
    final formatted = decimals == 0
        ? _integer.format(value)
        : (decimals == 1 ? _oneDecimal.format(value) : _twoDecimals.format(value));
    final suffix = switch (units) {
      UnitSystem.metric => 'km',
      UnitSystem.imperial => 'mi',
    };
    return '$formatted $suffix';
  }

  /// Formats a distance using the *short* unit label only (e.g. "km").
  static String distanceUnit(UnitSystem units) => switch (units) {
        UnitSystem.metric => 'km',
        UnitSystem.imperial => 'mi',
      };

  /// Formats a speed in metres per second.
  static String speed(double metersPerSecond, UnitSystem units) {
    final value = switch (units) {
      UnitSystem.metric => metersPerSecond * 3.6,
      UnitSystem.imperial => metersPerSecond * 2.2369362920544,
    };
    final suffix = switch (units) {
      UnitSystem.metric => 'km/h',
      UnitSystem.imperial => 'mph',
    };
    return '${_oneDecimal.format(value)} $suffix';
  }

  /// Formats an elevation in metres using feet for imperial users.
  static String elevation(double meters, UnitSystem units) {
    final value = switch (units) {
      UnitSystem.metric => meters,
      UnitSystem.imperial => meters * 3.280839895,
    };
    final suffix = switch (units) {
      UnitSystem.metric => 'm',
      UnitSystem.imperial => 'ft',
    };
    return '${_integer.format(value)} $suffix';
  }

  /// Formats a duration given in milliseconds as `H:MM:SS` / `MM:SS`.
  static String duration(int milliseconds) {
    final total = Duration(milliseconds: milliseconds);
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Formats a duration using the long form, e.g. `1 h 05 min 12 s`.
  static String durationLong(int milliseconds) {
    final total = Duration(milliseconds: milliseconds);
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    final parts = <String>[
      if (hours > 0) '$hours h',
      if (minutes > 0 || hours > 0) '${minutes.toString().padLeft(2, '0')} min',
      '${seconds.toString().padLeft(2, '0')} s',
    ];
    return parts.join(' ');
  }

  /// Formats a timestamp as `d MMM yyyy, HH:mm`.
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  /// Formats a timestamp as `d MMM yyyy`.
  static String date(DateTime value) => _date.format(value.toLocal());

  /// Formats a timestamp as `HH:mm:ss`.
  static String time(DateTime value) => _time.format(value.toLocal());

  /// Formats a pace (seconds per kilometre / per mile).
  static String pace(double metersPerSecond, UnitSystem units) {
    if (metersPerSecond <= 0) return '--:-- /km';
    final metersPerUnit = switch (units) {
      UnitSystem.metric => 1000.0,
      UnitSystem.imperial => 1609.344,
    };
    final secondsPerUnit = metersPerUnit / metersPerSecond;
    final minutes = secondsPerUnit ~/ 60;
    final seconds = (secondsPerUnit % 60).round();
    final unit = switch (units) {
      UnitSystem.metric => 'km',
      UnitSystem.imperial => 'mi',
    };
    return '$minutes:${seconds.toString().padLeft(2, '0')} /$unit';
  }
}
