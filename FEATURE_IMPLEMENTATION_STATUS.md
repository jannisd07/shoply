# Shoply Feature Implementation Status

_Last updated: 2026-07-02 (autonomous session)_

## Critical environment note (read first)

This session ran in a **Linux cloud container with no Flutter/Dart SDK and no
network access to install one** (outbound access is allow-listed to a small
set of domains — `flutter.dev`/GitHub SDK downloads are not reachable, and no
system package for Flutter exists). This was verified, not assumed:
`flutter`/`dart` are absent from `PATH`, no cached SDK exists anywhere on the
filesystem, and `git clone` of `flutter/flutter` was blocked by the network
policy (403).

**Consequence: `dart analyze`, `flutter test`, and `flutter build` could NOT
be run this session.** Every code change below was written by close reading
of the existing code (matching exact provider names, method signatures, and
column names verified live against the Supabase database) and a manual
brace/paren/bracket balance check across all touched files, but **none of it
has been compiler-verified**. Before merging, please run at minimum:

```bash
flutter pub get
dart analyze
flutter build ios --simulator --debug
```

and fix anything that surfaces. I've tried to keep changes additive and
pattern-matched to minimize risk, but this is not a substitute for the real
toolchain.

## Session context you should know

The Supabase project (`ShoplyAI`, `rtwzzerhgieyxsijemsd`) already had two
migrations applied this morning (`pricing_and_cost_splitting`,
`fix_shopping_history_rls_sharing`) that added price columns and the
`expense_splits` table — but **no corresponding Dart code existed anywhere**
and no migration file was committed. Likely an earlier session built the
backend for Features 1–2 and stopped before the Flutter side. This session
picked that up, wrote the missing migration file for version control, and
built the Dart integration on top of it. Similarly, commit `8e2d84e` (today)
added a substantial live-offers backend (`OfferPriceService`, `StoreOffer`,
`price_comparison_provider.dart`, `OfferSuggestionsBar`) for Feature 1 that
was **never wired into any screen** — this session wired it up.

---

## Status overview

| # | Feature | Completion | Status | Blockers |
|---|---|---|---|---|
| 1 | Pricing, offers, cheapest store | ~65% | In progress | Regular (non-offer) shelf prices have no public API — offers-only by design |
| 2 | Split shopping trip costs | ~85% | Implemented (needs QA) | None functional; needs compiler verification |
| 3 | Widgets & quick actions | ~55% | In progress | Root cause fixed; needs a real Xcode/device build to confirm |
| 4 | AI assistant app control | ~70% | Implemented (needs QA) | None functional; needs compiler verification |
| 5 | Avo mascot & smart notifications | ~20% | Not started (this session) | Large scope; see plan below |
| 6 | Calorie tracking | 0% | Not started | Large greenfield feature; see plan below |
| 7 | Personalized onboarding & navbar | ~15% | Not started (this session) | Depends on Feature 6 decisions |
| 8 | Cross-feature UX / growth / premium | ~10% | Not started (this session) | Depends on 1–7 |

---

## Feature 1 — Product search, pricing, cheapest supermarket, offers

**Before this session:** Two parallel, fully disconnected implementations
existed:
- A real, working **marktguru.de** (unofficial API) offer-search pipeline
  (`OfferPriceService`, `StoreOffer`, `UserLocationService`,
  `price_comparison_provider.dart`, `OfferSuggestionsBar`) — built in commit
  `8e2d84e` today, but with **zero call sites** outside its own files.
  `BasketComparison.bestStore` already implemented "cheapest store" logic.
- A dead OCR/flyer-scan pipeline (`ExtractedDeal`, `DealExtractorService`,
  `DealsDatabaseService`, `ProductMatchingService`, `DealBadge`) with no data
  ingestion path at all — nothing ever calls the extractor, so its local
  SQLite table is permanently empty. Left as-is (out of scope to revive; the
  marktguru pipeline is the better foundation and is what "real" offer data
  in this app looks like today).
- `ShoppingItemModel`/`ShoppingListModel` had no price fields in Dart, but
  the live DB already had `shopping_items.price/price_currency/
  price_retailer/price_unit/price_updated_at` from this morning's migration.

**What I implemented:**
- Added price fields (`price`, `priceCurrency`, `priceRetailer`, `priceUnit`,
  `priceUpdatedAt`, `hasPrice`) to `ShoppingItemModel`
  (`lib/data/models/shopping_item_model.dart`).
