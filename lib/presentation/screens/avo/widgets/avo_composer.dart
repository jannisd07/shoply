import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

/// Kap. 2.11: at 4,000 characters the field takes nothing more; Teil A's
/// [AvoComposerField] counts down from 5 % left (3,800).
const int avoMaxQuestionLength = 4000;
const int _maxLines = 5; // Kap. 2.11: grows to five lines, then scrolls

/// The glass composer of the Avo tab (Kap. 2.11), on Teil A's
/// [AvoComposerField] with Avo's texts: "Frag Avo …" (VoiceOver "Avo
/// fragen"), Return and the arrow send, the round button starts the voice
/// mode while the field is empty and becomes "Antwort anhalten" while Avo
/// answers and the field is empty ([responding] with [onStop]). The camera button opens
/// [photoMenuItems] as a pull-down; the counter and the 4,000 limit are A's.
///
/// [above] (the context capsule) sits 8 pt over the glass. With [enabled]
/// false (AI switched off) the composer is dimmed and takes no input; the
/// reason is the status row under the title.
class AvoComposer extends StatelessWidget {
  const AvoComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.onVoice,
    this.photoMenuItems,
    this.onStop,
    this.responding = false,
    this.above,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;
  final VoidCallback? onVoice;

  /// "Foto hinzufügen" (Kap. 2.11): "Foto aufnehmen / Foto auswählen".
  final List<AvoMenuEntry>? photoMenuItems;

  /// Stops Avo's running answer.
  final VoidCallback? onStop;

  /// True while Avo answers.
  final bool responding;
  final Widget? above;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Kap. 2.11 / 3: "Antwort anhalten" only while the field is empty; with
    // text the button sends, and the question waits for the answer
    // ("Wird nach dieser Antwort gesendet").
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) =>
          _field(context, stopping: responding && value.text.isEmpty),
    );
  }

  Widget _field(BuildContext context, {required bool stopping}) {
    return AvoComposerField(
      placeholder: context.tr('avo_input_placeholder'),
      semanticLabel: context.tr('avo_input_label'),
      sendLabel: context.tr('avo_send'),
      voiceLabel: context.tr('avo_voice_start'),
      cameraLabel: context.tr('avo_photo_add'),
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onSubmitted: onSend,
      onVoice: onVoice,
      onStop: onStop,
      responding: stopping,
      photoMenuItems: photoMenuItems,
      maxLength: avoMaxQuestionLength,
      above: above,
      maxLines: _maxLines,
    );
  }
}
