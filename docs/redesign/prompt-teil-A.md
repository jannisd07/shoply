ultracode

# Avo-Redesign – Teil A (Mac 1, Owner): Fundament und Kern-App

Du übernimmst **Teil A** eines kompletten Redesigns und Umbaus unserer iPhone-App „Avo“ (im Code noch „Shoply“; Flutter, iOS zuerst, Supabase, Riverpod) im Repo, in dem du gerade arbeitest.

**Teil B** macht gleichzeitig eine zweite Claude-Code-Session auf Jannis' Mac: im selben GitHub-Repo (`jannisd07/shoply`), mit demselben Claude-Account, die ganze Zeit parallel zu dir.

Dieser Prompt verfolgt zwei Ziele:
1. Die App wird so gut, als käme sie von Apple.
2. A und B kommen sich nie in die Quere.

Arbeite selbstständig und gründlich. Frag den Owner nur bei den Entscheidungen in Abschnitt 10, und arbeite bis zur Antwort an etwas anderem weiter. Beginne jede Antwort mit der Zeile „Bereich: …“, wie es die Zwei-Mac-Regeln in `CLAUDE.md` verlangen.

---

## 1. Ziel

- **Komplettes Redesign im D2-Glas-Design:**
  - Das Aussehen ist verbindlich festgelegt im Artifact „Shoply Redesign – 5 Richtungen“, Seite „D2 · Glas“ (https://claude.ai/artifact/FKDP5yDZnBeGzfn6HH19dU), samt der Erweiterungen `X-…`. Details stehen in `docs/redesign/design-quelle.md`.
  - Apple-Stil, iOS 27, Liquid Glass auf der schwebenden Bedienebene
  - SF Pro, Federn statt fester Animationsdauern
  - hochwertig genug, dass Leute Avo Pro kaufen
  - Das heutige „Paper“-Design (Creme, Georgia-Serifen, Terrakotta) verschwindet komplett.
- **Auf jedem iPhone korrekt:**
  - Breiten 320 pt (Anzeigezoom „Größerer Text“), 375, 390/393, 402 und 440 pt
  - Dynamic Type bis AX5, fetter Text, Reduce Motion und Reduce Transparency
  - Nichts wird abgeschnitten. Heute ist z. B. auf dem iPhone 13 Pro der Mutter des Owners der Text in der Eingabeleiste einer Liste halb abgeschnitten.
- **Schnell und flüssig:** Inhalte kommen sofort aus dem lokalen Stand, nie ein Vollbild-Spinner, Abhaken und Scrollen ohne Ruckeln.
- **Täglich nützlich:** Die Startseite ist die Liste von heute und zeigt höchstens ein bis zwei wirklich nützliche Hinweise.

## 2. Pflichtlektüre (vor der ersten Änderung, vollständig)

1. `CLAUDE.md`: Zwei-Mac-Regeln, Skills-Tabelle, Build- und Analyse-Befehle, Speicher-Hinweise.
2. `docs/redesign/arbeitsteilung.md`: **verbindlich** für Dateibesitz, Verträge, Meilensteine, Status-Dateien und Git-Protokoll.
3. **Das Design:**
   - `docs/redesign/design-quelle.md` und `docs/DESIGN-STATUS.md` (feste Owner-Regeln: **keine Bottom-Sheets, keine Schieberegler, Bearbeiten immer im Vollbild**; Avo immer als echte 3D-Figur)
   - das D2-Artifact selbst (Artifact-Tool, `action: "read"`). Lies mindestens `project/D2-Komponenten.dc.html` und jeden Screen deines Bereichs; die Bild-URLs `/_blob/…` sind die Fotos des Entwurfs.
   - Danach `docs/redesign/konzept/00-grundlagen.md` und `01-navigation-und-struktur.md`, aber **nur inhaltlich** (Abläufe, Zustände, Barrierefreiheit, Module). Ihr Aussehen ist überholt, D2 gewinnt.
4. **Deine Kapitel** in `docs/redesign/konzept/`:
   - `10-heute.md`
   - `11-listen.md`
   - `13-rezepte.md`
   - `17-onboarding.md`
   - `18-profil-pro.md`
   - `20-qualitaet.md`
   - aus `19-system.md` der Teil zum App-Icon
5. **Die Kapitel von Teil B nur überfliegen**, damit du seine Slots und Abläufe kennst: `12-angebote-verlauf.md`, `14-wochenplan.md`, `15-kalorien.md`, `16-avo.md`, `19-system.md`.
6. **Ist-Zustand deiner Bereiche** mit Datei:Zeile: `docs/redesign/konzept/inventar/` (shell, home, lists-core, lists-more, recipes-browse, recipes-detail, onboarding, profile, perf, brand).
7. **Weitere Quellen:**
   - `docs/Shoply-Ideen-und-Plan.md` (Jannis' Plan; **bei Widersprüchen gilt der Plan**)
   - `docs/research/Preise Angebote und Artikelbilder.md`
   - `docs/redesign/avo-verbesserungsliste.md`
8. `docs/redesign/status-B.md`, falls schon vorhanden.

## 3. Skills

Lade die passenden Skills nach der Tabelle in `CLAUDE.md`, ohne zu fragen:

| Wofür | Skills |
|---|---|
| Planung und Umsetzung | `superpowers:writing-plans` für deinen Plan; danach `superpowers:subagent-driven-development` oder Workflows; `planning-with-files`, um den Fortschritt über die lange Arbeit zu halten |
| Jeder Screen und jede Komponente | `apple-design`, `design-taste-frontend` (dessen App-Screen-Regeln; seine Web-Regel „kein Glas“ gilt in iOS nicht, hier gilt Apples Liquid-Glass-Regel), `frontend-design`, `ui-ux-pro-max` |
| Barrierefreiheit | `design:accessibility-review` |
| Alle sichtbaren Texte | `design:ux-copy`, danach `humanizer` |
| Flows testen | `idiotensicher-testen` für Onboarding, Hinzufügen, Teilen und Paywall (im Simulator) |
| Bugs | `superpowers:systematic-debugging` |
| Vor jedem „fertig“ | `superpowers:verification-before-completion` |
| Größere Pakete | `superpowers:requesting-code-review` |
| Flutter-, Riverpod-, GoRouter- und Supabase-Fragen | Context7 |

Fehlt ein Plugin auf diesem Mac, sag es einmal und arbeite weiter.

## 4. Zuerst, in dieser Reihenfolge

1. **Synchronisieren:** `git fetch` und `git pull --rebase origin main`.
   - Meldet git, dass unversionierte Dateien unter `docs/redesign/` überschrieben würden: Das sind lokale Kopien derselben Dateien, entstanden vor dem Push.
   - Vergleiche sie mit `origin/main` (`git diff --no-index`). Liegt eine lokale Datei neuer, sichere sie zuerst.
   - Entferne die lokalen Kopien und pulle erneut.
2. **Meilenstein S0 (Aufräumen):**
   - Auf diesem Mac lief ein Aufräum-Workflow: Session „Shoply App Version“, Branches `cleanup/group-A` bis `cleanup/group-I`, Worktrees unter `.claude/worktrees/`. Er löscht u. a. `lib/presentation/screens/ai/ai_screen.dart`, `ai_dashboard_screen.dart`, `scanner/ingredient_scanner_screen.dart` und `recipes/add_recipe_screen*.dart`.
   - Prüfe, ob diese Arbeit in `origin/main` ist. Wenn nicht, frag den Owner, ob jene Session fertig ist und gemergt werden soll. Merge nie ohne sein Ja.
   - Stelle sicher, dass keine andere Claude-Session in diesem Ordner arbeitet. Wenn doch, arbeite in einem eigenen Worktree.
   - Trag S0 in deine Status-Datei ein, sobald `main` sauber ist.
3. **Design steht fest:**
   - Verbindlich ist D2 · Glas (siehe `design-quelle.md`).
   - Hängt der Owner neue Bilder an oder ändert er das Artifact, gilt der neueste Stand. Lies das Artifact dann erneut.
   - Passe Konzept-Texte nur an, wenn sich Funktionen ändern.
4. **Status-Datei:** Lege `docs/redesign/status-A.md` an (Aufbau laut `arbeitsteilung.md` Abschnitt 5) und pushe sie.
5. **Plan:** Schreibe deinen Plan mit `superpowers:writing-plans` nach `docs/superpowers/plans/<datum>-teil-a.md`. Zerlege die Arbeitspakete A1 bis A12 in kleine, einzeln prüfbare Aufgaben.

## 5. Arbeitspakete Teil A

Die Reihenfolge ist wichtig: A1 und A2 schalten Teil B frei.

### A1 Struktur, Meilenstein S1. Sofort, so früh wie möglich.

- **Übersetzungen aufteilen:** `lib/core/localization/app_translations.dart` in Bereichsdateien unter `lib/core/localization/translations/` zerlegen, je Bereich Deutsch und Englisch.
  - A-Bereiche: common, home, lists, recipes, onboarding, auth, profile, settings, paywall, legal.
  - B-Bereiche: avo, calories, plan, offers, history, notifications, system.
  - Die B-Dateien legst du einmalig mit dem heutigen Inhalt an. Danach gehören sie B.
  - `AppTranslations.get` verhält sich unverändert, `test/translations_test.dart` bleibt grün.
- **Router aufteilen:** `lib/routes/app_router.dart` in Bereichsdateien unter `lib/routes/areas/` zerlegen. Routen, Redirects und Deep Links bleiben unverändert. Die B-Dateien (avo, calories, plan, offers, history) gehören danach B.
- **Modulsystem** nach Vertrag 3.1 in `arbeitsteilung.md`: `lib/core/modules/app_modules.dart` mit `enum AppModule` (alle Module aus 00 Kap. 15) und `moduleEnabledProvider`. Lokal gespeichert und mit dem Konto synchronisiert. Noch ohne UI.
- **Abschluss:** Pushen, S1 in `status-A.md`, ein Satz an den Owner, dass Jannis' Session pullen kann.

### A2 Fundament, Meilenstein S2

- **Tokens aus D2** (`D2-Komponenten` und die Screens): Farben (hell; dunkel und erhöhter Kontrast passend dazu ableiten und dem Owner einmal zeigen), Typografie, Abstände, Radien, Glas und Feder-Tokens in `lib/core/constants/` (`AppColors`, `AppDimensions`, `AppTextStyles`). Keine hart codierten Werte in Screens.
- **Typografie:**
  - Stile analog iOS: Größe, Gewicht, Zeilenhöhe und Laufweite je Stil.
  - Dynamic-Type-Regeln: mitwachsen, umbrechen statt abschneiden, keine festen Höhen um Text.
- **Material:**
  - Liquid Glass genau dort, wo D2 es zeigt (Tab-Bar, Toolbar-Knöpfe, Eingabefeld, Info-Glas auf Fotos), nativ über `adaptive_platform_ui` bzw. `ios/Runner/LiquidGlassViewFactory.swift`.
  - Fallbacks für Reduce Transparency und ältere Geräte.
  - Performance-Budget einhalten (iPhone 13 Pro).
- **Komponenten-Bibliothek** nach `D2-Komponenten` (Ablauf- und Zustandsregeln aus 00 Kap. 12) in `lib/core/design/` bzw. `lib/presentation/widgets/design/`, jede mit Widget-Test. Dazu gehören auch die für B zugesagten Bausteine: `RecipeCard`, Pro-Kennzeichnung, Leer-, Fehler- und Offline-Zustände, Vollbild-Bearbeiten-Screen, Menüs und Buttons (keine Sheets).
- **Shell:**
  - Die D2-Tab-Bar: schwebende Glas-Kapsel mit **Home, Listen, Avo, Rezepte, Profil**. Der Avo-Tab ist der eine Avo-Einstieg und führt auf die Avo-Route von B.
  - Module bekommen keine eigenen Tabs: Wochenplan ist ein Segment im Rezepte-Tab, Kalorien läuft über Home und Push-Screens (siehe `design-quelle.md`).
  - Routen-Pfade für B-Screens legst du in A1 fest und trägst sie in `status-A.md` ein.
- **Ikonografie:** die Icons so, wie D2 sie zeigt. Ob SF Symbols nativ oder eigene Vektoren: Technik und Lizenz prüfen und eine Alternative bereithalten.
- **Bewegung und Haptik:** Helfer für Federn (`SpringDescription`), Herkunft am Auslöser, Haptik-Tabelle, Reduce Motion.
- **Layout-Prüfgerüst `test/layout/`:**
  - Ein Helfer rendert einen Widget-Baum in allen Breiten (320, 375, 390, 402, 440) und Textskalierungen (1.0, 1.35, 2.0, 3.1), auch mit fettem Text.
  - Er schlägt bei jedem Overflow fehl.
  - Teil B nutzt ihn auch.
- **Komponenten-Galerie** (Debug-Route): alle Komponenten hell, dunkel und in AX-Größe. Dient zum Vergleich mit den Konzeptbildern.
- **Doku:** Den Designsystem-Abschnitt in `CLAUDE.md` auf das neue Konzept umschreiben (geteilte Datei: eigener Commit, sofort pushen).
- **Paper-Dateien** erst löschen, wenn kein Screen sie mehr nutzt (vorher per grep prüfen, auch in B-Dateien; sonst als Anfrage an B).
- **Abschluss:** Pushen, S2 melden.

### A3 Sofort-Fix Eingabeleiste

Unabhängig von A2 und früh einplanen.
- Den abgeschnittenen Text in `lib/presentation/screens/lists/widgets/add_item_composer.dart` reproduzieren: Widget-Test bei 390 pt mit Textskalierung 1.35 und bei 320 pt.
- **Vermutete Ursachen:**
  - feste Mindesthöhe `_kControlSize = 38`
  - feste Schrift 17 pt plus 9 pt Padding
  - die Höhe wird erst nach dem Frame gemessen (`_height`)
  - `SizedBox(height: h)` im Native-Glass-Pfad
- Beheben, Test grün, eigener kleiner Commit. Das neue Eingabe-Accessory aus A2 darf diesen Fehler nie wieder haben.

### A4 Home nach `D2-FuerDich` (Funktionen aus Kapitel 10)

- Liste von heute mit Listen-Umschalter, Fortschritt und Präsenz.
- Darüber höchstens ein bis zwei kompakte Hinweise.
- Die Hinweis-Karten aus B-Bereichen sind B-Widgets. Du ordnest sie an (`home_nudge_card_order.dart`) und reagierst auf Module.

### A5 Listen nach Kapitel 11

- **Listenübersicht** und **Liste**.
- **Hinzufügen** über ein Feld:
  - Vorschläge aus dem Verlauf.
  - „2 Milch“ ergibt Menge 2 plus Artikel. Den Parser legst du als reine Funktion in `lib/core/utils/` an, mit Tests.
  - Die Kategorie wird im Hintergrund gesetzt.
- **Einkaufsmodus:** große Häkchen, nach Gang sortiert, Bildschirm bleibt an.
- **Geteilte Listen live:** Präsenz („Lena kauft gerade ein“), Abgehaktes erscheint sofort.
- **Teilen und Einladen.**
- **Listen-Einstellungen**, Hintergründe und Listenfarben, Kategorie-Reihenfolge, Aktivitäten.
- **Foto-Import:** Die Oberfläche gehört dir, der Service gehört B.
- **Tempo:** lokaler Stand zuerst und optimistische Updates in `lists_provider`, `items_provider`, `ItemRepository`, `ListRepository` und `offline_cache_service`. Die öffentlichen Methoden bleiben stabil.
- **Slots für B** (Vertrag 3.3): `StoreChip`, `OfferSuggestionsBar`, `ItemOfferBadge`, `ListOfferSummary`, `ArticleImage`, `openCheckoutFlow` und im Listen-Menü der Schalter „Angebote für diese Liste ausblenden“ über `setOffersHiddenForList`. Bis B sie liefert (Meilenstein S4), rufst du die heutigen B-Widgets weiter auf. Danach tauschst du sie gegen die neuen.

### A6 Rezepte nach Kapitel 13

- Entdecken, Suche, Filter, Rezept der Woche, Creator und Folgen, Gespeichert, Meine Rezepte, Entwürfe.
- **Rezeptdetail:** Nährwerte, Zutaten auf die Liste, Personalisierung bei Allergien (Sicherheit zuerst), Varianten.
- **Kochmodus** mit Timern und Portionen; Rezept erstellen in Schritten.
- B-Slots: `RecipeOffersCard`, `openLogRecipe`.

### A7 Onboarding, Login und Modulwahl nach Kapitel 17

- Willkommen; Apple, Google, E-Mail, Passwort vergessen; Name.
- **Modulwahl mit Nutzen:** Kern sind Liste und Rezepte. Welche Module vorausgewählt sind, fragst du den Owner. Sein bisheriger Wunsch: Spar-Funktionen an.
- Ist das Angebots-Modul an, bettest du B's `OffersSetupStep` ein (Standort bzw. PLZ, Lieblingsmärkte; Vertrag 3.3).
- Ernährung und Allergien, optional Kalorienziel.
- Mitteilungen nur mit klarem Nutzen.
- Erstes Erfolgserlebnis: der erste Artikel auf der ersten Liste.
- Das alte Tutorial nur behalten, wenn das Konzept es vorsieht.

### A8 Profil und Einstellungen nach Kapitel 18

- **Struktur:** Module, Mitteilungen, Darstellung, Sprache, Ernährung und Allergien, Konto (Abmelden und Löschen mit Rückfrage), Hilfe, Rechtliches.
- **Links auf B-Seiten:** „Preise & Angebote“, Apple Health und alle weiteren, die das Konzept vorsieht.

### A9 Pro und Paywall nach Kapitel 18

1. **Analyse** nach `docs/redesign/pro-konzept.md`:
   - Ist-Stand: wo wird `isPremium` geprüft, was ist wirklich gesperrt, was verspricht die Paywall?
   - Vorschlag Free gegen Pro: Angebote sind nie Pro, solange keine Lizenz besteht.
   - Wertbeweis und Zeitpunkt der Paywall.
   - Familienfreigabe prüfen.
2. **Der Owner entscheidet**, dann baust du:
   - die Paywall
   - die Pro-Kennzeichnung
   - eine `ProGate`-Komponente, die B für seine Bereiche nutzt
3. **Texte:** Die Pro-Texte in Avos Wissen (`AvoAppKnowledge`) gehören B. Schick B die finalen Inhalte als Anfrage.

### A10 App-Icon und Maskottchen

- **App-Icon** nach 19-system und 00 Kap. 3: in allen iOS-Erscheinungen (hell, dunkel, klar, getönt) als Ebenen vorbereiten, eingebaut in `AppIcon.appiconset`.
- **Neue Maskottchen-Grafiken** kannst du nicht selbst zeichnen. Schreibe dafür präzise Bild-Prompts und bitte den Owner, sie zu erzeugen. Danach baust du sie ein.

### A11 Qualität für alle A-Screens

- **Prüfmatrix** (`test/layout/`) für jeden A-Screen, grün.
- **Simulator-Stichproben** mit Screenshots, hell und dunkel.
- **Barrierefreiheit:** VoiceOver-Labels, Kontrast, Reduce Motion, Reduce Transparency.
- **Messung im Profile-Modus** (Startseite, Liste, Rezepte): keine Frames über 16 ms.
- **Flows testen** mit `idiotensicher-testen`: Onboarding, Hinzufügen, Teilen, Paywall.

### A12 Aufräumen und Analysen

- **Rest des Repo-Aufräumens:** z. B. `screens/admin/recipe_batch_labeling_screen.dart`, alte Paper-Bausteine, kurze Doku statt der großen Status-Datei.
- **Owner fragen**, ob die tägliche Claude-Routine (`claude/daily`) weiterlaufen soll.
- **Analyse** `docs/redesign/feature-ideen.md`: Tägliche Nutzung und Alleinstellungsmerkmale mit kurzem Wettbewerbsvergleich (Bring!, Listonic, AnyList, Apple Erinnerungen, marktguru, kaufDA, REWE- und Lidl-App, Yazio). Pro Idee: Nutzen, Aufwand, Free oder Pro. Der Owner entscheidet.
- **Gegenprüfung (S6):** die Screens von Teil B nur lesend prüfen (Prüfmatrix, Konzepttreue, Apple-Regeln). Funde als Anfragen in `status-A.md`.

## 6. Dateibesitz (Kurzfassung, maßgeblich ist `docs/redesign/owner.sh`)

**Deine Dateien:**
- Designsystem und Kern: `lib/core/constants`, `theme`, `widgets`, `mascot`, `modules`, `design`, `utils` (außer `category_detector`, `product_name_normalizer`, `request_throttle`)
- Übersetzungs- und Router-Gerüst plus deine Bereichsdateien, `lib/app.dart`, `main_scaffold.dart`
- Screens `home`, `lists`, `recipes`, `onboarding`, `auth`, `splash`, `profile`, `subscription`, `legal`, `admin`
- Widgets `common`, `recipes`, `recommendations`, `tutorial`, `design`
- Provider `auth`, `items`, `last_list`, `lists`, `recipes`, `saved_recipes`, `theme`, `language`, `subscription`, `ml_recommendations`
- Repositories; die Modelle für Listen, Artikel, Rezepte, Nutzer und Kategorien; die Services für Listen, Rezepte, Konto, Einstellungen, Tutorial, Teilen, Deep Links, Offline-Cache und Abo
- `ios/Runner/LiquidGlassViewFactory.swift`, das `AppIcon.appiconset`, `assets/*` (außer Artikelbilder), `test/layout/`

**Nicht deine Dateien, auch wenn sie in deinen Ordnern liegen:**
- Angebots-Widgets der Liste: `offer_*`, `list_price_summary_bar`, `list_offer_*`, `item_offer_*`, `zip_code_sheet`, `checkout_store_sheet`, `store_chip*`
- `recipe_offers_card`, `weekly_deals_screen`
- die Hinweis-Karten `avo_nudge_card`, `calorie_recipe_nudge_card`, `pending_splits_banner`, `personal_flyer_card`, `price_comparison_nudge_card`, `split_trip_nudge_card`
- `profile/settings/offers_settings_screen.dart`

**Außerdem gehören B:**
- alles unter `ios/` außer den zwei genannten Dateien
- `lib/main.dart`
- alle KI-, Angebots-, Verlaufs-, Kalorien-, Avo- und System-Services, -Provider und -Modelle
- `supabase/functions/*` und die bestehenden Migrationen

**Werkzeuge:**
- Vor jedem Commit: `bash docs/redesign/check-ownership.sh A`. Bricht es ab, nimmst du die fremde Datei aus dem Commit und trägst eine Anfrage in `status-A.md` ein.
- Bei Zweifel: `bash docs/redesign/owner.sh <pfad>`.

**Geteilte Dateien:**
- `pubspec.yaml` und `pubspec.lock`: neue Pakete als eigener Mini-Commit, sofort pushen. Bei Konflikt beide behalten, `flutter pub get`.
- `CLAUDE.md`: nur der Designsystem-Abschnitt.
- `docs/`: nur deine Dateien und deine Konzeptkapitel. Das sind 00, 01, 10, 11, 13, 17, 18, 20 und der Icon-Teil von 19.

## 7. Arbeitsweise mit ultracode (Workflows)

- **Eine Sitzung je Arbeitspaket** (Owner, 09.11.2026, Wochenlimit): Jede Sitzung bearbeitet genau ein Paket, schreibt
  das Ergebnis in die Dateien, erinnert den Owner an eine neue Sitzung und gibt ihm den Start-Prompt. Ablauf, Pakete
  und Start-Prompt: [`a-sitzungen.md`](a-sitzungen.md).
- **Workflows lohnen sich hier:**
  - viele Screens eines Bereichs umbauen (ein Agent pro Screen)
  - Prüfmatrix über alle Screens
  - Konzepttreue-Review vor dem Push eines großen Pakets (unabhängige Prüfer mit unterschiedlichen Blickwinkeln: Apple-Treue, Barrierefreiheit, Tempo, Regressionen)
  - Bug-Suche bis keine neuen Funde mehr kommen
- **Dosierung:** Höchstens 4–6 Agenten gleichzeitig. Ihr teilt euch einen Claude-Account mit B, und die Platte ist voll.
- **Worktree-Isolation** nur, wenn Agenten parallel Dateien ändern, und dann höchstens 3 gleichzeitig. In Worktrees nur `flutter pub get` und `dart analyze`, nie iOS-Builds. Worktrees danach entfernen.
- **Speicher:** vor jedem Build `df -h /System/Volumes/Data`. Unter 15 GB keine neuen Worktrees. Unter 10 GB keine Builds, stattdessen den Owner bitten, Platz zu schaffen (Papierkorb, alte Simulatoren, siehe `CLAUDE.md`). Lösche nie selbst Dinge außerhalb des Repos.

## 8. Git-Protokoll und Abstimmung mit Teil B

1. **Vor jeder Aufgabe:** `git pull --rebase origin main`, dann `docs/redesign/status-B.md` lesen (Anfragen an dich, Meilensteine von B).
2. **Branch pro Arbeitspaket:** `feature/a-<thema>`, kleine Commits.
3. **Vor jedem Commit:** `bash docs/redesign/check-ownership.sh A`, dann `dart analyze` (0 Errors, 0 Warnings; die bekannten Info-Lints ignorieren).
4. **Vor jedem Push:**
   - `git fetch`, `origin/main` hereinholen, `dart analyze` erneut
   - bei UI-Änderungen `flutter build ios --simulator --debug` (Speicher prüfen)
   - `main` vorspulen, `git push origin main`, Branch löschen
   - ein Satz, dass Jannis pullen kann
5. **Anfragen von B** haben Vorrang vor neuer eigener Arbeit, wenn B sonst blockiert ist. Erledigt wird mit Commit-Hash in `status-A.md`.
6. **Niemals:**
   - Force-Push oder Umschreiben veröffentlichter Historie
   - geheime Dateien pushen
   - Migrationen auf der echten Datenbank anwenden oder Edge Functions deployen ohne Owner-Freigabe
   - TestFlight auslösen
   - `claude/daily` ungefragt mergen
7. **Notfall:** Bricht der Build durch eine Datei von B, machst du die kleinste mögliche Korrektur als eigenen Commit `fix(a): …` und trägst sie sofort in `status-A.md` ein.

## 9. Qualitätsmaßstab (gilt für jedes Arbeitspaket)

- **Designtreue:** jeder Screen sieht aus wie im D2-Artifact; im Code nur deine Tokens und Komponenten. Abweichungen sprichst du mit dem Owner ab.
- **Barrierefreiheit:** Prüfmatrix grün; VoiceOver-Labels; Touch-Ziele mindestens 44 pt.
- **Zustände:** leer, lädt (sofort lokaler Stand), Fehler, offline, Modul aus, Pro gesperrt. Jeder Zustand ist gestaltet.
- **Texte:** Deutsch und Englisch, konkret, mit `design:ux-copy` und `humanizer` geprüft.
- **Code:** sauber und in kleinen Commits; `dart analyze` 0/0; Simulator-Build läuft.
- **„Fertig“:** erst nach `superpowers:verification-before-completion` und mit Belegen (Testausgabe, Screenshots).

## 10. Nur der Owner entscheidet

Stelle diese Fragen mit `AskUserQuestion` und arbeite weiter:
1. App-Name (Avo oder Shoply) und damit Abo-Name, Icon-Schriftzug und Siri-Sätze.
2. Freigabe der Design-Richtung bzw. Abweichungen nach den ChatGPT-Bildern.
3. Welche Module beim ersten Start vorausgewählt sind.
4. Free gegen Pro (nach deiner Analyse in A9).
5. Ob der Aufräum-Workflow gemergt werden soll; ob `claude/daily` weiterläuft.
6. Neue Maskottchen-Grafiken und das finale App-Icon-Motiv.
7. TestFlight und App Store.

## 11. Fertig, wenn

- A1 bis A12 erledigt sind und jeder Meilenstein in `status-A.md` steht.
- Alle A-Screens dem Konzept entsprechen und die Prüfmatrix grün ist.
- Der Bug der Mutter des Owners nachweislich behoben ist.
- Kein Paper-Rest mehr in A-Dateien steckt.
- Die Anfragen von B erledigt sind und die Gegenprüfung (S6) abgeschlossen ist.
- Der Owner einen Abschlussbericht hat: was gebaut wurde, was offen ist, welche Entscheidungen noch ausstehen.

**Starte jetzt mit Abschnitt 4, Schritt 1.**
