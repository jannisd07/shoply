import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// A full swipe acts once the row moved this share of its width (as in the
/// list and the recipe library).
const double _kThreshold = 0.6;
const double _kIcon = 20; // D2 swipe glyph

/// One swipe action of an offer row.
@immutable
class OfferSwipeAction {
  const OfferSwipeAction({
    required this.label,
    required this.icon,
    required this.run,
    this.removes = false,
  });

  final String label;
  final AvoIconData icon;
  final VoidCallback run;

  /// The row leaves ("Nicht interessiert"); otherwise it springs back
  /// ("Auf die Liste").
  final bool removes;
}

/// Swipe on an offer row (S10, `angebote.md` 3.5): to the end for [start]
/// ("Auf die Liste", tinted), to the start for [end] ("Nicht interessiert",
/// grey). The row follows the finger 1:1; past 60 % it acts, with the light
/// haptic at the threshold. Under Reduce Motion there is no swipe: the
/// same actions are on the row's context menu and VoiceOver actions.
class OfferSwipe extends StatelessWidget {
  const OfferSwipe({
    super.key,
    required this.id,
    required this.child,
    this.start,
    this.end,
  });

  /// Stable id of the row.
  final String id;
  final Widget child;
  final OfferSwipeAction? start;
  final OfferSwipeAction? end;

  @override
  Widget build(BuildContext context) {
    final toEnd = start;
    final toStart = end;
    if (context.reduceMotion || (toEnd == null && toStart == null)) {
      return child;
    }
    final colors = context.colors;

    Widget background(OfferSwipeAction action, {required bool leading}) {
      final fill = leading
          ? colors.tintFill
          : Color.alphaBlend(colors.fillStrong, colors.surface);
      final ink = leading ? colors.onTint : colors.label;
      return ColoredBox(
        color: fill,
        child: Align(
          alignment: leading
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvoIcon(action.icon, size: _kIcon, color: ink),
                if (!context.isAccessibilityText) ...[
                  const SizedBox(width: AvoSpacing.s),
                  Text(
                    action.label,
                    maxLines: 1,
                    style: context.text(
                      AvoTextStyle.subhead,
                      weight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final direction = toEnd != null && toStart != null
        ? DismissDirection.horizontal
        : toEnd != null
        ? DismissDirection.startToEnd
        : DismissDirection.endToStart;
    // One direction only: Dismissible shows [background] for it.
    final primary = toEnd != null
        ? background(toEnd, leading: true)
        : background(toStart!, leading: false);
    return Dismissible(
      key: ValueKey<String>('offer-swipe-$id'),
      direction: direction,
      dismissThresholds: const {
        DismissDirection.startToEnd: _kThreshold,
        DismissDirection.endToStart: _kThreshold,
      },
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          unawaited(AvoHaptics.light());
        }
      },
      confirmDismiss: (dir) async {
        final action = dir == DismissDirection.startToEnd ? toEnd : toStart;
        if (action == null) return false;
        if (!action.removes) {
          action.run();
          return false;
        }
        return true;
      },
      onDismissed: (dir) {
        final action = dir == DismissDirection.startToEnd ? toEnd : toStart;
        action?.run();
      },
      background: primary,
      secondaryBackground: toEnd != null && toStart != null
          ? background(toStart, leading: false)
          : null,
      child: child,
    );
  }
}
