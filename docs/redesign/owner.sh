#!/usr/bin/env bash
# Dateibesitz fürs Avo-Redesign: Teil A (Owner, Mac 1) oder Teil B (Jannis, Mac 2).
# Nutzung: bash docs/redesign/owner.sh <pfad> [<pfad> ...]
# Ausgabe pro Pfad: A | B | GETEILT (nur nach Protokoll ändern) | NEU-BEIDE (neue Datei, beide dürfen) |
#                   TEST (gehört dem Besitzer der getesteten Datei) | UNKLAR (vorher abstimmen)
# Erste passende Regel gewinnt. Details und Begründung: docs/redesign/arbeitsteilung.md
set -u

owner_of() {
  local p="${1#./}"
  case "$p" in
    # --- Teil-B-Dateien in Ordnern von Teil A (Angebote, Kosten teilen, Avo-Hinweise) ---
    lib/presentation/screens/lists/widgets/offer_*|\
    lib/presentation/screens/lists/widgets/list_price_summary_bar.dart|\
    lib/presentation/screens/lists/widgets/list_offer_*|\
    lib/presentation/screens/lists/widgets/item_offer_*|\
    lib/presentation/screens/lists/widgets/zip_code_sheet.dart|\
    lib/presentation/screens/lists/widgets/checkout_store_sheet.dart|\
    lib/presentation/screens/lists/widgets/store_chip*|\
    lib/presentation/screens/recipes/widgets/recipe_offers_card.dart|\
    lib/presentation/screens/home/weekly_deals_screen.dart|\
    lib/presentation/screens/home/widgets/avo_nudge_card.dart|\
    lib/presentation/screens/home/widgets/calorie_recipe_nudge_card.dart|\
    lib/presentation/screens/home/widgets/pending_splits_banner.dart|\
    lib/presentation/screens/home/widgets/personal_flyer_card.dart|\
    lib/presentation/screens/home/widgets/price_comparison_nudge_card.dart|\
    lib/presentation/screens/home/widgets/split_trip_nudge_card.dart|\
    lib/presentation/screens/profile/settings/offers_settings_screen.dart)
      echo B ;;

    # --- Gemeinsame Hotspots: kleine Commits, sofort pushen ---
    pubspec.yaml|pubspec.lock|CLAUDE.md|analysis_options.yaml|README.md|.gitignore)
      echo GETEILT ;;

    # --- Datenbank: neue Migrationen dürfen beide anlegen, bestehende gehören B ---
    database/migrations/*|supabase/migrations/*)
      if git cat-file -e "HEAD:$p" 2>/dev/null; then echo B; else echo NEU-BEIDE; fi ;;
    database/*|supabase/*)
      echo B ;;

    # --- Designsystem, Module, Übersetzungs- und Router-Gerüst (A) ---
    lib/core/constants/*|lib/core/theme/*|lib/core/widgets/*|lib/core/mascot/*|lib/core/modules/*|lib/core/design/*)
      echo A ;;
    lib/core/localization/translations/avo*|lib/core/localization/translations/calories*|\
    lib/core/localization/translations/plan*|lib/core/localization/translations/offers*|\
    lib/core/localization/translations/history*|lib/core/localization/translations/notifications*|\
    lib/core/localization/translations/system*)
      echo B ;;
    lib/core/localization/*)
      echo A ;;
    lib/core/utils/category_detector.dart|lib/core/utils/product_name_normalizer.dart|lib/core/utils/request_throttle.dart)
      echo B ;;
    lib/core/utils/*)
      echo A ;;
    lib/core/config/*|lib/core/services/*|lib/main.dart|lib/firebase_options*)
      echo B ;;
    lib/app.dart|lib/presentation/screens/main_scaffold.dart)
      echo A ;;
    lib/routes/areas/avo*|lib/routes/areas/calories*|lib/routes/areas/plan*|lib/routes/areas/offers*|lib/routes/areas/history*)
      echo B ;;
    lib/routes/*)
      echo A ;;

    # --- Screens ---
    lib/presentation/screens/home/*|lib/presentation/screens/lists/*|lib/presentation/screens/recipes/*|\
    lib/presentation/screens/onboarding/*|lib/presentation/screens/auth/*|lib/presentation/screens/splash/*|\
    lib/presentation/screens/profile/*|lib/presentation/screens/subscription/*|lib/presentation/screens/legal/*|\
    lib/presentation/screens/admin/*)
      echo A ;;
    lib/presentation/screens/ai/*|lib/presentation/screens/avo/*|lib/presentation/screens/calories/*|\
    lib/presentation/screens/history/*|lib/presentation/screens/plan/*|lib/presentation/screens/offers/*|\
    lib/presentation/screens/scanner/*|lib/presentation/screens/system/*)
      echo B ;;

    # --- Gemeinsam genutzte Widgets ---
    lib/presentation/widgets/common/*|lib/presentation/widgets/recipes/*|lib/presentation/widgets/recommendations/*|\
    lib/presentation/widgets/tutorial/*|lib/presentation/widgets/design/*)
      echo A ;;
    lib/presentation/widgets/*)
      echo B ;;

    # --- State ---
    lib/presentation/state/auth_provider.dart|lib/presentation/state/items_provider.dart|\
    lib/presentation/state/last_list_provider.dart|lib/presentation/state/lists_provider.dart|\
    lib/presentation/state/recipes_provider.dart|lib/presentation/state/saved_recipes_provider.dart|\
    lib/presentation/state/theme_provider.dart|lib/presentation/state/language_provider.dart|\
    lib/presentation/providers/subscription_provider.dart|lib/presentation/providers/ml_recommendations_provider.dart)
      echo A ;;
    lib/presentation/state/*|lib/presentation/providers/*)
      echo B ;;

    # --- Daten: Repositories und Modelle ---
    lib/data/repositories/*)
      echo A ;;
    lib/data/models/custom_category.dart|lib/data/models/dietary_preference.dart|lib/data/models/list_activity.dart|\
    lib/data/models/product_category.dart|lib/data/models/recipe.dart|lib/data/models/recipe_draft.dart|\
    lib/data/models/recipe_filter.dart|lib/data/models/recommendation_item.dart|lib/data/models/shopping_item_model.dart|\
    lib/data/models/shopping_list_model.dart|lib/data/models/user_model.dart|lib/data/models/user_preferences_model.dart)
      echo A ;;
    lib/data/models/*)
      echo B ;;

    # --- Daten: Services (A = Listen, Rezepte, Konto, Einstellungen; B = KI, Angebote, Verlauf, Kalorien, Avo, System) ---
    lib/data/services/user_service.dart|lib/data/services/native_oauth_service.dart|\
    lib/data/services/onboarding_answers_service.dart|lib/data/services/tutorial_service.dart|\
    lib/data/services/interactive_tutorial_service.dart|lib/data/services/dynamic_tutorial_service.dart|\
    lib/data/services/theme_service.dart|lib/data/services/profile_picture_service.dart|\
    lib/data/services/subscription_service.dart|lib/data/services/app_review_service.dart|\
    lib/data/services/achievements_service.dart|lib/data/services/sharing_service.dart|\
    lib/data/services/list_activity_service.dart|lib/data/services/item_merge_service.dart|\
    lib/data/services/unread_service.dart|lib/data/services/navigation_service.dart|\
    lib/data/services/deep_link_service.dart|lib/data/services/dynamic_link_service.dart|\
    lib/data/services/recipe_service.dart|lib/data/services/recipe_draft_service.dart|\
    lib/data/services/recipe_features_service.dart|lib/data/services/recipe_variations_service.dart|\
    lib/data/services/recipe_labeling_service.dart|lib/data/services/recipe_batch_labeling_utility.dart|\
    lib/data/services/ingredient_substitution_service.dart|lib/data/services/unit_conversion_service.dart|\
    lib/data/services/unified_search_service.dart|lib/data/services/user_category_preferences.dart|\
    lib/data/services/offline_cache_service.dart|lib/data/services/notification_preferences_service.dart)
      echo A ;;
    lib/data/services/*)
      echo B ;;

    # --- iOS und Backend ---
    ios/Runner/LiquidGlassViewFactory.swift|ios/Runner/Assets.xcassets/AppIcon.appiconset/*)
      echo A ;;
    ios/*|android/*|macos/*|web/*|supabase/functions/*)
      echo B ;;

    # --- Assets ---
    assets/illustrations/*|assets/articles/*)
      echo B ;;
    assets/*)
      echo A ;;

    # --- KI-Evals (promptfoo, B) ---
    evals/*)
      echo B ;;

    # --- Doku und Tests ---
    docs/redesign/status-A.md)
      echo A ;;
    docs/redesign/status-B.md)
      echo B ;;
    docs/*)
      echo GETEILT ;;
    test/layout/screens/b/*)
      echo B ;;
    test/layout/*)
      echo A ;;
    test/*)
      echo TEST ;;
    *)
      echo UNKLAR ;;
  esac
}

for f in "$@"; do
  printf '%s\t%s\n' "$(owner_of "$f")" "$f"
done
