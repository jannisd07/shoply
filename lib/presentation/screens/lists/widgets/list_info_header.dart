import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';

/// Corner radius of the name field: a capsule on one line (title2 line 28 +
/// 2 × 12 padding = 52), a rounded rectangle when the name wraps.
const double _kFieldRadius = 26;

/// Space between the glyph and the name field, and below the field.
const double _kGap = AvoSpacing.l;

/// The list name as an editable capsule (Konzept 11 §8/§10.1: `title2` bold,
/// centred, `fill` capsule). Wraps over several lines instead of cutting the
/// name; Return finishes editing.
class ListNameField extends StatelessWidget {
  const ListNameField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text(AvoTextStyle.title2, weight: FontWeight.w700);
    return Semantics(
      textField: true,
      label: context.tr('list_ov_name_field'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(_kFieldRadius),
        ),
        child: CupertinoTextField.borderless(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          placeholder: context.tr('list_ov_name_placeholder'),
          placeholderStyle: style.copyWith(color: colors.placeholder),
          style: style,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          minLines: 1,
          maxLines: null,
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: AvoSpacing.m,
          ),
          onSubmitted: onSubmitted,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// The head of Neue Liste and Listen-Info: the 64 pt glyph, the name field
/// and an optional line below ("Erstellt von Jannis · seit 12. Okt.").
class ListInfoHeader extends StatelessWidget {
  const ListInfoHeader({
    super.key,
    required this.color,
    required this.field,
    this.coverUrl,
    this.caption,
  });

  final Color color;
  final String? coverUrl;
  final Widget field;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final line = caption;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AnimatedSwitcher(
              // A colour change cross-fades; nothing moves.
              duration: AvoMotion.fadeReduced,
              child: ListGlyph(
                key: ValueKey('${color.toARGB32()}|$coverUrl'),
                color: color,
                coverUrl: coverUrl,
              ),
            ),
          ),
          const SizedBox(height: _kGap),
          field,
          if (line != null) ...[
            const SizedBox(height: AvoSpacing.s),
            Text(
              line,
              textAlign: TextAlign.center,
              style: context.text(
                AvoTextStyle.subhead,
                color: context.colors.secondaryLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
