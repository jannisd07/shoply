import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/chip_section.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Ernährung & Allergien (`/settings/diet`, alias `/diet-preferences`,
/// Konzept 18 §5.2, K18-05): allergies first (safety), then diet, both as
/// the onboarding's chips (`kOnboardingAllergies`, `kOnboardingDietIds`,
/// five allergies behind "Weitere anzeigen"), then "Rezepte automatisch
/// anpassen". Every chip acts at once and is written through
/// `mergeDietAndAllergies` (both columns); allergies Avo saved as free text
/// show as chips too and are never dropped.
class DietSettingsScreen extends ConsumerStatefulWidget {
  const DietSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  ConsumerState<DietSettingsScreen> createState() => _DietSettingsScreenState();
}

class _DietSettingsScreenState extends ConsumerState<DietSettingsScreen> {
  bool _more = false;

  void _removeOther(String text) {
    final notifier = ref.read(dietSettingsProvider.notifier);
    notifier.removeOtherAllergy(text);
    AvoToast.show(
      context,
      message: context.tr('setp_diet_removed', params: {'name': text}),
      actionLabel: context.tr('common_undo'),
      onAction: () => notifier.restoreOtherAllergy(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diet = ref.watch(dietSettingsProvider);
    final notifier = ref.read(dietSettingsProvider.notifier);
    final autoAdapt = ref.watch(recipeAutoAdaptProvider);
    final moreChosen = kOnboardingMoreAllergies.any(
      (t) => diet.allergies.contains(t.name),
    );
    final showMore = _more || moreChosen;
    final allergies = <AllergyType>[
      ...kOnboardingAllergies,
      if (showMore) ...kOnboardingMoreAllergies,
    ];

    return SettingsPage(
      title: context.tr('setp_diet_title'),
      intro: context.tr('setp_diet_intro'),
      highlightRowId: widget.highlightRowId,
      children: [
        ChipSection(
          header: context.tr('setp_diet_allergies'),
          footer: context.tr('setp_diet_allergies_footer'),
          highlightId: 'diet.allergies',
          moreLabel: context.tr('onb_food_more'),
          onMore: showMore ? null : () => setState(() => _more = true),
          chips: [
            for (final t in allergies)
              AppFilterChip(
                label: context.tr('onb_allergy_${t.name}'),
                selected: diet.allergies.contains(t.name),
                onSelected: (on) => notifier.setAllergy(t.name, on),
              ),
            for (final other in diet.otherAllergies)
              AppFilterChip(
                label: other,
                selected: true,
                onSelected: (_) => _removeOther(other),
              ),
          ],
        ),
        ChipSection(
          header: context.tr('setp_diet_diet'),
          footer: context.tr('setp_diet_diet_footer'),
          highlightId: 'diet.diet',
          chips: [
            for (final id in kOnboardingDietIds)
              AppFilterChip(
                label: context.tr('diet_$id'),
                selected: diet.diet.contains(id),
                onSelected: (on) => notifier.setDiet(id, on),
              ),
          ],
        ),
        const SizedBox(height: kSettingsSectionGap),
        InsetSection(
          children: [
            HighlightableRow(
              id: 'diet.auto_adapt',
              child: ToggleRow(
                title: context.tr('setp_diet_auto'),
                subtitle: context.tr('setp_diet_auto_sub'),
                value: autoAdapt,
                onChanged: ref.read(recipeAutoAdaptProvider.notifier).set,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