- Extended `ItemRepository.addItem()` and `ItemsNotifier.addItem()` with
  optional price parameters, applied on both the insert path and the
  existing-item merge path.
- Wired `OfferSuggestionsBar` into the list detail screen's add-item bar
  (`list_detail_screen.dart`) — typing 2+ characters now shows the top 3
  live offers above the add bar; tapping one adds the real product with its
  price/retailer/unit attached (`_addItemFromOffer`).
- Added a per-item price label under the item name in the list row.
- Built `ListPriceSummaryBar` (new file) — shows the running known total for
  unchecked items and a "cheapest at X" chip when `basketComparisonProvider`
  has data; tapping it opens a full per-store comparison sheet (ranked by
  matched-item count, tie-broken by lowest total — this was already
  implemented in `BasketComparison.bestStore`, just never surfaced).
- `ShoppingHistoryService.completeShoppingTrip()` now carries item
  price/retailer into `shopping_history_items` and seeds
  `shopping_history.total_cost` from known prices, so completed trips feed
  straight into Feature 2's cost splitting.
- Added an Avo AI tool, `search_offers` (Feature 4).

**Explicitly NOT done (documented, not faked):**
- Regular (non-promotional) shelf prices — no public API exists for German
  supermarkets; this is a hard external constraint, not a shortcut. The
  offer coverage is honestly partial (only currently-running Angebote), and
  the UI/AI copy says so ("offer prices only").
- Smart substitutions ("this alternative saves you X") — not implemented.
- Price confidence labels — not implemented (the underlying data source
  doesn't provide staleness/confidence signals beyond `validFrom`/`validTo`,
  which is already used to filter to `isValidNow`).
- "Closest reasonable option" using real distance — `UserLocationService`
  only resolves a zip code (for the offers API's regional filter), not
  actual store distances/addresses. A real "near me" store list would need a
  store-locator API, which isn't wired up.
- The dead OCR/flyer pipeline was left alone rather than revived or deleted
  — deleting ~1,500 lines of working-but-unused code felt outside this
  session's risk budget without being asked; flagged as an idea below.

**Files changed:** `lib/data/models/shopping_item_model.dart`,
`lib/data/repositories/item_repository.dart`,
`lib/presentation/state/items_provider.dart`,
`lib/presentation/screens/lists/list_detail_screen.dart`,
`lib/presentation/screens/lists/widgets/list_price_summary_bar.dart` (new),
`lib/data/services/shopping_history_service.dart`,
`lib/core/localization/app_translations.dart`,
`supabase/migrations/20260702055031_pricing_and_cost_splitting.sql` (new —
documents already-applied live schema).

**Checks performed:** Manual trace of every call site against the live
Supabase schema (columns verified via MCP `list_tables`); brace/paren
balance check. **Not run:** `dart analyze`, build, or a real device/simulator
test of the add-item-from-offer flow. Please verify search debouncing feels
right in practice — there's no explicit debounce on the `ValueListenableBuilder`
beyond Riverpod's `FutureProvider.autoDispose.family` caching per exact
query string, which may fire a network call per keystroke on a fast typer.
Consider adding a 300ms debounce if that turns out to be an issue.

---

## Feature 2 — Split shopping trip costs

**Before this session:** Completely greenfield in Dart (confirmed via
full-repo grep for split/owe/debt/settle — zero hits outside subscription
"payment" terminology). However, the DB schema was already live: `expense_splits`
table (with correct, tested-looking RLS policies) and
`shopping_history.total_cost/paid_by_user_id/paid_by_name` columns, added by
an untracked migration this morning. `shopping_history`/`shopping_history_items`
schemas themselves also turned out to not be tracked in any migration file
in the repo (pre-existing gap, not introduced by this session).

**What I implemented:**
- `ExpenseSplit` model + `TripSplitSummary` convenience wrapper
  (`lib/data/models/expense_split.dart`).
- `ExpenseSplitService` (`lib/data/services/expense_split_service.dart`):
  create/replace splits for a trip, fetch splits for a trip, toggle
  paid/unpaid, and two home-banner queries — trips the user paid for that
  still have unpaid participants, and trips where the user themselves still
  owes someone else.
- Riverpod providers (`lib/presentation/state/expense_split_provider.dart`).
- `SplitCostSheet` (new bottom sheet,
  `lib/presentation/screens/history/widgets/split_cost_sheet.dart`): pick a
  total cost, pick participants from the list's real members (via
  `ListRepository.getListMembers`) or add a name-only person, toggle
  equal/custom split, save. Re-splitting a trip overwrites its previous
  splits (simple, avoids partial-state bugs).
