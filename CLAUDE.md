# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Shoply** is a Flutter shopping list app (iOS-primary) with shared lists, AI-powered ingredient categorization, recipe system, and premium subscriptions. Backend is Supabase (Auth, PostgreSQL, Edge Functions, Storage). State management is Riverpod. The app is bilingual (German/English).

- **Bundle ID**: `com.dominik.shoply`
- **Current version**: 1.1.4+30 (in `pubspec.yaml`)
- **Firebase project**: `shoplyai-1554e`

## Build & Run Commands

```bash
# Install dependencies
flutter pub get
cd ios && pod install && cd ..

# iOS simulator build (primary dev workflow)
flutter build ios --simulator --debug

# Full clean build
flutter clean && flutter pub get && flutter build ios --simulator --debug

# Nuclear clean (when pods misbehave)
cd ios && pod deintegrate && pod install && cd ..
flutter clean && flutter pub get && flutter build ios --simulator --debug

# Run on device
flutter run -d <device-id>

# Static analysis
dart analyze

# Code generation (Riverpod generators, JSON serializable)
dart run build_runner build --delete-conflicting-outputs

# iOS release build
flutter build ios --release
# Then archive in Xcode: Product > Archive > Distribute App > App Store Connect > Upload

# View simulator logs
xcrun simctl spawn <SIMULATOR_ID> log stream --predicate 'processImagePath contains "Runner"' 2>&1 | grep -E "\[TAG\]"
```

There are no automated unit tests. Verification is done via `flutter build ios --simulator --debug`.

## Live Development Workflow

**Always check if the app is already running before starting it.** Use `ps aux | grep flutter | grep run` to check. If not running, start it:

```bash
# Start app on simulator with hot reload
flutter run -d <simulator-id>

# If app is already running, trigger hot reload by pressing 'r' in the flutter run terminal
# or use hot restart with 'R'
```

When making code changes during an active `flutter run` session, the app supports **hot reload** — changes to widget code are reflected instantly without restarting. For changes to `initState`, services, or native code, use **hot restart** (`R`) or full restart.

**Important**: Always verify changes compile before claiming they work. If `flutter run` is active, a failed hot reload will show errors in the terminal. If not running, use `flutter build ios --simulator --debug` to verify.

## Architecture

### Layer Structure (`lib/`)

```
lib/
├── main.dart                    # Service initialization (Supabase, Firebase, Gemini, FCM, etc.)
├── app.dart                     # AdaptiveApp root widget with theme/locale/routing
├── core/
│   ├── config/env.dart          # API keys (gitignored - copy from env.example.dart)
│   ├── constants/               # AppColors, AppDimensions, AppTextStyles, categories
│   ├── localization/            # Bilingual support (DE/EN) via AppLocalizations
│   ├── services/service_locator.dart  # Services.x accessor pattern
│   ├── theme/app_theme.dart     # Material 3 light/dark themes
│   ├── widgets/                 # design_system.dart, liquid_glass_widgets.dart
│   └── gamification/            # Mascot ("Avo") greeting & gamification
├── data/
│   ├── models/                  # Data classes (see Model Location Map below)
│   ├── repositories/            # ItemRepository, ListRepository, AdminRepository
│   └── services/                # ~50 service classes (business logic, API clients)
├── presentation/
│   ├── screens/                 # Feature-organized: home/, recipes/, ai/, profile/, auth/, lists/
│   ├── widgets/                 # Shared widgets: common/, recipes/, recommendations/, deals/
│   ├── state/                   # Riverpod providers (auth, lists, recipes, theme, language)
│   └── providers/               # Additional providers (subscription, ML recommendations)
└── routes/app_router.dart       # GoRouter with auth redirects, deep links, ShellRoute for tabs
```

### Key Architectural Patterns

- **Navigation**: GoRouter with `ShellRoute` wrapping 4 bottom tabs (Home, Recipes, Avo Chat, Profile) via `MainScaffold`. Auth redirects in `redirect:` callback check Supabase session + onboarding status.
- **State**: Riverpod providers in `presentation/state/`. `FutureProvider` for one-time fetches, `StreamProvider` for realtime (Supabase streams), `Provider` for singletons.
- **Services**: Singleton pattern (`ServiceName.instance`) for most services. Accessible via `Services.x` from `lib/core/services/service_locator.dart`. Initialized sequentially in `main()`.
- **iOS 26 Styling**: Uses `adaptive_platform_ui` package for Liquid Glass effects. Custom `MainScaffold` implements floating glass pill navbar with spring physics animations.
- **AI Categorization**: Gemini 1.5-flash via `GeminiCategorizationService` with 1.1s rate limiting and SharedPreferences cache. Falls back to `ProductClassifierService` keyword matching (1000+ German/English keywords across 29 categories). Language-agnostic category IDs (e.g., `'dairy'`) displayed in current locale.
- **Avo AI Chat**: Gemini 2.0 Flash Lite via `AvoAssistantService`. Can add items to lists, search recipes, analyze lists. Tab at `/avo`.
- **Premium**: `SubscriptionService` handles iOS IAP. Features gated via `subscription.isPremium`. Android IAP not implemented.
  - Product IDs: `shoply_premium_monthly` ($2.99/month), `shoply_premium_yearly` ($29.99/year), both with 14-day free trial.
  - Supabase DB functions: `activate_subscription`, `activate_trial`, `is_premium_user`
- **Push Notifications**: Local (`flutter_local_notifications`) + FCM (`firebase_messaging`). FCM tokens stored in `user_devices` table in Supabase.

