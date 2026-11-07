# 17 Onboarding, Login und Modulwahl

Stand: 07.11.2026. Besitz: **Teil A** (Screens `onboarding`, `auth`, Router-Gerüst). Slots von **Teil B**: `OffersSetupStep(onDone:)` (Region und Märkte) und die Zielberechnung über die stabile API von `nutrition_goal_service`. Baut auf `00-grundlagen.md` (Verweise "00 x.y") und `01-navigation-und-struktur.md` (Verweise "01 x.y") auf. Quellen: Plan 1, Verbesserungsliste 5 und 6, Inventare `onboarding.md` und `brand.md`.

**Owner-Regel "keine Slider" (CLAUDE.md, 07.11.2026) gilt in diesem Kapitel ohne Ausnahme:** keine Bottom-Sheets, keine halbhohen Modals, keine Drawer, keine Schieberegler. Alles in diesem Bereich ist ein Vollbild-Schritt (Push mit Zurück), passiert direkt am Ort oder ist ein zentrierter Alert bzw. ein Pull-down-Menü. Wo 00 und 01 für diesen Bereich ein Sheet vorsehen (Vorab-Erklärung für Berechtigungen, Beitritts-Sheet, Modul-Sheet), steht hier die regelkonforme Lösung; die Abweichungen sind in Kapitel 8 gesammelt.

Inhalt: 1 Überblick · 2 Gemeinsamer Rahmen · 3 Erster Start (Schritte) · 4 Konto, Anmelden, Passwort · 5 Sonderfälle und Varianten · 6 Nach dem Onboarding: Tipp-Zeilen und Berechtigungen · 7 Abläufe · 8 Offene Fragen · 9 Ergänzungen zum Fundament

---

## 1. Überblick

### 1.1 Ablauf

```
Launch (Systemhintergrund)
└─ Willkommen ─┬─ "Los geht's" ──────────────────────────────────────────────┐
               └─ "Ich habe schon ein Konto" → Anmelden (4.1) → Tab Liste     │
                                                                              ▼
   Module → [Angebote in deiner Region]* → Konto → [E-Mail → Code] → Name
          → Ernährung und Allergien → [Dein Ziel]** → Erste Liste bzw. [Beitreten]***
          → Tab Liste (Accessory fokussiert, Tipp-Zeile)

   *   nur mit Modul Preise & Angebote an und Kill-Switch aus
   **  nur mit Modul Kalorien & Gesundheit an
   *** statt "Erste Liste", wenn man über eine Einladung kommt (5.1)

Anmelden mit einem Konto, das es noch nicht gibt (4.1):
   Konto → Module → [Region]* → Name → Ernährung → [Dein Ziel]** → Erste Liste → Tab Liste
```

Ab dem Konto gibt es kein Zurück mehr zu den Schritten davor (man ist angemeldet; Konto, E-Mail und Code ergeben dann keinen Sinn). Was vorher gewählt wurde, lässt sich in den Einstellungen ändern. So bleibt die Antwort auf "Wie komme ich raus?" in jedem Schritt eindeutig: vor dem Konto Zurück bis Willkommen, danach nur vorwärts oder Überspringen.

Regeln (aus 01 10.9, verbindlich):
- **Unter 60 Sekunden** bis zur eigenen Liste auf dem Standardweg (Kalorien aus). Zeitbudget: Willkommen 3 s, Module 8 s, Region 10 s, Konto mit Apple 6 s, Name 3 s, Ernährung 8 s, Erste Liste 6 s, zusammen etwa 45 s. Mit Kalorien kommt "Dein Ziel" mit etwa 20 s dazu; dieser Weg darf bis 75 s dauern.
- **Jeder Schritt außer Konto ist überspringbar.** Überspringen speichert den Stand des Schritts nicht und nimmt die Standardwerte.
- **Bestandskonten überspringen fast alles:** Wer sich mit einem Konto anmeldet, das schon eingerichtet ist, landet direkt in Tab Liste. Module, Region, Name, Ernährung, Ziel und Listen kommen aus dem Konto.
- **Nicht im Onboarding:** Feature-Seiten, die Prioritäten-Frage (K-22), das Coach-Mark-Tutorial (K-21), die Mitteilungsabfrage, die Pro-Testphase, Pro-Kennzeichnungen, der Avo-Kreis, ein Profilbild.

### 1.2 Daten vor und nach dem Konto

- Die Schritte vor dem Konto (Module, Region) funktionieren **ohne Konto und offline**. Antworten liegen lokal in einem `OnboardingController` (ein Riverpod-Notifier, der während des ganzen Ablaufs lebt) und werden nach jedem Schritt in SharedPreferences gesichert. Wird die App beendet, geht es beim nächsten Start an derselben Stelle weiter (`/onboarding?step=`).
- Nach dem Konto schreibt eine einzige Datenbankfunktion alle Antworten von vor dem Konto in einer Transaktion ins Konto (`apply_onboarding`, 9.6). Sie wirkt nur, wenn das Konto noch nicht eingerichtet ist (`users.onboarding_completed` nicht `true`), und meldet `new` oder `existing` zurück. Sie setzt `onboarding_completed` **nicht**; das geschieht erst am Ende des Ablaufs ("Liste anlegen", "Beitreten" oder Überspringen des letzten Schritts), damit ein abgebrochener Ablauf beim nächsten Start weiterläuft (5.5). Ein zweiter Aufruf mit denselben Antworten ist harmlos (der erste Gewichtseintrag wird pro Tag überschrieben, nicht verdoppelt). Das ersetzt die 5-Minuten-Regel und die 3-Minuten-Regel (Inventar Bugs 4, 5, 6).
- **Bestandskonten vor dem Release:** Heute wird `onboarding_completed` nur beim Sync gesetzt; viele alte Konten haben dort `null`. Eine Migration setzt das Feld für alle Konten, die vor dem Release existieren, auf `true` (9.6). Ohne sie würde `apply_onboarding` alte Konten als neu behandeln und ihre Ernährung überschreiben.
- Die Schritte nach dem Konto (Name, Ernährung, Ziel, Erste Liste) schreiben direkt ins Konto, optimistisch: sofort weiter, Abgleich im Hintergrund, bei Fehler eine `StatusRow` im nächsten Schritt mit "Erneut versuchen". Jeder Schritt aktualisiert nur seine eigenen Felder (gezieltes `update` auf die Spalten), nie die ganze `users`-Zeile aus einem Modell (Inventar Bug 15).

| Daten | Schritt | Lokal vor dem Konto | Ziel im Konto | Später änderbar |
|---|---|---|---|---|
| Module | Module | `onb_pending_modules` (neu) | über `moduleEnabledProvider` (Vertrag 1) | Einstellungen > Module |
| Region, Lieblingsmärkte | Region (B) | Speicher von B | Speicher von B | Einstellungen > Preise & Angebote |
| Anzeigename | Name | – | `users.display_name` | Profil |
| Ernährung | Ernährung | – | `users.diet_preferences` (IDs aus `kDietPreferenceIds`) | Einstellungen > Ernährung & Allergien |
| Allergien | Ernährung | – | `users.allergies` (Feld existiert, heute ohne Oberfläche) | ebenda |
| Ziel und Körperdaten | Dein Ziel | – | `nutrition_goals`, `weight_logs`, `users.age/height/height_unit/gender` | Kalorien > Ziele |
| Erste Liste | Erste Liste | – | `shopping_lists` mit Markt (Feld laut Liste 6c) | Listen-Info |
| Onboarding erledigt | Ende | `onboarding_complete_v1` (Schlüssel bleibt) | `users.onboarding_completed` | – |

Bestehende Schlüssel `onboarding_complete_v1`, `onb_answers_synced_v1` und `calorie_tracking_enabled` bleiben gültig, damit bestehende Nutzer das Onboarding nicht erneut sehen. `onb_pending_app_priorities` wird nicht mehr geschrieben (F-14).

### 1.3 Einstiegsfälle

| Fall | Was passiert |
|---|---|
| Neu, ohne Link | Willkommen, voller Ablauf |
| Neu, über Einladung (`/invite/:id`, `/join/:code`) | Willkommen mit Einladungszeile, voller Ablauf, am Ende "Beitreten" statt "Erste Liste" (5.1) |
| Neu, über Rezept-Link (`/recipe/:id`) | Rezept ohne Anmeldung lesbar. Erst "Zutaten auf Liste" führt ins Onboarding; die Aktion wird gemerkt und am Ende ausgeführt (5.2) |
| Neu, über einen anderen privaten Link (`/lists/:id`, `/author/:id`, Mitteilung, Widget) | Link wird wie eine Einladung dauerhaft gemerkt (`pending_link`), voller Ablauf ohne Einladungszeile, danach öffnet sich das Ziel über dem passenden Tab (01 6) |
| Bestandskonto, neues Gerät oder Neuinstallation | Willkommen > "Ich habe schon ein Konto" > Anmelden > Tab Liste |
| Bestandskonto, abgemeldet, über Einladung | Willkommen mit Einladungszeile > "Ich habe schon ein Konto" > Anmelden > Push-Screen Beitreten (wie 5.1, Kap. 11) > Tab Liste mit dieser Liste |
| Bestandskonto tippt versehentlich "Los geht's" | Ablauf bis Konto; nach der Anmeldung erkennt die App das eingerichtete Konto, verwirft die lokalen Antworten und öffnet Tab Liste (5.3) |
| Neues Konto über "Ich habe schon ein Konto" | Anmelden legt das Konto an; danach Module, Region, Name, Ernährung, Ziel, Erste Liste (4.1) |
| Abgemeldet auf einem Gerät, das das Onboarding kennt | `/welcome` zeigt Willkommen in der Variante "Anmelden" (3.2) |
| Bestehender Nutzer nach dem Update | kein Onboarding; einmalige Hinweis-Zeile zu Modulen (5.4) |

---

## 2. Gemeinsamer Rahmen der Schritte (`OnboardingStepScaffold`)

Alle Schritte außer Willkommen nutzen denselben Rahmen. Er ist neu und steht als Ergänzung in 9.1.

### 2.1 Aufbau von oben nach unten

1. **Obere Leiste** (mindestens 44 pt, unter der Statusleiste): links Glas-Knopf `chevron.left` (00 12.3, "Zurück"; ab Name leer, siehe 1.1); Mitte die **Fortschrittslinie** (9.2): Kapsel 96 × 3 pt, Spur `fill`, Wert `label`; rechts Glas-Text-Kapsel "Überspringen" (00 12.3). In Konto, E-Mail, Code und Beitreten entfällt "Überspringen".
2. **Inhalt** (scrollt, Hintergrund `bgGrouped`): Titel in `title1`, linksbündig, `pageMargin` Abstand, bricht um (keine `\n`); 8 pt darunter ein Satz in `body`, `label`; 24 pt darunter die Inhalte des Schritts aus `InsetSection`s, `ToggleRow`s, `FilterChip`s und Feldern.
3. **Untere Aktionsleiste:** die eine Hauptaktion des Schritts als `AppButton` prominent, volle Breite minus `pageMargin`, 16 pt über dem sicheren Bereich. Oben weicher Scroll-Edge-Verlauf (40 pt aus `bgGrouped`), keine Linie, kein Glas (die Hauptaktion ist ein Inhalts-Knopf, keine schwebende Bedienebene).

Glas-Budget: höchstens 2 native Glas-Views pro Schritt (Zurück, Überspringen), plus ein offenes Pull-down-Menü, solange es offen ist (zusammen höchstens 3, 00 8.5). Kein `BackdropFilter`, kein Glas auf Inhalten oder auf der Aktionsleiste.

### 2.2 Verhalten

- **Übergang zwischen Schritten:** Push von rechts (`CupertinoPageRoute`, 00 10.2), Zurück-Wischen vom linken Rand folgt 1:1 und ist unterbrechbar. Technisch liegen die Schritte in einem eigenen `Navigator` unter der stehenden oberen Leiste; Inhalt und Aktionsleiste gehören zur Seite und schieben mit. Die Fortschrittslinie gleitet beim Weiter mit `springStandard` auf den neuen Wert und folgt beim Zurück-Wischen anteilig dem Finger (bricht man das Wischen ab, federt sie vom aktuellen Wert zurück). Reduce Motion: Überblendung (`fadeReduced`), die Linie springt.
- **Nach dem Konto kein Zurück:** Ab Name ist der linke Platz der oberen Leiste leer und das Zurück-Wischen ausgeschaltet (1.1). Zwischen Name, Ernährung, Ziel und Erste Liste geht Zurück weiterhin.
- **Gesamtzahl der Schritte** ergibt sich aus der Modulwahl: Module, [Region], Konto, Name, Ernährung, [Ziel], Erste Liste bzw. Beitreten, also 5 bis 7 gezählte Schritte (Standard mit Angeboten, ohne Kalorien: 6). Willkommen zählt nicht; E-Mail und Code gehören zum Schritt Konto und zeigen dessen Stand. Der letzte Schritt zeigt die Linie voll. Ändert man im Schritt Module einen Schalter, ändert sich die Linie erst beim Verlassen des Schritts, nie während man liest.
- **Tastatur:** Schritte mit Feld öffnen die Tastatur beim Erscheinen. Die Aktionsleiste sitzt dann direkt auf der Tastatur (`viewInsets`), der Inhalt darüber scrollt. Return im letzten Feld löst die Hauptaktion aus.
- **Hauptaktion bleibt verfügbar:** Kein Schritt sperrt "Weiter" wegen leerer Auswahl; leer heißt Standard. Ausnahmen mit Begründung im jeweiligen Schritt (E-Mail, Code, Neues Passwort).
- **Haptik:** keine bei Weiter, Zurück, Schaltern und Chips (00 11). Fehler-Haptik bei falschem Code und fehlgeschlagener Anmeldung. Auswahl-Haptik am Stepper.
- **Statusleiste:** jeder Schritt setzt die Statusleiste passend zur Darstellung (heute unsichtbar auf Creme, Inventar 3.2).
- **Hell und dunkel:** alle Schritte folgen der Systemdarstellung; es gibt keine fest helle oder fest dunkle Seite mehr.

### 2.3 Große Schrift und 320 pt

- **Aktionsleiste fest oder im Fluss:** Die Leiste bleibt unten angeheftet, solange sie höchstens 25 % der Bildschirmhöhe belegt. Wird sie höher (AX-Größen, iPhone SE mit Anzeigezoom 320 × 568 pt), wandert die Hauptaktion ans Ende des Inhalts und scrollt mit. So bleiben auf dem SE mit AX5 mindestens drei Viertel der Höhe für Inhalt.
- **"Überspringen" ab AX1 und bei schmaler Breite:** Ab AX1 oder wenn die Kapsel bei 320 pt nicht neben Zurück (44 pt) und Fortschrittslinie (96 pt) passt, wandert "Überspringen" aus der oberen Leiste als schlichter Knopf (`AppButton` schlicht, 44-pt-Ziel) unter die Hauptaktion und wächst dort mit der Schrift. Die obere Leiste trägt dann nur Zurück und Linie (1 Glas-View). Grund: Eine Glas-Kapsel mit "Überspringen" in AX2 (33 pt) ist allein rund 200 pt breit und würde abgeschnitten. Die Fortschrittslinie bleibt 3 pt hoch.
- **Ab AX3** stapeln alle Zeilen dieses Bereichs: führende Symbole entfallen, Schalter und Werte rutschen unter den Titel (linksbündig). Grund: Bei 320 pt und AX5 (Body 53 pt) passt ein Wort wie "Gesundheit" sonst nicht neben einen Schalter.
- **Lange Wörter:** Titel und Sektionstitel enthalten deutsche Wörter, die bei AX5 auf 288 pt nicht in eine Zeile passen ("Unverträglichkeiten" in `headline` bei AX5 ist rund 500 pt breit). Die Übersetzungen setzen dafür weiche Trennstellen (U+00AD, im Text hier als "|" dargestellt: "Unverträg|lichkeiten", "Ernäh|rung", "Nachtschatten|gewächse"). Im Spike prüfen, ob Flutter sie als Trennstrich zeichnet; sonst bricht das Wort ohne Strich um. Es wird nie abgeschnitten und nie verkleinert.
- Kein Text hat eine feste Höhe; alle Felder wachsen mit (00 6.2). Die Prüfmatrix 00 14.3 gilt für jeden Schritt.

