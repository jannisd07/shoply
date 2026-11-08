import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

const double _kFigure = 96; // D2 empty states

/// S1a "Tagebuch ohne Ziel": Avo waves, says what the goal is for and offers
/// "Ziel einrichten", "Ohne Ziel eintragen" and "Kalorien ausschalten".
/// Shown only when there really is no goal (never on a network error).
class CalorieNoGoalState extends ConsumerStatefulWidget {
  const CalorieNoGoalState({super.key, required this.onTurnedOff});

  /// Leaves the diary (back to Home); the module goes off once it is gone.
  final VoidCallback onTurnedOff;

  @override
  ConsumerState<CalorieNoGoalState> createState() => _CalorieNoGoalStateState();
}

class _CalorieNoGoalStateState extends ConsumerState<CalorieNoGoalState> {
  /// Set by "Kalorien ausschalten": switch off when this screen is gone.
  VoidCallback? _switchOffWhenGone;

  void _turnOff() {
    final modules = ref.read(appModulesProvider.notifier);
    final host = Navigator.of(context, rootNavigator: true).context;
    final message = context.tr('cal_turned_off');
    final undo = context.tr('common_undo');
    // The module guard of this route would ask to switch it back on while
    // the route is still on screen: leave first, switch off once the route
    // has been removed (after its pop animation).
    _switchOffWhenGone = () {
      if (!modules.mounted) return;
      modules.setEnabled(AppModule.calories, false);
      if (!host.mounted) return;
      AvoToast.show(
        host,
        message: message,
        actionLabel: undo,
        onAction: () => modules.setEnabled(AppModule.calories, true),
      );
    };
    widget.onTurnedOff();
  }

  @override
  void dispose() {
    final off = _switchOffWhenGone;
    if (off != null) Future<void>(off);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ax = context.isAccessibilityText;
    return InsetSection(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.xl, vertical: AvoSpacing.xxl),
          child: Column(
            crossAxisAlignment: ax ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!ax) ...[
                const AvoFigure(pose: AvoPose.waving, size: _kFigure),
                const SizedBox(height: AvoSpacing.l),
              ],
              Semantics(
                header: true,
                child: Text(
                  context.tr('cal_empty_goal_title'),
                  textAlign: ax ? TextAlign.start : TextAlign.center,
                  style: context.text(AvoTextStyle.title3),
                ),
              ),
              const SizedBox(height: AvoSpacing.s),
              Text(
                context.tr('cal_empty_goal_body'),
                textAlign: ax ? TextAlign.start : TextAlign.center,
                style: context.text(AvoTextStyle.body),
              ),
              const SizedBox(height: AvoSpacing.xl),
              AppButton.primary(
                label: context.tr('cal_set_goal'),
                expand: ax,
                onPressed: () => context.push('${RoutePaths.calories}/goals/setup?from=empty'),
              ),
              const SizedBox(height: AvoSpacing.s),
              AppButton.plain(
                label: context.tr('cal_log_without_goal'),
                expand: ax,
                onPressed: () => ref.read(calorieWithoutGoalProvider.notifier).choose(),
              ),
              AppButton.plain(
                label: context.tr('cal_turn_off'),
                expand: ax,
                onPressed: _turnOff,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
