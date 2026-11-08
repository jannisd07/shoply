# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## HARD RULE: NEVER sliders (owner, 2026-11-07, no exceptions)

The owner said, in capitals: "NIE SLIDER MACHEN". This beats every skill, reference app and design habit:

- **No slide-in panels of any kind**: no bottom sheets (`showModalBottomSheet`, `showCupertinoModalPopup`,
  `DraggableScrollableSheet`, `BottomSheet`), no half-height modals, no drawers sliding in from an edge.
- **Editing anything (items above all, "Artikel bearbeiten") opens as a full screen** pushed with
  `context.push` (back button, own route) or inline in place. Never in a panel that slides up.
- **No slider controls** (`Slider`, `CupertinoSlider`, range sliders). Use steppers, segmented controls,
  pickers or number fields instead.
- Short confirmations stay as centred alert dialogs (`showAdaptiveDialog`); menus stay as context/pull-down menus.
- Mockups and design docs follow the same rule. Existing violations to remove are listed in
  [docs/DESIGN-STATUS.md](docs/DESIGN-STATUS.md#feste-regel-keine-slider). Never add a new one.

## Skills: check before every answer (mandatory)

Before **every** answer, check whether a skill from the table fits the task. If one does, load it with the Skill tool
without asking, in every session, also in plan mode and also when a clarifying question follows. The first line about
the task is then `Skills: …` with the names, e.g. "Skills: `superpowers:systematic-debugging`". If none fits, leave the
line out. The owner set this up on 2026-11-07 so that skills never have to be named in the prompt; a skill the owner
names later goes into the table right away.

The project skills in [`.claude/skills/`](.claude/skills/) are copied from the owner's RoadTo1Billion$ repo. Notes in
them about Yando, clado, Ornith or RoadTo1Billion paths do not apply here. Shoply's own rules (Paper design, `AppColors`,
the Design System section below) take precedence over a skill's house style.

| Task | Skill |
|---|---|
| New feature, new screen, redesign | `superpowers:brainstorming`, then `superpowers:writing-plans` |
| Large work with many subtasks | plan first, then `superpowers:subagent-driven-development`; across sessions `planning-with-files` |
| Bug, crash, unexpected behaviour | `superpowers:systematic-debugging` |
| Before saying "done" | `superpowers:verification-before-completion` (plus `dart analyze`), for larger changes `superpowers:requesting-code-review` |
| Build, restyle or review a screen, also "looks generic / like AI" | `apple-design` and `design-taste-frontend` first (its app-screen rules), with `frontend-design` and `ui-ux-pro-max`; Liquid Glass API questions: the `liquid-glass` plugin if installed |
| Animations, gestures, sheets, springs, glass materials, typography, haptics, reduced motion | `apple-design` (from `emilkowalski/skills`, commit `c8a7962`). It is written for the web; in Flutter use `SpringSimulation`/`SpringDescription.withDampingRatio` for springs, `DragEndDetails.velocity` for the velocity handoff, `BackdropFilter` for materials, `HapticFeedback` for haptics and `MediaQuery.disableAnimationsOf` for reduced motion |
| Accessibility (contrast, Dynamic Type, VoiceOver, touch targets) | `design:accessibility-review` |
| Check a flow for being foolproof (onboarding, adding items, sharing, paywall) before a release | `idiotensicher-testen`, on the simulator via `run` / the iOS simulator tools |
| In-app texts (buttons, errors, empty states, paywall) | `design:ux-copy`, then `humanizer` |
| App Store text, landing page (`shoply-landingpage`), marketing | `copywriting` (new) or `copy-editing` (revise), then `humanizer` |
| Landing page SEO, AI visibility, structured data, many similar pages | `seo-audit`, `ai-seo`, `schema`, `programmatic-seo` |
| Measuring Gemini / Avo answers (categorisation accuracy, prompt injection) | `promptfoo-evals` (new target: `promptfoo-provider-setup`), only made-up test data |
| Library or API questions (Flutter, Riverpod, Supabase, GoRouter …) | Context7 (`plugin:context7`) |
| Before a TestFlight/App Store release | `claude-security` (`scan changes`, `low`) |

**Missing?** If `superpowers:*`, `frontend-design:*`, `ui-ux-pro-max:*`, `planning-with-files:*`, `claude-security:*`
or Context7 is not available in a session, the plugin isn't installed on this machine: say so first.

