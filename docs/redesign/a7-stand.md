# A7 Onboarding, Login, Tipps: Ergebnis und offene Punkte (09.11.2026)

Auftrag: [`a7-auftrag.md`](a7-auftrag.md). Schrittrahmen `870da50`, Schnittstelle `e352025`, Tipps `de77f8a`–`f189222`,
Tipp-Ereignisse `3a5592d`, Ablauf und Konto siehe `git log --grep "Onboarding"`. Geprüft auf sauberem `main` (ganze
Testsuite, `dart analyze` ohne Errors/Warnings). Nicht im Simulator angesehen: echte Apple-/Google-Blätter,
Schlüsselbund, Code-Vorschlag aus Mail.

## Was jetzt da ist

- **Ablauf** (`onboarding/onboarding_flow.dart`, `OnboardingController`): Willkommen → Module → [Region] → Konto →
  [E-Mail → Code] → Name → Ernährung und Allergien → [Dein Ziel] → Erste Liste bzw. Beitreten → Liste mit
  `?arrival=new|joined|existing`. Eigener Navigator, ab dem Konto kein Zurück, Wiederaufnahme nach Abbruch (`onb_step`),
  Fortschritt zählt nur gezeigte Schritte. Region: B's `OffersSetupStep` (A-O1), ein Platzhalter ohne Inhalt wird
  übersprungen.
- **Router**: `entryRedirect` als reine Funktion; private Links ohne Konto werden als `pending_link` gemerkt (7 Tage),
  Rezept-Links und `/reset-password` bleiben offen, `/join/:code` wird zum Schritt Beitreten.
- **Konto** (`auth/steps/*`, `auth_gateway.dart`): Apple, Google (Partnerfarben), E-Mail mit 6-stelligem Code (Einfügen
  aus Mailtext, 60 s Sperre, offline wartet), Name ohne E-Mail-Präfix, Passwort anmelden, vergessen, neu (Regeln mit
  Haken). Fehlertexte nach Konzept 17 §4.6 ohne Rohfehler.
- **Tipps** (`tip_service.dart`, `widgets/tips/*`): T1–T7 an ihren Orten, höchstens einer gleichzeitig und ein neuer
  pro Tag, Wischen „Ausblenden“, „Tipps zurücksetzen“ im Profil. Altes Coach-Mark-Tutorial gelöscht.
- **Neu oder eingerichtet ohne Server-Änderung**: eingerichtet, wenn `users.onboarding_completed == true` oder das Konto
  vor `kOnboardingRedesignCutoff` (09.11.2026) angelegt wurde.

## Braucht den Owner (Server, nicht angewendet)

- **`kOnboardingRedesignCutoff` auf den Release-Tag setzen** oder den Backfill ausführen; sonst gilt ein altes Konto mit
  `onboarding_completed = null`, das nach dem 09.11.2026 angelegt wurde, als neu.
- SQL-Entwurf für Migration mit Backfill, RPC `apply_onboarding(answers jsonb)` und `invite_preview(code)` steht im
  Bericht des Teils „Ablauf“ (Kopie: [`a7-server-entwurf.sql`](a7-server-entwurf.sql)). Mit der RPC fallen
  `decideAccountStatus` und die Konstante weg.
- Supabase Auth (B trägt sie in OPEN-ISSUES §2): Mailvorlagen „Confirm signup“/„Magic Link“ mit `{{ .Token }}`
  (6 Ziffern), 60 s Mindestabstand, 3600 s Gültigkeit, Passwortregeln 8 Zeichen/Großbuchstabe/Ziffer, automatische
  Kontoverknüpfung bei bestätigter E-Mail (F-17-05).
- Offene Konzeptfragen: KI-Einwilligung im Schritt Module (F-17-03, F-17-12), Fußzeile „Deine Tabs“ (F-17-06),
  Willkommens-Satz (F-17-07), Maskottchen (F-17-11), Analytics (F-17-10).

## Von Teil B (angefragt)

- `SupabaseService.signInWithApple()` → `AppleSignInResult?` mit Nonce und Name (B baut, nach „Auth-Dateien frei“).
  `sendEmailCode`/`verifyEmailCode` sind da (`2022317`); das Gateway nutzt sie noch nicht.
- `b_slots`: `offersKillSwitchOffProvider` (bekannt und aus), `suggestStoreChain(listName)`,
  `StoreSuggestionChip(listName:, onChanged:)`, `favoriteStoreNamesProvider`, `setStoreForList(listId, chainId)` für die
  erste Liste; Vertrag `OffersSetupStep`: `onDone` in den ersten zwei Frames heißt „nichts zu zeigen“.
- T8/T9 und `note(TipEvent.avoTextMessage)` kommen mit Avo-Tab und Wochenplan (Avo-Tab: `a3a25e2`).

## Offen bei A

- §9.8 Startvorschläge vor dem ersten Buchstaben (Milch, Brot, Eier, Bananen, Butter): das Eingabefeld der Liste hat
  noch keine Vorschlagsliste (A-C4 zusammen bauen).
- T6 im Rezepte-Tab: `RecipesBrowseContent(tip:)` einbauen, danach den Ernährungs-Hinweis von A6 durch T7 als Tipp-Zeile
  ersetzen (Test `recipes_browse_screen_test.dart:271` anpassen).
- Leere Liste bei `arrival=new`: der leere Zustand doppelt T1 („… zum Beispiel „2 Milch““); laut §3.12 keine Sektionen.
- `pending_action` für Rezept-Links (§5.2), Statuszeile je Schritt, Fokus auf den Titel, Zwei-Finger-Z.
- Schritt Dein Ziel: `ValueStepper` ohne Schrittweite (Zeitraum in 1-Wochen-Schritten), kcal ohne `RollingNumber`,
  „Eigenes Ziel“ nur kcal.
- `OnboardingStepPage`: Linie folgt dem Zurück-Wischen nicht anteilig (obere Leiste gehört zur Seite).
- `AvatarSize.xl` (64 pt) fehlt; der Name-Schritt zeichnet den Kreis selbst. `AppButton` ohne graue `fill`-Variante.
- Apple-Knopf ist in Flutter gezeichnet (nativer `ASAuthorizationAppleIDButton` bräuchte `ios/`-Code).
- `LegalLinks.terms` zeigt noch auf `shoplyai.app` (Rename nach Teil B).
- Aufräumen: alte Texte `onb_sorted_*`, `onb_shared_*`, `onb_recipes_*`, `onb_priorities_*`, `onb_cal_*`,
  `onb_illus_*`, `onb_diet_*`, `onb_goal_*` (onboarding.dart), alte Schlüssel der gelöschten Login-Screens (auth.dart),
  `restart_tutorial`/`tutorial_restarted` (profile.dart), `NavigationService.navigateToDietPreferences`; Texte von A7 in
  `onboarding.dart`/`auth.dart` zusammenführen; Tutorial in `docs/ARCHITECTURE.md` (Z. 11, 23) und
  `docs/DESIGN-STATUS.md:59`.

## Bewusst abgewichen

- Module als Karten nach D2 (`X-Onboarding`) statt `ToggleRow`, Titel „Was soll Avo für dich tun?“.
- Fortschritt als `StepProgress` (96 × 3, `label`) statt D2's grüner Segmente (K-09).
- Tipp-Glühbirne in `secondaryLabel`; Ausblenden nur durch ganzes Wischen; T2 frühestens am Tag nach T1; T2/T4 auch auf
  Home; bei `arrival=existing` gelten T1–T7 als gezeigt.
- Rechtslinks im Konto-Schritt als eigene 44-pt-Links unter dem Satz.
