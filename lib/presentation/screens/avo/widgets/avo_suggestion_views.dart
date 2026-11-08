import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_glyphs.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 chips (Kap. 2.10): visible 34 high, padding 0 14, capsule, fill,
// 15/20 medium in the label colour, a 44 pt hit height; gap 8, run gap 10.
const double _chipHeight = 34; // D2
const double _chipPadH = 14; // D2
const double _chipGap = AvoSpacing.s; // D2
const double _chipRunGap = 10; // D2
const double _disabledOpacity = 0.45; // iOS dims unavailable controls

// Empty chat (Kap. 4.1): rows at least 52 high, padding 14/16, symbol 17.
const double _rowMinHeight = 52; // D2
const double _rowPadV = 14; // D2
const double _symbolSize = 17; // D2
const double _symbolGap = AvoSpacing.m;
const double _titleGroupGap = AvoSpacing.s; // D2 8 pt
const double _footerGap = AvoSpacing.s; // D2 8 pt

/// Symbols grow with Dynamic Type up to xxxL (body 23 pt), like A's glyphs.
const double _symbolGrowthLimit = 23 / 17;

String _labelOf(BuildContext context, AvoSuggestion s) =>
    context.tr(s.key, params: s.params);

/// VoiceOver label and hint of a suggestion that sends at once.
String _semanticsOf(BuildContext context, String text, bool enabled) {
  final label = context.tr('avo_suggestion_label', params: {'text': text});
  return enabled ? label : '$label, ${context.tr('avo_needs_connection')}';
}

/// Up to two follow-up questions under the newest answer (Kap. 2.10). A tap
/// sends the question at once; without a connection they are dimmed. From
/// AX1 every chip takes the full width.
class AvoFollowUpChips extends StatelessWidget {
  const AvoFollowUpChips({
    super.key,
    required this.suggestions,
    required this.onSend,
    this.enabled = true,
  });

  final List<AvoSuggestion> suggestions;
  final ValueChanged<String> onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final ax = context.isAccessibilityText;
    final chips = [
      for (final s in suggestions)
        _SuggestionChip(
          text: _labelOf(context, s),
          expand: ax,
          onTap: enabled ? () => onSend(_labelOf(context, s)) : null,
        ),
    ];
    if (ax) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: chips,
      );
    }
    // The 44 pt hit areas already hold 5 pt above and below each chip.
    return Wrap(
      spacing: _chipGap,
      runSpacing: _chipRunGap - (AvoSizes.hitTarget - _chipHeight),
      children: chips,
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.text,
    required this.onTap,
    this.expand = false,
  });

  final String text;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    final line = context.typography.lineHeightOf(AvoTextStyle.subhead);
    final vertical = ((_chipHeight - line) / 2).clamp(0.0, _chipHeight);
    Widget chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.fill,
        shape: context.isAccessibilityText
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_chipHeight / 2),
              )
            : const StadiumBorder(),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _chipHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _chipPadH,
            vertical: vertical,
          ),
          child: Text(
            text,
            textAlign: expand ? TextAlign.start : TextAlign.center,
            style: context.text(AvoTextStyle.subhead, weight: FontWeight.w500),
          ),
        ),
      ),
    );
    if (!enabled) chip = Opacity(opacity: _disabledOpacity, child: chip);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: _semanticsOf(context, text, enabled),
      hint: context.tr('avo_suggestion_hint'),
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AvoSizes.hitTarget,
            minWidth: AvoSizes.hitTarget,
          ),
          child: Align(
            widthFactor: expand ? null : 1,
            heightFactor: 1,
            alignment: AlignmentDirectional.centerStart,
            child: chip,
          ),
        ),
      ),
    );
  }
}

/// The empty chat (Kap. 4): "Wie kann ich helfen?", three suggestions for
/// the screen the person came from (a tap sends at once), and the note on
/// what Avo uses with the link to the privacy page.
class AvoEmptyChat extends StatelessWidget {
  const AvoEmptyChat({
    super.key,
    required this.suggestions,
    required this.onSend,
    required this.onPrivacy,
    this.enabled = true,
  });

  final List<AvoSuggestion> suggestions;
  final ValueChanged<String> onSend;
  final VoidCallback onPrivacy;

  /// False offline or with the AI switched off: the rows are dimmed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Semantics(
            header: true,
            child: Text(
              context.tr('avo_empty_title'),
              style: context.text(AvoTextStyle.title3, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: _titleGroupGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AvoRadii.group),
            child: ColoredBox(
              color: colors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < suggestions.length; i++) ...[
                    if (i > 0)
                      const AvoHairline(
                        indent: AvoSpacing.l + _symbolSize + _symbolGap,
                      ),
                    _SuggestionRow(
                      suggestion: suggestions[i],
                      onTap: enabled
                          ? () => onSend(_labelOf(context, suggestions[i]))
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: _footerGap),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.screen + AvoSpacing.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('avo_empty_footer'),
                style: context.text(
                  AvoTextStyle.footnote,
                  color: colors.secondaryLabel,
                ),
              ),
              _FootnoteLink(label: context.tr('avo_privacy'), onTap: onPrivacy),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});

  final AvoSuggestion suggestion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    final text = _labelOf(context, suggestion);
    final scale =
        (context.typography.sizeOf(AvoTextStyle.body) /
                AvoTypography.forFactor(1).sizeOf(AvoTextStyle.body))
            .clamp(1.0, _symbolGrowthLimit);
    final symbol = _symbolSize * scale;
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _rowPadV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: context.typography.lineHeightOf(AvoTextStyle.body),
              child: Center(
                child: IconStyleScope(
                  size: symbol,
                  color: colors.secondaryLabel,
                  child: avoSuggestionGlyph(suggestion.symbol, size: symbol),
                ),
              ),
            ),
            const SizedBox(width: _symbolGap),
            Expanded(child: Text(text, style: context.text(AvoTextStyle.body))),
          ],
        ),
      ),
    );
    if (!enabled) row = Opacity(opacity: _disabledOpacity, child: row);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: _semanticsOf(context, text, enabled),
      hint: context.tr('avo_suggestion_hint'),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _Highlight(enabled: enabled, child: row),
      ),
    );
  }
}

/// iOS row highlight while pressed (fill under the row).
class _Highlight extends StatefulWidget {
  const _Highlight({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_Highlight> createState() => _HighlightState();
}

class _HighlightState extends State<_Highlight> {
  bool _down = false;

  void _set(bool down) {
    if (!widget.enabled || down == _down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: ColoredBox(
      color: _down
          ? context.colors.fill
          : context.colors.fill.withValues(alpha: 0),
      child: widget.child,
    ),
  );
}

/// A footnote-sized text link with a 44 pt hit height ("Datenschutz").
class _FootnoteLink extends StatelessWidget {
  const _FootnoteLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    link: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: PressableScale(
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AvoSizes.hitTarget,
          minWidth: AvoSizes.hitTarget,
        ),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            label,
            style: context.text(
              AvoTextStyle.footnote,
              color: context.colors.tint,
            ),
          ),
        ),
      ),
    ),
  );
}
