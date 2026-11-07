# Inventar: Onboarding, Login und Start (Ist-Zustand, Stand 2026-11-07)

Grundlage für das Redesign (Konzept 17, Teil A). Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf `main` (3e886d0).

Kurzfassung: Der erste Start läuft heute so: nativer Launch-Screen (leer, Systemhintergrund) → `/onboarding` (6 bis 7 Paper-Seiten im `PageView`: drei Feature-Seiten, „Was bringt dich zu uns?“, Ernährung, Kalorien ja/nein, optional Körperdaten) → `/welcome` (Apple, Google, Konto erstellen, Anmelden) → `/signup` oder `/login` (E-Mail mit 6-stelligem Code) → `/name-prompt?new=1` (nur neue Konten) → `/home`, wo ein app-weites Coach-Mark-Tutorial (`TutorialOverlay`) startet. Die Antworten aus dem Onboarding werden lokal zwischengespeichert und beim ersten angemeldeten Laden des Profils ins Konto geschrieben. Ein Modul-Schritt existiert noch nicht; das einzige „Modul“ ist der Kalorien-Schalter. Gestaltung: durchgehend Paper (Creme, Terrakotta, Georgia-Serife, Großbuchstaben-Kicker), nur hell, mit Ausreißern (Passwort-Reset fest dunkel im Material-Stil, Namensabfrage halb adaptiv).

Hinweis zu den genannten Diensten: `tutorial_service.dart`, `interactive_tutorial_service.dart` und `native_oauth_service.dart` existieren nicht (mehr) in `lib/`. Das Tutorial läuft ausschließlich über `dynamic_tutorial_service.dart` + `tutorial_overlay.dart`; Apple- und Google-Login stecken in `supabase_service.dart`. Einen Ordner `screens/splash/` gibt es nicht; der „Splash“ ist der native `LaunchScreen.storyboard`.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/onboarding/onboarding_screen.dart` | `/onboarding`: `PageView` mit allen Seiten, Fortschrittspunkte, Weiter/Los-geht's, Überspringen; Flag `onboarding_complete_v1` (`hasCompletedOnboarding`, `markOnboardingComplete`); drei Illustrationen; Kalorien-Opt-in-Seite | 609 |
| `lib/presentation/screens/onboarding/widgets/onboarding_priorities_page.dart` | Seite „Was bringt dich zu uns?“ (Mehrfachauswahl, 5 Zeilen) | 128 |
| `lib/presentation/screens/onboarding/widgets/onboarding_diet_page.dart` | Seite „Isst du besonders?“ (12 Diät-Chips) | 103 |
| `lib/presentation/screens/onboarding/widgets/onboarding_goal_page.dart` | Körperdaten und Ziel (nur bei Kalorien = ja), meldet `OnboardingGoalDraft` nach oben | 345 |
| `lib/presentation/screens/auth/welcome_screen.dart` | `/welcome`: Einstieg mit Apple, Google, Konto erstellen, Anmelden | 152 |
| `lib/presentation/screens/auth/login_screen.dart` | `/login`: E-Mail + Passwort, Passwort vergessen (Code per Mail), Google | 394 |
| `lib/presentation/screens/auth/signup_screen.dart` | `/signup`: E-Mail, Passwort, Bestätigung, danach 6-stelliger Code; Google | 349 |
| `lib/presentation/screens/auth/reset_password_screen.dart` | `/reset-password`: neues Passwort setzen (fest dunkles Material-Layout) | 281 |
| `lib/presentation/screens/auth/name_prompt_screen.dart` | `/name-prompt?new=1`: Anzeigename mit Avo-Maskottchen | 203 |
| `lib/presentation/screens/auth/social_auth.dart` | Gemeinsamer Apple/Google-Ablauf, `routeAfterSignIn` (neu < 3 min → Namensabfrage) | 45 |
| `lib/presentation/screens/auth/auth_errors.dart` | Fehlertexte per Teilstring-Abgleich (Rate-Limit, Netz, Social, OTP) | 51 |
| `lib/presentation/screens/auth/widgets/otp_verification_view.dart` | „Schau in dein Postfach“: Codefeld, Bestätigen, Erneut senden (für Signup und Reset) | 100 |
| `lib/presentation/screens/auth/widgets/google_logo.dart` | Google-„G“ per `Image.network` von google.com, Fallback-Icon | 22 |
| `lib/routes/app_router.dart` | `initialLocation`, `GoRouterRefreshStream`, gesamte Redirect-Logik (Z. 368-457), Pending-Link für geteilte Listen | 466 |
| `lib/data/services/onboarding_answers_service.dart` | `OnboardingGoalDraft`; lokale Zwischenspeicherung der Antworten; `applyPendingAnswersToAccount` (einmalig ins Konto) | 208 |
| `lib/data/services/dynamic_tutorial_service.dart` | Coach-Mark-Tutorial: 8 Schritte, GlobalKeys der Ziele, `users.tutorial_completed` | 334 |
| `lib/presentation/widgets/tutorial/tutorial_overlay.dart` | Overlay über der ganzen App: Abdunklung mit Loch, Pulsring, Tap-Blocker, Avo-Karten, Fortschrittspunkte, Überspringen | 724 |
| `lib/data/services/user_service.dart` | Nur `updateUserProfile` (schreibt das ganze `UserModel` als Update); genutzt von Avo und `goal_setup_screen` | 19 |
| `lib/data/services/supabase_service.dart` | Auth-Methoden: E-Mail, Apple (Z. 58-119), Google (Z. 122-187), Reset per OTP (Z. 195-227), `updateUser` | 266 |
| `lib/presentation/state/auth_provider.dart` | `authUserProvider`, `authUserIdProvider` (leert Offline-Cache bei Kontowechsel), `currentUserProvider` (legt `users`-Zeile an, ruft Onboarding-Sync) | 119 |
| `lib/presentation/state/calorie_tracking_provider.dart` | `calorieTrackingEnabledProvider` (lokal + `nutrition_goals`), Vorbild fürs Modulsystem | 57 |
| `lib/core/constants/app_priorities.dart` | 5 Prioritäten mit Material-Icons | ca. 25 |
| `lib/core/constants/diet_preferences.dart` | 12 Diät-IDs (geteilt mit Einstellungen) | ca. 20 |
| `lib/core/constants/paper_colors.dart` | `PaperColors` (fest hell), `PaperTextStyles.serif/kicker/body` | 66 |
| `lib/core/widgets/paper/paper_widgets.dart` | `PaperKicker`, `PaperPrimaryButton`, `PaperOutlineButton`, `PaperUnderlineField`, `PaperOrDivider` | 226 |
| `lib/core/mascot/avo_mascot.dart` | Avo-PNG mit Ausdrücken (Namensabfrage, Tutorial) | 129 |
| `lib/main.dart` | Start: Supabase vor `runApp`, Rest im Hintergrund, Auth-Seiteneffekte (FCM, Widget, Erinnerungen) | 175 |
| `lib/app.dart` | `AdaptiveApp.router`; `builder` legt `ScaffoldMessenger` + `TutorialOverlay` um jede Route (Z. 228) | 233 |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` + `Assets.xcassets/LaunchImage.imageset` | Nativer Launch-Screen: `systemBackgroundColor`, LaunchImage ist 1x1 px transparent (also leer) | – |
| `lib/core/localization/app_translations.dart` | Texte `onb_*`, `welcome_*`, `otp_*`, `name_prompt_*`, `reset_password_*` (EN ab ca. Z. 240, DE ca. Z. 1404-1500, 1707-1753) | – |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Nativer Launch-Screen
- **Datei/Einstieg:** `LaunchScreen.storyboard`, vor dem ersten Flutter-Frame.
- **Hauptfrage:** keine (soll nur überbrücken).
- **Aufbau:** leere Fläche in `systemBackgroundColor`; das Bild ist 1x1 px transparent.
- **Übergang:** Danach erscheint je nach Session `/home` oder `/onboarding` (cremefarben `#F7F3EC`). Im Dunkelmodus springt es von Schwarz auf Creme.
- **Vor dem ersten Frame:** Bildschirmausrichtung und `SupabaseService.initialize()` werden abgewartet (`main.dart:32-37`), alles andere startet danach.

