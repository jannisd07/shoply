import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

// D2 X-Avo user bubble (Kap. 2.2).
const double _maxWidthShare = 0.75; // D2: 270 of 360 pt content
const double _axInset = 48; // Kap. 2.2: from AX3 full width minus 48
const double _padV = 10; // D2
const double _padH = 14; // D2
const Radius _round = Radius.circular(20); // D2
const Radius _tail = Radius.circular(6); // D2 small corner bottom right

/// The person's question: a green bubble on the right, white 17/22 text.
///
/// At most 75 % of the content width (from AX3 the full width minus 48 pt).
/// A VoiceOver heading, so the rotor jumps question by question. [note]
/// goes under the bubble ("Nicht gesendet", "Wird nach dieser Antwort
/// gesendet") with an optional text button ("Erneut senden"). A long press
/// offers "Kopieren" and [onEdit] ("Bearbeiten und neu senden").
class AvoUserBubble extends StatelessWidget {
  const AvoUserBubble({
    super.key,
    required this.text,
    this.note,
    this.noteActionLabel,
    this.onNoteAction,
    this.onEdit,
  });

  final String text;
  final String? note;
  final String? noteActionLabel;
  final VoidCallback? onNoteAction;
  final VoidCallback? onEdit;

  void _menu(BuildContext anchor) {
    showAvoMenu(
      anchor,
      items: [
        AvoMenuItem(
          label: anchor.tr('avo_copy'),
          onSelected: () => Clipboard.setData(ClipboardData(text: text)),
        ),
        if (onEdit != null)
          AvoMenuItem(label: anchor.tr('avo_edit_resend'), onSelected: onEdit!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final axLarge =
        context.typography.category.index >= ContentSizeCategory.ax3.index;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxWidth = axLarge
            ? (width - _axInset).clamp(0.0, width)
            : width * _maxWidthShare;
        final bubble = Builder(
          builder: (anchor) => GestureDetector(
            // VoiceOver gets the same choices as custom actions.
            excludeFromSemantics: true,
            onLongPress: () => _menu(anchor),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tintFill,
                  borderRadius: const BorderRadius.only(
                    topLeft: _round,
                    topRight: _round,
                    bottomLeft: _round,
                    bottomRight: _tail,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _padH,
                    vertical: _padV,
                  ),
                  child: Text(
                    text,
                    style: context.text(
                      AvoTextStyle.body,
                      color: colors.onTint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final noteText = note;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              customSemanticsActions: {
                CustomSemanticsAction(label: context.tr('avo_copy')): () =>
                    Clipboard.setData(ClipboardData(text: text)),
                if (onEdit != null)
                  CustomSemanticsAction(label: context.tr('avo_edit_resend')):
                      onEdit!,
              },
              child: bubble,
            ),
            if (noteText != null)
              Padding(
                padding: const EdgeInsets.only(top: AvoSpacing.xs),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AvoSpacing.s,
                  children: [
                    Text(
                      noteText,
                      textAlign: TextAlign.end,
                      style: context.text(
                        AvoTextStyle.footnote,
                        color: colors.secondaryLabel,
                      ),
                    ),
                    if (noteActionLabel != null && onNoteAction != null)
                      AppButton.plain(
                        label: noteActionLabel!,
                        onPressed: onNoteAction,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
