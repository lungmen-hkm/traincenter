import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A Material 3 "slide to confirm" action.
///
/// The user has to drag the thumb all the way to the right to confirm the
/// action. This deliberately requires a *gesture* instead of a simple tap so
/// that saving an activity (or any other destructive action) can never be
/// triggered accidentally.
///
/// The widget is fully themed: every colour is taken from the ambient
/// [ColorScheme], there is not a single hard-coded colour value.
class SlideToConfirm extends StatefulWidget {
  /// Creates a slide-to-confirm action.
  const SlideToConfirm({
    super.key,
    required this.onConfirmed,
    this.label = 'Slide to save',
    this.confirmedLabel = 'Saved',
    this.enabled = true,
    this.height = 64,
    this.icon = Icons.arrow_forward_rounded,
    this.onCancelled,
  });

  /// Called once the thumb has been dragged past the confirmation threshold.
  final VoidCallback onConfirmed;

  /// Label displayed behind the thumb.
  final String label;

  /// Label displayed once the action has been confirmed.
  final String confirmedLabel;

  /// Whether the action can currently be triggered.
  final bool enabled;

  /// Height of the whole control.
  final double height;

  /// Icon rendered inside the thumb.
  final IconData icon;

  /// Called when the user releases the thumb before the threshold.
  final VoidCallback? onCancelled;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  /// Fraction of the track that has to be travelled to confirm the action.
  static const double _confirmThreshold = 0.85;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  Animation<double>? _animation;
  double _dragX = 0;
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Current horizontal offset of the thumb.
  double get _offset => _animation?.value ?? _dragX;

  /// Animates the thumb to [target].
  void _animateTo(double target) {
    _animation = Tween<double>(begin: _dragX, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..removeListener(_handleAnimationTick)
      ..addListener(_handleAnimationTick)
      ..forward(from: 0);
  }

  void _handleAnimationTick() {
    final animation = _animation;
    if (animation == null) return;
    setState(() => _dragX = animation.value);
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxTravel) {
    if (!widget.enabled || _confirmed) return;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0.0, maxTravel);
    });
  }

  void _handleDragEnd(double maxTravel) {
    if (!widget.enabled || _confirmed) return;

    if (maxTravel > 0 && _dragX >= maxTravel * _confirmThreshold) {
      _confirmed = true;
      _animateTo(maxTravel);
      HapticFeedback.mediumImpact();
      widget.onConfirmed();
    } else {
      _animateTo(0);
      if (widget.onCancelled != null) widget.onCancelled!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbSize = widget.height - 12;
        final horizontalPadding = 6.0;
        final maxTravel =
            (constraints.maxWidth - thumbSize - horizontalPadding * 2).clamp(0.0, double.infinity);

        final trackColor = _confirmed
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest;
        final labelColor = _confirmed
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant;
        final thumbColor = _confirmed ? colorScheme.primary : colorScheme.surface;
        final onThumbColor = _confirmed
            ? colorScheme.onPrimary
            : colorScheme.onSurfaceVariant;

        return Semantics(
          button: true,
          enabled: widget.enabled && !_confirmed,
          label: widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) => _handleDragUpdate(details, maxTravel),
            onHorizontalDragEnd: (_) => _handleDragEnd(maxTravel),
            onHorizontalDragCancel: () => _handleDragEnd(maxTravel),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  // Track.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(left: thumbSize + 8, right: 16),
                      child: Text(
                        _confirmed ? widget.confirmedLabel : widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),

                  // Thumb.
                  Transform.translate(
                    offset: Offset(horizontalPadding + _offset, 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: thumbColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _confirmed ? Icons.check_rounded : widget.icon,
                        color: onThumbColor,
                        size: thumbSize * 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
