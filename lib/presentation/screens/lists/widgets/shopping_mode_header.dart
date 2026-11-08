import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

// D2 X-Einkaufsmodus header: chip line 8 below the title (gap 8), presence
// line 10 below it (gap 8), offer card 14 below the header.
const double _chipLineTop = AvoSpacing.s; // D2 margin-top 8
const double _chipGap = AvoSpacing.s; // D2 gap 8
const double _chipRunGap = AvoSpacing.xs;
const double _presenceTop = 10; // D2 margin-top 10
const double _presenceGap = AvoSpacing.s; // D2 gap 8
const double _summaryTop = 14; // D2 margin 14 16 0

/// Who else of [listId] is in the shopping mode right now, by display name
/// (Konzept 11 §1.5, L-01). There is no presence channel yet
/// (`list_presence_service.dart` is still to be built), so nobody is
/// reported; the service will feed this provider.
final shoppingCompanionsProvider = Provider.autoDispose
    .family<List<String>, String>((ref, listId) => const []);

/// The top of the shopping mode (D2 X-Einkaufsmodus): the list name as large
/// title, the market chip and "5 von 11 erledigt" with a rolling count,
/// the presence line and Teil B's offer summary card.
class ShoppingModeHeader extends StatelessWidget {
  /// Creates the header.
  const ShoppingModeHeader({
    super.key,
    required this.listId,
    required this.title,
    required this.done,
    required this.total,
    this.companions = const [],
  });

  /// The list whose market and offers are shown.
  final String listId;

  /// The list name.
  final String title;

  /// Checked items.
  final int done;

  /// All items of the list.
  final int total;

  /// Others shopping right now ([shoppingCompanionsProvider]).
  final List<String> companions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.text(AvoTextStyle.largeTitle),
                ),
              ),
              const SizedBox(height: _chipLineTop),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: _chipRunGap,
                children: [
                  ShoppingSlotPadding(
                    padding: const EdgeInsetsDirectional.only(end: _chipGap),
                    child: StoreChip(listId: listId),
                  ),
                  ShoppingProgressText(done: done, total: total),
                ],
              ),
              if (companions.isNotEmpty) ...[
                const SizedBox(height: _presenceTop),
                ShoppingPresenceLine(names: companions),
              ],
            ],
          ),
        ),
        ShoppingSlotPadding(
          padding: const EdgeInsets.only(top: _summaryTop),
          child: ListOfferSummary(listId: listId),
        ),
      ],
    );
  }
}

/// "5 von 11 erledigt" (15/20, secondary label): the done count rolls when
/// it changes. VoiceOver reads the whole sentence as a live region.
class ShoppingProgressText extends StatelessWidget {
  /// Creates the progress text.
  const ShoppingProgressText({
    super.key,
    required this.done,
    required this.total,
  });

  /// Checked items.
  final int done;

  /// All items.
  final int total;

  @override
  Widget build(BuildContext context) {
    final style = context.text(
      AvoTextStyle.subhead,
      color: context.colors.secondaryLabel,
      tabular: true,
    );
    final template = context.tr(
      'list_shop_progress',
      params: {'total': '$total'},
    );
    final spoken = template.replaceAll('{done}', '$done');
    final at = template.indexOf('{done}');
    final Widget visual;
    if (at < 0) {
      visual = Text(spoken, style: style);
    } else {
      visual = Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: template.substring(0, at)),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: RollingNumber(value: done, style: style),
            ),
            TextSpan(text: template.substring(at + '{done}'.length)),
          ],
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      label: spoken,
      child: ExcludeSemantics(child: visual),
    );
  }
}

/// "Lena kauft gerade mit ein" with Lena's avatar and the green presence
/// dot (D2 X-Einkaufsmodus). Two people are named, more are counted.
class ShoppingPresenceLine extends StatelessWidget {
  /// Creates the line for [names]; draws nothing without a name.
  const ShoppingPresenceLine({super.key, required this.names});

  /// Display names of the others shopping now.
  final List<String> names;

  /// The sentence for [names].
  static String sentence(BuildContext context, List<String> names) {
    final first = names.first.trim();
    return switch (names.length) {
      1 => context.tr('list_shop_presence_one', params: {'name': first}),
      2 => context.tr(
        'list_shop_presence_two',
        params: {'first': first, 'second': names[1].trim()},
      ),
      _ => context.tr(
        'list_shop_presence_more',
        params: {'first': first, 'count': '${names.length - 1}'},
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final text = sentence(context, names);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Avatar(
              name: names.first,
              presence: true,
              ringColor: context.colors.background,
            ),
            const SizedBox(width: _presenceGap),
            Expanded(
              child: Text(text, style: context.text(AvoTextStyle.subhead)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puts [padding] around [child] only when the child draws something: a
/// Teil B slot that renders `SizedBox.shrink()` (module off, no data)
/// leaves no gap.
class ShoppingSlotPadding extends SingleChildRenderObjectWidget {
  /// Creates the padding.
  const ShoppingSlotPadding({
    super.key,
    required this.padding,
    required super.child,
  });

  /// Space around a child that has a size.
  final EdgeInsetsGeometry padding;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSlotPadding(padding.resolve(Directionality.of(context)));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSlotPadding).padding = padding.resolve(
      Directionality.of(context),
    );
  }
}

class _RenderSlotPadding extends RenderShiftedBox {
  _RenderSlotPadding(this._padding) : super(null);

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  Size _layout(BoxConstraints constraints, ChildLayouter layoutChild) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final inner = constraints.deflate(_padding);
    final size = layoutChild(child, inner);
    if (size.isEmpty) return constraints.constrain(Size.zero);
    return constraints.constrain(
      Size(size.width + _padding.horizontal, size.height + _padding.vertical),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild);
    final child = this.child;
    if (child == null) return;
    final parentData = child.parentData! as BoxParentData;
    parentData.offset = child.size.isEmpty
        ? Offset.zero
        : Offset(_padding.left, _padding.top);
  }

  bool get _empty => child == null || child!.size.isEmpty;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsic((c) => c.getMinIntrinsicWidth(height), _padding.horizontal);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsic((c) => c.getMaxIntrinsicWidth(height), _padding.horizontal);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsic((c) => c.getMinIntrinsicHeight(width), _padding.vertical);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsic((c) => c.getMaxIntrinsicHeight(width), _padding.vertical);

  double _intrinsic(double Function(RenderBox child) of, double extra) {
    final child = this.child;
    if (child == null) return 0;
    final value = of(child);
    return value == 0 ? 0 : value + extra;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_empty) return;
    super.paint(context, offset);
  }
}
