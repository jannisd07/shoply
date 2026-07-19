# Daily Code Review Log

Tracks files reviewed by the scheduled daily code-quality routine, so future
runs pick a different part of the app each time. One entry per run.

## 2026-07-05 — `lib/presentation/screens/profile/settings/notifications_screen.dart`

Reviewed the file plus its references: `NotificationPreferencesService`
(`lib/data/services/notification_preferences_service.dart`),
`MascotNotificationService`, `PaperSettingsAppBar`/`PaperSectionHeader`
widgets, routing from `profile_screen.dart`, and localization keys in
`app_translations.dart`.

Findings:
- **Minor bug**: `_loadPreferences`/toggle handlers in the screen chain
  `.then()` off `NotificationPreferencesService.setMasterEnabled` /
  `setCategoryEnabled` with no `.catchError`. Those service methods leave
  their first two lines (`SharedPreferences.getInstance()`, `prefs.setBool`)
  outside their own try/catch, so a throw there would produce an unhandled
  Future exception. Low impact, easy fix.
- **Cleanliness**: `build()` is ~145 lines (over the CLAUDE.md >100-line
  extraction guidance) due to four structurally identical
  header+toggle-list sections; could be data-driven with a loop.
- **Cleanliness (minor)**: `_loadPreferences()` awaits 8 category reads
  serially instead of `Future.wait`.
- No security issues, no dead code, no provider misuse (file doesn't use
  Riverpod — plain `StatefulWidget` talking to singleton services, all
  imports/widgets/routes/localization keys verified to exist and be used).

No changes were made this run (review-only).

## 2026-07-06 — `lib/presentation/screens/lists/list_activities_screen.dart`

Reviewed the file plus its references: `ListActivity`/`ListActivityType`
(`lib/data/models/list_activity.dart`), `ListActivityService`
(`lib/data/services/list_activity_service.dart`), the only caller of
`logActivity`/`notifyCategoryChange` (`category_order_screen.dart`), the
route (`lib/routes/app_router.dart`), and the notification-tap path
(`NavigationService.navigateToListActivities`, `fcm_service.dart`,
`notification_service.dart`).

Findings:
- **Feature gap**: `ListActivityType` has 13 cases, each with full
  description/icon/color rendering support, but `logActivity()` is only
  ever called for 3 of them (`categoryAdded`, `categoryRemoved`,
  `categoryReordered`), all from `category_order_screen.dart`. The other
  10 types (item added/removed/checked/unchecked, list shared, member
  joined/left, list renamed, shopping completed, background changed) are
  fully built out in the UI but never produced anywhere in the app — this
  screen is effectively a "category changes log" dressed as a general
  activity feed.
- **Design mismatch**: activities are stored only in local
  `SharedPreferences`, keyed by `listId` with no per-user/device scoping,
  and there is no Supabase table or sync logic despite the file's own doc
  comment claiming "synced when possible." For a *shared* list, each
  member's activity feed only shows changes made on their own device —
  other members' category edits never appear, they only trigger a push
  notification (which doesn't write anything into the recipient's local
  activity log).
- **Minor bug**: `widget.listName` is threaded all the way through the
  notification tap → `NavigationService.navigateToListActivities` → GoRouter
  query param → this screen's constructor, but is never read in `build()`
  — the app bar always shows the generic `list_activities` translation
  ("List Activities"/"Listenaktivitäten") instead of naming the list.
- **Minor bug**: `_showClearConfirmation`'s confirm handler calls
  `setState` after `await _activityService.clearActivities(...)` with no
  `mounted` check, unlike `_loadActivities` in the same file which does
  check `mounted`. Could throw if the screen is popped while the clear is
  in flight.
- **Cleanliness**: the screen is declared as `ConsumerStatefulWidget`/
  `ConsumerState` but never touches `ref` — could be a plain
  `StatefulWidget`.
- **Efficiency (minor)**: for a category reorder/add/remove,
  `logActivity` and `notifyCategoryChange` each independently fetch the
  current user's `display_name` from Supabase (two round-trips for one
  event), and `notifyCategoryChange` fetches each member's `fcm_token`
  one row at a time in a loop instead of a single batched `.in_()` query.
- No direct security issues found (no auth/RLS logic in this file; local
  storage is per-device and not attacker-reachable).

No changes were made this run (review-only) — the feature-completeness and
sync-architecture gaps look like product decisions, not one-line fixes.