### 2.2 Onboarding (`OnboardingScreen`)
- **Route:** `/onboarding` (Startroute ohne Session, `app_router.dart:107`).
- **Hauptfrage:** „Was kann die App, und was soll sie für mich tun?“
- **Aufbau oben → unten:** „Überspringen“ (TextButton rechts oben) → `PageView` (wischbar) → Fortschrittspunkte (aktiver Punkt 18 pt breit) → schwarze Pillen-Schaltfläche „Weiter“ bzw. „Los geht's“ auf der letzten Seite.
- **Seiten:**
  1. Feature „Clevere Listen“: Illustration (Salbei-Block mit Mini-Liste „OBST & GEMÜSE“, Tomaten abgehakt, Avocados, „MILCHPRODUKTE“, Milch, Joghurt), Kicker, Serifentitel „Artikel sortieren sich selbst.“, Untertitel „Füge einfach hinzu, die KI ordnet alles automatisch …“.
  2. Feature „Gemeinsam“: Creme-Block mit drei Initialen-Avataren (J, M, L) und Pille „Marie hat ‚Milch‘ abgehakt“; Titel „Listen, die ihr teilt.“
  3. Feature „Rezepte & Avo“: Rosé-Block mit Rezeptkarte „Ofengemüse, 35 Min · vegetarisch, Sahne → Hafercreme“; Titel „Rezepte passen sich dir an.“
  4. `OnboardingPrioritiesPage`: Kicker „Über dich“, Titel „Was bringt dich zu uns?“, fünf Zeilen mit Icon (Geld sparen, Listen mit anderen teilen, Gesünder essen, Rezepte entdecken, Organisiert bleiben), Mehrfachauswahl (ausgewählt = schwarz gefüllt), Hinweis „Nichts ausgewählt? Dann zeigen wir dir einfach alles …“.
  5. `OnboardingDietPage`: „Isst du besonders?“, 12 Chips im `Wrap` (Vegetarisch, Vegan, Glutenfrei, Laktosefrei, Pescetarisch, Keto, Paleo, Low-Carb, Halal, Koscher, Nussfrei, Natriumarm), Hinweis „Nichts ausgewählt? Dann isst du einfach alles.“
  6. `_CalorieOptInPage`: Creme-Block mit Flammen-Icon, Kicker „Optional“, „Auch Kalorien tracken?“, zwei Auswahlkarten „Nur Einkaufen & Rezepte“ (Standard) / „Mit Kalorien-Tracking“.
  7. Nur bei „Mit Kalorien-Tracking“: `OnboardingGoalPage` mit Ziel-Chips (`goal_type_*`), Geschlecht (weiblich/männlich/divers), Alter, Größe cm, aktuelles Gewicht, Zielgewicht (nur bei Abnehmen/Muskelaufbau), Aktivitätslevel (Zeilen mit Untertitel), Zeitrahmen-Slider 4-52 Wochen (nur mit Zielgewicht), Hinweis „Noch unsicher? Überspringen …“.
- **Komponenten:** `PaperKicker`, `PaperTextStyles.serif(28)`, `PaperPrimaryButton`, `PaperUnderlineField`, eigene Chips/Zeilen mit `AnimatedContainer`, Material-Icons.
- **Zustände:** kein Laden (alles lokal), kein Fehlerzustand, offline voll nutzbar; leer = nichts gewählt ist gültig; Pro/Modul: Kalorien ist das einzige Modul, sonst keine Modulwahl.
- **Aktionen/Gesten:** horizontal wischen; Weiter (400 ms `easeInOutCubic`); Überspringen beendet sofort und speichert den aktuellen Stand (auch leere Auswahl); Tippen auf Zeilen/Chips toggelt.
- **Datenquellen:** `calorieTrackingEnabledProvider.setEnabled` (lokal, ohne Konto kein Server), `OnboardingAnswersService.savePendingAnswers`, `markOnboardingComplete` (SharedPreferences), dann `context.go('/welcome')` (`onboarding_screen.dart:58-77`).