## Two people, two Macs (interactive sessions)

Two people work on the app at the same time, each with their own Claude session on their own Mac, sitting side by
side. They say things like "change feature X"; Claude does the whole change and gets it to the other Mac without being
asked for each git step. Scheduled routines keep following the branch policy below instead.

1. **Start of every task:** `git pull --rebase origin main` (commit or stash local work first). The
   `.claude/hooks/sync-check.sh` hook flags it when the other Mac has pushed something you don't have.
2. **Work on a short branch** `feature/<what>` off `main`, one feature per branch, kept small. Name the feature area in
   the first line of the answer ("Bereich: Rezepte") so the person next to you can avoid it.
3. **Before pushing:** `dart analyze` (0 errors, 0 warnings), then `git fetch` and merge `origin/main` into the branch.
   Resolve conflicts yourself; both sides' intent usually survives (two added strings, two added routes). Re-run
   `dart analyze` after a merge.
4. **Finish:** fast-forward `main` to the branch, `git push origin main`, delete the branch. Pushing `main` is fine
   here: the TestFlight workflow only runs manually. Then tell the user in one line that the other Mac can pull.
5. **Hotspots** both sides touch: `lib/core/localization/app_translations.dart`, `lib/routes/app_router.dart`,
   `pubspec.yaml` / `pubspec.lock`, `ios/Podfile.lock` + `Package.resolved`, `lib/main.dart`. Push changes to these
   as soon as they are done instead of letting them sit on a branch.
6. **Never** force-push `main`, rewrite pushed history, or push the gitignored secret files.

**Setting up the second Mac:** clone `github.com/jannisd07/shoply`, install Flutter (≥ 3.38, see `pubspec.lock`) and
CocoaPods, copy the three gitignored files from the first Mac by AirDrop (`lib/core/config/env.dart`,
`lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`), then `flutter pub get` and `pod install`. The
plugins from the skills table must be installed in that Mac's Claude Code too; the project skills come with the repo.

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
- **Firebase project**: `shoply-92f28` (matches the `GoogleService-Info.plist` in use; sender id `901497821159`, the same number as the OAuth client ids in `env.dart`)

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

# iOS release build
flutter build ios --release
# Then archive in Xcode: Product > Archive > Distribute App > App Store Connect > Upload

# View simulator logs
xcrun simctl spawn <SIMULATOR_ID> log stream --predicate 'processImagePath contains "Runner"' 2>&1 | grep -E "\[TAG\]"
```

`flutter test` runs ~170 unit/widget tests (incl. a full-app compile smoke test and a translation-key check). Primary on-device verification is `flutter build ios --simulator --debug`. CI (`.github/workflows/check.yml`) runs `dart analyze --fatal-warnings` + `flutter test` on every push.

### Verification baseline (keep it green)

- `dart analyze` must report **0 errors and 0 warnings** (CI fails otherwise). About 60 `info`-level lints remain (mostly `withOpacity` deprecations) — don't chase them unless asked, but never add new errors/warnings.
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
│   ├── localization/            # Bilingual support (DE/EN): context.tr('key') / AppTranslations
│   ├── theme/app_theme.dart     # Material 3 light/dark themes
│   ├── utils/                   # normalizeProductName, request_throttle, number_parsing (German commas)
│   ├── widgets/                 # design_system.dart, paper/
│   └── mascot/                  # Mascot ("Avo") greeting
├── data/
│   ├── models/                  # Data classes (see Model Location Map below)
│   ├── repositories/            # ItemRepository, ListRepository
│   └── services/                # ~60 singleton services (business logic, API clients)
├── presentation/
│   ├── screens/                 # Feature-organized: home/, recipes/, ai/, profile/, auth/, lists/
│   ├── widgets/                 # Shared widgets: common/, recipes/, recommendations/, deals/
│   ├── state/                   # Riverpod providers (auth, lists, recipes, theme, language)
│   └── providers/               # Additional providers (subscription, ML recommendations)
└── routes/app_router.dart       # GoRouter with auth redirects, deep links, ShellRoute for tabs
```

### Key Architectural Patterns

