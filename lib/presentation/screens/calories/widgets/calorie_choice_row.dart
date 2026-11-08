import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

const double _kRowMinHeight = 52; // D2 X-Profil `.row`
const double _kRowVertical = 9; // D2
const double _kCheckGlyph = 17; // D2 checkmark

/// One option of a single choice inside an inset group (S14 "Ziel",
/// "Alltag"): title, optional grey subtitle, a tinted checkmark when chosen.
/// VoiceOver reads a radio button in a group ("Abnehmen, ausgewählt, 1 von
/// 3" comes from the group order). [enabled] false greys it and the
/// subtitle says why ("Für unter 18-Jährige …").
class CalorieChoiceRow extends StatefulWidget {
  const CalorieChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<CalorieChoiceRow> createState() => _CalorieChoiceRowState();
}

class _CalorieChoiceRowState extends State<CalorieChoiceRow> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.enabled;
    final subtitle = widget.subtitle;
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      button: true,
      enabled: enabled,
      label: widget.title,
      hint: subtitle,
      onTap: enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: enabled
            ? () {
                if (!widget.selected) widget.onTap();
              }
            : null,
        child: ColoredBox(
          color: _pressed ? colors.fill : colors.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kRowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kRowVertical),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: context.text(
                            AvoTextStyle.body,
                            color: enabled ? colors.label : colors.secondaryLabel,
                          ),
                        ),
                        if (subtitle != null)
                          Text(subtitle, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                  SizedBox(
                    width: _kCheckGlyph,
                    child: widget.selected
                        ? AvoIcon(AvoIcons.check, size: _kCheckGlyph, color: colors.tint)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
