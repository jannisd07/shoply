import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_price_tag.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

// D2 offer rows (Konzept E-03, `angebote.md` 2.3).
const double _kMinHeightCompact = 52; // D2 one line
const double _kMinHeightFull = 60; // D2 with a second line
const double _kVertical = 8; // D2
const double _kTile = 28; // D2 category symbol in rows
const double _kTileRadius = 8; // D2
const double _kTileGlyph = 16; // D2 symbol inside the 28-pt tile
const double _kGap = AvoSpacing.m; // D2 gap 12
const double _kPlusGlyph = 22; // D2 plus.circle in rows

/// Where a row's text starts with the category symbol (for the group's
/// hairlines): 16 inset + 28 tile + 12 gap.
const double offerRowTextIndent = AvoSpacing.l + _kTile + _kGap;

/// One offer as a row (Konzept E-03): category symbol, product, one to three
/// lines below, the [OfferPriceTag] at the end.
///
/// [compact] is the add field's variant (S6, at least 52 pt); the full one
/// (S5 "Weitere Angebote") is at least 60 pt. Text is never cut: the name
/// wraps, the pill moves below the text when the name would get less than
/// half the width, and from AX1 on the symbol goes and the pill sits below
/// the text. The whole row is one VoiceOver button with [semanticLabel];
/// pressing highlights it at once.
///
/// [onAdd] adds a `plus.circle` (22 pt in a 44-pt target) at the end, its
/// own VoiceOver button named [addLabel]; from AX1 on it sits top right,
/// level with the first line. [actions] become VoiceOver actions of the row
/// (the swipe and context-menu actions of S10).
class OfferRow extends StatefulWidget {
  const OfferRow({
    super.key,
    required this.title,
    required this.price,
    required this.semanticLabel,
    this.lines = const [],
    this.store,
    this.uncertain = false,
    this.symbol,
    this.compact = false,
    this.semanticHint,
    this.onTap,
    this.onLongPress,
    this.longPressLabel,
    this.onAdd,
    this.addLabel,
    this.actions = const {},
  });

  /// Product name, 17/22.
  final String title;

  /// Up to three lines below, 15/20 `secondaryLabel`.
  final List<String> lines;

  /// Formatted offer price for the pill.
  final String price;

  /// Market in the pill (lists without a market).
  final String? store;

  /// A similar product: question mark in the pill.
  final bool uncertain;

  /// Category glyph in the 28-pt tile; null leaves the tile out.
  final IconData? symbol;

  final bool compact;

  /// The full sentence for VoiceOver.
  final String semanticLabel;

  /// What a double tap does ("Fügt Milch hinzu").
  final String? semanticHint;

  final VoidCallback? onTap;

  /// A second action (long press), also a VoiceOver action named
  /// [longPressLabel].
  final VoidCallback? onLongPress;
  final String? longPressLabel;

  /// The `plus.circle` at the end ("Auf die Liste", S9, S10); gets the
  /// button's context, so a menu can grow out of it.
  final ValueSetter<BuildContext>? onAdd;

  /// VoiceOver label of [onAdd] ("Haferflocken auf Wocheneinkauf setzen").
  final String? addLabel;

  /// More VoiceOver actions of the row, by label.
  final Map<String, VoidCallback> actions;

  @override
  State<OfferRow> createState() => _OfferRowState();
}

class _OfferRowState extends State<OfferRow> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down && mounted) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final symbol = widget.symbol;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: context.text(AvoTextStyle.body)),
        for (final line in widget.lines)
          Text(
            line,
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
      ],
    );
    final pill = OfferPriceTag(
      price: widget.price,
      store: widget.store,
      uncertain: widget.uncertain,
    );
    final body = AdaptiveTrailing(
      gap: _kGap,
      stacked: ax,
      trailing: pill,
      child: text,
    );
    final add = widget.onAdd;
    final main = Row(
      children: [
        if (symbol != null && !ax) ...[
          ExcludeSemantics(
            child: Container(
              width: _kTile,
              height: _kTile,
              decoration: BoxDecoration(
                color: colors.fill,
                borderRadius: BorderRadius.circular(_kTileRadius),
              ),
              child: Icon(
                symbol,
                size: _kTileGlyph,
                color: colors.secondaryLabel,
              ),
            ),
          ),
          const SizedBox(width: _kGap),
        ],
        Expanded(child: body),
      ],
    );
    final tap = widget.onTap;
    final longPress = widget.onLongPress;
    final longLabel = widget.longPressLabel;
    final customActions = <CustomSemanticsAction, VoidCallback>{
      if (longPress != null && longLabel != null)
        CustomSemanticsAction(label: longLabel): longPress,
      for (final e in widget.actions.entries)
        CustomSemanticsAction(label: e.key): e.value,
    };
    final element = Semantics(
      container: true,
      button: tap != null,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      onTap: tap,
      customSemanticsActions: customActions.isEmpty ? null : customActions,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: tap == null ? null : (_) => _press(true),
        onTapUp: tap == null ? null : (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: tap,
        onLongPress: longPress == null
            ? null
            : () {
                _press(false);
                longPress();
              },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: widget.compact ? _kMinHeightCompact : _kMinHeightFull,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AvoSpacing.l,
              _kVertical,
              add == null ? AvoSpacing.l : AvoSpacing.xs,
              _kVertical,
            ),
            child: main,
          ),
        ),
      ),
    );
    return ColoredBox(
      color: _pressed ? colors.fillStrong : colors.surface,
      child: add == null
          ? element
          : Row(
              crossAxisAlignment: ax
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Expanded(child: element),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: _kVertical,
                    end: AvoSpacing.xs,
                    bottom: _kVertical,
                  ),
                  child: Builder(
                    builder: (anchor) => PressableScale(
                      onPressed: () => add(anchor),
                      child: Semantics(
                        container: true,
                        button: true,
                        label: widget.addLabel,
                        onTap: () => add(anchor),
                        excludeSemantics: true,
                        child: SizedBox(
                          width: AvoSizes.hitTarget,
                          height: AvoSizes.hitTarget,
                          child: Center(
                            child: AvoIcon(
                              AvoIcons.plusCircle,
                              size: _kPlusGlyph,
                              color: colors.tint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
