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
