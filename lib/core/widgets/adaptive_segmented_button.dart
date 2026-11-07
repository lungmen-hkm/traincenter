import 'package:flutter/material.dart';

/// A segmented button that switches to a vertical radio list when the current
/// text scale would force labels to wrap mid-word.
///
/// Segmented buttons look compact at the default scale, but at 200 % text they
/// cannot always fit three labels on a narrow phone. The radio fallback keeps
/// the same selection semantics while giving every label the full width.
class AdaptiveSegmentedButton<T> extends StatelessWidget {
  /// Creates an adaptive segmented button.
  const AdaptiveSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  /// The options to display.
  final List<ButtonSegment<T>> segments;

  /// The currently selected option.
  final Set<T> selected;

  /// Called when the user picks another option.
  final ValueChanged<Set<T>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final useRadioList = textScale > 1.25;

    if (!useRadioList) {
      return SegmentedButton<T>(
        showSelectedIcon: false,
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
      );
    }

    return RadioGroup<T>(
      groupValue: selected.first,
      onChanged: (value) {
        if (value != null) onSelectionChanged(<T>{value});
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final segment in segments)
            RadioListTile<T>(
              value: segment.value,
              title: segment.label,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
