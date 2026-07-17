# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Branch policy for scheduled routines (standing permission from the owner)

Scheduled/routine Claude Code sessions must NOT each work on their own
one-off session branch (that forces the owner to merge a PR every few
hours). Instead — the repo owner has explicitly granted standing permission
for this — every scheduled routine run should:

1. `git fetch origin claude/daily` — if the branch exists, base all work on
   it: `git checkout -B claude/daily origin/claude/daily`. If it doesn't
   exist yet, create it from the latest `origin/main`.
2. Develop and commit on `claude/daily` (this overrides the session's
   auto-generated designated branch for scheduled routine runs).
3. Push to `origin claude/daily` (use the `GITHUB_FINEGRAINED_PAT` fallback
   below if the normal push 403s).

NEVER push to `main` directly: every push to `main` triggers the TestFlight
deploy workflow (`.github/workflows/ios-testflight.yml`, no path filter),
and routine sessions cannot compile-verify code (no Flutter SDK in the
remote environment). The owner merges `claude/daily` into `main` manually
whenever they choose.

Interactive (non-routine) sessions where the user gives explicit different
instructions are unaffected by this policy.

## Git push fallback (remote/scheduled sessions)

In remote Claude Code sessions, `git push` through the default proxy remote can
fail with 403 ("Resource not accessible by integration") — the GitHub App
integration has read-only repo access. If that happens AND the
`GITHUB_FINEGRAINED_PAT` environment variable is set (a fine-grained PAT with
Contents: Read and write on this repo, configured in the Claude Code
environment settings), push directly instead:

```bash
git push https://x-access-token:${GITHUB_FINEGRAINED_PAT}@github.com/jannisd07/shoply.git <branch>
```

The credentialed URL bypasses the proxy's `insteadOf` rewrite (literal prefix
match doesn't cover URLs with userinfo), and github.com's git endpoint is
reachable through the egress policy. Never print the token or commit it.
If the variable is unset and the normal push 403s, commit locally, tell the
user pushes are blocked, and do not retry.

## Project Overview

**Shoply** is a Flutter shopping list app (iOS-primary) with shared lists, AI-powered ingredient categorization, recipe system, and premium subscriptions. Backend is Supabase (Auth, PostgreSQL, Edge Functions, Storage). State management is Riverpod. The app is bilingual (German/English).

- **Bundle ID**: `com.dominik.shoply`
- **Current version**: see `version:` in `pubspec.yaml` (do not trust hardcoded versions in docs)
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

There is only a minimal smoke test (`test/widget_test.dart`, run via `flutter test`). Primary verification is `flutter build ios --simulator --debug`.

### Verification baseline (keep it green)

- `dart analyze` must report **0 errors and 0 warnings**. There are ~680 pre-existing `info`-level lints (mostly `withOpacity` deprecations) — don't chase them unless asked, but never add new errors/warnings.
- After any change to `lib/`, run `dart analyze` (fast) before claiming success. For non-trivial changes, also run `flutter build ios --simulator --debug`.

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
├── app.dart                     # AvoApp root widget (AdaptiveApp) with theme/locale/routing
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
│   ├── repositories/            # ItemRepository, ListRepository
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

- **ShoppingListWidget**: iOS home screen widget (Small/Medium/Large) in `ios/ShoppingListWidget/` (Xcode target `ShoppingListWidgetExtension`). Requires App Group `group.com.shoply.app` shared with main app — code-signed via `ios/ShoppingListWidgetExtension.entitlements` (the file `ios/ShoppingListWidget/ShoppingListWidget.entitlements` is unused/orphaned, not referenced by the Xcode project).
- **Siri Shortcuts / App Intents**: `ios/Runner/AppIntents.swift` (compiled into the `Runner` target as of 2026-07 — it previously existed on disk but was never added to the Xcode project, so it silently had zero effect). Defines `AddItemToListIntent`/`CreateListIntent`/the recipe-browsing intents plus `ShoplyAppShortcuts` (the Siri phrases). Intents hand off to Flutter via `shoply://add-item`, `shoply://create-list`, `shoply://recipes/...` deep links handled in `DeepLinkService`/`app.dart` — the old App-Group `UserDefaults` pending-queue never worked (it lived in a different `UserDefaults` suite with different key names than the now-deleted `SiriService.dart` read) and has been fully removed, along with `SiriService.dart` itself and `home_screen.dart`'s dead `_checkSiriPendingItems()` (see `FEATURE_IMPLEMENTATION_STATUS.md` Feature 3). `ios/Runner/VoiceAssistantPlugin.swift` (legacy `INIntent`-based donation) is **not** part of the Xcode build and has no Dart-side caller — dead/orphaned, intentionally left unbuilt (adding it back would collide with `AppIntents.swift`'s `CreateListIntent` type name in the same target).
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
| `No space left on device` during build | Disk is chronically full. Free space with `rm -rf ~/Library/Developer/Xcode/DerivedData` and `flutter clean`, then check `df -h /` |

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

> **Note on the auto-generated GitNexus section below:** it is rewritten by every `gitnexus analyze` run. Its MUST/NEVER rules apply **only when `gitnexus_*` MCP tools are actually connected in your session**. If they are not available (common), skip that section entirely — do NOT attempt the tool calls. Use Grep/Read instead: find all callers of a symbol before changing its signature, and review `git diff` before committing.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **shoply** (13216 symbols, 29759 relationships, 256 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/shoply/context` | Codebase overview, check index freshness |
| `gitnexus://repo/shoply/clusters` | All functional areas |
| `gitnexus://repo/shoply/processes` | All execution flows |
| `gitnexus://repo/shoply/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
