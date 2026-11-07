import 'package:flutter/material.dart';
import 'package:shoply/core/constants/diet_preferences.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/multi_select_settings_screen.dart';

/// Profile → Diet preferences: edits `users.diet_preferences`. An empty
/// selection means "no restrictions".
class DietPreferencesScreen extends StatelessWidget {
  const DietPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiSelectSettingsScreen(
      title: context.tr('diet_preferences'),
      sectionTitle: context.tr('diet_preferences'),
      column: 'diet_preferences',
      initialValues: (user) => user.dietPreferences,
      showSelectedCount: true,
      options: [
        for (final id in kDietPreferenceIds)
          MultiSelectOption(
            id: id,
            title: context.tr('diet_$id'),
            subtitle: context.tr('diet_${id}_desc'),
          ),
      ],
      noneSectionTitle: context.tr('other'),
      noneOption: MultiSelectOption(
        id: '',
        title: context.tr('no_restrictions'),
        subtitle: context.tr('i_eat_everything'),
      ),
    );
  }
}
