# Shoply Feature Implementation Status

_Last updated: 2026-07-19, second run (scheduled routine — Feature 4 focus:
closed the item/list CRUD gap in Avo's tool registry — the brief requires
"AI can add, **edit**, remove, and **organize** items" and "AI can **change
shopping lists**", but no tool existed to edit an item, move items between
lists, create a list, or rename a list; all four added)_

**2026-07-19 second run — why Feature 4.** Same walk as every recent
session: Features 1–2 re-confirmed blocked on hard externals/device QA;
Feature 3 had the morning session (deployment-target fix) and its remaining
items are device-confirmation- or decision-gated. Feature 4 is next in
order, marked "Implemented (needs QA)" — but per the fresh-discovery
precedent (re-audit the feature itself against the brief, don't just trust
the table), this session diffed the actual 25-tool registry in
`avo_assistant_service.dart` against the brief's required capabilities and
found four unconditional, buildable-here gaps: Avo could **add**, check,
delete, and read list items, but a user saying "change the milk to 2
liters," "move the butter to the party list," "make me a list for the
weekend," or "rename this list" hit a dead end — no `update_item`,
`move_items`, `create_list`, or `rename_list` tool existed. These are
explicit brief bullets ("add, edit, remove, and organize items"; "AI can
change shopping lists"), need no owner decision, and are Dart-only. See
Feature 4's ninth-session notes below.

**2026-07-19 — why Feature 3, again.** Same walk as every recent session:
Features 1–2 re-confirmed blocked on hard externals/device QA (re-checked
their summary-table status, unchanged since 2026-07-16/17). Feature 3 is the
first feature genuinely marked "In progress." Its own Ideas list had nothing
left at an unconditional recommendation-`yes` (the `VoiceAssistantPlugin.swift`
deletion explicitly waits on a real-device confirmation this container still
can't provide; the new-widget-kind ideas are needs-decision) — so, following
the same precedent Feature 8's 2026-07-17/18 sessions set ("do fresh
discovery on the selected feature itself rather than picking from the
Ideas log"), this session re-read Feature 3's own "Explicitly NOT done"
history line by line instead of just the Ideas section, and picked the one
item repeatedly flagged as "worth checking" but never actually investigated:
*"The widget target's `IPHONEOS_DEPLOYMENT_TARGET = 26.0` vs. Runner's
`15.6`/`13.0` is unusually high and worth double-checking against your
actual target device/simulator OS versions"* (first flagged in the fourth
session, repeated unchanged through the eighth). See Feature 3's ninth-session
notes below for what investigating it actually found.

**2026-07-18 second run — why Feature 6.** Same walk as every recent session:
Features 1–2 blocked on hard externals/device QA; Feature 3's open items are
device-confirmation- or decision-gated; Features 4–5 and 7 have only
needs-decision or device-QA items; Feature 8's two open items (premium gating,
weekly nutrition summary) both carried needs-decision flags. But re-reading the
weekly-summary idea against the original brief showed the flag was
over-cautious: "Weekly progress summary" is an explicit *autonomy bullet of
Feature 6 itself* in the brief ("Weekly progress summary", "Streaks, but not
too aggressive"), i.e. work the brief already authorizes — the prior session
had flagged it only because it isn't in Feature 6's *required* list. So this
session built it as a Feature 6 session. The other half of that same idea (a
dedicated in-app "what can I still eat today?" surface) is NOT covered by an
explicit brief bullet and stays flagged for a decision — see the updated idea
below.

**2026-07-18 — why Feature 8, again.** Same walk as every recent session:
Features 1–2 re-confirmed blocked on hard externals/device QA; Feature 3's
open items are device-confirmation- or decision-gated; Features 4–7's open
items are all needs-decision or device-QA (re-checked each section's
"Explicitly NOT done" list, not just the summary table). Feature 8's own
Ideas list had nothing left at unconditional recommendation-`yes` (weekly
nutrition summary and premium gating both explicitly need a decision; the
one `yes` item left, deleting `VoiceAssistantPlugin.swift`, belongs to
Feature 3 and is still waiting on real-device confirmation). So this session
did fresh discovery on Feature 8 itself rather than picking from the log —
see the fourth-session notes below for what that surfaced.

**2026-07-17 second run — why Feature 8.** Same walk as every recent
session: Features 1–2 re-confirmed blocked on hard externals/device QA;
Feature 3's two open items explicitly wait on a real-device confirmation
(`VoiceAssistantPlugin.swift` deletion) or an owner decision ("today's
list" widget); Features 4–7's open items are all needs-decision or
device-QA. Feature 8 (~40%, lowest completion) carried the one
fully-scoped, unconditional recommendation-`yes` item with no owner
decision or device dependency: the `dealBonus`/recommendation-engine
cleanup, whose own write-up suggested folding it into "a future Feature 8
pass on the recommendation engines." This session was that pass — see
Feature 8's third-session notes for the significant correction it
uncovered (two prior write-ups wrongly believed `RecommendationService`
was live because of a substring-grep pitfall: every grep for
`RecommendationsSection`/`recommendation_service.dart` also matches
`MLRecommendationsSection`/`ml_recommendation_service.dart`).

**2026-07-17 — why Feature 3, again.** Feature 1 (~95%, blocked on genuine
external constraints) and Feature 2 (~95%, device-QA-only) were
re-confirmed as having no unblocked buildable-here work, per the same
precedent prior sessions established. Feature 3 is the first feature
genuinely marked "In progress," and its Ideas list had exactly one
fully-scoped, unconditional recommendation-`yes` item with no owner decision
or device dependency attached: deleting the now-triply-confirmed-dead Siri
method-channel code (`SiriService.dart`, `home_screen.dart`'s
`_checkSiriPendingItems()`) that the working `AppIntents.swift` deep-link
flow (fifth session) already superseded. The broader, related idea
(also deleting `VoiceAssistantPlugin.swift`) was deliberately left alone —
its own write-up asks to wait for a real-device confirmation of the
`AppIntents.swift` fix first, which this container still can't provide. See
Feature 3's eighth-session notes below for the full change and verification.

**2026-07-16 second run — why Feature 3.** Per the brief's priority order:
Feature 1 was re-audited by the morning session (all required + autonomy
capabilities implemented; remaining gaps are hard external constraints),
Feature 2 is ~95% with only device-QA items left (a constraint every
feature here shares — no macOS/Xcode in this container). Feature 3 is the
first feature in the order that is genuinely "In progress" **and** had
concrete, unblocked, buildable-here work: the Ideas list carried a
fully-scoped, recommendation-`yes` item from Feature 3's own sixth session
(proactively re-push the widget's cached Supabase access token on token
refresh — without it, a widget tap silently no-ops once the cached token
expires, ~1h after the app was last opened). Auditing that code path also
surfaced a second, related real gap fixed this session: `WidgetService.clearWidget()`
existed but had **zero call sites**, and the native `clearWidgetData`
handler only removed 2 of the ~8+ `widget_*` App Group keys — so signing
out never cleared the widget's cached list contents, credentials, or
Siri's cached list names. The other two open Feature 3 ideas were
deliberately NOT bundled in (the dead-Siri-code deletions explicitly ask to
be their own isolated change; the new "today's list" widget kind is marked
needs-decision).

The 2026-07-16 **Feature-3** session (second run of the day) downloaded
Flutter 3.35.6 stable fresh into `/tmp/flutter` and verified with
full-project `flutter analyze`: baseline (via `git stash`, this branch
before this session's changes) and after-change counts are **byte-identical:
610 issues (0 errors, 59 warnings, 551 info)**, diffed with line numbers
normalized out. `flutter test` passes ("All tests passed"). The one touched
Swift file (`ios/Runner/AppDelegate.swift`) was verified with a string- and
comment-aware brace/paren/bracket-balance parser (no Swift toolchain in
this container) — the edit is a small mechanical change inside an existing
function (prefix sweep instead of two hardcoded `removeObject` calls).
`pubspec.lock` churn from `flutter pub get` was reverted before committing.
No iOS build/device test possible here (no macOS/Xcode) — see "Not
verified" in the Feature 3 seventh-session notes below.

**Earlier 2026-07-16 session — why Feature 8, not Feature 1.** Per the brief's
priority order, Feature 1 (pricing/offers) is first and technically still
"In progress" (~95%), so this session started there and did a full code
audit rather than trusting the log: read every pricing/offers file
end-to-end, live-`curl`-verified the marktguru API pipeline is still healthy
with the shipped fallback keys, and checked every required/autonomy
capability from the brief against the current code. Result: **all of
Feature 1's required and autonomy capabilities are implemented**; the only
remaining gaps are the same two the fifth session (2026-07-10) already
documented as genuinely blocked — no public shelf-price API for German
supermarkets (hard external constraint) and cross-product substitution
(deliberately out of scope for diet/allergy safety) — plus device-only
rendering verification, which every feature in this file shares as a
permanent constraint of this Linux container. This matches the precedent
the Feature 2 fourth-session (2026-07-04) note already established
explicitly for this exact situation ("Feature 1's remaining gaps are all
genuinely blocked externally, so per the feature order this session
selected Feature 2") — so this session moved to the next feature with
genuine, unblocked, buildable-here work. Features 2–7 were spot-checked
against their own documented blockers (mostly "needs a real device/Xcode
session," a constraint that applies identically to every feature here) and
Feature 8 stood out as the clear next pick: lowest completion (~30%) *and*
the Ideas list already contained a fully-scoped, owner-recommendation-`yes`
item with no open product decision — the home-screen price-comparison card
— unlike Feature 8's other open items (premium gating, a weekly nutrition
summary) which explicitly need an owner decision first.

The 2026-07-16 **Feature-8** session downloaded Flutter 3.35.6 stable fresh
into `/tmp/flutter` and verified with full-project `flutter analyze`:
baseline (via `git stash`, this branch before this session's changes) and
after-change counts are **byte-identical: 610 issues (0 errors, 59 warnings,
551 info)** — confirmed by also scoping `flutter analyze` to just the 6
new/touched files (2 real bugs caught on the first pass and fixed before
committing — see below; re-scoped analyze came back clean). `flutter test`
passes ("All tests passed"). The new `_deriveHomeHighlight` selection logic
(which store to call "cheaper," which to compare against, the minimum-
savings/minimum-matched-items gates) was verified with a throwaway `dart
run` script (4 cases, all passed, not committed, deleted before finishing) —
notably confirming the deliberate design choice to compare the cheapest
store against the *second*-cheapest, not the priciest outlier, so the
on-screen claim is a fair comparison rather than a cherry-picked worst case.
No iOS build/device test possible here (no macOS/Xcode) — see "Not
verified" in the Feature 8 session notes below.

The 2026-07-14 **Feature-6** session downloaded Flutter 3.35.6 stable fresh
into `/tmp/flutter` and verified with full-project `dart analyze`: baseline
(via `git stash`, this branch before this session's changes) and after-change
counts are **byte-identical: 610 issues (0 errors, 59 warnings, 551 info)** —
confirmed by also scoping `dart analyze` to just the 10 new/touched files (2
issues found on the first pass, both `unnecessary_import` on a redundant
`dart:typed_data` import already re-exported by `flutter/services.dart`/
`flutter/foundation.dart`; fixed, re-scoped analyze came back clean).
`flutter test` passes ("All tests passed"). The new `DietChallenge.currentStreak`/
`adherenceRate`/`daysRemaining`/`isPastTargetEnd` logic was verified with a
throwaway `dart run` script (21 cases) — **one real bug caught and fixed
before committing**: `currentStreak` used `!= true` to decide whether to fall
back to checking yesterday, which couldn't distinguish "no check-in yet
today" from "explicitly checked in as missed today" — an explicit miss
incorrectly kept yesterday's streak alive instead of resetting to 0. Fixed by
checking `containsKey` first. `pubspec.lock` churn from `flutter pub get`
with the freshly-downloaded SDK was reverted before committing. No iOS
build/device test possible here (no macOS/Xcode) — see "Not verified" in the
Feature 6 session notes below.

## Environment note (read first)

The 2026-07-13 **Feature-3** session downloaded Flutter 3.35.6 stable fresh
into `/tmp/flutter` and verified with full-project `dart analyze`: baseline
(via `git stash`, this branch before this session's changes) and after-change
counts are **byte-identical: 610 issues (0 errors, 59 warnings, 551 info)**.
`flutter test` passes ("All tests passed"). The three touched/new Swift
files (`ios/ShoppingListWidget/QuickAddWidget.swift` (new),
`ios/ShoppingListWidget/ShoppingListWidget.swift`, `ios/Runner/AppDelegate.swift`)
were verified with a brace/bracket/paren-balance parser (Python, string- and
comment-aware) rather than a real Swift compiler — no Swift toolchain exists
in this Linux container and no `swiftc`/`swift` binary is installed. The new
widget file was **not** added to `project.pbxproj` — it didn't need to be:
`ios/ShoppingListWidget` is a `PBXFileSystemSynchronizedRootGroup` (confirmed
by reading the project file directly), so Xcode auto-discovers any `.swift`
file dropped into that folder and compiles it into the
`ShoppingListWidgetExtension` target with zero project-file edits, the same
mechanism that already covers `ShoppingListWidget.swift` and
`ShoppingListWidgetControl.swift`. `pubspec.lock` churn from `flutter pub get`
was reverted before committing. No iOS build/device test possible here (no
macOS/Xcode) — see "Not verified" in the Feature 3 sixth-session notes below.

The 2026-07-10 **Feature-1** session downloaded Flutter 3.35.6 stable
fresh into `/tmp/flutter` and verified with full-project `dart analyze`:
baseline (via `git stash`, this branch before this session's changes) and
after-change counts are **byte-identical: 610 issues (0 errors, 0
warnings, 610 info)** — every touched file is analyzer-clean on its own
(`dart analyze` scoped to the 6 changed files: 6 pre-existing `avoid_print`
info lints in `offer_price_service.dart`, same style as the rest of the
codebase, 0 new issues). `flutter test` passes ("All tests passed"). The
new `asBroadMatch()`/`broadMatchOnlyCount` confidence logic was verified
with a throwaway `flutter test` file (4 cases: flag-without-mutating,
zero-count-when-an-exact-match-exists-anywhere, counts-an-item-only-broad-
matched-everywhere, excluded-once-any-store-has-an-exact-match — all
passed, not committed, deleted before finishing). `pubspec.lock` churn from
`flutter pub get` with the freshly-downloaded SDK was reverted before
committing. No iOS build/device test possible here (no macOS/Xcode) — see
"Not verified" in the Feature 1 session notes below for what that leaves
unconfirmed, in particular how the new "Similar product" badge and warning
note actually render and wrap at real device widths.

The earlier note from the 2026-07-09 **Feature-4** session (second run of the day) downloaded
Flutter 3.35.6 stable fresh into `/tmp/flutter` and verified with
full-project `flutter analyze` before (via `git stash`) and after this
session's changes — see the Feature 4 eighth-session notes for the exact
counts — plus `flutter test` ("All tests passed") and a throwaway
calculator/validation test file (not committed). No iOS build/device test
possible here (no macOS/Xcode); a live Gemini conversation QA pass (does
flash-lite route "hilf mir ein Kalorienziel einzurichten" to the new tools
correctly?) still needs a real device + API key.

The earlier note from the 2026-07-09 Feature-8 session (first run of the day):

The 2026-07-09 **Feature-8** session downloaded Flutter 3.35.6 stable fresh
into `/tmp/flutter` and verified with full-project `flutter analyze`: baseline
(this branch, before this session's changes) **610 issues (0 errors, 59
warnings)**; after this session's 3 new files + 7 touched files: **still 610
issues, byte-identical** — every new/touched file is analyzer-clean, confirmed
by also running `flutter analyze` scoped to just the 3 new files (0 issues).
`flutter test` passes ("All tests passed"). The new `filterAndSort` selection
logic (calorie fit, diet-preference matching, allergen exclusion, closest-fit
sort, rating tie-break) was verified with a throwaway `flutter test` file (8
cases: no-nutrition exclusion, over-budget exclusion, zero/negative-calorie
guard, closest-fit ordering, rating tie-break, diet AND-matching, allergen
exclusion, limit — all passed, not committed). No iOS build/device test
possible here (no macOS/Xcode) — see "Not verified" in the Feature 8 section
below for what that leaves unconfirmed, in particular the actual card
rendering and the real evening-notification delivery.

The earlier note from the 2026-07-08 Feature-7 session:

The 2026-07-08 **Feature-7** session downloaded Flutter 3.35.6 stable fresh
into `/tmp/flutter` and verified with full-project `flutter analyze`: baseline
(this branch, before this session's changes) **612 issues (0 errors, 59
warnings, 553 info)**; after this session's 3 new files + 5 touched files + 1
deleted dead file: **610 issues (0 errors, 59 warnings, 551 info)** —
diffed ignoring line numbers, the only real change is the 2 `withOpacity`
info-lints that left with the deleted dead `unified_setup_screen.dart`; every
new/touched file is analyzer-clean. `flutter test` passes ("All tests
passed"). The `OnboardingGoalDraft` JSON round-trip and
`NutritionGoalCalculator` sanity (reused from Feature 6, not reimplemented)
were verified with a throwaway `flutter test` file (7 assertions, all passed,
not committed). No iOS build/device test possible here (no macOS/Xcode) — see
"Not verified" in the Feature 7 section below for what that specifically
leaves unconfirmed, in particular the real signup → onboarding-answers-sync
round trip against a live Supabase project.

The earlier note from the 2026-07-07 second run (Feature 5):

The 2026-07-07 **Feature-5** session (second run of the day) downloaded
Flutter 3.35.6 stable fresh into `/tmp/flutter` and verified with
full-project `flutter analyze`: **612 issues (0 errors, 59 warnings) before
and after** — byte-identical modulo line numbers (the only diff vs. the raw
baseline run is the two expected errors from the gitignored
`firebase_options.dart`, which disappear once the usual throwaway stub is in
place; the stub and `env.dart` copy are untracked and not committed).
`flutter test` passes ("All tests passed"). The offer-nudge relevance and
selection logic was verified **against the live marktguru API** (which
exposed and fixed two real design flaws — see the Feature 5 session notes),
and the weekday/eligibility/matching logic with two throwaway `dart run`
scripts (18 + 14 cases, all passed, not committed). `pubspec.lock` churn
from `pub get` was reverted before committing. No iOS build/device test
possible here (no macOS/Xcode).

The earlier note from the 2026-07-07 Feature-1 session:

The 2026-07-07 **Feature-1** session downloaded Flutter 3.35.6 stable fresh
into `/tmp/flutter` and verified with full-project `flutter analyze`:
baseline **608 issues (0 errors, 59 warnings)**, confirmed byte-identical to
the previous session's recorded baseline before any changes. After this
session's 2 new files + 5 touched files: **612 issues (0 errors, 59
warnings)** — the +4 are `avoid_print` info lints in the one wholly new
service file (`store_locator_service.dart`), same accepted logging style
used throughout the codebase (emoji-prefixed `print`, per `CLAUDE.md`), not a
new category of issue. `flutter test` passes ("All tests passed"). Verified
the new Overpass API (OpenStreetMap) integration live with `curl` — real
supermarket branch data (brand, name, address, lat/lon) returned in the
exact shape the parser expects — and verified the Haversine distance
formula and OSM-brand→retailer-id normalization logic with a throwaway
`dart run` script (15/15 cases passed, not committed). `flutter build ios`
and a live in-app GPS/location-permission test remain impossible here (no
macOS/Xcode; no simulator to grant location permission to). `pubspec.lock`
churn from `pub get` was reverted before committing.

The earlier note from the 2026-07-06 second-run (Feature 4) session:

The 2026-07-06 **Feature-4** session (second run of the day) downloaded
Flutter 3.35.6 stable fresh into `/tmp/flutter` and verified with
full-project `flutter analyze`: **608 issues (0 errors, 59 warnings) —
byte-identical to the baseline the morning Feature-6 session recorded**;
both touched files are analyzer-clean. `flutter test` passes ("All tests
passed"). `flutter build ios` and a live Gemini conversation test remain
impossible here (no macOS/Xcode; `env.dart` is a gitignored stub in this
container). `pubspec.lock` churn from `pub get` was reverted before
committing.

The earlier note from the morning Feature-6 session:

The 2026-07-06 Feature-6 session downloaded Flutter 3.35.6 stable fresh into
`/tmp/flutter` (same approach as prior sessions) and verified every change
with a full-project `flutter analyze` and `flutter test` before and after.
Baseline (this branch, before this session's changes): 608 issues (0 errors,
59 warnings, 549 info). After this session's ~20 new files + 3 touched files:
**still 608 issues (0 errors, 59 warnings)** — byte-identical to baseline
once new-file paths are excluded; every new/touched file is analyzer-clean
with zero issues of any severity. `flutter test` passes ("All tests
passed"). `flutter build ios` remains impossible here (no macOS/Xcode in the
Linux container) — see "Not verified" in the Feature 6 section below for
what that specifically leaves unconfirmed.

Recent scheduled sessions (including the latest, 2026-07-05) download a real
Flutter SDK into the container and verify every change with a full-project
`flutter analyze`; the 2026-07-05 Feature-5 session additionally found that
`flutter test` **passes** on Flutter 3.35.6 (the long-reported
`lucide_icons`/`IconData` failure only occurs on newer 3.44.x SDKs where
`IconData` became `final`). `flutter build ios` remains impossible here (no
macOS/Xcode in the Linux container). The note below is from the 2026-07-02
session, kept for history:

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
| 1 | Pricing, offers, cheapest store | ~95% | Implemented (blocked on hard externals) | Re-audited 2026-07-16, code-verified against every brief bullet: all required + autonomy capabilities implemented. Only remaining gaps are a genuine external constraint (no public non-offer shelf-price API) and an out-of-scope-by-design item (cross-product substitution, diet/allergy safety) |
| 2 | Split shopping trip costs | ~95% | Implemented (needs device QA) | None functional; push + widget rendering need a real device run |
| 3 | Widgets & quick actions | ~93% | In progress (needs device QA) | **2026-07-19: fixed a real, likely-severe regression** — the widget extension's `IPHONEOS_DEPLOYMENT_TARGET` was `26.0` (Runner is `15.6`), meaning the widget/quick-add extension could never install on any device below iOS 26 no matter how correct the entitlements/App-Intents fixes were; corrected to `17.0`, the code's real minimum (unguarded `Button(intent:)` interactive widgets). Token re-push on refresh + sign-out widget-data clearing shipped 2026-07-16; Quick-Add widget shipped 2026-07-13; dead Siri method-channel code deleted 2026-07-17; all of it still needs a real Xcode/device build to confirm. Remaining in-code work: `VoiceAssistantPlugin.swift` deletion (waiting on device confirmation of the deep-link fix) and the needs-decision "today's list" widget kind |
| 4 | AI assistant app control | ~93% | Implemented (needs QA) | Item/list CRUD gap closed 2026-07-19 (second run): `update_item`, `move_items`, `create_list`, `rename_list` — Avo can now edit and organize items and create/rename lists, not just add/delete. None functional; needs a real device run + live Gemini QA |
| 5 | Avo mascot & smart notifications | ~85% | In progress | Proactive recipe-suggestion nudges shipped 2026-07-09 (`CalorieRecipeNudgeService`, cross-linked from Feature 8's first session) — the table blocker naming this as still-open was stale and is now corrected; needs device QA for scheduled notifications. A real `item_purchase_stats` double-counting bug that was skewing the restock nudge's "every N days" math was fixed 2026-07-18 (Feature 8's fourth session) |
| 6 | Calorie tracking | ~90% | In progress (needs device QA) | Weekly summary screen + logging streak shipped 2026-07-18 (second run). Camera barcode scanning still not built (`mobile_scanner` commented out for iOS build issues, per CLAUDE.md); needs device QA |
| 7 | Personalized onboarding & navbar | ~75% | In progress (needs device QA) | Diet-preference + goal-questionnaire onboarding pages and account-level sync are new and unverified on a real device/signup flow |
| 8 | Cross-feature UX / growth / premium | ~55% | In progress | Proactive "split this trip?" nudge (snackbar action + home-screen card) shipped 2026-07-18, closing the brief's own headline cross-feature example; recommendation-engine consolidation done 2026-07-17; premium-gating audit still open and needs an owner product decision first (the weekly nutrition summary was built 2026-07-18 as Feature 6 work — see that section) |

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
  *[2026-07-17 correction: this paragraph's "**is** live" claim was itself
  wrong — a substring-grep artifact (`MLRecommendationsSection` contains
  `RecommendationsSection`). `RecommendationsSection` has never been
  mounted by any screen; the whole chain incl. these three files was
  deleted in Feature 8's third session. See that section's notes.]*

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
- ~~Real distance-based "closest reasonable store" — `UserLocationService`
  only resolves a zip code, not store addresses/distances; would need a
  store-locator API that isn't wired up.~~ **Implemented in the fourth
  session (2026-07-07)** via the free Overpass/OpenStreetMap API — see that
  session's notes below for what it covers and its remaining limits
  (straight-line distance, GPS-only, marktguru-covered chains only).
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

**Fourth session, 2026-07-07 (scheduled routine).** Picked Feature 1 again —
first not-fully-implemented feature in the brief's priority order — and
audited the previously-documented "explicitly NOT done" list rather than
re-reading it at face value. Two of the three were re-confirmed as genuine,
unchanged external constraints (no public shelf-price API; cross-product
substitution is out of scope for diet/allergy safety). The third —
**"real distance-based closest reasonable store"** — turned out to be
solvable without any paid API or key: `UserLocationService` already fetches
a raw GPS fix (`Geolocator.getCurrentPosition`) to resolve a zip code via
reverse geocoding, but discarded the coordinates afterward, and the
[Overpass API](https://overpass-api.de) (OpenStreetMap's free, keyless query
service) returns real supermarket branch locations — brand, name, address,
lat/lon — for any coordinate, worldwide, with no account or usage cap
beyond fair-use rate limiting. Verified this live with `curl` from this
container before writing any Dart: a real query near central Berlin
returned actual branches (Netto Marken-Discount, Edeka, …) with `brand`,
`addr:street/housenumber/city/postcode`, and top-level `lat`/`lon` — an
exact match for what the new parser expects.

**What I implemented:**
- `UserCoordinates` + `UserLocationService.getCoordinates()`
  (`lib/data/services/user_location_service.dart`) — exposes the raw GPS
  fix (24h cache, same pattern as the existing zip cache) instead of
  discarding it. Refactored the permission-check-and-fix logic that used to
  live only in `_zipFromGps()` into a shared private `_getPosition()`, used
  by both the zip resolver and the new coordinates getter, so there's still
  only one place in the codebase that requests location permission.
  Zero behavior change to the existing zip flow — same permission dance,
  same GPS accuracy/timeout settings, same fallback-to-stale-cache path.
- `NearbyStore` (new, `lib/data/models/nearby_store.dart`) — a real branch:
  name, address, lat/lon, distance from the user (Haversine, accurate
  enough for "which branch is closest" — not turn-by-turn routing), plus a
  `retailerUniqueName` when the OSM brand could be confidently mapped to one
  of marktguru's known grocery chains (null for chains outside marktguru's
  coverage — still a real nearby store, just not price-comparable).
- `StoreLocatorService` (new, `lib/data/services/store_locator_service.dart`)
  — queries Overpass for `shop=supermarket` nodes within 8km of a
  coordinate, with a mirror endpoint fallback (`overpass.kumi.systems`) if
  the primary times out or errors, matching the resilience pattern already
  used for the marktguru key refresh. Results are cached in memory per
  rounded coordinate (~110m) for 6 hours — Overpass is a shared community
  service with informal fair-use limits, so this is called at most once per
  store-comparison-sheet open, never polled. Never throws: returns an empty
  list on any failure, which callers treat identically to "no location
  data" (distance info just doesn't show).
- Brand normalization (`_normalizeRetailer`) maps OSM's `brand`/`name` tags
  to marktguru's exact retailer ids (`rewe`, `edeka`, `lidl`, `kaufland`,
  `aldi-sued`/`aldi-nord`/`aldi`, `penny`, `norma`, `netto-marken-discount`
  vs. plain `netto` — two distinct German chains that share the "Netto"
  word, checked in the right order so the compound name wins — `nahkauf`,
  `globus`, `famila`, `tegut`). Verified with 15 hand-written cases
  (including the Netto ambiguity and two non-grocery brands that should
  correctly resolve to `null`) via a throwaway `dart run` script — all
  passed.
- `BasketComparison.closestReasonableAlternative()` (new method,
  `lib/data/models/store_offer.dart`) — the actual "closest reasonable
  option" logic the brief asked for: returns null when the cheapest store
  already has a nearby branch (≤3km — nothing to recommend instead),
  otherwise finds the cheapest *comparable* store that does have a branch
  within 3km, and only surfaces it when the extra cost is small (≤€3 or
  ≤15% more than the outright cheapest total) — so it never recommends
  "closer but meaningfully worse."
- Wired into the store-comparison sheet
  (`lib/presentation/screens/lists/widgets/list_price_summary_bar.dart`):
  each ranked store row now shows a real distance chip (e.g. "1.2 km") next
  to its name when a nearby branch was found, and a new "Closer option" card
  appears above the estimated-total line when
  `closestReasonableAlternative()` has a recommendation — e.g. "Netto has a
  branch 900 m away — only 1.40 € more than the cheapest total." New
  providers `userCoordinatesProvider` / `nearbyStoresProvider`
  (`lib/presentation/providers/price_comparison_provider.dart`) follow the
  same `FutureProvider`/`autoDispose` shape as the existing zip/offer
  providers, and fail open (empty list) exactly like `bestStore` already
  did when data isn't available — the whole comparison sheet still works
  with zip-only data if the user denies location permission, distance info
  is a pure addition on top.
- Two new i18n keys (EN/DE), `closer_option_title` / `closer_option_body`,
  added next to the existing pricing strings in
  `lib/core/localization/app_translations.dart`.

**Explicitly NOT done / known limits of this increment:**
- This only resolves distance for chains covered by marktguru's offer data
  (the same `groceryRetailers` set `OfferPriceService` already searches) —
  a nearby branch of an unlisted chain is still detected by the locator but
  won't appear in the price comparison, since there's no offer data for it
  to compare.
- Haversine straight-line distance, not real walking/driving distance —
  labeled as such internally; a genuinely "closest by road" answer would
  need a routing API (Mapbox/OSRM/Google Directions), which is a bigger
  scope addition than this session's brief called for.
- Coordinates are only ever sourced from GPS — a user on the manual-zip-only
  path (no location permission) gets zip-based offers as before, but no
  distance chips or "closer option" card, since a zip code alone can't place
  a store on a map. This is the same tradeoff the "not done" note already
  flagged before this session; it's now *narrower* (distance genuinely works
  for GPS users) rather than fully unblocked for everyone.
- Not verified on a real device/simulator: the actual location-permission
  prompt, a live Overpass round-trip from inside the running app, or how the
  new distance chip/callout card actually renders and wraps at real device
  widths. The Overpass response shape, the Haversine math, and the brand
  matching are verified (curl + throwaway script); the Flutter widget tree
  is analyzer-clean but not visually confirmed.

**Files changed (fourth session):**
`lib/data/models/nearby_store.dart` (new),
`lib/data/services/store_locator_service.dart` (new),
`lib/data/services/user_location_service.dart` (`getCoordinates`,
`_getPosition` refactor),
`lib/data/models/store_offer.dart` (`closestReasonableAlternative`),
`lib/presentation/providers/price_comparison_provider.dart`
(`userCoordinatesProvider`, `nearbyStoresProvider`),
`lib/presentation/screens/lists/widgets/list_price_summary_bar.dart`
(distance chips, closer-option card),
`lib/core/localization/app_translations.dart` (2 new EN/DE keys).

**Checks performed (fourth session):** See the environment note at the top
of this document for the full `flutter analyze`/`flutter test` results and
live-data verification. Summary: 0 errors, 59 warnings (byte-identical to
baseline), +4 info (`avoid_print` in the one new service file, same style as
the rest of the codebase); `flutter test` passes; Overpass API verified live
via `curl` against real coordinates; Haversine distance and brand
normalization verified via a throwaway `dart run` script (15/15 cases
passed, not committed); `pubspec.lock` churn from `pub get` reverted before
committing. No iOS build/device test possible in this container.

**Fifth session, 2026-07-10 (scheduled routine).** Picked Feature 1 again —
first not-fully-implemented feature in the brief's priority order, and the
next un-actioned item in that priority order since the fourth session. Went
back to the brief's "Autonomy improvements" bullets rather than re-reading
the "explicitly NOT done" list at face value, and found one genuinely
unaddressed, low-risk item: **"Add price confidence labels if data quality
varies."** No such signal existed anywhere in the pricing UI.

Digging into why it mattered here specifically: `OfferPriceService`'s
generic-term fallback (added in an earlier session, `_genericTerm()`)
already broadens a branded/compound search ("Toastbrötchen", "Golden
Toast") to a generic stem when the exact query returns offers from fewer
than 2 retailers, then merges in the stem-matched results so more stores
show up. That's a good recall fix, but the merged results were
indistinguishable from an exact match in the UI — a user searching
"Golden Toast" could be shown a generic "Toastbrötchen" offer at a
different price with no indication it wasn't literally the product they
typed. Cross-product substitution suggestions ("swap to a cheaper
alternative brand") remain correctly out of scope per the fourth session's
note (diet/allergy safety), but *labeling an already-shown broad match as
lower-confidence* is a strictly additive trust fix, not a new
substitution feature.

**What I implemented:**
- `StoreOffer.isBroadMatch` (new field, defaults `false`) +
  `StoreOffer.asBroadMatch()` (new method) in
  `lib/data/models/store_offer.dart` — tags a copy of an offer as having
  been found via generic-term broadening rather than the user's literal
  query.
- `OfferPriceService.searchOffers` (`lib/data/services/offer_price_service.dart`)
  now tags every fallback-sourced offer with `.asBroadMatch()` before
  merging it into the results — the only place broad matches enter the
  system, so every downstream consumer (search suggestions, per-item offer
  chip, basket comparison) now carries the confidence flag automatically.
- `BasketComparison.broadMatchOnlyCount` (new getter,
  `lib/data/models/store_offer.dart`) — counts comparable-basket items
  where *every* offer found for that item, at every store, was only a
  broad match (i.e. no store had a real exact-name match) — the aggregate
  confidence signal for the store-comparison sheet.
- `OfferSuggestionsBar`/`_OfferRow` (`lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart`)
  — broad-match offers in the top-3 add-bar suggestions now show a small
  "Similar product" badge under the retailer line. The "save up to €X"
  header comparison was also tightened to only compare confidently-matched
  (non-broad) offers, so it can no longer claim a saving based on two
  different products' prices.
- `ItemOfferChip` / `_ItemOfferSheet` (`lib/presentation/screens/lists/widgets/item_offer_sheet.dart`)
  — the compact per-item chip appends "· Similar product" when relevant;
  the full offer sheet (shown before a user applies an offer's price to an
  existing item) shows an explicit warning-colored note: "Matched by
  category, not the exact name you typed — double-check it's the right
  product before adding."
- `_StoreComparisonSheet` (`lib/presentation/screens/lists/widgets/list_price_summary_bar.dart`)
  — shows a new note ("{count} item(s) priced from a similar product, not
  an exact name match — worth a quick check") when
  `broadMatchOnlyCount > 0`, next to the existing comparable-basket and
  offers-source disclaimers.
- 4 new EN/DE i18n keys in `lib/core/localization/app_translations.dart`:
  `similar_product_match`, `similar_product_note`, `broad_match_items_note`.

**Explicitly NOT done / known limits of this increment:**
- This labels *broad-term* matches, not general "data quality" in a wider
  sense (e.g. it doesn't flag an offer as lower-confidence just because it
  has no disclosed regular price, or because the retailer's product-name
  formatting is unusually terse) — scoped to the one concrete
  precision-vs-recall tradeoff the codebase actually makes today.
- Cross-product substitution suggestions ("cheaper alternative saves you
  X") remain out of scope, unchanged from the fourth session's assessment —
  still a diet/allergy-safety concern, not attempted here.
- Not verified on a real device/simulator: how the new badge/warning note
  actually renders and wraps at real device widths, or whether the
  generic-term fallback is triggered often enough in practice for a typical
  German grocery list that this label will actually be seen regularly (it
  only shows when the exact query returned offers from fewer than 2
  retailers).

**Files changed (fifth session):**
`lib/data/models/store_offer.dart` (`isBroadMatch`, `asBroadMatch()`,
`broadMatchOnlyCount`),
`lib/data/services/offer_price_service.dart` (tag fallback offers),
`lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart`
(badge, tightened savings comparison),
`lib/presentation/screens/lists/widgets/item_offer_sheet.dart` (chip +
sheet confidence note),
`lib/presentation/screens/lists/widgets/list_price_summary_bar.dart`
(aggregate confidence note),
`lib/core/localization/app_translations.dart` (4 new EN/DE keys).

**Checks performed (fifth session):** See the environment note at the top
of this document for the full `dart analyze`/`flutter test` results.
Summary: 0 errors, 0 new warnings, 610 issues before and after (byte-
identical); every touched file individually analyzer-clean (only the 6
pre-existing `avoid_print` info lints); `flutter test` passes; the new
`asBroadMatch`/`broadMatchOnlyCount` logic verified with a throwaway
4-case `flutter test` file (all passed, not committed, deleted after the
run); `pubspec.lock` churn from `pub get` reverted before committing. No
iOS build/device test possible in this container.

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

**Fifth session, 2026-07-05 (scheduled routine — this feature's dedicated
session).** A real Flutter 3.35.6 toolchain was available this session
(downloaded to `/tmp/flutter`), so every Dart change is verified with
`flutter analyze` — 641 issues before and after (0 errors, 59 warnings, 582
info), byte-identical once line numbers are normalized out: **zero new
issues of any severity**. Went looking for "quick actions" beyond the
widget (the feature title is "Widgets *and quick actions*") and found a
second, much larger root-cause bug of the exact same shape as the widget's:
a real, substantial feature existed entirely as source code and did
**nothing at all** on a real device.

**What was broken:** `ios/Runner/AppIntents.swift` (462 lines — a full Siri
Shortcuts / App Intents implementation: "add item to list", "create list",
"show lists", "search recipes", "show saved recipes", "show recipes", plus
an `AppShortcutsProvider` with real Siri phrases in German and English) has
existed in the repo since the app's early commits. **It was never added to
the Xcode project.** Confirmed by grepping `Runner.xcodeproj/project.pbxproj`
for the filename — zero hits, and there's no `PBXFileSystemSynchronizedRootGroup`
covering `ios/Runner/` (only the widget extension's folder uses that
Xcode-16 auto-sync mechanism) that could have picked it up implicitly. The
file compiled into nothing, shipped in no build, and had zero effect —
Shortcuts app, Siri, and Spotlight never saw any of these six shortcuts,
ever. A second file, `ios/Runner/VoiceAssistantPlugin.swift` (legacy
`INIntent`-based donation), is *also* unbuilt and unregistered, and — not
that it matters, since it's not compiled either — defines its own
`class CreateListIntent: INIntent`, which would collide with
`AppIntents.swift`'s `struct CreateListIntent: AppIntent` if both were ever
added to the same target. Left `VoiceAssistantPlugin.swift` unbuilt
(legacy/superseded, no Dart caller — see below) rather than risk that
collision.

Even had `AppIntents.swift` been compiling all along, it still wouldn't
have worked: `AddItemToListIntent`/`CreateListIntent` wrote "pending"
item/list data into `UserDefaults(suiteName: "group.com.shoply.app")` under
keys `pending_items`/`pending_lists`/`user_lists` — but the Dart side
(`SiriService.dart`) reads a **completely different storage domain**
(`SharedPreferences.getInstance()`, which is `UserDefaults.standard`, not
the App Group suite — the *only* domain shared between an App Intents
extension process and the main app) under **different key names**
(`siri_pending_items`/`siri_pending_lists`). Two independent bugs stacked on
top of the "never compiled" bug: wrong storage suite, wrong keys. A third,
already-wired call site (`home_screen.dart`'s `_checkSiriPendingItems()`,
called from `initState`) has perfectly reasonable find-or-create-list logic
sitting on top of that same permanently-empty `siri_pending_items` source —
so it runs on every app launch and is a harmless no-op, forever, because
its data source can never be written to from an extension process. Three
layered, independent implementation attempts, all dead, none catching the
others' bugs because none of them were ever exercised end-to-end.

**What I implemented:**
- **Compiled `AppIntents.swift` into the `Runner` target.** Verified there
  was no safe automatic way to do this (no synchronized group covers
  `ios/Runner/`), so added it the same way the existing
  `LiquidGlassViewFactory.swift` is wired: one `PBXFileReference`, one
  `PBXBuildFile`, one entry in the Runner group's children, one entry in the
  Runner target's `Sources` build phase — a 4-line diff. To do this safely
  without Xcode available to validate the result, installed the `pbxproj`
  Python library (`pip install pbxproj`) in a venv and used it twice: once
  to dry-run `add_file()` and read back a guaranteed-unique, non-colliding
  GID pair, then discarded that (its own writer reformats the *entire* file,
  which would have made the diff unreviewable), and again afterward to
  parse my hand-written 4-line edit and confirm (a) the file parses as valid
  as a whole, and (b) `AppIntents.swift` ends up in the `Runner` target's
  `Sources` phase only — not `RunnerTests`, not `ShoppingListWidgetExtension`.
  `VoiceAssistantPlugin.swift` was deliberately left out of the project (see
  above).
- **Fixed the App-Group-vs-standard-UserDefaults storage bug at the root**,
  rather than patching either side to match the other's broken convention:
  `AddItemToListIntent`/`CreateListIntent` now hand off to Flutter via a
  deep link (`shoply://add-item?name=...&list=...&quantity=...`,
  `shoply://create-list?name=...`) — the same working pattern the other four
  intents already used (`UIApplication.shared.open(url)`), instead of the
  cross-process UserDefaults queue that could never work. Removed the dead
  `pending_items`/`pending_lists`/`user_lists` bookkeeping entirely rather
  than leaving it as inert clutter next to the real fix.
- **`DeepLinkService`** (`lib/data/services/deep_link_service.dart`) gained
  two callback fields (`onAddItemRequested`, `onCreateListRequested`) set
  once from `app.dart` — the one place in the widget tree with both a
  Riverpod `ref` and the deep-link init call already — since the service
  itself is a plain singleton with no provider access. `_handleDeepLink` now
  intercepts these two action-type hosts before falling through to the
  existing path-based navigation.
- **`app.dart`** implements the actual add-item/create-list logic:
  resolve-by-name against the user's real lists (`userListsProvider`),
  exact case-insensitive match reuses the list, no match creates a new one
  with that name (matching exactly what the Siri dialog told the user would
  happen), then adds the item via the existing `ItemsNotifier.addItem` (same
  Gemini-categorization path as manual entry) and navigates to
  `/list/:id` — the same route the widget's own deep link already uses.
- **Fixed `ListNameQuery.suggestedEntities()`** (Siri's "which list?" picker)
  to read the App Group's `widget_available_lists` key — the real, already-
  live cache `WidgetService.updateAvailableLists` writes on every list load
  — instead of the never-written `user_lists` plain-string array. Siri will
  now actually suggest the user's real lists instead of a hardcoded
  `["Einkaufsliste", "Wocheneinkauf"]` fallback.
- **Fixed two broken deep-link routes** that `AppIntents.swift`'s working
  intents already pointed at, discovered while tracing the flow end-to-end:
  `shoply://recipes` (host `recipes`, no segments) fell through to the
  default case and opened Home instead of the Recipes tab;
  `shoply://recipes/search?q=X` fell through to a nonexistent `/search`
  route. Added explicit `recipes`/`lists` cases to
  `_parseCustomSchemePath`, and threaded the search query through properly:
  `RecipesScreen` now takes an `initialQuery` (set post-frame in `initState`
  — setting `.text` fires the existing search listener synchronously, which
  calls `setState`, so it can't happen during `initState` itself), and
  `app_router.dart`'s `/recipes` route passes `state.uri.queryParameters['q']`
  through. `shoply://recipes/saved` already matched an existing route once
  `recipes` had a case at all.
- **Removed the widget's dead "pending toggles" pull-sync path** — a second,
  smaller instance of the same disease. `WidgetService.getPendingToggles`/
  `clearPendingToggles` (Dart), `AppDelegate.swift`'s matching native
  handlers, and `ItemsNotifier._syncWidgetToggles()` (which called them on
  every single list load) all round-tripped through a `widget_pending_toggles`
  App Group key that **nothing has ever written** — the widget's real
  toggle path (`ToggleItemIntent` → `toggleItemInDefaults` →
  `syncToggleToSupabase`) writes the item state directly and syncs straight
  to Supabase, bypassing this queue entirely. Confirmed zero writers via
  grep across the whole repo (Dart and Swift) before deleting.
- **Corrected `CLAUDE.md`'s iOS Native Components note**, which claimed
  `VoiceAssistantPlugin.swift` was "iOS-only, initialized via `SiriService`"
  — it never was; documented the real (now-fixed) architecture and the
  reason `VoiceAssistantPlugin.swift` stays unbuilt.

**Explicitly NOT done / still open:**
- **The single most important remaining step is the same as last session:
  a real Xcode build.** This session's fix makes `AppIntents.swift` compile
  into the target for the first time ever — that specific claim (it wasn't
  in the project file, now it is, verified by parsing) is about as
  confident as source inspection can be, but only Xcode can confirm it
  actually builds clean, and only a device can confirm Siri/Shortcuts/
  Spotlight actually surface the six shortcuts and that tapping "Add Milch
  to Einkaufsliste" really adds the item.
- **`SiriService.dart`'s method-channel path (`com.shoply.app/siri`) and
  `home_screen.dart`'s `_checkSiriPendingItems()`** are now confirmed-dead
  in a second, independent way (no native code anywhere calls that channel)
  but were left in place rather than deleted this session — they're inert,
  not harmful, and touching `home_screen.dart`'s init flow felt like a
  separate, riskier change than the deep-link fix this session focused on.
  Flagged as a cleanup idea below.
- Still not built: a distinct "today's list" widget, "recently used items"
  quick-add widget, or "Avo suggestion" widget (Feature 5 doesn't exist yet
  to suggest anything from). The existing configurable widget (pick any one
  list) plus the now-working Siri "add item" shortcut cover a meaningful
  slice of "low-friction home-screen actions" without inventing a new
  WidgetKit target this session.
- The two pre-existing, non-blocking issues flagged last session
  (`SavedRecipesWidget` plumbing with no matching WidgetKit widget; the
  widget target's `IPHONEOS_DEPLOYMENT_TARGET = 26.0`) are unchanged —
  still worth a look, not touched here.

**Files changed (fifth session):**
`ios/Runner.xcodeproj/project.pbxproj` (compile `AppIntents.swift` into
`Runner`), `ios/Runner/AppIntents.swift` (deep-link handoff instead of the
broken UserDefaults queue, real list-cache read, dead bookkeeping removed),
`ios/Runner/AppDelegate.swift` (removed dead pending-toggles handlers),
`lib/data/services/deep_link_service.dart` (action-link callbacks,
`recipes`/`lists` routing), `lib/app.dart` (Siri add-item/create-list
handlers), `lib/presentation/screens/recipes/recipes_screen.dart`
(`initialQuery`), `lib/routes/app_router.dart` (`q` query param wiring),
`lib/data/services/widget_service.dart` +
`lib/presentation/state/items_provider.dart` (dead pending-toggles code
removed), `CLAUDE.md` (corrected Siri doc note).

**Checks performed:** Flutter 3.35.6 downloaded fresh
(`storage.googleapis.com`); `flutter analyze` before/after every change,
diffed with line/column numbers normalized out — **byte-identical issue
set** (641 issues: 0 errors, 59 warnings, 582 info; zero new issues of any
severity). Validated the hand-edited `project.pbxproj` by parsing it with
the Python `pbxproj` library (confirms the OpenStep-plist grammar is intact
— a real syntax error would fail to parse, not just look different) and
asserting `AppIntents.swift` lands in exactly one target's `Sources` phase
(`Runner`, not `RunnerTests`/`ShoppingListWidgetExtension`). Traced every
new deep-link route against `app_router.dart`'s actual route table to
confirm each one resolves to a real screen. Confirmed via repo-wide grep
that `widget_pending_toggles` had zero writers anywhere before deleting the
code that read it. **Not run (no macOS/Xcode in this container):** an
actual Xcode build, Siri/Shortcuts appearing on a real device, or the
add-item/create-list flow end-to-end on a device.

**Sixth session, 2026-07-13 (scheduled routine — this feature's dedicated
session).** Feature 1's remaining gaps are genuine external blockers (no
public shelf-price API) and Feature 2 is 95%/device-QA-blocked, so per the
feature order this session picked Feature 3. Re-read the brief's **required**
capability list rather than the "explicitly NOT done" list, and found the
biggest real gap wasn't an autonomy nice-to-have — it was one of the two
literal required capabilities: *"Quick-add item to shopping list from
widget"*. The existing widget (fixed in earlier sessions) can display a list
and toggle items checked/unchecked, but there was **no way to add a new item
without opening the app** — the "quick actions" half of "Widgets and quick
actions" didn't exist yet.

**Why a plain text-entry widget isn't the answer:** WidgetKit interactive
elements are limited to `Button` and `Toggle` (no `TextField`) — a Home
Screen widget fundamentally cannot offer freeform text entry. The realistic
version of "quick-add from widget" is tap-to-add on a small set of
suggestions, which conveniently also satisfies the brief's separately-listed
autonomy idea *"recently used items quick-add widget"* — one feature closes
both asks.

**What I implemented:**
- **New `QuickAddWidget` (Swift, new file
  `ios/ShoppingListWidget/QuickAddWidget.swift`)** — a second WidgetKit
  widget ("Schnell hinzufügen" / Quick Add) registered in the existing
  `ShoppingListWidgetBundle`, systemSmall/systemMedium, reusing the existing
  `SelectListIntent` (same list-picker config as the shopping-list widget) so
  the user can pin it to whichever list they want quick-add suggestions for.
  Shows up to 4 frequently-bought items as tappable rows; tapping one runs
  `QuickAddItemIntent`, which does a **direct Supabase REST insert**
  (`POST /rest/v1/shopping_items`) using the same cached-credentials pattern
  `ToggleItemIntent`/`syncToggleToSupabase` already established for
  checkbox toggling — the widget process has no Flutter/Dart runtime, so it
  can't call `ItemRepository.addItem()`; it has to talk to Supabase directly.
  On a successful insert, the new item is also appended to the widget's own
  cached copy of that list (`widget_list_<id>`) so the shopping-list widget
  reflects it immediately instead of waiting for its next 30-minute timeline
  refresh — mirrors how `toggleItemInDefaults` already updates the local
  cache eagerly. Fails open and silent on any error (missing/expired
  credentials, network failure), same as the existing toggle sync — a failed
  tap just does nothing rather than crashing the widget.
- **Data source: reused, not reinvented.** `PurchaseTrackingService.getFrequentItems()`
  already existed (used by `RecommendationService` for in-app "you might also
  need" suggestions) and does exactly the aggregation a "recently/frequently
  used items" widget needs (`item_purchase_stats`, ≥2 purchases, sorted by
  count) — no new backend logic was written for this.
- **`WidgetService.updateRecentItems()`** (new,
  `lib/data/services/widget_service.dart`) + `WidgetRecentItem` model —
  pushes up to 8 frequent items (title-cased for display; purchase stats are
  stored lowercase) to the App Group via a new `updateRecentItems` method
  channel call. Wired into `ListsNotifier.loadLists()`
  (`lib/presentation/state/lists_provider.dart`) right next to the existing
  `_updateWidgetAvailableLists()` call, so the widget's suggestions refresh
  on every app foreground and every realtime item-change event, same
  cadence as the list-selection cache. Best-effort/`unawaited`: a failed
  purchase-stats fetch never blocks list loading.
- **`AppDelegate.swift`** gained the native handler for `updateRecentItems`
  (writes `widget_recent_items` to the App Group, reloads the
  `QuickAddWidget` timeline) and `updateSupabaseCredentials` now also stores
  a `widget_supabase_user_id` key — required because a direct widget-side
  insert needs a value for `shopping_items.added_by`, which the widget
  process has no other way to obtain. `home_screen.dart`'s
  `_syncWidgetCredentials()` now passes `SupabaseService.instance.currentUser?.id`
  through.
- Confirmed via reading `project.pbxproj` directly (not guessed) that
  `ios/ShoppingListWidget` is a `PBXFileSystemSynchronizedRootGroup` with
  only `Info.plist` excluded from the build-sources membership exception
  list — meaning the new `QuickAddWidget.swift` file needed **zero**
  project-file edits to compile into the extension target, unlike the
  higher-risk manual `project.pbxproj` surgery the fifth session had to do
  to get `AppIntents.swift` into the main `Runner` target (which has no such
  synchronized group).

**Explicitly NOT done / known limits of this increment:**
- **Not verified on a real device/simulator** — no macOS/Xcode in this
  container, same limitation every prior Feature 3 session has flagged. This
  is the single most important thing to check before considering this done:
  does the widget actually appear in the widget gallery, does the tap-to-add
  button work, does the new item show up in the app.
- **Cached Supabase access token can expire.** `_syncWidgetCredentials()`
  only refreshes the App Group's cached token on app launch / auth-state
  change, not on Supabase's background token refresh — so a widget tap more
  than ~1 hour after the app was last opened could hit an expired-token 401
  and silently no-op. This is a **pre-existing** limitation of the toggle-sync
  design this session's insert reuses, not a new one — flagged as a shared
  idea below rather than fixed here, since fixing it properly means the app
  proactively re-pushing the token on every Supabase auth refresh event, a
  change that would also benefit the existing checkbox-toggle sync and felt
  like more than this session's one-widget scope.
- **No duplicate-merge check on quick-add.** The app's own `addItem()` merges
  into an existing unchecked item with the same name; the widget's direct
  REST insert always creates a new row. Tapping "Milch" twice quickly (or
  once from the widget when "Milch" is already unchecked on the list) creates
  two rows instead of bumping quantity. Accepted as a v1 tradeoff — a
  merge-safe insert would need an extra round-trip GET before the POST,
  adding latency to a widget interaction that should feel instant.
- **New suggestions need ≥2 real purchases** (`getFrequentItems`'s existing
  threshold) before they show up — a brand-new user's Quick-Add widget shows
  the "Noch keine Vorschläge" (no suggestions yet) empty state until they've
  completed a couple of real shopping trips. Not a bug, just worth knowing
  when testing on a fresh account.
- Did **not** touch the two smaller pre-existing issues flagged by earlier
  sessions (dead `SiriService.dart` method-channel/`_checkSiriPendingItems()`
  code; the widget extension's `IPHONEOS_DEPLOYMENT_TARGET = 26.0` vs.
  Runner's `15.6`/`13.0`) — both are unrelated to the required-capability gap
  this session closed, and touching either felt like scope creep into
  low-value/higher-risk cleanup rather than the one selected feature.

**Files changed (sixth session):**
`ios/ShoppingListWidget/QuickAddWidget.swift` (new — widget, timeline
provider, quick-add intent, direct REST insert),
`ios/ShoppingListWidget/ShoppingListWidget.swift` (register `QuickAddWidget()`
in the bundle), `ios/Runner/AppDelegate.swift` (`updateRecentItems` handler,
`userId` in `updateSupabaseCredentials`), `lib/data/services/widget_service.dart`
(`updateRecentItems()`, `WidgetRecentItem`, `userId` param),
`lib/presentation/state/lists_provider.dart` (push recent-item suggestions
on every list load), `lib/presentation/screens/home/home_screen.dart`
(pass `userId` to the widget credentials sync).

**Checks performed (sixth session):** See the environment note at the top of
this document. Summary: Flutter 3.35.6 downloaded fresh; `dart analyze`
byte-identical before/after (610 issues, 0 errors, 0 new warnings/info);
`flutter test` passes; the three touched/new Swift files verified with a
custom string/comment-aware brace-balance checker (no Swift toolchain
available in this container) and by manually diffing every new pattern
(REST insert, App Group read/write, `AppIntentTimelineProvider` conformance)
against the already-compiling code it was modeled on
(`ToggleItemIntent`/`syncToggleToSupabase`/`ShoppingListProvider`);
confirmed via direct `project.pbxproj` inspection that the new widget file
needs no project-file changes to build. `pubspec.lock` churn from `pub get`
reverted before committing. **Not run (no macOS/Xcode in this container):**
an actual Xcode build, the widget appearing in the widget gallery, or a
live on-device quick-add tap.

**Seventh session, 2026-07-16 (scheduled routine, second run of the day —
this feature's dedicated session).** Selected per the priority order (see
the selection note at the top of this file). Scope: the two ways the
widget's shared-container state could go stale or leak — credential
freshness while signed in, and data hygiene on sign-out.

**What I implemented:**

1. **Token re-push on every Supabase token refresh** (the Ideas-list item
   from the sixth session, recommendation-`yes` — now done). Both
   widget-side REST calls (the existing checkbox-toggle sync and the
   Quick-Add insert) authenticate with an access token cached in the App
   Group, which until now was only written by `home_screen.dart`'s
   `_syncWidgetCredentials()` on app launch / user change. Supabase access
   tokens expire after ~1h, so any widget tap later than that silently
   no-oped until the next app open. Now:
   - `WidgetService.syncCredentialsFromSession({Session? session})` (new,
     `lib/data/services/widget_service.dart`) — the one shared
     implementation: reads the given session (or
     `SupabaseService.instance.currentSession`), no-ops on null or
     non-iOS, pushes url/anonKey/accessToken/userId via the existing
     `updateSupabaseCredentials` channel call.
   - `main.dart`'s existing global `onAuthStateChange` listener now calls
     it on `initialSession`, `signedIn`, and `tokenRefreshed` (fire-and-
     forget via `unawaited` — a failed push must never affect auth
     handling). Placing this in the **global** listener rather than
     `home_screen.dart`'s (which the original idea suggested) means it
     fires no matter which screen is mounted when the SDK refreshes the
     token mid-session — home_screen's listener only reacts to user-id
     *changes*, and a refresh isn't one.
   - `home_screen.dart`'s `_syncWidgetCredentials()` now just delegates to
     the shared helper (same behavior on its existing launch/user-change
     call sites; duplicated credential-assembly logic removed, and its
     now-unused `env.dart` import dropped).
   - Honest limit: this keeps the cached token fresh **while the app
     process is alive** (foreground or briefly backgrounded — Supabase's
     auto-refresh runs ~every 50min in-process). A widget tap hours/days
     after the app was last alive still hits an expired token and no-ops.
     The genuinely-always-fresh alternative — the widget process using the
     refresh token itself — was deliberately NOT built: Supabase rotates
     refresh tokens on use, and two processes independently refreshing the
     same token family risks revoking the user's whole session (a logout
     bug is far worse than a no-op tap). Flagged in the ideas list below.

2. **Widget data + credentials now actually cleared on sign-out.**
   `WidgetService.clearWidget()` existed since the widget was first built
   but had zero call sites, and its native handler only removed
   `widget_shopping_list` + `widget_saved_recipes` — not the per-list
   caches (`widget_list_<id>`) the configurable widget actually renders
   from, not `widget_available_lists` (which Siri's list picker also
   reads), not `widget_recent_items`, and not the four cached credential
   keys. Net effect: after sign-out, a home-screen widget kept displaying
   the signed-out account's shopping list indefinitely — a real privacy
   gap on shared/handed-over devices, and stale-credential clutter
   besides. Now:
   - `AppDelegate.swift`'s `clearWidgetData` sweeps **every** App Group
     key with the `widget_` prefix (verified by grep that every key this
     app writes to the shared container uses it), then reloads all widget
     timelines — widgets drop to their signed-out empty state immediately.
   - `main.dart`'s `signedOut` handler calls `WidgetService.clearWidget()`
     (first-ever call site).
   - Race-checked the surrounding sign-out flow: `home_screen`'s listener
     fires `loadLists()` on user change, which on a signed-out client can
     only write *empty* available-lists/recent-items arrays — so whichever
     order the two handlers run in, nothing of the previous account
     survives. On account *switch*, `signedOut` clears and the subsequent
     `signedIn` + list load repopulate for the new user.

**Explicitly NOT done / known limits:**
- The two standing cleanup ideas (delete the confirmed-dead
  `SiriService.dart` method-channel path + `_checkSiriPendingItems()`;
  delete `VoiceAssistantPlugin.swift`) — both explicitly ask to be their
  own tiny, isolated change, not bundled with a feature-shipping session.
  Unchanged.
- The "today's list" / new widget-kind ideas — still marked needs-decision.
- Widget taps after the app process has been dead for >1h still silently
  no-op (see the honest limit above — a deliberate safety tradeoff, now
  documented as its own idea below rather than half-fixed).
- The `IPHONEOS_DEPLOYMENT_TARGET = 26.0` question on the widget target is
  unchanged — still worth checking in a real Xcode session.

**Files changed (seventh session):**
`lib/data/services/widget_service.dart` (`syncCredentialsFromSession`),
`lib/main.dart` (credential re-push on initialSession/signedIn/
tokenRefreshed; `clearWidget()` on signedOut),
`lib/presentation/screens/home/home_screen.dart` (`_syncWidgetCredentials`
delegates to the shared helper; unused import dropped),
`ios/Runner/AppDelegate.swift` (`clearWidgetData` prefix sweep).

**Checks performed (seventh session):** See the environment note at the top
of this document. Summary: Flutter 3.35.6 downloaded fresh; full-project
`flutter analyze` byte-identical before/after via `git stash` baseline (610
issues: 0 errors, 59 warnings, 551 info; line numbers normalized out of the
diff); `flutter test` passes ("All tests passed"); `AppDelegate.swift`
verified with the string/comment-aware brace/paren/bracket-balance checker
(all balanced) — the Swift edit is a small mechanical change inside an
existing function, using only APIs already used elsewhere in the same file;
`pubspec.lock` churn reverted before committing. **Not run (no macOS/Xcode
in this container):** an Xcode build; a real token-refresh → widget-tap
round trip; a real sign-out → widget-shows-empty check on device.

**Eighth session, 2026-07-17 (scheduled routine — this feature's dedicated
session).** Per the priority order, Feature 1 (~95%, blocked on genuine
external constraints — no public shelf-price API, cross-product substitution
out of scope) and Feature 2 (~95%, device-QA-only) were re-confirmed as
having no unblocked buildable-here work, same precedent prior sessions
established. Feature 3 is the first feature genuinely marked "In progress,"
and its own Ideas list carried exactly one fully-scoped, unconditional
recommendation-`yes` item with no owner decision or device-QA prerequisite
attached: **"Remove the confirmed-dead Siri method-channel plumbing"** (the
sixth/seventh sessions' Ideas entry) — explicitly asking to be done "as its
own tiny, isolated change," which is exactly this session's scope. The
broader idea right below it (deleting `VoiceAssistantPlugin.swift` too) was
deliberately **not** done — that one's own recommendation text says to wait
until the fifth session's `AppIntents.swift` deep-link fix is confirmed
working on a real device, which still hasn't happened in this container.

**What I implemented — pure dead-code removal, re-verified reachability
before deleting anything (not trusting the prior sessions' audit at face
value):**
- Grepped the whole repo (Dart *and* Swift/`ios/`) for
  `SiriService`/`siri_service`/`com.shoply.app/siri` — confirmed, as the
  fifth and seventh sessions already found, that **no native code anywhere**
  registers or calls that method channel, and the only two Dart call sites
  left were `main.dart`'s `SiriService().initialize()` (sets up the
  never-answered channel handler and fires a `syncLists` call into the void)
  and `home_screen.dart`'s `_checkSiriPendingItems()` (reads a
  `SharedPreferences` key, `siri_pending_items`, that nothing has ever
  written to, since the only would-be writer lived in an App Group
  `UserDefaults` suite `SiriService.dart` never actually read from — the
  process-boundary bug the fifth session already diagnosed in detail).
  Every other public method on `SiriService` (`donateAddItemInteraction`,
  `donateRecipeSearchInteraction`, `donateSavedRecipesInteraction`,
  `getPendingSiriAction`, `getPendingLists`, `updateUserLists`) had **zero**
  callers anywhere in the repo, confirmed via grep before removal.
- **Deleted `lib/core/services/siri_service.dart` outright** (349 lines) —
  once its only two call sites are gone, every one of its methods only
  serves the same dead channel/dead-SharedPreferences-key round trip, so
  there was nothing in the file left to keep.
- **`lib/main.dart`**: removed the `import 'package:shoply/core/services/siri_service.dart'`
  and the `if (Platform.isIOS) { await SiriService().initialize(); }` block
  from `_initializeServicesInBackground()`.
- **`lib/presentation/screens/home/home_screen.dart`**: removed the
  `_checkSiriPendingItems()` call from `initState`'s post-frame callback and
  deleted the method itself (82 lines — the find-or-create-list-then-add-item
  logic that could never run because its input source could never be
  written to), plus the now-unused `siri_service.dart` and
  `category_detector.dart` imports (the latter was only used inside the
  deleted method's `CategoryDetector.detectCategory(itemName)` call).
- **Corrected `CLAUDE.md`'s iOS Native Components note**, which still
  referenced `SiriService.dart`'s method-channel path as existing-but-dead —
  updated to say it's now fully removed, not just orphaned.
- Deliberately did **not** touch `ios/Runner/VoiceAssistantPlugin.swift` (per
  the broader idea's own device-QA gate, see above) — it remains unbuilt and
  unregistered in the Xcode project, exactly as before this session.

**Why this was worth doing now rather than leaving it flagged again:** three
independent sessions (fifth, sixth/seventh's idea write-up, and this one's
own re-verification) had each confirmed this exact code path dead by
whole-repo grep with zero live callers found — the risk this idea's own
write-up worried about (accidentally breaking something by touching
`home_screen.dart`'s `initState` ordering) turned out to be low in practice:
removing the call was a one-line deletion with no reordering of the
remaining calls, and `flutter analyze`/`flutter test` catch a broken
reference immediately (see Checks below). Leaving three confirmed-dead
implementations of the same already-superseded feature sitting in the
codebase is exactly the kind of trap the fifth session's own history
warns about ("the fifth session almost built on top of the wrong one before
tracing the process boundary all the way through").

**Explicitly NOT done / still open:**
- `ios/Runner/VoiceAssistantPlugin.swift` (unbuilt, unregistered, no Dart
  caller) is still present — its own idea explicitly wants the
  `AppIntents.swift` deep-link fix confirmed on a real device first, which
  remains blocked on this container having no macOS/Xcode.
- The "today's list" / "recently used items as a distinct widget kind"
  ideas are unchanged — still marked needs-decision.
- The `IPHONEOS_DEPLOYMENT_TARGET = 26.0` widget-target question is
  unchanged.
- The single most important remaining step for Feature 3 overall is still
  the same as every prior session: a real Xcode build + on-device test of
  the widget, the Siri/Shortcuts intents, and the token-refresh/sign-out
  credential handling shipped in the sixth/seventh sessions.

**Files changed (eighth session):** `lib/main.dart` (removed `SiriService`
init), `lib/presentation/screens/home/home_screen.dart` (removed
`_checkSiriPendingItems()` + its call site + 2 now-unused imports),
`CLAUDE.md` (corrected Siri doc note). **Deleted:**
`lib/core/services/siri_service.dart`.

**Checks performed (eighth session):** Flutter 3.35.6 downloaded fresh into
`/tmp/flutter`. Baseline taken from a separate `git worktree` checked out at
this session's starting commit (`git stash` hit a pathspec error against the
already-`git rm`'d file, so a worktree was used instead for a clean,
uncontaminated baseline) — `flutter analyze`: **610 issues (0 errors, 59
warnings, 551 info)**. After this session's changes: **603 issues (0 errors,
59 warnings, 544 info)**. Diffed both outputs with line/column numbers
normalized out: every one of the 7 fewer issues is fully accounted for and
none are new-elsewhere regressions — 6 `empty_catches` info lints that lived
entirely inside the now-deleted `siri_service.dart`, plus one genuine
pre-existing bug that left with the deleted `_checkSiriPendingItems()`
method: an `await_only_futures` warning on `await listsAsync.whenData(...)`
(`whenData` returns `void`/`Null`, not a `Future` — awaiting it was already a
no-op bug in the dead code, not something this session introduced). Zero new
issues of any severity anywhere else in the project. `flutter test` passes
("All tests passed"). Grepped the full repo (Dart + `ios/`) for every
`SiriService`/`siri_service`/`com.shoply.app/siri` reference before and
after deleting, confirming zero remaining live references outside this
Markdown file and `CLAUDE.md`. `pubspec.lock` churn from `pub get` reverted
before committing. **Not run (no macOS/Xcode in this container):** an actual
Xcode build — though this change is pure Dart-side deletion with no Swift
edits, so the existing device-QA backlog for Feature 3 is unchanged in
scope, not added to.

**Ninth session, 2026-07-19 (scheduled routine — this feature's dedicated
session).** Per the selection note at the top of this file: rather than
picking from the Ideas list (nothing left there is unconditionally
buildable-here), re-read Feature 3's own "Explicitly NOT done" history
across all eight prior sessions line by line and picked the one item every
session from the fourth onward had flagged as "worth double-checking" but
none had actually investigated: the widget extension's unusually high
`IPHONEOS_DEPLOYMENT_TARGET`.

**What investigating it found — a real, high-severity regression, same shape
as the entitlements bug the very first Feature-3 session fixed:**
`ios/Runner.xcodeproj/project.pbxproj`'s `ShoppingListWidgetExtension` target
(the one that builds both `ShoppingListWidget` and `QuickAddWidget`, via the
shared `ShoppingListWidgetBundle`) had `IPHONEOS_DEPLOYMENT_TARGET = 26.0` in
all three build configs (Debug/Release/Profile), while `Runner` itself is
`15.6` and the project-level default is `13.0`. `IPHONEOS_DEPLOYMENT_TARGET`
is a hard *minimum OS* requirement enforced by the App Store and iOS itself —
not a "nice to have latest SDK" setting — so as configured, the widget
extension could never be installed, never appear in the widget gallery, and
never run on **any device below iOS 26**, independent of and stacking on top
of every previous session's entitlements/App-Intents/token-refresh fixes.
Given iOS 26 is very recent, this alone is a fully sufficient explanation for
"widgets have not worked before" that survives even after the App Group
entitlement was restored (first session) — nobody except a fresh-iOS-26
device could ever have seen the widget work at all.

Traced why `17.0` (not `13.0`/`15.6`, matching the rest of the project) is
the correct, real minimum rather than guessing: `ItemRowView` in
`ShoppingListWidget.swift` (line 372) and `QuickAddRow` in
`QuickAddWidget.swift` (line 230) both call `Button(intent:)` — WidgetKit's
interactive-button API, introduced in iOS 17.0 — **unconditionally, with no
`#available` guard**. Both files already have a properly-guarded
`if #available(iOS 17.0, *) { .containerBackground(...) } else { ... }`
fallback for a *different* iOS-17-only API (the widget's background
modifier), proving the code was written iOS-17-aware for that API but the
project's deployment target was never set to actually match it — with
`CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE` already set in the same
build config, an unguarded `Button(intent:)` call is exactly the kind of
thing that would only silently compile if the deployment target already sat
at ≥ 17 (as it did, just wrongly at 26 instead of 17).

**What I fixed:** changed all three
`IPHONEOS_DEPLOYMENT_TARGET = 26.0;` occurrences (`project.pbxproj` lines
957, 1005, 1050 — Debug/Release/Profile of `ShoppingListWidgetExtension`) to
`17.0`. A minimal, mechanical 3-line diff — same "smallest correct change to
the exact value that broke it" spirit as the first session's entitlements
fix.

**Verification performed (no macOS/Xcode in this container, same
constraint every Feature-3 session has had):**
- Installed the `pbxproj` Python library in a fresh venv (same tool the
  fifth session used to safely add `AppIntents.swift` to the `Runner`
  target) and parsed the edited file: all three Xcode targets
  (`RunnerTests`, `Runner`, `ShoppingListWidgetExtension`) load without
  error, confirming the OpenStep-plist grammar is still intact (a real
  syntax error from a bad edit would fail to parse, not just render
  differently).
- Walked the parsed object graph per-target, per-config, to confirm the
  actual `IPHONEOS_DEPLOYMENT_TARGET` values landed exactly where intended:
  `Runner` Debug/Release/Profile all read `15.6` (untouched), `RunnerTests`
  reads `None`/inherits the project default, `ShoppingListWidgetExtension`
  Debug/Release/Profile all read `17.0` (fixed) — confirming the edit
  touched only the intended target and didn't accidentally also change
  `Runner`'s or the project-level default via a stray match.
- Traced every interactive-widget API call site (`Button(intent:)` in both
  widget Swift files) against Apple's documented iOS-17 introduction to
  justify `17.0` specifically rather than picking an arbitrary lower number;
  confirmed no iOS 18+-only APIs are used anywhere in
  `ios/ShoppingListWidget/` (grepped for `@available(iOS` — the widget
  files have none; the two `#available(iOS 17.0, *)` runtime checks already
  in the code are the only version-gating present, and they're now
  consistent with the corrected deployment target instead of permanently
  dead code).
- Confirmed via `git diff` the change touches exactly the 3 lines intended,
  nothing else in the 1000+ line project file.
- **Not run (no macOS/Xcode in this container, unchanged constraint):** an
  actual Xcode build, or confirming on a real sub-iOS-26 device that the
  widget now actually appears in the gallery. This is the single most
  important thing to verify next — arguably more important than any prior
  Feature-3 device-QA item, since if this diagnosis is correct, no widget
  functionality fixed by any earlier session could have been observed
  working on a real device until now.
- No Dart files were touched this session, so `flutter analyze`/`flutter
  test` (which prior sessions ran because they touched `lib/`) don't apply
  here; no Flutter toolchain was downloaded for a change scoped entirely to
  one Xcode project-file value.

**Explicitly NOT done / still open:**
- Everything else already flagged by prior sessions is unchanged: the
  `VoiceAssistantPlugin.swift` deletion still waits on real-device
  confirmation of the `AppIntents.swift` deep-link fix; the "today's list"
  widget kind remains needs-decision; the widget-side "token stale" UX idea
  remains needs-decision.
- Did not lower the deployment target further than `17.0` (e.g., to match
  Runner's `15.6`) — that would require either removing the interactive
  `Button(intent:)` widgets entirely (a real feature regression, worse than
  the status quo) or wrapping every interactive element in an
  `#available(iOS 17.0, *)` branch with a non-interactive fallback view for
  iOS 13–16 (a real, larger feature addition — a "read-only widget for
  older iOS" tier — not something to improvise without device verification).
  Flagged as an idea below for an explicit decision rather than guessed at.

**Files changed (ninth session):** `ios/Runner.xcodeproj/project.pbxproj`
(3-line `IPHONEOS_DEPLOYMENT_TARGET` fix), `FEATURE_IMPLEMENTATION_STATUS.md`.

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

**Seventh session, 2026-07-06 (scheduled routine — this feature's dedicated
session).** Feature 6 now exists, which unblocked the one required Feature-4
capability that had been waiting on it: "AI can interact with calorie
tracking once implemented." Per the feature order this was the first
feature in sequence with genuinely unblocked work (Features 1–3's remaining
gaps all need external APIs or a real device/Xcode). Real Flutter 3.35.6
toolchain (`/tmp/flutter`); analyzer baseline byte-identical before/after
(608 issues, 0 errors, 59 warnings), `flutter test` passes.

*What was added (same typed-function-calling architecture, additive only):*
- **`get_nutrition_status`** — today's consumed calories/protein/carbs/fat
  + water, the goal targets, remaining amounts (negative = over budget,
  Gemini phrases it), goal type, and every diary entry with its `entry_id`
  (so "what did I eat today" and entry deletion both work). Honest
  states: reports `tracking_enabled: false` (with instructions to offer
  enabling, never auto-enable) and `goal_configured: false` (totals
  without targets, points at goal setup) instead of guessing.
- **`log_food`** — "I just ate a banana" / "log 200g chicken for lunch".
  If the user stated calories/macros they're used verbatim; otherwise a
  one-shot Gemini JSON estimate (same pattern as the existing recipe
  nutrition estimator) fills them in and the entry is flagged
  `estimated: true`, with a system-prompt rule to tell the user it's an
  estimate. Meal type comes from the user or is inferred from time of
  day. Returns fresh "consumed today / remaining" so Avo can say "that
  puts you at 1,450 of 2,100 kcal." Writes through the existing
  `FoodLogService` (source `manual`), then invalidates the nutrition
  providers so the dashboard updates live.
- **`log_water`** ("I drank a glass of water" — glass/bottle sizes hinted
  in the tool description, clamped 1–3000 ml) and **`log_weight`**
  (validated 20–400 kg, upserts today's row via the existing per-day
  upsert, returns the previous weight + goal target so Avo can mention
  progress).
- **`delete_food_log`** — same two-step confirmation pattern as
  delete_item/delete_list: first call returns a question, deletion only
  happens after an explicit confirm=true.
- **`calorie_tracking` settings key in `AvoSettingsBridge`** — "Avo,
  turn on calorie tracking" now flips the same local preference the
  profile toggle and onboarding opt-in use (tab appears/disappears
  immediately since `MainScaffold` watches that provider). All nutrition
  tools are gated on it: when off they log/read nothing and tell Gemini
  to offer enabling it first.
- **Calorie-aware recipe suggestions** — `search_recipes` results now
  include `calories_per_serving` when the recipe has stored nutrition,
  and the system prompt wires the "what can I still eat today?" flow:
  get_nutrition_status → search_recipes → prefer recipes fitting the
  remaining calories, always saying kcal.

*Verification:* full-project `flutter analyze` before/after —
byte-identical 608-issue baseline, zero new issues of any severity;
`flutter test` passes. Every new tool's argument names checked against its
Schema declaration; all service calls verified against the real Feature-6
service signatures (no new DB access paths were invented — everything goes
through the same services the calorie UI already uses, so RLS coverage is
identical). **Not run:** a live Gemini conversation (needs a real API key
in `env.dart` + device), so tool-routing quality (does flash-lite pick the
right tool for "wie viele Kalorien habe ich noch?") needs a manual QA pass.

**Eighth session, 2026-07-09 (scheduled routine, second run of the day —
this feature's dedicated session).** Selected per the feature order:
Features 1–3's remaining gaps still need external APIs or a real
device/Xcode, and Feature 4 had the one documented item that just became
unblocked — "Onboarding-guidance tools still blocked on Feature 7" — since
Feature 7's goal questionnaire + `NutritionGoalCalculator` wiring shipped
yesterday. Real Flutter 3.35.6 toolchain; full-project `flutter analyze`
verified before/after via `git stash` (zero new issues of any severity);
`flutter test` passes.

*What was added (same typed-function-calling architecture, additive only):*
- **`get_user_profile`** (read tool) — Avo previously had *write* access to
  settings via `update_setting` but no way to READ current state beyond the
  context string (which only carries diet/allergies/name). The new tool
  returns name, age, gender, height, diet preferences, allergies, language,
  theme, notifications on/off, calorie-tracking on/off, manual zip code, and
  a goal summary (type + calorie/macro targets) when one is configured —
  with honest `'not set'` markers so Gemini knows what it may ask about vs.
  what it already knows. Deliberately reads only the *manual* zip
  (`getManualZipCode`), never `getZipCode()`, so a profile read can never
  trigger a GPS permission prompt mid-chat.
- **`setup_nutrition_goal`** — the actual "AI can guide the user through
  onboarding/preferences" capability. Before this session, when
  `get_nutrition_status` reported `goal_configured: false` the only thing
  Avo could do was point the user at the calories tab. Now the goal
  questionnaire runs conversationally: the tool takes whatever is known
  (goal type, gender, age, height, weight, target weight, timeline,
  activity level), prefills the rest from the profile / existing goal /
  latest weight-log entry (the *same* prefill sources and priority as
  `GoalSetupScreen._loadExisting()`), and returns a `missing` list so
  Gemini asks only for genuinely unknown fields (system prompt: at most two
  questions per message, conversational, never a form). When complete it
  calculates targets via the *same* `NutritionGoalCalculator` (no
  duplicated math), saves through `NutritionGoalService.saveGoal`, logs the
  current weight, syncs age/height/gender back onto the profile, and
  invalidates the same providers — mirroring `GoalSetupScreen._save()`
  line for line. Replacing an already-configured goal uses the established
  two-step confirmation pattern (first call returns a question naming the
  old goal + kcal target; only `confirm_replace=true` saves), including an
  explicit instruction to re-pass all field values on the confirm call so
  the prefill can't silently resurrect the old goal type.
- **`zip_code` setting key** (`AvoSettingsBridge` + `update_setting`
  schema) — fixes a real dead-end: `search_offers` used to respond "ask the
  user to set their zip code in Profile settings"; now Avo asks for the PLZ
  and sets it directly (validated 4–5 digits, empty clears, writes through
  the same `UserLocationService.setManualZipCode` the zip sheet uses), then
  can immediately re-search offers. The `search_offers` no-location note
  now routes to this instead of to the settings screen.
- **Dead-end note fixes**: `get_nutrition_status`'s no-goal note now offers
  the in-chat setup flow; system-prompt routing rules added for both new
  tools (profile-read-first, ask-only-missing, confirm-replace).

*Verification (eighth session):* full-project `flutter analyze` before
(`git stash`: 610 issues, 0 errors, 59 warnings) and after (610 issues, 0
errors, 59 warnings) — the issue sets are **identical** once line numbers
are normalized out, i.e. zero new issues of any severity from this
session's additions. `flutter test` passes ("All tests passed"). A
throwaway `flutter test` file (5 cases, all passed, not committed)
exercised `NutritionGoalCalculator` with the exact input shapes the new
tool passes (maintain with no target weight, lose_weight with target +
timeline produces a real deficit, extreme-short-timeline safety floor
holds), the zip-code validation regex (valid 4/5-digit, rejects
letters/too-short/too-long), and the timeline clamp. Every service call in
the new tools was traced against the real signatures
(`NutritionGoalService.saveGoal`, `WeightLogService.logWeight/getLatest`,
`UserService.instance.updateUserProfile`,
`UserLocationService.setManualZipCode/getManualZipCode`,
`MascotNotificationService.rearmDinnerIdeasReminder`) — no new DB access
paths were invented, so RLS coverage is identical to the existing goal/
profile screens. **Not run (no device/API key here):** a live Gemini
conversation confirming flash-lite routes goal-setup requests to the new
tools and carries field values across the multi-turn ask-missing-fields
loop — this is the most important manual QA item for this session's work.

**Ninth session, 2026-07-19 (scheduled routine, second run of the day —
this feature's dedicated session).** Fresh-discovery audit of the actual
tool registry against the brief's required-capability list (rather than
trusting the section's own "Implemented" status) found that the registry's
item/list write surface was **add/check/delete-only**: the brief requires
"AI can add, *edit*, remove, and *organize* items" and "AI can *change
shopping lists*", but there was no way for Avo to edit an existing item
(rename / quantity / unit / note), move items between lists, create a new
list, or rename a list. Four new tools close that gap — same typed
function-calling architecture, additive only, zero new DB access paths:

- **`update_item`** — edits name/quantity/unit/notes of a list item.
  Writes through `ItemsNotifier.updateItem` with the *exact same* update
  keys the list detail screen's own edit sheet writes (`name`, `quantity`,
  `unit`, `notes`; empty string clears unit/note to null, blank rename and
  non-positive quantities are ignored rather than written). Only the
  fields the model passes are touched; an all-empty call returns an error
  instead of a no-op write. Non-destructive → no confirmation step, same
  as the UI's own edit sheet.
- **`move_items`** — moves one or more items to another list by updating
  `shopping_items.list_id`, which keeps the item's id, checked state,
  category, and price fields intact (vs. a delete+re-add, which would
  lose them). **RLS verified live before choosing this design** (Supabase
  MCP, `pg_policy` on `shopping_items`): the UPDATE policies use a
  `USING` clause scoped to lists the user owns/is a member of, with no
  separate `WITH CHECK` — in Postgres the `USING` expression then applies
  to the *new* row too, so moving is permitted exactly when the user is a
  member of **both** source and destination lists, and fails closed (0
  rows / PostgrestException) for a foreign destination. A mid-loop
  failure reports partial progress honestly ("moved N of M") instead of
  discarding the count. Invalidates both lists' item providers + the list
  summaries after the move.
- **`create_list`** — `ListsNotifier.createList`; returns the new
  `list_id` plus a hint so Gemini can chain "create a party list and add
  chips and dip" into create → add_item_to_list in one turn.
- **`rename_list`** — `ListsNotifier.updateList(listId, {'name': …})`,
  the same call the list screen's own rename dialog makes.
- System-prompt routing rules for all four (edit → only changed fields,
  resolve item ids via get_list_contents first; move → resolve ids and
  destination via get_list_contents/get_lists; create → chain adds onto
  the returned list_id; rename).

*Deliberate scope choices:* no confirmation step for any of the four —
they're edits, not destructions (delete_item/delete_list keep theirs), and
every one of them is user-reversible in-app; `move_items` deliberately does
**not** pre-validate the destination against the service's `_fetchLists`
helper (that helper only returns *owned* lists — a shared list the user is
merely a member of is a perfectly valid move target that RLS alone
correctly permits); item `order_index` is left untouched on move (the
destination list sorts moved items by their existing/absent index — same
behavior as items created before ordering existed, no interleaving bug,
just appended-feeling placement).

*Verification (ninth session):* Flutter 3.35.6 (`/tmp/flutter`, cached from
the morning session); full-project `flutter analyze` baseline via `git
stash` **601 issues (0 errors, 59 warnings)** vs. after-change **601
issues — byte-identical** with line numbers normalized out; `dart analyze`
scoped to the one touched file: **No issues found**. `flutter test` passes
("All tests passed", 11 tests). The `update_item` argument-normalization
logic (trim-then-rename, blank-rename excluded, quantity 0/negative
excluded, Gemini-int → double, empty-string-clears-unit/note, no-op →
error) was verified with a throwaway `dart run` script mirroring the exact
expressions — 10/10 cases passed (not committed, deleted). RLS policies
for the `list_id`-change move verified live via Supabase MCP (see above).
`pubspec.lock` churn from `pub get` reverted before committing. **Not run
(no device/API key here):** a live Gemini conversation confirming
flash-lite routes "verschieb die Butter auf die Party-Liste" / "mach mir
eine Liste fürs Wochenende" to the new tools — same manual QA item as
every prior Feature 4 session.

**Explicitly NOT done:**
- Assistant-owned memory/preferences across sessions — architecturally this
  would mean persisting a summary or key facts to Supabase and re-injecting
  them, similar to how diet/allergies already work; not implemented this
  session (flagged as an idea below — it's a real design decision, not just
  an engineering task).
- ~~Calorie-tracking tools — blocked on Feature 6 not existing yet.~~
  **Done in the seventh session (2026-07-06), see above.**
- ~~Onboarding-guidance tools — blocked on Feature 7 not being rebuilt
  yet.~~ **Done in the eighth session (2026-07-09), see above**
  (`get_user_profile`, `setup_nutrition_goal`, `zip_code` setting key).
- No rich chat card for the nutrition status (Avo answers in text; the
  existing recipe-nutrition card payload doesn't fit a daily-status shape) —
  same deliberate presentation-only scope cut as offers/splits, to avoid
  touching the 1000+ line chat screen without device verification. A
  "daily ring" chat card is a nice follow-up once someone can eyeball it
  on a device.
- No new rich-card UI for offers/splits results in the chat itself (Avo
  answers in text, e.g. "Milk is cheapest at Aldi for €0.89") rather than a
  new widget payload kind — deliberate scope cut to avoid touching the
  1000+ line `avo_chat_screen.dart` UI file without compiler verification.
  The underlying split/offer actions still use the real services, so this
  is a presentation limitation, not a fake integration.

**Files changed (earlier session):** `lib/data/services/avo_assistant_service.dart`.
**Files changed (seventh session):** `lib/data/services/avo_assistant_service.dart`
(5 new nutrition tools + declarations + routing + `calories_per_serving` in
search_recipes results), `lib/data/services/avo_settings_bridge.dart`
(`calorie_tracking` key).
**Files changed (eighth session):** `lib/data/services/avo_assistant_service.dart`
(`get_user_profile` + `setup_nutrition_goal` tools: declarations, routing,
implementations, system-prompt rules, dead-end note fixes),
`lib/data/services/avo_settings_bridge.dart` (`zip_code` key).
**Files changed (ninth session):** `lib/data/services/avo_assistant_service.dart`
(`update_item` + `move_items` + `create_list` + `rename_list`: declarations,
dispatch cases, implementations, system-prompt routing rules).

**Checks performed:** Verified every new tool's argument names line up with
its `Schema.object` declaration; verified `deleteItem`/`deleteList` notifier
method signatures against `items_provider.dart`/`lists_provider.dart`
exactly. Brace/paren balance check. **Not run:** a live Gemini conversation
test (needs `dart run`/simulator + a real Gemini API key in `env.dart`,
neither available here). (Seventh session: full `flutter analyze` +
`flutter test` — see that session's notes above.)

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

**Sixth session, 2026-07-05 (scheduled routine — this feature's dedicated
session).** Executed exactly the three-step plan the previous audit
recommended (and the owner approved via the `[ yes]` consolidation idea),
plus the surfaces that make it user-visible. Real Flutter 3.35.6 toolchain
(`/tmp/flutter`); every change verified with full-project `flutter analyze`
(0 errors, 59 warnings before and after — zero new issues of any severity;
info count *dropped* 557 → 549 from dead-code deletion). Notably, `flutter
test` **passes** on this SDK ("All tests passed", including the app-construct
smoke test) — the `lucide_icons`/`IconData` failure reported by earlier
sessions is specific to newer SDKs (3.44.x) where `IconData` became `final`.

*1. Consolidation (approved idea — done):*
- **Deleted `lib/core/gamification/` entirely** (`GamificationService`,
  `HomeGreetingWidget`, `ShoplySprout` mascot, barrel file) — re-verified
  zero external imports before deleting. One mascot voice remains.
- **Deleted the seven never-called `notify*` helpers** in
  `NotificationService` (`notifyListUpdate`, `notifyRecipeRating`,
  `notifyRecipeComment`, `notifyListInvitation`, `notifyShoppingComplete`,
  `notifyItemDeleted`, `notifyItemToggled`) — grep-confirmed zero callers;
  `showNotification` is (and was) the single real display path, used by the
  FCM foreground handler and the mascot service.
- **Rewrote `MascotNotificationService`**, removing the random
  time-of-day fluff ("Avo says hi!", "miss you", weekend messages — exactly
  the spam the brief says to avoid), the per-call streak counter that was
  both never-invoked and mathematically wrong (3 trips in one day = "3-day
  streak"), and the dead `AvoContext`/expression-message catalogs (zero
  external callers). What remains is one focused, data-driven job (below).

*2. The single enforced notification gate (approved idea — done):*
- New `NotificationPreferencesService`
  (`lib/data/services/notification_preferences_service.dart`):
  - **Master switch = `users.notification_enabled`** (account-scoped,
    verified live: column exists, RLS lets users update their own row),
    mirrored into SharedPreferences for synchronous/offline checks and
    synced from the DB on sign-in and when opening the settings screen.
  - **The 7 existing per-category SharedPreferences toggles** (same keys the
    settings screen always wrote, so saved values carry over) plus a new
    `notif_avo_nudges` category — all now actually enforced.
  - `NotificationService.showNotification`/`scheduleNotification` check the
    gate (master + optional category) before showing anything; the FCM
    foreground handler maps push `type` → category so remote pushes respect
    the user's toggles while the app is open.
  - **Disabling the master switch also nulls `users.fcm_token`** (and
    re-enabling re-saves it, incl. on token refresh/re-login, which now
    check the gate) — verified that all push senders
    (`PushNotificationService`, `ListActivityService`) read exactly that
    column, so background pushes genuinely stop. This is real enforcement,
    not a decorative toggle.
  - Settings screen: new master switch at the top (with description);
    category toggles fade + become inert while it's off; new "Avo" section
    with the restock-reminders toggle. Avo chat's `update_setting`
    notifications path (`AvoSettingsBridge`) now routes through the same
    cache/FCM/reminder sync, so "Avo, turn off notifications" really turns
    everything off.

*3. Real behavioral nudge — restock suggestions (done):*
- New `AvoNudgeService` (`lib/data/services/avo_nudge_service.dart`)
  computes "probably running low" items from the already-populated
  `item_purchase_stats.average_days_between` (verified live: 730 stat rows,
  126 currently nudge-eligible in the real DB). Rules: ≥3 tracked
  purchases, rhythm between 2–60 days, overdue by ≥1× its own average but
  ≤4× (beyond that the habit has probably changed), not already unchecked
  on any visible list (one RLS-scoped query), not snoozed. Dismissing
  snoozes for one of the item's own purchase cycles — not forever — so the
  nudge honestly comes back when it's plausibly due again.
- **Home-screen card** (`AvoNudgeCard`, placed with the pending-splits
  banner): small Avo mascot + up to 3 items with "Etwa alle 5 Tage ·
  zuletzt vor 8 Tagen", one-tap **Hinzufügen** (adds to the most recently
  touched list with the item's preferred quantity/category, `autoParse:
  false` so no Gemini call is burned on a known item name; snackbar
  confirms which list) and an ✕ to snooze. Renders nothing when nothing is
  due. EN/DE localized.
- **Scheduled morning reminder, designed not to spam:** on every app
  open/resume (and sign-in), `MascotNotificationService.rearmRestockReminder`
  cancels and re-schedules ONE one-shot local notification for tomorrow
  09:00 ("Milch ist wahrscheinlich fast aufgebraucht – du kaufst es etwa
  alle 5 Tage."). While the user keeps using the app it therefore never
  fires (the in-app card is the surface); it only fires if the app hasn't
  been opened since yesterday AND something was actually due. No repeat
  schedule, gated by master + Avo category, cleared on sign-out/disable.
  Uses `zonedSchedule` (added explicit `timezone` dep — already in the
  lockfile transitively via flutter_local_notifications, so resolution is
  unchanged).
- **Avo assistant connection:** new `get_restock_suggestions` Gemini tool
  ("was sollte ich nachkaufen?") returning item + rhythm + days-since, with
  a system-prompt rule to offer adding the items via the existing
  `add_item_to_list` tool.

**Explicitly NOT done (honest gaps):**
- ~~Recipe suggestions from past meals/offers/budget, price-drop/Angebote
  notifications, "you usually buy this on Sundays" (weekday patterns), and
  milestone celebrations — all still open; the notification gate +
  `AvoNudgeService` now give them a clean place to land.~~ **Angebote
  nudges, weekday patterns, and milestone celebrations were built in the
  seventh session (2026-07-07, below). Proactive recipe-suggestion nudges
  remain open** (Avo *chat* already does calorie-aware recipe suggestions
  on request since Feature 4's session; the proactive-notification version
  overlaps Feature 8 and is still to do).
- Scheduled-notification delivery needs a real device QA pass (fires when
  app is closed? iOS pending-notification limits?). Logic is
  analyzer-verified and edge-case-tested (filter math, month/year rollover,
  snooze pruning — throwaway `dart run` script, all passed), but no
  simulator/device run is possible in this container.
- The nudge computation runs on app open/resume; there is no server-side
  push for it (a Supabase cron + push edge function would deliver even if
  the app is never opened — flagged as an idea below).

**Seventh session, 2026-07-07 (scheduled routine, second run of the day —
this feature's dedicated session).** Features 1–4's remaining gaps all need
a device/Xcode or external data that doesn't exist, so per the feature
order this session closed Feature 5's documented open items that are
buildable here: Angebote nudges, weekday buying patterns, and milestone
celebrations. Real Flutter 3.35.6 toolchain; analyzer byte-identical
before/after (612 issues, 0 errors, 59 warnings), `flutter test` passes.

*1. Offer/Angebote nudges ("Avo can notify about price drops or relevant
Angebote") — done:*
- `AvoNudgeService.getOfferNudges()`: rhythm items that are due again soon
  (≥0.6 of their own purchase cycle, same trust rules as restock: ≥3
  purchases, 2–60-day rhythm) and not already on any open list are checked
  against live marktguru offers. A nudge is produced when a *relevant*
  offer exists; offers with a disclosed regular price ("statt 1,49", ≥10%
  off) are preferred and shown with the discount, otherwise the cheapest
  relevant offer is shown as a plain Angebot — **no discount figure is
  ever invented** (verified live: most staple flyer offers disclose no
  regular price at all, so requiring one would have made the feature
  near-dead).
- **Two real design flaws were caught by testing against the live API
  before shipping:** (a) the first cut required a disclosed ≥10% discount —
  live data showed 0/30 milk offers and ~1/30 branded offers carry one, so
  the rule was demoted from requirement to preference; (b) plain substring
  matching picked "Milch Reis" for *milch* and "Frucht Butter Milch" for
  *butter* — embarrassing as proactive claims. New
  `offerMatchesItem()`: German compounds put the head noun last, so an
  exact word only counts in last position ("Frische Milch" yes, "Milch
  Reis" no) and compound words must *end* with the item ("Vollmilch",
  "Räucherkäse" yes, "Milchreis" no). 14 unit cases + a live re-simulation
  across 6 staples all produce sensible nudges (e.g. "Butter · 0,99 € ·
  Lidl", "Fladenbrot · 1,79 € statt 2,67 · Lidl").
- Cost control: results cached in SharedPreferences for 6h keyed by
  zip+candidate set, max 6 offer searches per computation (the offers
  service's own 30-min cache and 250ms throttle still apply). Only runs
  with a **real** zip (GPS or manual) — never claims "nearby" offers from
  the nationwide fallback zip.
- Home card: offer rows join the existing Avo card (restock rows keep
  priority; an offer for an already-suggested restock item shows inline
  under it instead of duplicating). Each row names the actual offered
  product ("Frische Vollmilch · −23 % · 0,99 € · Lidl"), one-tap add
  carries price/retailer/pack-size onto the list item (`autoParse: false`,
  same as the list's own offer flow), ✕ snoozes until the offer expires.
  The card header switches to "Für dich im Angebot" when only offer rows
  are present. Gated by the same auth/empty rules — renders nothing when
  nothing is due.
- Morning reminder: when the top due item also has a live offer that is
  still valid at fire time (tomorrow 09:00), the body becomes "Milch ist
  wahrscheinlich fast aufgebraucht – und gerade im Angebot bei Lidl
  (0,99 €)." — same single one-shot notification, same avoNudges gate, no
  new notification stream.

*2. Weekday buying patterns ("you usually buy this on Sundays") — done:*
- `dominantWeekday()` from the already-stored per-item `purchase_dates`
  arrays: a weekday counts when ≥3 purchases fall on it AND it covers at
  least half of all purchases (verified with 6 edge cases incl.
  exactly-half and under-threshold).
- Used in two ways: the card's rhythm line becomes "Etwa alle 7 Tage ·
  meistens sonntags", and — the actionable part — items that are ≥0.75 of
  the way through their cycle surface on their usual buying day even
  before they're strictly overdue (so the Sunday-shopper sees "Milch"
  on Sunday morning, not Tuesday).
- The Avo chat `get_restock_suggestions` tool now reports
  `usually_bought_on` so chat answers can mention the pattern too.
- Localized weekday adverbs (montags…sonntags / on Mondays…on Sundays),
  EN/DE.

*3. Milestone celebrations ("without being childish") — done:*
- `MascotNotificationService.milestoneMessageForCompletedTrip()`: on
  completing a shopping trip, if the user's own completed-trip count just
  hit 10/25/50/100/250/500/1000, the completion snackbar becomes "🥑
  Meilenstein: Das war dein 50. Einkauf mit Shoply!" — each milestone
  fires at most once (tracked locally), milestones are sparse by design,
  it's an in-app moment (no notification), and on any error the normal
  snackbar shows instead.

**Files changed (seventh session):**
`lib/data/services/avo_nudge_service.dart` (OfferNudge model +
getOfferNudges + offerMatchesItem + dominantWeekday + weekday eligibility +
offer snooze/cache), `lib/presentation/state/avo_nudge_provider.dart`
(offerNudgesProvider), `lib/presentation/screens/home/widgets/avo_nudge_card.dart`
(offer rows, weekday line, shared row layout, offer-aware add),
`lib/data/services/mascot_notification_service.dart` (offer-enriched
reminder body, milestone method),
`lib/presentation/screens/lists/list_detail_screen.dart` (milestone
snackbar on trip completion), `lib/data/services/avo_assistant_service.dart`
(usually_bought_on in restock tool output),
`lib/core/localization/app_translations.dart` (13 new EN/DE keys).

**Checks performed (seventh session):** full `flutter analyze` before/after
(612 issues both times, 0 errors, 59 warnings, diffed ignoring line
numbers — zero new issues of any severity); `flutter test` passes; live
marktguru verification of discount-disclosure rates and a 6-staple
end-to-end nudge simulation with the final matcher; 18 eligibility/weekday
cases + 14 matcher cases via throwaway `dart run` scripts (all passed, not
committed). **Not run (no device):** actual rendering of the offer rows,
the snackbar milestone moment, or the offer-enriched scheduled
notification firing.

---

## Feature 6 — Complete calorie tracking

**Before this session:** 0%, confirmed genuinely greenfield in Dart (see the
prior session's audit above — still accurate). However, exactly like the
Feature 1/2 precedent documented at the top of this file, **the Supabase
schema had already been built and applied live** (`nutrition_goals`,
`food_log_entries`, `weight_log`, `water_log`, `nutrition_challenges` — all
with correct RLS, check constraints matching this brief's exact enums, and
sensible indexes/unique constraints) with **zero corresponding Dart code and
no migration file in the repo**. This session verified the live schema via
the Supabase MCP tools (columns, constraints, indexes, RLS policies — all
correct and exactly matching the brief), wrote the missing migration file
for version control, and built the entire Dart/Flutter side on top of it.

**What I implemented (real, wired, persisted — not mockups):**

*Schema & models:*
- `supabase/migrations/20260706000000_calorie_tracking.sql` — documents the
  already-live schema (idempotent, same pattern as the pricing/splits
  migration).
- `NutritionGoal`, `FoodLogEntry` (+ `DailyNutritionTotals`),
  `WeightLogEntry`, `WaterLogEntry`, `FoodProduct` models
  (`lib/data/models/`) — typed enums (`NutritionGoalType`, `ActivityLevel`,
  `MealType`, `FoodLogSource`) with DB-value mapping, matching the live
  check constraints exactly.

*Services:*
- `NutritionGoalService` + `NutritionGoalCalculator` — Mifflin-St Jeor BMR ×
  activity factor, adjusted for goal type (deficit/surplus derived from
  target weight + timeline, clamped to a safe 200-1000 kcal/day range and a
  1200/1500 kcal absolute floor), with a protein-first macro split (higher
  g/kg for muscle gain and weight loss to preserve lean mass). Sanity-tested
  with a throwaway `dart` script against 5 realistic profiles (maintenance,
  loss, gain, an extreme short-timeline case to confirm the safety clamp
  holds, and the no-target-weight fallback) — all produced plausible
  targets, no crashes, no negative/zero values, macros always sum back to
  ~the calorie target.
- `FoodLogService`, `WeightLogService` (upsert-per-day), `WaterLogService` —
  straightforward CRUD + day/week aggregation, same singleton-service
  pattern as `ExpenseSplitService`.
- `OpenFoodFactsService` — **real, live, free, keyless** food database
  integration (no new API key needed, unlike the Gemini features). Verified
  against the actual API from this container: name search via
  `search.openfoodfacts.org` (the legacy `cgi/search.pl` endpoint the docs
  usually point to returns "temporarily unavailable" for every request
  right now, confirmed independent of query/headers — the search-a-licious
  endpoint is the live replacement) and exact-barcode lookup via
  `world.openfoodfacts.org/api/v2/product/{barcode}.json` (tested live with
  a real barcode — Nutella, `3017620422003` — full nutriment payload
  confirmed). Never throws to callers; returns empty/null on any failure so
  the UI shows a clean empty state instead of an error screen.
- `MealPhotoAnalysisService` — Gemini **vision** (multimodal `Content.multi`
  with `DataPart`), a first for this codebase (every other Gemini service
  here is text-only). One-shot meal-photo → `{food_name, calories,
  protein_g, carbs_g, fat_g, confidence}` JSON, using `gemini-2.0-flash`
  (the flash-lite model used elsewhere for categorization isn't
  multimodal). Deliberately never logs directly — always returns an
  editable pre-fill, since a single-photo estimate can't know portion
  weight or hidden oil/sauce; the UI shows the confidence level and lets
  the user correct any field before saving.

*UI (Riverpod, `lib/presentation/screens/calories/`):*
- **Dashboard** (`calories_screen.dart`, replacing the old "not built yet"
  v0 placeholder): day switcher, a 7-day mini bar strip (real weekly
  totals, not a mockup — this is the "progress graphs" requirement),
  a hand-rolled `CalorieRing` (consumed vs. target, no chart package in this
  project so a small `CustomPainter` was used — same reasoning applies to
  `WeightChart`), three macro progress bars, `WaterTrackerCard`
  (+250/500/750 ml quick-add), and meal-grouped (breakfast/lunch/
  dinner/snack) food log sections with swipe-to-delete.
- **Goal setup** (`goal_setup_screen.dart`) — goal type, gender, age,
  height, current/target weight, activity level (with plain-language
  descriptions, not just labels), timeline slider — calculates and saves
  targets, and syncs age/height/gender back onto the user's actual profile
  (`UserModel`/`users` table) rather than duplicating them silently, since
  those fields are used elsewhere (diet/allergy logic, personal info
  screen).
- **Food entry** (`widgets/food_entry_sheet.dart`) — four tabs in one
  sheet: **Search** (debounced Open Food Facts search, tap a result → grams
  dialog → logged with scaled macros), **Barcode** (manual numeric entry +
  lookup — no camera scanner; see "Not done" below), **Photo** (camera or
  gallery → Gemini vision → editable pre-fill), **Manual** (direct
  calorie/macro entry for anything not in a product database, e.g. home
  cooking).
- **Weight tracking** (`weight_tracking_screen.dart` +
  `widgets/weight_chart.dart`) — log today's weight, see a line chart
  against the goal's target weight (dashed reference line).
- **Recipe integration** (`widgets/log_recipe_sheet.dart`, wired into
  `recipe_detail_screen.dart`) — pick a meal + serving count, logs the
  recipe's nutrition scaled by servings, `source: 'recipe'`,
  `source_recipe_id` set. **Also revived a real piece of dead code as part
  of this**: `NutritionInfoWidget` (a fully-built nutrition display card)
  existed in the repo with zero call sites — recipe nutrition was
  completely invisible to users everywhere except one Avo chat card. It's
  now shown on every recipe with nutrition data, tracking-enabled or not
  (useful info on its own), with the "log to diary" button appearing only
  when calorie tracking is enabled.

**Explicitly NOT done (honest gaps, not shortcuts):**
- **Camera barcode scanning.** `mobile_scanner` is commented out in
  `pubspec.yaml` for iOS build issues (per `CLAUDE.md`, "don't re-enable
  without testing" — and this container can't build iOS to verify it).
  Manual barcode entry + Open Food Facts lookup is a real, working
  alternative, not a stub, but it's not what a "scan the barcode" UX
  implies. Re-enabling the camera scanner needs a session with a real
  device/simulator build.
- **Meal photo storage.** `photo_url` exists on `food_log_entries` but
  photos aren't uploaded to Supabase Storage — the AI estimate is used to
  fill the log entry, then the local image is discarded. Adding storage
  would need a new bucket + upload path; scoped out to keep this session
  focused on the core tracking loop.
- **Diet challenges** (16:8 fasting, 30-day no sugar). The
  `nutrition_challenges` table exists (live schema, migration documented)
  but has no Dart service or UI yet — deprioritized behind the core
  logging loop, which is the foundation everything else (including
  challenges) needs.
- ~~**Avo integration** ("recommends recipes based on calories
  remaining", `get_calories_remaining` tool). Deliberately left to Feature
  4/5's own sessions per the single-feature-mode rule — this session
  exposes `NutritionGoalService`/`FoodLogService` in a way that a future
  Avo tool can call directly, but didn't touch
  `avo_assistant_service.dart`.~~ **Done later the same day in Feature 4's
  seventh session** (get_nutrition_status/log_food/log_water/log_weight/
  delete_food_log + calorie-aware recipe suggestions — see Feature 4).
- **Onboarding integration.** The goal questionnaire is a standalone screen
  reachable from the calorie tab, not wired into the onboarding flow —
  that's Feature 7's job (see its updated blocker note above); the
  goal-calculation logic it needs now exists and is ready to be called from
  there.
- **Weekly summary / streaks / "what can I still eat" assistant flow** —
  not built; flagged as ideas below.

**Not verified (no macOS/Xcode/device in this container):** actual
appearance/layout on a simulator or device (ring sizing, chart rendering,
sheet scroll behavior on a small screen); real Gemini vision output quality
on an actual meal photo (the service is analyzer-clean and follows the
exact same call pattern as the app's other Gemini services, but was not
exercised against the live API from this container — doing so would need a
real image and burn a real API call); `image_picker` camera/gallery
permission prompts on-device.

**Files changed:** `supabase/migrations/20260706000000_calorie_tracking.sql`
(new), `lib/data/models/{nutrition_goal,food_log_entry,weight_log_entry,
water_log_entry,food_product}.dart` (new), `lib/data/services/
{nutrition_goal_service,food_log_service,weight_log_service,
water_log_service,open_food_facts_service,meal_photo_analysis_service}.dart`
(new), `lib/presentation/state/nutrition_provider.dart` (new),
`lib/presentation/screens/calories/{calories_screen.dart (rewritten),
goal_setup_screen.dart,weight_tracking_screen.dart}` (new/rewritten),
`lib/presentation/screens/calories/widgets/{calorie_ring,macro_bar,
water_tracker_card,food_log_tile,food_entry_sheet,weight_chart,
log_recipe_sheet,weekly_calories_strip}.dart` (new),
`lib/presentation/screens/recipes/recipe_detail_screen.dart` (nutrition
card + "log to diary" button added), `lib/core/localization/
app_translations.dart` (~85 new EN/DE keys).

**Checks performed:** Flutter 3.35.6 downloaded fresh; `flutter analyze`
before/after — 608 issues both times (0 errors, 59 warnings), every new file
individually confirmed to contribute zero issues of any severity; `flutter
test` passes. Verified the live DB schema (columns, check constraints,
indexes, RLS policies) via the Supabase MCP tools against every table before
writing any Dart code, instead of assuming the brief's shape. Verified the
Open Food Facts endpoints live with `curl` (search + barcode lookup, real
data, matching the model's parsing logic). Sanity-tested the goal calculator
against 5 profiles with a throwaway script (not committed). Traced every new
provider/service call site by hand for RLS-column/field-name correctness
against the verified live schema.

**Second session, 2026-07-14 (scheduled routine).** Features 1–5's remaining
gaps are all device-QA/external-only per the feature order (see the top-level
environment note and each feature's status row), so this session picked
Feature 6 and re-read the required-capability list against the "explicitly
NOT done" list from the first session, rather than re-reading the writeup at
face value. Picked the two biggest concrete gaps that don't need a device to
build: **diet challenges** (a literal required capability — "16:8 fasting,
30-day no sugar challenge") and **meal-photo storage** (the food log's photo
tab analyzes a photo with Gemini vision, then silently discarded the image).
Camera barcode scanning was re-confirmed as still genuinely blocked
(`mobile_scanner` commented out in `pubspec.yaml`, can't verify an iOS build
here) — left alone, not touched.

**Same backend-ahead-of-Dart pattern found again:** exactly like Features
1/2/6's first session, the `nutrition_challenges` table already had a
`daily_checkins jsonb` column and a `nutrition_challenges_one_active_per_type`
partial unique index live in Supabase (migration `20260710062531
challenge_daily_checkins`, applied 4 days before this session, likely a stray
backend-only pass from an earlier Feature-1 run) — with **zero Dart code**
referencing challenges anywhere in `lib/`. Verified via the Supabase MCP
tools before writing anything, then wrote the missing migration file for
version control (idempotent, same pattern as every prior "undocumented live
schema" fix in this repo).

**What I implemented:**

*Diet challenges (16:8 fasting, 30-day no sugar):*
- `DietChallenge` model (`lib/data/models/diet_challenge.dart`) —
  `ChallengeType` (`fasting16_8`, `noSugar30`, `custom` for future use),
  `ChallengeStatus` (active/completed/abandoned), and the `daily_checkins`
  map (`'yyyy-MM-dd' -> kept?`). Deliberately modeled the two challenge types
  differently to match how they actually work: `noSugar30` has a
  `fixedDurationDays` of 30 (so it auto-completes when the target end date
  passes), `fasting16_8` is an ongoing daily habit with no fixed finish line
  — the user ends it themselves whenever they like (matches the brief's
  "16:8 fasting" being a lifestyle habit, not a countdown).
- `DietChallengeService` (`lib/data/services/diet_challenge_service.dart`) —
  `getActiveChallenges()` (auto-closes any `noSugar30` challenge that just
  passed its target end date to `completed`, so the user gets a final result
  instead of an indefinitely-lingering "active" challenge), `getHistory()`,
  `startChallenge(type)` (throws a typed `ChallengeAlreadyActiveException` on
  the DB's unique-constraint violation — server-enforced, not a client-side
  race-prone check), `checkIn(challenge, kept:)` (read-merge-write of the
  jsonb map — the Supabase Dart client has no partial-jsonb-patch without an
  RPC), `completeChallenge()`/`abandonChallenge()`.
- `ChallengesScreen` (`lib/presentation/screens/calories/challenges_screen.dart`)
  — three sections: **Active** (streak chip, day-X-of-Y or open-ended day
  counter, days-remaining for fixed-length challenges, adherence %,
  kept-it/not-today check-in buttons that become a "Checked in — kept/not"
  status + change link once today's already logged, "Mark complete"/"Give
  up" actions with a confirmation dialog on give-up), **Start a new
  challenge** (catalog cards for types the user doesn't already have active —
  hides a type once it's running so you can't double-start it client-side
  either), **Past challenges** (completed vs. ended-early, final adherence
  %).
- `ChallengesEntryCard` (`lib/presentation/screens/calories/widgets/
  challenges_entry_card.dart`) — a compact, tappable card on the calorie
  dashboard: shows the active-challenge count once you have one, or a
  low-key "Try a challenge" invite otherwise. Entirely optional, doesn't
  block or clutter the rest of the dashboard — matches the brief's "make
  calorie tracking optional and not forced" ethos extended to challenges
  specifically.
- `diet_challenge_provider.dart` — `activeChallengesProvider`,
  `challengeHistoryProvider`, `invalidateChallenges()`.
- 40 new EN/DE keys in `app_translations.dart`.

*Meal-photo storage (the other concrete gap):*
- New `meal-photos` Supabase Storage bucket (public read, write/delete
  restricted to the uploader's own `{user_id}/...` folder) — mirrors the
  existing `profile-pictures`/`recipe-images` buckets' shape exactly, for
  consistency with the rest of the app's storage security posture. Written
  as part of the same migration file as the challenges schema documentation
  (`supabase/migrations/20260714000000_diet_challenges_and_meal_photos.sql`),
  applied live via the Supabase MCP tools and verified (`storage.buckets`
  row + `pg_policies` both confirmed).
- `MealPhotoStorageService` (`lib/data/services/meal_photo_storage_service.dart`)
  — uploads the already-in-memory photo bytes (the food entry sheet already
  reads them for the Gemini vision call) via `uploadBinary`, returns the
  public URL. Best-effort: a failed upload never blocks saving the food log
  entry, it just leaves `photo_url` unset (same fail-open philosophy as the
  rest of this feature's services).
- Wired into `food_entry_sheet.dart`'s `_savePhotoEntry`: the picked photo's
  bytes are now retained in state (previously discarded right after the
  Gemini call), uploaded on save, and the resulting URL is attached to the
  `FoodLogEntry` (`photoUrl` — the model and DB column already existed from
  the first Feature-6 session, just never populated). The "Add" button now
  shows a loading state during upload.
- `FoodLogTile` now renders a 32×32 thumbnail from `photoUrl` when present
  (falls back to the existing source icon on load error or when absent) —
  the photo was being saved-and-forgotten with no way to ever see it again
  before this.

**Bug found and fixed while verifying (not a "not done" item — actually
fixed before committing):** the throwaway test script for
`DietChallenge.currentStreak` caught a real logic bug: the original
implementation used `dailyCheckins[key] != true` to decide whether to fall
back to checking yesterday, which can't distinguish "no check-in yet today"
from "explicitly checked in as missed today" — so marking today as
"Not today" (an explicit miss) incorrectly left yesterday's streak count
intact instead of resetting to 0. Fixed by checking `containsKey` first; all
21 throwaway test cases (streak continuity/breaks/explicit-miss, adherence
rate incl. zero-checkins, fixed-duration day counting or its absence,
days-remaining clamping, past-target-end detection incl. suppression once a
challenge is already closed out) pass.

**Explicitly NOT done (honest gaps, not shortcuts):**
- Camera barcode scanning — still genuinely blocked (`mobile_scanner`
  commented out in `pubspec.yaml` for iOS build issues, unchanged from the
  first session; this container still can't build iOS to verify a fix).
- Weekly nutrition summary / a dedicated in-app "what can I still eat today"
  screen — not built (the *chat* version of "what can I still eat" already
  works via Avo's `get_nutrition_status` → `search_recipes` chaining from
  Feature 4's seventh session; this is about a first-class UI surface for
  it, which is still open); flagged as an idea below.
- Avo/assistant awareness of challenges (e.g. "how's my fasting streak
  going?") — deliberately not touched, per the single-feature-mode rule;
  Feature 4/5's own sessions are the right place for that, same precedent as
  the first Feature-6 session's calorie-tool integration being finished
  later in a Feature-4 session.
- `custom` challenge type — exists in the DB check constraint and the Dart
  enum for forward compatibility, but has no catalog card or dedicated UI;
  only `fasting_16_8` and `no_sugar_30` are user-facing today, matching what
  the brief actually asked for.

**Not verified (no macOS/Xcode/device in this container):** actual
appearance of the new challenge cards/thumbnails on a simulator or device;
whether `uploadBinary` against the real `meal-photos` bucket succeeds
end-to-end from a real device camera photo (the bucket, policies, and
service code are all live/analyzer-clean and follow the exact same
call pattern as `ProfilePictureService`/`recipe_service.dart`'s existing
storage uploads, but weren't exercised with a real authenticated upload from
this container — doing so would need a real signed-in session); the
give-up confirmation dialog and check-in button states on a small screen.

**Files changed (second session):**
`supabase/migrations/20260714000000_diet_challenges_and_meal_photos.sql`
(new), `lib/data/models/diet_challenge.dart` (new),
`lib/data/services/diet_challenge_service.dart` (new),
`lib/data/services/meal_photo_storage_service.dart` (new),
`lib/presentation/state/diet_challenge_provider.dart` (new),
`lib/presentation/screens/calories/challenges_screen.dart` (new),
`lib/presentation/screens/calories/widgets/challenges_entry_card.dart` (new),
`lib/presentation/screens/calories/calories_screen.dart` (entry card wired
in), `lib/presentation/screens/calories/widgets/food_entry_sheet.dart`
(photo upload wiring), `lib/presentation/screens/calories/widgets/
food_log_tile.dart` (photo thumbnail), `lib/core/localization/
app_translations.dart` (40 new EN/DE keys).

**Checks performed (second session):** see the environment note at the top
of this file for the full `dart analyze`/`flutter test` verification detail
(610 issues before and after, byte-identical; `flutter test` passes; 21/21
throwaway logic tests pass, one real bug caught and fixed). Verified the
live Supabase schema and the new bucket/policies via the Supabase MCP tools
before and after applying the migration.

**Third session, 2026-07-18 (scheduled routine, second run of the day — this
feature's dedicated session).** Built the weekly nutrition summary — an
explicit Feature 6 autonomy bullet from the brief ("Weekly progress summary",
"Streaks, but not too aggressive") that had been sitting mis-flagged as
needs-decision in the Ideas list (see the top-of-file walk note). No schema
changes needed — everything aggregates data the existing tables already hold.

*What was built:*
- **`WeeklyNutritionSummary`** (`lib/data/models/weekly_nutrition_summary.dart`,
  new) — a pure, I/O-free computation over the last 7 days with deliberately
  honest semantics, documented in the class comment: averages are per *logged*
  day (an unlogged day is unknown, not 0 kcal); "within budget" = logged and
  ≤ 105% of the calorie target (unlogged days never count); "protein reached"
  = ≥ 90% of target; water averages only over days with water logged; the
  weight delta is only reported when two weigh-ins fall inside the window (no
  trend claimed from one data point); the logging streak counts consecutive
  logged days ending today, or yesterday when today has nothing yet (an
  unfinished day doesn't break it).
- **`WeeklySummaryScreen`**
  (`lib/presentation/screens/calories/weekly_summary_screen.dart`, new) —
  date-range header, a quiet streak row (only shown from 2 days up — the
  brief's "not too aggressive"), a calories card (Ø kcal vs. target, "{n} of 7
  days logged · {m} within budget", and a larger 7-day bar chart with per-day
  kcal labels), a macros card (Ø protein/carbs/fat vs. targets via the
  existing `MacroBar`, plus the protein-days line), a water card, and a
  tappable weight card (weekly delta when two weigh-ins exist, otherwise an
  honest "weigh in a couple of times a week" hint; opens the existing weight
  screen). Clean `AppEmptyState` when nothing was logged this week.
- **Entry points:** the dashboard's weekly strip is now tappable, plus an
  explicit "Wochenrückblick ›" link above it — no navbar/tab changes.
- **Service/provider additions:** `FoodLogService.getRecentLoggedDates()`
  (single-column fetch for the streak), `WaterLogService.getWeeklyTotals()`,
  and `weeklyWaterTotalsProvider`/`recentLoggedDatesProvider`/
  `weeklyNutritionSummaryProvider` in `nutrition_provider.dart`.
- **Real pre-existing bug fixed:** `weeklyNutritionTotalsProvider` was defined
  inside `weekly_calories_strip.dart` and was missing from
  `invalidateNutritionLog` (whose own doc comment claims it refreshes "the
  weekly summary") — so while the dashboard stayed mounted, the weekly strip
  never updated after logging/deleting food; today's bar only caught up after
  leaving the tab long enough for autoDispose to kick in. The provider now
  lives in `nutrition_provider.dart` with the others and is invalidated
  alongside the daily providers (as are the two new weekly providers).
- 15 new EN/DE translation key pairs.

*Explicitly NOT done:*
- The dedicated "what can I still eat today?" surface — see the updated idea
  below (needs an owner decision; the chat version already works via Avo).
- No Avo tool for the weekly summary ("how was my week?") — Feature 4's
  session is the right place, same precedent as the calorie tools.
- No notification/nudge angle (that would be Feature 5/8 territory), and no
  premium gating (still owner-decision-gated).

*Checks performed (third session):* fresh Flutter 3.35.6 in `/tmp/flutter`;
full-project `flutter analyze` before/after — **byte-identical (621 issues
both times, diffed with line numbers normalized out; zero issues in any
touched/new file)**; `flutter test` passes ("All tests passed") after
recreating the gitignored `env.dart` from `env.example.dart` (needed by the
pre-existing smoke test, not by this session's code). The summary math ships
with a **committed** unit test (`test/weekly_summary_logic_test.dart`, 10
cases: empty week, per-logged-day averaging, the 105%-budget and 90%-protein
boundaries inclusive, no-target behavior, water averaging/reached counts,
weight-delta two-weigh-in rule, streak with/without today, streak across a
month boundary, non-midnight timestamp normalization) — a deliberate upgrade
from the throwaway-script pattern of earlier sessions, since the repo's test
suite runs fine here and the logic is pure Dart. `pubspec.lock` churn from
`pub get` reverted before committing. **Not verified (no macOS/Xcode/device):**
actual rendering (bar-label fit at 7 columns on narrow screens, card layout,
dark mode appearance) — needs a device pass like everything else here.

---

## Feature 7 — Personalized onboarding and navbar

**Fifth session, 2026-07-08 (scheduled routine — this feature's dedicated
session).** Features 1–6 have each had multiple dedicated sessions and sit
at 70–95% with genuinely mature, documented states (external blockers or
"needs a real device build" as the only gaps); the owner had also already
approved (`[ yes]`) sequencing Feature 7 right after Feature 6's schema
landed. Audited the ~30% state left by the 2026-07-04 sessions (navbar
already data-driven and calorie-optional; the onboarding flow itself still a
3-page marketing carousel that "collects nothing and doesn't even
functionally gate anything") and closed the two required-but-missing pieces:
personalization questions during onboarding, and a real account-level goal
questionnaire when the user opts into calorie tracking.

**Before this session:**
- Onboarding was 3 marketing pages + a binary "calorie tracking yes/no"
  page, gated purely by a device-local `SharedPreferences` flag
  (`onboarding_complete_v1`). It asked nothing about the user and collected
  no personalization data at all.
- `users.diet_preferences`/`allergies` (already used everywhere for recipe
  filtering and ingredient substitution) were only ever collected later, from
  Profile → Diet preferences — never during onboarding.
- If a user opted into calorie tracking during onboarding, they landed on an
  empty calories tab and had to separately discover "Set up your goals" to
  reach the real goal questionnaire (`GoalSetupScreen`, built in Feature 6) —
  a real drop-off point, and the opposite of "ask follow-up goal questions"
  from the brief.
- `NutritionGoalService.setTrackingEnabled()` (a real, working server call
  Feature 6 already built) had **zero call sites anywhere in the app** — the
  calorie-tracking on/off preference was purely local, so it silently reset
  to "off" on reinstall or a second device.
- `users.onboarding_completed` (DB column) was fetched and cached every app
  start but never written by anything reachable, and never used to make a
  redirect decision — dead weight, exactly as the prior audit flagged.
- A second, fully unreachable onboarding screen, `UnifiedSetupScreen`
  (`/setup` route — a leftover dark-themed "what's your name" screen, no
  navigation call site anywhere, confirmed via grep), sat next to the real
  onboarding flow as a trap for the next person searching for "onboarding".

**What I implemented:**
- **Diet-preference onboarding page** (`onboarding_diet_page.dart`, new) —
  "Isst du besonders?" with the *exact same 12 diet ids* the Profile → Diet
  preferences screen already uses (`vegetarian`, `vegan`, `gluten_free`, …),
  as compact multi-select pill chips. None selected = no restrictions, same
  semantics as the settings screen. This directly feeds real, already-live
  behavior (recipe filtering, ingredient substitution) — not a cosmetic
  question with no effect.
- **Goal questionnaire onboarding page** (`onboarding_goal_page.dart`, new) —
  shown only when the previous page's calorie-tracking opt-in is "yes":
  goal type (lose/gain/maintain/custom), gender, age, height, current
  weight, target weight + timeline (only when relevant), activity level —
  the exact fields the brief asks for, using the *same*
  `NutritionGoalCalculator` Feature 6 already built (no duplicated
  calculation logic). Reports a nullable draft up to the parent on every
  change; an incomplete draft is a valid, non-blocking state.
- **Onboarding never traps the user.** The primary button always finishes
  onboarding regardless of whether the goal page is complete — skipping just
  means calorie tracking is enabled without a configured goal yet, which
  Feature 6's existing calories dashboard already handles gracefully (its
  own "Set up your goals" prompt card). The page count is now dynamic
  (5 pages, or 6 with the goal page included) and the "Skip" button and swipe
  navigation both still work with the dynamic page list — a clamp guards the
  one real edge case (toggling calorie tracking off after having reached the
  now-removed goal page) so `PageView` never receives an out-of-range index.
- **`OnboardingAnswersService`** (new,
  `lib/data/services/onboarding_answers_service.dart`) — the missing piece
  that makes the two new pages real instead of decorative. Onboarding runs
  *before* an account exists, so there's nowhere to save these answers yet;
  this service stashes them in `SharedPreferences` and applies them to the
  real `users` / `nutrition_goals` rows **the first time this device sees an
  authenticated user** (idempotent via a synced flag — never re-runs, never
  clobbers answers the user later changes from Profile/goal settings, and is
  a safe no-op for existing users who onboarded before this session, since
  they have nothing pending). Wired into `currentUserProvider`'s
  `users`-row lookup (`auth_provider.dart`) — the one real choke point every
  first login (email OTP signup *and* Google/Apple OAuth) already passes
  through, since that's also where the `users` row itself gets created for a
  brand-new account. When it applies changes, the provider re-fetches the row
  so the very first `UserModel` the app sees is already correct rather than
  stale until the next refresh.
- **Fixed the completely dead `calorie_tracking_enabled` server sync.**
  `CalorieTrackingNotifier` (`calorie_tracking_provider.dart`) now also reads
  `nutrition_goals.calorie_tracking_enabled` on load (server wins when a row
  exists, local `SharedPreferences` is the offline-safe mirror, same pattern
  Feature 5's `NotificationPreferencesService` already established) and
  writes through `NutritionGoalService.setTrackingEnabled()` on every
  toggle — a previously-built, previously-unused server method now actually
  gets called. This means the calorie-tab preference set during onboarding
  (or later from Profile) now survives a reinstall or a second device instead
  of silently resetting to off, directly satisfying "must be optional... you
  can change this anytime" for real rather than only on the device that set
  it.
- **`users.onboarding_completed` now has a real writer.** It's set `true` by
  `OnboardingAnswersService` the moment the answers are applied to a fresh
  account — the column stops being fetched-but-never-written dead weight.
  Left the router's actual pre-login onboarding gate as the local
  `SharedPreferences` flag (unchanged, low-risk) rather than rewiring
  `redirect:`'s auth logic, since a logged-in user already skips `/onboarding`
  entirely regardless of this field (traced the full redirect function to
  confirm) — the real value of finally writing this field is that it's an
  honest signal for anything that reads it later (analytics, support, a
  future admin view), not a redirect-logic change.
- **Deleted the confirmed-dead `UnifiedSetupScreen`/`/setup` route** —
  zero navigation call sites anywhere (`context.go('/setup')`,
  `context.push('/setup')`, `goNamed('setup')` all return no matches), the
  real "ask for a display name" flow is `NamePromptScreen` at `/name-prompt`
  (reachable, upserts `display_name` after OAuth login). Direct,
  well-scoped cleanup since it sits in the exact onboarding-adjacent code
  this session was already auditing.
- **14 new EN/DE translation key pairs** for the two new pages (diet
  kicker/title/sub + 12 diet labels, goal kicker/title/sub/skip-hint) —
  reused the existing `goal_type_*`/`gender_*`/`activity_*` keys Feature 6
  already localized rather than duplicating them.

**Explicitly NOT done / still open:**
- **The real account-signup → sync round trip is unverified on a live
  device.** The JSON round-trip, the calculator math, and the analyzer pass
  are all verified; a real OTP/OAuth signup actually hitting
  `currentUserProvider`'s create-branch, writing `diet_preferences`/
  `onboarding_completed`/the `nutrition_goals` row, and having the calories
  dashboard immediately show the right target — needs a real device/Xcode
  session with a live Supabase project, which this container doesn't have.
- **Existing users are unaffected by design** (nothing pending to sync,
  confirmed by tracing the no-pending-answers early-return), but that also
  means this session doesn't retroactively personalize anyone who onboarded
  before it — expected, not a shortcut.
- **The router's pre-login onboarding gate is still local-device-only.**
  This is unchanged from before (traced: a logged-in user already bypasses
  `/onboarding` regardless of the DB field), so it's not a regression, but a
  genuinely account-scoped "skip onboarding" (e.g. for a user who logs into
  a second, never-onboarded device) would need touching the redirect
  function itself — flagged as an idea below since it's a real, if rare,
  UX gap, not something this session's brief specifically asked for.
- **"What kind of user are you" is scoped to diet preferences + calorie
  goals** — the two personalization axes that have a real, already-wired
  effect on the app (recipe filtering/substitution, calorie targets).
  Deliberately did *not* add a separate "which features do you want" toggle
  for shopping/recipes/deals, since none of those are actually gateable in
  the app today (Standard shopping/recipe features are always on, per the
  brief) — inventing toggles with no code behind them would be exactly the
  "fake working integration" the brief warns against.
- **Navbar personalization itself was already done** in the 2026-07-04
  sessions (data-driven Kalorien tab via `calorieTrackingEnabledProvider`) —
  this session only touched the account-scoping of that same preference, not
  the navbar layout.

**Not verified (no macOS/Xcode/device in this container):** the actual
onboarding UI on a real screen (chip wrapping, goal-page scroll behavior,
the dynamic page-count dot indicator); a live signup completing the full
onboarding → answers-applied → dashboard-shows-target loop; whether Apple/
Google OAuth's first login (vs. email OTP) hits the same
`currentUserProvider` create-branch identically (traced via code reading, not
exercised live).

**Files changed (fifth session):**
`lib/presentation/screens/onboarding/onboarding_screen.dart` (dynamic page
list, diet/goal state, wiring to `OnboardingAnswersService`),
`lib/presentation/screens/onboarding/widgets/onboarding_diet_page.dart`
(new), `lib/presentation/screens/onboarding/widgets/onboarding_goal_page.dart`
(new), `lib/data/services/onboarding_answers_service.dart` (new),
`lib/presentation/state/auth_provider.dart` (`currentUserProvider` sync
hook, re-fetch on apply), `lib/presentation/state/calorie_tracking_provider.dart`
(server read/write via `NutritionGoalService`), `lib/routes/app_router.dart`
(removed the dead `/setup` route), `lib/core/localization/app_translations.dart`
(14 new EN/DE key pairs). **Deleted:**
`lib/presentation/screens/onboarding/unified_setup_screen.dart`.

**Checks performed (fifth session):** Flutter 3.35.6 downloaded fresh into
`/tmp/flutter`; `flutter analyze` before/after (612 → 610 issues, 0 errors,
59 warnings both times, diffed ignoring line numbers — the only change is
the 2 info-lints removed with the deleted dead file); `flutter test` passes.
A throwaway `flutter test` file (not committed) verified the
`OnboardingGoalDraft` JSON round-trip (including the maintain-goal
no-target-weight null case) and re-exercised `NutritionGoalCalculator`
against the lose-weight and extreme-short-timeline profiles (macros sum back
to the calorie target, safety floor holds) — same calculator Feature 6
already unit-checked, re-verified here because the onboarding page feeds it
fresh input shapes. Traced every new Supabase call
(`OnboardingAnswersService`, `CalorieTrackingNotifier`) against the exact
column names/RLS-scoping pattern `goal_setup_screen.dart` and
`diet_preferences_screen.dart` already use successfully, rather than
inventing a new access pattern. Grepped for zero remaining references to
`UnifiedSetupScreen`/`unified_setup_screen` before deleting.

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

**Recommended first cross-feature wins** (audited pre-session): a home-screen
card surfacing "€X cheaper at [store] this week" using the now-wired
`basketComparisonProvider` (Feature 1 infra); "you usually buy milk every 5
days" using the already-populated `item_purchase_stats` — **this one shipped
in Feature 5's sixth session** (`AvoNudgeCard`, already live); once Feature 6
exists, "N calories left — 3 dinner ideas from your list" — **this is what
this session built.**

**Second session, 2026-07-09 (scheduled routine — this feature's dedicated
session).** Features 1–7 all sit at 70–95% with mature, documented states
(external blockers or "needs a real device build" as the only remaining
gaps) — Feature 8 (~10%, not started) is clearly the feature that most needs
a session now, and it's explicitly sequenced last since it composes 1–7.
Picked the most concretely-scoped, already-approved-in-spirit item from the
ideas list: the proactive recipe-suggestion nudge ("N calories left — Avo
found dinner ideas"), flagged in the ideas section as "the last open
Feature-5 brief item, overlapping Feature 8" with recommendation "yes, as the
next Feature 5/8 slice." It's a genuine three-feature connection (Feature 6
calorie tracking → Feature-2-recipe nutrition data → Feature 5's Avo nudge
surface) and, unlike a live-pricing home card, needed no new caching/rate-limit
design since it only reads already-stored data.

**What I implemented:**
- `CalorieRecipeNudgeService` (new,
  `lib/data/services/calorie_recipe_nudge_service.dart`) —
  `getRemainingCaloriesToday()` (today's `dailyCalorieTarget` minus the food
  log's summed calories, or null when tracking is off/unconfigured/signed
  out) and `getSuggestions()`, which pools candidates from saved + popular +
  recent recipes (deduplicated by id) and keeps only recipes that: already
  carry a stored `nutrition.calories` (never calls Gemini — this never
  competes with the 1.1s-throttled categorization pipeline and costs nothing
  beyond ordinary Supabase reads), fit within the remaining budget, satisfy
  every one of the user's diet preferences against the recipe's labels (same
  AND-matching rule Avo's `search_recipes` tool already uses), and contain no
  allergen keyword in their ingredient names (same rule too). Survivors sort
  by closest fit to the remaining budget without exceeding it, tie-broken by
  rating. The filter/sort step is split into a `@visibleForTesting static
  filterAndSort()` so it's unit-testable without a live Supabase connection.
  Below 150 kcal remaining, nothing is suggested — there isn't enough budget
  left for a real meal idea to make sense.
- `calorieRecipeSuggestionsProvider` / `remainingCaloriesTodayProvider` /
  `calorieNudgeDismissedProvider` (new,
  `lib/presentation/state/calorie_recipe_nudge_provider.dart`) — standard
  `autoDispose` `FutureProvider`s, same shape as the existing
  `restockSuggestionsProvider`.
- `CalorieRecipeNudgeCard` (new home-screen widget,
  `lib/presentation/screens/home/widgets/calorie_recipe_nudge_card.dart`) —
  same visual language as `AvoNudgeCard`/`PendingSplitsBanner` (paper card,
  Avo mascot header, dismiss ✕), showing up to 3 recipe rows (thumbnail,
  name, "X kcal · Y min", tap → `/recipes/:id`, the same in-shell route
  `RecipeOfTheWeekCard` already uses). Renders nothing for users who haven't
  opted into calorie tracking, haven't configured a goal, have too little
  budget left, already dismissed it today, or have no stored-nutrition recipe
  that fits — never a fake/empty card. Dismissal is a simple date-scoped
  SharedPreferences flag (resets automatically the next day), invalidated via
  `ref.invalidate` on tap, same pattern the restock card's snooze uses.
  Wired into `home_screen.dart` directly under the existing `AvoNudgeCard`.
- **Evening reminder.** `MascotNotificationService.rearmDinnerIdeasReminder()`
  (new method, same file as the existing restock reminder — kept in one
  service since the file is explicitly "Avo's notification voice"): schedules
  a local notification for 18:00 *today* (never pushed to a future day, since
  the remaining-calorie budget is date-specific — if it's already past 18:00
  or nothing fits, it simply arms nothing until the next re-arm recomputes it
  fresh tomorrow), gated by the same `NotificationCategory.avoNudges`
  preference the restock reminder already uses (per the idea's own
  recommendation: "reuse the avoNudges gate"). Wired into the *exact* same
  four re-arm call sites as `rearmRestockReminder` (`app.dart` init + resume,
  `main.dart` sign-in/sign-out, `avo_settings_bridge.dart`'s notification
  toggle, `notifications_screen.dart`'s master/category toggles), plus one
  extra call site specific to this feature: `avo_settings_bridge.dart`'s
  `_setCalorieTracking` handler, so turning calorie tracking on/off via Avo
  chat immediately re-arms (or clears) the reminder instead of waiting for
  the next natural resume.
- Broadened the existing `avo_restock_reminders`/`_desc` settings-screen
  strings (EN/DE) to describe both reminder types under the one toggle,
  rather than adding a second category — there's one Avo-nudges preference,
  it should describe what it actually controls.
- 8 new EN/DE translation key pairs for the card and notification copy.

**Design decisions:**
- No live API calls anywhere in this feature — deliberately scoped to only
  recipes that already have stored nutrition data, so there's no Gemini-rate
  or Supabase-load concern to design around (unlike the home-price-card idea,
  which would need real caching before it's safe to auto-run on every home
  visit — see the still-open idea below).
- The evening reminder recomputes fresh on every re-arm rather than being a
  recurring daily alarm — consistent with the restock reminder's philosophy
  of "only fire when the in-app card hasn't been the surface," and avoids
  ever sending a stale suggestion for calories already eaten.
- Recipes without stored nutrition are silently skipped, not estimated on
  the spot — an explicit non-goal, to avoid a background/passive feature
  quietly burning Gemini calls or showing a slow-loading card.

**Not verified (no macOS/Xcode/device in this container):** the card's actual
rendering on a real screen (thumbnail loading/wrapping, dismiss animation);
a live evening notification actually firing at 18:00 on a device; whether a
real account's saved/popular/recent recipes contain enough
`nutrition.calories`-populated rows for the card to ever have something to
show in practice (this depends on how many recipes in the live DB have had
nutrition estimated via `get_recipe_nutrition` or the recipe-detail screen —
not itself verifiable from this container, since it requires a live Supabase
read against real content, not just schema/RLS shape).

**Explicitly NOT done this session (still open):**
- The other two recommended cross-feature wins:
  - Home-screen "€X cheaper at [store] this week" card
    (`basketComparisonProvider`) — deliberately deferred: unlike this
    feature, auto-running it on every home-screen visit for every user would
    fire a live marktguru search per unchecked item on the user's
    most-recently-touched list, and the existing basket-comparison provider
    has no caching layer (it's `autoDispose`, recomputed fresh every mount) —
    doing this safely needs a TTL-cached wrapper (same pattern
    `AvoNudgeService.getOfferNudges` already uses for its 6h offer cache)
    designed and reasoned through on its own, not bolted on as a second
    half-feature in the same session as a properly-scoped first one.
  - The premium-gating audit / `dealBonus` cleanup / four-recommendation-engine
    consolidation flagged in the pre-session audit above — real, but each is
    its own scoped decision, not a natural pairing with this session's work.
- No new premium upsell moment was added — the brief says "only when
  genuinely useful," and a calorie/recipe nudge card felt like the wrong
  place to introduce the first one cold; flagged as a question below instead
  of guessed at.

**Files changed:** `lib/data/services/calorie_recipe_nudge_service.dart`
(new), `lib/presentation/state/calorie_recipe_nudge_provider.dart` (new),
`lib/presentation/screens/home/widgets/calorie_recipe_nudge_card.dart` (new),
`lib/data/services/mascot_notification_service.dart` (`rearmDinnerIdeasReminder`),
`lib/app.dart`, `lib/main.dart`, `lib/data/services/avo_settings_bridge.dart`,
`lib/presentation/screens/profile/settings/notifications_screen.dart`,
`lib/presentation/screens/home/home_screen.dart`,
`lib/core/localization/app_translations.dart`.

**Checks performed:** See the environment note at the top of this document.

**Second session, 2026-07-16 (scheduled routine — this feature's dedicated
session).** Built the other "recommended first cross-feature win" flagged
by the first session and the Ideas list: the home-screen "€X cheaper at
[store] this week" card, using Feature 1's already-wired
`basketComparisonProvider`/`BasketComparison` infra — deliberately *not*
built in the same session as the calorie/recipe nudge, per that session's
own note, specifically so the required TTL-cache design got its own focused
pass instead of being bolted on.

**Before this session:** `basketComparisonProvider` (Feature 1) computes a
full per-store price comparison for a list's open items, but was only ever
reachable by opening a list and tapping its summary bar — the home screen,
the highest-traffic screen in the app, never surfaced it. Running it blind
on every home visit was flagged as unsafe: it fires one live marktguru
search per open list item (up to 25), and the provider itself has no
persistent cache (`autoDispose`, recomputed fresh every mount) — doing this
for every user on every app open would be a real risk of hammering an
unofficial, keyless-auth third-party API.

**What I implemented:**
- **`HomePriceHighlight`** (new, `lib/data/models/home_price_highlight.dart`)
  — a small, JSON-serializable result: which list, which store is cheaper,
  which store it's being compared against, the savings amount, and
  matched/total item counts. Carries its own `signature` (the exact
  list+items+zip snapshot it was computed from) so the cache and the
  dismiss action both key off the same value without recomputing it twice.
- **`HomePriceComparisonCacheService`** (new,
  `lib/data/services/home_price_comparison_cache_service.dart`) — persistent
  SharedPreferences cache, same shape as `AvoNudgeService`'s existing 6h
  offer-nudge cache: `load(signature)` returns a hit/miss (a cached *null*
  result — "checked this snapshot, no meaningful highlight" — is a valid,
  storable answer, distinct from "not computed yet"), `save`, plus
  `isDismissed`/`dismiss` keyed by the same signature so dismissing one
  specific claim doesn't suppress a genuinely different one that shows up
  later.
- **`homePriceHighlightProvider`** (new,
  `lib/presentation/providers/price_comparison_provider.dart`) — the
  caching wrapper this idea explicitly called for:
  1. Requires a **real** zip (GPS or manual) — never claims a "this week"
     saving from the nationwide fallback zip, same rule the offer nudges
     already follow.
  2. Scans up to 5 recently-updated lists using only cheap local reads
     (`uncheckedCount` from the already-loaded list summary, then a plain
     `ItemRepository.getListItems` call — deliberately *not*
     `itemsNotifierProvider`, since that creates a persistent
     `StateNotifier` with an open realtime subscription; using it here
     would leak a live subscription for every candidate list scanned past,
     not just the one actually compared).
  3. Only for the **first** list that both has ≥3 real open items and has
     no fresh cache entry does it run the actual `basketComparisonProvider`
     computation — so a single home-screen visit costs at most one basket
     comparison, never one per candidate list.
  4. Caches the result (including a "no highlight" outcome) for 6h per
     exact signature, so a repeat visit with an unchanged list is a pure
     cache read with zero network calls.
- **Selection logic** (`_deriveHomeHighlight`): requires ≥3 comparable
  (multi-store-matched) items and ≥2 stores with real offers, and only
  surfaces the highlight when the saving is ≥€1.50 — a stricter bar than
  the in-list comparison sheet, since this is a proactive claim the user
  didn't ask to see, not something they opened a sheet to check. Compares
  the cheapest store against the **second**-cheapest, not the priciest
  outlier — verified with a throwaway test (see Checks) — so "cheaper at
  Aldi than Rewe" is a fair comparison between two real options, not a
  cherry-picked worst case that would overstate the saving.
- **`PriceComparisonNudgeCard`** (new,
  `lib/presentation/screens/home/widgets/price_comparison_nudge_card.dart`)
  — placed on the home screen right after the calorie/recipe nudge card,
  matching the existing card style (paper surface, rounded, dismiss ✕).
  Tapping it opens the relevant list; the ✕ dismisses this exact
  comparison (via the cache service's signature-keyed dismiss) and
  invalidates the provider so the card disappears immediately rather than
  waiting for the next cache expiry.
- 2 new EN/DE translation keys (`home_price_highlight_title`,
  `home_price_highlight_subtitle`).

**Two real bugs caught by `flutter analyze` before committing (not just
style nits):**
1. The first draft used `ref.watch(listsNotifierProvider.future)` and
   `ref.watch(itemsNotifierProvider(id).future)` — but both are plain
   `StateNotifierProvider`s, which don't expose a `.future` combinator (only
   `FutureProvider`/`StreamProvider` families do). This would have failed
   to compile, not silently misbehaved — caught immediately by the analyzer
   (`undefined_getter`), fixed by reading `.valueOrNull` synchronously, the
   same pattern `basketComparisonProvider` itself already uses for the same
   providers.
2. `HomePriceCacheLookup` (a supporting result type) was originally
   private (`_CacheLookup`) but returned from a public method — an
   `library_private_types_in_public_api` info-lint. Fixed by making the
   type public, since real callers outside the file need it.

**Explicitly not done / deliberately deferred:**
- **No premium gating.** The idea's own write-up flags this card as "a
  plausible premium-gate candidate," but per the Feature 8 first-session
  note, that's a business decision requiring an explicit answer to the
  still-open "where should the app's first real premium gate go" question
  — not guessed at here.
- **Only one list is compared per visit**, by design (see point 3 above) —
  a user with several long, equally-recently-updated lists only ever sees a
  highlight for one of them per cache window, not the objectively best
  saving across all their lists. A cross-list "best saving anywhere" version
  would need to run the expensive comparison for every candidate, which is
  exactly the API-hammering risk this session's caching design exists to
  avoid.
- **The `dealBonus`/four-recommendation-engine cleanup and the premium-gating
  decision remain open**, unchanged from the first session's audit — still
  flagged as their own scoped follow-ups below.

**Not verified (no macOS/Xcode/device in this container):** the actual card
rendering on a real screen, tap-through to the list, or the dismiss-then-
reappear-after-cache-expiry behavior end to end. The selection logic,
caching gate, and signature/dismiss keying are analyzer-verified and
unit-tested via a throwaway script (see Checks).

**Files changed (second session):**
`lib/data/models/home_price_highlight.dart` (new),
`lib/data/services/home_price_comparison_cache_service.dart` (new),
`lib/presentation/screens/home/widgets/price_comparison_nudge_card.dart`
(new), `lib/presentation/providers/price_comparison_provider.dart`
(`homePriceHighlightProvider` + helpers),
`lib/presentation/screens/home/home_screen.dart` (card wired in),
`lib/core/localization/app_translations.dart` (2 new EN/DE keys).

**Checks performed (second session):** See the environment note at the top
of this document for the full `flutter analyze`/`flutter test` results and
the live marktguru API re-verification (done as part of this session's
Feature 1 audit, not repeated here). The `_deriveHomeHighlight` selection
logic was verified with a throwaway `dart run` script (4 cases — below-
threshold matched count, only one comparable store, savings below the €1.50
floor, and the cheapest-vs-second-cheapest comparison choice with a
deliberately extreme third "worst outlier" store present to confirm it's
correctly ignored — all passed, not committed, deleted before finishing).

**Third session, 2026-07-17 (scheduled routine, second run of the day —
this feature's dedicated session).** Executed the recommendation-engine
consolidation pass that both prior Feature 8 sessions deferred and the
Ideas list carried as recommendation-`yes` ("strip the now-fully-inert
`dealBonus` hook from `RecommendationService`, and decide whether
`ProductMatchingService`/`DealsDatabaseService`/`ExtractedDeal` should go
too").

**The headline finding — a correction to two prior write-ups.** The idea
(and the 2026-07-03 Feature 1 session, and the 2026-07-08 daily code
review of `product_matching_service.dart`) all described
`RecommendationService` as *live*, "reachable from `list_detail_screen.dart`
via `RecommendationsSection`," which is why the idea asked for a cautious
surgical strip of one scoring term rather than deletion. That belief was
wrong, and traceably so: `list_detail_screen.dart` has only ever mounted
`MLRecommendationsSection` (verified against commit `65b615e`, the commit
that created the screen — it never contained the non-ML section), and every
grep that "confirmed" the non-ML path live was hitting a substring trap —
`MLRecommendationsSection` contains `RecommendationsSection`, and
`ml_recommendation_service.dart` literally ends with the substring
`recommendation_service.dart`, so filename greps matched the wrong file.
Re-run with word-boundary-safe patterns, the whole non-ML chain closes on
itself with zero external references:

`RecommendationsSection` (0 users) → `recommendations_provider.dart` (only
user: the section) → `RecommendationService` (only user: that provider) →
`ProductMatchingService` (only user: that service) → `DealsDatabaseService`
(only user: that service; its SQLite table `shoply_deals.db` is its own
file, shared with nothing, and has been permanently empty since the OCR
extractor deletion — nothing ever wrote to it even before that) →
`ExtractedDealModel` (only users: the two services above).

**What was deleted (every file verified zero external references, whole
repo including `test/`, word-boundary-safe):**
- The dead non-ML chain (6 files): `lib/presentation/widgets/recommendations/recommendations_section.dart`,
  `lib/presentation/state/recommendations_provider.dart`,
  `lib/data/services/recommendation_service.dart`,
  `lib/data/services/product_matching_service.dart`,
  `lib/data/services/deals_database_service.dart`,
  `lib/data/models/extracted_deal_model.dart`.
- The two other dead engines from the first session's "four recommendation
  engines" audit (3 files): `lib/data/services/shopping_recommender_service.dart`
  (0 references anywhere — it even declared its own conflicting
  `RecommendationItem` class), `lib/data/services/smart_recommendation_engine.dart`
  + its sole user `lib/presentation/widgets/recommendations/smart_recommendations_widget.dart`
  (the widget itself has 0 users).
- **Dependency cleanup:** `sqflite` and `string_similarity` were direct
  `pubspec.yaml` dependencies used *only* by the deleted files. Both
  removed. `sqflite` stays in the dependency tree transitively (pulled by
  `cached_network_image`'s cache manager), so the iOS Pod set is unchanged
  — zero native-build risk; `string_similarity` (pure Dart) drops out of
  `pubspec.lock` entirely. The lockfile was hand-edited minimally (sqflite
  `direct main` → `transitive`, string_similarity block removed) rather
  than committed from this container's `pub get`, which would have smuggled
  in unrelated version downgrades (this container's Flutter 3.35.6 is older
  than the SDK the committed lock was resolved with).

**What this leaves (the consolidation result):** exactly one
recommendation engine — `MLRecommendationService` →
`ml_recommendations_provider.dart` → `MLRecommendationsSection`, live in
`list_detail_screen.dart` — plus the shared `recommendation_item.dart`
model and `recommendation_card.dart` widget, both of which the live ML
path uses (kept). The `dealBonus` question from the idea is fully
resolved: not stripped from a live path, but gone with the dead path it
lived on.

**Explicitly NOT done (unchanged):** the premium-gating decision and the
weekly nutrition summary — both still need an owner call (see Ideas). No
new user-visible surface was added this session; this was the flagged
cleanup pass, and bundling a needs-decision feature into it would have
contradicted the very flag that scoped it.

**Files changed (third session):** the 9 deletions above, `pubspec.yaml`,
`pubspec.lock`, this file.

**Checks performed (third session):** downloaded Flutter 3.35.6 stable
fresh into `/tmp/flutter`; full-project `flutter analyze` baseline (via
`git stash`) **603 issues (0 errors, 59 warnings, 544 info)** vs.
after-change **601 issues (0 errors, 59 warnings, 542 info)** — diffed
with line numbers normalized: the only two lines that left are info lints
inside two of the deleted files (`unintended_html_in_doc_comment` in
`extracted_deal_model.dart`, `depend_on_referenced_packages` in
`deals_database_service.dart`); zero new issues of any severity.
`flutter test` passes ("All tests passed"). Reachability of every deleted
symbol re-verified with word-boundary-safe greps across `lib/` and `test/`
(the substring trap that misled prior sessions is exactly why). No iOS
build/device test possible here (no macOS/Xcode) — but this change is
pure deletion of never-mounted Dart code plus a dependency-graph no-op
(pods unchanged, see above), so device risk is limited to "the app builds,"
which `flutter analyze`'s zero errors already covers at the Dart level.

**Fourth session, 2026-07-18 (scheduled routine — this feature's dedicated
session).** Per the same walk every recent session does: Features 1–2 remain
blocked on hard externals/device QA; Feature 3's two open items are
device-confirmation- or decision-gated; Features 4–7's open items are all
needs-decision or device-QA (confirmed by re-reading each section's
"Explicitly NOT done" list, not just trusting the table). Feature 8's own
Ideas list had nothing left at unconditional recommendation-`yes` (the
weekly-nutrition-summary and premium-gating items are both explicitly
"needs decision", and the one `yes` item — deleting `VoiceAssistantPlugin.swift`
— is Feature 3's and still waiting on real-device confirmation of the
`AppIntents.swift` fix). So this session did fresh discovery instead of
picking from the log: audited the Feature 2 (splitting) ↔ Feature 8
(cross-feature UX) boundary directly, since the original brief's own
worked example is "Split yesterday's Lidl trip with Max and Jonas" / "Split
this trip with your roommates?" — a case Feature 2's sessions built the
*mechanics* for (the split sheet, paid/unpaid tracking, the
already-owed/owing home banner) but never a *proactive prompt*. Today,
after completing a shared list, the app silently deletes the checked items
and shows a plain success snackbar — nothing ever suggests splitting the
cost, even though `ExpenseSplitService`/`showSplitCostSheet` have existed
since Feature 2's first session. A user only discovers cost-splitting by
independently opening Shopping History and tapping a trip. This is exactly
the brief's own headline cross-feature example, fully scoped, and needs no
business/premium decision — a clean, unconditional pick.

**What I implemented:**
- **Real bug fixed while reading the code path this session touches:**
  `ShoppingHistoryService.completeShoppingTrip()` already calls
  `PurchaseTrackingService.trackPurchases(items)` internally — but
  `list_detail_screen.dart`'s `_completeShoppingTrip()` called
  `trackingService.trackPurchases(checkedItems)` a **second time** right
  after, for every single completed trip. `_trackSingleItem`'s upsert isn't
  idempotent (it appends to `purchase_dates`, doubles `purchase_count`, and
  recomputes `average_days_between` from now-duplicated same-day
  timestamps), so this was silently corrupting `item_purchase_stats` on
  every trip completion — the exact table `AvoNudgeCard`'s "you usually buy
  milk every 5 days" nudge (Feature 5) and the live `MLRecommendationService`
  (Feature 8's third session confirmed it the one real recommendation
  engine) both read. Removed the redundant call site; the service's own
  call is the single source of truth. This was pre-existing, not introduced
  by this session's other changes — found by tracing exactly what the
  `_completeShoppingTrip` function this session's work touches actually
  does end to end.
- **`ShoppingHistoryService.completeShoppingTrip()` now returns the created
  `ShoppingHistory`** (was `Future<void>`) instead of discarding it — the
  one caller (`list_detail_screen.dart`) needed it to open the split sheet
  without a redundant re-fetch; every field is already known synchronously
  at insert time, so this costs nothing extra.
- **Immediate in-context nudge:** after a shared-list trip completes (list
  has ≥2 members, checked via the existing `ListRepository.getListMembers`),
  the completion `SnackBar` now carries a "Split cost" action button that
  opens the existing `showSplitCostSheet` pre-filled with the just-completed
  trip. Solo lists get the plain snackbar unchanged — no new UI noise for
  the common case.
- **Persistent home-screen nudge**, for anyone who doesn't act on the
  snackbar (or wasn't looking at the screen when the trip completed):
  - `ExpenseSplitService.getUnsplitTripNudgeCandidate()` (new) — scans the
    user's 5 most recent shared-list trips (newest first) and returns the
    first one that has no `expense_splits` row yet and has ≥2 list members,
    stopping the scan entirely once a candidate older than 7 days is hit
    (everything after is stale too, by sort order) so it never resurfaces
    an old forgotten trip. `UnsplitTripCandidate` (new, same file) is the
    lightweight result DTO.
  - `SplitNudgeCacheService` (new,
    `lib/data/services/split_nudge_cache_service.dart`) — single
    last-dismissed-trip-id in SharedPreferences, same shape as
    `HomePriceComparisonCacheService`'s dismiss key: dismissing this exact
    trip suppresses it permanently, but any different trip (older or newer)
    still surfaces normally.
  - `unsplitTripNudgeProvider` (new, `expense_split_provider.dart`) —
    combines the candidate fetch with the dismiss check, `autoDispose` so it
    re-evaluates fresh each time the home screen mounts.
  - `SplitTripNudgeCard` (new home-screen widget,
    `lib/presentation/screens/home/widgets/split_trip_nudge_card.dart`) —
    same visual language as `PriceComparisonNudgeCard`/`PendingSplitsBanner`
    (paper card, icon, dismiss ✕); shows the amount when known
    ("≈ €X total — tap to split") or a plain prompt when not; tapping opens
    the same `showSplitCostSheet`. Wired into `home_screen.dart` directly
    under `PendingSplitsBanner` (existing pending splits above, "here's a
    trip you haven't split yet" right below — a natural grouping).
  - 6 new EN/DE translation keys.

**Design decisions:**
- No live/expensive calls: the candidate scan is plain Supabase reads
  (`shopping_history`, `expense_splits`, `list_members`), same complexity
  class as `_sendShoppingCompleteNotifications` (an existing N+1-style scan
  in the same file) — nothing like the marktguru-API-per-item concern that
  justified `homePriceHighlightProvider`'s TTL cache, so no caching layer
  was needed here, only the dismiss flag.
- Deliberately did **not** gate the nudge on `total_cost` being known — the
  split sheet already lets the user type a total manually, so requiring a
  priced trip first would silently exclude every trip whose items never
  matched a live offer.
- The snackbar action and the home card are two surfaces for the same
  underlying state (an unsplit trip), not two separate features — the
  snackbar is the immediate opportunity, the card is the persistent one for
  anyone who skips it. Neither duplicates the other's data source
  (`historyEntry` returned in-hand vs. a fresh provider fetch).

**Not verified (no macOS/Xcode/device in this container):** the actual
`SplitTripNudgeCard`/`SnackBarAction` rendering on a real screen; the
purchase-tracking bug fix's real-world effect on `AvoNudgeCard` (would need
a live account with a purchase history already skewed by the old
double-counting to observe a visible change — the fix itself is a
straightforward call-site deletion, verified by grepping for remaining call
sites, not something that needs a device to confirm is *correct*, only to
watch it *render*).

**Files changed:** `lib/data/services/shopping_history_service.dart`
(`completeShoppingTrip` returns `ShoppingHistory`),
`lib/presentation/screens/lists/list_detail_screen.dart` (duplicate
`trackPurchases` call removed, split SnackBarAction added),
`lib/data/services/expense_split_service.dart`
(`getUnsplitTripNudgeCandidate` + `UnsplitTripCandidate`),
`lib/data/services/split_nudge_cache_service.dart` (new),
`lib/presentation/state/expense_split_provider.dart`
(`unsplitTripNudgeProvider`),
`lib/presentation/screens/home/widgets/split_trip_nudge_card.dart` (new),
`lib/presentation/screens/home/home_screen.dart` (card wired in),
`lib/core/localization/app_translations.dart` (6 new EN/DE keys).

**Checks performed (fourth session):** downloaded Flutter 3.35.6 stable
fresh into `/tmp/flutter`; full-project `flutter analyze` baseline (via
`git stash`) **601 issues (0 errors, 59 warnings, 542 info)** vs.
after-change **601 issues, byte-identical** — confirmed by also scoping
`flutter analyze` to just the 8 new/touched files (1 issue, a pre-existing
`unnecessary_cast` in `expense_split_service.dart` re-verified present at
its original line in the pre-session baseline too, i.e. not new — every
other touched/new file is fully clean). `flutter test` passes ("All tests
passed"). The candidate-scan selection logic (newest-first scan, skip
already-split, skip solo lists, stop entirely past the 7-day cutoff, and
the boundary case of exactly 7 days still counting as fresh) was verified
with a throwaway `dart run` script mirroring the exact loop (6 cases, all
passed, not committed, deleted before finishing). `pubspec.lock` churn from
`flutter pub get` with the freshly-downloaded SDK was reverted before
committing. No iOS build/device test possible here (no macOS/Xcode) — see
"Not verified" above.

---

## Ideas / Needs My Approval

- [ ] IDEA: Assistant-owned memory across chat sessions — persist a small
  set of durable facts Avo learns in conversation ("household of 3",
  "shops at Lidl on Saturdays", "doesn't eat pork") to a `users` JSONB
  column or a small `assistant_memory` table, re-injected into the system
  context each session.
  - Why it helps: Feature 4's original brief lists "assistant
    memory/preferences if the architecture supports it"; today the context
    is rebuilt from live app state each turn, so anything the user *told*
    Avo that isn't a formal setting is forgotten when the chat resets.
    (This idea was referenced in Feature 4's notes as "flagged below" but
    had never actually been added to this list — fixed now.)
  - Expected user value: medium-high — the assistant stops re-asking known
    things and feels genuinely personal.
  - Expected business/premium value: medium (retention; plausible premium
    surface as "Avo remembers you").
  - Complexity: Medium — needs a schema decision (what's allowed to be
    remembered), a size cap, and a way for the user to view/delete memory
    (privacy — this is the real design work, not the plumbing).
  - Risk: Medium — storing free-text inferences about a user touches
    privacy expectations; needs an explicit user-visible memory list with
    delete, not a silent store.
  - Recommendation: needs decision — worth doing, but only with the
    view/delete UI included from day one.

- [ ] IDEA: Re-enable `mobile_scanner` for real camera barcode scanning in
  the Feature 6 food-log barcode tab (currently manual numeric entry +
  Open Food Facts lookup).
  - Why it helps: "scan the barcode" is the expected UX for packaged food
    logging apps; manual entry works but is more friction than users expect.
  - Expected user value: medium-high — barcode scanning is one of the most
    used actions in apps like this.
  - Expected business/premium value: low-medium (retention via less
    friction).
  - Complexity: Medium — the package is commented out specifically for iOS
    build issues (`CLAUDE.md`), so this needs a session with a real
    Xcode/simulator build to verify before shipping, not a blind uncomment.
  - Risk: Medium without build verification (that's exactly why it's
    commented out today).
  - Recommendation: needs decision — do this in a session with real iOS
    build access.

- [x] IDEA (DONE 2026-07-14, Feature 6's second session): Build diet
  challenges (16:8 fasting, 30-day no sugar) on top of the already-live
  `nutrition_challenges` table.
  - **Outcome:** implemented as `DietChallenge`/`DietChallengeService`/
    `ChallengesScreen`/`ChallengesEntryCard` — catalog, daily check-in,
    streaks, auto-completion at day 30 for the fixed-length challenge,
    history. The "premium challenges" upsell angle from this idea's original
    write-up is not done — flagged as its own idea below since it's a
    Feature 8 (monetization) concern, not core Feature 6 scope.

- [x] IDEA (DONE 2026-07-06, Feature 4's seventh session): Wire calorie
  tracking into Avo — nutrition status/remaining, `log_food` for "I just
  ate a banana", water/weight logging, diary-entry deletion with
  confirmation, and calorie-aware recipe suggestions.
  - **Outcome:** implemented as `get_nutrition_status`, `log_food`,
    `log_water`, `log_weight`, `delete_food_log`, the `calorie_tracking`
    settings key, and `calories_per_serving` in search_recipes results.
    The Feature-5 half of the idea (proactive "N calories left — 3 dinner
    ideas" *nudges*, i.e. notifications rather than chat answers) is NOT
    done — that belongs to a Feature 5/8 session on top of the
    now-existing tools. Details in Feature 4's seventh-session notes.

- [x] IDEA (DONE 2026-07-14, Feature 6's second session): Upload meal photos
  to Supabase Storage instead of discarding them after the AI estimate is
  extracted.
  - **Outcome:** new `meal-photos` bucket (public read, own-folder write,
    same shape as `profile-pictures`) + `MealPhotoStorageService` + wired
    into `food_entry_sheet.dart`'s save flow + a thumbnail in `FoodLogTile`.
    Not verified against a real device/camera photo end-to-end (no
    macOS/Xcode in this container) — see Feature 6's second-session "Not
    verified" note.

- [ ] IDEA: "Premium: unlock challenge history / advanced adherence stats"
  or a premium-only third challenge type, as a Feature 8 monetization touch
  on top of the now-existing challenges feature.
  - Why it helps: the brief explicitly calls out premium upsells "only where
    genuinely useful" — challenges are a natural low-pressure spot once a
    user has run one to completion and wants to see long-term patterns.
  - Expected user value: low-medium (most value is in using a challenge, not
    reviewing its stats).
  - Expected business/premium value: medium — a soft, non-blocking upsell
    moment, unlike gating the core check-in loop itself.
  - Complexity: Low once Feature 8's premium-gating audit happens.
  - Risk: Low, as long as basic challenge participation stays fully free
    (gating the core loop would contradict "optional, not forced").
  - Recommendation: needs decision — belongs in a Feature 8 session, not
    this one.

- [x] IDEA (weekly-summary half DONE 2026-07-18, Feature 6's third session):
  A weekly nutrition summary screen/card ("you averaged X kcal, hit your
  protein target Y/7 days").
  - **Outcome:** built as `WeeklySummaryScreen` + `WeeklyNutritionSummary`
    (pure, unit-tested computation) + a tappable weekly strip/"Wochenrückblick"
    link on the dashboard, including a gentle ≥2-day logging streak row (the
    brief's "Streaks, but not too aggressive" bullet). The original
    needs-decision flag was re-examined against the brief: "Weekly progress
    summary" is an explicit Feature 6 autonomy bullet, so it didn't actually
    need an owner decision. Details in Feature 6's third-session notes.
  - The "premium: monthly trends" upsell angle was NOT built (still part of
    the open premium-gating decision below).

- [ ] IDEA: A first-class in-app "what can I still eat today?" surface — the
  chat version already works via Avo (`get_nutrition_status` →
  `search_recipes`), but there's no dedicated UI for a user who doesn't want
  to open chat for it.
  - Why it helps: turns remaining-calories into an actionable "here are 3
    dinner ideas that fit" moment right on the dashboard.
  - Expected user value: medium.
  - Expected business/premium value: low-medium.
  - Complexity: Medium — would reuse the recipe-filtering logic Feature 4's
    Avo tool and Feature 8's `CalorieRecipeNudgeService` already have; the
    real question is placement/overlap with the existing home-screen
    calorie-recipe nudge card, which is a product call.
  - Risk: Low.
  - Recommendation: needs decision — split out from the (now done) weekly
    summary idea above; unlike that one, this has no explicit brief bullet
    and overlaps an existing surface.

- [x] IDEA (DONE 2026-07-16, Feature 3's seventh session): Proactively
  re-push the widget's cached Supabase access token on every token refresh,
  not just app launch/auth-state change.
  - **Outcome:** implemented as `WidgetService.syncCredentialsFromSession()`
    called from `main.dart`'s global `onAuthStateChange` listener on
    `initialSession`/`signedIn`/`tokenRefreshed` (global rather than
    `home_screen.dart` as originally suggested, so it fires regardless of
    which screen is mounted); `home_screen.dart` now delegates to the same
    helper. Details in Feature 3's seventh-session notes.

- [ ] IDEA: Widget-side "token stale" UX — when a widget REST call fails
  with 401 (app hasn't been opened in >1h so the cached token expired),
  have the widget render a small "Open the app to sync" hint instead of
  silently no-oping the tap.
  - Why it helps: the re-push fix above keeps the token fresh while the app
    process is alive, but a tap days after last app use still silently does
    nothing — the one remaining silent-failure mode. A *real* fix (widget
    refreshing the token itself with the cached refresh token) was
    deliberately rejected: Supabase rotates refresh tokens on use, and two
    processes racing on one token family can revoke the whole session —
    a forced logout is far worse than a no-op tap.
  - Expected user value: medium — turns a confusing dead tap into an
    actionable instruction.
  - Expected business/premium value: low (trust/retention).
  - Complexity: Medium — the intent would write a "stale" flag to the App
    Group on 401 and the widget views would render the hint until the next
    credential push clears it; needs a real device to verify the flow.
  - Risk: Low-medium (Swift-only change, unverifiable in this container).
  - Recommendation: needs decision — worth it if device QA confirms the
    expired-token no-op actually bites in practice.

- [x] IDEA (DONE 2026-07-17, Feature 3's eighth session): Remove the
  confirmed-dead Siri method-channel plumbing (`SiriService.dart`'s
  `com.shoply.app/siri` channel, `home_screen.dart`'s
  `_checkSiriPendingItems()`) now that Feature 3's fifth session replaced it
  with the working deep-link-based flow.
  - **Outcome:** `lib/core/services/siri_service.dart` deleted outright (its
    only two live call sites — `main.dart`'s `initialize()` and
    `home_screen.dart`'s `_checkSiriPendingItems()` — were both removed, and
    every other method on the class had zero callers to begin with);
    `home_screen.dart`'s dead method + its now-unused `siri_service.dart`/
    `category_detector.dart` imports removed. `flutter analyze` came back
    with *fewer* issues than baseline, not just byte-identical — the deleted
    code carried 6 pre-existing `empty_catches` lints plus one genuine
    `await_only_futures` bug (`await`ing `AsyncValue.whenData()`, which
    returns `void`) that's now gone along with the rest of the dead method.
    Details in Feature 3's eighth-session notes.

- [ ] IDEA: Delete the last remaining dead Siri legacy code:
  `ios/Runner/VoiceAssistantPlugin.swift` (unbuilt, unregistered, no Dart
  caller — `SiriService.dart` and `home_screen.dart`'s
  `_checkSiriPendingItems()` were already deleted in Feature 3's eighth
  session, see above).
  - Why it helps: one last confirmed-dead code path for the superseded Siri
    architecture is confusing for whoever touches this next — the fifth
    session almost built on top of the wrong one before tracing the
    App-Group-vs-standard-UserDefaults process boundary all the way through.
  - Expected user value: none directly (already invisible; the real path is
    the new `shoply://add-item` deep link).
  - Expected business/premium value: none directly; prevents a future
    regression where someone "fixes" the dead path instead of the live one.
  - Complexity: Low (pure deletion, one Swift file, already confirmed zero
    build-target membership and zero Dart caller).
  - Risk: Low, but it's a Swift-only file this container cannot compile —
    unlike the Dart-side deletion above, there's no `flutter analyze`/
    `flutter test` safety net for a Swift-only deletion.
  - Recommendation: yes, as a small follow-up once the Feature 3 deep-link
    fix (`AppIntents.swift`) has been confirmed working on a real device
    (don't want two Siri changes unverified at the same time).

- [ ] IDEA: Build a distinct "Today's list" and/or "recently used items"
  WidgetKit widget, per the original Feature 3 brief.
  - Why it helps: the existing widget covers "my one chosen list" well; a
    second widget kind (e.g. "items you buy most often, tap to add to your
    active list") adds a genuinely different quick-add surface.
  - Expected user value: medium — a real convenience, not just parity with
    what already exists.
  - Expected business/premium value: low-medium (retention via more
    home-screen surface area).
  - Complexity: Medium-high — a new WidgetKit target/kind is exactly the
    kind of change that can't be verified at all without Xcode, more so than
    editing an existing one.
  - Risk: Medium without build verification.
  - Recommendation: needs decision — do after the current widget +
    Siri/Shortcuts fixes are confirmed working on a real device, so any new
    build issue is easy to isolate to the new code.

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

- [x] IDEA (DONE 2026-07-17, Feature 8's third session — with a major
  correction): Strip the now-fully-inert `dealBonus` hook from
  `RecommendationService` (and decide whether `ProductMatchingService`/
  `DealsDatabaseService`/`ExtractedDeal` should go too).
  - **Outcome:** the premise ("touches a live, user-facing ranking path")
    was wrong — `RecommendationsSection` has zero call sites, so
    `RecommendationService` was never reachable from any screen; the
    "live" claim in this idea, the 2026-07-03 Feature 1 notes, and the
    2026-07-08 daily code review all trace back to the same substring-grep
    trap (`MLRecommendationsSection` contains the string
    `RecommendationsSection`). The entire dead chain was deleted (9 files:
    the 3 asked-about deal files, `RecommendationService` + its provider +
    section, plus the two other dead engines `ShoppingRecommenderService`
    and `SmartRecommendationEngine`/`SmartRecommendationsWidget`), along
    with the now-unused `sqflite`/`string_similarity` direct dependencies.
    `MLRecommendationService` is now verifiably the app's one
    recommendation engine. Details in Feature 8's third-session notes.

- [x] IDEA (approved, DONE 2026-07-05): Consolidate the two dead
  mascot/gamification systems into one, and make
  `users.notification_enabled` the single enforced notification gate.
  - **Outcome:** `core/gamification/` deleted; `MascotNotificationService`
    rewritten as the one data-driven Avo voice; new
    `NotificationPreferencesService` enforces master + category toggles at
    the `showNotification` choke point and syncs the FCM token so the
    master switch stops background pushes too. Details in Feature 5's
    sixth-session notes.

- [x] IDEA (approved, DONE 2026-07-09, Feature 8's first session): Proactive
  recipe-suggestion nudge — "600 kcal left today — Avo found 3 dinner ideas
  from your list."
  - **Outcome:** Implemented as `CalorieRecipeNudgeService` +
    `CalorieRecipeNudgeCard` (home screen) +
    `MascotNotificationService.rearmDinnerIdeasReminder()` (18:00 local,
    reuses the `avoNudges` gate, capped at one card/one notification a day via
    the same dismiss-for-today + re-arm-per-day pattern the restock reminder
    uses). Details in Feature 8's second-session notes above.

- [x] IDEA (DONE 2026-07-16, Feature 8's second session): Home-screen "€X
  cheaper at [store] this week" card, using the now-wired
  `basketComparisonProvider` (Feature 1 infra) — the other recommended
  first cross-feature win, deliberately not done in the same session as the
  calorie/recipe nudge above.
  - **Outcome:** Implemented as `HomePriceHighlight` +
    `HomePriceComparisonCacheService` (the caching wrapper this idea called
    for — 6h TTL, signature-keyed, mirrors `AvoNudgeService`'s offer-nudge
    cache) + `homePriceHighlightProvider` (scans up to 5 recent lists with
    cheap local reads, runs the actual comparison for at most one) +
    `PriceComparisonNudgeCard`. Compares the cheapest store against the
    second-cheapest (not the priciest outlier) for a fair, non-inflated
    claim. Details in Feature 8's second-session notes above. The premium-
    gate angle this idea's own write-up floated was deliberately **not**
    done — still needs the owner's premium-gating decision below.

- [x] IDEA (DONE 2026-07-18, Feature 8's fourth session): Proactive "split
  this trip with your roommates?" nudge after completing a shared-list
  shopping trip — the brief's own headline cross-feature example, which
  Feature 2's sessions built the mechanics for but never a proactive prompt.
  - **Outcome:** a `SnackBarAction` on the completion snackbar (immediate,
    when the list has ≥2 members) plus a persistent home-screen
    `SplitTripNudgeCard` (for the most recent unsplit shared trip, ≤7 days
    old, dismissible per-trip) — both open the existing `showSplitCostSheet`.
    Also fixed a real pre-existing bug found while tracing this exact code
    path: `_completeShoppingTrip` was calling `trackPurchases` a second time
    on top of `ShoppingHistoryService`'s own internal call, double-counting
    every completed trip into `item_purchase_stats` (the table Feature 5's
    "you usually buy X every N days" nudge and the live `MLRecommendationService`
    both read). Details in Feature 8's fourth-session notes above.

- [ ] IDEA: Server-side restock reminders (Supabase cron + the existing
  send-push-notification edge function) instead of the client-scheduled
  local notification.
  - Why it helps: the current reminder is scheduled on-device when the app
    is used, so a user who stops opening the app entirely gets at most one
    reminder (the last one armed). A daily cron could compute due items in
    SQL (the same `item_purchase_stats` rules) and push, honestly gated by
    `users.notification_enabled` + a per-user nudge opt-out column.
  - Expected user value: medium-high — this is the actual "bring users
    back" channel.
  - Expected business/premium value: high (retention loop).
  - Complexity: Medium (SQL port of the eligibility rules; snooze state
    would need to move server-side to be respected).
  - Risk: Medium — real push spam potential if the caps aren't right; needs
    careful frequency capping (e.g. max 2/week).
  - Recommendation: needs decision — only after the on-device version has
    proven the copy/frequency feels right to you.

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

- [x] IDEA (approved, DONE 2026-07-06): Build calorie tracking (Feature 6) as
  its own dedicated multi-session effort with build verification available,
  following the phased plan above, rather than attempting it piecemeal.
  - **Outcome:** Built in the 2026-07-06 session (models, services, full
    dashboard/goal-setup/food-log UI, Mifflin-St Jeor calculator) — see
    Feature 6's session notes. Left as historical context below rather than
    deleted, since the "please confirm the formula/scanner approach"
    questions it raised are still relevant to the two open ideas about
    barcode scanning and diet challenges further down.
  - Why it helped: avoids shipping a half-working, unverified nutrition
    feature that touches user health data.
  - Expected user value: high (explicitly requested, large feature area).
  - Expected business/premium value: high (Lifesum-style tracking is a
    strong premium upsell surface per the original brief).
  - Complexity: High.
  - Risk: Medium if rushed without verification; low if properly scoped.
  - Recommendation (historical): needs decision — specifically, please confirm the goal
    calculation formula/source you want (e.g. Mifflin-St Jeor) and whether
    barcode scanning should re-enable `mobile_scanner` or use a lighter
    camera+Gemini-vision approach, before a follow-up session starts on it.

- [x] IDEA (approved, DONE 2026-07-08): Rebuild onboarding (Feature 7)
  immediately after Feature 6's schema is settled, replacing the static
  carousel with the adaptive flow.
  - **Outcome:** Added a diet-preference page and a conditional goal
    questionnaire page (reusing Feature 6's `NutritionGoalCalculator`), plus
    `OnboardingAnswersService` to actually apply those answers to the
    account once one exists (`onboarding_completed`, `diet_preferences`,
    `nutrition_goals`). **Not done as originally scoped:** rewiring the
    router's `redirect:` to branch on `onboarding_completed` — traced the
    full redirect function and found a logged-in user already bypasses
    `/onboarding` unconditionally, so the router side had no real bug to
    fix; see the new account-scoped-gate idea below for the one genuine
    (rare) gap this leaves. Details in Feature 7's fifth-session notes.

- [ ] IDEA: Make the pre-login onboarding gate account-scoped, not just
  device-local.
  - Why it helps: today, a user who completes onboarding on device A, then
    logs into a never-before-seen device B, sees the 3-page marketing
    carousel again before landing on `/welcome` — harmless (they can still
    tap Skip), but not "personalized," since `users.onboarding_completed`
    now genuinely reflects reality (Feature 7's fifth session gave it a real
    writer) yet the router never reads it to skip the carousel pre-login.
  - Expected user value: low-medium (saves a few taps on a second device;
    most users never hit this).
  - Expected business/premium value: low.
  - Complexity: Low-medium — the field is already correct now, this is
    purely a `redirect:` read; the tricky part is doing it only when
    genuinely known-safe offline (same "don't block app entry when offline"
    constraint the rest of that function already respects).
  - Risk: Low if scoped to read-only branching (no new writes), but it's
    auth/router code, so it deserves its own careful pass rather than a
    drive-by edit.
  - Recommendation: needs decision — low priority, real but minor UX gap.

- [ ] IDEA: Decide where the app's *first* real, enforced premium gate
  should go, now that Feature 8 is adding genuinely smart cross-feature
  moments (price comparison, calorie-aware recipe ideas) that are plausible
  "premium" hooks.
  - Why it helps: today, literally every premium perk on the paywall screen
    except recipe cooking-mode is unenforced marketing copy (see the
    premium-gating audit in Feature 8 above) — the app has real
    infrastructure for this (`PremiumFeatureGate`/`GoProButton`) sitting
    unused. Cross-feature moments like the new calorie/recipe nudge or the
    still-open price-comparison card are natural candidates ("unlimited
    price comparisons," "unlimited AI meal ideas"), but picking which
    feature to gate, and how generous the free tier should be, is a business
    call, not an engineering one — this session deliberately did not gate
    anything it built.
  - Expected user value: neutral-to-negative if done wrong (gating something
    users already expect for free feels like a bait-and-switch); positive if
    scoped to something genuinely "more" rather than "less."
  - Expected business/premium value: potentially high — this is the actual
    monetization gap in the app today.
  - Complexity: Low to wire (the gating widgets already exist) once the
    product decision is made.
  - Risk: Low technically, but a real product/trust risk if the free tier is
    cut too aggressively after users are already used to it being free.
  - Recommendation: needs decision — please confirm which feature(s) should
    get a real free-tier limit before a follow-up session wires any gating.

- [ ] IDEA: Build a non-interactive fallback view for the ShoppingListWidget/
  QuickAddWidget on iOS 13.0–16.x, now that Feature 3's ninth session traced
  the real reason the widget extension needs iOS 17+ (unconditional
  `Button(intent:)` interactive elements, no `#available` guard).
  - Why it helps: right now, a user on iOS 15.6–16.x (below the corrected
    `17.0` widget deployment target, but still within Runner's own `15.6`
    minimum) can install and use the app fully but literally cannot add the
    widget at all — it won't appear in the widget gallery. A read-only
    fallback (tap the whole widget to open the app; no per-item checkbox/
    quick-add buttons) would restore *some* widget value to that range
    instead of none.
  - Expected user value: low-medium — only matters for the slice of users on
    iOS 15.6–16.x specifically; shrinks over time as the user base ages onto
    newer iOS regardless.
  - Expected business/premium value: low.
  - Complexity: Medium — needs `#available(iOS 17.0, *)` branches around
    every `Button(intent:)` call site with a genuinely different (tappable-
    row-only, `widgetURL` deep-link) view for the `else` branch, plus
    deciding whether `QuickAddWidget` (which is *entirely* tap-to-add
    buttons, no non-interactive purpose) should just not offer itself as a
    configuration option below iOS 17 at all.
  - Risk: Low-medium — more surface area to get subtly wrong without a
    device to test either OS-version branch.
  - Recommendation: needs decision — worth doing only if you want widget
    coverage on iOS 15.6–16.x specifically; if your real user base is
    already mostly on 17+, this is low-value effort better spent elsewhere.