### 2.3 Welcome (`WelcomeScreen`)
- **Route:** `/welcome` (nach Onboarding, nach Abmelden, nach Passwort-Reset; jede private Route ohne Login landet hier).
- **Hauptfrage:** „Wie melde ich mich an?“
- **Aufbau:** Salbei-Block 190 pt mit weißem Kreis und Blatt-Icon (`Icons.eco_outlined`, nicht Avo) → Kicker „Willkommen bei Shoply“ → Serife „Einkaufen, schön sortiert.“ → Untertitel → unten fest: „Mit Apple fortfahren“ (nur iOS, Outline mit `Icons.apple`) → „Mit Google fortfahren“ (Outline, Google-Favicon aus dem Netz) → „Konto erstellen“ (schwarze Pille) → „Schon ein Konto? Anmelden“ (Terrakotta-Link).
- **Zustände:** kein Ladezustand für Apple/Google (kein Spinner, Doppeltipp möglich); Fehler als Material-`AlertDialog` „Hinweis“; Abbruch zeigt nichts; offline: Fehlertext „network_error“, Google-Logo fällt auf Material-Icon zurück.
- **Aktionen:** Apple/Google → `signInWithSocialProvider`; Konto erstellen → `push('/signup')`; Anmelden → `push('/login')`.

### 2.4 Login (`LoginScreen`)
- **Route:** `/login`.
- **Hauptfrage:** „Wie komme ich wieder in mein Konto?“
- **Aufbau:** Zurück-Pfeil (Material, `context.go('/welcome')`) → Kicker „ANMELDEN“ → Serife „Willkommen zurück.“ → E-Mail (Unterstrich-Feld, Hint `name@example.com`) → Passwort mit Augen-Icon → „Passwort vergessen?“ (Terrakotta, rechts) → „Anmelden“ (Pille) → „oder“-Trenner → „Mit Google fortfahren“ → „Noch kein Konto? Registrieren“.
- **Kein Apple-Button** auf diesem Screen.
- **Unterzustand OTP (Passwort vergessen):** `OtpVerificationView` mit Kicker „PASSWORT ZURÜCKSETZEN“, „Schau in dein Postfach.“, „Code gesendet an …“, Spam-Hinweis, Codefeld (24 pt, Laufweite 8), „Bestätigen“, „Nicht erhalten? Erneut senden“, Zurück-Pfeil.
- **Zustände:** Button-Spinner (`CupertinoActivityIndicator`); Fehler als rote Material-SnackBar über eigenem `ScaffoldMessenger`, teils mit Aktion („Registrieren“, „Erneut senden“); „Passwort vergessen“ ohne E-Mail → gelbe SnackBar „Bitte zuerst E-Mail eingeben“; offline → „network_error“.
- **Datenquellen:** `SupabaseService.signInWithEmail`, `resetPassword` (= `signInWithOtp(shouldCreateUser: false)`), `verifyPasswordResetOtp` (`OtpType.email`, meldet an), `auth.resend(OtpType.signup)`.

### 2.5 Registrieren (`SignUpScreen`)
- **Route:** `/signup` (übernimmt optional `extra['email']`).
- **Hauptfrage:** „Wie lege ich ein Konto an?“
- **Aufbau:** Zurück → Kicker „KONTO ERSTELLEN“ → „Schön, dass du da bist.“ → E-Mail → Passwort (Regeln: min. 8 Zeichen, ein Großbuchstabe, eine Ziffer, `validators.dart:25-37`) → Passwort bestätigen → „Konto erstellen“ → „oder“ → Google → „Schon ein Konto? Anmelden“. Kein Apple-Button.
- **Unterzustand OTP:** wie Login, Kicker „E-MAIL BESTÄTIGEN“, `verifyOTP(OtpType.signup)`, danach `go('/name-prompt?new=1')`.
- **Zustände:** 30-s-Timeout beim Registrieren; Fehler: Konto existiert (mit Aktion „Anmelden“), schwaches Passwort, ungültige E-Mail, Netz, Rate-Limit.

### 2.6 Passwort zurücksetzen (`ResetPasswordScreen`)
- **Route:** `/reset-password` (nach gültigem Reset-Code; Nutzer ist dann bereits angemeldet).
- **Hauptfrage:** „Welches neue Passwort will ich?“
- **Aufbau:** Material-`AppBar` mit X und Titel, fest dunkel `#121212` → großes `lock_reset`-Icon 64 pt → „Neues Passwort erstellen“ → Hinweis → zwei gefüllte Outline-Felder (Radius 16) → graue Schaltfläche 56 pt „Passwort zurücksetzen“.
- **Aktionen:** Speichern → `updateUser(password)` → Abmelden → SnackBar „Passwort aktualisiert, bitte anmelden“ (grün) → `/welcome`. X → abmelden → `/welcome`.
- **Zustände:** Spinner im Button; Fehler-SnackBar; kein Paper, kein Hellmodus.

### 2.7 Namensabfrage (`NamePromptScreen`)
- **Route:** `/name-prompt?new=1` (ohne `new=1` leitet der Router weg, `app_router.dart:435-437`).
- **Hauptfrage:** „Wie sollen andere mich in geteilten Listen sehen?“
- **Aufbau:** Spacer → Avo winkend (120 pt, animiert) → Sprechblase „Hey! Ich bin Avo 🥑 Wie darf ich dich nennen?“ → zentriertes gefülltes Textfeld 20 pt „Dein Name“ → grüne Akzent-Schaltfläche „Weiter“ (`AppColors.accent`) → „Überspringen“ → Spacer. Hell = Paper-Creme, dunkel = `#1C1C1E` (einziger Auth-Screen mit Dunkelmodus).
- **Aktionen:** Weiter → `users`-Upsert (`display_name`, `email`, `auth_provider`), `invalidate(currentUserProvider)`, `/home`. Überspringen → `/home` (Name bleibt E-Mail-Präfix bzw. Provider-Name).
- **Zustände:** Spinner im Button; Fehler-SnackBar „generic_error“; kein Vorbefüllen mit dem Namen von Apple/Google.

