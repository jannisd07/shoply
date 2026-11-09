import 'package:flutter/widgets.dart';
import 'package:flutter/physics.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 X-Einkaufsmodus savings card: radius 20, padding 12 × 14, tag 20.
const double _kPadV = AvoSpacing.m; // D2 12
const double _kPadH = 14; // D2
const double _kIcon = 20; // D2
const double _kGap = AvoSpacing.m - AvoSpacing.xxs; // D2 10

/// "Ca. 3,20 € durch Angebote gespart, laut Händler" (verlauf-kosten.md
/// 2.3). Renders nothing for null [cents]: the caller passes the value of a
/// provider that is already null with offers off, no real region, the
/// switch off or below 0,50 €. Appears and disappears on a spring
/// (Reduce Motion: a short fade).
class SavingsLine extends StatelessWidget {
  const SavingsLine({super.key, required this.cents});

  /// Rounded savings ([roundedSavingsCents]); null shows nothing.
  final int? cents;

  @override
  Widget build(BuildContext context) {
    final value = cents;
    return SpringCollapse(
      visible: value != null,
      child: value == null ? const SizedBox.shrink() : _card(context, value),
    );
  }

  Widget _card(BuildContext context, int value) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final text = context.tr(
      'hist_savings_sentence',
      params: {'amount': formatEuroCents(value, lang)},
    );
    final spoken = context.tr(
      'hist_savings_sentence',
      params: {'amount': spokenEuroCents(value, lang)},
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Semantics(
        container: true,
        label: lang == 'de'
            ? spoken.replaceFirst('Ca.', 'Circa')
            : spoken,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AvoRadii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kPadH,
              vertical: _kPadV,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvoIcon(AvoIcons.tag, size: _kIcon, color: colors.tint),
                const SizedBox(width: _kGap),
                Expanded(
                  child: Text(text, style: context.text(AvoTextStyle.subhead)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grows [child] in and shrinks it away on [AvoMotion.standard], from the
/// current height (interruptible); with Reduce Motion a short fade.
class SpringCollapse extends StatefulWidget {
  const SpringCollapse({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<SpringCollapse> createState() => _SpringCollapseState();
}

class _SpringCollapseState extends State<SpringCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  Widget? _last;

  @override
  void didUpdateWidget(covariant SpringCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) _last = widget.child;
    if (oldWidget.visible == widget.visible) return;
    final target = widget.visible ? 1.0 : 0.0;
    if (context.reduceMotion) {
      _controller.animateTo(
        target,
        duration: AvoMotion.fadeReduced,
        curve: Curves.easeInOut,
      );
    } else {
      _controller.animateWith(
        SpringSimulation(
          AvoMotion.standard,
          _controller.value,
          target,
          _controller.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visible) _last = widget.child;
    final child = _last;
    if (child == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value.clamp(0.0, 1.0);
        if (t == 0 && !widget.visible) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: context.reduceMotion ? 1 : t,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
    );
  }
}
