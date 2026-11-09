import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Whether a module row may be shown (Konzept 00 §15.2).
enum ModuleRowStatus {
  /// Shown in onboarding, settings and Avo's knowledge.
  visible,

  /// Half-finished: never shown, the module counts as off.
  hidden,
}

/// One row of the module choice (Konzept 17 §3.3, §9.5): the same symbol,
/// title and benefit sentence in onboarding, Einstellungen > Module (Kap. 18)
/// and Avo's knowledge.
@immutable
class ModuleDescriptor {
  const ModuleDescriptor({
    required this.module,
    required this.icon,
    required this.tileColor,
    required this.titleKey,
    required this.benefitKey,
  });

  final AppModule module;

  /// White glyph on the coloured tile (D2 X-Onboarding).
  final AvoIconData icon;

  /// Tile colour: data like the list palette, not a design token (D2).
  final Color tileColor;

  /// Translation key of the title (`common_module_*`).
  final String titleKey;

  /// Translation key of the one-sentence benefit (under 60 characters, so it
  /// takes at most two lines at 320 pt and size L).
  final String benefitKey;

  /// Preselection in the onboarding module step.
  bool get onboardingDefault => module.onboardingDefault;

  ModuleRowStatus get status =>
      module.released ? ModuleRowStatus.visible : ModuleRowStatus.hidden;
}

/// Symbols the base set (`AvoIcons`) does not have yet, drawn from the D2
/// X-Onboarding paths (24 pt grid).
abstract final class ModuleIcons {
  /// Kalorien: a flame (D2).
  static const flame = AvoIconData([
    AvoIconPath(
      'M12 3c1 4 6 6 6 11a6 6 0 01-12 0c0-3 2-4 2-7 2 1 3 3 3 4 1-2 1-5 1-8z',
      style: AvoIconStyle.fill,
    ),
  ]);

  /// Kosten teilen: two people (D2).
  static const split = AvoIconData([
    AvoIconCircle(9, 9, 3, style: AvoIconStyle.fill),
    AvoIconCircle(17, 10, 2.4, style: AvoIconStyle.fill),
    AvoIconPath(
      'M3 19c0-3 3-5 6-5s6 2 6 5zM15 19c0-2 1-3.5 3-3.5s3 1.5 3 3.5z',
      style: AvoIconStyle.fill,
    ),
  ]);
}

/// All module rows in the order of Konzept 17 §3.3 (F-04). Read through
/// [visibleModuleDescriptors] in screens; unreleased modules are never shown.
const List<ModuleDescriptor> moduleDescriptors = [
  ModuleDescriptor(
    module: AppModule.offers,
    icon: AvoIcons.tag,
    tileColor: Color(0xFFFF9F0A), // D2
    titleKey: 'common_module_offers',
    benefitKey: 'onb_module_offers_benefit',
  ),
  ModuleDescriptor(
    module: AppModule.mealPlan,
    icon: AvoIcons.calendar,
    tileColor: Color(0xFF5E5CE6), // D2
    titleKey: 'common_module_meal_plan',
    benefitKey: 'onb_module_meal_plan_benefit',
  ),
  ModuleDescriptor(
    module: AppModule.avo,
    icon: AvoIcons.sparkle,
    tileColor: Color(0xFF1F7A3A), // D2 tint
    titleKey: 'common_module_avo',
    benefitKey: 'onb_module_avo_benefit',
  ),
  ModuleDescriptor(
    module: AppModule.calories,
    icon: ModuleIcons.flame,
    tileColor: Color(0xFFA8521A), // D2
    titleKey: 'common_module_calories',
    benefitKey: 'onb_module_calories_benefit',
  ),
  ModuleDescriptor(
    module: AppModule.costSplit,
    icon: ModuleIcons.split,
    tileColor: Color(0xFF0062CC), // D2
    titleKey: 'common_module_cost_split',
    benefitKey: 'onb_module_cost_split_benefit',
  ),
];

/// The rows that may be shown. [offersAvailable] false drops "Preise &
/// Angebote" without a gap when the remote kill switch is known to be off
/// (Konzept 00 §15.3).
List<ModuleDescriptor> visibleModuleDescriptors({
  bool offersAvailable = true,
}) => [
  for (final d in moduleDescriptors)
    if (d.status == ModuleRowStatus.visible &&
        (offersAvailable || d.module != AppModule.offers))
      d,
];