### 2.8 Coach-Mark-Tutorial (`TutorialOverlay` + `DynamicTutorialService`)
- **Einstieg:** global in `app.dart:228` um jede Route; startet bei jeder Anmeldung, wenn `users.tutorial_completed` nicht `true` ist; neu startbar in Profil (`profile_screen.dart:237`).
- **Hauptfrage:** „Wie benutze ich Listen und Rezepte?“
- **Schritte** (`dynamic_tutorial_service.dart:134-221`, Texte fest Deutsch): Willkommen (Vollbild, Avo, „Los geht's“) → Liste öffnen (Klick-Schritt auf `firstListCardKey`; legt bei Bedarf „Meine erste Liste“ an, `home_screen.dart:110-150`) → Artikel-Bereich → Eingabefeld → Rezepte-Tab tippen (Klick auf Tab-Bar) → Rezepte-Bereich → Rezept erstellen → Fertig (Vollbild, „Loslegen“, Zweitknopf „Ernährungspräferenzen angeben“ → `/diet-preferences`).
- **Komponenten:** Abdunklung 65-85 % mit ausgestanztem Loch, pulsierender weißer Ring, Tap-Blocker außerhalb des Ziels, dunkle Karte `rgba(28,28,30,0.92)` mit Avo 64 pt, Pille „Überspringen“ (12 pt), Fortschrittspunkte.
- **Zustände:** Ziel nicht gefunden → Karte bei 35 % Höhe ohne Loch; Datenzustände `hasLists`, `listHasItems`, `hasRecipes` ändern die Texte.
- **Gesten:** nur Tippen; Wischen/Scrollen außerhalb des Lochs ist blockiert.

### 2.9 Dialoge und Meldungen im Bereich
- Welcome: `AlertDialog` „Hinweis“ für Social-Fehler (`welcome_screen.dart:23-37`).
- Login/Signup/OTP/Reset/Name: Material-`SnackBar` (rot `AppColors.error`, grün `AppColors.success`/`Colors.green`, gelb `AppColors.warning`), teils mit Aktion.
- System: iOS-Mitteilungsabfrage erscheint beim allerersten Start ohne Kontext über dem Onboarding (`main.dart:115`, `notification_service.dart:52-54`).

### 2.10 Ablauf und Redirect-Logik (`app_router.dart:368-457`)
1. `shoply://`-Links werden in Pfade umgebaut (`recipe`, `list`, `invite`, `author`), alles andere → `/home`.
2. Öffentlich: `/onboarding`, `/welcome`, `/login`, `/signup`, `/reset-password`, `/recipe/:id`.
3. Geteilte Liste ohne Login: Ziel wird in `_pendingListLink` (nur Speicher) gemerkt und nach dem ersten Erreichen von `/home` angesprungen.
4. Onboarding-Flag einmal aus SharedPreferences gelesen und gemerkt.
5. Nicht angemeldet und Onboarding offen → `/onboarding` (außer Rezept-Link, Login, Signup, Reset).
6. Onboarding erledigt und auf `/onboarding` → `/welcome`; private Route ohne Login → `/welcome`.
7. Angemeldet auf `/welcome` oder `/onboarding` → `/home`; Login/Signup leiten selbst weiter (bewusst, wegen OTP-Rennen).
8. Refresh nur bei `initialSession`, `signedIn`, `signedOut`, `passwordRecovery`.

### 2.11 Welche Daten erfasst und wo gespeichert werden

| Daten | Erfasst in | Zwischenspeicher (ohne Konto) | Ziel im Konto | Später änderbar in |
|---|---|---|---|---|
| Onboarding erledigt | Onboarding-Ende/Überspringen | SharedPreferences `onboarding_complete_v1` | `users.onboarding_completed = true` (nur beim Sync) | nicht (Flag wird nie zurückgesetzt) |
| Prioritäten | Seite 4 | `onb_pending_app_priorities` | `users.app_priorities` (JSONB) | Profil → „Was dir wichtig ist“ |
| Ernährung | Seite 5 | `onb_pending_diet_preferences` | `users.diet_preferences` | `/diet-preferences` |
| Kalorien an/aus | Seite 6 | `calorie_tracking_enabled` + `onb_pending_calories_opt_in` | `nutrition_goals.calorie_tracking_enabled` | Profil-Einstellungen, Kalorien-Tab |
| Ziel, Aktivität, Geschlecht, Alter, Größe, Gewicht, Zielgewicht, Zeitrahmen | Seite 7 | `onb_pending_goal_draft` (JSON) | `nutrition_goals` (Ziele + berechnete kcal/Makros via `NutritionGoalCalculator`), `weight_logs` (erster Eintrag), `users.age/height/height_unit/gender` | `goal_setup_screen` |
| Anzeigename | Namensabfrage | – | `users.display_name` (Upsert) | Profil |
| Tutorial erledigt | Tutorial | – | `users.tutorial_completed` | Profil → Tutorial neu starten |
| Sync erledigt | – | `onb_answers_synced_v1` | – | – |

Sync-Regel (`onboarding_answers_service.dart:113-207`, aufgerufen in `auth_provider.dart:58-63`): läuft einmal pro Gerät; nur wenn die `users`-Zeile höchstens 5 Minuten alt ist, sonst werden die lokalen Antworten verworfen (schützt bestehende Konten vor Überschreiben).

---

## 3. Design-Probleme heute

### 3.1 Paper-Reste (Anti-Slop)
- Großbuchstaben-Kicker über jeder Überschrift: `PaperKicker` macht `toUpperCase()` mit Laufweite 2 (`paper_widgets.dart:14`, `paper_colors.dart:50-57`); genutzt in `onboarding_screen.dart:236, 283`, `onboarding_priorities_page.dart:31`, `onboarding_diet_page.dart:29`, `onboarding_goal_page.dart:106`, `welcome_screen.dart:79`, `login_screen.dart:294`, `signup_screen.dart:240`, `otp_verification_view.dart:41`. In der Illustration zusätzlich `_MiniKicker` 9 pt (`onboarding_screen.dart:514-534`), Texte selbst in Großbuchstaben übersetzt („OBST & GEMÜSE“).
- Serife Georgia für alle Titel: `PaperTextStyles.serif(28/27/16)` (`paper_colors.dart:31-48`; z. B. `onboarding_screen.dart:238, 480`, `login_screen.dart:298`).
- Creme/Terrakotta/Salbei/Rosé-Palette, fest hell und nicht adaptiv (`paper_colors.dart:3-26`, Kommentar „intentionally light“). Terrakotta als Akzent für Links, Slider, Häkchen (`onboarding_goal_page.dart:212-213`, `welcome_screen.dart:136`).
- Getönte Farbblöcke als Illustrationen statt echter Inhalte (`onboarding_screen.dart:361-512`), Blatt-Icon im Kreis auf Salbei als Hero (`welcome_screen.dart:55-77`).
- Blasse Fließtexte: Untertitel in `PaperColors.muted` (#8A8274), Hinweise in `faint` (#B5AB97, Kontrast auf #F7F3EC ca. 2:1) (`onboarding_priorities_page.dart:65`, `onboarding_diet_page.dart:61`, `onboarding_goal_page.dart:232`, `otp_verification_view.dart:52`).
- Harte Hairline-Rahmen um jede Auswahlzeile statt Tonstufen (`onboarding_priorities_page.dart:98-100`, `onboarding_goal_page.dart:310-314`, `onboarding_screen.dart:333-336`).

### 3.2 Abweichungen von Apple-Regeln
- **Kein Dunkelmodus:** Onboarding, Welcome, Login, Signup, OTP sind immer creme; Reset ist immer dunkel (`reset_password_screen.dart:97-99`); Namensabfrage hat eigene Hartfarben (`name_prompt_screen.dart:77, 101-103, 136-138`). Drei verschiedene Gestaltungen in einem Ablauf.
- **Statusleiste unsichtbar:** `app.dart:212-219` setzt die Statusleiste nach Systemmodus. Im Dunkelmodus stehen helle Symbole auf der cremefarbenen Paper-Fläche; im Hellmodus dunkle Symbole auf dem dunklen Reset-Screen. Keiner der Auth-Screens setzt eine eigene `AnnotatedRegion`.
- **Material statt iOS:** `AppBar`, `ElevatedButton`, `OutlinedButton`, `TextButton`, `AlertDialog`, `SnackBar`, `Slider`, Material-Icons (`Icons.arrow_back` statt Chevron, `Icons.apple`, `Icons.eco_outlined`, `Icons.local_fire_department_outlined`). Keine SF Symbols, keine Cupertino-Navigation, keine Sheets.
- **Sign in with Apple nicht nach HIG:** selbstgebauter Outline-Button mit Material-Apple-Icon statt systemkonformem Button (`welcome_screen.dart:99-108`); auf Login und Signup fehlt Apple ganz, Google ist dort vorhanden (`login_screen.dart:359-364`, `signup_screen.dart:314-319`).
- **Zurück-Navigation:** Login/Signup springen mit `context.go('/welcome')` statt `pop` (`login_screen.dart:291`, `signup_screen.dart:237`); „Registrieren“/„Anmelden“-Links ersetzen den Stack (`login_screen.dart:368`, `signup_screen.dart:323`). OTP-Schritt ist ein Zustandswechsel im selben Screen, kein Push; die Wischgeste „zurück“ verlässt dann den ganzen Screen statt den OTP-Schritt.
- **Touch-Ziele unter 44 pt:** „Passwort vergessen?“ als 13-pt-Text mit `GestureDetector` (`login_screen.dart:338-348`); Augen-Icon 19 pt mit `suffixIconConstraints` 32x24 (`paper_widgets.dart:183`, `login_screen.dart:324-333`); „Registrieren“/„Anmelden“-Links (`login_screen.dart:366-388`, `signup_screen.dart:321-343`); „Erneut senden“ (`otp_verification_view.dart:76-95`); Tutorial-„Überspringen“ 12 pt mit 7 pt Innenabstand (`tutorial_overlay.dart:304-323`); Fortschrittspunkte 5 pt.
- **Bewegung:** feste Dauern und Kurven statt Federn (`onboarding_screen.dart:120-121, 182-183`, alle `AnimatedContainer` 180-250 ms); Reduce Motion wird nirgends beachtet (Avo-Animation, Pulsring 1,5 s Endlosschleife `tutorial_overlay.dart:40-43, 86`).
- **Keine Haptik** beim Auswählen, bei Erfolg (Konto erstellt, Code bestätigt) oder Fehler.
- **VoiceOver:** Auswahlzeilen und Chips sind `GestureDetector` ohne `Semantics` (kein „ausgewählt“, keine Rolle Button) (`onboarding_priorities_page.dart:88`, `onboarding_diet_page.dart:78`, `onboarding_goal_page.dart:262, 302`, `onboarding_screen.dart:323`); Fortschrittspunkte ohne Beschriftung; Tutorial-Overlay ohne Fokussteuerung.
- **Erlaubnisse ohne Kontext:** Mitteilungsabfrage beim ersten Start vor dem Onboarding (`main.dart:110-119`, `notification_service.dart:52-54`). Widerspricht Liste Punkt 5 („Mitteilungen nur mit klarem Nutzen erfragen“).
- **Wayfinding:** Onboarding hat keinen Weg „Ich habe schon ein Konto“; wer die App neu installiert, muss 6 Seiten durchlaufen oder „Überspringen“ finden. Fortschritt ändert seine Länge (6 → 7 Punkte), sobald Kalorien gewählt werden.
- **Name „Shoply“** in sichtbaren Texten („Willkommen bei Shoply“, „Shoply hebt … hervor“), obwohl die App auf dem Home-Bildschirm „Avo“ heißt; Hero zeigt ein Blatt statt Avo.
- **Fester Bildschirm statt Inhalt:** Tutorial-Texte und -Knöpfe fest Deutsch (`dynamic_tutorial_service.dart:141-218`, `tutorial_overlay.dart:317, 354, 360, 614`), ignorieren die Spracheinstellung. Emoji im Text „Ich bin Avo 🥑“.

### 3.3 Feste Höhen, Breiten und Schriftgrößen (brechen bei großer Schrift oder 320 pt)
Die App begrenzt die Textskalierung nirgends (kein `textScaler` in `app.dart`), daher wachsen Schriften, feste Container aber nicht.
- `PaperPrimaryButton` fest 54 pt hoch, Label ohne Umbruch/Ellipse (`paper_widgets.dart:33-56`): bei Bedienungshilfen-Größen wird „Konto erstellen“ oben und unten abgeschnitten.
- `PaperOutlineButton` fest 50 pt, Label mit Ellipse (`paper_widgets.dart:83-112`): „Mit Google fortfahren“ wird schon bei großer Schrift auf 320 pt gekürzt.
- Reset-Button fest 56 pt (`reset_password_screen.dart:248-250`).
- Illustrationen fest 250 pt hoch (`onboarding_screen.dart:268, 367, 407, 456`), Rezeptkarte 210 pt breit (`:462`), Avatar-Stack 108x52 (`:417-419`): auf iPhone SE mit Zoom (320x568) bleibt unter dem Bild kaum Platz für Titel und Text, alles muss scrollen, während Punkte und Button (ca. 100 pt) fest unten stehen.
- Welcome: unterer Block mit vier Schaltflächen fest (ca. 230 pt) außerhalb des Scrollbereichs (`welcome_screen.dart:98-146`); Hero fest 190 pt (`:56`). Bei 320x568 und großer Schrift bleibt für Headline und Text sehr wenig Höhe.
- Namensabfrage: `Column` mit `Spacer`, nicht scrollbar (`name_prompt_screen.dart:81-197`). Avo 120 + Blase + Feld + Button + Überspringen ≈ 420 pt; auf dem iPhone SE mit offener Tastatur bleiben ca. 380 pt → Überlauf bereits bei Standardschrift (Annahme aus Rechnung, auf Gerät zu prüfen).
- Feste Zeilenumbrüche `\n` in Überschriften („Einkaufen,\nschön sortiert.“, „Willkommen\nzurück.“, „Was bringt\ndich zu uns?“, `app_translations.dart:1408, 1420, 1434` usw.): bei großer Schrift oder 320 pt entstehen zusätzliche hässliche Umbrüche.
- Goal-Seite: zwei Felder nebeneinander mit 20 pt Abstand (`onboarding_goal_page.dart:147-187`): Labels wie „Aktuelles Gewicht (kg)“ und „Zielgewicht (kg)“ werden bei 320 pt und großer Schrift gequetscht.
- Tutorial: Kartenposition mit festen Annahmen (Karte 180-200 pt hoch, `tutorial_overlay.dart:396-411`), Punkte bei `safeBottom + 70` (`:632`): bei großer Schrift überlappen Karte, Ziel und Punkte.
- Kleinstschriften: 9 pt (`onboarding_screen.dart:526`), 11 pt (`:484`, `tutorial_overlay.dart:616`), 12 pt Labels über Feldern (`paper_widgets.dart:159`).

---

## 4. Bugs, Risiken und Performance

1. **Tutorial über der Namensabfrage (plausibel, auf Gerät prüfen).** `TutorialOverlay` hängt global um jede Route (`app.dart:228`) und startet bei jedem `signedIn` (`tutorial_overlay.dart:58-71`). Neue Konten haben `tutorial_completed` nicht gesetzt, also legt sich das Vollbild-Willkommen direkt nach dem Bestätigen des Codes über `/name-prompt`. Der nächste Schritt zielt auf `firstListCardKey`, der dort nicht existiert.
2. **Ziel-Seite verliert Eingaben, Draft bleibt.** `PageView` hält keine Seiten am Leben; wischt man von Seite 7 zurück und wieder vor, sind Alter/Größe/Gewicht leer, der Elternzustand `_goalDraft` enthält aber noch die alten Werte und wird gespeichert (`onboarding_screen.dart:50, 110-113`, `onboarding_goal_page.dart:26-57`).
3. **Keine Plausibilitätsprüfung der Körperdaten:** „1,80“ als Größe wird 1,8 cm, Alter 0 wird abgefangen, 300 kg nicht (`onboarding_goal_page.dart:63-80`). Der Rechner klemmt nur auf 1200/1500 kcal (`nutrition_goal_service.dart:45-50`). „Divers“ wird wie männlich gerechnet (`:45`).
4. **Sync nicht atomar:** `applyPendingAnswersToAccount` schreibt nacheinander `users`, `nutrition_goals`, `weight_logs`, `users`. Scheitert ein späterer Schritt, bleibt `_syncedKey` false und der nächste Versuch legt einen zweiten Gewichtseintrag an (`onboarding_answers_service.dart:139-205`). Das erste `users`-Update läuft ins Leere, falls die Zeile fehlt; der Fall ist durch `_createUserRow` in `auth_provider.dart:52` abgedeckt, hängt aber an der Reihenfolge.
5. **5-Minuten-Regel und Uhrzeit:** `_createUserRow` schreibt `created_at` als lokale Zeit ohne Zeitzone (`auth_provider.dart:94-103`), verglichen wird mit `DateTime.now()` (`onboarding_answers_service.dart:120-121`). Funktioniert heute nur, weil der Fehler die Differenz negativ macht. `routeAfterSignIn` nutzt dieselbe Art Heuristik (< 3 min, `social_auth.dart:39-45`); bei falsch gehender Geräteuhr bekommen neue Konten keine Namensabfrage.
6. **Bestehendes Konto auf neuem Gerät:** muss das Onboarding durchlaufen, die Antworten werden danach stillschweigend verworfen. Das Server-Feld `users.onboarding_completed` wird für das Routing nie gelesen; `OfflineCacheService.getCachedUserProfile` wird nirgends aufgerufen (toter Code, Kommentar in `auth_provider.dart:43-45` veraltet).
7. **Doppelte Social-Anmeldung:** Welcome hat keinen Ladezustand, zwei Tipps starten zwei Apple/Google-Abläufe (`welcome_screen.dart:15-21, 107, 114`).
8. **Kurz sichtbares `/home` nach Social-Login:** `signedIn` lässt den Router `/welcome` → `/home` umleiten, danach ruft `routeAfterSignIn` `/name-prompt?new=1`. Home baut kurz auf und legt dabei ggf. „Meine erste Liste“ an (`home_screen.dart:110-150`).
9. **Passwort-Reset ist ein Code-Login:** `verifyPasswordResetOtp` meldet mit `OtpType.email` an (`supabase_service.dart:212-227`). Wird die App auf `/reset-password` beendet, startet sie danach angemeldet in `/home`, ohne dass ein neues Passwort gesetzt wurde. Kein Sicherheitsleck (E-Mail-Besitz ist bewiesen), aber verwirrend.
10. **Fehlertexte über Teilstrings:** `supabase_service.dart` wirft deutsche Freitexte („nicht verfügbar“, „nicht konfiguriert“), `auth_errors.dart:27-43` sucht genau diese Wörter. Jede Textänderung bricht die Zuordnung. Apple-Login ohne Nonce; Apple-Name (`fullName`) wird angefordert, aber nie gespeichert (`supabase_service.dart:75-93`).
11. **Kein iOS-Autofill:** keine `AutofillGroup`, kein `TextInput.finishAutofillContext`, kein `AutofillHints.oneTimeCode`; Reset-Felder ohne `newPassword`-Hint (`login_screen.dart:301-334`, `signup_screen.dart:247-304`, `otp_verification_view.dart:55-68`, `reset_password_screen.dart:158-243`). Folge: kein Passwort-Speichern-Dialog, kein Code-Vorschlag aus Mail, kein starkes Passwort von iOS.
12. **Google-Logo aus dem Netz:** `Image.network('https://www.google.com/favicon.ico')` bei jedem Aufbau (`google_logo.dart:11-20`): Anfrage an Google vor jeder Einwilligung (Datenschutz), Aufpoppen, offline ein unpassendes Ersatz-Icon.
13. **Namensabfrage überspringen** lässt den E-Mail-Präfix als Anzeigenamen in geteilten Listen stehen (`auth_provider.dart:100-101`); andere Mitglieder sehen so einen Teil der E-Mail-Adresse.
14. **Pending-Link nur im Speicher:** Wird die App während Registrierung oder Mail-Bestätigung beendet, ist die Einladung weg (`app_router.dart:69, 401-403`). Der Nutzer sieht im Onboarding auch nicht, dass er eingeladen wurde.
15. **`UserService.updateUserProfile` schreibt die ganze Zeile** aus einem evtl. veralteten Modell (`user_service.dart:9-18`); parallele Änderungen (z. B. Ernährung aus dem Onboarding-Sync oder vom zweiten Gerät) können überschrieben werden.
16. **Tutorial-Performance:** `Timer.periodic(100 ms)` misst das Ziel und ruft `setState` über einen Stack, der die ganze App umschließt (`tutorial_overlay.dart:88-91, 111-120`); `ListenableBuilder` baut bei jedem Schritt die App-Hülle neu; Endlos-Pulsanimation. Tap-Blocker sperrt Scrollen, wodurch Ziele außerhalb des Bildschirms unerreichbar werden können.
17. **Launch-Übergang:** leerer System-Launch-Screen, danach harter Farbwechsel auf Creme; im Dunkelmodus Schwarz → Creme (`LaunchScreen.storyboard`, LaunchImage 1x1 px).
18. **Zwei Caches für dasselbe Flag:** `_onboardingCompleteCache` (`onboarding_screen.dart:19`) und `_onboardingDone` (`app_router.dart:65`); `markOnboardingComplete` setzt nur den ersten. Funktioniert, weil der Router `false` nie memoisiert, ist aber fragil.
19. **Snackbar-Abhängigkeit:** `NamePromptScreen` nutzt `ScaffoldMessenger.of(context)` (`name_prompt_screen.dart:57`) und verlässt sich auf den globalen Messenger aus `app.dart:228`; ohne ihn wirft der Aufruf auf iOS.
20. **Tests:** Kein Test für Router-Redirects, Onboarding-Sync oder Auth-Fehlerzuordnung (`test/` enthält nur andere Bereiche plus `translations_test.dart`). Keine Analytics-Ereignisse für den Onboarding-Trichter (kein `logEvent` im Bereich).

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Router (`app_router.dart`):** Redirects für alle Bereiche, `/diet-preferences`, geteilte Listen (`/list`, `/invite` → `/lists/:id`), öffentliche Rezept-Links. Teil A besitzt den Router; das Modulsystem (Vertrag 1 in `arbeitsteilung.md`) muss hier Modul-Tabs ein- und ausblenden.
- **Modulsystem:** heute nur `calorieTrackingEnabledProvider` (`calorie_tracking_provider.dart`), liest `nutrition_goals` über `NutritionGoalService`, wird von `main_scaffold.dart` (Kalorien-Tab) und Kalorien-Screens gelesen. Laut Vertrag zieht B es auf `moduleEnabledProvider(AppModule)` um; das Onboarding schreibt künftig dort hinein.
- **B-Slots im Onboarding:** `OffersSetupStep(onDone:)` (PLZ/Standort, Lieblingsmärkte), Zielberechnung über `nutrition_goal_service` (`arbeitsteilung.md`, Vertrag 3).
- **`users.app_priorities`:** steuert die Reihenfolge der Startseiten-Karten (`home_nudge_card_order.dart`, Test `home_nudge_card_order_test.dart`), Avo-Chat-Vorschläge (`avo_chat_screen.dart:42`), Rezept-Personalisierung (`recipe_personalization.dart`), Avo-Kontext (`avo_assistant_service.dart:1951`); editierbar in `profile/settings/app_priorities_screen.dart`.
- **`users.diet_preferences`:** Rezeptfilter und Ersetzungen (Rezepte, Avo, Kalorien-Rezeptvorschläge), Einstellungen `diet_preferences_screen.dart`.
- **Kalorien:** `nutrition_goals`, `weight_logs`, `NutritionGoalCalculator`, `goal_setup_screen.dart` (gleiche Felder wie Onboarding-Seite 7).
- **Tutorial-Ziele in fremden Screens:** `home_screen.dart:61-150, 387-443` (legt erste Liste an), `list_detail_screen.dart:146, 382, 400, 528`, `recipes_screen.dart:163, 268, 328`, `main_scaffold.dart:180-187, 302-310` (Tab-Keys), `profile_screen.dart:237` (Neustart). Ein neues Layout dieser Screens bricht die Coach-Marks.
- **Auth-Seiteneffekte in `main.dart:121-175`:** bei `signedIn` Mitteilungs-Sync, FCM-Token, Avo-Erinnerungen, Widget-Credentials; bei `signedOut` Widget leeren, Offline-Cache und Kategorie-Lernspeicher leeren. `home_screen.dart` lädt Listen bei Kontowechsel neu.
- **Abmelden:** `profile_screen.dart:286-288` → `/welcome`.
- **Gemeinsame Bausteine:** `PaperColors`/`PaperTextStyles` werden in 47 Dateien importiert, `paper_widgets.dart` in 8. Beim Entfernen von Paper sind Startseite, Tab-Bar (`main_scaffold.dart` nutzt `PaperColors.ink`) und weitere Screens betroffen.
- **Maskottchen:** `avo_mascot.dart` + `assets/avo/*.png` (Namensabfrage, Tutorial, Startseite, Avo).
- **Strings:** `onb_*`, `welcome_*`, `otp_*`, `name_prompt_*`, `reset_password_*`, `priority_*`, `diet_*`, `goal_type_*`, `activity_*`, `gender_*`, `my_first_list` in `app_translations.dart` (DE und EN, geprüft durch `test/translations_test.dart`). Tutorial-Texte liegen außerhalb der Übersetzungen.
- **Deep Links:** `DeepLinkService`, `NavigationService.navigateToDietPreferences` (vom Tutorial genutzt).
- **Datenbank:** `users` (Spalten `display_name`, `diet_preferences`, `app_priorities`, `onboarding_completed`, `tutorial_completed`, `age`, `height`, `height_unit`, `gender`, `auth_provider`). Für `tutorial_completed` und `onboarding_completed` liegt keine Migration in `database/migrations/` (nur `add_app_priorities_to_users.sql`).

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen**
- Anmeldung mit Apple (iOS), Google und E-Mail + Passwort; Registrierung mit 6-stelligem Code; Code erneut senden; Passwort vergessen per Code; neues Passwort mit denselben Regeln (8 Zeichen, Großbuchstabe, Ziffer).
- Namensabfrage nur für neue Konten, überspringbar.
- Onboarding funktioniert ohne Konto und offline; Antworten werden lokal gehalten und genau einmal ins neue Konto übertragen, nie in ein bestehendes Konto (5-Minuten-Schutz oder ein besseres Kriterium).
- Personalisierung: Prioritäten, Ernährung, Kalorien an/aus, Körperdaten mit derselben Berechnung wie `goal_setup_screen` (`NutritionGoalCalculator`); jede Frage überspringbar, leere Auswahl = Standardverhalten.
- Kalorien-Schalter als Vorbild für die künftige Modulwahl (Plan 1, Liste 5): Kern Liste + Rezepte immer an, Module mit Schalter, Angebote/Spar-Funktionen standardmäßig an, bei Angebots-Modul PLZ/Märkte im selben Ablauf.
- Ein Einführungsweg nach dem ersten Login (heute Coach-Marks inkl. „Meine erste Liste“ anlegen, überspringbar, im Profil neu startbar).

**Daten**
- Alle Felder aus Tabelle 2.11 mit identischen Spaltennamen und IDs (`kAppPriorities`-IDs, `kDietPreferenceIds`, `goal_type`/`activity_level`-DB-Werte), damit Startseite, Rezepte, Avo und Kalorien weiter funktionieren.
- SharedPreferences-Schlüssel `onboarding_complete_v1`, `onb_pending_*`, `onb_answers_synced_v1`, `calorie_tracking_enabled` (oder eine Migration), sonst sehen bestehende Nutzer das Onboarding erneut.

**Sonderfälle**
- Eingeladen per Link ohne Konto: Einladung merken und nach Anmeldung öffnen (heute nur im Speicher, besser dauerhaft und sichtbar).
- Geteilte Rezept-Links bleiben ohne Anmeldung lesbar und überspringen das Onboarding.
- Bestehender Nutzer auf neuem Gerät oder nach Neuinstallation.
- Social-Login abgebrochen → keine Meldung; Apple im Simulator nicht verfügbar → eigene Meldung; Provider nicht konfiguriert → eigene Meldung; Rate-Limit und Netzfehler überall.
- E-Mail nicht bestätigt beim Login → Bestätigungsmail erneut senden; falsches Passwort → Angebot „Registrieren“; Konto existiert bei Registrierung → Angebot „Anmelden“.
- Passwort-Reset abbrechen meldet die Wiederherstellungs-Session ab.
- Abmelden leert Widget-Daten, Offline-Cache und Lernspeicher; Kontowechsel lädt alles neu.
- Router-Ausnahme: Login/Signup leiten nach Erfolg selbst weiter (sonst Rennen mit der OTP-Prüfung und falsche Fehlermeldung, `app_router.dart:446-451`).