- Wired into `ShoppingHistoryScreen`: expanding a trip shows either a "Split
  cost" action (unsplit trips) or the live per-person paid/unpaid status
  with a one-tap paid toggle (split trips).
- `PendingSplitsBanner` (new, `lib/presentation/screens/home/widgets/`) on
  the home screen: shows "X owes you €Y" (with a one-tap "mark as paid" for
  single-participant cases) and "You owe €Y to X" rows; renders nothing once
  everything is settled (no permanent home-screen clutter). Tapping any row
  opens the history screen.
- Added Avo AI tool `split_trip_cost` (Feature 4) — "split yesterday's Lidl
  trip with Max and Jonas" resolves via `get_shopping_history` →
  `split_trip_cost`.

**Design decisions:**
- Equal split and custom split are both supported (checkbox per participant
  + editable amount field, live "assigned vs total" reconciliation line).
- "I paid for everything" is implicit: `paid_by_user_id`/`paid_by_name`
  defaults to whoever opens the split sheet (normally the person who just
  completed the trip) — there's no separate "who paid" picker UI yet; see
  idea below if you want to let a different member be marked as payer.
- Partially-paid trips: each participant's paid/unpaid status is independent
  and persisted per-row, so a 3-person split can be 1/3 paid without losing
  state — this was a specific ask and is handled naturally by the
  per-`expense_splits`-row model rather than a single trip-level flag.

**Explicitly NOT done:**
- Copyable/shareable "reminder" payment messages — I added translation keys
  for it (`copy_reminder`, `reminder_copied`) anticipating this, but didn't
  wire the actual clipboard action; small follow-up.
- No push notification when someone marks a split paid/unpaid (would need a
  Supabase trigger or a client-side call to `PushNotificationService` on
  `setPaid()` — straightforward follow-up, flagged as an idea below).

**Files changed:** `lib/data/models/expense_split.dart` (new),
`lib/data/models/shopping_history.dart` (added cost/paid fields),
`lib/data/services/expense_split_service.dart` (new),
`lib/presentation/state/expense_split_provider.dart` (new),
`lib/presentation/screens/history/widgets/split_cost_sheet.dart` (new),
`lib/presentation/screens/history/shopping_history_screen.dart`,
`lib/presentation/screens/home/widgets/pending_splits_banner.dart` (new),
`lib/presentation/screens/home/home_screen.dart`,
`lib/core/localization/app_translations.dart`,
`supabase/migrations/20260702055031_pricing_and_cost_splitting.sql` (new).

**Checks performed:** Verified `expense_splits` RLS policies live via
Supabase MCP (SELECT/INSERT/UPDATE/DELETE all correctly scoped to trip
owner, list members, or the participant themselves). Verified the
`shopping_history` → `expense_splits` embedded-select syntax matches the
existing `shopping_history_items` embed pattern already used in the
codebase. Brace/paren balance check on all files. **Not run:** `dart
analyze`, build, or a real end-to-end split/pay flow on device.

---

## Feature 3 — Widgets and quick actions

**Root cause found and fixed.** This was a real, well-defined regression,
not a from-scratch misconfiguration:

- The widget extension target (`ShoppingListWidgetExtension`) code-signs
  with `ios/ShoppingListWidgetExtension.entitlements`. As of commit `767f4f6`
  (2026-04-11, a "backup all current changes" commit), that file's App Group
  entry was silently stripped down to an empty `<dict/>` — likely an
  accidental Xcode Signing & Capabilities re-sync bundled into an unrelated
  mixed commit. It had App Groups correctly set when the widget was first
  added in commit `adc9d57` (2026-03-28).
- Because of that, the widget process has never been able to read the
  `group.com.shoply.app` shared container the main app writes to via
  `WidgetService`/`AppDelegate.swift` — so it always rendered
  empty/placeholder state and interactive checkbox toggles silently failed
  to sync, exactly matching "broken for a long time."
