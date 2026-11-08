# A7 Onboarding, Login und Tipps – gemeinsamer Auftrag für die A7-Agenten (Teil A)

Stand 08.11.2026. Drei Teile laufen gleichzeitig: **„Ablauf“**, **„Konto“**, **„Tipps“**. Welche Dateien zu welchem
Teil gehören, steht unten; fremde Dateien nicht ändern, sondern im Bericht nennen.

## Ort und harte Regeln (wie A6)

- Repo `/Users/jannisdietrich/Apps/shoply-neu` (Flutter-App „Avo“, Dart-Paket heißt noch `shoply`). Jeder Bash-Befehl
  beginnt mit `cd /Users/jannisdietrich/Apps/shoply-neu && …`.
- **Teil B (andere Claude-Session) und zwei weitere A7-Agenten arbeiten gleichzeitig im Ordner.** Keine git-Befehle,
  die etwas ändern (kein add, commit, stash, checkout, switch, restore, reset, clean). Committen macht die Hauptsitzung.
- **Nur die Dateien deines Teils.** Texte nur in deiner Textdatei (unten); vorhandene Schlüssel anderer Dateien darfst du
  lesen und benutzen. Ein Schlüssel, den es schon gibt, ist ein Compile-Fehler (const-Maps): dann neuen Namen wählen.
  **Neue Texte sagen „Avo“, nie „Shoply“** (Owner 08.11.2026). Keine `\n` in Texten, keine Überzeilen/Kicker.
- Prüfen nur auf deine Dateien: `flutter test --no-pub <deine Tests>` und `dart analyze <deine Dateien>` (0 Errors,
  0 Warnings, 0 Infos in deinen Dateien). Lange Befehle mit `timeout 600`; bei „Waiting for another flutter command“
  warten. Fehler aus fremden halbfertigen Dateien ignorieren und nennen. Kein `dart format` auf fremde Ordner.
- Keine iOS-Builds, keine Simulatoren, keine Worktrees (Speicher knapp). **Keine Änderungen an Supabase** (keine
  Migration, kein SQL, keine Edge Function): Was der Server braucht, kommt in den Bericht (Owner-Freigabe nötig).
- `bash docs/redesign/owner.sh <pfad>` zeigt, wem eine Datei gehört. B-Dateien nie ändern (z. B.
  `lib/data/services/supabase_service.dart`, `lib/presentation/widgets/deals/**`, `nutrition_goal_service`).

## Pflichtlektüre vor dem Schreiben

1. `CLAUDE.md` Abschnitt „Design System“ und die harte Regel: **keine Sheets, keine halbhohen Modals, keine Slider,
   Bearbeiten im Vollbild**; zentrierte Alerts (`showAvoConfirm`) und Pull-down-Menüs (`showAvoMenu`) sind erlaubt.
2. **Konzept `docs/redesign/konzept/17-onboarding.md`**: Kap. 1 und 2 für alle, dazu die Abschnitte deines Teils.
   Optik dort ist teils überholt; D2 gewinnt. Ist-Zustand: `docs/redesign/konzept/inventar/onboarding.md`.
3. D2-Vorlage (verbindlich für die Optik): `/private/tmp/claude-501/-Users-jannisdietrich-Apps-RoadTo1Billion-/76ad5c46-b5c2-4efd-a1ef-f81b6109f927/scratchpad/d2/project/X-Onboarding.dc.html`,
   dazu `D2-Komponenten.dc.html`, `D2-Liste.dc.html` (Ankunft, Tipp-Zeile) und `D2-Home.dc.html`.
4. Komponenten in `lib/presentation/widgets/design/` (nutzen statt Eigenbau): `AppButton` (primary/secondary/plain,
   `expand`, `floating`), `InsetSection`/`SectionCaps`/Settings-Rows (`ToggleRow`, `NavRow` …), `AppFilterChip`/
   `ChipRow`, `AppTextField`/`AvoSearchField`, `ValueStepper`, `AppSegmentedControl`, `StatusRow`, `EmptyState`,
   `AvoToast`, `showAvoConfirm`, `showAvoMenu`, `GlassIconButton`, `AvoIcons`, `Mascot`. Tokens:
   `package:shoply/core/design/design.dart`. Prüfgerüst: `test/layout/layout_matrix.dart`.
