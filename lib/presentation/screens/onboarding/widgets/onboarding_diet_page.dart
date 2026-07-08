import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';

/// Same diet-preference ids used by the Profile → Diet preferences screen
/// (`diet_preferences_screen.dart`) — collecting them here just moves the
/// question earlier, it doesn't invent a second taxonomy.
const List<String> kOnboardingDietIds = [
  'vegetarian',
  'vegan',
  'gluten_free',
  'dairy_free',
  'pescatarian',
  'keto',
  'paleo',
  'low_carb',
  'halal',
  'kosher',
  'nut_free',
  'low_sodium',
];

/// Onboarding page: pick any diet preferences that apply. Feeds the exact
/// same `users.diet_preferences` field the rest of the app already reads
/// for recipe filtering and ingredient substitutions — none selected means
/// "no restrictions", same semantics as the settings screen.
class OnboardingDietPage extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const OnboardingDietPage({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          PaperKicker(context.tr('onb_diet_kicker'), color: PaperColors.terracotta),
          const SizedBox(height: 10),
          Text(context.tr('onb_diet_title'), style: PaperTextStyles.serif(28)),
          const SizedBox(height: 12),
          Text(
            context.tr('onb_diet_sub'),
            style: PaperTextStyles.body(color: PaperColors.muted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kOnboardingDietIds.map((id) {
              final isSelected = selected.contains(id);
              return _DietChip(
                label: context.tr('diet_$id'),
                selected: isSelected,
                onTap: () {
                  final next = Set<String>.from(selected);
                  if (isSelected) {
                    next.remove(id);
                  } else {
                    next.add(id);
                  }
                  onChanged(next);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('onb_diet_none_hint'),
            style: const TextStyle(fontSize: 12.5, color: PaperColors.faint),
          ),
        ],
      ),
    );
  }
}

class _DietChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DietChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PaperColors.ink : PaperColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? PaperColors.ink : PaperColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: selected ? PaperColors.paper : PaperColors.ink,
          ),
        ),
      ),
    );
  }
}
