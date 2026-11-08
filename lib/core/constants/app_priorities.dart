import 'package:flutter/material.dart';

/// One persona/motivation chip a user can pick during onboarding (or edit
/// later from Profile → "What matters to you") answering the brief's
/// "ask what kind of user they are / what they want from the app"
/// requirement. Purely a personalization signal — selecting or not
/// selecting any of these never hides or gates a feature. Home keeps the
/// fixed D2 order (owner decision 2026-11-07); the priorities feed recipe
/// personalisation and Avo.
class AppPriority {
  final String id;
  final IconData icon;

  const AppPriority(this.id, this.icon);
}

const List<AppPriority> kAppPriorities = [
  AppPriority('save_money', Icons.savings_outlined),
  AppPriority('share_lists', Icons.group_outlined),
  AppPriority('eat_healthier', Icons.local_fire_department_outlined),
  AppPriority('discover_recipes', Icons.restaurant_menu_outlined),
  AppPriority('stay_organized', Icons.checklist_rtl_outlined),
];