5. **Schrittrahmen (fertig, auf main):** `lib/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart` mit
   `OnboardingStepPage(title:, message:, children:, primaryAction:, progress:, onBack:, onSkip:)` und
   `StepProgress(step:, total:, semanticLabel:)`. **Jeder Schritt und jeder Login-Screen nutzt ihn.** Die API darf nur
   ergänzt werden (Teil „Ablauf“), nichts umbenennen oder entfernen.

## Gemeinsame Schnittstellen (auf main, nicht ändern)

- `lib/presentation/screens/onboarding/onboarding_steps.dart`: `OnboardingStep` (IDs für `/onboarding?step=`),
  `AccountStepMode { signUp, login }`, `OnboardingArrival { created 'new', joined 'joined', existing 'existing' }` mit
  `OnboardingArrival.queryKey = 'arrival'`.
- Konto-Schritte (Platzhalter von der Hauptsitzung, Teil „Konto“ füllt sie, **Konstruktoren bleiben so**):
  - `auth/steps/account_step.dart`: `AccountStep({mode, required onEmail, required onSignedIn, onPassword, onBack, progress})`
  - `auth/steps/email_step.dart`: `EmailStep({mode, required ValueChanged<String> onCodeSent, onBack, progress})`
  - `auth/steps/code_step.dart`: `CodeStep({mode, required String email, required onVerified, onBack, progress})`
  - `auth/steps/name_step.dart`: `NameStep({required onDone, onSkip, progress})`
  - `auth/password_login_screen.dart`: `PasswordLoginScreen({required onSignedIn})`, `ResetPasswordRequestScreen()`
  - vorhanden: `auth/reset_password_screen.dart` `ResetPasswordScreen()` (Route `/reset-password`, §4.4)
  - `onSignedIn`/`onVerified` heißt nur „es gibt eine Session“. Ob das Konto neu oder schon eingerichtet ist,
    entscheidet der Ablauf.
- Ankunft (§3.12): Der Ablauf öffnet am Ende `/lists/<id>?arrival=new|joined|existing` (über `context.go`), Teil „Tipps“
  wertet den Parameter in der Liste aus.
- Module: `lib/core/modules/app_modules.dart` (`AppModule`, `onboardingDefault`, `released`, `moduleEnabledProvider`,
  `appModulesProvider.notifier.setEnabled`). Standard beim ersten Start (Owner 07.11.2026): Angebote an, Wochenplan an
  (aber `released: false`, also unsichtbar), Avo an, Kalorien aus, Kosten teilen aus.
- Slot von B nur über `import 'package:shoply/presentation/widgets/slots/b_slots.dart';`: `OffersSetupStep(onDone:)`
  (heute ein Platzhalter, der nichts zeichnet und sofort `onDone` ruft; der Ablauf muss das aushalten).

## Teil „Ablauf“

Dateien: `lib/presentation/screens/onboarding/**` (außer `widgets/onboarding_step_scaffold.dart` nur ergänzen),
`lib/routes/app_router.dart`, `lib/routes/areas/auth_routes.dart`, `lib/routes/route_paths.dart` (nur ergänzen),
`lib/data/services/onboarding_answers_service.dart`, `lib/presentation/state/auth_provider.dart` (nur §1.2/§9.11:
kein E-Mail-Präfix als Name, keine 5-Minuten-Regel), `lib/core/modules/module_descriptors.dart` (neu, §9.5),
`lib/presentation/screens/auth/welcome_screen.dart` (darf entfallen), Tests unter `test/screens/onboarding/` und
`test/routes/`. Texte: `lib/core/localization/translations/onboarding_flow.dart` (`onboardingFlowEn/De`, Präfix `onb_`).

- Konzept §1, §2, §3.1–3.4, §3.9–3.12 (Übergang), §5, §7, §9.5–9.7, §9.10.
- `onboarding_flow.dart`: `OnboardingFlow` mit `OnboardingController` (Riverpod-Notifier, sichert nach jedem Schritt in
  SharedPreferences, `onb_step`; Wiederaufnahme §5.5), eigener `Navigator` für die Schritte (Push mit Zurück-Wischen),
  Fortschritt „Schritt x von n“ über die tatsächlich gezeigten Schritte.
