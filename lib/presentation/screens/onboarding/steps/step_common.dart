import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// The progress line "Schritt x von n" (Konzept 17 §9.2), or null.
Widget? onboardingProgressLine(
  BuildContext context,
  ({int step, int total})? progress,
) {
  if (progress == null) return null;
  return StepProgress(
    step: progress.step,
    total: progress.total,
    semanticLabel: context.tr(
      'onb_progress',
      params: {'step': '${progress.step}', 'total': '${progress.total}'},
    ),
  );
}

/// Runs [action] only while the step's route is the top one, so a double tap
/// during the push never opens the next step twice.
void runIfCurrent(BuildContext context, VoidCallback action) {
  final route = ModalRoute.of(context);
  if (route == null || route.isCurrent) action();
}

/// "Deine Angaben sind noch nicht gespeichert. Erneut versuchen" in the step
/// after a failed background write (Konzept 17 §1.2); pass it as
/// `OnboardingStepPage.status`. Nothing while all writes went through.
class OnboardingSyncStatus extends ConsumerWidget {
  const OnboardingSyncStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(
      onboardingControllerProvider.select((s) => s.syncFailed),
    );
    if (!failed) return const SizedBox.shrink();
    return StatusRow(
      kind: StatusKind.failed,
      text: context.tr('onb_sync_failed'),
      actionLabel: context.tr('retry'),
      onAction: () =>
          ref.read(onboardingControllerProvider.notifier).retrySync(),
    );
  }
}

/// A selection row with a check mark at the end (iOS settings pattern,
/// Konzept 17 §3.10). VoiceOver reads a button with a selected state.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: subtitle == null ? title : '$title, $subtitle',
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: AvoSpacing.m - AvoSpacing.xxs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.text(
                            AvoTextStyle.body,
                            color: enabled
                                ? colors.label
                                : colors.secondaryLabel,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: context.text(
                              AvoTextStyle.subhead,
                              color: colors.secondaryLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                  SizedBox.square(
                    dimension: 22,
                    child: selected
                        ? AvoIcon(AvoIcons.check, size: 20, color: colors.tint)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
