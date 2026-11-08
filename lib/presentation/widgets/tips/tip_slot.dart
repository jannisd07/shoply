import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/widgets/tips/tip_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// The app-wide [TipService] (`app.dart` attaches it at start). Tests
/// override it with their own attached service.
final tipServiceProvider = Provider<TipService>((ref) => TipService.instance);

/// "Tipp: …" of [id].
String tipText(BuildContext context, TipId id) => switch (id) {
  TipId.quantity => context.tr('tip_t1'),
  TipId.shoppingMode => context.tr('tip_t2'),
  TipId.checkOff => context.tr('tip_t3'),
  TipId.share => context.tr('tip_t4'),
  TipId.joined => context.tr('tip_t5'),
  TipId.recipeToList => context.tr('tip_t6'),
  TipId.diet => context.tr('tip_t7'),
  TipId.voice => context.tr('tip_t8'),
  TipId.mealPlan => context.tr('tip_t9'),
};

/// The action of [id], only T7 has one ("Einstellen").
String? tipActionLabel(BuildContext context, TipId id) =>
    id == TipId.diet ? context.tr('tip_t7_action') : null;

/// The tip one screen shows during one visit (Konzept 00 §12.12: fixed at
/// the first frame, new tips only on the next visit).
///
/// [resolve] picks the tip at its first call whose facts are ready while the
/// screen is visible, and returns the same tip afterwards, also once it is
/// done (ask [TipService.isShowing] whether to draw it). When the screen
/// becomes visible again (its [TickerMode] turns back on: tab switched back,
/// a pushed screen closed) a new visit starts.
class TipVisit {
  TipVisit(this.place, {this.only});

  final TipPlace place;

  /// The tips this place can draw (null: all of the place).
  final Set<TipId>? only;

  bool _resolved = false;
  bool? _tickerOn;
  TipId? _picked;

  /// The tip picked for this visit, if any.
  TipId? get picked => _picked;

  /// Call in build. With [allowed] false the visit shows no tip (Home with
  /// two hint rows already, K-38).
  TipId? resolve(
    BuildContext context,
    TipService service,
    TipFacts facts, {
    bool allowed = true,
  }) {
    final on = TickerMode.valuesOf(context).enabled;
    if (_tickerOn == false && on) {
      _resolved = false;
      _picked = null;
    }
    _tickerOn = on;
    service.observe(place, facts);
    if (!_resolved && on && facts.ready) {
      _resolved = true;
      if (allowed && service.isAttached) {
        service.visit(place);
        _picked = service.pick(place, facts, only: only);
      }
    }
    return _picked;
  }
}

/// Wraps the bare row, e.g. in `InsetSection(header: "Für heute")`.
typedef TipWrap = Widget Function(BuildContext context, Widget row);

/// Draws the tip itself; [tip] is null when there is nothing to show.
typedef TipSlotBuilder =
    Widget Function(BuildContext context, TipId? tip, VoidCallback hide);

/// The place of one tip row (Konzept 17 §6.1): picks the visit's tip,
/// draws it as a [TipRow] (optionally wrapped) and collapses it with
/// `springStandard` once it is done or swiped away (Reduce Motion: fades).
/// Without a tip it takes no space.
class TipSlot extends ConsumerStatefulWidget {
  /// A slot that draws a [TipRow].
  const TipSlot({
    super.key,
    required this.place,
    required this.facts,
    this.visit,
    this.only,
    this.allowed = true,
    this.wrap,
    this.onAction,
  }) : builder = null;

  /// A slot that leaves the drawing to [builder] (no collapse animation).
  /// It may return a sliver.
  const TipSlot.builder({
    super.key,
    required this.place,
    required this.facts,
    required TipSlotBuilder this.builder,
    this.visit,
    this.only,
    this.allowed = true,
  }) : wrap = null,
       onAction = null;

  final TipPlace place;

  /// What the screen knows now; pass it on every build.
  final TipFacts facts;

  /// The host's visit, when the host must know about the tip before it
  /// builds the slot (Home); otherwise the slot keeps its own.
  final TipVisit? visit;

  /// See [TipVisit.only] (own visit only).
  final Set<TipId>? only;

  /// See [TipVisit.resolve] (own visit only).
  final bool allowed;

  final TipWrap? wrap;

  /// The action of a tip (T7 "Einstellen"); default opens the target.
  final void Function(BuildContext context, TipId tip)? onAction;

  final TipSlotBuilder? builder;

  @override
  ConsumerState<TipSlot> createState() => _TipSlotState();
}

class _TipSlotState extends ConsumerState<TipSlot>
    with SingleTickerProviderStateMixin {
  TipVisit? _own;
  TipService? _service;

  /// 1 = open, 0 = collapsed.
  late final AnimationController _open = AnimationController(
    vsync: this,
    value: 1,
  );

  /// The tip whose row is on screen; kept while it collapses.
  TipId? _shown;
  bool _collapsing = false;

  TipVisit get _visit =>
      widget.visit ?? (_own ??= TipVisit(widget.place, only: widget.only));

  @override
  void dispose() {
    _service?.removeListener(_onChanged);
    _open.dispose();
    super.dispose();
  }

  void _listen(TipService service) {
    if (identical(service, _service)) return;
    _service?.removeListener(_onChanged);
    _service = service..addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _collapse() {
    if (_collapsing) return;
    _collapsing = true;
    final tip = _shown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_collapsing || _shown != tip) return;
      final TickerFuture run;
      if (context.reduceMotion) {
        run = _open.animateTo(0, duration: AvoMotion.fadeReduced);
      } else {
        run = _open.animateWith(
          SpringSimulation(AvoMotion.standard, _open.value, 0, 0),
        );
      }
      run.whenCompleteOrCancel(() {
        // Cancelled because another tip opened: keep that one.
        if (!mounted || !_collapsing || _shown != tip) return;
        setState(() {
          _shown = null;
          _collapsing = false;
        });
      });
    });
  }

  void _act(TipId tip) {
    final custom = widget.onAction;
    if (custom != null) {
      custom(context, tip);
      return;
    }
    if (tip == TipId.diet) {
      GoRouter.maybeOf(context)?.push(RoutePaths.dietPreferences);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(tipServiceProvider);
    _listen(service);
    final facts = widget.facts;
    final tip = _visit.resolve(
      context,
      service,
      facts,
      allowed: widget.allowed,
    );
    final showing = tip != null && service.isShowing(tip, widget.place, facts);

    final builder = widget.builder;
    if (builder != null) {
      return builder(context, showing ? tip : null, () {
        if (tip != null) service.dismiss(tip);
      });
    }

    if (showing) {
      if (_shown != tip) {
        _shown = tip;
        _collapsing = false;
        _open.value = 1;
      }
    } else if (_shown != null) {
      _collapse();
    }

    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();

    final action = tipActionLabel(context, shown);
    final row = TipRow(
      key: ValueKey<TipId>(shown),
      text: tipText(context, shown),
      hideLabel: context.tr('tip_hide'),
      onHide: () => service.dismiss(shown),
      actionLabel: action,
      onAction: action == null ? null : () => _act(shown),
    );
    final wrapped = widget.wrap?.call(context, row) ?? row;
    return FadeTransition(
      opacity: _open,
      child: context.reduceMotion
          ? wrapped
          : SizeTransition(
              sizeFactor: _open,
              alignment: Alignment.topCenter,
              child: wrapped,
            ),
    );
  }
}