- A second, correctly-configured entitlements file
  (`ios/ShoppingListWidget/ShoppingListWidget.entitlements`) exists in the
  repo but isn't referenced anywhere in the Xcode project — a trap for
  anyone assuming the widget was configured by looking at that file.

**What I fixed:**
- Restored the `com.apple.security.application-groups` entry
  (`group.com.shoply.app`, `group.com.dominik.shoply`) to
  `ios/ShoppingListWidgetExtension.entitlements` — the file actually used
  for code-signing, matching `Runner.entitlements` exactly.
- Fixed the stale `CLAUDE.md` doc reference (`ios/ShoplyWidget/` →
  `ios/ShoppingListWidget/`, plus a note about the orphaned duplicate
  entitlements file) so this doesn't trip up the next person searching for
  it.

**Explicitly NOT done / needs a real device:**
- This fix **cannot be verified without Xcode** — I have no macOS/Xcode
  access in this container. Please rebuild, re-add the widget on a simulator
  or device, and confirm it now populates and checkbox taps sync back to
  Supabase.
- Two pre-existing, non-blocking issues noted but left alone (small,
  separate from the entitlement bug, and touching them without build
  verification felt riskier than the value):
  - `AppDelegate.swift`'s `getPendingToggles`/`clearPendingToggles`
    "pending toggles" pull-sync path is dead — the current widget code
    syncs toggles directly to Supabase instead
    (`ToggleItemIntent.syncToggleToSupabase`) and never writes to the
    `widget_pending_toggles` key that path reads. Not harmful, just vestigial
    from an earlier architecture.
  - `AppDelegate`/`WidgetService` have full plumbing for a `SavedRecipesWidget`
    (`reloadTimelines(ofKind: "SavedRecipesWidget")`) but no such WidgetKit
    widget exists in `ios/ShoppingListWidget/` — unfinished, not a
    regression.
  - The widget target's `IPHONEOS_DEPLOYMENT_TARGET = 26.0` vs. Runner's
    `15.6`/`13.0` is unusually high and worth double-checking against your
    actual target device/simulator OS versions.
- "Today's list" widget, "recently used items" widget, "Avo suggestion"
  widget — not built. The existing `ShoppingListWidget.swift` already
  supports per-widget list selection (`SelectListIntent`) which covers "my
  chosen list" reasonably well; a distinct "today's list" concept would need
  a definition of what "today's list" means (last-accessed? soonest planned
  trip?) — flagged as an idea below rather than guessed at.

**Files changed:** `ios/ShoppingListWidgetExtension.entitlements`, `CLAUDE.md`.

**Checks performed:** Read-diffed against `Runner.entitlements` for exact
App Group string match; confirmed via `git show` history that this exact
content existed before the regression commit. **Not run (cannot be, in this
environment):** an actual Xcode build/signing/widget-on-device test. This is
the single most important item to verify manually before considering
Feature 3 done — the diagnosis is high-confidence but unverified in
practice.

---

## Feature 4 — AI assistant app control

**Before this session:** Already substantially real — not a stub. Avo uses
genuine Gemini function-calling (typed `Tool`/`FunctionDeclaration` schemas,
not prompt+regex parsing) with 13 tools covering recipes, nutrition
estimation, shopping history, list contents, adding items, checking
items/completing lists, re-adding history items, and settings changes.
Multi-turn tool-calling loop (bounded to 4 turns), rich card payloads per
tool. Gaps found: no delete capability of any kind (add-only), no
confirmation pattern for destructive actions (none existed to confirm), and
no memory persistence across sessions (context is live app-state re-injected
each turn, not assistant-owned memory).

**What I implemented (additive, same architecture/patterns):**
- `search_offers` tool — live offer search via `OfferPriceService` +
  `UserLocationService`, returns top 5 offers + cheapest store; gracefully
  reports "no location set" instead of guessing when the zip code is
  unavailable.
- `split_trip_cost` tool — resolves a trip via `history_id` (system prompt
  instructs Gemini to call `get_shopping_history` first to resolve a
  natural-language hint like "yesterday's Lidl trip"), splits equally
  between the current user + named participants, requires a known total
  (asks the user if the trip has none saved).
