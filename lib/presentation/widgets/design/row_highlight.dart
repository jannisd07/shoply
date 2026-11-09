import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';

/// Which settings row a page should highlight once (Konzept 18 §3.5, E18-14):
/// the `row` query parameter of `/settings/<page>?row=<id>`.
class RowHighlightScope extends InheritedWidget {
  const RowHighlightScope({
    super.key,
    required this.rowId,
    required super.child,
  });

  final String? rowId;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RowHighlightScope>()?.rowId;

  @override
  bool updateShouldNotify(RowHighlightScope oldWidget) =>
      oldWidget.rowId != rowId;
}

/// Wraps one row. When its [id] is the scope's row, it scrolls into view and
/// shows the pressed fill (`fill`) that fades out after 1 s.
class HighlightableRow extends StatefulWidget {
  const HighlightableRow({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<HighlightableRow> createState() => _HighlightableRowState();
}

class _HighlightableRowState extends State<HighlightableRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AvoMotion.fadeReduced,
    value: 0,
  );
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done || RowHighlightScope.of(context) != widget.id) return;
    _done = true;
    _fade.value = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: context.reduceMotion ? Duration.zero : AvoMotion.fadeReduced,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) await _fade.reverse();
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.fill;
    return AnimatedBuilder(
      animation: _fade,
      child: widget.child,
      builder: (context, child) => _fade.value == 0
          ? child!
          : DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: color.a * _fade.value),
              ),
              child: child,
            ),
    );
  }
}
