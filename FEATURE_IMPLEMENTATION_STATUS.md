# Shoply Feature Implementation Status

_Last updated: 2026-07-04 (scheduled routine — Feature 2 focus: QA pass + approved ideas)_

## Environment note (read first)

Unlike the prior two sessions, **this session had a working Flutter/Dart
toolchain**: outbound network access allowed `git clone` of `flutter/flutter`
(stable channel), so the SDK was fetched locally into `/tmp/flutter-sdk` and
used to run real verification — `flutter pub get` and `dart analyze` both ran
successfully against the full `lib/` tree. `flutter build ios` still cannot
run here (no macOS/Xcode in this Linux container — that's a hard platform
limitation, not a policy/network one), and `flutter test` fails on an
unrelated pre-existing issue (see Checks section of Feature 1 below), but
`dart analyze` gave real, full-project compiler feedback for every change in
this session, which the previous two sessions could not get. Baseline
(before this session's changes, confirmed by re-running analyze against the
prior commit): 2 errors (both from the gitignored `firebase_options.dart`,
expected in this environment) and 67 warnings, all pre-existing. After this
session's changes: still 2 errors (same expected cause), and 61 warnings —
net *fewer* than baseline (dead-code deletion removed some), **zero new
errors or warnings introduced**.

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
| 1 | Pricing, offers, cheapest store | ~90% | In progress (this session) | Regular (non-offer) shelf prices have no public API — offers-only by design |
| 2 | Split shopping trip costs | ~95% | Implemented (needs device QA) | None functional; push + widget rendering need a real device run |
| 3 | Widgets & quick actions | ~55% | In progress | Root cause fixed; needs a real Xcode/device build to confirm |
| 4 | AI assistant app control | ~70% | Implemented (needs QA) | None functional; needs a real device run |
| 5 | Avo mascot & smart notifications | ~20% | Not started | Large scope; see plan below |
| 6 | Calorie tracking | 0% | Not started | Large greenfield feature; see plan below |
| 7 | Personalized onboarding & navbar | ~30% | In progress | Goal questionnaire depends on Feature 6 |
| 8 | Cross-feature UX / growth / premium | ~10% | Not started | Depends on 1–7 |

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

**This session (2026-07-03) picked up from that baseline and did a QA +
gap-closing pass**, since the prior session's own audit already flagged the
fast-typer debounce risk and several unimplemented autonomy items. What
changed:

- **Debounced live offer search.** The add-bar search was previously fed
  straight from `_searchController` into `OfferSuggestionsBar` on every
  keystroke — since each distinct string is a separate
  `FutureProvider.autoDispose.family` instance, a fast typer really was
  firing one marktguru API call per character. Added a 300ms debounce
  (`_offerQuery` `ValueNotifier` + `Timer` in `list_detail_screen.dart`);
  clearing the field still updates instantly (no lag on dismiss).
- **Fixed a real correctness bug in `_addItemFromOffer`:** adding a picked
  offer called `ItemRepository.addItem()` with `quantity: 1.0, unit: null`,
  which is exactly the condition that triggers the *Gemini ingredient-parse*
  pass (meant for free-text entries like "2 cups flour") — so a real,
  branded product name/price from a live offer could get silently rewritten
  by the AI parser, and burned an extra Gemini call for data that was
  already exact. Added an `autoParse` flag (default `true`, preserving all
  existing call sites) threaded through `ItemRepository.addItem()` →
  `ItemsNotifier.addItem()`, and the offer-add path now passes
  `autoParse: false` to keep the product name/price exactly as returned by
  the offer.