## 2026-07-07 — `lib/presentation/widgets/oauth_webview_dialog.dart`

Reviewed the file plus a search for its references, and how Google Sign-In
actually works in the app today (`login_screen.dart`, `signup_screen.dart`,
`welcome_screen.dart`, `supabase_service.dart`).

Findings:
- **Dead code**: `OAuthWebViewDialog` has zero callers anywhere in the repo
  (`grep`-confirmed — the class only appears in its own definition file).
  Actual Google auth is implemented via the `google_sign_in` package
  end-to-end; this widget is an orphaned prototype.
- **Bug (if it were ever used)**: even ignoring the dead-code issue, the
  widget doesn't work. `build()` branches on
  `kIsWeb || defaultTargetPlatform == TargetPlatform.iOS`, but *both*
  branches render a static "not supported, use email/password" message —
  there is no actual WebView anywhere. `initState()` has a matching
  platform check whose body is just a comment: `// WebView initialization
  would go here for supported platforms`. The three constructor
  parameters that give the widget its purpose — `authUrl`,
  `redirectScheme`, `onRedirect` — are never read anywhere in the class.
- **Provenance**: `git log --follow` shows this file was introduced in
  commit `65b615e` ("Add avocado loading screen and video_player
  dependency"), an unrelated bulk commit — consistent with it being
  scaffolding that was never finished or connected.
- No security issues (no auth logic actually executes here — it's an
  inert placeholder), no localization keys needed fixing (its strings are
  hardcoded English, but since it's unreachable/dead this doesn't affect
  users).

No changes were made this run (review-only). Recommendation for a future
run/human: safe to delete `lib/presentation/widgets/oauth_webview_dialog.dart`
outright since it has no callers, or finish wiring it to a real WebView
package if OAuth-via-webview is still wanted as a fallback to
`google_sign_in`.

## 2026-07-08 — `lib/data/services/product_matching_service.dart`

Reviewed the file plus its one real caller
(`lib/data/services/recommendation_service.dart`), the SQLite-backed
`DealsDatabaseService` (`lib/data/services/deals_database_service.dart`)
it queries, and how `RecommendationService.getRecommendations` gets wired
into the UI (`recommendations_provider.dart` →
`recommendations_section.dart`).

Findings:
- **Dead code**: 9 of this file's 11 public static methods are unused
  anywhere in the app (`grep`-confirmed) — `findDealsForShoppingList`,
  `findBestDealsForShoppingList`, `calculateTotalSavings`,
  `findDealsByCategory`, `categorizeShoppingList` (+ its private
  `_detectCategory` helper with hardcoded German-only keyword lists),
  `findSimilarProducts`, `findRelatedProducts`, `hasActiveDeals`, and
  `countDealsForProduct`. Only `findBestDealForProduct` is called (from
  `RecommendationService`), and it internally uses `findDealsForProduct`.
  That's roughly 100 of the file's 245 lines with no live caller.
- **Efficiency bug (real, in the live path)**: `RecommendationService
  .getRecommendations()` awaits `ProductMatchingService
  .findBestDealForProduct(stats.itemName)` **serially inside a `for` loop**
  over every purchase-history item not already on the list. Each call
  re-runs `findDealsForProduct`, which re-queries `DealsDatabaseService
  .getActiveDeals()` — the *entire* active-deals table, no caching — and
  then computes a Levenshtein `string_similarity` score against every one
  of those deals. For N history items and M active deals this is N
  redundant full-table reads plus O(N×M) string comparisons, none of it
  parallelized (`Future.wait` isn't used). This runs on the home screen's
  recommendation section, so it scales with both purchase history size and
  active-deal volume.
- **Cache-defeating provider key**: `recommendationsProvider` in
  `recommendations_provider.dart` is a `FutureProvider.family` keyed on
  `List<ShoppingItemModel>`. `ShoppingItemModel` itself is `Equatable`, but
  the surrounding `List` is compared by Riverpod with plain `==`, which for
  a `List` is reference/identity equality, not element-wise — Dart's
  `List` doesn't override `==`. `recommendations_section.dart` passes in
  `currentItems` fresh from the parent on every rebuild, so nearly every
  rebuild produces a "new" family key even when the items haven't actually
  changed, defeating Riverpod's caching and re-triggering the expensive
  path above far more often than the underlying data changes. A
  content-based key (e.g. a sorted list of item ids/names, or a hash) would
  fix this.
- **Misleading comments**: `findBestDealForProduct` (the only live method)
  has `// Höchster Rabatt` ("highest discount") and `// Bester Deal
  insgesamt` ("best deal overall") comments on `.first` picks, but the list
  they're drawn from is sorted by *similarity* (from `findDealsForProduct`),
  not by discount — so the "best deal" returned is actually the best
  *name match*, which may not carry the largest discount. Low impact, but
  the comment doesn't describe what the code does.
- No security issues (local SQLite only, no user input reaches raw SQL —
  all queries use parameterized `where`/`whereArgs`).

No changes were made this run (review-only). Recommendation for a future
run/human: either delete the 9 unused methods (and `_detectCategory`) to
cut ~100 lines of dead weight, or wire them in if they were meant to power
features (batch list-matching, category grouping) that never got
connected. Separately, the family-key and serial-loop issues in the live
recommendation path are worth fixing together — they compound: a
correctly memoized provider would mean the expensive N×M matching only
reruns when the list truly changes, and parallelizing/batching the deal
lookups (e.g. fetch `getActiveDeals()` once per `getRecommendations()`
call instead of once per item) would cut it from N queries to 1.

## 2026-07-13 — `lib/presentation/widgets/recommendations/ml_recommendations_section.dart`

Reviewed the file plus its references: `mlRecommendationsProvider`
(`lib/presentation/providers/ml_recommendations_provider.dart`),
`MLRecommendationService`
(`lib/data/services/ml_recommendation_service.dart`, 665 lines),
`ShoppingHistoryService`/`PurchaseTrackingService` (the Supabase-backed
data sources it queries), `GeminiCategorizationService` (the
complementary-items call), `RecommendationCard` (the row widget it
renders), and the one caller wiring it up (`list_detail_screen.dart`).
The section widget itself (collapsible paper card, `AnimatedCrossFade`) is
clean — all issues are in the service layer it depends on.

Findings:
- **Efficiency bug (real, in the live path)**: `getRecommendations()` calls
  `ShoppingHistoryService.getRecentHistory(limit: 10)` directly, and then
  `_calculateAssociationScore()` independently calls
  `getRecentHistory(limit: 50)` again — same method, same user, just a
  different limit. Each `getRecentHistory` call issues 2-3 separate
  Supabase round-trips internally (own history, `list_members`, shared
  history), so *every* recommendation computation makes ~4-6 network
  queries fetching heavily overlapping data. The limit-10 result is a
  strict prefix of the limit-50 result and could be reused/sliced instead
  of queried twice.
- **Efficiency/cost bug (real, in the live path)**:
  `_calculateComplementaryScore()` calls
  `GeminiCategorizationService.getSmartRecommendations()` with **no
  caching** — unlike `categorizeItem()` in the same service, which caches
  via `_categoryCache`/`SharedPreferences`. Because
  `mlRecommendationsProvider` (`FutureProvider.autoDispose.family`)
  `ref.watch`es `itemsNotifierProvider(listId)`, the *entire* recommendation
  pipeline — including this Gemini call — reruns on every list mutation
  (add/remove/check an item), so routine shopping-list use can trigger a
  fresh, billed Gemini API request every time, gated only by the service's
  rate limiter.
- **Convention violation**: `GeminiCategorizationService._rateLimitMs` is
  `1000` (`gemini_categorization_service.dart:20`), but CLAUDE.md's Gemini
  convention says "Always maintain 1100ms minimum delay between requests
  ... Never reduce this delay." `git log -p` shows it's been 1000ms since
  the constant was introduced, i.e. a pre-existing gap between code and
  documented convention rather than a regression — flagging since it's
  directly in this feature's call chain.
- **Bilingual-UX bug**: every recommendation "reason" string produced by
  `MLRecommendationService` is a hardcoded German literal — `'Oft
  gekauft'`, `'Passt gut dazu'`, `'Ergänzt deine Liste'`, `'Wieder Zeit zu
  kaufen'`, `'Oft auf dieser Liste'`, `'Beliebtes Produkt'` — and
  `RecommendationCard` (`recommendation_card.dart:65`) renders
  `recommendation.reason` verbatim with no localization lookup. English-
  locale users see German subtext under every AI recommendation. Compounding
  this, the Gemini prompt in `getSmartRecommendations()`
  (`gemini_categorization_service.dart:313-326`) explicitly instructs
  "Antworte NUR mit Artikelnamen auf Deutsch" — so the complementary-item
  *suggestions themselves* are always German words, regardless of app
  locale. This contradicts the project's stated bilingual DE/EN design and
  the language-agnostic-ID pattern used elsewhere (e.g. `category_id`).
- **Dead category-icon matching**: `_getStarterRecommendations()` hardcodes
  German display-name categories (`'Milchprodukte'`, `'Obst'`, `'Gemüse'`,
  `'Backwaren'`, `'Eier & Milchprodukte'`), but
  `RecommendationCard._getCategoryIcon()` matches against English keyword
  substrings (`'fruit'`, `'dairy'`, `'bread'`, ...). None of the German
  strings contain their English counterparts, so starter recommendations
  (shown to brand-new users with no purchase history — the "cold start"
  experience) always fall through to the generic `shopping_basket_outlined`
  icon instead of a category-specific one.
- **Dead code**: `MLRecommendationService._normalizeScore()`
  (`ml_recommendation_service.dart:392`) has zero callers anywhere in the
  file or repo (`grep`-confirmed) — every other scoring helper normalizes
  inline instead of using it.
- **Doc/logic mismatch (minor)**: `_filterByConfidence()`'s docstring says
  tiers "fill up to 4 total" (good) / "fill up to 3 total" (decent) / "fill
  up to 2 total" (acceptable), but the actual fill logic is
  cumulative-remaining-slots against `maxRecommendations = 5`, so e.g. 3
  excellent + 2 good already reaches 5 total, not capped at 4. Cosmetic —
  the code's behavior (fill 5 slots, prioritizing higher tiers) is
  reasonable, the comment just doesn't describe it precisely.
- No direct security issues: all Supabase queries in the reviewed chain
  use parameterized `.eq()`/`.inFilter()`, no raw SQL or string
  interpolation into queries.

No changes were made this run (review-only). Recommendation for a future
run/human: collapse the two `getRecentHistory` calls into one (fetch once
at the larger limit, slice for the smaller use), add a
content-based/short-TTL cache around `getSmartRecommendations()` so a
single Gemini call doesn't re-fire on every item toggle, and route both
the reason strings and the Gemini prompt output through
`context.tr(...)`/locale-aware generation the way the rest of the app's
category system already does.

## 2026-07-16 — `lib/presentation/widgets/premium_feature_gate.dart`

Reviewed the file (three widgets: `PremiumFeatureGate`, `GoProButton`,
`PremiumLockedOverlay`) plus its references: `isSubscribedProvider`/
`subscriptionStatusProvider` (`lib/presentation/providers/subscription_provider.dart`),
`showSubscriptionSheet` (`lib/presentation/screens/subscription/subscription_screen.dart`),
and every real premium-gating call site in the app
(`profile_screen.dart`, `recipe_detail_screen.dart`, `avo_chat_screen.dart`).

Findings:
- **Dead code (whole file)**: all three exported widgets have zero callers
  anywhere in the repo (`grep`-confirmed, no barrel export either). Every
  actual premium gate in the app — the Premium/email line and Pro banner in
  `profile_screen.dart`, the cooking-mode button in
  `recipe_detail_screen.dart`, the Premium chip in `avo_chat_screen.dart` —
  hand-rolls its own `if (ref.watch(isSubscribedProvider)) {...} else
  {...}` UI instead of using this dedicated gating widget, duplicating the
  same branch four times over instead of centralizing it here. Same
  pattern as the `oauth_webview_dialog.dart` finding from 2026-07-07:
  built, never wired in.
- **Dead field / bug (latent, inside the dead code)**: `PremiumFeatureGate`
  takes a `featureName` constructor parameter (line 13) but never reads it
  anywhere in `build()`/`_buildPremiumBadge()`/`_buildSmallBadge()` — the
  overlay always shows the generic `premium_feature`/`unlock_with_pro`
  strings regardless of what feature the caller says is being gated. (The
  same-named `featureName` field on the unrelated `PremiumLockedOverlay`
  class, line 245, is used correctly — only the `PremiumFeatureGate` one is
  dropped.)
- **Latent gesture conflict (inside the dead code)**: when
  `showBadgeOnly: true`, `IgnorePointer.ignoring` is set to `!showBadgeOnly`
  = `false`, so the wrapped `child` keeps receiving touches at full
  opacity, while the enclosing `GestureDetector.onTap` also wants to open
  the subscription sheet on any tap in the same region. If `child` itself
  contains interactive elements, the two tap handlers would compete in the
  gesture arena instead of the paywall reliably winning. Never observed in
  practice since the widget is unreferenced.
- **Doc/code mismatch (tangential)**: CLAUDE.md's Premium section says
  "Features gated via `subscription.isPremium`", but no `isPremium`
  property exists anywhere in `lib/` (`grep`-confirmed) — real gating is
  `ref.watch(isSubscribedProvider)` (backed by
  `SubscriptionService.status == SubscriptionStatus.subscribed`) called ad
  hoc at each site. Worth a docs fix independent of this file.
- **Minor style**: `PremiumFeatureGate._showSubscriptionSheet` is a
  private one-line wrapper that just calls the top-level
  `showSubscriptionSheet(context)` — adds indirection for a single call
  site, could call the top-level function directly.
- No security issues (no auth/entitlement logic lives in this file itself
  — it only reads a provider computed elsewhere).

No changes were made this run (review-only). Recommendation for a future
run/human: either delete `premium_feature_gate.dart` outright (like the
`oauth_webview_dialog.dart` recommendation) since none of its three widgets
are reachable, or — if centralized premium gating is still wanted — wire
`PremiumFeatureGate`/`PremiumLockedOverlay` into the four existing hand-rolled
call sites and fix the dropped `featureName` while doing so.

## 2026-07-17 — `lib/data/repositories/admin_repository.dart` (deleted)

Randomly selected file (64 lines, two methods:
`fixAllListOwnership`/`deleteAllLists`). Checked for callers (`grep`-
confirmed zero — only self-reference and a `CLAUDE.md` architecture-doc
mention), then, because the methods looked destructive, queried the live
**ShoplyAI** Supabase project's actual RLS policies (`pg_policies` on
`shopping_lists`/`list_members`) via the Supabase MCP tool to determine
real-world exploitability rather than guessing from the code alone.

Findings:
- **Latent privilege-escalation bug (would work against production RLS,
  not just inert)**: `fixAllListOwnership()` has no admin/role check —
  only `userId != null` (i.e. any signed-in user). It fetches every list
  visible to the caller (RLS's `SELECT` policy on `shopping_lists` allows
  this for lists you own, are a member of, **or** any list with
  `is_shared = true` and a `share_code`, whether or not you've joined it),
  then loops `UPDATE shopping_lists SET owner_id = <caller>`. The RLS
  `UPDATE` policy only permits this for lists the caller already owns or
  is a member of, so share-code-only lists are silently skipped — but for
  every shared list the caller is already a plain **member** of, the
  update succeeds and makes them owner. The very next step,
  `DELETE FROM list_members WHERE user_id != caller` (no `list_id`
  filter), is scoped by RLS's `DELETE` policy to
  "self" rows or rows in lists the caller owns — and since the update loop
  just made the caller owner of every shared list they belonged to, this
  delete now sweeps across all of them, evicting every other member.
  Net effect: **any member of any shared list can call this one method to
  unilaterally seize ownership and kick out everyone else — including the
  real owner — from every shared list they belong to**, with no
  confirmation and no role gate. This is squarely in Shoply's core
  "shared lists" feature.
- **Related RLS gap surfaced by this code path (not fixed here, flagging
  separately)**: the insert step re-adds the caller to every fetched list
  with `role: 'owner'`. The `list_members` `INSERT` policies
  ("Users can join lists" / "Anyone can join shared lists") only check
  `user_id = auth.uid()` in `with_check` — they don't constrain `role` — so
  self-inserting as `'owner'` on a share-code-visible list you were never
  invited to is accepted by RLS. Worth a follow-up to add a `WITH CHECK
  (role = 'member')`-style constraint (or a trigger) so only the ownership-
  transfer path (or an explicit invite flow) can grant `'owner'`.
- **Misleading comments, but RLS saves it from being worse than
  described**: `deleteAllLists()`'s comment says "nuclear option" /
  delete-everything, and the query (`.neq('id', <dummy-uuid>)`) reads as
  "delete all rows in the table" — but RLS's `DELETE` policy on
  `shopping_lists` (`owner_id = auth.uid()`) actually confines it to lists
  the caller owns. Still a zero-confirmation bulk-delete of everything a
  user owns, reachable by any authenticated user, with a class name
  (`AdminRepository`) implying a permission level the code never checks.
- **Provenance**: `git log --follow` traces the file to the same
  unrelated bulk commit (`65b615e`, "Add avocado loading screen and
  video_player dependency") that introduced `oauth_webview_dialog.dart`
  (flagged 2026-07-07) — another never-wired-in prototype from the same
  drop, not something added and later intentionally left as a dev tool.

Action taken this run: deleted `lib/data/repositories/admin_repository.dart`
and removed its stale mention from the `CLAUDE.md` architecture tree.
Unlike the `oauth_webview_dialog.dart`/`premium_feature_gate.dart` findings
(inert dead code, left for a human decision), this one combined dead code
with a real destructive RLS-adjacent exploit path, so deletion — the same
disposition already flagged as safe for the other two — was applied
directly rather than left as a recommendation. The separate `list_members`
`role` INSERT-policy gap is a live RLS issue independent of this file and
still needs a human/DBA decision; not changed here since it requires a
Supabase migration, not an app-code change.

## 2026-07-18 — `lib/presentation/screens/home/home_screen.dart`

Randomly selected file (1854 lines — the home tab screen). Read the whole
file plus its references: every widget it composes
(`GreetingHeader`, `AvoNudgeCard`, `CalorieRecipeNudgeCard`,
`PendingSplitsBanner`, `PriceComparisonNudgeCard`, `SplitTripNudgeCard`,
`_PaperListRow`, `_LatestActivityLine`), the providers it reads
(`listsNotifierProvider`, `lastAccessedListProvider`,
`recentHistoryProvider`, `currentUserProvider`), `DynamicTutorialService`,
`WidgetService.syncCredentialsFromSession`, `SupabaseService`, the
`app_router.dart` `StatefulShellRoute` wiring that hosts this screen, and
`git log --follow -p` / `git log -S` on the file to trace how its two
halves came to diverge.

Findings:
- **Dead code (~46% of the file)**: `_ShoppingHistorySection` (a
  `ConsumerStatefulWidget`) and everything it exclusively owned —
  `_ShoppingHistorySectionState`, `_HomeExpandedItemsContent`,
  `_HomeExpandedItemsContentState`, plus their private helpers
  (`_buildHistoryCard`, `_addAllItemsToList`, `_addSingleItem`,
  `_buildListCard`, `_formatDate`) — were never instantiated anywhere
  (`grep`-confirmed zero call sites, including within this file). 853 of
  the file's 1854 lines. `git log -S "_LatestActivityLine"` pinpoints the
  cause: commit `8e2d84e` ("feat: refresh app UI and add nearby offers")
  replaced the old expandable-history-cards section with the current
  one-line "Aktivitätszeile → full history screen" row
  (`_LatestActivityLine`, tap navigates to `ShoppingHistoryScreen`) but
  never deleted the superseded class it replaced — same pattern as the
  `oauth_webview_dialog.dart`/`premium_feature_gate.dart`/dead-engines
  findings from earlier runs, just larger (853 vs. ~250 lines).
- **Bug (live path, real leak)**: `initState()` subscribes to
  `SupabaseService.instance.client.auth.onAuthStateChange.listen(...)`
  without storing the `StreamSubscription`, and `dispose()` never
  cancelled it. `HomeScreen` lives inside a `StatefulShellRoute`
  (`app_router.dart`), whose branches normally stay alive for the app
  session — but sign-out redirects to the auth screens *outside* the
  shell and back in on sign-in, which disposes and recreates
  `HomeScreen`, registering a fresh listener each cycle with the old ones
  never freed. The `mounted` guard inside the callback prevents a
  post-dispose `setState` crash, but each stale closure (and the `State`
  object it closes over) is kept alive forever by the stream, so repeated
  sign-out/sign-in cycles accumulate permanently-leaked listeners.
- **Bilingual-UX bug (live path)**: the empty-lists state (`'Noch keine
  Listen erstellt'`) and the lists-loading-error state (`'Fehler beim
  Laden'`) were hardcoded German literals with no `context.tr(...)`, so
  English-locale users saw German text on a brand-new account or on a
  network error — same class of bug flagged in the
  `ml_recommendations_section.dart` review. Matching translation keys
  already existed and were unused (`no_lists_yet`, `loading_error`).
- No security issues (no auth/RLS logic in this file — it only reads
  `SupabaseService.instance.currentUser` for id comparison and delegates
  all list mutations to `listsNotifierProvider`).

Action taken this run: deleted the 853-line dead
`_ShoppingHistorySection`/`_HomeExpandedItemsContent` chain (and the
imports — `shopping_history.dart` model types, `items_provider.dart`,
`success_alert.dart` — that only that dead code used; the underlying
`ShoppingHistory` model, `SuccessAlert`, and `itemsNotifierProvider`
remain alive via their real callers elsewhere in the app, e.g.
`ShoppingHistoryScreen`/`avo_chat_screen.dart`). Fixed the
`StreamSubscription` leak by storing it in a field and cancelling it in
`dispose()`. Routed both hardcoded strings through `context.tr(...)` to
the existing `no_lists_yet`/`loading_error` keys. Verified brace/paren
balance and that every remaining import still has a live use site by hand
(`dart analyze`/`flutter build` aren't available in this remote
environment per CLAUDE.md — no Flutter SDK — so this run's verification
was static: full-file read, grep-confirmed zero remaining references to
the deleted symbols, and import-by-import usage check). Recommendation
for a future run/human: run `flutter build ios --simulator --debug` on
this file once a Flutter toolchain is available, as an extra check beyond
the static review done here.

## 2026-07-19 — `lib/presentation/providers/ml_recommendations_provider.dart`

Reviewed the file plus its references: `MLRecommendationService`
(`lib/data/services/ml_recommendation_service.dart`, whose service chain
— `ShoppingHistoryService`, `GeminiCategorizationService`,
`RecommendationCard` — was already covered in depth by the
2026-07-13 `ml_recommendations_section.dart` review, so not re-litigated
here), `itemsNotifierProvider`
(`lib/presentation/state/items_provider.dart`), and the one consumer,
`ml_recommendations_section.dart`.

Findings:
- **Correctness bug (live path)**: `MLRecommendationService.getRecommendations`
  uses `currentListItems` to build the `excludeItems` set that filters
  out items already on the list from suggestions
  (`ml_recommendation_service.dart:74-76`, consumed at line 513+ in
  `_calculateCategoryAffinityScore` and elsewhere). The provider's
  `currentItemsAsync.when(... loading: () => [], error: (_,__) => [])`
  fell back to an **empty** list whenever `itemsNotifierProvider` was
  still loading or had errored, meaning the exclusion set was empty at
  exactly the moment it mattered — right after opening a list, before its
  items had loaded. Because `mlRecommendationsProvider` is a
  `FutureProvider.autoDispose.family` that `ref.watch`es
  `itemsNotifierProvider(listId)`, this ran the *entire* (network- and
  Gemini-backed) recommendation pipeline once with the wrong empty
  exclusion set, then again from scratch once items resolved — so users
  could briefly see a recommendation for an item already sitting in their
  cart, sandwiched between two loading spinners in
  `ml_recommendations_section.dart`. An `AsyncError` from
  `itemsNotifierProvider` was silently swallowed the same way, with
  recommendations computed forever after as if the list were empty.
- **Dead code**: `mlRecommendationsLoadingProvider`
  (line 35, `StateProvider<bool>`) had zero readers/writers anywhere in
  the repo (`grep`-confirmed) — likely a leftover from before
  `mlRecommendationsProvider` became a `FutureProvider` (whose `AsyncValue`
  already carries loading state natively, making a parallel bool provider
  redundant even if it had been wired up).

Action taken this run: replaced the `.when` fallback with
`currentItemsAsync.valueOrNull` and an early `return []` when null, so the
service only ever runs once items have actually resolved — this also
fixes the wasted duplicate network/Gemini call, since the provider now
resolves instantly to `[]` instead of running the full pipeline during
the loading window. Deleted the unused `mlRecommendationsLoadingProvider`.
Verified via `grep` that nothing else in the repo references
`mlRecommendationsLoadingProvider`, that `itemsNotifierProvider`'s
declared type (`AsyncValue<List<ShoppingItemModel>>`) matches the new
`valueOrNull` usage, and that the `ShoppingItemModel` import stays live
(now referenced via the explicit local type annotation, since it's no
longer used inside `.when` branch literals). `flutter build`/`dart
analyze` aren't available in this remote environment (no Flutter SDK per
CLAUDE.md), so this run's verification was static only — recommend a
`dart analyze` + `flutter build ios --simulator --debug` pass once a
toolchain is available.
