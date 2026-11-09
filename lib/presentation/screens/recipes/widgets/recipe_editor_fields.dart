import 'package:flutter/cupertino.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Vertical text padding of a 44 pt row at the default size: (44 - 22) / 2.
const double kEditorRowVertical = 11;

/// A borderless text field for the editor rows. The placeholder wraps like
/// the text, so the row grows at large text sizes instead of cutting it
/// (`CupertinoTextField` sizes its placeholder to one line).
class RecipeEditorTextField extends StatelessWidget {
  const RecipeEditorTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.placeholder,
    required this.semanticLabel,
    this.textInputAction = TextInputAction.next,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String placeholder;

  /// What VoiceOver calls the field ("Name des Rezepts").
  final String semanticLabel;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? IgnorePointer(
                  child: ExcludeSemantics(
                    child: Text(
                      placeholder,
                      style: style.copyWith(color: colors.placeholder),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Semantics(
          label: semanticLabel,
          child: CupertinoTextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            style: style,
            cursorColor: colors.tint,
            decoration: null,
            padding: EdgeInsets.zero,
            minLines: 1,
            // Grows with the text; Return still runs [textInputAction]
            // unless it is `newline`.
            maxLines: null,
            keyboardType: textInputAction == TextInputAction.newline
                ? TextInputType.multiline
                : keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// A friendly sentence under a field when something required is missing
/// ("Gib dem Rezept einen Namen."), with `exclamationmark.circle`, in the
/// destructive colour. Announced when it appears.
class RecipeEditorError extends StatelessWidget {
  const RecipeEditorError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text(AvoTextStyle.subhead, color: colors.destructive);
    final iconSize = context.typography.sizeOf(AvoTextStyle.subhead);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xxs),
            child: AvoIcon(
              AvoIcons.exclamationmarkCircle,
              size: iconSize,
              color: colors.destructive,
            ),
          ),
          const SizedBox(width: AvoSpacing.s - AvoSpacing.xxs),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// The red "Löschen" behind a row swiped to the left.
class RecipeEditorDeleteBackground extends StatelessWidget {
  const RecipeEditorDeleteBackground({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.red,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
          child: Text(
            label,
            style: context.text(
              AvoTextStyle.body,
              color: colors.onTint,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