- Schritte: Willkommen (§3.2, Variante Anmelden für `/welcome`), Module (§3.3, Zeilen aus `moduleDescriptors`,
  `released: false` nie zeigen, KI-Zeile nach F-17-03/F-17-12 als offener Punkt), Region (B's `OffersSetupStep`, nur mit
  Modul Angebote), Konto/E-Mail/Code/Name (Widgets von „Konto“ einbetten), Ernährung und Allergien (§3.9 und §9.7,
  immer `Wrap`, 20 Werte aus `AllergyType`, Diät-IDs aus `kDietPreferenceIds`), Dein Ziel (§3.10, nur Modul Kalorien,
  **ohne Slider**: `ValueStepper`/Eingabefelder; Zielberechnung nur über die öffentliche API von
  `nutrition_goal_service`), Erste Liste (§3.11), Ende per Überblendung und `context.go('/lists/<id>?arrival=new')`.
- Neu oder eingerichtet (§1.2, §5.3), **ohne Server-Änderung**: eingerichtet, wenn `users.onboarding_completed == true`
  oder das Konto vor `kOnboardingRedesignCutoff` angelegt wurde (Konstante, Ersatz für den Backfill aus §9.6, mit
  Kommentar). Eingerichtet → lokale Antworten verwerfen, `/lists/<zuletzt>?arrival=existing` bzw. Tab Listen. Neu →
  Antworten von vor dem Konto per gezielten Updates schreiben (Module über `appModulesProvider`, Ernährung/Allergien
  nur ihre Spalten). `onboarding_completed = true` erst am Ende. Beschreib die RPC `apply_onboarding`, die Migration
  und den Backfill im Bericht als Vorschlag (SQL-Entwurf), nicht anwenden.
- Router: Redirects nach §1.3 (Neu, Bestand, Einladung `/invite/:id`/`/join/:code` merken als `pending_link`, Rezept-Link
  öffentlich, Reset), `/login` → Ablauf im Modus Anmelden (§4.1), `/login?method=password` → `PasswordLoginScreen`,
  `/login?method=reset` → `ResetPasswordRequestScreen`, `/signup` → Schritt E-Mail, `/name-prompt` → `NameStep`.
  Alte Routen auf `LoginScreen`/`SignUpScreen`/`NamePromptScreen`/`OnboardingScreen` entfernen; die alten Dateien
  löscht die Hauptsitzung am Ende (nicht du, außer `onboarding_screen.dart`, `onboarding_priorities_page.dart` und
  `welcome_screen.dart`, wenn nichts mehr darauf zeigt). Prioritäten-Frage entfällt (K-22).
- Tests: Router-Redirects (Neu, Bestand, Einladung, Rezept-Link, Reset) mit Fakes, Controller (Wiederaufnahme,
  Überspringen nimmt Standardwerte, Region nur mit Angeboten, Ziel nur mit Kalorien), `layoutMatrix` je Schritt.

## Teil „Konto“

Dateien: `lib/presentation/screens/auth/**` außer `welcome_screen.dart`, Tests unter `test/screens/auth/`. Texte:
`lib/core/localization/translations/auth_flow.dart` (`authFlowEn/De`, Präfix `auth_`).

- Konzept §3.5–3.8, §4.1–4.6, §9.3, §9.9, F-17-01, F-17-05.
- Die Platzhalter in `auth/steps/` und `auth/password_login_screen.dart` mit Inhalt füllen (Konstruktoren bleiben).
  Apple als Systemknopf (Paket `sign_in_with_apple`, falls vorhanden), Google mit Partnerfarben aus §9.9 (Daten, keine
  Tokens), E-Mail mit Code (6 Ziffern; Eingabe mit `AutofillHints.oneTimeCode`), Name ohne E-Mail-Präfix als Vorschlag,
  Passwort anmelden (4.2), Passwort vergessen (4.3), Neues Passwort (4.4) mit Regeln (`circle`/`checkmark.circle.fill`).
- Fehlertexte §4.6 verbindlich, ohne Rohfehler: `auth_errors.dart` neu (Code → Text).
- Anmelden geht über die vorhandenen Methoden von `SupabaseService` (B). Fehlt etwas (Apple mit Nonce und Name,
  OTP-Registrierung `shouldCreateUser`, Fehlercodes), Signatur in den Bericht; bis dahin mit dem Vorhandenen arbeiten.
