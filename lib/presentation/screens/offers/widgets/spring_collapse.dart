import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// Shows [child] while [visible] and folds it away on [AvoMotion.standard]
/// (height and opacity together) when it goes, unfolds it when it comes
/// back (`angebote.md` 3.5: "Sektion klappt zusammen"). Interruptible: a
/// change mid-way continues from where it is. Under Reduce Motion it does
/// not move: it is there or gone. A hidden child is not built.
class SpringCollapse extends StatefulWidget {
  const SpringCollapse({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<SpringCollapse> createState() => _SpringCollapseState();
}

class _SpringCollapseState extends State<SpringCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController.unbounded(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );

  @override
  void didUpdateWidget(SpringCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    final target = widget.visible ? 1.0 : 0.0;
    if (context.reduceMotion) {
      _t.value = target;
      return;
    }
    _t.animateWith(
      SpringSimulation(
        AvoMotion.standard,
        _t.value,
        target,
        _t.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) {
      final t = _t.value.clamp(0.0, 1.0);
      if (t == 0) return const SizedBox.shrink();
      if (t == 1) return child!;
      return ClipRect(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: t,
          child: Opacity(opacity: t, child: child),
        ),
      );
    },
    child: widget.child,
  );
}
