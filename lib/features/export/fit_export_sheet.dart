import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/export_service.dart';
import '../../core/services/fit_export_service.dart';
import '../../data/models/activity.dart';
import '../../data/models/gear.dart';
import '../../data/models/track_point.dart';

/// Bottom sheet that exports an activity as a Garmin-compatible FIT file.
class FitExportSheet extends StatefulWidget {
  /// Creates the FIT export sheet.
  const FitExportSheet({
    super.key,
    required this.activity,
    required this.points,
    required this.gearType,
  });

  /// The activity being exported.
  final Activity activity;

  /// The recorded GPS samples.
  final List<TrackPoint> points;

  /// Gear type used to derive the FIT sport.
  final GearType? gearType;

  /// Shows the FIT export sheet.
  static Future<void> show(
    BuildContext context, {
    required Activity activity,
    required List<TrackPoint> points,
    required GearType? gearType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FitExportSheet(
        activity: activity,
        points: points,
        gearType: gearType,
      ),
    );
  }

  @override
  State<FitExportSheet> createState() => _FitExportSheetState();
}

class _FitExportSheetState extends State<FitExportSheet> {
  static const FitExportService _encoder = FitExportService();

  final ActivityExportService _exportService = ActivityExportService();

  /// Anchor of the share button, required by iPadOS to place the popover.
  final GlobalKey _shareButtonKey = GlobalKey();

  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  /// Encodes the activity into FIT bytes.
  Uint8List _encode() {
    return _encoder.encodeActivity(
      activity: widget.activity,
      points: widget.points,
      gearType: widget.gearType,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  /// Saves the FIT file into the device's public Downloads folder.
  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final bytes = _encode();
      final location = await _exportService.saveFitToDownloads(
        bytes,
        activityName: widget.activity.displayTitle,
      );
      _showMessage('Saved to $location');
    } on PlatformException catch (error) {
      _showMessage(
        error.message ?? 'Could not save the FIT file to Downloads.',
        isError: true,
      );
    } on Object catch (error) {
      _showMessage('Could not save the FIT file: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the native share sheet with the FIT file.
  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = _encode();
      final result = await _exportService.saveFit(
        bytes,
        activityName: widget.activity.displayTitle,
      );
      await _exportService.shareFit(
        result.file,
        text: 'My TrainCenter activity',
        origin: _shareOrigin(),
      );
    } on Object catch (error) {
      _showMessage('Could not share the FIT file: $error', isError: true);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sportLabel = switch (widget.gearType) {
      GearType.bicycle => 'Cycling',
      GearType.shoe => 'Running',
      null => 'Other',
    };
    final sampleCount = widget.points.length;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final stackActions =
        textScale > 1.35 || MediaQuery.sizeOf(context).width < 360;

    final saveButton = OutlinedButton.icon(
      onPressed: _busy ? null : _save,
      icon: const Icon(Icons.download_rounded),
      label: const Text('Save FIT'),
    );
    final shareButton = FilledButton.icon(
      key: _shareButtonKey,
      onPressed: _busy ? null : _share,
      icon: const Icon(Icons.ios_share_rounded),
      label: const Text('Share'),
    );

    return SafeArea(
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
              'Export FIT',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A Garmin-compatible .fit file with your GPS track, timestamps, '
              'distance, speed and elevation. Import it into Garmin Connect, '
              'Strava or another training app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // --- Summary ---------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: <Widget>[
                  _SummaryRow(
                    icon: Icons.sports_rounded,
                    label: 'Sport',
                    value: sportLabel,
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    icon: Icons.route_rounded,
                    label: 'Samples',
                    value:
                        '$sampleCount GPS ${sampleCount == 1 ? 'sample' : 'samples'}',
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    icon: Icons.insert_drive_file_outlined,
                    label: 'Format',
                    value: 'FIT activity',
                  ),
                ],
              ),
            ),

            if (sampleCount == 0) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This activity has no GPS samples. The FIT file will '
                      'contain the summary but no route.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
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
}

/// A label / value row inside the FIT summary card.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
