import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 choice card (Kap. 2.6): answer rows at least 56 high, cover or glyph
// 36, name 17/22, subtitle 15/20 secondary, no chevron.
const double _rowMinHeight = 56; // D2
const double _rowPadV = AvoSpacing.s;
const double _leading = 36; // D2
const double _gap = AvoSpacing.m;
const double _check = 20; // D2 checkmark
const int _collapsedRows = 5; // Kap. 2.6: from 6 lists the 5 newest
const double _dimmed = 0.45; // iOS dims unavailable rows

/// One possible answer of an [AvoChoiceCard].
@immutable
class AvoChoiceOption {
  const AvoChoiceOption({
    required this.id,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// 36 pt cover or glyph square; left out from AX1.
  final Widget? leading;
}

/// Avo asks back ("Auf welche Liste?", Kap. 2.6): a white group of answer
/// rows under Avo's question.
///
/// After the choice the chosen row gets a checkmark and the others turn
/// secondary and inactive. When a newer question came before an answer
/// ([stale]) every row is inactive with "Nicht beantwortet". From six
/// options the five first ones show with "Alle Listen anzeigen".
class AvoChoiceCard extends StatefulWidget {
  const AvoChoiceCard({
    super.key,
    required this.options,
    required this.onSelect,
    this.selectedId,
    this.stale = false,
    this.enabled = true,
  });

  final List<AvoChoiceOption> options;
  final ValueChanged<String> onSelect;
  final String? selectedId;
  final bool stale;

  /// False offline: the rows are dimmed until there is a connection.
  final bool enabled;

  @override
  State<AvoChoiceCard> createState() => _AvoChoiceCardState();
}

class _AvoChoiceCardState extends State<AvoChoiceCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final options = widget.options;
    final collapsible = options.length > _collapsedRows;
    final shown = collapsible && !_all && widget.selectedId == null
        ? options.take(_collapsedRows).toList()
        : options;
    final answered = widget.selectedId != null;
    final ax = context.isAccessibilityText;

    Widget row(AvoChoiceOption o) {
      final chosen = o.id == widget.selectedId;
      final active = !answered && !widget.stale && widget.enabled;
      final sub = widget.stale
          ? context.tr('avo_choice_unanswered')
          : o.subtitle;
      Widget content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: _rowPadV,
          ),
          child: Row(
            children: [
              if (o.leading != null && !ax) ...[
                SizedBox.square(dimension: _leading, child: o.leading),
                const SizedBox(width: _gap),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      o.title,
                      style: context.text(
                        AvoTextStyle.body,
                        color: answered && !chosen
                            ? colors.secondaryLabel
                            : colors.label,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty)
                      Text(
                        sub,
                        style: context.text(
                          AvoTextStyle.subhead,
                          color: colors.secondaryLabel,
                          tabular: true,
                        ),
                      ),
                  ],
                ),
              ),
              if (chosen) ...[
                const SizedBox(width: _gap),
                AvoIcon(AvoIcons.check, size: _check, color: colors.tint),
              ],
            ],
          ),
        ),
      );
      if (!active && !chosen) {
        content = Opacity(opacity: _dimmed, child: content);
      }
      return Semantics(
        container: true,
        button: true,
        selected: chosen,
        enabled: active,
        label: [o.title, if (sub != null && sub.isNotEmpty) sub].join(', '),
        onTap: active ? () => widget.onSelect(o.id) : null,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: active ? () => widget.onSelect(o.id) : null,
          child: content,
        ),
      );
    }

    final rows = <Widget>[
      for (final o in shown) row(o),
      if (collapsible && !_all && !answered)
        Semantics(
          container: true,
          button: true,
          label: context.tr('avo_choice_show_all'),
          onTap: () => setState(() => _all = true),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _all = true),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AvoSpacing.l,
                  vertical: AvoSpacing.s,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.tr('avo_choice_show_all'),
                    style: context.text(AvoTextStyle.body, color: colors.tint),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];

    final indent = ax ? AvoSpacing.l : AvoSpacing.l + _leading + _gap;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: avoTrCount(context, 'avo_choice_label', options.length),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AvoRadii.group),
        child: ColoredBox(
          color: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) AvoHairline(indent: indent),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A fixed question or sentence in Avo's voice above a card ("Was soll ich
/// mit dem Foto machen?"), body text with "Avo:" for VoiceOver.
class AvoQuestionText extends StatelessWidget {
  const AvoQuestionText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${context.tr('avo_a11y_prefix')} $text',
    excludeSemantics: true,
    child: Text(text, style: context.text(AvoTextStyle.body)),
  );
}