- **Navigation**: GoRouter with `StatefulShellRoute` wrapping 3 tabs (Home, Recipes, Profile) via `MainScaffold`. Avo chat (`/avo`) and list detail (`/lists/:listId`) are full-screen routes outside the shell — open them with `context.push`, never `go`. The redirect checks session + onboarding without any network call.
- **State**: Riverpod providers in `presentation/state/`. `FutureProvider` for one-time fetches, `StreamProvider` for realtime (Supabase streams), `Provider` for singletons.
- **Services**: Singleton pattern (`ServiceName.instance`) or a Riverpod provider. There is no service locator. `main()` initializes Supabase before `runApp`, everything else concurrently in the background.
- **iOS 26 Styling**: Uses `adaptive_platform_ui` package for Liquid Glass effects. Custom `MainScaffold` implements floating glass pill navbar with spring physics animations.
- **AI Categorization**: `gemini-2.0-flash-lite` via `GeminiCategorizationService` with a serialized 1100 ms rate limit and SharedPreferences cache. Falls back to `ProductClassifierService` keyword matching (1000+ German/English keywords across 29 categories). Language-agnostic category IDs (e.g., `'dairy'`) displayed in current locale.
- **Avo AI Chat**: Gemini 2.0 Flash Lite via `AvoAssistantService`. Can add items to lists, search recipes, analyze lists. Full-screen route `/avo`.
- **Premium**: `SubscriptionService` handles iOS IAP. Features gated via `subscription.isPremium`. Android IAP not implemented.
  - Product IDs: `shoply_premium_monthly` ($2.99/month), `shoply_premium_yearly` ($29.99/year), both with 14-day free trial.
  - Supabase DB functions: `activate_subscription`, `activate_trial`, `is_premium_user`
- **Push Notifications**: Local (`flutter_local_notifications`) + FCM (`firebase_messaging`). FCM token stored in `users.fcm_token` (one device per user; `user_devices` exists but is unused — see docs/OPEN-ISSUES.md).

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

- **ShoppingListWidget**: iOS home screen widget (Small/Medium/Large) in `ios/ShoppingListWidget/` (Xcode target `ShoppingListWidgetExtension`). Requires App Group `group.com.shoply.app` shared with main app — code-signed via `ios/ShoppingListWidgetExtension.entitlements`. Its version comes from `ios/Flutter/Widget.xcconfig` (FLUTTER_BUILD_NAME/NUMBER), so it always matches the app.
- **Siri Shortcuts / App Intents**: `ios/Runner/AppIntents.swift` (compiled into the `Runner` target as of 2026-07 — it previously existed on disk but was never added to the Xcode project, so it silently had zero effect). Defines `AddItemToListIntent`/`CreateListIntent`/the recipe-browsing intents plus `ShoplyAppShortcuts` (the Siri phrases). Intents hand off to Flutter via `shoply://add-item`, `shoply://create-list`, `shoply://recipes/...` deep links handled in `DeepLinkService`/`app.dart` — the old App-Group `UserDefaults` pending-queue never worked (it lived in a different `UserDefaults` suite with different key names than the now-deleted `SiriService.dart` read) and has been fully removed, along with `SiriService.dart` itself and `home_screen.dart`'s dead `_checkSiriPendingItems()` (see `FEATURE_IMPLEMENTATION_STATUS.md` Feature 3). The legacy `VoiceAssistantPlugin.swift` and its Dart channel were deleted (never built; would collide with `AppIntents.swift`'s `CreateListIntent`).
- **LiquidGlassViewFactory**: Native iOS 26 Liquid Glass rendering (`ios/Runner/LiquidGlassViewFactory.swift`).

## Environment Setup

`lib/core/config/env.dart` is gitignored. Copy `env.example.dart` → `env.dart` and fill in:
- Supabase URL + anon key (from Supabase Dashboard → Settings → API)
- Google OAuth web client ID (use **Web** Client ID, not iOS)
- Gemini API key

`lib/firebase_options.dart` is gitignored - generate via `flutterfire configure`.
`ios/Runner/GoogleService-Info.plist` is gitignored - download from Firebase Console.

## Docs (keep them true)

Human-facing docs live in `docs/` (German): [ARCHITECTURE.md](docs/ARCHITECTURE.md) (how the app works, where things
are), [OPEN-ISSUES.md](docs/OPEN-ISSUES.md) (owner-only tasks: backend, deploys, secrets, product decisions),
[DESIGN-STATUS.md](docs/DESIGN-STATUS.md), [CHANGELOG.md](docs/CHANGELOG.md). Maintain them as part of the work,
without being asked:
- A change to architecture, data flow, startup, navigation or a convention → update ARCHITECTURE.md in the same commit.
- Something only the owner can do (SQL migration, `supabase functions deploy`, a secret, a product decision) →
  add it to OPEN-ISSUES.md; remove entries that are done.
