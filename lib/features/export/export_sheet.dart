import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:widgets_to_image/widgets_to_image.dart';

import '../../core/services/export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/adaptive_segmented_button.dart';
import '../../data/models/activity.dart';
import '../settings/app_settings.dart';
import 'activity_export_card.dart';

/// Bottom sheet that previews and exports the transparent PNG card of an
/// activity.
class ActivityExportSheet extends StatefulWidget {
  /// Creates the export sheet.
  const ActivityExportSheet({
    super.key,
    required this.activity,
    required this.points,
    required this.settings,
  });

  /// The activity being exported.
  final Activity activity;

  /// Geometry of the recorded route.
  final List<LatLng> points;

  /// The user preferences.
  final AppSettings settings;

  /// Shows the export sheet.
  static Future<void> show(
    BuildContext context, {
    required Activity activity,
    required List<LatLng> points,
  }) {
    final settings = context.read<AppSettings>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ActivityExportSheet(
        activity: activity,
        points: points,
        settings: settings,
      ),
    );
  }

  @override
  State<ActivityExportSheet> createState() => _ActivityExportSheetState();
}

class _ActivityExportSheetState extends State<ActivityExportSheet> {
  final WidgetsToImageController _controller = WidgetsToImageController();
  final ActivityExportService _exportService = ActivityExportService();

