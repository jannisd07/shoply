import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';

/// Kap. 2.11: from 3,800 characters a note counts down; at 4,000 the field
/// takes nothing more.
const int avoMaxQuestionLength = 4000;
const int _warnFrom = 3800;
const double _disabledOpacity = 0.4; // Konzept 00 §12.20
const int _maxLines = 5; // Kap. 2.11: grows to five lines, then scrolls

/// The glass composer of the Avo tab (Kap. 2.11), on Teil A's
/// [AvoComposerField]: "Frag Avo …", Return and the arrow send, the round
/// button starts the voice mode while the field is empty.
///
/// [above] (the context capsule) sits 8 pt over the glass. With [enabled]
/// false (AI switched off) the composer is dimmed and takes no input; the
/// reason is the status row under the title.
class AvoComposer extends StatefulWidget {
  const AvoComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.onVoice,
    this.above,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;
  final VoidCallback? onVoice;
  final Widget? above;
  final bool enabled;

  @override
  State<AvoComposer> createState() => _AvoComposerState();
}

class _AvoComposerState extends State<AvoComposer> {
  int _length = 0;

  @override
  void initState() {
    super.initState();
    _length = widget.controller.text.length;
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant AvoComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _length = widget.controller.text.length;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    final value = widget.controller.value;
    if (value.text.length > avoMaxQuestionLength) {
      final text = value.text.substring(0, avoMaxQuestionLength);
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      return;
    }
    final length = value.text.length;
    final warnBefore = _length >= _warnFrom;
    final warnNow = length >= _warnFrom;
    if (warnBefore != warnNow || (warnNow && length != _length)) {
      setState(() => _length = length);
    } else {
      _length = length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = avoMaxQuestionLength - _length;
    final count = _length >= _warnFrom
        ? Padding(
            padding: const EdgeInsetsDirectional.only(start: AvoSpacing.l),
            child: Semantics(
              liveRegion: true,
              child: Text(
                left == 1
                    ? context.tr('avo_chars_left_one')
                    : context.tr('avo_chars_left', params: {'n': '$left'}),
                style: context.text(
                  AvoTextStyle.footnote,
                  color: context.colors.secondaryLabel,
                  tabular: true,
                ),
              ),
            ),
          )
        : null;
    final above = widget.above;
    final panel = above == null && count == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ?above,
              if (above != null && count != null)
                const SizedBox(height: AvoSpacing.xs),
              ?count,
            ],
          );

    Widget field = AvoComposerField(
      placeholder: context.tr('avo_input_placeholder'),
      sendLabel: context.tr('avo_send'),
      voiceLabel: context.tr('avo_voice_start'),
      controller: widget.controller,
      focusNode: widget.focusNode,
      onSubmitted: widget.enabled ? widget.onSend : null,
      onVoice: widget.enabled ? widget.onVoice : null,
      above: panel,
      maxLines: _maxLines,
    );
    if (!widget.enabled) {
      field = Semantics(
        enabled: false,
        child: IgnorePointer(
          child: Opacity(opacity: _disabledOpacity, child: field),
        ),
      );
    }
    return field;
  }
}
