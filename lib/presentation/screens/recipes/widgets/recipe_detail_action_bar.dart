import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';

/// Labels in floating glass capsules grow up to xxxL, then stay (Konzept 13
/// §2.7, E-19): body 23 pt / 17 pt.
const double _maxTextScale = 23 / 17;

/// Gap between the two capsules (D2 toolbar gap).
const double _gap = AvoSpacing.s;

// D2 button metrics, to decide what fits: icon 18, gap 6, padding 14 / 18.
const double _buttonChrome = 18 + 6 + 14 + 18; // D2

/// The floating action bar of the detail (Konzept 13 §12.1 Nr. 13): the
/// tinted capsule "Zutaten auf die Liste" (the one main action) and the
/// glass capsule "Kochen". Where both do not fit (320 pt, large text)
/// "Kochen" becomes a 44 pt glass circle, then the main label shortens to
/// "Auf die Liste"; VoiceOver keeps the full names. Labels stop growing at
/// xxxL so the bar stays one line. With cooking progress "Kochen" reads
/// "Weiter: Schritt 3" (Konzept 13 §19.2).
class RecipeDetailActionBar extends StatelessWidget {
  const RecipeDetailActionBar({
    super.key,
    required this.onToList,
    required this.onCook,
    this.resumeStep,
  });

  final VoidCallback? onToList;
  final VoidCallback? onCook;

  /// The step cooking stopped at; null starts from the beginning.
  final int? resumeStep;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final full = context.tr('recipe_detail_to_list');
    final short = context.tr('recipe_detail_to_list_short');
    final step = resumeStep;
    final cook = step == null
        ? context.tr('recipe_detail_cook')
        : context.tr('recipe_detail_cook_continue', params: {'n': '$step'});
    final style = context.text(AvoTextStyle.subhead, weight: FontWeight.w600);
    final scale =
        context.typography.sizeOf(AvoTextStyle.subhead) /
        AvoTypography.forFactor(1).sizeOf(AvoTextStyle.subhead);
    double width(String text) =>
        _measure(context, text, style) + _buttonChrome * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final fullWidth = width(full);
        final cookWidth = width(cook);
        // "Weiter: Schritt 3" says more than the long main label: with
        // progress the main label shortens first, otherwise "Kochen"
        // becomes the circle first (Konzept 13 §12.5).
        final String label;
        final bool cookText;
        if (fullWidth + _gap + cookWidth <= available) {
          label = full;
          cookText = true;
        } else if (step != null &&
            width(short) + _gap + cookWidth <= available) {
          label = short;
          cookText = true;
        } else {
          label = fullWidth + _gap + AvoSizes.toolbarButton <= available
              ? full
              : short;
          cookText = false;
        }

        Widget toList = AppButton.primary(
          label: label,
          icon: const AvoIcon(AvoIcons.cart),
          floating: true,
          expand: true,
          onPressed: onToList,
        );
        if (label != full) {
          // VoiceOver keeps the full name of the short label.
          toList = Semantics(
            container: true,
            button: true,
            label: full,
            onTap: onToList,
            excludeSemantics: true,
            child: toList,
          );
        }
        final cookButton = cookText
            ? AppButton.secondary(
                label: cook,
                icon: const AvoIcon(AvoIcons.flame),
                floating: true,
                onPressed: onCook,
              )
            : GlassIconButton(
                icon: const AvoIcon(AvoIcons.flame),
                semanticLabel: step == null
                    ? context.tr('recipe_detail_cook_start')
                    : cook,
                onPressed: onCook,
              );
        return Row(
          children: [
            Expanded(child: toList),
            const SizedBox(width: _gap),
            cookButton,
          ],
        );
      },
    );
  }

  static double _measure(BuildContext context, String text, TextStyle style) {
    final effective = MediaQuery.boldTextOf(context)
        ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
        : style;
    final painter = TextPainter(
      text: TextSpan(text: text, style: effective),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }
}