- `login_screen.dart`, `signup_screen.dart`, `name_prompt_screen.dart`, `widgets/otp_verification_view.dart` **nicht
  löschen** (Routen zeigen noch darauf); im Bericht nennen, was entfallen kann.
- Tests: `layoutMatrix` je Screen, Code-Eingabe (Einfügen, Löschen, Fehler, erneut senden mit Wartezeit), Fehlertexte.

## Teil „Tipps“

Dateien: `lib/data/services/tip_service.dart` (neu), `lib/presentation/widgets/tips/**` (neu, `TipRow`),
`lib/data/services/dynamic_tutorial_service.dart` und `lib/presentation/widgets/tutorial/tutorial_overlay.dart`
(entfallen), die Tutorial-Stellen in `lib/app.dart`, `lib/presentation/screens/main_scaffold.dart`,
`lib/presentation/screens/home/home_screen.dart`, `lib/presentation/screens/lists/list_detail_screen.dart`,
`lib/presentation/screens/profile/profile_screen.dart`, `lib/presentation/screens/recipes/recipes_screen.dart`
(nur Tutorial raus und Tipp-Zeile rein, sonst nichts an diesen Screens ändern), `lib/routes/areas/lists_routes.dart`
(nur den Parameter `arrival` durchreichen), Tests unter `test/tips/`. Texte:
`lib/core/localization/translations/home_tips.dart` (`homeTipsEn/De`, Präfix `tip_`).

- Konzept §6.1 (T1–T9), §6.2, §3.12 (Ankunft), §9.8 (Startvorschläge im Accessory, falls die Vorschlagsliste in einer
  A-Datei liegt; sonst Bericht).
- `TipService`: lokaler Zähler je Tipp und Tag, höchstens eine Tipp-Zeile gleichzeitig und eine neue pro Tag, gezeigt
  heißt nie wieder (außer `reset()`), `markDone(id)` für Ereignisse (B ruft das später für T8/T9), Welche Zeile
  erscheint, steht beim ersten Frame fest (synchron aus SharedPreferences, wie `getCachedListsSync`).
- `TipRow`: `lightbulb` 16 pt `labelSecondary`, `callout` mit „Tipp:“ im Satz, Wischen nach links „Ausblenden“, nur T7
  mit Aktion. In Liste unter „Für heute“, in Rezepte als eigene Sektion ohne Titel unter dem Großtitel, auf Home als
  Hinweis-Zeile nach Ersparnis und Wochenplan (höchstens zwei Hinweis-Zeilen, K-38).
- Ankunft: `arrival=new` → Eingabefeld fokussiert, T1; `joined` → T5, keine Tastatur; `existing` → einmal Status
  „Angemeldet als <Name>. Deine Listen sind da.“, keine Tastatur.
- Mitteilungsabfrage beim ersten Start: prüfen, ob sie noch kommt (`main.dart`, `notification_service.dart`); gehört
  die Datei nicht A, Bericht.
- Tests: `TipService` (Regeln oben), `TipRow` mit `layoutMatrix`, Ankunft je Parameter.

## Qualität (alle)

- Jeder neue Screen/jedes neue Widget mit Test: `layoutMatrix` (Breiten 320–440, Schrift bis 3,1×, fett, dunkel,
  Kontrast) und Verhaltenstests. Supabase/Provider im Test über `ProviderScope(overrides:)` und Fakes.
- Zustände: leer, lädt (nie Vollbild-Spinner), Fehler mit „Erneut versuchen“, offline (Schritte vor dem Konto gehen
  offline), Modul aus.
- VoiceOver-Reihenfolge nach §2.4, 44-pt-Ziele, Reduce Motion, Dunkelmodus, DE/EN kurz und konkret, Plural über
  Parameter statt `\n`.
- Unter 60 s bis zur eigenen Liste auf dem Standardweg (§1.1): keine Feature-Seiten, keine Mitteilungsabfrage, keine
  Pro-Testphase, kein Profilbild im Ablauf.

## Bericht (deine letzte Antwort)

1. Geänderte/neue/gelöschte Dateien. 2. Was jetzt wie aussieht und funktioniert (kurz). 3. Letzte Zeile von
`flutter test` und `dart analyze`. 4. Abweichungen von D2/Konzept mit Grund; nötige Änderungen an fremden Dateien
(genau, mit Signatur); Server-Vorschläge; offene Punkte.
