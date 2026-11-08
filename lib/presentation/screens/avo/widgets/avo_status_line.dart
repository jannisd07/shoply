import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

// D2 X-Avo "arbeitet": three 5 pt dots, an opacity wave of 1.2 s, the only
// endless animation of the area (Kap. 12.3).
const double _dotSize = 5; // D2
const double _dotGap = 4; // D2
const Duration _waveDuration = Duration(milliseconds: 1200); // D2
const double _dotMinOpacity = 0.3; // D2
const double _lineMinHeight = AvoSizes.hitTarget; // Kap. 2.4: 44 pt reserved

/// Avo's quiet activity sign: three dots with an opacity wave. Under Reduce
/// Motion three still dots. Decorative.
class AvoActivityDots extends StatefulWidget {
  const AvoActivityDots({super.key});

  @override
  State<AvoActivityDots> createState() => _AvoActivityDotsState();
}

class _AvoActivityDotsState extends State<AvoActivityDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: _waveDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.secondaryLabel;
    final still = context.reduceMotion;
    Widget dot(int i) => AnimatedBuilder(
      animation: _wave,
      builder: (context, _) {
        var opacity = 1.0;
        if (!still) {
          final t = (_wave.value - i * 0.2) % 1.0;
          final rise = t < 0.5 ? t * 2 : (1 - t) * 2;
          opacity = _dotMinOpacity + (1 - _dotMinOpacity) * rise;
        }
        return Opacity(
          opacity: opacity,
          child: SizedBox.square(
            dimension: _dotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot(0),
            const SizedBox(width: _dotGap),
            dot(1),
            const SizedBox(width: _dotGap),
            dot(2),
          ],
        ),
      ),
    );
  }
}

/// The line that holds the place of Avo's answer while it works (Kap. 2.4):
/// the dots, what is happening ("Schreibt auf Wocheneinkauf") and "Stopp".
///
/// At least 44 pt high, so the first card or word replaces it without a
/// jump. The text wraps at large sizes; "Stopp" moves under it from AX1.
class AvoStatusLine extends StatelessWidget {
  const AvoStatusLine({super.key, required this.step, required this.onStop});

  final AvoWorkStep step;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      context.tr(step.key, params: step.params),
      style: context.text(
        AvoTextStyle.subhead,
        color: context.colors.secondaryLabel,
      ),
    );
    final stop = AppButton.plain(
      label: context.tr('avo_stop'),
      onPressed: onStop,
    );
    final head = Row(
      children: [
        const AvoActivityDots(),
        const SizedBox(width: AvoSpacing.m),
        Expanded(child: text),
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _lineMinHeight),
      child: context.isAccessibilityText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [head, stop],
            )
          : Row(
              children: [
                Expanded(child: head),
                const SizedBox(width: AvoSpacing.s),
                stop,
              ],
            ),
    );
  }
}
