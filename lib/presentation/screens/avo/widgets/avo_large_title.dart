import 'package:flutter/widgets.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';

// D2 X-Avo head (Kap. 2.1): figure 44 × 44 (contain), 10 pt to "Avo" in
// LargeTitle 34/41 bold, left at 16 pt.
const double _figureSize = 44; // D2
const double _figureGap = 10; // D2

/// The large title of the Avo tab with the one Avo figure of the screen
/// (Kap. 2.1, 2.13). The pose follows what Avo does ([pose]) and changes as
/// a 200 ms cross-fade. From AX1 the figure goes, the title stays. The
/// figure is decorative; the title is a heading.
class AvoLargeTitle extends StatelessWidget {
  const AvoLargeTitle({super.key, required this.pose});

  final AvoPose pose;

  @override
  Widget build(BuildContext context) {
    final showFigure = !context.isAccessibilityText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Row(
        children: [
          if (showFigure) ...[
            AnimatedSwitcher(
              duration: AvoMotion.fadeReduced,
              child: AvoFigure(
                key: ValueKey(pose),
                pose: pose,
                size: _figureSize,
              ),
            ),
            const SizedBox(width: _figureGap),
          ],
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                AppBrand.name,
                style: context.text(AvoTextStyle.largeTitle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
