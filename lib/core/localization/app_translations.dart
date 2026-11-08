import 'package:shoply/core/localization/translations/common.dart';
import 'package:shoply/core/localization/translations/home.dart';
import 'package:shoply/core/localization/translations/lists.dart';
import 'package:shoply/core/localization/translations/lists_detail.dart';
import 'package:shoply/core/localization/translations/lists_item.dart';
import 'package:shoply/core/localization/translations/lists_overview.dart';
import 'package:shoply/core/localization/translations/lists_shopping.dart';
import 'package:shoply/core/localization/translations/recipes.dart';
import 'package:shoply/core/localization/translations/recipes_browse.dart';
import 'package:shoply/core/localization/translations/recipes_cook.dart';
import 'package:shoply/core/localization/translations/recipes_detail.dart';
import 'package:shoply/core/localization/translations/recipes_library.dart';
import 'package:shoply/core/localization/translations/onboarding.dart';
import 'package:shoply/core/localization/translations/auth.dart';
import 'package:shoply/core/localization/translations/profile.dart';
import 'package:shoply/core/localization/translations/settings.dart';
import 'package:shoply/core/localization/translations/paywall.dart';
import 'package:shoply/core/localization/translations/legal.dart';
import 'package:shoply/core/localization/translations/avo.dart';
import 'package:shoply/core/localization/translations/calories.dart';
import 'package:shoply/core/localization/translations/plan.dart';
import 'package:shoply/core/localization/translations/offers.dart';
import 'package:shoply/core/localization/translations/history.dart';
import 'package:shoply/core/localization/translations/notifications.dart';
import 'package:shoply/core/localization/translations/system.dart';

/// App translations for English and German.
///
/// The texts live in one file per area under `translations/` (Teil A: common, home,
/// lists, recipes, onboarding, auth, profile, settings, paywall, legal; Teil B: avo,
/// calories, plan, offers, history, notifications, system). Both maps are const, so a
/// key defined in two area files is a compile error.
class AppTranslations {
  static String get(
    String key,
    String languageCode, {
    Map<String, String>? params,
  }) {
    final translations = languageCode == 'de' ? _de : _en;
    String text = translations[key] ?? _en[key] ?? key;

    // Replace parameters
    if (params != null) {
      params.forEach((paramKey, value) {
        text = text.replaceAll('{$paramKey}', value);
      });
    }

    return text;
  }

  static const Map<String, String> _en = {
    ...commonEn,
    ...homeEn,
    ...listsEn,
    ...listsDetailEn,
    ...listsItemEn,
    ...listsShoppingEn,
    ...listsOverviewEn,
    ...recipesEn,
    ...recipesBrowseEn,
    ...recipesLibraryEn,
    ...recipesDetailEn,
    ...recipesCookEn,
    ...onboardingEn,
    ...authEn,
    ...profileEn,
    ...settingsEn,
    ...paywallEn,
    ...legalEn,
    ...avoEn,
    ...caloriesEn,
    ...planEn,
    ...offersEn,
    ...historyEn,
    ...notificationsEn,
    ...systemEn,
  };

  static const Map<String, String> _de = {
    ...commonDe,
    ...homeDe,
    ...listsDe,
    ...listsDetailDe,
    ...listsItemDe,
    ...listsShoppingDe,
    ...listsOverviewDe,
    ...recipesDe,
    ...recipesBrowseDe,
    ...recipesLibraryDe,
    ...recipesDetailDe,
    ...recipesCookDe,
    ...onboardingDe,
    ...authDe,
    ...profileDe,
    ...settingsDe,
    ...paywallDe,
    ...legalDe,
    ...avoDe,
    ...caloriesDe,
    ...planDe,
    ...offersDe,
    ...historyDe,
    ...notificationsDe,
    ...systemDe,
  };
}