- `delete_item` / `delete_list` tools with a genuine two-step confirmation
  flow: the first call **never deletes anything** — it returns
  `requires_confirmation: true` + a question string that the system prompt
  instructs Gemini to relay verbatim and wait on. Only a second call with
  `confirm: true` (after the user's explicit yes) performs the deletion.
  This reuses the existing text-turn loop rather than adding new chat-UI
  widget plumbing, keeping the change low-risk.
- Updated the system prompt with routing rules for all four new tools.

**Explicitly NOT done:**
- Assistant-owned memory/preferences across sessions — architecturally this
  would mean persisting a summary or key facts to Supabase and re-injecting
  them, similar to how diet/allergies already work; not implemented this
  session (flagged as an idea below — it's a real design decision, not just
  an engineering task).
- Calorie-tracking tools — blocked on Feature 6 not existing yet.
- Onboarding-guidance tools — blocked on Feature 7 not being rebuilt yet.
- No new rich-card UI for offers/splits results in the chat itself (Avo
  answers in text, e.g. "Milk is cheapest at Aldi for €0.89") rather than a
  new widget payload kind — deliberate scope cut to avoid touching the
  1000+ line `avo_chat_screen.dart` UI file without compiler verification.
  The underlying split/offer actions still use the real services, so this
  is a presentation limitation, not a fake integration.

**Files changed:** `lib/data/services/avo_assistant_service.dart`.

**Checks performed:** Verified every new tool's argument names line up with
its `Schema.object` declaration; verified `deleteItem`/`deleteList` notifier
method signatures against `items_provider.dart`/`lists_provider.dart`
exactly. Brace/paren balance check. **Not run:** a live Gemini conversation
test (needs `dart run`/simulator + a real Gemini API key in `env.dart`,
neither available here).

---

## Feature 5 — Avo as real assistant and mascot

**Not implemented this session** — audited in depth, not touched, because
the honest scope here is a consolidation project, not a quick addition, and
I'd rather flag it precisely than rush a shallow pass:

- There are **two parallel, fully dead mascot/gamification systems**
  (`lib/core/gamification/` — `GamificationService`, `HomeGreetingWidget`,
  `ShoplySprout` — and a second streak counter inside
  `MascotNotificationService`) that are never imported by any screen, and
  the streak counter that *is* reachable is never actually incremented
  anywhere.
- **Three disconnected notification-preference concepts** exist
  (`users.notification_preferences` — documented, never read/written;
  `users.notification_enabled` — chatbot-settable, never enforced; 7
  SharedPreferences toggles in the Settings screen — UI-only, gate nothing).
  None of them currently prevent a notification from firing.
- Real, populated data already exists to build real nudges on:
  `item_purchase_stats.average_days_between` is computed and stored after
  every completed trip (`PurchaseTrackingService`), and
  `MLRecommendationService` already produces "usually buy every X days" /
  "overdue" reasoning strings for in-app recommendation cards — but none of
  this feeds any notification today.
- Most local-notification helper methods
  (`notifyListUpdate`/`notifyItemToggled`/etc.) are defined and never called.
  FCM push works for cross-user events (list joins, recipe ratings/comments)
  but achievement-unlock and recipe-of-the-day pushes are stubbed/never
  triggered.

**Recommended approach for a follow-up session** (not started): (1) delete
or consolidate the dead `core/gamification/` module into
`MascotNotificationService` rather than running two systems; (2) make
`users.notification_enabled` (already chatbot-settable) the single real gate
and wire it into `NotificationService`/`MascotNotificationService`; (3) add
one new behavioral trigger using the *already-computed*
`item_purchase_stats.average_days_between` — "you usually buy milk every 5
days, it's not on your list" — since the hard part (the data pipeline)
already exists and is populated.

---

## Feature 6 — Complete calorie tracking

**Not implemented this session — 0%, confirmed genuinely greenfield.**
Full-repo search found only recipe-level, display-only nutrition (`Recipe.nutrition`
JSONB + a Gemini one-shot estimator already exposed via Avo's
`get_recipe_nutrition` tool) and diet-tag/allergen data (`DietType`,
`AllergyType` — unrelated to calorie counting). No food diary, meal log,
weight log, water log, barcode scanner (package commented out), or nutrition
API integration exists anywhere, in Dart or in the database. Two dead-code
duplicate `NutritionInfo`/`RecipeNutrition` classes and an unused
`recipe_nutrition` SQL table were found as a side effect — worth a cleanup
pass separately.

**Why I didn't attempt it this session:** This is the single largest item in
the whole request — a full dashboard, food search/database, barcode
scanning, AI photo tracking, goal calculation, meal-by-day tracking,
weight/water tracking, progress graphs, and challenge modes is realistically
a multi-week feature on its own, and building a database schema + ~15-20 new
screens with zero compiler verification available in this environment would
be irresponsible — a single typo could produce a large volume of
unverifiable, potentially broken code. I'd rather hand you a clean plan than
a pile of unverified files.

**Suggested phased plan for a follow-up (with build verification available):**
1. Schema: `user_nutrition_goals` (goal type, target calories/macros, target
   weight, activity level), `food_log_entries` (day, meal, food, calories,
   macros, source: manual/recipe/barcode/photo), `weight_log`, `water_log`.
2. Goal calculator (Mifflin-St Jeor or similar) from onboarding inputs —
   ties directly into Feature 7.
3. Manual entry + "log from recipe" (the recipe nutrition data already
   exists — this is the cheapest first slice with real payoff).
4. Dashboard (today's totals vs. goal, ring/bar visualization).
5. Barcode scanning (re-enable `mobile_scanner`, or an Open Food Facts
   lookup) and AI photo tracking (Gemini vision) — external-data-dependent,
   should come after the core logging loop works.
6. Weight/water tracking + progress graphs.
7. Challenges (16:8, 30-day no sugar) as a lightweight layer on top of the
   logging data once it exists.

---

## Feature 7 — Personalized onboarding and navbar

**Not implemented this session.** Audited: the current "onboarding" is a
3-page static marketing carousel gated by a **device-local** SharedPreferences
flag (not account-scoped — reinstalling re-triggers it even for existing
users). The DB `onboarding_completed` column is fetched and cached but
**never actually used to branch the router redirect** — it's dead weight. A
second, unreachable `UnifiedSetupScreen` (`/setup` route) duplicates
display-name capture and is dead code. Real personalization fields already
exist on `UserModel` (age, height, gender, diet, allergies) but are only
ever collected later, from Profile settings — not during onboarding.

**Why not implemented:** This depends on Feature 6's decisions (what goal
questions to ask, what fields the goal calculator needs) — building the
onboarding flow before the calorie-tracking data model would mean guessing
at field names and likely reworking it. Recommend sequencing Feature 7 right
after Feature 6's schema (step 1 above) is settled.

**What a follow-up should do:** Replace the static carousel with a short
question flow ("what do you want from Shoply?" → feature toggles, calorie
tracking opt-in with goal follow-ups only if opted in), make
`onboarding_completed` actually gate the router redirect (it already almost
does — the field is fetched, just not branched on), and make the navbar
tab list data-driven (currently 5 hardcoded icons in `MainScaffold`) so a
calorie tab can be conditionally shown/hidden per user preference rather
than hardcoded.

---

## Feature 8 — Cross-feature UX, growth, premium, retention

**Not implemented this session** — correctly sequenced last since it
composes Features 1–7. Audited the current premium/growth surface:

- The only **functionally enforced** premium gate in the entire app is the
  recipe cooking-mode button. Everything else marketed as a premium perk on
  the paywall screen (unlimited lists, deals, statistics) has **no code
  enforcement anywhere** — worth knowing before promising more paywalls; the
  gap between marketing copy and actual gating already existed before this
  session.
- A fully-built, generic premium-gating widget system
  (`PremiumFeatureGate`/`GoProButton`/`PremiumLockedOverlay`) exists and is
  never imported anywhere — ready-made infra for future gates.
- Four separate, largely redundant recommendation engines exist; only one
  (`MLRecommendationService`) is actually live in the UI (inside the list
  detail screen only, not on the home screen). One of the dead ones
  (`RecommendationService`) already has a `dealBonus` scoring hook wired to
  `ProductMatchingService` — precedent for a price-aware recommendation,
  just on a currently-unused code path.
- The home screen's "Angebote" strip is decorative/non-tappable — a
  pre-existing dead end, not something this session touched, but relevant
  context: the new `PendingSplitsBanner` and any future price/offer
  cross-feature card should follow the pattern of the (functional) Avo hint
  strip above it, not the (non-functional) Angebote strip.

**Recommended first cross-feature wins** (not started, listed for
prioritization): a home-screen card surfacing "€X cheaper at [store] this
week" using the now-wired `basketComparisonProvider` (Feature 1 infra);
"you usually buy milk every 5 days" using the already-populated
`item_purchase_stats` (Feature 5's recommended first nudge); once Feature 6
exists, "N calories left — 3 dinner ideas from your list."

---

## Ideas / Needs My Approval

- [ ] IDEA: Delete the dead OCR/flyer-deal pipeline (`ExtractedDeal`,
  `DealExtractorService`, `DealsDatabaseService`, `ProductMatchingService`,
  `DealBadge`, `ShoppingItemGridCard`, `OffersScreen`,
  `SupermarktFinderPage`'s hardcoded demo data, `StoreFlyerService`'s
  fake-scrape-then-demo-data fallback) now that the marktguru pipeline is
  the real, wired-up offer source.
  - Why it helps: removes ~1,500 lines of code that can never do anything
    (nothing feeds it data) and that could confuse future contributors into
    building on the wrong foundation.
  - Expected user value: none directly (it's invisible today).
  - Expected business/premium value: none directly; reduces maintenance risk.
  - Complexity: Low (deletion + removing the now-empty `deals/` widget dir).
  - Risk: Low — confirmed zero live call sites — but I didn't want to delete
    a chunk of code I didn't write without asking first.
  - Recommendation: yes.

- [ ] IDEA: Consolidate the two dead mascot/gamification systems
  (`core/gamification/` and `MascotNotificationService`'s streak logic) into
  one, and make `users.notification_enabled` the single enforced
  notification gate.
  - Why it helps: right now there are 2 mascot personality systems and 3
    notification-preference flags, none of which fully work together.
  - Expected user value: a Settings toggle that actually does something,
    and one consistent Avo voice instead of two unused parallel ones.
  - Expected business/premium value: retention — this is the foundation
    Feature 5 needs to build real nudges on.
  - Complexity: Medium.
  - Risk: Low-medium (touches notification-sending code paths — should be
    tested with real device pushes).
  - Recommendation: yes, as the first step of Feature 5.

- [ ] IDEA: Let the split-cost sheet pick a different "who paid" person
  instead of always defaulting to whoever opens the sheet.
  - Why it helps: "I paid for everything" is common but so is "someone else
    fronted the money and I'm splitting it after the fact."
  - Expected user value: medium — avoids a workaround of re-opening the
    sheet as the payer's account.
  - Expected business/premium value: none.
  - Complexity: Low (add a picker to `SplitCostSheet`, service already
    supports arbitrary `paidByUserId`/`paidByName`).
  - Risk: Low.
  - Recommendation: yes, small follow-up.

- [ ] IDEA: Push notification when a split is marked paid/unpaid.
  - Why it helps: closes the loop without requiring someone to reopen the app.
  - Expected user value: medium.
  - Expected business/premium value: low-medium (retention nudge).
  - Complexity: Low (call the existing `PushNotificationService` from
    `ExpenseSplitService.setPaid()`).
  - Risk: Low.
  - Recommendation: yes.

- [ ] IDEA: Build calorie tracking (Feature 6) as its own dedicated
  multi-session effort with build verification available, following the
  phased plan above, rather than attempting it piecemeal.
  - Why it helps: avoids shipping a half-working, unverified nutrition
    feature that touches user health data.
  - Expected user value: high (explicitly requested, large feature area).
  - Expected business/premium value: high (Lifesum-style tracking is a
    strong premium upsell surface per the original brief).
  - Complexity: High.
  - Risk: Medium if rushed without verification; low if properly scoped.
  - Recommendation: needs decision — specifically, please confirm the goal
    calculation formula/source you want (e.g. Mifflin-St Jeor) and whether
    barcode scanning should re-enable `mobile_scanner` or use a lighter
    camera+Gemini-vision approach, before a follow-up session starts on it.

- [ ] IDEA: Rebuild onboarding (Feature 7) immediately after Feature 6's
  schema is settled, replacing the static carousel with the adaptive flow
  and making `onboarding_completed` actually gate the router.
  - Why it helps: currently onboarding collects nothing and doesn't even
    functionally gate anything — it's pure UI theater today.
  - Expected user value: high — this is the entry point for the app feeling
    personalized at all.
  - Expected business/premium value: medium (better activation funnel).
  - Complexity: Medium.
  - Risk: Medium — touches auth/router redirect logic, needs careful testing
    against existing users who already have `onboarding_completed=false`
    in the DB from the current (inert) field.
  - Recommendation: yes, sequenced after Feature 6.
