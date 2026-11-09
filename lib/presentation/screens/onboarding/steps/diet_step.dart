import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/auth/name_save.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/steps/step_common.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';

/// "Ernährung und Allergien" (Konzept 17 §3.9, §9.7): diet chips and the 20
/// allergies of `AllergyType` (five behind "Weitere anzeigen"), always in a
/// `Wrap` so no allergy hides behind the edge. Nothing chosen is valid and
/// means "no restrictions".
class DietStep extends ConsumerStatefulWidget {
  const DietStep({
    super.key,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.progress,
  });

  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  ConsumerState<DietStep> createState() => _DietStepState();
}

class _DietStepState extends ConsumerState<DietStep> {
  late bool _more = ref
      .read(onboardingControllerProvider)
      .allergies
      .any((a) => kOnboardingMoreAllergies.any((t) => t.name == a));

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final allergies = [
      ...kOnboardingAllergies,
      if (_more) ...kOnboardingMoreAllergies,
    ];

    void toggleDiet(String id, bool on) => controller.setDiet(
      diet: on ? {...draft.diet, id} : ({...draft.diet}..remove(id)),
    );
    void toggleAllergy(AllergyType t, bool on) => controller.setDiet(
      allergies: on
          ? {...draft.allergies, t.name}
          : ({...draft.allergies}..remove(t.name)),
    );

    return OnboardingStepPage(
      title: context.tr('onb_food_title'),
      message: context.tr('onb_food_sentence'),
      progress: widget.progress,
      onBack: widget.onBack,
      onSkip: () => runIfCurrent(context, widget.onSkip),
      // The step after Name shows whether the name went through (§3.8).
      status: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [NameSaveStatus(), OnboardingSyncStatus()],
      ),
      primaryAction: AppButton.primary(
        label: context.tr('next'),
        onPressed: () => runIfCurrent(context, widget.onNext),
        size: AppButtonSize.large,
        expand: true,
      ),
      children: [
        _Heading(context.tr('onb_food_diet_heading')),
        _ChipWrap(
          chips: [
            for (final id in kOnboardingDietIds)
              AppFilterChip(
                label: context.tr('diet_$id'),
                selected: draft.diet.contains(id),
                onSelected: (on) => toggleDiet(id, on),
              ),
          ],
        ),
        const SizedBox(height: AvoSpacing.xxl),
        _Heading(context.tr('onb_food_allergy_heading')),
        _ChipWrap(
          chips: [
            for (final t in allergies)
              AppFilterChip(
                label: context.tr('onb_allergy_${t.name}'),
                selected: draft.allergies.contains(t.name),
                onSelected: (on) => toggleAllergy(t, on),
              ),
          ],
        ),
        if (!_more)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.plain(
              label: context.tr('onb_food_more'),
              onPressed: () => setState(() => _more = true),
            ),
          ),
        const SizedBox(height: AvoSpacing.s),
        Text(
          context.tr('onb_food_footnote'),
          style: context.text(
            AvoTextStyle.footnote,
            color: context.colors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AvoSpacing.xs),
    child: Semantics(
      header: true,
      child: Text(text, style: context.text(AvoTextStyle.headline)),
    ),
  );
}

/// Chips wrap as a whole into the next line, never scroll sideways.
class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AvoSpacing.s, children: chips);
}
