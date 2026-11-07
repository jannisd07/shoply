import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_priorities.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/multi_select_settings_screen.dart';

/// Profile → "What matters to you" — lets a user change the priorities
/// they picked (or skipped) during onboarding at any time. Only ever
/// reorders home-screen nudge cards; nothing here gates a feature.
class AppPrioritiesScreen extends StatelessWidget {
  const AppPrioritiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiSelectSettingsScreen(
      title: context.tr('app_priorities'),
      hint: context.tr('app_priorities_hint'),
      sectionTitle: context.tr('app_priorities'),
      column: 'app_priorities',
      initialValues: (user) => user.appPriorities,
      options: [
        for (final priority in kAppPriorities)
          MultiSelectOption(
            id: priority.id,
            title: context.tr('priority_${priority.id}'),
            icon: priority.icon,
          ),
      ],
    );
  }
}