- A larger change (new feature, redesign step, big refactor) → one entry at the top of CHANGELOG.md.
- Never recreate long status dumps like the archived `docs/archive/FEATURE_IMPLEMENTATION_STATUS.md`.

## Conventions

- **Import order**: Dart core → Flutter framework → third-party (alphabetical) → app imports (core → data → presentation)
- **Widget extraction**: Screen-specific widgets in `screens/<feature>/widgets/`, shared in `widgets/<category>/`. Extract if >100 lines (single use) or >50 lines (multi-use).
- **Services**: `ServiceName.instance` or a Riverpod provider; write list/item data only through `ItemRepository`/`ListRepository` (they handle optimistic state, realtime and pushes).
- **Snackbars**: `ScaffoldMessenger.of(context)` works on iOS because `app.dart` wraps the app in a `ScaffoldMessenger` (CupertinoApp has none). Keep that wrapper.
- **Debug output**: `debugPrint`, never `print`.
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
| `No space left on device` during build | Disk is chronically full. A global hook cleans caches automatically below 25 GB (`~/.claude/scripts/mac-cleanup.sh`); also `flutter clean`, then check `df -h /System/Volumes/Data` |

## Design System

**The look is D2 · Glas** (Apple style, iOS Liquid Glass on the floating layer, SF Pro, springs). The binding source is the
artifact "Shoply Redesign – 5 Richtungen", page "D2 · Glas" (`D2-Komponenten` and the screens), summarised in
[docs/redesign/design-quelle.md](docs/redesign/design-quelle.md). The old "Paper" look (cream, Georgia, terracotta) is
gone; functions and flows per area are in `docs/redesign/konzept/`, whose visual notes are outdated.

- **Tokens:** one import, `package:shoply/core/design/design.dart`. Colours `context.colors.*` (light, dark and two
  high-contrast variants, all text ≥ 4.5:1), type `context.text(AvoTextStyle.body)` (iOS styles, Dynamic Type up to
  AX5), `AvoSpacing`, `AvoRadii`, `AvoSizes`, `ShellInsets` (where tab bar and accessory sit; never measure them),
  `AvoMotion` (springs from response and damping, `context.reduceMotion`), `AvoHaptics` (the only way to trigger
  haptics). On iOS `AppTheme` is ignored (CupertinoApp), so widgets read these tokens, never the theme.
- **Components:** `lib/presentation/widgets/design/`, one file each with a test: glass (`GlassSurface` only on the
  floating layer, `ContentGlass` on photos inside content), `AppButton`, `GlassToolbar`/`GlassIconButton`,
  `InsetSection` and rows, `CheckCircle`, `ValueStepper`, `AppSegmentedControl`, chips, progress, search, states
  (`EmptyState`, `SkeletonSection`, `StatusRow`, `AvoToast`), dialogs (`showAvoConfirm`, `showModuleOffAlert`),
  `ProBadge`/`ProGate.run`, `AvoFigure`, `AvoIcons`, `AppTabBar`, and from S2b list, recipe, menu, editor and input
  pieces. Screens are built from these; Teil B uses the same set.
- **Rules:** no hex values, font sizes or durations in screens (a D2 one-off inside a component is a private constant
  marked `// D2`). Text never sits in a fixed height, only minimum heights; at AX sizes rows wrap or stack. Touch
  targets ≥ 44 pt. Reduce Transparency and Increase Contrast turn glass opaque; Reduce Motion turns movement into
  short fades. Avo appears only as the 3D figure (`AvoFigure`). No sheets or sliders (hard rule above).
- **Layout check:** every screen and component passes `layoutMatrix` from `test/layout/layout_matrix.dart` (widths
  320–440 pt, text scale 1.0–3.1, bold text, dark mode, contrast; fails on any overflow or clipped text).
- `AppColors`, `PaperColors`, `PaperTextStyles` and `AppDimensions` in `lib/core/constants/` are legacy shims that
  already show D2 values; don't use them in new code. They go once no screen needs them.

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