### 2.4 Barrierefreiheit

- VoiceOver-Reihenfolge: Zurück, Fortschritt ("Schritt 3 von 6"), Titel (Überschrift), Satz, Inhalte, Hauptaktion, Überspringen zuletzt (egal ob oben oder unter der Hauptaktion, 2.3).
- Beim Erscheinen eines Schritts springt der Fokus auf den Titel.
- Zwei-Finger-Z geht einen Schritt zurück, nach dem Konto aber nie vor Name (2.2).
- Chips und Auswahlzeilen sind Tasten mit Zustand "ausgewählt" (heute ohne Semantik, Inventar 3.2).

---

## 3. Erster Start: die Schritte

### 3.1 Start (Launch bis erster Frame)

**Zweck:** keine Hauptfrage; überbrückt ohne Farbsprung.

**Wann:** jeder Kaltstart.

**Aufbau:** nativer `LaunchScreen.storyboard` nur in `systemGroupedBackground` (#F2F2F7 hell, #000000 dunkel), ohne Bild. Der erste Flutter-Frame liegt immer auf `bgGrouped` (00 13): ohne Sitzung Willkommen, mit Sitzung Tab Liste aus dem lokalen Stand. Launch und erster Frame sind damit in beiden Fällen farbgleich. (00 3.5 nennt `systemBackground`, das ist hell #FFFFFF und würde zum Tab Liste auf #F2F2F7 springen; Korrektur in 9.10.)

**Zustände:** Die Entscheidung "Onboarding oder Tab Liste" fällt vor `runApp` aus SharedPreferences und der gespeicherten Sitzung (ein Cache für das Flag statt heute zwei, Inventar Bug 18). Kein Spinner, kein Zwischenbild.

**Bewegung:** keine. Text und Knöpfe von Willkommen stehen ab dem ersten Frame; nur das Maskottchen winkt einmal (3.2).

**Änderung gegenüber heute:** heute springt es von Systemweiß bzw. Schwarz auf Creme `#F7F3EC`. Betroffen: `ios/Runner/Base.lproj/LaunchScreen.storyboard` (Hintergrund auf `systemGroupedBackgroundColor`), `LaunchImage.imageset` (entfällt), `lib/main.dart`, `lib/routes/app_router.dart` (Redirect), `onboarding_screen.dart` (`_onboardingCompleteCache` entfällt).

**Bildbeschreibung für ChatGPT:** Kein eigenes Bild nötig; der Launch-Screen ist eine leere hellgraue Fläche (#F2F2F7) im Hellmodus bzw. rein schwarz (#000000) im Dunkelmodus, ohne Logo, ohne Text, ohne Ladeanzeige.

---

### 3.2 Willkommen (`/onboarding`, Variante `/welcome`)

**Zweck:** Hauptfrage "Fange ich neu an oder habe ich schon ein Konto?" Der einzige Ort mit Begrüßung (01 5.2).

**Wann:** erster Start ohne Sitzung; nach dem Abmelden (`/welcome`); jeder private Link ohne Sitzung.

**Aufbau von oben nach unten** (Hintergrund `bgGrouped`, kein Rahmen aus 2, keine obere Leiste):
1. Flexibler Freiraum oben (mindestens 48 pt), damit der Block optisch knapp über der Mitte steht.
2. `Mascot(pose: winkend, size: 160)`, zentriert, dekorativ (Stil des Maskottchens: F-17-11).
3. 24 pt Abstand, "{app}" in `largeTitle`, zentriert.
4. 8 pt Abstand, ein Satz in `body`, `label`, zentriert, maximale Textbreite 300 pt (damit der Satz bei 393 pt in zwei ruhigen Zeilen steht statt in einer langen). Text legt der Owner fest; Vorschlag: "Einkaufsliste und Rezepte, die mitdenken."
5. Nur bei Einladung: 24 pt darunter eine `InsetSection` mit einer Zeile (5.1).
6. Flexibler Freiraum.
7. Unten: `AppButton` prominent "Los geht's"; 8 pt darunter `AppButton` schlicht "Ich habe schon ein Konto" (Trefferfläche 44).

**Beispielinhalt:** "Avo" · "Einkaufsliste und Rezepte, die mitdenken." · "Los geht's" · "Ich habe schon ein Konto".

**Variante `/welcome` (Gerät kennt das Onboarding schon, z. B. nach dem Abmelden):** gleiche Seite, Hauptaktion "Anmelden" (führt zu 4.1), schlicht "Neues Konto anlegen" (führt in den vollen Ablauf ab Module mit Standardwerten). Werte des abgemeldeten Kontos (Module, Postleitzahl, Märkte) werden nicht übernommen: Ein zweites Konto auf demselben iPhone gehört oft einer anderen Person, und die Postleitzahl ist eine persönliche Angabe.

**Zustände:**
- Erster Start: wie beschrieben.
- Lädt: nichts zu laden; alles lokal.
- Fehler: keiner möglich.
- Offline: gleich; der Ablauf funktioniert bis zum Schritt Konto offline.
- Modul aus, Pro gesperrt: nicht relevant.
- Ausstehender Link (Einladung, Rezept): Zeile unter dem Satz (5.1, 5.2).

**Interaktionen, Bewegung, Haptik:** Das Maskottchen winkt einmal beim Erscheinen (höchstens 1 s, Rive oder Vektor-Animation, 00 3.3), danach steht es still. Titel, Satz und Knöpfe stehen ab dem ersten Frame und sind sofort bedienbar (kein gestaffeltes Einblenden, das den ersten Tipp verzögert). Knöpfe zeigen den Druckzustand beim Berühren (0,97, `springQuick`). "Los geht's" pusht Module. Keine Haptik. Reduce Motion: Maskottchen statisch.

**Große Schrift und 320 pt:** Alles steht in einem Scrollbereich; die Knöpfe stehen am Ende des Inhalts, nicht fest unten, sobald der Inhalt die Höhe überschreitet. Maskottchen ab AX1 96 pt, ab AX3 entfällt es. Bei 320 pt bleibt die Textbreite 288 pt; der Satz bricht um.

**Barrierefreiheit:** Maskottchen ausgeblendet; Titel als Überschrift; Fokus beim Start auf dem Titel.

**Änderung gegenüber heute:** Die drei Feature-Seiten und `WelcomeScreen` werden zu diesem einen Screen. Avo statt Blatt-Icon, "{app}" statt "Willkommen bei Shoply", kein Kicker, keine Serife, kein Creme, hell und dunkel, und neu der Weg "Ich habe schon ein Konto" (heute fehlt er im Onboarding). Betroffen: `onboarding_screen.dart` (Seiten 1 bis 3 und die drei Illustrationen entfallen), `auth/welcome_screen.dart` (wird Variante dieses Screens), `core/mascot/avo_mascot.dart` (durch `Mascot`), Texte `onb_*`, `welcome_*`.

**Bildbeschreibung für ChatGPT:** Hochformat-Screenshot eines iPhone 16 (393 × 852 pt) im Hellmodus, iOS 27, ruhiger hellgrauer Hintergrund #F2F2F7, oben die normale Statusleiste mit schwarzen Symbolen. Etwas über der Mitte steht ein flach gezeichnetes Avocado-Maskottchen (eine aufgeschnittene Avocado-Hälfte mit braunem Kern #7A4A24, hellgrünem Fruchtfleisch #C9DE6E, dunkelgrüner Schale #3F7A1F, kurzen Ärmchen, freundlichem Gesicht), das mit einem Arm winkt, etwa 160 pt hoch, in zwei Tonstufen ohne Glanz. Darunter zentriert der Name "Avo" in SF Pro Bold 34 pt in Schwarz #000000, darunter in SF Pro Regular 17 pt Schwarz der Satz "Einkaufsliste und Rezepte, die mitdenken." Unten, 16 pt vom Rand, eine volle breite grüne Kapsel #3F7A1F, 50 pt hoch, mit weißem Text "Los geht's" in SF Pro Semibold 17 pt. Darunter ohne Fläche der grüne Text "Ich habe schon ein Konto" #3F7A1F. Keine Navigationsleiste, keine Tab-Bar, keine Großbuchstaben, keine Verläufe, viel ruhiger Freiraum. (Zweite Variante für den Vergleich nach F-17-11: statt der flachen Zeichnung die vorhandene glänzende 3D-Avocado-Figur mit Armen und Beinen, winkend, gleiche Größe und Position.)

---

### 3.3 Module "Was brauchst du?" (`/onboarding?step=modules`)

**Zweck:** Hauptfrage "Welche Bereiche will ich in der App sehen?" (Plan 1, Liste 5).

**Wann:** nach "Los geht's".

**Aufbau** (Rahmen 2):
1. Titel "Was brauchst du?" (`title1`).
2. Satz: "Liste und Rezepte sind immer dabei. Alles andere schaltest du hier ein oder aus." (`body`, `label`).
3. `InsetSection` ohne Titel mit je einer `ToggleRow` pro Modul (Symbol 17 pt `labelSecondary`, Titel `body`, Unterzeile `subheadline` `labelSecondary` mit einem Satz Nutzen, Schalter rechts, die ganze Zeile schaltet). Reihenfolge und Standard nach F-04:

| Zeile | Symbol | Unterzeile (Nutzen) | Standard |
|---|---|---|---|
| Preise & Angebote | `tag` | "Angebote deines Markts direkt an deiner Liste." | an |
| Wochenplan | `calendar` | "Rezepte auf die Woche verteilen, Zutaten auf die Liste." | an |
| Avo | `avo.core` | "Fragen oder sprechen, Avo erledigt es in der App." | an |
| Kalorien & Gesundheit | `flame` | "Essen per Foto oder Barcode eintragen, mit Apple Health." | aus |
| Kosten teilen | `eurosign.circle` | "Festhalten, wer wem wie viel schuldet." | aus |

Die Unterzeilen sind bewusst kurz (unter 60 Zeichen), damit sie bei 320 pt und Textgröße L in höchstens zwei Zeilen stehen.

4. Sektionsfuß (`footnote`, `labelSecondary`), dynamisch: "Deine Tabs: Liste, Rezepte, Plan. Ändern kannst du das jederzeit in den Einstellungen unter Module." Die Aufzählung folgt den Schaltern sofort (der Satz wechselt ohne Bewegung, damit nichts unter dem Finger springt); sie zeigt die Folge der Wahl, ohne eine nachgemachte Tab-Bar zu zeichnen (die könnte man für bedienbar halten).
5. Zweiter Fußsatz, immer sichtbar (die KI-Sortierung gehört zum Kern und läuft auch ohne Avo): "Das Sortieren nach Kategorien und Avo nutzen KI von Anthropic (Claude). Dafür gehen Artikelnamen und deine Fragen an Anthropic. Mehr unter Datenschutz." Mit Avo aus: "Das Sortieren nach Kategorien nutzt KI von Anthropic (Claude). Dafür gehen Artikelnamen an Anthropic. Mehr unter Datenschutz." "Datenschutz" ist ein schlichter Link, der die Datenschutz-Seite als Push öffnet (Responsibility; Einwilligungsfrage F-17-03).
6. Hauptaktion "Weiter".

**Beispielinhalt:** Lena lässt Angebote, Wochenplan und Avo an und schaltet Kalorien ein. Fußzeile: "Deine Tabs: Liste, Rezepte, Plan, Kalorien."

**Zustände:**
- Erster Start: Standardwerte wie in der Tabelle.
- Zurück aus einem späteren Schritt: die eigene Wahl bleibt erhalten.
- Lädt, Fehler: entfallen (alles lokal).
- Offline: gleich.
- Kill-Switch Angebote aktiv: Zeile "Preise & Angebote" fehlt ohne Lücke und ohne Hinweis (00 15.3); der Schritt Region entfällt.
- Modul mit Status `hidden` (Halbfertiges): Zeile fehlt (00 15.2).
- Pro gesperrt: **keine** `ProBadge` im Onboarding (00 16.5). Ist ein Modul später ganz oder teilweise Pro, wird es trotzdem eingeschaltet; die Pro-Grenze zeigt sich erst am Ort als echte Vorschau.
- Alle Module aus: gültig; Fußzeile "Deine Tabs: Liste, Rezepte."

**Interaktionen, Bewegung, Haptik:** Schalter mit `springQuick`, ganze Zeile tippbar, keine Haptik. "Überspringen" übernimmt die Standardwerte und geht weiter.

**Große Schrift und 320 pt:** ab AX3 gestapelt: Symbol entfällt, Titel und Satz über volle Breite, Schalter darunter linksbündig (2.3). Die Unterzeilen brechen um, nie gekürzt. Rechnung bei 320 pt und L: 288 pt Sektion minus 32 Innenabstand, 29 Symbol mit Abstand, 63 Schalter mit Abstand ergibt rund 164 pt Text, also etwa 22 Zeichen pro Zeile in `subheadline`; jede Unterzeile braucht damit höchstens drei Zeilen, die meisten zwei.

**Änderung gegenüber heute:** neu. Ersetzt die Seiten "Was bringt dich zu uns?" (K-22) und "Auch Kalorien tracken?". Schreibt über `moduleEnabledProvider` (Vertrag 1). Was heute `users.app_priorities` liest (Reihenfolge der Startseiten-Hinweise, Avo-Chat-Vorschläge, Rezept-Personalisierung, Avo-Kontext, Einstellungsseite "Was dir wichtig ist"), liest künftig die Modul-Schalter und die Ernährung; die Einstellungsseite entfällt (01 5.8, K-22). Alte Werte bleiben ungelesen in der Datenbank (F-14). Betroffen: `onboarding_screen.dart` (`_CalorieOptInPage` entfällt), `widgets/onboarding_priorities_page.dart` (entfällt), `core/constants/app_priorities.dart` (wird nicht mehr gelesen, F-14), `calorie_tracking_provider.dart` (B stellt um), `onboarding_answers_service.dart`. Die Einstellungsseite Module (Kap. 18) nutzt dieselben Zeilen und Texte (9.5).

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus, Hintergrund hellgrau #F2F2F7. Oben links ein runder, gläserner Zurück-Knopf mit Chevron, oben rechts eine gläserne Text-Kapsel "Überspringen", dazwischen zentriert eine dünne Fortschrittslinie (96 pt breit, Spur #E9E9EE, ein Sechstel schwarz #000000 gefüllt). Darunter linksbündig der Titel "Was brauchst du?" in SF Pro Bold 28 pt Schwarz und der Satz "Liste und Rezepte sind immer dabei. Alles andere schaltest du hier ein oder aus." in 17 pt Schwarz. Darunter eine weiße Sektion #FFFFFF mit 26 pt Eckenradius und fünf Zeilen, getrennt durch eingerückte Haarlinien #C6C6C8: je ein frei stehendes graues SF Symbol #636366 (Preisschild, Kalender, ein kleines Kreis-Symbol mit Ring, Flamme, Euro-Kreis), Titel in 17 pt Schwarz, darunter ein grauer Satz #636366 in 15 pt: "Preise & Angebote" / "Angebote deines Markts direkt an deiner Liste.", "Wochenplan" / "Rezepte auf die Woche verteilen, Zutaten auf die Liste.", "Avo" / "Fragen oder sprechen, Avo erledigt es in der App.", "Kalorien & Gesundheit" / "Essen per Foto oder Barcode eintragen, mit Apple Health.", "Kosten teilen" / "Festhalten, wer wem wie viel schuldet."; rechts je ein iOS-Schalter, die ersten vier grün #3F7A1F eingeschaltet, "Kosten teilen" grau aus. Unter der Sektion in grauem 13-pt-Text #636366 "Deine Tabs: Liste, Rezepte, Plan, Kalorien. Ändern kannst du das jederzeit in den Einstellungen unter Module." und darunter "Das Sortieren nach Kategorien und Avo nutzen KI von Anthropic (Claude). …" mit grünem Link "Datenschutz". Unten eine volle breite grüne Kapsel #3F7A1F mit weißem "Weiter". Keine Icons in farbigen Quadraten, keine Karten-Reihen.

---

### 3.4 Angebote in deiner Region (`/onboarding?step=region`, Slot `OffersSetupStep`, Teil B)

**Zweck:** Hauptfrage "Für welche Region und welche Märkte soll ich Angebote sehen?" (Liste 5 und 6d).

**Wann:** nach Module, nur wenn Preise & Angebote an ist und der Kill-Switch aus ist.

**Aufteilung:** Teil A baut den Rahmen (2), Titel, Satz und Aktionsleiste; Teil B liefert den Inhalt als `OffersSetupStep(onDone:)` und meldet über `onDone` "fertig" oder "übersprungen". Ist der Kill-Switch aktiv, rendert B `SizedBox.shrink()` und A überspringt den Schritt ohne Spur.

**Aufbau:**
1. Titel "Angebote in deiner Region".
2. Satz: "Du siehst nur Angebote der Märkte, in denen du einkaufst. Dafür brauchen wir deine Region."
3. Sektion "Region" (`InsetSection`):
   - Zeile als Knopf: `location` + "Standort verwenden", Unterzeile "Einmalig, um Region und Märkte in der Nähe zu finden. Gespeichert wird nur die Postleitzahl." Das ist die Vorab-Erklärung am Ort; der Tipp löst direkt die Systemabfrage aus (kein eigenes Sheet, Owner-Regel).
   - Zeile mit Feld: "Postleitzahl" links, Zahlenfeld rechts (`number`, Platzhalter "z. B. 10437", Zifferntastatur, 5 Stellen, `AutofillHints.postalCode`).
   - Nach erkannter Region erscheint unter dem Feld die Ortszeile (`subheadline`, `labelSecondary`): "10437 Berlin".
4. Sektion "Deine Märkte" mit Satz im Sektionsfuß "Wähle, wo du meistens einkaufst. Mehrere sind möglich.": Markt-Chips im `Wrap` (wählbare Variante von `StoreChip`, 9.4): Punkt in Markenfarbe, Name, gewählt mit `actionFill` und `checkmark`. Ohne Standort in fester Reihenfolge Lidl, Aldi, REWE, Edeka, Kaufland, Netto, PENNY; mit PLZ wird "Aldi" zu "Aldi Nord" bzw. "Aldi Süd". Mit Standort stehen die nächsten Märkte vorn mit Entfernung in `caption1`: "Lidl · 400 m".
5. Sektionsfuß (`footnote`, `labelSecondary`): "Angebote stammen aus Prospekten der Händler. Preise laut Händler, ohne Gewähr."
6. Hauptaktion "Weiter".

**Beispielinhalt:** Lena tippt "Standort verwenden", erlaubt "Beim Verwenden der App". Ortszeile "10437 Berlin". Chips: "Lidl · 400 m" (gewählt), "REWE · 650 m" (gewählt), "Aldi Nord · 900 m", "Edeka · 1,2 km", "Netto · 1,4 km", "Kaufland", "PENNY".

**Zustände:**
- Erster Start: Feld leer, Chips in Standardreihenfolge, nichts gewählt.
- Lädt: Standort wird ermittelt; die Zeile "Standort verwenden" zeigt rechts den kleinen Fortschrittsindikator am Auslöser, Text bleibt; Chips bleiben bedienbar. Ortsname nach PLZ: sofort aus einer gebündelten PLZ-Tabelle (offline), sonst nur "PLZ 10437".
- Fehler: Standort nicht ermittelbar: `StatusRow` "Standort gerade nicht verfügbar. Gib deine Postleitzahl ein." Ungültige PLZ (nicht 5 Ziffern oder unbekannt): Zeile unter dem Feld in `footnote` mit `exclamationmark.circle` in `danger`: "Diese Postleitzahl kennen wir nicht."
- Standort abgelehnt: Zeile wird zu `StatusRow` "Standort ist aus. Gib deine Postleitzahl ein oder erlaube ihn in den Einstellungen." mit schlichter Aktion "Einstellungen".
- Ungefährer Standort (iOS-Schalter "Genauer Standort" aus): Region und Postleitzahl werden erkannt, die Chips bleiben in Standardreihenfolge ohne Entfernungen. Kein Hinweis und keine zweite Abfrage; für die Region reicht der ungefähre Standort.
- Offline: PLZ und Märkte gehen (lokale Tabelle); Entfernungen fehlen; kein Hinweis nötig.
- Modul aus oder Kill-Switch: Schritt entfällt.
- Pro: Angebote sind nie Pro (00 16).
- Übersprungen oder ohne Region: keine Ersparnis-Zahlen in der App; später Hinweis-Zeile "Für Angebote in deiner Region: Postleitzahl festlegen" (00 3.2).

**Interaktionen, Bewegung, Haptik:** Chips mit `springQuick`; die Chip-Reihe sortiert sich nach erkanntem Standort einmal um (`springStandard`), solange noch kein Chip gewählt ist, danach nie wieder (kein Springen unter dem Finger). Keine Haptik.

**Große Schrift und 320 pt:** Feld und Beschriftung stapeln ab AX1 (Beschriftung über dem Feld). Chips brechen um; Markt-Punkt wächst bis AX2. Bei 320 pt und Textgröße L stehen zwei bis drei Chips pro Zeile (ein gewählter Chip mit Häkchen und Entfernung wie "Lidl · 400 m" ist rund 120 pt breit); ab AX3 steht jeder Chip in einer eigenen Zeile.

**Änderung gegenüber heute:** neu im Onboarding. Ersetzt `showZipCodeSheet` an dieser Stelle; die PLZ wandert aus Persönliche Daten zu Preise & Angebote (01 4). Fallback-PLZ 10115 entfällt als stille Annahme (Liste 6a). Betroffen (B): `lists/widgets/zip_code_sheet.dart`, `store_locator_service.dart`, `offer_price_service.dart`; neu `OffersSetupStep` im B-Ordner `widgets/deals/`.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus, Hintergrund #F2F2F7, oben gläserner Zurück-Knopf, Fortschrittslinie zu zwei Siebteln schwarz, gläserne Kapsel "Überspringen". Titel "Angebote in deiner Region" in SF Pro Bold 28 pt Schwarz, darunter der Satz "Du siehst nur Angebote der Märkte, in denen du einkaufst. Dafür brauchen wir deine Region." in 17 pt Schwarz. Eine weiße Sektion #FFFFFF (Radius 26 pt) mit zwei Zeilen: oben ein grünes Standort-Pfeil-Symbol #3F7A1F und grüner Text "Standort verwenden" mit grauer Unterzeile #636366, darunter "Postleitzahl" links und rechts die Zahl "10437", unter der Sektion grau "10437 Berlin". Darunter der Sektionstitel "Deine Märkte" in 17 pt Semibold und eine umbrechende Reihe hellgrauer Kapseln #E9E9EE, jede mit einem 8-pt-Farbpunkt und Namen: "Lidl · 400 m" (blauer Punkt #0050AA) und "REWE · 650 m" (roter Punkt #CC071E) sind gewählt, hellgrün hinterlegt #EEF5E4 mit grünem Häkchen und grünem Text #3F7A1F; ungewählt "Aldi Nord · 900 m" (Punkt #00549F), "Edeka · 1,2 km" (gelber Punkt #FFD400 mit feiner grauer Kontur #C6C6C8), "Netto · 1,4 km" (gelber Punkt #FFE500 mit feiner grauer Kontur #C6C6C8), "Kaufland" (#E10915), "PENNY" (#CD1414); Entfernungen in 12 pt Grau #636366. Unten grauer Hinweis in 13 pt "Angebote stammen aus Prospekten der Händler. Preise laut Händler, ohne Gewähr." und die grüne Kapsel "Weiter". Keine echten Supermarkt-Logos.

---

### 3.5 Konto (`/onboarding?step=account`)

**Zweck:** Hauptfrage "Womit melde ich mich an?" Der einzige Pflichtschritt.

**Wann:** nach Module bzw. Region; als Variante "Anmelden" aus Willkommen (4.1).

**Aufbau** (Rahmen 2, ohne "Überspringen"):
1. Titel "Konto anlegen".
2. Satz: "Damit deine Listen auf allen Geräten da sind und du sie mit anderen teilen kannst. Hast du schon ein Konto, meldest du dich hier genauso an."
3. Drei Knöpfe untereinander, volle Breite, je mindestens 50 pt hoch, 12 pt Abstand:
   - **"Mit Apple fortfahren":** der Systemknopf `ASAuthorizationAppleIDButton` (Typ "Fortfahren"), Stil schwarz im Hellmodus, weiß im Dunkelmodus, Ecken als Kapsel. Nur iOS.
   - **"Mit Google fortfahren":** nach Googles Markenvorgaben: Fläche #FFFFFF mit 1 pt Kontur #747775 (hell) bzw. #131314 mit Kontur #8E918F (dunkel), Google-"G" als gebündeltes Asset (nicht aus dem Netz), Text `headline` in `label`.
   - **"Mit E-Mail fortfahren":** `AppButton` grau (`fill`) mit Symbol `envelope` (9.3), Text `headline` `label`.
4. Unter den Knöpfen `footnote` `labelSecondary`: "Mit dem Fortfahren akzeptierst du die Nutzungsbedingungen und die Datenschutzhinweise." Beide Begriffe sind schlichte Links (Trefferfläche 44 über die Zeilenhöhe) und öffnen die jeweilige Seite als Push mit Zurück im Onboarding-Navigator (kein Sheet, Owner-Regel); Zurück führt an dieselbe Stelle.
5. Keine untere Aktionsleiste; die drei Knöpfe sind die Aktionen. Es gibt hier keinen grünen prominenten Knopf (der Apple-Knopf ist die visuell stärkste Aktion).

**Beispielinhalt:** wie oben; Lena wählt "Mit Apple fortfahren", Face ID, fertig.

**Zustände:**
- Erster Start: drei Knöpfe aktiv.
- Arbeitet (Apple oder Google offen, Anmeldung läuft): der gewählte Knopf zeigt den Arbeitszustand (00 12.20: Fortschrittsindikator links statt Symbol, Breite bleibt), die beiden anderen sind deaktiviert; ein zweiter Tipp startet keinen zweiten Ablauf (Inventar Bug 7). Bis feststeht, ob das Konto neu oder eingerichtet ist, bleibt man auf diesem Screen (kein kurzes Aufblitzen von Tab Liste, Bug 8).
- Abgebrochen (Apple- oder Google-Blatt geschlossen): nichts passiert, keine Meldung.
- Fehler: `StatusRow` über den Knöpfen, ein Satz, mit "Erneut versuchen" (Texte in 4.6). Fehler-Haptik.
- Offline: `StatusRow` "Offline. Zum Anmelden brauchst du eine Verbindung. Deine Auswahl bleibt gespeichert." Knöpfe bleiben sichtbar; ein Tipp zeigt dieselbe Zeile erneut (kurzes Hervorheben, kein Dialog).
- Modul aus, Pro: nicht relevant.
- Nach der Anmeldung: Der Knopf bleibt im Arbeitszustand, bis `apply_onboarding` `new` oder `existing` meldet (meist unter 1 s). Erst dann geht es weiter, damit nie der falsche nächste Screen aufblitzt.
- Erfolg, neues Konto: weiter zu Name.
- Erfolg, eingerichtetes Konto: weiter zu Tab Liste (5.3).
- Anmeldung gelingt, aber `apply_onboarding` scheitert (Netz bricht ab): `StatusRow` "Deine Auswahl ist noch nicht gespeichert. Erneut versuchen"; die Anmeldung bleibt bestehen, ein zweiter Tipp ruft nur `apply_onboarding` erneut auf.

**Interaktionen, Bewegung, Haptik:** Knöpfe mit Druckzustand (0,97, `springQuick`). Erfolg ohne eigene Haptik (der nächste Schritt ist die Rückmeldung). Fehler-Haptik bei Fehlschlag.

**Große Schrift und 320 pt:** Der Apple-Systemknopf skaliert seinen Text nur begrenzt; er bekommt die Höhe aus der Zeilenhöhe von `headline` (mindestens 50) und volle Breite. Google- und E-Mail-Knopf brechen ab AX3 auf zwei Zeilen um, Symbol oben bündig zur ersten Zeile; nie Ellipse (heute wird "Mit Google fortfahren" bei 320 pt gekürzt). Alles scrollt.

**Änderung gegenüber heute:** ein Schritt statt `WelcomeScreen` plus `SignUpScreen` plus `LoginScreen`. Systemknopf statt selbstgebauter Outline mit Material-Apple-Icon; Apple steht jetzt an jeder Anmeldestelle (heute fehlt er auf Login und Signup). Google-Logo gebündelt statt `Image.network` (Datenschutz, Bug 12). Fehler als `StatusRow` statt `AlertDialog` "Hinweis". Betroffen: `auth/welcome_screen.dart`, `auth/social_auth.dart` (`routeAfterSignIn` entfällt, Entscheidung über `apply_onboarding`), `auth/widgets/google_logo.dart` (Asset), `auth/auth_errors.dart`, `data/services/supabase_service.dart` (Apple mit Nonce, `fullName` speichern, Fehler als Codes).

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus, Hintergrund #F2F2F7, oben links gläserner Zurück-Knopf, Mitte Fortschrittslinie zu drei Siebteln schwarz, rechts nichts. Titel "Konto anlegen" in SF Pro Bold 28 pt Schwarz, darunter in 17 pt Schwarz "Damit deine Listen auf allen Geräten da sind und du sie mit anderen teilen kannst. Hast du schon ein Konto, meldest du dich hier genauso an." Darunter drei volle breite Kapseln, je 50 pt hoch, 12 pt Abstand: zuerst der schwarze offizielle "Mit Apple fortfahren"-Knopf mit weißem Apple-Logo und weißem Text, dann eine weiße Kapsel mit feiner grauer Kontur #747775, buntem Google-"G" und schwarzem Text "Mit Google fortfahren", dann eine hellgraue Kapsel #E9E9EE mit Briefumschlag-Symbol und schwarzem Text "Mit E-Mail fortfahren". Darunter in grauem 13-pt-Text #636366 "Mit dem Fortfahren akzeptierst du die Nutzungsbedingungen und die Datenschutzhinweise.", wobei "Nutzungsbedingungen" und "Datenschutzhinweise" grün #3F7A1F sind. Kein grüner Hauptknopf, kein Maskottchen.

---

### 3.6 E-Mail-Adresse (`/onboarding?step=email`, Alias `/signup`)

**Zweck:** Hauptfrage "An welche Adresse schicken wir den Code?"

**Wann:** "Mit E-Mail fortfahren" im Schritt Konto oder in Anmelden (4.1).

**Aufbau** (Rahmen 2, ohne "Überspringen"):
1. Titel "Deine E-Mail-Adresse".
2. Satz: "Wir schicken dir einen 6-stelligen Code. Ein Passwort brauchst du dafür nicht."
3. Feld als Kapsel `fill`, `body`, Platzhalter "name@beispiel.de", Tastatur E-Mail, `AutofillHints.email` und `username`, keine Autokorrektur, Kleinschreibung.
4. Hauptaktion "Code senden".
5. Unter der Hauptaktion schlicht "Mit Passwort anmelden" (für Bestandskonten mit Passwort, 4.2).

**Beispielinhalt:** "lena.berger@posteo.de".

**Zustände:**
- Leer: "Code senden" deaktiviert, bis die Eingabe die Form einer Adresse hat (Ausnahme von 2.2, weil ohne Adresse nichts passieren kann).
- Arbeitet: "Code senden" im Arbeitszustand, Feld bleibt editierbar.
- Fehler: ungültige Adresse (Server): Zeile unter dem Feld `footnote` in `danger` mit Symbol "Diese E-Mail-Adresse sieht nicht richtig aus." Zu viele Versuche: `StatusRow` "Zu viele Versuche. Bitte warte eine Minute." Fehler-Haptik.
- Offline: `StatusRow` "Offline. Zum Senden des Codes brauchst du eine Verbindung."
- Konto existiert mit Apple oder Google: kein Fehler; der Code meldet auch dort an, sofern Supabase die Identitäten verknüpft (F-17-05).

**Interaktionen:** Return sendet. Erfolg pusht Code.

**Große Schrift und 320 pt:** Feld wächst in der Höhe mit (00 6.2), lange Adressen scrollen im Feld waagerecht.

**Änderung gegenüber heute:** Registrierung ohne Pflicht-Passwort (heute E-Mail, Passwort, Bestätigung, dann Code). Das Passwort wird optional und lässt sich später unter Einstellungen > Konto festlegen (F-17-01). Supabase `signInWithOtp(shouldCreateUser: true)` mit E-Mail-Vorlage, die den Code (`{{ .Token }}`) statt nur eines Links enthält. Betroffen: `auth/signup_screen.dart` (wird dieser Schritt), `supabase_service.dart`, `core/utils/validators.dart` (Passwortregeln wandern zu 4.4).

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus mit offener deutscher iOS-Tastatur (E-Mail-Layout mit @-Taste) in der unteren Hälfte. Hintergrund #F2F2F7, oben gläserner Zurück-Knopf und die Fortschrittslinie zu drei Siebteln schwarz. Titel "Deine E-Mail-Adresse" in SF Pro Bold 28 pt Schwarz, darunter "Wir schicken dir einen 6-stelligen Code. Ein Passwort brauchst du dafür nicht." in 17 pt Schwarz. Darunter eine hellgraue Eingabe-Kapsel #E9E9EE, darin in Schwarz "lena.berger@posteo.de" mit Cursor. Direkt über der Tastatur eine volle breite grüne Kapsel #3F7A1F mit weißem Text "Code senden", darunter grüner Text ohne Fläche "Mit Passwort anmelden".

---

### 3.7 Code eingeben (`/onboarding?step=code`)

**Zweck:** Hauptfrage "Wie lautet der Code aus der E-Mail?"

**Wann:** nach "Code senden" (Anmelden, Registrieren und Passwort vergessen nutzen denselben Screen mit anderem Titel).

**Aufbau** (Rahmen 2, ohne "Überspringen"):
1. Titel "Code eingeben" (Variante Passwort: "Code zum Zurücksetzen").
2. Satz: "Wir haben ihn an lena.berger@posteo.de geschickt." Die Adresse ist ein schlichter Link "Ändern" dahinter (geht zurück zu 3.6).
3. Codefeld: eine Kapsel `fill`, Ziffern in `numberL` mit tabellarischen Ziffern und Laufweite 0, zentriert, Platzhalter "000000" in `labelSecondary`, Zifferntastatur, `AutofillHints.oneTimeCode` (iOS schlägt den Code aus Mail vor). Bei 6 Ziffern wird automatisch geprüft.
4. Sektionsfuß `footnote` `labelSecondary`: "Keine E-Mail da? Schau im Spam-Ordner nach."
5. Schlicht "Neuen Code senden"; 60 s nach dem Senden deaktiviert mit "Neuer Code in 0:48" (Sekunden wechseln, sie rollen nicht, 00 12.15). 60 s entsprechen der Sperrzeit von Supabase zwischen zwei Codes an dieselbe Adresse; ein früherer Tipp würde nur "Zu viele Versuche" auslösen.
6. Keine Hauptaktion nötig; ab 6 Ziffern prüft der Screen selbst. Für VoiceOver und Sprachsteuerung zusätzlich prominent "Bestätigen" in der Aktionsleiste, aktiv ab 6 Ziffern.

**Beispielinhalt:** Code "482 913" aus der Mail-Vorschlagsleiste.

**Zustände:**
- Leer, tippend, prüft (Ziffern bleiben stehen, kleiner Fortschrittsindikator rechts im Feld).
- Fehler falscher Code: Feld schüttelt sich waagerecht (drei Ausschläge, `springFling`, 8 pt), Fehler-Haptik im selben Frame, Zeile darunter in `danger` mit Symbol "Der Code stimmt nicht. Prüfe ihn oder lass dir einen neuen schicken." Feld wird markiert, nicht geleert. Reduce Motion: kein Schütteln, nur Zeile und Haptik.
- Abgelaufen: "Der Code ist abgelaufen. Neuen Code senden" (Aktion direkt in der Zeile).
- Offline: `StatusRow`; Prüfung wartet, bis das Netz zurück ist, und läuft dann von selbst.
- Erfolg: neues Konto weiter zu Name; eingerichtetes Konto zu Tab Liste; Passwort-Variante zu 4.4.

**Große Schrift und 320 pt:** eine Kapsel über die volle Breite statt sechs Einzelkästchen, damit auch bei 320 pt und AX5 (`numberL` bis 56 pt) sechs Ziffern in eine Zeile passen (6 × etwa 34 pt bei AX5 = 204 pt von 288 pt).

**Änderung gegenüber heute:** eigener Push-Schritt statt Zustandswechsel im selben Screen (heute verlässt Zurück-Wischen den ganzen Screen, Inventar 3.2). Autofill für den Code, Schütteln statt roter Snackbar. Betroffen: `auth/widgets/otp_verification_view.dart`, `login_screen.dart`, `signup_screen.dart`.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus mit offener Zifferntastatur, über der die iOS-Vorschlagsleiste "Aus Mail: 482913" zeigt. Hintergrund #F2F2F7, oben gläserner Zurück-Knopf und Fortschrittslinie. Titel "Code eingeben" in SF Pro Bold 28 pt Schwarz, darunter "Wir haben ihn an lena.berger@posteo.de geschickt." in 17 pt Schwarz mit grünem Link "Ändern" #3F7A1F. Darunter eine breite hellgraue Kapsel #E9E9EE mit den Ziffern "482 9" in SF Pro Rounded Semibold 22 pt Schwarz, gefolgt von zwei grauen Platzhalter-Nullen #636366. Darunter grauer 13-pt-Text #636366 "Keine E-Mail da? Schau im Spam-Ordner nach." und hellgrauer, deaktivierter Text #AEAEB2 "Neuer Code in 0:48". Über der Tastatur eine deaktivierte hellgraue Kapsel #E9E9EE mit grauem Text #AEAEB2 "Bestätigen" (aktiv erst ab 6 Ziffern).

---

### 3.8 Name (`/onboarding?step=name`, Alias `/name-prompt?new=1`)

**Zweck:** Hauptfrage "Wie sollen andere mich in geteilten Listen sehen?"

**Wann:** nach dem Konto, nur bei neuen Konten. Erster Schritt ohne Zurück (1.1); links in der oberen Leiste steht nichts.

**Aufbau** (Rahmen 2):
1. Titel "Wie heißt du?"
2. Satz: "So sehen dich andere in geteilten Listen."
3. `Avatar` 64 pt (`avatarXL`), zentriert, Initialen live aus dem Feld ("L" bei einem Wort, "LB" bei zwei), `label` auf `fill`.
4. 16 pt darunter Feld als Kapsel `fill`, `body`, Platzhalter "Vorname", `AutofillHints.givenName`, Großschreibung am Wortanfang.
5. Hauptaktion "Weiter".

**Vorbefüllung:** nur der Vorname: von Apple (`givenName` aus `fullName`, nur bei der ersten Autorisierung geliefert, deshalb sofort vollständig gespeichert) bzw. von Google (`given_name`). Bei E-Mail leer. Nie der Teil der E-Mail vor dem @. Grund für den Vornamen: Mitteilungen und Präsenz lauten "Lena hat Milch abgehakt" (00 3.2); der Nachname wäre in geteilten Listen eine unnötige Angabe. Wer mehr will, tippt ihn ein.

**Beispielinhalt:** Feld "Lena" (von Apple), Avatar "L".

**Zustände:**
- Vorbefüllt oder leer.
- Speichern: optimistisch, sofort weiter.
- Fehler beim Speichern: im nächsten Schritt `StatusRow` "Dein Name ist noch nicht gespeichert. Erneut versuchen".
- Offline: wird in die Warteschlange gelegt.
- Übersprungen bzw. leer: andere sehen "Mitglied" und Initialen-Platzhalter `person.fill`; beim ersten Teilen fragt der Teilen-Screen den Namen erneut am Ort (Kap. 11). Behebt Inventar Bug 13 (E-Mail-Präfix sichtbar).

**Interaktionen, Bewegung:** Initialen wechseln ohne Animation mit jedem Tastendruck (wie in Kontakte; `fadeReduced` ist für Reduce Motion und Fotos reserviert, 00 10.1). Return = Weiter. Keine Haptik.

**Große Schrift und 320 pt:** Avatar bleibt 64 pt; Feld wächst mit der Schrift; mit offener Tastatur auf dem SE scrollt der Inhalt (heute `Column` mit `Spacer`, Überlauf schon bei Standardschrift).

**Änderung gegenüber heute:** kein Maskottchen und keine Sprechblase "Hey! Ich bin Avo" mehr (Maskottchen nur bei Begrüßung, Emoji entfällt), Vorbefüllung neu, scrollbar, hell und dunkel aus Tokens. Betroffen: `auth/name_prompt_screen.dart`, `supabase_service.dart` (Apple-Name speichern), `auth_provider.dart` (`_createUserRow` ohne E-Mail-Präfix als Name).

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Dunkelmodus mit offener deutscher Tastatur. Hintergrund reines Schwarz #000000, oben links kein Knopf (nach dem Konto gibt es kein Zurück), Mitte die Fortschrittslinie (Spur #2C2C2E, vier Siebtel weiß #FFFFFF gefüllt), rechts eine dunkle Glas-Kapsel "Überspringen" in Weiß. Titel "Wie heißt du?" in SF Pro Bold 28 pt Weiß, darunter "So sehen dich andere in geteilten Listen." in 17 pt Weiß. Zentriert ein runder Avatar von 64 pt in Dunkelgrau #2C2C2E mit der weißen Initiale "L" in Semibold, darunter eine dunkelgraue Eingabe-Kapsel #2C2C2E mit "Lena" in Weiß und Cursor. Über der Tastatur eine volle breite Kapsel in hellem Avocadogrün #A6D45F mit sehr dunklem Text "Weiter" #0E1A06.

---

### 3.9 Ernährung und Allergien (`/onboarding?step=diet`)

**Zweck:** Hauptfrage "Worauf sollen Rezepte und Avo bei mir achten?"

**Wann:** nach Name.

**Aufbau** (Rahmen 2):
1. Titel "Ernährung und Allergien".
2. Satz: "Rezepte passen sich daran an und weisen dich auf Allergene hin."
3. Sektionstitel "Ernährung" (`headline`), darunter `FilterChip`s im `Wrap` (ohne Emojis): Vegetarisch, Vegan, Pescetarisch, Low-Carb, Keto, Paleo, Halal, Koscher, Natriumarm. Die drei "frei von"-Werte (`gluten_free`, `dairy_free`, `nut_free`) erscheinen nicht doppelt hier, sondern über die Allergien (9.7).
4. Sektionstitel "Allergien und Unverträglichkeiten", Chips: Gluten, Milch, Laktose, Eier, Erdnüsse, Schalenfrüchte (Nüsse), Soja, Fisch, Krebstiere, Weichtiere, Sellerie, Senf, Sesam, Sulfite, Lupinen; danach schlicht "Weitere anzeigen" (blendet ein: Fruktose, Histamin, Nachtschattengewächse, Mais, Hefe). IDs aus `AllergyType` (`dietary_preference.dart`), Texte über die Übersetzungen statt fester deutscher Labels.
5. Sektionsfuß `footnote` `labelSecondary`: "Hinweise auf Allergene helfen, ersetzen aber nicht den Blick auf die Zutatenliste."
6. Hauptaktion "Weiter".

**Beispielinhalt:** Lena wählt "Vegetarisch" und "Erdnüsse".

**Zustände:**
- Nichts gewählt: gültig, heißt "keine Einschränkungen"; Hauptaktion heißt dann "Weiter" wie sonst (kein Druck).
- Speichern: optimistisch beim Verlassen.
- Offline: Warteschlange.
- Fehler: wie 3.8.
- Modul Avo aus: der Satz lautet trotzdem "Rezepte passen sich daran an …"; Avo wird nicht erwähnt.

**Interaktionen:** Chips mit `springQuick`, "Weitere anzeigen" blendet die Chips mit `springStandard` ein und verschwindet danach. Keine Haptik. Die Chips stehen hier immer im `Wrap`, auch unter xxL (00 12.19 sieht dort eine waagerecht scrollende Zeile vor): Es ist eine Auswahl, kein Filter, und jede Option muss ohne Wischen sichtbar sein, damit niemand eine Allergie übersieht.

**Große Schrift und 320 pt:** Chips brechen als Ganzes in die nächste Zeile um, nie waagerecht scrollend. Ab AX3 steht jeder Chip in einer eigenen Zeile. Der längste Chip ("Nachtschattengewächse") bricht ab AX3 innerhalb der Kapsel an der weichen Trennstelle um (2.3); die Kapsel wird höher und bekommt ab zwei Textzeilen den Radius `radiusCard` statt Höhe/2.

**Änderung gegenüber heute:** Allergien bekommen erstmals eine Oberfläche (heute nur Datenfeld). Titel "Isst du besonders?" und der Hinweis "Nichts ausgewählt? Dann isst du einfach alles." entfallen. Betroffen: `onboarding/widgets/onboarding_diet_page.dart`, `core/constants/diet_preferences.dart` (IDs bleiben), `data/models/dietary_preference.dart` (Emojis und feste Labels entfallen), Texte `diet_*`, neu `allergy_*`.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus, Hintergrund #F2F2F7, oben gläserner Zurück-Knopf, Fortschrittslinie zu fünf Siebteln schwarz, gläserne Kapsel "Überspringen". Titel "Ernährung und Allergien" in SF Pro Bold 28 pt Schwarz, darunter "Rezepte passen sich daran an und weisen dich auf Allergene hin." in 17 pt Schwarz. Sektionstitel "Ernährung" in 17 pt Semibold, darunter umbrechende hellgraue Kapseln #E9E9EE mit schwarzem 15-pt-Text: "Vegetarisch" ist gewählt (Fläche #EEF5E4, grünes Häkchen und grüner Text #3F7A1F), dann "Vegan", "Pescetarisch", "Low-Carb", "Keto", "Paleo", "Halal", "Koscher", "Natriumarm". Darunter "Allergien und Unverträglichkeiten" und weitere Kapseln: "Gluten", "Milch", "Laktose", "Eier", "Erdnüsse" (gewählt, grün hinterlegt), "Schalenfrüchte (Nüsse)", "Soja", "Fisch" usw., am Ende grüner Text "Weitere anzeigen". Unten grauer 13-pt-Hinweis und die grüne Kapsel "Weiter". Keine Emojis, keine bunten Kategorie-Farben.

---

### 3.10 Dein Ziel (`/onboarding?step=goal`, nur Modul Kalorien)

**Zweck:** Hauptfrage "Wie viele Kalorien am Tag passen zu meinem Ziel?"

**Wann:** nach Ernährung, nur wenn Kalorien & Gesundheit an ist.

**Aufbau** (Rahmen 2; keine Schieberegler, Owner-Regel):
1. Titel "Dein Ziel".
2. Satz: "Aus ein paar Angaben schätzen wir dein Tagesziel. Du kannst es jederzeit ändern."
3. Sektion "Ziel": vier Auswahlzeilen mit `checkmark` rechts (iOS-Einstellungsmuster): Abnehmen, Gewicht halten, Muskeln aufbauen, Eigenes Ziel. DB-Werte `lose_weight`, `maintain`, `gain_muscle`, `custom`.
4. Sektion "Über dich" (`ValueRow`s mit Wert rechts, Tippen fokussiert das Feld in der Zeile):
   - Geschlecht: Pull-down-Menü (00 12.24), das aus dem Wert rechts in der Zeile wächst, mit Weiblich, Männlich, Divers; Wert mit `chevron.up.chevron.down` 13 pt.
   - Alter: Zahlenfeld "34".
   - Größe: Zahlenfeld "168" mit Einheit "cm".
   - Gewicht: Zahlenfeld "68" mit Einheit "kg".
   - Zielgewicht (nur Abnehmen, Muskeln aufbauen): "64 kg".
   - Zeitraum (nur mit Zielgewicht): `ValueStepper` in 2-Wochen-Schritten von 4 bis 52, "16 Wochen".
   - Bei "Eigenes Ziel": statt der Körperdaten eine Zeile "Kalorien pro Tag" mit Zahlenfeld.
5. Sektion "Aktivität": fünf Auswahlzeilen mit Titel und Unterzeile ("Leicht aktiv", "1 bis 3 Einheiten pro Woche" usw.).
6. Optional, wenn das Apple-Health-Lesen von Teil B fertig ist: Zeile `heart` "Aus Apple Health übernehmen" (füllt Geburtsdatum, Größe, Gewicht; Systemabfrage erst beim Tipp). Bis dahin unsichtbar (Halbfertiges, 00 15.2).
7. **Ergebniszeile** in der Aktionsleiste über der Hauptaktion: "Etwa 1.650 kcal am Tag" (`headline`, Zahl als `RollingNumber`), darunter `subheadline` `labelSecondary` "122 g Protein · 175 g Kohlenhydrate · 51 g Fett". Sie folgt jeder Eingabe sofort (Berechnung lokal über `NutritionGoalCalculator`).
8. Sektionsfuß über der Aktionsleiste: "Schätzung nach der Mifflin-St-Jeor-Formel, kein medizinischer Rat."
9. Hauptaktion "Weiter".

**Beispielinhalt:** Abnehmen, Weiblich, 34, 168 cm, 68 kg, Ziel 64 kg, 16 Wochen, Leicht aktiv: "Etwa 1.650 kcal am Tag · 122 g Protein · 175 g Kohlenhydrate · 51 g Fett". Mit "Gewicht halten": "Etwa 1.920 kcal am Tag". Rechnung mit `NutritionGoalCalculator` (geprüft): Grundumsatz 10 × 68 + 6,25 × 168 − 5 × 34 − 161 = 1.399 kcal; × 1,375 (leicht aktiv) = 1.924 kcal; minus 4 kg × 7.700 kcal / 112 Tage = 275 kcal ergibt 1.649 kcal; Protein 1,8 g × 68 kg = 122 g, Fett 28 % = 51 g, Rest 175 g Kohlenhydrate. Die Anzeige rundet kcal auf 10 ("Etwa"), gespeichert wird der genaue Wert.

**Zustände:**
- Leer: Ergebniszeile zeigt "Gib Größe, Gewicht und Alter ein, dann siehst du dein Tagesziel." Weiter ist trotzdem aktiv; ohne Angaben wird kein Ziel gespeichert (der Kalorien-Tab zeigt dann seinen leeren Zustand "Richte dein Ziel ein", 01 5.5).
- Unplausible Werte (Inventar Bug 3): Zeile unter dem Feld in `danger` mit Symbol: Größe 100 bis 250 cm, Gewicht 30 bis 300 kg, Alter 13 bis 110 Jahre; Komma-Eingaben wie "1,68" bei Größe werden als Meter erkannt und zu "168 cm" umgerechnet, mit Hinweis "Als 168 cm übernommen".
- Unter 18 Jahren: "Abnehmen" ist deaktiviert mit Unterzeile "Für unter 18-Jährige berechnen wir kein Abnehm-Ziel." (Responsibility, F-17-04).
- Zielgewicht passt nicht zum Ziel (Abnehmen mit höherem Zielgewicht): Hinweis in `warning` mit Symbol "Das Zielgewicht liegt über deinem Gewicht."
- Sehr steiles Ziel: Der Rechner begrenzt auf mindestens 1.200 bzw. 1.500 kcal; die Ergebniszeile sagt dann "Etwa 1.200 kcal am Tag, niedriger empfehlen wir nicht."
- Divers: Berechnung mit dem Mittelwert beider Formeln (F-17-04; heute wie männlich).
- Speichern, offline, Fehler: wie 3.8.
- Modul Kalorien aus: Schritt entfällt.
- Pro: keine Kennzeichnung im Onboarding.

**Interaktionen, Bewegung, Haptik:** Auswahl mit `springQuick`; Stepper mit Auswahl-Haptik pro Schritt; Ergebnis-Zahl rollt (`springDigits`); Zeilen für Zielgewicht und Zeitraum wachsen mit `springStandard` ein, wenn das Ziel sie braucht. Reduce Motion: Überblendung.

**Große Schrift und 320 pt:** Wertzeilen stapeln ab AX1 (Beschriftung über dem Feld). Die Ergebniszeile wandert mit der Hauptaktion in den Fluss, sobald die Aktionsleiste über 25 % der Höhe belegt (2.3); dann steht zusätzlich oben unter dem Satz eine Kopie der Ergebniszeile, damit man die Wirkung beim Ändern sieht.

**Änderung gegenüber heute:** Schieberegler für den Zeitraum entfällt (Stepper); zwei Felder nebeneinander entfallen (gequetscht bei 320 pt); Ziel-Chips werden Auswahlzeilen; Ergebnis-Vorschau neu; Eingaben gehen beim Zurück-Wischen nicht verloren, weil der Zustand im `OnboardingController` liegt (Bug 2). Betroffen: `onboarding/widgets/onboarding_goal_page.dart`, `data/services/nutrition_goal_service.dart` (B, API bleibt stabil), `onboarding_answers_service.dart`.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus, Hintergrund #F2F2F7, oben gläserner Zurück-Knopf, Fortschrittslinie zu sechs Siebteln schwarz, gläserne Kapsel "Überspringen". Titel "Dein Ziel" in SF Pro Bold 28 pt Schwarz, darunter in 17 pt Schwarz "Aus ein paar Angaben schätzen wir dein Tagesziel. Du kannst es jederzeit ändern." Eine weiße Sektion #FFFFFF (Radius 26 pt) mit vier Zeilen "Abnehmen" (mit grünem Häkchen #3F7A1F rechts), "Gewicht halten", "Muskeln aufbauen", "Eigenes Ziel". Darunter die Sektion "Über dich" mit Zeilen: "Geschlecht" rechts grau #636366 "Weiblich" mit kleinem Auf-ab-Pfeil, "Alter 34", "Größe 168 cm", "Gewicht 68 kg", "Zielgewicht 64 kg", "Zeitraum" mit einer grauen Stepper-Kapsel "− 16 Wochen +". Unten über der grünen Kapsel "Weiter" #3F7A1F steht auf hellgrauem Grund "Etwa 1.650 kcal am Tag" in 17 pt Semibold Schwarz mit runden Ziffern und darunter grau #636366 "122 g Protein · 175 g Kohlenhydrate · 51 g Fett". Kein Schieberegler, kein Diagramm.

---

### 3.11 Erste Liste (`/onboarding?step=first-list`)

**Zweck:** Hauptfrage "Wie heißt meine erste Liste, und für welchen Markt ist sie?"

**Wann:** letzter Schritt bei neuen Konten ohne Einladung.

**Aufbau** (Rahmen 2):
1. Titel "Deine erste Liste".
2. Satz (Modul Angebote an): "Heißt sie wie ein Markt, sortieren wir sie nach dessen Gängen und zeigen dir dort die Angebote." Modul aus bzw. Kill-Switch: "Heißt sie wie ein Markt, sortieren wir sie nach dessen Gängen."
3. Feld als Kapsel `fill`, `body`, Platzhalter "Zum Beispiel Wocheneinkauf", Fokus beim Erscheinen.
4. Darunter **Vorschau** als `InsetSection` mit einer `ListRow` ohne Chevron: Listen-Glyph (erste freie Listenfarbe Blau, Symbol `cart`), Name live aus dem Feld, rechts der `StoreChip` des erkannten Markts. Erkennung lokal aus dem Namen über das Ketten-Verzeichnis von Teil B (Aliase, Tippfehler):
   - eindeutig ("Lidl", "REWE Wocheneinkauf"): Chip gesetzt "Lidl";
   - unsicher ("Lidel"): Chip vorgeschlagen "Lidl?" mit gestricheltem Rand; Tippen setzt ihn;
   - kein Markt: Chip "Markt wählen" (`storefront`, `labelSecondary`); Tippen öffnet ein Pull-down-Menü, das aus dem Chip wächst (`springMenu`), mit den Lieblingsmärkten aus 3.4 oben, dann allen Ketten, "Kein fester Markt". Ohne Angebots-Modul oder ohne Lieblingsmärkte nur alle Ketten und "Kein fester Markt". Ein gesetzter Chip öffnet dasselbe Menü zum Ändern.
5. Sektion "Vorschläge" (Zeilen, Tippen übernimmt in das Feld): "Wocheneinkauf", dann die gewählten Lieblingsmärkte als Namen ("Lidl", "REWE"), sonst "Lidl", dann "Drogerie". Höchstens vier.
6. Hauptaktion "Liste anlegen".

**Beispielinhalt:** Lena tippt "Lidl". Vorschau: blauer Glyph mit Einkaufswagen, "Lidl", Chip "Lidl" mit blauem Punkt #0050AA.

**Zustände:**
- Leer: "Liste anlegen" legt "Wocheneinkauf" an (Platzhalter wird zum Namen); so führt auch das schnellste Weitertippen zu einer Liste.
- Anlegen: optimistisch; die Liste existiert sofort lokal, Abgleich im Hintergrund.
- Offline: Liste wird lokal angelegt und mit Sync-Zeichen gezeigt.
- Fehler: Liste bleibt lokal; `StatusRow` in Tab Liste (00 12.27).
- Modul Angebote aus: Markt-Chip bleibt (Kern, 00 15.1), nur ohne Angebots-Satz.
- Übersprungen: keine Liste; Tab Liste zeigt "Erste Liste" (01 2.4).
- Rezept-Aufschub (5.2): Satz zusätzlich "Hier landen danach die Zutaten für Ofengemüse mit Feta."

**Interaktionen, Bewegung:** Chip-Wechsel mit `springQuick`; die Vorschauzeile aktualisiert Name und Chip ohne Layout-Sprung. Return = "Liste anlegen". Keine Haptik (die Rückmeldung ist die Ankunft in 3.12).

**Große Schrift und 320 pt:** Die Vorschau-Zeile stapelt ab AX1 (Chip unter dem Namen, bricht um). Vorschläge als volle Zeilen statt Chips, damit sie bei AX5 lesbar bleiben.

**Änderung gegenüber heute:** neu. Ersetzt das automatische Anlegen von "Meine erste Liste" durch das Tutorial (`home_screen.dart:110-150`). Betroffen: `home_screen.dart` (Anlege-Logik entfällt), `data/repositories/list_repository.dart` (Anlegen mit Markt, Farbe, Symbol), B: Ketten-Verzeichnis und `StoreChip`.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus mit offener deutscher Tastatur. Hintergrund #F2F2F7, oben gläserner Zurück-Knopf (zurück zu Ernährung bzw. Ziel) und die Fortschrittslinie voll schwarz #000000, gläserne Kapsel "Überspringen". Titel "Deine erste Liste" in SF Pro Bold 28 pt Schwarz, darunter "Heißt sie wie ein Markt, sortieren wir sie nach dessen Gängen und zeigen dir dort die Angebote." in 17 pt Schwarz. Eine hellgraue Eingabe-Kapsel #E9E9EE mit "Lidl" und Cursor. Darunter eine weiße Sektion mit einer Zeile: links ein blauer Kreis #007AFF mit weißem Einkaufswagen-Symbol, daneben "Lidl" in 17 pt Schwarz, rechts eine hellgraue Kapsel mit blauem Punkt #0050AA und "Lidl". Darunter die Sektion "Vorschläge" mit den Zeilen "Wocheneinkauf", "REWE", "Drogerie". Über der Tastatur die grüne Kapsel #3F7A1F "Liste anlegen" in Weiß.

---

### 3.12 Ankunft: Tab Liste mit dem ersten Erfolgserlebnis

**Zweck:** Hauptfrage der Wurzel bleibt "Was muss ich als Nächstes kaufen?" (01 2.1). Das erste Erfolgserlebnis: der erste Artikel steht sofort richtig einsortiert mit Menge auf der eigenen Liste.

**Wann:** nach "Liste anlegen" (bzw. nach Beitreten, Überspringen der Liste oder Anmeldung eines Bestandskontos).

**Übergang:** Das Onboarding-Cover blendet aus (`springMorph` auf Deckkraft und Skalierung 0,98 nach 1 des Ziels), darunter liegt Tab Liste. Das Accessory "Artikel hinzufügen" ist fokussiert, die Tastatur offen (01 10.9 Schritt 9); solange sie offen ist, ist die Tab-Bar ausgeblendet (00 6.5). Schließt man die Tastatur (Wischen nach unten in der Liste oder Tippen daneben), erscheint die Tab-Bar mit den gewählten Tabs mit `springStandard`. Reduce Motion: Überblendung.

**Aufbau** (Tab Liste, 01 2 und 00 12):
1. Großer Titel "Lidl" mit Umschalter, Markt-Chip "Lidl".
2. Sektion "Für heute" mit **einer Tipp-Zeile** (6.1, T1): `lightbulb` 16 pt `labelSecondary`, Text "Tipp: Schreib „2 Milch“, dann steht die Menge gleich dabei."
3. Leere Liste: keine Sektionen, kein Maskottchen (die Tastatur ist offen, der Platz gehört dem Vorschlags-Panel).
4. Vorschlags-Panel des Accessory vor dem ersten Buchstaben: ohne Verlauf **Startvorschläge** (9.8): "Milch", "Brot", "Eier", "Bananen", "Butter".

**Das Erfolgserlebnis:** Lena tippt "2 Milch" und Return. Die Zeile wächst in der neuen Sektion "Milch & Käse" ein (`springStandard`): leerer Kreis, Symbol der Kategorie, "Milch", rechts "2". VoiceOver: "Milch hinzugefügt, Milch und Käse". Die Tipp-Zeile T1 verschwindet nach dem ersten Artikel mit Menge mit `springStandard` (Ziel erreicht). Nach dem dritten Artikel erscheint beim nächsten Öffnen des Tabs T2 (6.1). Kein Erfolgsmoment mit Maskottchen (der ist für Einkauf, Wochenplan, Pro und Challenges reserviert, 00 12.35); die Bestätigung ist die sofort richtig einsortierte Zeile.

**Zustände:**
- Bestandskonto: keine Tipp-Zeile T1, keine Tastatur; Liste von heute nach 01 2.2; einmalig ein Status-Hinweis (00 12.28, reiner Status) "Angemeldet als Lena. Deine Listen sind da." Erstes Laden ohne lokalen Stand: Skelett in Form von Zeilen (`fill`), nur bis zur ersten Antwort (00 13).
- Beitreten (5.1): Liste "Wocheneinkauf" mit 12 Artikeln, keine Tastatur, Tipp-Zeile T5 statt T1.
- Offline: `StatusRow` unter dem Titel; Hinzufügen geht.
- Liste übersprungen: "Erste Liste" (01 2.4).

**Änderung gegenüber heute:** Statt des Coach-Mark-Tutorials über der ganzen App (blockiert Gesten, nur Deutsch, `Timer.periodic`) eine Zeile am Ort. Betroffen: `presentation/widgets/tutorial/tutorial_overlay.dart` (entfällt), `data/services/dynamic_tutorial_service.dart` (entfällt, ersetzt durch `TipService`, 6.1), `app.dart` (Overlay aus dem `builder`), Tutorial-Keys in `home_screen.dart`, `list_detail_screen.dart`, `recipes_screen.dart`, `main_scaffold.dart`.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus mit offener deutscher Tastatur, der Moment kurz vor dem ersten Artikel. Hintergrund #F2F2F7; oben großer Titel "Lidl" in SF Pro Bold 34 pt Schwarz #000000 mit kleinem grauem Abwärts-Chevron #636366 direkt hinter dem Wort, darunter eine hellgraue Kapsel #E9E9EE mit 8-pt-Punkt in Blau #0050AA und "Lidl" in 15 pt Schwarz; rechts in der Titelzeile ein runder Profil-Avatar 36 pt, grau #E9E9EE mit schwarzer Initiale "L" (kein Glas). Darunter der Sektionstitel "Für heute" in 17 pt Semibold Schwarz und eine weiße Sektion #FFFFFF mit 26 pt Radius und einer Zeile: frei stehendes graues Glühbirnen-Symbol #636366 und schwarzer 16-pt-Text "Tipp: Schreib „2 Milch“, dann steht die Menge gleich dabei." Sonst ist die Liste leer, ruhiger grauer Grund. Direkt über der Tastatur schwebt eine Liquid-Glass-Kapsel (hell, durchscheinend) mit grauem Plus #636366, im Feld der getippte Text "2 Milch" mit Cursor und rechts ein graues Text-Scanner-Symbol. Darüber eine weiße schwebende Fläche #FFFFFF mit 20 pt Radius und weichem Schatten (kein Glas) mit Zeilen: oben "Milch · Menge 2 · Milch & Käse" in 17 pt Schwarz mit grünem Plus #3F7A1F, darunter grau "Brot", "Eier", "Bananen", "Butter". Keine Tab-Bar sichtbar (Tastatur offen), kein Maskottchen, keine Karten.

---

## 4. Konto, Anmelden und Passwort

### 4.1 Anmelden (`/login`, Variante von 3.5)

**Zweck:** Hauptfrage "Wie komme ich wieder in mein Konto?"

**Wann:** Willkommen > "Ich habe schon ein Konto"; `/welcome` nach dem Abmelden; private Links ohne Sitzung.

**Aufbau:** wie 3.5, aber obere Leiste ohne Fortschrittslinie (kein gezählter Ablauf); Titel "Anmelden"; Satz "Mit derselben Methode wie beim ersten Mal."; dieselben drei Knöpfe; darunter schlicht "Mit Passwort anmelden" (4.2). Fußnote mit Nutzungsbedingungen und Datenschutz.

**Zustände:** wie 3.5. Zusätzlich: Ist das Konto neu (jemand meldet sich hier zum ersten Mal an), geht es mit Module weiter, dann Region (falls Angebote an), Name, Ernährung, Ziel (falls Kalorien an) und Erste Liste (1.1). Module und Region brauchen kein Konto vor sich; so verpasst niemand die Modulwahl, nur weil er den falschen Knopf genommen hat. Ab dort gilt: kein Zurück zum Anmelden.

**Große Schrift, 320 pt:** wie 3.5.

**Änderung gegenüber heute:** ersetzt `LoginScreen` (E-Mail und Passwort zuerst, Apple fehlt). Zurück ist ein echter Pop statt `context.go('/welcome')`. Betroffen: `auth/login_screen.dart`.

**Bildbeschreibung für ChatGPT:** Wie der Konto-Screen, aber im Dunkelmodus: Hintergrund #000000, oben links ein dunkler Glas-Zurück-Knopf, keine Fortschrittslinie. Titel "Anmelden" in SF Pro Bold 28 pt Weiß, darunter "Mit derselben Methode wie beim ersten Mal." in 17 pt Weiß. Drei Kapseln: der weiße offizielle "Mit Apple fortfahren"-Knopf mit schwarzem Logo und Text, eine fast schwarze Kapsel #131314 mit grauer Kontur #8E918F, Google-"G" und weißem Text "Mit Google fortfahren", eine dunkelgraue Kapsel #2C2C2E mit Briefumschlag und weißem "Mit E-Mail fortfahren". Darunter in hellem Avocadogrün #A6D45F ohne Fläche "Mit Passwort anmelden" und ganz unten grauer 13-pt-Text #98989F zu Nutzungsbedingungen und Datenschutz.

### 4.2 Mit Passwort anmelden (`/login?method=password`)

**Zweck:** Hauptfrage "Wie melde ich mich mit meinem Passwort an?" Für Bestandskonten, die heute E-Mail und Passwort nutzen.

**Aufbau** (Rahmen ohne Fortschritt): Titel "Mit Passwort anmelden"; `InsetSection` mit zwei Feldzeilen in einer `AutofillGroup`: "E-Mail" (`username`, `email`) und "Passwort" (`password`, verdeckt, rechts schlichter Symbol-Knopf `eye` bzw. `eye.slash` in `labelSecondary` mit 44-pt-Ziel, Label "Passwort anzeigen"; Return im Feld E-Mail springt ins Feld Passwort, Return dort meldet an); darunter schlicht "Passwort vergessen?" (44-pt-Ziel, heute 13-pt-Text); Hauptaktion "Anmelden"; darunter schlicht "Stattdessen Code per E-Mail".

**Beispielinhalt:** "jannis@beispiel.de", Passwort aus dem iCloud-Schlüsselbund.

**Zustände:**
- Arbeitet: Hauptaktion im Arbeitszustand.
- Falsche Daten: `StatusRow` "E-Mail oder Passwort stimmt nicht." mit Aktion "Code senden" (statt heute "Registrieren"). Fehler-Haptik.
- E-Mail nicht bestätigt: "Bestätige zuerst deine E-Mail-Adresse." mit Aktion "Code senden".
- Zu viele Versuche, offline: wie 3.6.
- Erfolg: iOS bietet das Speichern im Schlüsselbund an (`TextInput.finishAutofillContext`); weiter wie nach 3.7.

**Große Schrift, 320 pt:** Feldzeilen stapeln ab AX1 (Beschriftung über dem Feld).

**Änderung gegenüber heute:** Autofill und Schlüsselbund (heute fehlen beide, Bug 11), Trefferflächen 44 pt, Fehler als `StatusRow` statt Snackbar. Betroffen: `auth/login_screen.dart`, `core/widgets/paper/paper_widgets.dart` (`PaperUnderlineField` entfällt).

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus, Hintergrund #F2F2F7, oben links gläserner Zurück-Knopf. Titel "Mit Passwort anmelden" in SF Pro Bold 28 pt Schwarz. Eine weiße Sektion #FFFFFF (Radius 26 pt) mit zwei Zeilen: "E-Mail" mit "jannis@beispiel.de" und "Passwort" mit acht Punkten und rechts einem grauen Augen-Symbol. Darunter grüner Text "Passwort vergessen?" #3F7A1F, unten die grüne Kapsel "Anmelden" mit weißem Text und darunter grün "Stattdessen Code per E-Mail". Über der Tastatur zeigt iOS die Schlüsselbund-Leiste mit "jannis@beispiel.de".

### 4.3 Passwort vergessen (`/login?method=reset`)

**Zweck:** Hauptfrage "Wie komme ich ohne Passwort wieder hinein?"

**Ablauf:** Screen wie 3.6 mit Titel "Passwort zurücksetzen", Satz "Wir schicken dir einen Code. Danach legst du ein neues Passwort fest." und vorbefüllter E-Mail aus 4.2 (heute: gelbe Snackbar, wenn die E-Mail fehlt) > Code (3.7, Titel "Code zum Zurücksetzen") > Neues Passwort (4.4).

**Zustände:** Unbekannte Adresse: aus Datenschutzgründen dieselbe Bestätigung wie bei bekannter Adresse ("Wenn es ein Konto mit dieser Adresse gibt, ist der Code unterwegs."), kein Hinweis, ob ein Konto existiert. Sonst wie 3.6 und 3.7.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus mit offener deutscher E-Mail-Tastatur (mit @-Taste). Hintergrund #F2F2F7, oben links ein runder gläserner Zurück-Knopf mit Chevron, keine Fortschrittslinie, kein "Überspringen". Titel "Passwort zurücksetzen" in SF Pro Bold 28 pt Schwarz #000000, darunter in 17 pt Schwarz "Wir schicken dir einen Code. Danach legst du ein neues Passwort fest." Darunter eine hellgraue Eingabe-Kapsel #E9E9EE mit der vorbefüllten Adresse "jannis@beispiel.de" in Schwarz. Direkt über der Tastatur eine volle breite grüne Kapsel #3F7A1F, 50 pt hoch, mit weißem Text "Code senden" in SF Pro Semibold 17 pt. Keine Snackbar, kein Schloss-Symbol.

### 4.4 Neues Passwort (`/reset-password`)

**Zweck:** Hauptfrage "Welches neue Passwort will ich?"

**Wann:** nach gültigem Code aus 4.3; außerdem beim nächsten Start, wenn die App während des Zurücksetzens beendet wurde (Flag `password_reset_pending`, Bug 9).

**Aufbau** (Rahmen ohne Fortschritt; oben links statt Zurück der Glas-Knopf `xmark` "Abbrechen"):
1. Titel "Neues Passwort".
2. Feld (Kapsel `fill`, verdeckt, `AutofillHints.newPassword`, damit iOS ein starkes Passwort vorschlägt) mit `eye`-Knopf. Kein zweites Bestätigungsfeld (Anzeigen-Knopf und Schlüsselbund ersetzen es).
3. Regeln als drei Zeilen darunter (`subheadline`, `label`), jede mit Symbol: erfüllt `checkmark.circle.fill` in `action`, offen `circle` in `controlOutline`: "Mindestens 8 Zeichen", "Ein Großbuchstabe", "Eine Ziffer". Farbe nie allein: das Symbol wechselt die Form.
4. Hauptaktion "Passwort speichern", aktiv, wenn alle Regeln erfüllt sind (Ausnahme von 2.2: ein Passwort, das die Regeln verletzt, lehnt der Server ohnehin ab; die Regelzeilen zeigen vorher, was fehlt).

**Zustände:**
- Arbeitet, Fehler (Server lehnt ab): `StatusRow` mit Grund.
- Erfolg: man bleibt angemeldet und landet in Tab Liste mit dem Status-Hinweis "Passwort geändert." (heute: abmelden und zurück zu Willkommen, grüne Snackbar).
- Abbrechen (`xmark`): nativer Alert (00 12.34, gleichwertig mit endgültig, weil die Sitzung endet), Titel "Zurücksetzen abbrechen?", Nachricht "Du wirst abgemeldet und kannst es später erneut versuchen.", Knöpfe "Weiter festlegen" (Abbrechen-Rolle) und rot "Abmelden". Danach Anmelden (4.1). Ohne Eingabe im Feld fragt der Alert trotzdem, weil die Abmeldung die Folge ist.
- Offline: `StatusRow`.

**Große Schrift, 320 pt:** Regelzeilen brechen um, Symbol oben bündig.

**Bewegung, Haptik:** Regel-Symbole wechseln mit `springQuick`; Erfolg ohne Haptik (Status-Hinweis genügt), Fehler mit Fehler-Haptik.

**Änderung gegenüber heute:** hell und dunkel aus Tokens statt fest `#121212`, kein Material-`AppBar`, kein 64-pt-Schloss-Icon, keine feste Knopfhöhe 56. Betroffen: `auth/reset_password_screen.dart`, `supabase_service.dart`.

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Dunkelmodus, Hintergrund #000000, oben links ein dunkler runder Glas-Knopf mit weißem X. Titel "Neues Passwort" in SF Pro Bold 28 pt Weiß. Darunter eine dunkelgraue Kapsel #2C2C2E mit Punkten und einem grauen Augen-Symbol rechts; über der Tastatur schlägt iOS "Starkes Passwort verwenden" vor. Darunter drei Zeilen in 15 pt Weiß: "Mindestens 8 Zeichen" und "Eine Ziffer" mit gefülltem hellgrünem Häkchen-Kreis #A6D45F, "Ein Großbuchstabe" mit leerem grauem Kreis #7C7C80. Unten eine hellgrüne Kapsel #A6D45F mit dunklem Text "Passwort speichern" #0E1A06.

### 4.5 Konten verknüpfen und Sonderfälle der Anmeldung

| Fall | Verhalten |
|---|---|
| Apple mit "E-Mail-Adresse verbergen" | normal; Name kommt trotzdem von Apple, sonst leer |
| Gleiche E-Mail schon mit Google, jetzt per Code | Code meldet in dasselbe Konto an, wenn Supabase die Identität verknüpft; sonst `StatusRow` "Diese Adresse gehört zu einem Konto mit Google. Mit Google fortfahren" mit Aktion (F-17-05) |
| Apple im Simulator | interner Log-Eintrag; Nutzer sieht "Anmelden mit Apple klappt gerade nicht. Nimm Google oder E-Mail." (kein Entwicklertext, `brand.md` 3.4) |
| Anbieter nicht eingerichtet | gleiche Zeile wie Simulator |
| Netzwerk weg während Apple-Blatt | `StatusRow` offline, Knopf zurück in normalen Zustand |
| Konto auf dem Server gelöscht, Sitzung noch lokal | Abmelden, Willkommen in Variante `/welcome`, Status-Hinweis "Dieses Konto gibt es nicht mehr." |

### 4.6 Fehlertexte (verbindlich, ohne Rohfehler)

Zuordnung über Fehlercodes (`AuthException.code`, `statusCode`) statt über Teilstrings deutscher Freitexte (Bug 10).

| Code bzw. Lage | Text | Aktion |
|---|---|---|
| Netz | "Offline. Zum Anmelden brauchst du eine Verbindung." | – |
| Rate-Limit | "Zu viele Versuche. Bitte warte eine Minute." | – |
| `invalid_credentials` | "E-Mail oder Passwort stimmt nicht." | "Code senden" |
| `email_not_confirmed` | "Bestätige zuerst deine E-Mail-Adresse." | "Code senden" |
| OTP falsch | "Der Code stimmt nicht. Prüfe ihn oder lass dir einen neuen schicken." | "Neuen Code senden" |
| OTP abgelaufen | "Der Code ist abgelaufen." | "Neuen Code senden" |
| `email_address_invalid` | "Diese E-Mail-Adresse sieht nicht richtig aus." (Zeile unter dem Feld) | – |
| Adresse gehört zu einem Konto mit Google bzw. Apple, Verknüpfung nicht möglich | "Diese Adresse gehört zu einem Konto mit Google." | "Mit Google fortfahren" |
| Social fehlgeschlagen | "Anmelden mit Apple hat nicht geklappt." (bzw. Google) | "Erneut versuchen" |
| Apple bzw. Google nicht verfügbar (Simulator, Anbieter nicht eingerichtet) | "Anmelden mit Apple klappt gerade nicht. Nimm Google oder E-Mail." | – |
| Konto auf dem Server gelöscht | "Dieses Konto gibt es nicht mehr." (Status-Hinweis auf Willkommen) | – |
| Unbekannt | "Das hat nicht geklappt." | "Erneut versuchen" |

Regel: Ist die Aktion ein Knopf "Erneut versuchen", endet der Text nicht zusätzlich mit der Frage "Erneut versuchen?" (00 3.2 nutzt die Frage nur, wenn kein Knopf daneben steht).

---

## 5. Sonderfälle und Varianten

### 5.1 Einladung ohne Konto ("Beitreten" als letzter Schritt)

**Zweck:** Hauptfrage "Will ich dieser Liste beitreten?"

**Wann:** Link `shoplyai.app/invite/<id>`, `shoplyai.app/list/<id>` oder `shoplyai.app/join/<CODE>` ohne Sitzung.

**Verhalten:**
- Der Link wird **dauerhaft** gemerkt (SharedPreferences, Schlüssel `pending_link`), nicht nur im Speicher (Bug 14). Er übersteht Registrierung, Mail-Bestätigung und App-Neustart; er verfällt nach 7 Tagen.
- **Willkommen** zeigt unter dem Satz eine `InsetSection` mit einer Zeile: `Avatar` 28 pt "J", Text (`callout`, `label`) "Jannis hat dich zu „Wocheneinkauf“ eingeladen." Die Daten (Name der Liste, Einladender, Anzahl) kommen aus einer öffentlichen Vorschau des Links (Supabase-Funktion, 9.6); ohne Netz steht nur "Du wurdest zu einer Liste eingeladen."
- Der Ablauf läuft normal. Statt "Erste Liste" kommt der Schritt **Beitreten** (Rahmen 2, ohne "Überspringen"): Titel "„Wocheneinkauf“ beitreten?", Satz "Von Jannis · 12 Artikel · geteilt mit Mia", Vorschau als `ListRow` mit Avatar-Stapel, Hauptaktion "Beitreten", schlicht "Nicht beitreten" (legt dann den Schritt Erste Liste nach).
- Nach dem Beitritt ist die Liste die Liste von heute; Ankunft (3.12) ohne Tastatur, mit Tipp T5.

**Zustände:** Einladung ungültig oder Liste gelöscht: Schritt zeigt den leeren Zustand (Symbol `link` 48 pt Light, "Diese Einladung gilt nicht mehr.", "Frag Jannis nach einem neuen Link.") und Hauptaktion "Eigene Liste anlegen" (weiter zu 3.11). Bereits Mitglied (Bestandskonto): direkt Tab Liste mit dieser Liste. Offline: Beitreten wartet auf Netz; Hauptaktion im Arbeitszustand mit `StatusRow`.

**Abweichung von 01 10.3:** dort ein Beitritts-Sheet; hier ein Vollbild-Schritt (Owner-Regel). Für angemeldete Nutzer gilt dieselbe Gestaltung als eigener Push-Screen `/invite/:id` (Kap. 11).

**Bildbeschreibung für ChatGPT:** iPhone-16-Screenshot im Hellmodus, Hintergrund #F2F2F7, oben gläserner Zurück-Knopf (zurück zu Ernährung) und die volle schwarze Fortschrittslinie #000000, kein "Überspringen". Titel "„Wocheneinkauf“ beitreten?" in SF Pro Bold 28 pt Schwarz, darunter "Von Jannis · 12 Artikel · geteilt mit Mia" in 17 pt Schwarz. Eine weiße Sektion mit einer Zeile: grüner Kreis-Glyph #34C759 mit weißem Korb-Symbol, "Wocheneinkauf" in 17 pt, darunter grau "12 offen · REWE", rechts zwei überlappende runde Avatare "J" und "M" auf Grau #E9E9EE. Unten die grüne Kapsel #3F7A1F "Beitreten" und darunter grüner Text "Nicht beitreten".

### 5.2 Aufgeschobene Aktion aus einem öffentlichen Rezept

- Wer ohne Konto ein geteiltes Rezept liest und "Zutaten auf Liste" tippt, kommt ins Onboarding; die Aktion wird mit Rezept-ID und Portionen dauerhaft gemerkt (`pending_action`).
- Willkommen zeigt die Zeile "Danach landen die Zutaten für Ofengemüse mit Feta auf deiner Liste." (`callout`, Rezept-Thumbnail 56 pt links).
- Nach "Liste anlegen" öffnet sich statt der leeren Liste der Screen "Zutaten auf Liste" (Kap. 13, als Vollbild-Push, nicht als Sheet) mit der neuen Liste als Ziel und den gemerkten Portionen; nach dem Hinzufügen zeigt Tab Liste die Zutaten, ohne Tastatur und ohne Tipp T1 (T6 ist damit erledigt).
- Der gemerkte Aufschub verfällt nach 7 Tagen wie `pending_link`. Ist das Rezept inzwischen gelöscht, entfällt die Zeile auf Willkommen und der Ablauf endet normal.
- Zurück aus dem öffentlichen Rezept ohne Onboarding: Das Rezept hat oben links `xmark`; es schließt zu Willkommen.

**Bildbeschreibung für ChatGPT:** Willkommen wie in 3.2 (Hintergrund #F2F2F7, winkendes Maskottchen, "Avo" in SF Pro Bold 34 pt Schwarz, der Satz in 17 pt Schwarz). Zusätzlich unter dem Satz eine weiße Sektion #FFFFFF mit 26 pt Radius und einer Zeile: links ein quadratisches Rezeptfoto 56 pt mit 12 pt Radius (Ofengemüse mit Feta auf einem Blech, warmes Licht), rechts in 16 pt Schwarz "Danach landen die Zutaten für Ofengemüse mit Feta auf deiner Liste." Unten die grüne Kapsel #3F7A1F "Los geht's" in Weiß und darunter grüner Text "Ich habe schon ein Konto".

### 5.3 Bestandskonto im Neu-Ablauf

Meldet sich jemand im Schritt Konto mit einem eingerichteten Konto an (`users.onboarding_completed = true`), verwirft `apply_onboarding` die lokalen Antworten, die Region aus 3.4 wird nur übernommen, wenn das Konto keine hat. Ankunft wie Bestandskonto (3.12) mit dem Status-Hinweis "Angemeldet als Lena. Deine Listen und Einstellungen sind da."

### 5.4 Bestehende Nutzer nach dem Update

Kein erneutes Onboarding. Module werden aus vorhandenen Daten vorbelegt: Kalorien aus `calorie_tracking_enabled`, Kosten teilen an, wenn es offene Beträge gibt, sonst Standard (F-04). Einmalig erscheint auf der Startseite die Hinweis-Zeile "Neu: Du entscheidest, welche Bereiche du siehst." mit Aktion "Module" (öffnet Einstellungen > Module). Kein Pop-up beim Start (00 16.5 sinngemäß). Tipp-Zeilen bekommen bestehende Nutzer nur für Funktionen, die es vorher nicht gab (T8 Sprachmodus, T9 Wochenplan); T1 bis T7 gelten beim Update als gezeigt.

### 5.5 Onboarding unterbrochen

- App im Hintergrund oder beendet: Rückkehr in denselben Schritt mit allen Eingaben (`OnboardingController` plus SharedPreferences).
- Zurück bis Willkommen: alle Eingaben bleiben, bis man die App neu installiert.
- Konto angelegt, aber Onboarding nicht beendet (z. B. App nach dem Code beendet): Start im nächsten offenen Schritt nach dem Konto, gemerkt als `onb_step` in SharedPreferences (`users.onboarding_completed` ist erst nach "Liste anlegen", "Beitreten" bzw. Überspringen des letzten Schritts `true`, 1.2; die Antworten vor dem Konto sind schon übertragen). Nach einer Neuinstallation fehlt `onb_step`: Anmelden, `apply_onboarding` meldet `new`, weiter ab Name.

---

## 6. Nach dem Onboarding: Tipp-Zeilen und Berechtigungen

### 6.1 Tipp-Zeilen statt Tutorial (K-21)

**Zweck:** jede Funktion einmal am Ort erklären, ohne die App zu blockieren.

**Form:** `HintRow` (00 12.12, Inhalt "einmalige Tipps") in der Variante Tipp: Symbol `lightbulb` 16 pt `labelSecondary`, Text `callout` `label` mit "Tipp:" am Anfang im selben Satz (keine Überzeile), rechts kein Knopf außer bei T7; Wischen nach links "Ausblenden"; erledigt sich von selbst, sobald man die Funktion nutzt. Im Tab Liste steht sie in der Sektion "Für heute"; in Rezepte und Plan als einzelne Zeile in einer eigenen Sektion ohne Titel direkt unter dem großen Titel.

**Regeln:**
- Höchstens eine Tipp-Zeile gleichzeitig in der ganzen App und höchstens eine neue pro Tag.
- Tipp-Zeilen zählen zu den höchstens zwei Hinweis-Zeilen der Startseite (K-38) und kommen nach Ersparnis und Wochenplan.
- Nie im Einkaufsmodus, im Kochmodus, in Sheets oder über Inhalten. Welche Zeile erscheint, steht beim ersten Frame fest (00 12.12).
- Ein gezeigter Tipp erscheint nie wieder, außer nach "Tipps zurücksetzen" (Einstellungen > Hilfe).
- Texte in beiden Sprachen über die Übersetzungen (heute fest Deutsch).

| Nr. | Ort | Bedingung | Text | Erledigt durch |
|---|---|---|---|---|
| T1 | Tab Liste | Ankunft nach dem Onboarding | "Tipp: Schreib „2 Milch“, dann steht die Menge gleich dabei." | erster Artikel mit Menge |
| T2 | Tab Liste | 3 offene Artikel, noch nie eingekauft | "Tipp: Im Markt auf Einkaufen tippen. Dann ist alles groß und nach Gängen sortiert." | Einkaufsmodus gestartet |
| T3 | Tab Liste | 5 offene Artikel, nichts abgehakt nach 24 h | "Tipp: Der Kreis hakt ab, der Name öffnet den Artikel." | erstes Abhaken |
| T4 | Tab Liste | nach dem ersten Einkauf, Liste nicht geteilt | "Tipp: Teil die Liste, dann siehst du, wer gerade einkauft." | Liste geteilt |
| T5 | Tab Liste | nach Beitritt zu einer geteilten Liste | "Tipp: Was andere abhaken, siehst du sofort." | nach 3 Tagen |
| T6 | Tab Rezepte | erstes Öffnen | "Tipp: „Zutaten auf Liste“ im Rezept setzt alles, was du dafür brauchst, auf deine Liste." | erstes "Zutaten auf Liste" |
| T7 | Tab Rezepte | Ernährung im Onboarding übersprungen, zweites Öffnen | "Tipp: Stell Ernährung und Allergien ein, dann passen sich Rezepte an." mit Aktion "Einstellen" | Einstellung gespeichert |
| T8 | Tab Liste | Modul Avo an, Avo 3-mal per Text genutzt | "Tipp: Halte den Avo-Kreis gedrückt, um mit Avo zu sprechen." | Sprachmodus genutzt |
| T9 | Tab Plan | erstes Öffnen | "Tipp: Leg Rezepte auf die Tage. „Auf die Liste“ setzt danach alle Zutaten auf einmal auf deine Liste." | erster Wochenplan auf der Liste |

**Flutter:** `TipService` (Teil A, `lib/data/services/tip_service.dart`) mit lokalem Zähler pro Tipp und Tag; ersetzt `dynamic_tutorial_service.dart` und `users.tutorial_completed` (Feld bleibt ungenutzt in der Datenbank). Teil B meldet Ereignisse für T8 und T9 über `TipService.markDone(id)`.

**Bildbeschreibung für ChatGPT:** Ausschnitt eines iPhone-Screens im Hellmodus: auf hellgrauem Grund #F2F2F7 eine weiße Sektion #FFFFFF mit 26 pt Radius und dem Sektionstitel "Für heute" darüber in 17 pt Semibold Schwarz. Darin eine Zeile mit grauem Glühbirnen-Symbol #636366 und schwarzem 16-pt-Text "Tipp: Im Markt auf Einkaufen tippen. Dann ist alles groß und nach Gängen sortiert." Die Zeile ist halb nach links gewischt und zeigt rechts eine graue Aktion "Ausblenden". Keine Karte, kein Rahmen, kein Maskottchen.

### 6.2 Berechtigungen aus diesem Bereich

| Berechtigung | Wann | Vorab-Erklärung | Abgelehnt |
|---|---|---|---|
| Standort | Tipp auf "Standort verwenden" in 3.4 (und später in Preise & Angebote) | Unterzeile der Zeile selbst, am Ort, vor dem Tipp sichtbar | `StatusRow` mit "Einstellungen" |
| Apple Health (lesen) | Tipp auf "Aus Apple Health übernehmen" in 3.10 | Unterzeile "Liest Geburtsdatum, Größe und Gewicht einmal aus." | Felder bleiben manuell |
| Mitteilungen | **nicht im Onboarding**; erst beim ersten Teilen einer Liste oder beim Einschalten einer Erinnerung (00 13, 01 10.3) | Abschnitt am Ort im Teilen-Screen: "Erfahre, wenn jemand etwas hinzufügt oder einkauft." mit "Mitteilungen erlauben" / "Nicht jetzt" (Kap. 11, als Vollbild bzw. Zeile statt Sheet) | Einstellungen > Mitteilungen zeigt den Status |
| Kamera, Mikrofon, Spracherkennung | nicht im Onboarding | Kap. 11, 15, 16 | – |

Die heutige Mitteilungsabfrage beim allerersten Start (`main.dart:110-119`, `notification_service.dart:52-54`) entfällt.

---

## 7. Abläufe

### 7.1 Neu, Standardweg (Ziel unter 60 s)

1. Kaltstart, Willkommen, Avo winkt. "Los geht's".
2. Module: Angebote, Wochenplan, Avo an, Kalorien und Kosten teilen aus. "Weiter".
3. Region: "Standort verwenden" > Systemabfrage "Beim Verwenden der App" > "10437 Berlin", Chips Lidl und REWE. "Weiter".
4. Konto: "Mit Apple fortfahren" > Face ID > `apply_onboarding` überträgt Module, Region.
5. Name: "Lena" vorbefüllt (Vorname von Apple). "Weiter".
6. Ernährung: "Vegetarisch", "Erdnüsse". "Weiter".
7. Erste Liste: "Lidl" antippen (Vorschlag), Chip "Lidl" gesetzt. "Liste anlegen".
8. Tab Liste "Lidl", Tastatur offen, Tipp T1. "2 Milch" > Zeile erscheint in "Milch & Käse" mit "2".

### 7.2 Neu mit Kalorien

Wie 7.1, in Schritt 2 Kalorien an; nach Ernährung kommt "Dein Ziel": Abnehmen, Weiblich, 34, 168, 68, 64 kg, 16 Wochen, Leicht aktiv > "Etwa 1.650 kcal am Tag" > "Weiter" > Erste Liste. Tab-Bar mit Liste, Rezepte, Plan, Kalorien.

### 7.3 Neu per E-Mail

Wie 7.1 bis Konto; "Mit E-Mail fortfahren" > "lena.berger@posteo.de" > "Code senden" > Mail-Vorschlag "482913" in der Tastaturleiste > automatisch geprüft > Name (leer, "Lena" eintippen) > weiter wie 7.1.

### 7.4 Bestandskonto auf neuem iPhone

1. Willkommen > "Ich habe schon ein Konto".
2. Anmelden > "Mit Apple fortfahren" > Face ID.
3. `onboarding_completed = true` > Tab Liste mit der Liste von heute aus dem Konto (erstes Laden mit ruhigem Skelett), Status-Hinweis "Angemeldet als Jannis. Deine Listen sind da." Module, Region, Ernährung aus dem Konto. Keine Tipp-Zeile T1.

### 7.5 Bestandskonto mit Passwort, Passwort vergessen

1. Willkommen > "Ich habe schon ein Konto" > "Mit Passwort anmelden".
2. Falsches Passwort > "E-Mail oder Passwort stimmt nicht." > "Passwort vergessen?".
3. Passwort zurücksetzen (E-Mail vorbefüllt) > "Code senden" > Code > Neues Passwort mit iOS-Vorschlag > "Passwort speichern".
4. Tab Liste, Status-Hinweis "Passwort geändert."

### 7.6 Eingeladen ohne App und ohne Konto

1. Jannis teilt `shoplyai.app/list/<id>` per Nachricht. Lena tippt, landet über `joinavo.app` im App Store, installiert, öffnet.
2. Der Link ist gemerkt. Willkommen zeigt "Jannis hat dich zu „Wocheneinkauf“ eingeladen."
3. Module, Region, Konto, Name, Ernährung wie 7.1.
4. Beitreten: "„Wocheneinkauf“ beitreten? Von Jannis · 12 Artikel" > "Beitreten".
5. Tab Liste "Wocheneinkauf" mit 12 Artikeln, Tipp T5. Jannis bekommt die Mitteilung, dass Lena beigetreten ist.

### 7.7 Abmelden und wieder anmelden

1. Einstellungen > Konto > Abmelden (Kap. 18). Widget-Daten, Offline-Cache und Lernspeicher werden geleert (wie heute).
2. `/welcome` in der Variante "Anmelden" (3.2).
3. "Anmelden" > 4.1 > Tab Liste.

### 7.8 Offline beim ersten Start

1. Willkommen, Module, Region (nur PLZ) funktionieren.
2. Konto: `StatusRow` offline; die Eingaben bleiben gespeichert. Die App kann beendet werden.
3. Mit Netz: zurück im Schritt Konto, weiter wie 7.1.

---

## 8. Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| F-17-01 | Neue Konten nur mit Code (ohne Passwort)? Passwort optional unter Einstellungen > Konto festlegbar; Bestandskonten behalten "Mit Passwort anmelden". | ja |
| F-17-02 | Widerspruch zwischen Owner-Regel "keine Slider" (CLAUDE.md, keine Sheets, keine halbhohen Modals) und 00/01 (`AppSheet` mit Detents, Paywall, Avo, Teilen, Beitreten, Modul-Sheet, Vorab-Erklärung als Sheet). Dieses Kapitel folgt der Owner-Regel. Gilt sie für die ganze App, müssen 00 12.23, 01 6 und alle Sheet-Stellen umgestellt werden. | Owner-Regel gilt; 00 und 01 werden nachgezogen |
| F-17-03 | Reicht der Fußsatz zur KI im Schritt Module, oder braucht es eine ausdrückliche Einwilligung vor der ersten Weitergabe von Daten an den KI-Anbieter (App Store Review 5.1.2, DSGVO)? Betrifft auch die Kern-KI (Kategorien, Zettel-Import). | ausdrückliche, einmalige Einwilligung im Schritt Module mit klarer Zeile; juristisch prüfen |
| F-17-04 | Kalorienziel: Mindestalter und Umgang mit "Divers" (Mittelwert beider Formeln)? Kein Abnehm-Ziel unter 18? | ab 13 Jahren nutzbar, Abnehmen erst ab 18, Divers als Mittelwert |
| F-17-05 | Sollen Konten mit gleicher E-Mail über Apple, Google und Code automatisch verknüpft werden (Supabase "manual linking" vs. automatisch)? | automatisch bei bestätigter E-Mail |
| F-17-06 | Widerspruch zu `docs/DESIGN-STATUS.md` (Commit ec5325c, Richtung "D2 Glas" mit 5 Tabs Home, Listen, Avo, Rezepte, Profil, ohne Avo-Kreis und ohne Profil-Avatar). Die Fußzeile "Deine Tabs: …" in 3.3 und die Ankunft in 3.12 folgen 01 (2 bis 4 Tabs plus Avo-Kreis). | Owner entscheidet, welches Navigationsmodell gilt; das Kapitel passt nur die Fußzeile und 3.12 an |
| F-17-07 | Text des Willkommens-Satzes (01 10.9 überlässt ihn dem Owner). | "Einkaufsliste und Rezepte, die mitdenken." |
| F-17-08 | Startvorschläge für leere Verläufe (9.8): fest kuratiert oder aus anonymen Häufigkeiten aller Nutzer? | fest kuratiert, 12 Artikel je Sprache |
| F-17-09 | Kosten teilen im Onboarding zeigen (Standard aus) oder erst beim ersten Teilen vorschlagen (F-15)? | zeigen, Standard aus, plus Vorschlag beim Teilen |
| F-17-10 | Analytics für den Onboarding-Trichter (heute keine Ereignisse): Schrittaufrufe und Abbrüche ohne personenbezogene Daten erfassen? | ja, nur Schritt-ID und Dauer |
| F-17-11 | Widerspruch beim Maskottchen: 00 3.3 und K-29 wollen es neu, flach, in zwei Tonstufen; `docs/DESIGN-STATUS.md` (Commit f872961) sagt "Avo ist immer die echte 3D-Figur aus `assets/avo/`, nie eine gezeichnete Avocado". Betrifft Willkommen (3.2) und alle Erfolgsmomente. Die Bildbeschreibung in 3.2 nennt deshalb beide Varianten. | Owner entscheidet nach dem Bildvergleich; das Kapitel ändert nur `Mascot`-Asset und Bildbeschreibung, Größe, Ort und Bewegung bleiben gleich |
| F-17-12 | Soll die KI-Zeile im Schritt Module den Anbieter (Anthropic, Claude) nennen? Transparenz spricht dafür; der Plan legt "alle KI über Claude" fest. | ja, mit Link zu Datenschutz; zusammen mit F-17-03 juristisch prüfen |

---

## 9. Ergänzungen zum Fundament

Was dieses Kapitel braucht und in 00 bzw. 01 fehlt. Teil A ergänzt es in 00, bevor die Screens gebaut werden.

### 9.1 Komponente `OnboardingStepScaffold` (neu, Teil A)

Rahmen aus Kapitel 2: stehende obere Leiste (mindestens 44 pt) mit Glas-Zurück (ab Name leer), `StepProgress` und optional Glas-Text-Kapsel "Überspringen" (bzw. `xmark` in 4.4); darunter ein eigener `Navigator` für die Schritte (Push mit Zurück-Wischen, Linie folgt dem Wischen anteilig); je Seite scrollender Inhalt auf `bgGrouped` mit Titel `title1`, Satz `body`, und untere Aktionsleiste mit einer prominenten Hauptaktion, angeheftet bis 25 % der Bildschirmhöhe, darüber im Fluss (Regel 2.3, gilt auch als allgemeine Regel für angeheftete Aktionsleisten außerhalb von Glas). "Überspringen" wandert ab AX1 bzw. bei Platzmangel unter die Hauptaktion (2.3). Ort: `lib/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart`.

### 9.2 Komponente `StepProgress` (neu)

Kapsel 96 × 3 pt, Spur `fill`, Wert `label` (K-09: Fortschritt nicht grün), `springStandard` beim Wechsel, Reduce Motion: springt. Barrierefreiheit: "Schritt 3 von 6", Wert ändert sich nur beim Schrittwechsel.

### 9.3 Symbole, die in 00 9.2 fehlen

| Funktion | Symbol |
|---|---|
| Mit E-Mail fortfahren | `envelope` |
| Tipp-Zeile | `lightbulb` |
| Passwort anzeigen / verbergen | `eye` / `eye.slash` |
| Regel offen / erfüllt | `circle` / `checkmark.circle.fill` |
| Unbenanntes Mitglied | `person.fill` |

### 9.4 `StoreChip`, wählbare Variante (Teil B)

00 12.10 kennt den Chip nur zur Anzeige und `FilterChip` (12.19) erlaubt keine Farbe. Für 3.4 braucht es eine Mehrfachauswahl mit Markenpunkt: Kapsel `fill`, Punkt 8 pt, Name `subheadline`, optional Entfernung `caption1` `labelSecondary`; gewählt `actionFill`, Text `action`, führendes `checkmark` 13 pt; Trefferfläche 44; VoiceOver "Lidl, 400 Meter, ausgewählt".

### 9.5 Geteilte Modul-Zeilen

Die Zeilen aus 3.3 (Symbol, Titel, Nutzen-Satz) sind dieselben wie in Einstellungen > Module (Kap. 18). Vorschlag: eine Konfiguration `moduleDescriptors` neben `AppModule` (Vertrag 1) mit Symbol, Titel- und Nutzen-Schlüssel, Standardwert und Status (`visible`, `hidden`). Avo-Wissen liest dieselbe Quelle.

### 9.6 Datenbank und Dienste (Teil A, Supabase)

- RPC `apply_onboarding(answers jsonb)`: schreibt Module und Region-Verweis (und, falls schon vorhanden, Ernährung, Allergien und Ziel) in einer Transaktion, nur wenn `users.onboarding_completed` nicht `true` ist; gibt `new` oder `existing` zurück; setzt `onboarding_completed` nicht (1.2). Wiederholbar: der erste `weight_logs`-Eintrag wird pro Tag per Upsert geschrieben. Ersetzt die Zeitheuristiken.
- Abschluss: `users.onboarding_completed = true` per gezieltem Update bei "Liste anlegen", "Beitreten" oder Überspringen des letzten Schritts.
- `users.onboarding_completed` wird für das Routing gelesen (heute nie). Migration für `onboarding_completed` und `tutorial_completed` nachtragen (heute ohne Datei in `database/migrations/`), **mit Backfill**: alle Konten mit `created_at` vor dem Release-Datum bekommen `onboarding_completed = true` (sonst behandelt `apply_onboarding` alte Konten mit `null` als neu und überschreibt ihre Ernährung, 1.2).
- Öffentliche, rate-limitierte Funktion `invite_preview(listId | code)`: Listenname, Vorname des Einladenden, Anzahl offener Artikel; keine weiteren Daten.
- Dauerhafte Schlüssel `pending_link` und `pending_action` (5.1, 5.2, verfallen nach 7 Tagen), `password_reset_pending` (4.4), `onb_step` (letzter offener Schritt, 5.5).

### 9.7 Zusammenführung Ernährung und Allergien

Die Diät-IDs `gluten_free`, `dairy_free`, `nut_free` überschneiden sich mit Allergien aus `AllergyType`. Vorschlag: In der Oberfläche nur als Allergie zeigen; beim Speichern beide Felder schreiben (`diet_preferences` und `allergies`), damit Rezeptfilter und Ersetzungen weiter funktionieren. Gilt auch für Einstellungen > Ernährung & Allergien.

| Allergie-Chip (`AllergyType`) | setzt zusätzlich | beim Laden alter Daten ohne Allergie |
|---|---|---|
| Gluten (`gluten`) | `gluten_free` | `gluten_free` zeigt "Gluten" gewählt |
| Milch (`milk`) oder Laktose (`lactose`) | `dairy_free` | `dairy_free` zeigt "Laktose" gewählt (heutiges Label "Laktosefrei") |
| Schalenfrüchte (`nuts`) oder Erdnüsse (`peanuts`) | `nut_free` | `nut_free` zeigt "Schalenfrüchte (Nüsse)" gewählt (heutiges Label "Nussfrei") |

`dairy_free` bzw. `nut_free` wird nur entfernt, wenn keiner der jeweiligen Chips mehr gewählt ist. Die Liste der Allergie-Chips in 3.9 entspricht genau den 20 Werten von `AllergyType` (14 EU-Hauptallergene plus Laktose sichtbar, Fruktose, Histamin, Nachtschattengewächse, Mais, Hefe hinter "Weitere anzeigen"). Emojis und feste Labels aus dem Enum werden nicht angezeigt.

### 9.8 Startvorschläge im Accessory

00 12.4 sieht im Vorschlags-Panel nur Treffer aus dem eigenen Verlauf vor. Ohne Verlauf zeigt es vor dem ersten Buchstaben feste Startvorschläge (Deutsch: Milch, Brot, Eier, Bananen, Butter; Englisch entsprechend), bis 5 eigene Artikel im Verlauf sind.

### 9.9 Partner-Markenfarben für Anmeldeknöpfe

Google-Knopf-Farben (#FFFFFF/#747775 hell, #131314/#8E918F dunkel) sind wie die Marktfarben Daten, keine Design-Tokens, und stehen nicht in `AppColors`. Der Apple-Knopf ist der Systemknopf (native View; eine kleine Platform View nur auf diesem Screen, kein Glas, zählt nicht zum Glas-Budget).

### 9.10 Abweichungen von 00 und 01 wegen der Owner-Regel "keine Slider"

| Stelle in 00/01 | Dort | Hier |
|---|---|---|
| 00 13 "Berechtigung nötig": kurzes Sheet mit einem Satz Nutzen | Sheet | Erklärung am Ort (Zeile bzw. Abschnitt), danach direkt die Systemabfrage (6.2) |
| 01 10.3 Beitreten | Sheet | Vollbild-Schritt bzw. Push-Screen (5.1) |
| 00 13 und 01 7 "Modul-Sheet" bei Routen ausgeschalteter Module | Sheet | zentrierter Alert "Kalorien ist ausgeschaltet" mit "Einschalten" / "Nicht jetzt" (für dieses Kapitel nicht direkt nötig, gemeldet für Kap. 15/18) |
| 00 12.10 Markt-Chip "Ist das deine Lidl-Liste?" | Rückfrage ohne festgelegte Form | Tippen auf den vorgeschlagenen Chip setzt ihn; Ändern über Pull-down-Menü (3.11) |
| 00 10.2 Vollbild-Cover "fährt von unten" für das Onboarding | Cover von unten | Onboarding ist der erste Screen und braucht keine Einfahrt; Ende per Überblendung (3.12) |

Weitere Abweichungen bzw. Korrekturen an 00, nicht wegen der Owner-Regel:

| Stelle in 00 | Dort | Hier, mit Grund |
|---|---|---|
| 00 3.5 Launch-Screen in `systemBackground` | #FFFFFF hell | `systemGroupedBackground` (#F2F2F7 hell), weil der erste Frame laut 00 13 auf `bgGrouped` liegt; sonst Farbsprung Weiß nach Hellgrau (3.1). 00 3.5 bitte angleichen. |
| 00 12.19 `FilterChip` bis xxL als waagerecht scrollende Zeile | Filter | im Schritt Ernährung immer `Wrap`, weil keine Allergie hinter dem Rand verschwinden darf (3.9) |
| 00 12.3 Text-Kapsel in der Toolbar | wächst mit | "Überspringen" wandert ab AX1 bzw. bei Platzmangel als schlichter Knopf unter die Hauptaktion (2.3); als allgemeine Regel für Text-Kapseln in Toolbars vorgeschlagen |
| 00 5.3 "Umbruch statt Abschneiden" | ohne Aussage zu langen Wörtern | weiche Trennstellen (U+00AD) in den Übersetzungen für lange deutsche Wörter in Titeln (2.3); als allgemeine Regel vorgeschlagen |

### 9.11 Betroffene Dateien (Gesamtübersicht)

| Datei | Schicksal |
|---|---|
| `lib/presentation/screens/onboarding/onboarding_screen.dart` | neu als `onboarding_flow.dart` mit `OnboardingController` und Schritt-Routen |
| `onboarding/widgets/onboarding_priorities_page.dart` | entfällt |
| `onboarding/widgets/onboarding_diet_page.dart` | wird Schritt 3.9 |
| `onboarding/widgets/onboarding_goal_page.dart` | wird Schritt 3.10 (ohne Slider) |
| `auth/welcome_screen.dart` | wird Willkommen-Variante bzw. Konto-Schritt |
| `auth/login_screen.dart`, `auth/signup_screen.dart` | werden 4.1, 4.2, 3.6 |
| `auth/widgets/otp_verification_view.dart` | wird Schritt 3.7 |
| `auth/reset_password_screen.dart` | wird 4.4 |
| `auth/name_prompt_screen.dart` | wird Schritt 3.8 |
| `auth/social_auth.dart`, `auth/auth_errors.dart` | Entscheidung über `apply_onboarding`, Fehlercodes |
| `auth/widgets/google_logo.dart` | gebündeltes Asset |
| `presentation/widgets/tutorial/tutorial_overlay.dart`, `data/services/dynamic_tutorial_service.dart` | entfallen; `TipService` neu |
| `data/services/onboarding_answers_service.dart` | neu geschrieben um `apply_onboarding` |
| `data/services/supabase_service.dart` | Apple mit Nonce und Name, OTP-Registrierung, Fehlercodes |
| `presentation/state/auth_provider.dart` | ohne E-Mail-Präfix als Name, ohne 5-Minuten-Sync |
| `routes/app_router.dart` | Redirects mit `onboarding_completed`, dauerhafte Pending-Links, Tests |
| `core/constants/app_priorities.dart` | wird nicht mehr gelesen |
| `core/constants/paper_colors.dart`, `core/widgets/paper/paper_widgets.dart` | im Bereich nicht mehr benutzt (00 17.3) |
| `core/mascot/avo_mascot.dart`, `assets/avo/*.png` | `Mascot` mit neuen Vektor-Posen |
| `lib/main.dart`, `data/services/notification_service.dart` | keine Mitteilungsabfrage beim Start |
| `lib/app.dart` | `TutorialOverlay` und globaler `ScaffoldMessenger`-Bedarf entfallen |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard`, `LaunchImage.imageset` | nur `systemGroupedBackground`, Bild entfällt (3.1) |
| Texte `onb_*`, `welcome_*`, `otp_*`, `name_prompt_*`, `reset_password_*`, `priority_*`, `diet_*`, neu `allergy_*`, `tip_*` | neu geschrieben ohne `\n`, Kicker und "Shoply"; Plural über ICU |
| `test/` | neu: Router-Redirects (Neu, Bestand, Einladung, Rezept-Link, Reset), `apply_onboarding`-Fälle, Prüfmatrix 00 14.3 für jeden Schritt |
