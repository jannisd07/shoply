import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// A's filter chip (D2-Komponenten "Filter-Chips"): 34 visible in a 44 hit
// height, capsule, 15 pt medium; the store chips add a leading StoreMark 18
// (request A-C2: a `leading` slot on AppFilterChip).
const double _kChipHeight = 34; // D2
const double _kPadStart = 8; // D2 with a leading tile (padding 0 12 0 8)
const double _kPadEnd = 14; // D2
const double _kMarkGap = 6; // D2
const double _kCheck = 14; // D2 check before a selected multi-choice chip

/// A market as a filter chip (`angebote.md` 2.3): [StoreMark] 18, the name
/// and optionally "· 400 m" in `secondaryLabel` (only inside white groups,
/// 3.8). Selected chips are dark with light text; in [multiple] mode they
/// also lead with a check mark (S14), single choice (S10) has none.
///
/// The whole chip is one VoiceOver button with a selected state: "Lidl,
/// 400 Meter entfernt, ausgewählt" ([semanticLabel]). Grows with Dynamic
/// Type, never cuts its text. No haptic.
class StoreFilterChip extends StatelessWidget {
  const StoreFilterChip({
    super.key,
    required this.chainId,
    required this.label,
    required this.selected,
    required this.onTap,
    this.distance,
    this.semanticLabel,
    this.multiple = false,
  });

  final String chainId;

  /// The market's name ("Lidl").
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// "400 m"; shown after the name.
  final String? distance;

  /// Spoken instead of the label ("Lidl, 400 Meter entfernt").
  final String? semanticLabel;

  /// A multiple-choice chip: a check mark while selected.
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = context.typography.lineHeightOf(AvoTextStyle.subhead);
    final vertical = ((_kChipHeight - line) / 2).clamp(0.0, _kChipHeight);
    final ink = selected ? colors.onChipSelected : colors.label;
    final away = distance;
    final textStyle = context.text(
      AvoTextStyle.subhead,
      weight: FontWeight.w500,
      color: ink,
    );

    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: selected ? colors.chipSelected : colors.fill,
        shape: const StadiumBorder(),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: _kChipHeight,
          minWidth: _kChipHeight,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            _kPadStart,
            vertical,
            _kPadEnd,
            vertical,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (multiple && selected) ...[
                AvoIcon(
                  AvoIcons.check,
                  size: MediaQuery.textScalerOf(context).scale(_kCheck),
                  color: ink,
                ),
                const SizedBox(width: _kMarkGap),
              ],
              StoreMark.chain(chainId),
              const SizedBox(width: _kMarkGap),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    children: [
                      if (away != null)
                        TextSpan(
                          text: ' · $away',
                          style: context.text(
                            AvoTextStyle.caption1,
                            color: selected
                                ? colors.onChipSelected
                                : colors.secondaryLabel,
                          ),
                        ),
                    ],
                  ),
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AvoSizes.hitTarget,
            minWidth: AvoSizes.hitTarget,
          ),
          child: Align(widthFactor: 1, heightFactor: 1, child: chip),
        ),
      ),
    );
  }
}
