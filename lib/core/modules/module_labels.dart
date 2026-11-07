import 'package:flutter/widgets.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';

/// Display names of the modules (onboarding, settings, "turned off" alert).
extension AppModuleLabel on AppModule {
  String label(BuildContext context) => switch (this) {
    AppModule.offers => context.tr('common_module_offers'),
    AppModule.mealPlan => context.tr('common_module_meal_plan'),
    AppModule.calories => context.tr('common_module_calories'),
    AppModule.avo => context.tr('common_module_avo'),
    AppModule.costSplit => context.tr('common_module_cost_split'),
  };
}