### Model Location Map (class name != file name)

| Class | File |
|-------|------|
| `Ingredient` | `data/models/recipe.dart` |
| `Recipe` | `data/models/recipe.dart` |
| `IngredientSubstitution` | `data/models/dietary_preference.dart` |
| `ShoppingItem` | `data/models/shopping_item_model.dart` |
| `ShoppingList` | `data/models/shopping_list_model.dart` |

If a model class isn't found at the obvious path, search: `grep -r "class ClassName" lib/data/models/`

### Supabase Schema

Key tables:
- **`users`**: Auth + subscription fields (`subscription_tier`, `subscription_status`, `subscription_expires_at`, `trial_ends_at`, `notification_preferences`)
- **`shopping_lists`**: Lists with `background_type`/`background_value`/`background_image_url`
- **`shopping_items`**: Items with `category` (legacy), `category_id` (language-agnostic, e.g., `'dairy'`), `language` (`'de'`/`'en'`)
- **`recipes`**: Community recipes with `language`, `translations` (JSONB)
- **`subscription_transactions`**: IAP purchase audit trail
- **`user_devices`**: FCM tokens for push notifications (`user_id`, `fcm_token`, `platform`)
- **`user_preferences`**: Theme mode and accent color
- **`ingredient_diet_tags`**: Vegan/vegetarian/gluten-free flags per ingredient name

All tables use Row Level Security (RLS) filtering by `auth.uid()`. Edge Functions: `expire-subscriptions` (daily cron), `send-push-notification`.

### Deep Linking

URL scheme: `shoply://` + Universal Links. Routes handled by `DeepLinkService`. Shared recipes: `/recipe/:id`, shared lists: `/list/:id`, invites: `/invite/:id`.

### iOS Native Components

- **ShoplyWidget**: iOS home screen widget (3 sizes) in `ios/ShoplyWidget/`. Requires App Group `group.com.shoply.app` shared with main app.
- **VoiceAssistantPlugin**: Siri integration (`ios/Runner/VoiceAssistantPlugin.swift`). iOS-only, initialized via `SiriService`.
- **LiquidGlassViewFactory**: Native iOS 26 Liquid Glass rendering (`ios/Runner/LiquidGlassViewFactory.swift`).

## Environment Setup

`lib/core/config/env.dart` is gitignored. Copy `env.example.dart` → `env.dart` and fill in:
- Supabase URL + anon key (from Supabase Dashboard → Settings → API)
- Google OAuth web client ID (use **Web** Client ID, not iOS)
- Gemini API key

`lib/firebase_options.dart` is gitignored - generate via `flutterfire configure`.
`ios/Runner/GoogleService-Info.plist` is gitignored - download from Firebase Console.

## Conventions

- **Import order**: Dart core → Flutter framework → third-party (alphabetical) → app imports (core → data → presentation)
- **Widget extraction**: Screen-specific widgets in `screens/<feature>/widgets/`, shared in `widgets/<category>/`. Extract if >100 lines (single use) or >50 lines (multi-use).
- **Service locator**: Prefer `Services.x` over direct `ServiceName.instance` in new code.
- **Gemini API calls**: Always maintain 1100ms minimum delay between requests. Check SharedPreferences cache first. Never reduce this delay.
- **Platform guards**: Firebase, FCM, IAP, Siri, Analytics are iOS/Android only. Always check `Platform.isIOS` or `Platform.isAndroid` before using.
- **pubspec.yaml**: Many packages are commented out with explanations (macOS compat, iOS build issues). Don't re-enable without testing.
- **Debug logging**: Use emoji prefixes: `🔵 [FEATURE]` info, `✅ [FEATURE]` success, `❌ [FEATURE]` error, `⚠️ [FEATURE]` warning.
- **Category system**: Use language-agnostic IDs (e.g., `'dairy'`, `'fruits_vegetables'`) not display names. UI reads `item.categoryId ?? item.category` for backward compat.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `No such module 'Flutter'` | `cd ios && pod install && cd ..` |
| `Supabase not initialized` | Check `lib/core/config/env.dart` has correct URL/key |
| Pods misbehave | `cd ios && pod deintegrate && pod install && cd ..` |
| Xcode codesigning errors on simulator | Already fixed via identity `-` |
| FCM not working | Needs `GoogleService-Info.plist` in `ios/Runner/` |
| IAP not working on simulator | Expected — requires real device + sandbox account |

## Design System

Dark-mode-first, minimalist design. Key values:
- 90% monochrome with 10% accent color
- Cards: 16-20px border radius, soft layered shadows, 24px internal padding
- Sections: minimum 24-32px spacing between sections
- Touch targets: minimum 64px height
- Animations: 250ms default with `Curves.easeInOutCubic`, 400ms for emphasis
- No heavy borders — use shadows or subtle backgrounds (`alpha: 0.08-0.12`)

Color constants in `AppColors`, spacing in `AppDimensions`, text styles in `AppTextStyles` (all in `lib/core/constants/`).

## Deployment

### TestFlight Upload
1. Increment build number in `pubspec.yaml` (`version: x.x.x+BUILD`)
2. `flutter clean && flutter pub get && cd ios && pod install && cd ..`
3. Open `ios/Runner.xcworkspace` in Xcode
4. Select "Any iOS Device (arm64)" → Product > Archive
5. Organizer → Distribute App → App Store Connect → Upload
6. In App Store Connect → TestFlight → link IAP products to build

### Supabase Migrations
Run SQL in Supabase dashboard SQL editor. Document in `database/migrations/`.