- **Manual zip-code fallback** — `UserLocationService` already supported a
  manual PLZ override, but there was **no UI anywhere** to set one. Any user
  who denies location permission (or is on a platform without GPS) got
  pricing silently and permanently disabled with zero explanation. Added:
  - `zip_code_sheet.dart` (new) — a bottom sheet to set the zip code,
    reusable from anywhere.
  - A nudge card in `OfferSuggestionsBar` ("Add your zip code to see nearby
    offers") that appears exactly where the dead-end was — while
    searching, once we know the zip resolved to nothing (not just "still
    loading").
  - A permanent "Zip code (for local offers)" field on the Personal Info
    settings screen, so it can be set or changed anytime, not just from the
    nudge.
- **Savings signal ("smart substitutions").** A real product-substitute
  graph doesn't exist (marktguru returns offers per literal search query,
  not a mapped "cheaper alternative" relation), so building one honestly
  would mean guessing at product equivalence — risky for a diet/allergy-aware
  app. Instead, implemented the safe version of the same idea: the search
  results for one query already span multiple brands/retailers at different
  prices; when the spread between the cheapest and priciest match for that
  query is ≥ €0.20, the suggestion card now shows "Save up to €X" next to
  the top (cheapest) result — using data already fetched, no extra network
  cost (`offerSearchAllProvider`, new, feeds both the top-3 list and this
  stat from one shared request).
- **Freshness/confidence tag.** Each offer row now shows "Offer ends today" /
  "Offer ends in Xd" when its `validTo` is within 3 days — a lightweight,
  honest confidence signal from data that already exists (no fake
  confidence score invented).
- **Removed the genuinely dead OCR/flyer pipeline — with a correction to the
  prior session's audit.** Verified reachability of every symbol before
  deleting anything (grepped for constructors, providers, and routes, not
  just class names). Deleted (zero live references, confirmed):
  `DealExtractorService`, `StoreFlyerService`, `TesseractSetup` (OCR helper
  for a package that's commented out in `pubspec.yaml` — never had a real
  backend), `StoreFlyerModel`, `ShoppingItemWithDeal`, `flyers_provider.dart`
  (all 3 of its providers had 0 external watchers), `OffersScreen`,
  `SupermarktFinderPage`, `FlyerViewerScreen` (none reachable from
  `app_router.dart` or any navigation call site), `FlyerCard`, `DealBadge`,
  `ShoppingItemGridCard`. **Correction:** the prior session's write-up
  described `ProductMatchingService`/`DealsDatabaseService`/`ExtractedDeal`
  as part of the dead pipeline with "a `dealBonus` scoring hook... on a
  currently-unused code path." That's not accurate — `RecommendationService`
  (which calls `ProductMatchingService.findBestDealForProduct`) **is** live,
  reachable from `list_detail_screen.dart` via `RecommendationsSection`. So
  those three files were **kept**, not deleted. In practice the `dealBonus`
  they compute is always zero today, because the only writer to
  `DealsDatabaseService`'s local deals table was the extractor that's now
  removed (it was already permanently empty before this session — deleting
  it doesn't change behavior, just removes an always-inert write path).
  Whether to also strip that now-fully-inert `dealBonus` hook from
  `RecommendationService` is flagged as a new idea below rather than done
  here, since it touches the (separate, Feature 8-ish) recommendations
  engine, not pricing/offers directly.

**Second session, 2026-07-03 (scheduled routine).** Started by reconciling
two divergent lines of Feature-1 work: your own `ac54af5` on `main`
(comparable-basket totals, German-placemark zip fix, food filter, relevance
sort + generic-term search fallback, single-line summary bar) and the
morning routine session's `d7afe2f` on `claude/daily` (debounce, offer-add
fidelity/`autoParse`, manual-zip UX, dead-code deletion) had **no common
descendant** — each was missing the other's fixes. Merged `main` into
`claude/daily`, resolving three conflicting files so both sides' behavior
survives:
- `price_comparison_provider.dart`: kept your `effectiveZipProvider`
  (nationwide fallback zip) and rebased the shared `offerSearchAllProvider`
  on it; one `offerSuggestionsProvider` with your relevance sort + the
  distinct-retailer top-3.
- `list_detail_screen.dart`: your either/or logic (offer suggestions XOR
  summary bar, never stacked, keyed off the live text) now feeds the
  suggestions from the debounced query, so fast typing still doesn't fire an
  API call per keystroke.
- `app_translations.dart`: union of both sides' new keys.

Then closed the gaps that were still open, in order of user value:
- **Per-item smart substitutions (the "cheaper alternative saves you €X"
  ask).** New `BasketComparison.cheapestOfferFor(itemName)` exposes the
  per-item cheapest offer the basket comparison already fetches (zero extra
  API traffic). Every unchecked list row now shows a small accent chip:
  "Spare €X bei [Store]" when the item's saved price beats a live offer by
  ≥ €0.10, or "€X · [Store]" when the item has no price yet. Tapping opens a
  new offer sheet (`item_offer_sheet.dart`) — product image, brand, store,
  unit, price, regular-price/discount, validity — with one "Preis
  übernehmen" action that persists price/retailer/unit onto the item via
  the existing `ItemsNotifier.updateItem`. After applying, the chip
  disappears on its own (the saved price now matches the offer).
- **Whole-list estimated total.** The store-comparison sheet now shows
  "Ganze Liste, geschätzt (Y/Z Artikel) ≈ €X": each open item counts its own
  saved price if set, else the cheapest current offer, and the coverage
  fraction is shown so the estimate is honest about what it excludes.
- **Quantity-pricing bugfix.** `knownTotal` multiplied price × quantity
  unconditionally, so "500 g Hackfleisch" with a €2.99 offer price would
  have contributed €1,495 to the total. New
  `ShoppingItemModel.pricingQuantity` multiplies only piece-like quantities
  (no unit / Stk / x / pcs, 1–50) and counts measured quantities once; used
  by both the summary-bar total and the new estimate.
- **Zip-gating consistency fix.** `OfferSuggestionsBar` blocked all
  suggestions behind the zip nudge even though your `effectiveZipProvider`
  fallback makes nationwide search work without one. Now it shows the
  fallback results with a compact "set your zip for local prices" footer
  inside the card; the full nudge card only appears when there are no
  results at all.

**Verification this session:** Flutter 3.44.4/Dart 3.12.2 installed from
`storage.googleapis.com`; `dart analyze` = **0 errors, 0 new warnings**
(60 pre-existing warnings byte-identical to the parent commits, diffed
ignoring line numbers). Live end-to-end check of the marktguru pipeline
from this container: `offers/search?q=Milch&zipCode=10115` returns 200 with
real offers using the shipped fallback keys, the JSON shape matches
`StoreOffer.fromJson` field-for-field, and the CDN image URL pattern
(`mg2de.b-cdn.net/api/v1/offers/{id}/images/default/0/medium.jpg`) resolves
200. `flutter test` fails on Flutter 3.44 because `lucide_icons` 0.257.0
extends the now-`final` `IconData` — dependency/SDK mismatch, pre-existing,
not app code. No iOS build possible here (Linux).

**Still explicitly NOT done (documented, not faked):**
- Regular (non-promotional) shelf prices — no public API exists for German
  supermarkets; hard external constraint, not a shortcut. UI/AI copy says so.
- Real distance-based "closest reasonable store" — `UserLocationService`
  only resolves a zip code, not store addresses/distances; would need a
  store-locator API that isn't wired up.
- Cross-product substitution ("buy Rama instead of Kerrygold") — the chip
  suggests the cheapest offer matching the item's own name/stem, not a
  different product class; real product-equivalence mapping would need to
  respect diet/allergy constraints and is out of scope.

**Third session, 2026-07-04 (scheduled routine).** This session had a real
Flutter/Dart toolchain (downloaded Flutter 3.44.4 stable from
`storage.googleapis.com` into `/tmp/flutter`, same version the earlier
session used) so every change below is verified with a real `flutter
analyze` and a live curl-based check of the marktguru API's actual JSON
shape — not just brace-balance/grep verification. Audited the existing 85%
state instead of re-reading the write-up at face value, and found two real,
previously-undiscovered gaps:

1. **Performance bug in the "cheapest store" comparison — now fixed.**
   `basketComparisonProvider` fetched each list item's offers with a
   sequential `for (name in names) { await ... }` loop. Timed the real
   marktguru endpoint from this container: ~850–1050ms per request. For a
   25-item list (the code's own cap) that's a **20+ second wait** just to
   open the store-comparison sheet — effectively broken for any
   realistically-sized list, not a minor slowness. Fixed by:
   - Rewriting the loop as `Future.wait(names.map(...))` so all items fetch
     concurrently (`lib/presentation/providers/price_comparison_provider.dart`).
   - Fixing a real concurrency bug this exposed in
     `OfferPriceService._throttle()`: it read/wrote a shared `_lastRequest`
     timestamp with a bare check-then-act (no synchronization), so N
     concurrent callers would all read the same stale timestamp and pass the
     rate-limit gate together — the throttle silently did nothing under
     concurrency. Replaced it with a proper serialized queue (each call
     chains onto `_throttleQueue`, so request *starts* are still spaced by
     the 250ms minimum gap even when many callers fire at once) —
     `lib/data/services/offer_price_service.dart`. Net effect: a 25-item
     basket comparison now takes roughly (25 × 250ms spacing) + one request's
     latency ≈ 7s instead of 20–25s, while still not hammering the
     (unofficial, keyless-auth) API with a simultaneous burst.
2. **"Unit size and unit price" — a required capability from the brief that
   was never implemented, despite the API already providing the data for
   free.** Verified live against the real marktguru API
   (`offers/search?q=...&zipCode=10115`) that every offer response includes
   `volume` (pack size), `quantity` (pack count, e.g. 12 for a 12-pack case),
   and `referencePrice` (the Grundpreis — price per `unit.shortName`,
   already computed server-side as `price / (volume × quantity)`) — none of
   which `StoreOffer.fromJson` parsed, so this data was being silently
   discarded on every single request the app already makes. Implemented:
   - Added `volume`/`packQuantity`/`referencePrice` fields to `StoreOffer`
     plus two getters: `unitSizeLabel` (e.g. `"12 x 1 l"`, `"0.5 kg"`) and
     `unitPriceLabel` (Grundpreis, e.g. `"1.58 €/kg"`; suppressed for plain
     single-pack-single-unit items where it would just repeat the sale
     price) — `lib/data/models/store_offer.dart`.
   - Wired both into the offer suggestion rows and the item-offer detail
     sheet (replacing the previously-shown bare unit letter, e.g. "l", with
     the actual pack size) —
     `lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart`,
     `lib/presentation/screens/lists/widgets/item_offer_sheet.dart`.
   - The persisted `price_unit` on an item (set when adding from an offer or
     applying an offer to an existing item) now stores the human pack-size
     label instead of the bare unit letter, and the list-item row now
     actually displays it (`priceUnit` was being saved but never rendered
     anywhere) — `lib/presentation/screens/lists/list_detail_screen.dart`,
     `lib/presentation/screens/lists/widgets/item_offer_sheet.dart`.
   - Verified the new model logic (parsing + both label getters, including
     the multipack and suppressed-redundant-label cases) against JSON
     shaped exactly like real API responses, via a throwaway `dart run`
     script (not committed) — all cases passed.

Re-audited the previously-listed "explicitly NOT done" items and confirmed
they're still genuinely blocked, not shortcuts: `UserLocationService` only
ever resolves a zip code (no lat/lng, no store addresses), so real
distance-based "closest store" has no data to work from without adding a
store-locator API; regular (non-promotional) shelf prices still have no
public API for German supermarkets. Both are unchanged, honest blockers.

**Files changed (third session):**
`lib/data/models/store_offer.dart` (unit size/price fields + getters),
`lib/data/services/offer_price_service.dart` (serialized throttle queue),
`lib/presentation/providers/price_comparison_provider.dart` (parallel
per-item fetch),
`lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart`,
`lib/presentation/screens/lists/widgets/item_offer_sheet.dart`,
`lib/presentation/screens/lists/list_detail_screen.dart`.

**Checks performed (third session):** Downloaded Flutter 3.44.4 stable
directly (no `CI=true`/root issues once `git config --global --add
safe.directory /tmp/flutter` was set); `flutter pub get` + `flutter analyze`
run before and after, diffed ignoring line-number shifts — **byte-identical
issue set** (0 errors — after copying `env.example.dart` → `env.dart` and
adding a throwaway stub `firebase_options.dart`, both gitignored/untracked,
to get a real baseline instead of the 17 expected-but-noisy "file doesn't
exist" errors; 60 pre-existing warnings, 581 pre-existing info, 641 total
before and after). Verified live against the real marktguru API with `curl`
that `volume`/`quantity`/`referencePrice` are present and consistent with
the parsing logic (milk: 1l/1pack/€0.99 grundpreis; yogurt: 0.5kg/1pack/€1.58;
water: 1l×12pack/€0.50 grundpreis). `flutter test` still fails on the
pre-existing `lucide_icons`/`IconData` final-class incompatibility
(confirmed unrelated: same failure on this branch before any of this
session's changes). No iOS build possible (Linux container, no Xcode) — the
UI changes (unit-size labels, price-summary display) are logic-verified and
analyzer-clean but not visually confirmed on a simulator/device.

**Files changed (morning session):** `lib/presentation/providers/price_comparison_provider.dart`
(added `offerSearchAllProvider`), `lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart`
(zip nudge, savings badge, expiry tag), `lib/presentation/screens/lists/widgets/zip_code_sheet.dart`
(new), `lib/presentation/screens/lists/list_detail_screen.dart` (debounce,
`autoParse: false` on offer-add), `lib/data/repositories/item_repository.dart`
+ `lib/presentation/state/items_provider.dart` (`autoParse` param),
`lib/presentation/screens/profile/settings/personal_info_screen.dart` (zip
field), `lib/core/localization/app_translations.dart` (new EN/DE keys).

**Files changed (second session):**
`lib/presentation/screens/lists/widgets/item_offer_sheet.dart` (new —
`ItemOfferChip` + offer detail/apply sheet),
`lib/data/models/store_offer.dart` (`cheapestOfferFor`),
`lib/data/models/shopping_item_model.dart` (`pricingQuantity`),
`lib/presentation/screens/lists/widgets/list_price_summary_bar.dart`
(estimated list total, quantity fix),
`lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart`
(nationwide-fallback footer), `lib/presentation/screens/lists/list_detail_screen.dart`
(chip in item rows, merge resolution),
`lib/presentation/providers/price_comparison_provider.dart` (merge
resolution), `lib/core/localization/app_translations.dart` (7 new EN/DE
keys), plus the merge commit reconciling `main`'s `ac54af5`.
**Deleted** (dead code, see above): `lib/data/services/deal_extractor_service.dart`,
`lib/data/services/store_flyer_service.dart`, `lib/data/services/tesseract_setup.dart`,
`lib/data/models/store_flyer_model.dart`, `lib/data/models/shopping_item_with_deal.dart`,
`lib/presentation/state/flyers_provider.dart`,
`lib/presentation/screens/flyers/flyer_viewer_screen.dart`,
`lib/presentation/screens/markets/supermarkt_finder_page.dart`,
`lib/presentation/screens/offers/offers_screen.dart`,
`lib/presentation/widgets/flyer_card.dart`,
`lib/presentation/widgets/deals/deal_badge.dart`,
`lib/presentation/widgets/list/shopping_item_grid_card.dart`.

**Checks performed:** Real Flutter SDK available this session (see
environment note above) — ran `flutter pub get` and `dart analyze` against
the full project before and after every meaningful change. Result: 2
pre-existing errors (gitignored `firebase_options.dart`, expected), 61
warnings (down from the 67-warning baseline — the dead-code deletion removed
some, zero new warnings introduced by any change this session), 643 total
issues (down from 655). Verified every deleted symbol's reachability by
grepping for constructor calls, provider watchers, and router entries before
removing it — not just class-name mentions. `flutter test` (the repo's
compile-smoke test) fails on both this branch and its unmodified parent
commit with the same error, in an unrelated package (`lucide_icons` vs. this
Flutter SDK's `IconData` being a `final class`) — confirmed pre-existing via
`git stash` + re-run, not a regression from this session. `pubspec.lock`
churn from running `pub get` with a freshly-downloaded SDK was reverted
before committing, to avoid unrelated dependency-version noise in the diff.
**Not run (no macOS/Xcode available in this container):** `flutter build ios
--simulator --debug`, or a real on-device test of the add-item-from-offer
flow, the zip-code sheet, or the savings/expiry badges rendering correctly.

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

**Fourth session, 2026-07-04 (scheduled routine — this feature's dedicated
session).** Feature 1's remaining gaps are all genuinely blocked externally,
so per the feature order this session selected Feature 2: a QA audit of the
existing ~85% state plus the two owner-approved ideas. Real Flutter 3.44.4
toolchain available (downloaded to `/tmp/flutter`); every change verified
with full-project `flutter analyze` against a baseline diff.

*Bugs found by auditing (all fixed):*
1. **The payer's own share was created unpaid**, so the payer appeared in
   their own home-screen "owes you" banner ("Dominik owes you €12.50" shown
   to Dominik). `createSplits` now marks the payer's share `is_paid: true`
   (+ `paid_at`) at insert — they settled it at the register. The home
   banner additionally filters out payer-own rows defensively, so trips
   split before this fix stop showing the phantom row too.
2. **List members merged into the split sheet got €0.00 shares** — 
   `_mergeMembers` never recalculated the equal split, so amounts were stale
   until the user happened to touch the total or a checkbox. Recalc now runs
   (post-frame, since the merge happens during build) whenever members load.
3. **Equal split lost cents** (€10 / 3 → 3× €3.33 = €9.99). The sheet now
   distributes whole cents (3.34/3.33/3.33 — verified with a small
   edge-case script: remainders, 1 participant, €0.01 totals). The Avo
   `split_trip_cost` tool had the same bug; there the payer's share absorbs
   the remainder so shares always sum to the trip total.
4. **The "assigned vs. total" reconciliation line didn't update live** while
   typing custom amounts, and per-participant amount `TextEditingController`s
   were recreated inline on every rebuild (a rebuild mid-typing would
   clobber the field, and none were ever disposed). Participants now own
   persistent controllers (disposed with the sheet), the sum line updates on
   every keystroke, and it turns terracotta + semibold when custom amounts
   don't add up to the total (soft warning, doesn't block saving).
5. **`createSplits` silently coerced a name-only payer into the current
   user** (`paidByUserId ?? currentUserId`). The fallback now applies only
   when no payer is given at all, which the approved payer picker requires.

*Approved ideas implemented (moved here from the ideas section):*
- **"Who paid" picker** in the split sheet — a chip row of all participants
  under "Paid by", defaulting to the current user. Works with name-only
  payers (e.g. a roommate without the app fronted the money): the trip then
  stores `paid_by_name` with a null `paid_by_user_id`, and the current
  user's own unpaid share correctly shows up in their "you owe" banner.
- **Push notification on paid/unpaid** — `setPaid()` now notifies "the
  other side" (the payer when a participant settles their own share; the
  participant when the payer marks/reopens it), via the existing
  `PushNotificationService` → `send-push-notification` edge function.
  Fire-and-forget with `unawaited(...)`: a failed push can never fail the
  toggle. Never notifies the actor themselves; skips name-only people.
- **Copyable payment reminder** (was "explicitly NOT done" above) — unpaid,
  non-payer rows in the history split view now have a copy icon that puts a
  friendly localized message on the clipboard ("Hi Max! Kleine Erinnerung:
  du schuldest mir noch 12,50 € für unseren Einkauf \"Wocheneinkauf\".
  Danke! 🛒"), using the `copy_reminder`/`reminder_copied` keys that already
  existed plus a new `payment_reminder_message` key (EN/DE).

*Other UX improvements:*
- The home banner's "you owe €X to Y" rows now have an "I paid it back"
  quick action (the payer gets the push above). Verified against live RLS
  that participants may update their own split row (`auth.uid() = user_id`
  is in the UPDATE policy).
- The history split view now shows "Paid by: X" under the total, so a trip's
  payer is visible without opening the edit sheet.
- Marking paid from any surface now invalidates both banner providers, so
  the two home-banner directions can't go stale against each other.

*Files changed (fourth session):*
`lib/data/services/expense_split_service.dart` (payer-share settlement,
name-only payer fix, paid-status push), `lib/data/models/expense_split.dart`
(`toInsertJson` carries `paid_at`),
`lib/presentation/screens/history/widgets/split_cost_sheet.dart` (payer
picker, persistent controllers, cent-accurate split, live sum line),
`lib/presentation/screens/history/shopping_history_screen.dart` (copy
reminder, paid-by line), 
`lib/presentation/screens/home/widgets/pending_splits_banner.dart`
(payer-row filter, "I paid it back" action),
`lib/data/services/avo_assistant_service.dart` (cent-remainder fix only),
`lib/core/localization/app_translations.dart` (3 new EN/DE keys).

*Checks performed (fourth session):* `flutter analyze` before/after —
baseline 642 issues (0 errors, 61 warnings), after 641 (0 errors, 60
warnings — one pre-existing unused-variable warning was cleared because the
new paid-by line uses it; zero new issues of any severity). Cent-split math
verified with a throwaway `dart run` edge-case script (remainder
distribution, single participant, €0.01 totals, Avo payer-remainder — all
pass, not committed). Live RLS re-verified via Supabase MCP for the new
participant-updates-own-row path and the shopping_history SELECT scope the
notification lookup relies on (a participant later removed from the list
degrades gracefully — trip embed returns null and the row is skipped).
`flutter test` still fails on the pre-existing `lucide_icons`/`IconData`
SDK mismatch (unrelated, unchanged). **Not run (no macOS/Xcode here):** iOS
build; real push delivery end-to-end (needs two devices with FCM tokens);
visual check of the payer chips/copy icon on a device.

*Still open (small):* real push delivery QA on device; consider a
Supabase trigger instead of client-side push if you ever want reminders
when the *app is closed* on the payer's side (current approach sends from
the actor's client, which is fine for this flow).

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

**Navbar update (2026-07-04, owner-directed):** After an interactive design
round (three concepts → Option B variations → light/dark treatments), the
owner picked the "D1" design and it is now implemented in `MainScaffold`:
a full-width ink pill with three tabs (Listen · Rezepte · Profil) whose
active tab sits in a 12% paper circular seat, plus a detached circular Avo
orb on the right that pushes `/avo`. The navbar "+" was removed — create-list
already exists on the home screen ("+ Neue Liste") and lists screen. Two
deliberate deviations from the mockup, to avoid faking state: no Kalorien
tab yet (no screen exists until Feature 6; the pill is where it will slot
in) and no nudge dot on the orb (no nudge signal exists until Feature 5).
Verified with `flutter analyze` (0 errors, no new warnings); not yet seen
on a device/simulator.

**Navbar fix + calorie-tab visibility (2026-07-04, second round):** The
first D1 cut stretched the pill edge-to-edge (looked broken on device —
owner screenshot). Now the pill + orb group is content-sized and centered,
so it lays out correctly with either tab set. The Kalorien tab is now real
and preference-driven: `calorieTrackingEnabledProvider` (SharedPreferences,
default off), settable from a new opt-in page at the end of onboarding and
a switch in Profile → Preferences; a `/calories` shell branch (branch 2,
profile moved to 3) hosts an honest v0 screen that says tracking isn't
built yet (no fake data) and offers "hide this tab". Disabling the pref
while on the tab falls back to Home. Feature 7 moves to ~30%: the navbar
side of "calorie tracking must be optional" is done; the full adaptive
onboarding questionnaire and goal math remain with Feature 6.

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

- [x] IDEA (approved, DONE this session — with a correction): Delete the dead
  OCR/flyer-deal pipeline now that the marktguru pipeline is the real,
  wired-up offer source.
  - **Outcome:** Deleted `DealExtractorService`, `StoreFlyerService`,
    `TesseractSetup`, `StoreFlyerModel`, `ShoppingItemWithDeal`,
    `flyers_provider.dart`, `OffersScreen`, `SupermarktFinderPage`,
    `FlyerViewerScreen`, `FlyerCard`, `DealBadge`, `ShoppingItemGridCard` —
    all confirmed zero live call sites (grepped for constructors/providers/
    routes, not just class-name mentions).
  - **Correction to the original idea:** `ExtractedDeal`,
    `DealsDatabaseService`, and `ProductMatchingService` were **not**
    deleted, because they turned out to be live — `RecommendationService`
    calls `ProductMatchingService.findBestDealForProduct()`, and
    `RecommendationService` is reachable from `list_detail_screen.dart` via
    `RecommendationsSection`. Deleting them would have broken a working (if
    functionally inert — see below) code path. See Feature 1's session notes
    above for the full explanation.
  - See the new idea directly below for the follow-up this uncovered.

- [ ] IDEA: Strip the now-fully-inert `dealBonus` hook from
  `RecommendationService` (and decide whether `ProductMatchingService`/
  `DealsDatabaseService`/`ExtractedDeal` should go too).
  - Why it helps: `RecommendationService.dealBonus` scoring can never
    contribute anything now — its only real data source (the OCR extractor)
    was just deleted as dead code, and it was already permanently empty
    before that (nothing ever populated `DealsDatabaseService`'s local
    table). Right now it's a live call that always no-ops, which is subtler
    and easier to miss than obviously-dead code.
  - Expected user value: none directly (already invisible).
  - Expected business/premium value: none directly; reduces confusion for
    whoever next touches the recommendations engine.
  - Complexity: Low-medium — touches `RecommendationService` (used by
    `RecommendationsSection`, which is live in `list_detail_screen.dart`),
    so it's a recommendations-engine change, not a pure pricing one. Slightly
    out of Feature 1's scope, closer to Feature 8 (cross-feature
    recommendations) — flagging rather than doing it opportunistically.
  - Risk: Low if done carefully (just remove the dead scoring term), but
    touches a live, user-facing ranking path, so it deserves its own
    focused pass rather than a drive-by edit.
  - Recommendation: yes, as a small follow-up — either standalone or folded
    into a future Feature 8 pass on the recommendation engines.

- [ yes] IDEA: Consolidate the two dead mascot/gamification systems
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

- [x] IDEA (approved, DONE 2026-07-04): Let the split-cost sheet pick a
  different "who paid" person instead of always defaulting to whoever opens
  the sheet.
  - **Outcome:** Implemented as a "Paid by" chip row in the split sheet,
    including name-only payers. Details in Feature 2's fourth-session notes.

- [x] IDEA (approved, DONE 2026-07-04): Push notification when a split is
  marked paid/unpaid.
  - **Outcome:** Implemented client-side in `ExpenseSplitService.setPaid()`
    via the existing `PushNotificationService`; notifies the other party
    only, fire-and-forget. Details in Feature 2's fourth-session notes.

- [ yes] IDEA: Build calorie tracking (Feature 6) as its own dedicated
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

- [ yes] IDEA: Rebuild onboarding (Feature 7) immediately after Feature 6's
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
