import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

/// How long a logged row says "Eingetragen" (D2 X-Essen / S3: 2 s).
const Duration _kLoggedShown = Duration(seconds: 2); // D2
const double _kRowMin = 60; // D2
const double _kPlusGlyph = 22; // D2 plus.circle
const double _kRowVertical = 9; // D2 (60 - 22 - 20) / 2

/// A "Zuletzt gegessen" row (S3): name, "60 g · 220 kcal" and a green plus.
/// A tap on the plus runs [onLog]; when it succeeds the plus springs into a
/// check and the second line says "Eingetragen" for two seconds. A tap on
/// the text opens S7 with this amount ([onOtherAmount]). Long press (and
/// VoiceOver actions): "Andere Menge …", "Aus „Zuletzt“ entfernen". For
/// VoiceOver the row is one element whose double-tap logs.
class RecentFoodRow extends StatefulWidget {
  const RecentFoodRow({
    super.key,
    required this.food,
    required this.onLog,
    required this.onRemove,
    this.onOtherAmount,
  });

  final RecentFood food;

  /// Opens S7 with this food and amount; null logs on a tap of the text too.
  final VoidCallback? onOtherAmount;

  /// Logs the food; true when it was queued.
  final Future<bool> Function() onLog;
  final VoidCallback onRemove;

  @override
  State<RecentFoodRow> createState() => _RecentFoodRowState();
}

class _RecentFoodRowState extends State<RecentFoodRow> {
  bool _logged = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _log() async {
    if (!await widget.onLog() || !mounted) return;
    setState(() => _logged = true);
    _timer?.cancel();
    _timer = Timer(_kLoggedShown, () {
      if (mounted) setState(() => _logged = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final e = widget.food.template;
    final kcal = context.tr('cal_meal_sum', params: {'kcal': context.kcal(e.calories)});
    final amount = context.entryAmount(e);
    final subtitle = _logged ? context.tr('cal_logged') : [?amount, kcal].join(' · ');
    final spoken = [
      e.foodName,
      ?amount,
      context.tr('cal_kcal_value', params: {'kcal': context.kcal(e.calories)}),
    ].join(', ');

    return Semantics(
      container: true,
      button: true,
      label: spoken,
      hint: context.tr('cal_log_item_a11y', params: {'name': e.foodName}),
      onTap: _log,
      customSemanticsActions: {
        if (widget.onOtherAmount case final other?)
          CustomSemanticsAction(label: context.tr('cal_other_amount_a11y')): other,
        CustomSemanticsAction(label: context.tr('cal_remove_recent')): widget.onRemove,
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOtherAmount ?? _log,
        onLongPress: () => showAvoMenu(context, items: [
          if (widget.onOtherAmount case final other?)
            AvoMenuItem(label: context.tr('cal_other_amount'), onSelected: other),
          AvoMenuItem(
            label: context.tr('cal_remove_recent'),
            icon: AvoIcons.trash,
            destructive: true,
            onSelected: widget.onRemove,
          ),
        ]),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMin),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(AvoSpacing.l, _kRowVertical, AvoSpacing.xs, _kRowVertical),
            child: Row(
              crossAxisAlignment: context.isAccessibilityText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.foodName, style: context.text(AvoTextStyle.body)),
                      Text(subtitle, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                    ],
                  ),
                ),
                GestureDetector(
                  key: ValueKey('cal-recent-log-${widget.food.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _log,
                  child: SizedBox.square(
                    dimension: AvoSizes.hitTarget,
                    child: Center(child: _LogGlyph(logged: _logged)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `plus.circle` that springs into `checkmark.circle.fill` (springQuick;
/// Reduce Motion: plain swap).
class _LogGlyph extends StatefulWidget {
  const _LogGlyph({required this.logged});

  final bool logged;

  @override
  State<_LogGlyph> createState() => _LogGlyphState();
}

class _LogGlyphState extends State<_LogGlyph> with SingleTickerProviderStateMixin {
  static const double _from = 0.6; // grows out of the plus
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didUpdateWidget(_LogGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logged == widget.logged || context.reduceMotion) return;
    _scale.value = _from;
    _scale.animateWith(SpringSimulation(AvoMotion.quick, _from, 1, 0));
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.tint;
    return ScaleTransition(
      scale: _scale,
      child: AvoIcon(
        widget.logged ? AvoIcons.checkmarkCircleFill : AvoIcons.plusCircle,
        size: _kPlusGlyph,
        color: tint,
      ),
    );
  }
}
