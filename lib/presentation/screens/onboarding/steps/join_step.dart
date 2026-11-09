import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/steps/step_common.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// A joined list.
typedef JoinedList = ({String id, String name});

/// "Beitreten" as the last step when someone came through an invitation
/// (Konzept 17 §5.1), without "Überspringen". Without the public preview
/// (`invite_preview`, a server proposal) it names no list or inviter yet.
class JoinStep extends StatefulWidget {
  const JoinStep({
    super.key,
    required this.join,
    required this.onJoined,
    required this.onDecline,
    this.onBack,
    this.progress,
  });

  /// Joins with the remembered code; null when no list has it any more.
  /// Throws when the server cannot be reached.
  final Future<JoinedList?> Function() join;
  final ValueChanged<JoinedList> onJoined;

  /// "Nicht beitreten" or "Eigene Liste anlegen": the first list step.
  final VoidCallback onDecline;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  State<JoinStep> createState() => _JoinStepState();
}

class _JoinStepState extends State<JoinStep> {
  bool _working = false;
  bool _failed = false;
  bool _gone = false;

  Future<void> _join() async {
    if (_working) return;
    setState(() {
      _working = true;
      _failed = false;
    });
    try {
      final list = await widget.join();
      if (!mounted) return;
      if (list == null) {
        setState(() {
          _working = false;
          _gone = true;
        });
        return;
      }
      widget.onJoined(list);
    } catch (e) {
      debugPrint('⚠️ [Onboarding] Joining failed: $e');
      if (!mounted) return;
      AvoHaptics.error();
      setState(() {
        _working = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) {
      return OnboardingStepPage(
        title: context.tr('onb_join_title'),
        progress: widget.progress,
        onBack: widget.onBack,
        primaryAction: AppButton.primary(
          label: context.tr('onb_join_own_list'),
          onPressed: () => runIfCurrent(context, widget.onDecline),
          size: AppButtonSize.large,
          expand: true,
        ),
        children: [
          EmptyState(
            title: context.tr('onb_join_gone_title'),
            message: context.tr('onb_join_gone_message'),
          ),
        ],
      );
    }
    return OnboardingStepPage(
      title: context.tr('onb_join_title'),
      message: context.tr('onb_join_sentence'),
      progress: widget.progress,
      onBack: widget.onBack,
      status: _failed
          ? StatusRow(
              kind: StatusKind.failed,
              text: context.tr('onb_join_failed'),
              actionLabel: context.tr('retry'),
              onAction: _join,
            )
          : const OnboardingSyncStatus(),
      primaryAction: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.primary(
            label: context.tr('onb_join_action'),
            onPressed: () => runIfCurrent(context, _join),
            working: _working,
            size: AppButtonSize.large,
            expand: true,
          ),
          Center(
            child: AppButton.plain(
              label: context.tr('onb_join_decline'),
              onPressed: _working
                  ? null
                  : () => runIfCurrent(context, widget.onDecline),
            ),
          ),
        ],
      ),
    );
  }
}

/// `/join/<code>` for a signed-in person (Konzept 17 §5.1; Kap. 11 shows
/// the same layout as a push screen): "Beitreten" opens the list with
/// `?arrival=joined`, "Nicht beitreten" and the back button lead to the
/// lists tab.
class JoinLinkScreen extends ConsumerWidget {
  const JoinLinkScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void leave() {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(RoutePaths.lists);
      }
    }

    return JoinStep(
      onBack: leave,
      join: () async {
        if (code.isEmpty) return null;
        final list = await ref.read(listActionsProvider).joinWithCode(code);
        return list == null ? null : (id: list.id, name: list.name);
      },
      onJoined: (list) => GoRouter.of(context).go(
        RoutePaths.listArrival(
          list.id,
          OnboardingArrival.joined.id,
          name: list.name,
        ),
      ),
      onDecline: () => GoRouter.of(context).go(RoutePaths.lists),
    );
  }
}