  /// Anchor of the share button, required by iPadOS to place the popover.
  final GlobalKey _shareButtonKey = GlobalKey();

  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  /// Whether the activity name is printed on the card.
  ///
  /// The card is supposed to contain *only* the distance, the average speed,
  /// the moving time and the route, so the caption is opt-in.
  bool _showLabel = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Captures the preview as a PNG.
  Future<Uint8List?> _capture() async {
    try {
      return await _controller.capture(
        options: const CaptureOptions(
          format: ImageFormat.png,
          pixelRatio: 3,
          waitForAnimations: true,
        ),
      );
    } on Object catch (error) {
      _showMessage('Could not render the image: $error', isError: true);
      return null;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  /// Saves the PNG into the device's public Downloads folder.
  Future<void> _save() async {
    setState(() => _busy = true);
    final bytes = await _capture();
    if (bytes == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      final location = await _exportService.savePngToDownloads(
        bytes,
        activityName: widget.activity.displayTitle,
      );
      _showMessage('Saved to $location');
    } on PlatformException catch (error) {
      _showMessage(
        error.message ?? 'Could not save the image to Downloads.',
        isError: true,
      );
    } on Object catch (error) {
      _showMessage('Could not save the image: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the native share sheet with the PNG.
  Future<void> _share() async {
    setState(() => _busy = true);
    final bytes = await _capture();
    if (bytes == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      final result = await _exportService.savePng(
        bytes,
        activityName: widget.activity.displayTitle,
      );
      await _exportService.sharePng(
        result.file,
        text: 'My TrainCenter activity',
        origin: _shareOrigin(),
      );
    } on Object catch (error) {
      _showMessage('Could not share the image: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns the screen rectangle of the share button.
  ///
  /// iPadOS requires an anchor for the share popover, otherwise the sheet is
  /// displayed in the middle of the screen.
  Rect? _shareOrigin() {
    final renderObject = _shareButtonKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  /// Builds the colour scheme used for the exported card.
  ColorScheme _exportScheme(BuildContext context) {
    final current = Theme.of(context).colorScheme;

    return switch (widget.settings.exportBrightness) {
      ExportBrightness.system => current,
      ExportBrightness.light => ColorScheme.fromSeed(
        seedColor: current.primary,
        brightness: Brightness.light,
      ),
      ExportBrightness.dark => ColorScheme.fromSeed(
        seedColor: current.primary,
        brightness: Brightness.dark,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = widget.settings;

    final exportTheme = AppTheme.build(_exportScheme(context));

    final distanceValue = _split(
      Formatters.distance(widget.activity.distanceMeters, settings.units),
    );
    final speedValue = _split(
      Formatters.speed(widget.activity.avgSpeedMps, settings.units),
    );
    final durationValue = Formatters.duration(widget.activity.movingTimeMs);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final stackActions =
        textScale > 1.35 || MediaQuery.sizeOf(context).width < 360;

    final saveButton = OutlinedButton.icon(
      onPressed: _busy ? null : _save,
      icon: const Icon(Icons.download_rounded),
      label: const Text('Save PNG'),
    );
    final shareButton = FilledButton.icon(
      key: _shareButtonKey,
      onPressed: _busy ? null : _share,
      icon: const Icon(Icons.ios_share_rounded),
      label: const Text('Share'),
    );

    return SafeArea(
      // The preview uses a fixed logical size so that the captured PNG keeps
      // its design dimensions. On short screens the sheet therefore has to
      // scroll instead of shrinking (or clipping) the card.
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Export',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A transparent PNG with only your distance, average speed, '
              'moving time and the route geometry.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // --- Preview ---------------------------------------------------
            // The card has a fixed logical size so the exported PNG always
            // has the same layout. It is *scaled* down to fit the sheet, but
            // the capture boundary keeps the original size (and therefore
            // stays sharp at 3x).
            LayoutBuilder(
              builder: (context, constraints) {
                const cardWidth = 420.0;
                const cardHeight = 520.0;
                const previewPadding = 20.0;

                final availableWidth =
                    constraints.maxWidth - previewPadding * 2;
                final scale = (availableWidth / cardWidth)
                    .clamp(0.0, 1.0)
                    .toDouble();
                final previewHeight = cardHeight * scale + previewPadding * 2;

                return ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(
                    painter: _CheckerboardPainter(
                      colorA: colorScheme.surfaceContainerHighest,
                      colorB: colorScheme.surfaceContainerLow,
                    ),
                    child: SizedBox(
                      height: previewHeight,
                      child: Padding(
                        padding: const EdgeInsets.all(previewPadding),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: WidgetsToImage(
                              controller: _controller,
                              // The card is a fixed-size graphic: keep its
                              // typography at 1x so accessibility text scaling
                              // cannot change the exported PNG layout.
                              child: MediaQuery.withNoTextScaling(
                                child: Theme(
                                  data: exportTheme,
                                  child: ActivityExportCard(
                                    points: widget.points,
                                    distanceValue: distanceValue.value,
                                    distanceUnit: distanceValue.unit,
                                    speedValue: speedValue.value,
                                    speedUnit: speedValue.unit,
                                    durationValue: durationValue,
                                    activityLabel: _showLabel
                                        ? widget.activity.displayTitle
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // --- Brightness ------------------------------------------------
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
            const SizedBox(height: 4),
            SwitchListTile(
              value: _showLabel,
              onChanged: (value) => setState(() => _showLabel = value),
              title: const Text('Print the activity name'),
              subtitle: const Text(
                'Off by default: the card only contains the statistics and '
                'the route.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            if (_message != null) ...<Widget>[
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _messageIsError
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (stackActions)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  saveButton,
                  const SizedBox(height: 8),
                  shareButton,
                ],
              )
            else
              Row(
                children: <Widget>[
                  Expanded(child: saveButton),
                  const SizedBox(width: 12),
                  Expanded(child: shareButton),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Splits "12.42 km" into the value and the unit.
  ({String value, String unit}) _split(String formatted) {
    final parts = formatted.split(' ');
    if (parts.length == 1) return (value: parts.first, unit: '');
    return (value: parts.first, unit: parts.sublist(1).join(' '));
  }
}

/// Paints a checkerboard so the transparency of the exported card is visible.
class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter({required this.colorA, required this.colorB});

  final Color colorA;
  final Color colorB;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    canvas.drawRect(Offset.zero & size, Paint()..color = colorA);

    final paint = Paint()..color = colorB;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final row = (y / cell).floor();
        final column = (x / cell).floor();
        if ((row + column).isEven) continue;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) =>
      oldDelegate.colorA != colorA || oldDelegate.colorB != colorB;
}
