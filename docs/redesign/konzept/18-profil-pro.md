# 18 Profil, Einstellungen und Pro

Stand: 07.11.2026. Besitz: **Teil A** (Screens `profile`, `subscription`, `legal`, Router-Gerüst `/settings/...` und `/pro`). Seiten von **Teil B** im Profil werden hier nur eingeordnet und verlinkt: "Preise & Angebote" (12 Kap. 6.3), "Kalorien & Gesundheit" (15 Kap. 3.23), "Wochenplan" (14 Kap. 12), "Avo" (16 Kap. 13), "Siri & Kurzbefehle" und "Widgets" (Kap. 19). Baut auf `00-grundlagen.md` ("00 x.y") und `01-navigation-und-struktur.md` ("01 x.y") auf. Quellen: Plan 1, 8 und 12, Verbesserungsliste 6d und 15, Inventare `profile.md` und `brand.md`.

**Owner-Regel "keine Slider" (CLAUDE.md, 07.11.2026) gilt in diesem Kapitel ohne Ausnahme:** keine Bottom-Sheets, keine halbhohen Modals, keine Drawer, keine Schieberegler. Bearbeiten ist ein Vollbild-Push mit Zurück oder passiert direkt am Ort; kurze Rückfragen sind zentrierte Alerts; Auswahl läuft über Pull-down-Menüs, Stepper, Segmente oder Picker in der Zeile. Wo 00 und 01 in diesem Bereich ein Sheet vorsehen (Profil als großes Sheet, Paywall als Sheet, Modul-Sheet, Aktionsblatt "Änderungen verwerfen?"), steht hier die regelkonforme Lösung. Die Abweichungen sind in Kapitel 12.3 gesammelt (gleiche Linie wie 17 Kap. 9.10 und 15).

Inhalt: 1 Regeln des Bereichs · 2 Beispieldaten · 3 Profil (Wurzel) · 4 Profil bearbeiten · 5 Einstellungsseiten von Teil A · 6 Seiten von Teil B (Einordnung) · 7 Konto, Abmelden, Konto löschen · 8 Paywall · 9 Pro-Flächen in der App · 10 Dialoge und Sonderzustände · 11 Abläufe · 12 Entscheidungen, offene Fragen, Ergänzungen zum Fundament

---

## 1. Regeln des Bereichs (verbindlich)

1. **Profil ist ein Ort, kein Modal.** Der Avatar (36 pt, kein Glas) rechts in der Titelzeile jeder Tab-Wurzel pusht die Seite "Profil" (`/settings`) in den aktuellen Tab, wie jede andere Unterseite (`CupertinoPageRoute`, Zurück-Wischen vom Rand). Tab-Bar und Avo-Kreis bleiben sichtbar. Jede Einstellungsseite ist ein weiterer Push (höchstens drei Ebenen ab Profil, 01 6). Die Seite funktioniert unverändert auch als Tab-Wurzel, falls der Owner das Navigationsmodell "D2" (5 Tabs mit Tab "Profil") wählt (F18-01).
2. **Einstellungen wirken sofort.** Kein "Speichern"-Knopf, kein Zurück-Dialog. Schalter, Auswahl und Chips gelten im Moment des Tippens, lokal zuerst, Abgleich mit dem Konto im Hintergrund. Einzige Texteingabe mit Übernahme ist der Name (übernimmt bei Return und beim Verlassen der Seite, 4).
3. **Jede Seite hat eine Route** (`/settings/<seite>`), einen Eintrag in der Einstellungssuche (Titel plus Suchwörter) und einen Schlüssel in der Avo-Brücke (`AvoSettingsBridge`), damit Avo sie öffnen oder ändern kann. Kein Avo-Schlüssel zeigt auf eine unsichtbare Einstellung (heute `accent_color`, `allergies`).
4. **Module zeigen nur, was an ist.** Seiten ausgeschalteter Module erscheinen nicht im Profil; ihre Daten bleiben. Module mit Status `hidden` erscheinen nirgends (00 15.2). Ist der Angebots-Kill-Switch aktiv, heißt "Preise & Angebote" überall "Märkte" (00 15.3, K-27), ohne Hinweis.
5. **Pro ist Kennzeichnung, keine Mauer.** `ProBadge` hinter Feature-Namen; gesperrte Funktionen zeigen eine echte Vorschau; erst die eigentliche Pro-Aktion öffnet die Paywall, die aus genau diesem Element wächst und danach die Aktion fortsetzt (9). **Angebote sind nie Pro**, auch keine einzelne Angebots-Einstellung.
6. **Ehrlich und ohne Druck.** Preise, Rabatt und Testphasen-Berechtigung kommen aus StoreKit. Kein Countdown, keine durchgestrichenen Fantasiepreise, Schließen sofort sichtbar, kein Maskottchen auf der Paywall, kein Pro-Hinweis beim Start, im Onboarding, im Einkaufs- oder Kochmodus.
7. **Keine Vanity-Zahlen.** Die drei Zähler der heutigen Profilkarte (Einkäufe, Listen, gespeichert) entfallen; Zahlen, die etwas bedeuten, stehen dort, wo man handelt (Verlauf, Alle Listen).
8. **Endgültiges braucht einen Alert, Umkehrbares ein Widerrufen.** Profilbild entfernen, Tipps zurücksetzen, Avo-Gespräch löschen: sofort, mit `UndoToast`. Konto löschen und Abmelden mit ungesendeten Änderungen: `confirmDestructive` (00 12.34).

---

## 2. Beispieldaten (durchgehend verwendet)

Heute ist Sa., 7. Nov. 2026. Gleiche Welt wie Kapitel 12 und 14.

| Feld | Wert |
|---|---|
| Person | Jannis Dietrich, angezeigt als "Jannis", E-Mail `jannis.d@beispiel.de`, angemeldet mit Apple, Profilfoto vorhanden |
| Listen | Wocheneinkauf (Lidl, geteilt mit Lena, angeheftet), Grillabend (Kaufland), Drogerie (ohne Markt, Angebote ausgeblendet) |
| Module | Preise & Angebote an, Wochenplan an, Avo an, Kosten teilen an, Kalorien & Gesundheit aus |
| Region | 79098 Freiburg im Breisgau (per Standort), Lieblingsmärkte Lidl, REWE |
| Ernährung | Vegetarisch; Allergien: Erdnüsse; "Rezepte automatisch anpassen" an |
| Persönliche Daten | 34 Jahre, 182 cm, männlich |
| Darstellung / Sprache | System / System (Deutsch) |
| Mitteilungen | iOS erlaubt; Hauptschalter an; Nachkauf-Erinnerung 9:00 |
| Pro | nicht Pro, Testphase noch nicht genutzt; Preise aus StoreKit: 2,99 € im Monat, 29,99 € im Jahr (12 × 2,99 € = 35,88 €, also "16 % günstiger", 2,50 € im Monat) |
| Testphase, falls heute gestartet | Tag 12 = Do., 19. Nov. (Erinnerung), Tag 14 = Sa., 21. Nov. (Abo beginnt, 29,99 €) |
| Version | aus `package_info`, z. B. "Version 1.1.4 (31)" (heute fest "1.0.0", Inventar 4.7) |

Varianten, die in den Zuständen vorkommen: **Lena Hoffmann** (Pro aktiv, Jahresabo, verlängert sich am 7. Nov. 2027); **Tom** (Familienkind, Kauf wartet auf Freigabe); Kalorien-Modul an (für Persönliche Daten und Health-Zeile).

Die Pro-Vorteile in den Beispielen sind **Platzhalter** aus der Konfiguration `pro_features` (00 16.3), nicht die Entscheidung des Owners (F-05): Wochenplan auf die Liste, Avo mit Stimme, Kalorien mit Apple Health, Monatsrückblick über 6 Monate, Kochmodus.

---

## 3. Profil (Wurzel, `/settings`, Alias `/profile`)

### 3.1 Zweck und Einstieg

- **Hauptfrage:** Wie ist meine App eingerichtet, und wo ändere ich das?
- **Wann:** Tipp auf den Avatar in der Titelzeile einer Tab-Wurzel (VoiceOver "Profil und Einstellungen"); Deep Link `shoply://settings` bzw. `/profile` (alte Links und Siri); Avo ("Öffne die Einstellungen"); globale Suche (Treffer "Einstellungen"). Deep Links bauen den Stapel: Wurzel des zuletzt aktiven Tabs (beim Kaltstart Liste) > Profil > Seite.

### 3.2 Aufbau von oben nach unten

1. **Navigationsleiste** (`LargeTitleNavBar`, Push erste Ebene): links Glas-Zurück "Liste" (Name des Tabs), großer Titel "Profil". Rechts keine Toolbar.
2. **Suchfeld** (`SearchField`, Platzhalter "Einstellungen durchsuchen"), scrollt mit dem Inhalt (3.5).
3. **Kopfzeile Person** (`InsetSection` ohne Titel, eine Zeile, Mindesthöhe 76): `Avatar` 64 pt (Foto oder Initialen), daneben Name (`title3`, `label`, bricht um) und E-Mail (`subheadline`, `labelSecondary`), rechts `chevron.right`. Ganze Zeile pusht "Profil bearbeiten" (4).
4. **Pro-Zeile** (`InsetSection` ohne Titel, eine `NavRow`): führendes Symbol `sparkles` (17 pt, `action`; einzige farbige Zeile der Seite, weil sie zu einer Hauptaktion führt), Titel "{pro}" (`body`), Unterzeile mit Status (`subheadline`, `labelSecondary`, Tabelle 3.4), rechts `chevron.right`. Tippen: Paywall wächst aus der Zeile (`/pro`, 8). Bei Pro zeigt dieselbe Paywall den Zustand "Du hast {pro}" (8.6).
5. **Sektion "App"** (`NavRow`s mit führendem Symbol 17 pt `labelSecondary`, Wert rechts in `labelSecondary`):
   - `switch.2` "Module", Wert "4 an" (Zahl eingeschalteter Module) > 5.1
   - `tag` "Preise & Angebote", Wert "79098 Freiburg" bzw. "Aus" (Modul aus) > 12 Kap. 6.3. Bei Kill-Switch: `storefront` "Märkte", Wert "Lidl, REWE".
6. **Sektion "Module"** (nur die eingeschalteten Module mit eigener Seite; entfällt ganz, wenn keines an ist): `flame` "Kalorien & Gesundheit" > 15 Kap. 3.23 · `calendar` "Wochenplan" > 14 Kap. 12 · `avo.core` "Avo" > 16 Kap. 13. Kosten teilen hat keine eigene Seite.
7. **Sektion "Für dich":** `leaf` "Ernährung & Allergien", Wert "Vegetarisch · 1 Allergie" > 5.2 · `person.text.rectangle` "Persönliche Daten" > 5.3 · `checklist` "Listen" > 5.4.
8. **Sektion "Allgemein":** `bell` "Mitteilungen", Wert "An" bzw. "Aus" (bei iOS-Verbot: `exclamationmark.triangle.fill` in `warning` vor "In iOS aus") > 5.5 · `circle.lefthalf.filled` "Darstellung", Wert "System" > 5.6 · `globe` "Sprache", Wert "Deutsch" > 5.7.
9. **Sektion "iPhone":** `waveform.circle` "Siri & Kurzbefehle" > Kap. 19 · `rectangle.3.group` "Widgets" > Kap. 19.
10. **Sektion "Hilfe und Rechtliches":** `questionmark.circle` "Hilfe" > 5.8 · `doc.text` "Rechtliches" > 5.9.
11. **Sektion "Konto":** `person.crop.circle` "Konto", Wert "Apple" (Anmeldeweg) > 7.1.
12. **Fuß** (`footnote`, `labelSecondary`, zentriert): "{app} · Version 1.1.4 (31)".

Sektionstitel stehen in `headline`, `label`, gemischte Schreibweise (00 12.5). Abstand zwischen Sektionen `sectionGap` 32. Unterer Inhaltsabstand aus `ShellInsets` (00 6.2), nicht `120 + padding`.

### 3.3 Beispielinhalt

Profil · [Einstellungen durchsuchen] · (Foto) **Jannis** / jannis.d@beispiel.de · {pro}: "14 Tage gratis testen" · App: Module "4 an", Preise & Angebote "79098 Freiburg" · Module: Wochenplan, Avo · Für dich: Ernährung & Allergien "Vegetarisch · 1 Allergie", Persönliche Daten, Listen · Allgemein: Mitteilungen "An", Darstellung "System", Sprache "Deutsch" · iPhone: Siri & Kurzbefehle, Widgets · Hilfe und Rechtliches: Hilfe, Rechtliches · Konto "Apple" · "Avo · Version 1.1.4 (31)".

### 3.4 Status der Pro-Zeile

| Zustand (aus `subscriptionStatusProvider`) | Unterzeile | Tippen |
|---|---|---|
| nicht Pro, Testphase möglich | "14 Tage gratis testen" | Paywall |
| nicht Pro, Testphase genutzt | "Alle Vorteile ansehen" | Paywall ("Abonnieren") |
| Testphase läuft | "Testphase bis Sa., 21. Nov." | Paywall im Zustand "Du hast {pro}" |
| aktiv | "Aktiv · verlängert sich am 7. Nov. 2027" bzw. "Aktiv bis 7. Nov. 2027" (gekündigt) | dito |
| Zahlung fehlgeschlagen (Kulanzzeit) | `exclamationmark.triangle.fill` `warning` + "Zahlung fehlgeschlagen. Zahlungsdaten prüfen" | Systemblatt "Abos verwalten" |
| ausstehend (Kaufen anfragen) | "Wartet auf Freigabe" | Paywall im Zustand "ausstehend" |
| Status unbekannt (Start, offline) | letzter bekannter Status, sonst nur "{pro}" ohne Unterzeile | Paywall |
| über Familienfreigabe | "Aktiv über Familienfreigabe" | dito, ohne "Abo verwalten" |

### 3.5 Suche in den Einstellungen

- Index aller Seiten **und** aller Zeilen (Titel, Unterzeile, Suchwörter) in beiden Sprachen, lokal, ohne Netz. Beispiele: "PLZ", "Postleitzahl", "Region" → Preise & Angebote > Region; "dunkel", "Nachtmodus" → Darstellung; "Allergie", "Nuss" → Ernährung & Allergien; "kündigen", "Abo" → {pro}; "löschen" → Konto > Konto löschen, Profil bearbeiten > Foto entfernen; "Bildschirm an" → Listen.
- Beim Tippen ersetzen Treffer den Inhalt unter dem Feld sofort (keine Entprellung, alles lokal), in einer Sektion "Einstellungen": Titel (`body`) mit Pfad als Unterzeile ("Preise & Angebote › Region"), Symbol der Seite, `chevron.right`. Treffer innerhalb einer Seite stehen unter ihrer Seite.
- Tippen pusht die Zielseite (bei Unterseiten den ganzen Pfad) und hebt die gesuchte Zeile einmal hervor (Fläche `fillPressed`, blendet mit `springStandard` nach 1 s aus; Reduce Motion: `fadeReduced`). Das Suchfeld behält den Text, Zurück führt zu den Treffern.
- Keine Treffer: `EmptyState` (Pose "suchend", ab AX1 Symbol `magnifyingglass` 48 pt) "Keine Einstellung zu „Kontrast“." mit einem Satz "Systemeinstellungen wie Textgröße findest du in den iOS-Einstellungen." und schlicht "iOS-Einstellungen öffnen". Keine "Frag Avo"-Zeile (ein Avo-Einstieg, 01 3).
- Kill-Switch: Angebots-Begriffe ("Angebot", "Prospekt", "Sparen") liefern keine Treffer; "Markt", "PLZ" führen zu "Märkte".

### 3.6 Zustände

| Zustand | Verhalten |
|---|---|
| Erster Start / leer | nicht leer möglich (eingeloggt). Ohne Profilfoto: Initialen "J" in `label` auf `fill`. Ohne Namen (Altkonten): Kopfzeile "Namen festlegen" in `action` statt Name, E-Mail darunter. |
| Lädt | sofort aus dem lokalen Stand (Name, Foto aus Cache, Werte aller Zeilen aus SharedPreferences bzw. Providern, die vor `runApp` geladen sind). Kein Skelett, keine springenden Zähler (heute Balken und Zähler ab 0). |
| Fehler | Profil konnte nicht neu geladen werden: kein Hinweis, solange ein lokaler Stand da ist; nur wenn Name und E-Mail fehlen: Kopfzeile "Profil nicht geladen" mit schlicht "Erneut versuchen". |
| Offline | `StatusRow` unter dem Titel "Offline. Änderungen werden gespeichert, sobald du wieder online bist." Alle Zeilen bleiben bedienbar; Seiten mit Netzpflicht sagen es am Ort (Konto löschen, Paywall). |
| Modul aus | Zeile der Modulseite fehlt ohne Lücke; Sektion "Module" entfällt, wenn leer. Preise & Angebote bleibt (Märkte sind Kern), Wert "Aus". |
| Kill-Switch | Zeile heißt "Märkte" (`storefront`). |
| Pro gesperrt | nicht relevant (keine Einstellung ist Pro). Die Pro-Zeile ist der Einstieg. |

### 3.7 Interaktionen, Bewegung, Haptik

- Push und Zurück: `CupertinoPageRoute`, Zurück-Wischen folgt 1:1 (00 10.2). Zeilen: gedrückt `fillPressed` beim Berühren, nicht beim Loslassen.
- Pro-Zeile: Paywall wächst aus der Zeile (`springMorph`, 8.3).
- Erneutes Tippen auf den aktiven Tab: Zurück zur Tab-Wurzel (Profil schließt), dann nach oben.
- Keine Haptik (heute `selectionClick` bei jeder Zeile und `lightImpact` bei jedem Zurück: entfällt, 00 11).
- Ändert sich ein Wert auf einer Unterseite, steht er beim Zurückkehren schon in der Zeile (Riverpod), ohne Überblendung.

### 3.8 Große Schrift (AX) und 320 pt

- Ab AX1: Sektionen randlos (00 6.4); Werte rutschen unter den Titel (`NavRow` stapelt); Kopfzeile: Avatar über Name und E-Mail (Spalte), Avatar bleibt 64 pt; E-Mail bricht an "@" und "." um, nie Ellipse.
- 320 pt: Seitenrand 16; Werte rechts brechen um ("79098 Freiburg" in zwei Zeilen ist erlaubt), bevor der Titel gekürzt wird. Pro-Unterzeile bricht um.
- Fuß bricht um, bleibt zentriert.

### 3.9 Was sich gegenüber heute ändert, betroffene Dateien

- Tab 4 "Profil" mit Titel "Einstellungen" wird eine Seite aus dem Avatar mit Titel "Profil" (behebt Wayfinding und das doppelte "Einstellungen", Inventar 3.2). Profilkarte mit drei Zählern, Premium-Karte, Paper-Kicker, Serifen, Creme-Avatar, rote Abmelden-Umrandung entfallen.
- Neu: Suche, Module, Preise & Angebote, Modulseiten, Listen, Siri, Widgets, Rechtliches, Konto mit Konto löschen. "Was dir wichtig ist" und "Tutorial neu starten" entfallen (K-22, K-21; Ersatz "Tipps zurücksetzen" in Hilfe). Kalorien-Schalter wandert nach Module.
- Dateien: `profile/profile_screen.dart` (neu als `profile_root_screen.dart`), `widgets/common/paper_settings.dart` (entfällt, 00 17.3), `routes/app_router.dart` (Routen `/settings/...`, `/profile` als Alias, Tab 4 entfällt), `main_scaffold.dart` (Avatar statt Tab), neu `profile/settings_search_index.dart`, `data/services/avo_settings_bridge.dart` (Schlüssel je Zeile), `avo_app_knowledge.dart` (Pfade "Profil › …").

### 3.10 Bildbeschreibung für ChatGPT

iPhone-17-Pro-Screenshot im hellen Modus, Hintergrund #F2F2F7. Oben links ein runder Liquid-Glass-Knopf mit Zurück-Pfeil, darunter linksbündig der große fette Titel "Profil" in SF Pro 34 pt Schwarz, darunter ein hellgraues Kapsel-Suchfeld #E9E9EE mit Lupe und grauem Platzhalter "Einstellungen durchsuchen". Darunter eine weiße Gruppe (#FFFFFF, Eckenradius 26) mit einem runden Profilfoto 64 pt, daneben "Jannis" in 20 pt Semibold Schwarz und darunter "jannis.d@beispiel.de" in 15 pt Grau #636366, rechts ein grauer Chevron. Darunter eine weiße Gruppe mit einer Zeile: grünes Funkel-Symbol #3F7A1F, "Avo Pro" in Schwarz, Unterzeile "14 Tage gratis testen" in Grau, Chevron. Dann weitere weiße Gruppen mit fetten schwarzen Sektionstiteln "App", "Module", "Für dich", "Allgemein", jeweils Zeilen mit freistehenden grauen SF Symbols (keine farbigen Quadrate), schwarzem Titel und grauem Wert rechts: "Module · 4 an", "Preise & Angebote · 79098 Freiburg", "Wochenplan", "Avo", "Ernährung & Allergien · Vegetarisch · 1 Allergie", "Mitteilungen · An", "Darstellung · System", "Sprache · Deutsch", getrennt durch eingerückte Haarlinien #C6C6C8. Unten schwebt die gläserne Tab-Bar mit "Liste" (grün ausgewählt), "Rezepte", "Plan" und rechts abgesetzt ein runder Glaskreis mit einem braunen Kern und hellgrünem Ring. Keine Karten, keine Zähler, kein Maskottchen.

---

## 4. Profil bearbeiten (`/settings/profile`)

### 4.1 Zweck und Einstieg

- **Hauptfrage:** Wie sehen mich andere in geteilten Listen und bei meinen Rezepten?
- **Wann:** Kopfzeile im Profil; "Namen ändern" im Rezept-Editor (13); Avo ("Ändere meinen Namen in Jannis D."); Suche ("Name", "Foto", "Bild").

### 4.2 Aufbau von oben nach unten

1. `LargeTitleNavBar`, zweite Ebene: Inline-Titel "Profil bearbeiten", Glas-Zurück "Profil". Kein Speichern-Knopf.
2. **Avatar-Bereich** (ohne Sektion, zentriert auf `bgGrouped`): `Avatar` 64 pt, darunter schlichter Knopf "Foto ändern" (`body`, `action`, Trefferfläche 44). Avatar und Knopf öffnen dasselbe Pull-down-Menü (`AppMenu`, wächst aus dem Avatar): "Foto auswählen" (`photo`), "Foto aufnehmen" (`camera`), Trenner, "Foto entfernen" (`trash`, `danger`, nur mit Foto).
3. **Sektion "Name"**: eine Zeile mit Textfeld (`body`, Platzhalter "Dein Name", Löschen-Kreuz bei Fokus). Sektionsfuß: "So sehen dich andere in geteilten Listen und bei deinen Rezepten."
4. **Sektion "E-Mail"**: `ValueRow` "jannis.d@beispiel.de" (nicht editierbar), Fuß "Ändern kannst du sie unter Konto." mit schlichtem Link "Konto" > 7.1.

### 4.3 Verhalten

- **Name:** Übernahme bei Return und beim Verlassen der Seite (Zurück, Tab-Wechsel, App in den Hintergrund). Regeln: 2 bis 40 Zeichen, Leerzeichen am Rand entfernt. Ungültig: Text unter dem Feld (`footnote`) mit `exclamationmark.circle` in `danger` "Mindestens 2 Zeichen." und Fehler-Haptik bei Return; beim Verlassen mit ungültigem Text bleibt der alte Name und unten erscheint `UndoToast` (Status) "Name nicht geändert: zu kurz". Kein Dialog.
- **Foto auswählen / aufnehmen:** System-Fotoauswahl (`PHPicker`, braucht keine Erlaubnis) bzw. Kamera (Erlaubnis im Moment des Tippens, Erklärung steht als Menü-Unterzeile "Fragt einmal nach der Kamera"). Danach System-Zuschnitt quadratisch. Das neue Bild steht sofort im Avatar (lokal, 512 px); Upload im Hintergrund, solange zeigt der Avatar unten rechts das Sync-Zeichen (00 12.7). Fehler: Avatar bleibt beim neuen Bild, `StatusRow` unter dem Avatar "Foto nicht hochgeladen. Erneut versuchen" und Fehler-Haptik; nie rohe Exception (heute `'Error: $e'`).
- **Foto entfernen:** sofort Initialen, `UndoToast` "Foto entfernt · Widerrufen" (4 s). Die Datei im Speicher wird erst nach Ablauf gelöscht (heute sofort und endgültig).
- Profilfotos liegen künftig in einem Bucket mit signierten URLs für Mitglieder gemeinsamer Listen, nicht öffentlich (Inventar 4.7; Teil A, Supabase).

### 4.4 Zustände

- Lädt: Name und Foto aus dem Cache sofort (heute lädt das Foto über `NetworkImage` ohne Cache sichtbar neu).
- Offline: Name wird lokal übernommen (Sync-Zeichen hinter dem Feld bis zum Abgleich); Foto auswählen geht, Upload wartet in der Warteschlange.
- Kamera abgelehnt: Menüeintrag "Foto aufnehmen" bleibt; Tippen zeigt `StatusRow` "Kamera ist aus. In Einstellungen erlauben".
- Modul aus, Pro: nicht relevant.

### 4.5 Bewegung, Haptik, AX, 320 pt

- Menü `springMorph`/`springMenu` aus dem Avatar; neues Foto blendet mit `fadeReduced` über die Initialen.
- Haptik nur bei Fehler.
- AX: Avatar bleibt 64 pt, "Foto ändern" bricht um; das Feld wächst mit der Schrift (`minLines: 1`, keine feste Höhe). 320 pt: unverändert, Feld volle Breite.

### 4.6 Was sich ändert, Dateien

Ersetzt `profile/settings/display_name_screen.dart` (Speichern-Pille, Kicker, Avatar 100 pt mit `NetworkImage`) und den Material-Dialog "Profilbild ändern" (Inventar 2.4). `profile_picture_service.dart` bekommt verzögertes Löschen und signierte URLs. Avo-Schlüssel `display_name` bleibt.

### 4.7 Bildbeschreibung für ChatGPT

iPhone-Screenshot hell, Hintergrund #F2F2F7. Oben links ein Glas-Zurück-Knopf, mittig klein "Profil bearbeiten" in 17 pt Semibold. Mittig darunter ein rundes Profilfoto 64 pt eines Mannes, darunter der grüne Textknopf "Foto ändern" #3F7A1F. Aus dem Foto ist ein gläsernes Pull-down-Menü aufgeklappt mit drei Zeilen "Foto auswählen" (Bild-Symbol rechts), "Foto aufnehmen" (Kamera-Symbol) und, durch ein schmales Band getrennt, "Foto entfernen" in Rot #D70015 mit Papierkorb. Dahinter, leicht verdeckt, eine weiße Gruppe "Name" mit dem Text "Jannis" und darunter grau die Fußnote "So sehen dich andere in geteilten Listen und bei deinen Rezepten.", darunter die Gruppe "E-Mail" mit "jannis.d@beispiel.de". Kein Speichern-Knopf.

---
## 5. Einstellungsseiten von Teil A

Gemeinsamer Rahmen aller Seiten: `LargeTitleNavBar` als Push erste Ebene mit großem Titel (Seitenname), Glas-Zurück "Profil"; Inhalt in `InsetSection`s auf `bgGrouped`; Zeilen aus 00 12.22 (`ToggleRow`, `NavRow`, `ValueRow`); jede Änderung wirkt sofort (Regel 2), ohne Haptik (Schalter sind Flutter-gezeichnet, K-31); offline wirkt alles lokal, Abgleich später (kein eigener Hinweis je Zeile, die `StatusRow` unter dem Titel genügt); ab AX1 Sektionen randlos, Werte unter dem Titel, Unterzeilen brechen um. Abweichungen davon stehen bei der Seite.

### 5.1 Module (`/settings/modules`)

- **Hauptfrage:** Welche Bereiche will ich in der App haben?
- **Wann:** Profil > Module; leerer Zustand eines Modul-Tabs ("Tab ausblenden"); Alert "… ist ausgeschaltet" (10.2); Seiten der Module ("Wochenplan ausschalten", 14 Kap. 12.1); Avo ("Schalte Kalorien ein"); Suche ("Tab", "ausblenden", "Kalorien", "Wochenplan").
- **Aufbau:**
  1. Satz (`body`, `label`, ohne Sektion): "Liste und Rezepte sind immer dabei. Alles andere schaltest du hier ein oder aus. Deine Daten bleiben erhalten."
  2. `InsetSection` ohne Titel mit einer `ToggleRow` je Modul, dieselben Zeilen und Texte wie im Onboarding (17 Kap. 3.3, gemeinsame Konfiguration `moduleDescriptors`, 17 Kap. 9.5): Symbol, Titel, Nutzen-Satz als Unterzeile, Schalter.
     - `tag` "Preise & Angebote" · "Angebote deiner Märkte in Listen und beim Hinzufügen"
     - `calendar` "Wochenplan" · "Rezepte auf die Woche legen, Zutaten mit einem Tipp auf die Liste"
     - `avo.core` "Avo" · "Dein Assistent zum Schreiben und Sprechen"
     - `flame` "Kalorien & Gesundheit" · "Essen eintragen, Ziele, Apple Health"
     - `eurosign.circle` "Kosten teilen" · "Beträge in geteilten Listen aufteilen"
  3. Sektionsfuß, dynamisch wie im Onboarding: "Deine Tabs: Liste, Rezepte, Plan." Folgt den Schaltern sofort (Wörter blenden mit `springStandard`).
  4. Ist ein Modul ganz oder teilweise Pro (F-05): `ProBadge` hinter dem Titel als reine Kennzeichnung (nicht einzeln antippbar, 12.4 E18-03); Einschalten bleibt möglich (echte Vorschau, 00 16.2). Fuß ergänzt: "Mit Pro gekennzeichnete Bereiche kannst du einschalten und ansehen. Einzelne Aktionen darin brauchen {pro}."
- **Beispiel:** Preise & Angebote an, Wochenplan an, Avo an, Kalorien aus, Kosten teilen an. Fuß "Deine Tabs: Liste, Rezepte, Plan."
- **Verhalten beim Umschalten:**
  - Einschalten: Tab erscheint in der Tab-Bar mit `springStandard` (der Tab-Bar-Rand ist unten sichtbar, man sieht die Wirkung sofort); Zeile der Modulseite erscheint im Profil. Kalorien ein ohne Ziel: Unterzeile wird kurz zu "Richte im Tab Kalorien dein Ziel ein." (kein Sprung dorthin).
  - Ausschalten: sofort, ohne Rückfrage (umkehrbar, Daten bleiben), `UndoToast` "Kalorien ausgeschaltet · Widerrufen". Bei Kalorien zusätzlich in der Unterzeile: "Apple Health pausiert. Deine Einträge bleiben." Bei Avo: "Der Kreis wird zur Suche." Bei Angebote: "Märkte und Gang-Reihenfolge bleiben."
  - Avo ein, zum ersten Mal: Einwilligung in die KI-Verarbeitung am Ort, falls F-17-03 sie verlangt (gleiche Zeile wie im Onboarding).
- **Zustände:** Kill-Switch: Zeile "Preise & Angebote" fehlt ohne Hinweis. `hidden`-Module fehlen. Offline: Schalter wirken lokal sofort. Pro gesperrt: siehe Punkt 4. Fehler beim Abgleich: Schalter bleibt in der gewählten Stellung, Abgleich wird wiederholt (kein Zurückspringen, weil lokal maßgeblich; Konto übernimmt beim nächsten Erfolg).
- **AX / 320 pt:** Unterzeilen umbrechen; Schalter oben bündig zur ersten Textzeile.
- **Änderung, Dateien:** neu. Ersetzt den Kalorien-Schalter im Profil (`calorieTrackingEnabledProvider` geht in `moduleEnabledProvider(AppModule.calories)` auf, B stellt um). Neu `profile/settings/modules_screen.dart` (A), liest `lib/core/modules/app_modules.dart`.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, Glas-Zurück-Knopf, großer fetter Titel "Module". Darunter schwarzer 17-pt-Satz "Liste und Rezepte sind immer dabei. Alles andere schaltest du hier ein oder aus. Deine Daten bleiben erhalten." Eine weiße Gruppe mit Radius 26 und fünf Zeilen: graue SF Symbols (Preisschild, Kalender, kleiner Kreis mit Ring, Flamme, Euro-Kreis), schwarze Titel "Preise & Angebote", "Wochenplan", "Avo", "Kalorien & Gesundheit", "Kosten teilen", je ein grauer Satz darunter, rechts iOS-Schalter: vier grün #3F7A1F an, "Kalorien & Gesundheit" grau aus. Darunter graue Fußnote "Deine Tabs: Liste, Rezepte, Plan." Unten die gläserne Tab-Bar mit drei Tabs und dem Avo-Kreis.

### 5.2 Ernährung & Allergien (`/settings/diet`, Alias `/diet-preferences`)

- **Hauptfrage:** Was esse ich nicht, und worauf muss die App achten?
- **Wann:** Profil; Tipp-Zeile T7 im Tab Rezepte (17 Kap. 6.1); Hinweis "Für dich angepasst" im Rezept (13); Avo ("Ich habe eine Erdnussallergie"); Suche ("Allergie", "vegan", "Laktose", "Nuss").
- **Aufbau:**
  1. Satz (`body`, `label`): "Rezepte passen sich daran an und weisen dich auf Allergene hin."
  2. Sektion "Allergien und Unverträglichkeiten" (zuerst, weil sicherheitsrelevant): `FilterChip`s im `Wrap` auf `surface` in der Sektion: Gluten, Milch, Laktose, Eier, Erdnüsse, Schalenfrüchte (Nüsse), Soja, Fisch, Krebstiere, Weichtiere, Sellerie, Senf, Sesam, Sulfite, Lupinen; schlicht "Weitere anzeigen" (Fruktose, Histamin, Nachtschattengewächse, Mais, Hefe). Gewählt: `actionFill`, `checkmark`, Text `action`. Fuß (`footnote`): "Hinweise auf Allergene helfen, ersetzen aber nicht den Blick auf die Zutatenliste."
  3. Sektion "Ernährung": Chips Vegetarisch, Vegan, Pescetarisch, Low-Carb, Keto, Paleo, Halal, Koscher, Natriumarm. Nichts gewählt = "Ich esse alles" (kein eigener Chip; der Fuß sagt es: "Nichts gewählt heißt: keine Einschränkung."). Gluten-, laktose- und nussfrei erscheinen nur als Allergie (17 Kap. 9.7).
  4. Sektion ohne Titel: `ToggleRow` "Rezepte automatisch anpassen" mit Unterzeile "Ersetzt Zutaten, die nicht passen, und zeigt den Grund." (Standard an).
- **Beispiel:** Allergien: Erdnüsse gewählt. Ernährung: Vegetarisch. Anpassen an.
- **Verhalten:** Jeder Chip schaltet sofort (`springQuick`), schreibt `users.allergies` bzw. `users.diet_preferences` (bei überlappenden Werten beide, 17 Kap. 9.7) und invalidiert Rezept-Anpassungen; Rezepte zeigen beim nächsten Aufbau den neuen Stand, ohne Sprung in offenen Rezepten. Vegan wählt Vegetarisch nicht automatisch mit (keine versteckte Logik), Vegan schließt Vegetarisch fachlich ein; die Anpassung nutzt die strengere Wahl.
- **Zustände:** Leer: alle Chips grau, Satz bleibt. Offline: lokal, Sync später. Avo nutzt dieselben Daten; ändert Avo sie, erscheint hier der neue Stand. Modul aus: unabhängig von Modulen (Rezepte sind Kern). Pro: nie.
- **AX / 320 pt:** Chips umbrechen (`Wrap`), jede Chip-Zeile volle Breite; ab AX3 eine Chip je Zeile ist erlaubt. "Weitere anzeigen" bleibt am Ende der Sektion.
- **Änderung, Dateien:** Allergien bekommen erstmals eine Oberfläche (Inventar 4.2, Sicherheitsrisiko). Checkliste mit Speichern-Pille wird Chips mit sofortiger Wirkung. Dateien: `diet_preferences_screen.dart`, `widgets/multi_select_settings_screen.dart` (entfällt), `core/constants/diet_preferences.dart` (IDs bleiben), `data/models/dietary_preference.dart` (`AllergyType`, ohne Emojis und feste Labels), `avo_app_knowledge.dart` (Pfad "Profil › Ernährung & Allergien"). Texte `allergy_*` neu.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Ernährung & Allergien". Schwarzer Satz "Rezepte passen sich daran an und weisen dich auf Allergene hin." Weiße Gruppe "Allergien und Unverträglichkeiten" mit umbrechenden hellgrauen Kapseln #E9E9EE: "Gluten", "Milch", "Laktose", "Eier", "Erdnüsse" (gewählt: hellgrüne Fläche #EEF5E4, grünes Häkchen und grüner Text #3F7A1F), "Schalenfrüchte (Nüsse)", "Soja", "Fisch", "Krebstiere", "Sellerie", "Senf", "Sesam", "Sulfite", "Lupinen", am Ende grüner Text "Weitere anzeigen"; darunter graue Fußnote. Gruppe "Ernährung" mit Kapseln, "Vegetarisch" grün gewählt. Unten eine Gruppe mit Schalterzeile "Rezepte automatisch anpassen", Schalter grün an. Keine Emojis, keine bunten Kategoriefarben.

### 5.3 Persönliche Daten (`/settings/personal`)

- **Hauptfrage:** Welche Angaben nutzt die App für meine Kalorienziele?
- **Wann:** Profil; Kalorien-Ziele (15); Avo ("Ich bin 34"); Suche ("Alter", "Größe", "Geschlecht").
- **Aufbau:**
  1. Sektion ohne Titel:
     - `ValueRow` "Alter", Wert "34 Jahre". Tippen klappt in der Zeile einen Rad-Picker auf (wie in Kalender, 13 bis 100 Jahre), erneutes Tippen klappt zu. Kein Schieberegler.
     - `ValueRow` "Größe", Wert "182 cm". Tippen klappt in der Zeile auf: `SegmentedControl` "cm | ft, in" und darunter der Rad-Picker (cm 100 bis 230; ft 3 bis 7 und in 0 bis 11 in zwei Rädern). Wechsel der Einheit rechnet um (182 cm = 5 ft 11 in), statt den Wert zu löschen (heute Bug, Inventar 4.7).
     - `ValueRow` "Geschlecht", Wert "Männlich" mit Pull-down-Menü: Weiblich, Männlich, Divers, Keine Angabe.
  2. Sektionsfuß: Modul Kalorien an: "Daraus berechnet {app} deinen Tagesbedarf. Die Angaben bleiben in deinem Konto." Modul aus: "Wird nur für Kalorienziele genutzt. Kalorien & Gesundheit ist ausgeschaltet."
  3. Mit Modul Kalorien und Apple Health verbunden: schlicht "Aus Apple Health übernehmen" (liest Geburtsdatum und Größe einmal, 15 Kap. 3.22).
- **Zustände:** Leer: Werte "Nicht angegeben" in `labelSecondary`. Offline: lokal. Pro: nie. Modul aus: Seite bleibt erreichbar (Avo kann die Werte setzen), Fuß wie oben.
- **Bewegung:** Aufklappen des Pickers mit `springStandard` (Zeile wächst, Nachbarn rücken), Reduce Motion: Überblendung. Auswahl-Haptik beim Einrasten des Rads (System).
- **AX / 320 pt:** Picker-Räder wachsen mit der Schrift bis AX2, darüber wird die Eingabe ein Zahlenfeld mit Ziffernblock (Rad wäre zu klein); Segmente werden ab AX ein Pull-down-Menü (00 12.18).
- **Änderung, Dateien:** Kicker, Radio cm/FT, Speichern-Pille, mehrdeutiges "5.7 ft" entfallen; die PLZ wandert nach Preise & Angebote (01 5.8, 12 Kap. 6.1). Datei `personal_info_screen.dart`. Felder in `users` (`age`, `height`, `height_unit`, `gender`) bleiben.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Persönliche Daten". Eine weiße Gruppe mit drei Zeilen: "Alter" mit grauem Wert "34 Jahre"; "Größe" ist aufgeklappt und zeigt einen grauen Segment-Schalter "cm | ft, in" mit "cm" gewählt und darunter ein iOS-Rad-Picker mit "182" in der Mitte; "Geschlecht" mit grauem Wert "Männlich" und kleinem Auf-Ab-Pfeil. Darunter graue Fußnote "Wird nur für Kalorienziele genutzt. Kalorien & Gesundheit ist ausgeschaltet." Kein Speichern-Knopf, kein Schieberegler.

### 5.4 Listen (`/settings/lists`)

- **Hauptfrage:** Wie sollen sich meine Listen und der Einkaufsmodus verhalten?
- **Wann:** Profil; Suche ("Bilder", "Bildschirm", "Vorschläge", "Start"); Avo.
- **Aufbau:**
  1. Sektion "Anzeige": `ToggleRow` "Artikelbilder anzeigen" (Unterzeile "Symbole und Produktfotos neben dem Namen. Bei sehr großer Schrift automatisch aus."); `ToggleRow` "Vielleicht auch" (Unterzeile "Vorschläge, was du bald wieder brauchst, am Ende der Liste").
  2. Sektion "Beim Öffnen": `ValueRow` "Liste beim Start" mit Pull-down-Menü "Zuletzt benutzte Liste" / jede Liste mit Glyph (Wert "Wocheneinkauf" = angeheftete Liste, 01 2.2).
  3. Sektion "Einkaufsmodus": `ToggleRow` "Bildschirm anlassen" (Standard an; Unterzeile "Nur solange du einkaufst"); `ToggleRow` "Anderen zeigen, dass ich einkaufe" (Standard an; Unterzeile "Mitglieder geteilter Listen sehen „Jannis kauft gerade ein“."). Datenschutz-Schalter für die Präsenz (Plan 4) fehlt heute.
  4. Sektion "Kategorien": `NavRow` "Reihenfolge im Markt" mit Unterzeile "Pro Liste in der Listen-Info" > öffnet die Listen-Info der Liste von heute (11). Keine zweite Bearbeitungsstelle.
- **Zustände:** Offline: lokal. Modul aus: unabhängig. Pro: nie. Bei AX1+ zeigt "Artikelbilder anzeigen" die Unterzeile "Bei deiner Schriftgröße ausgeblendet", der Schalter bleibt bedienbar und gilt ab kleinerer Schrift.
- **Änderung, Dateien:** neu (`profile/settings/lists_settings_screen.dart`, A). Schlüssel für Avo: `show_item_images`, `suggestions_enabled`, `start_list`, `keep_screen_on`, `share_presence`.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Listen". Weiße Gruppe "Anzeige" mit zwei Schalterzeilen "Artikelbilder anzeigen" und "Vielleicht auch", beide grün #3F7A1F an, je mit grauer Unterzeile. Gruppe "Beim Öffnen" mit "Liste beim Start" und grauem Wert "Wocheneinkauf" mit kleinem grünen Kreis-Glyph davor. Gruppe "Einkaufsmodus" mit "Bildschirm anlassen" und "Anderen zeigen, dass ich einkaufe", beide an. Gruppe "Kategorien" mit "Reihenfolge im Markt" und Chevron. Sektionstitel fett schwarz.

### 5.5 Mitteilungen (`/settings/notifications`)

- **Hauptfrage:** Wann darf mich die App stören?
- **Wann:** Profil (Zeile zeigt den iOS-Status); nach dem ersten Teilen einer Liste (Vorab-Erklärung am Ort, 11); Avo ("Keine Mitteilungen mehr zu Rezepten"); Suche ("Benachrichtigung", "Push", "Erinnerung", "Uhrzeit").
- **Aufbau:**
  1. **iOS-Status** (oberste Sektion, je nach Erlaubnis):
     - nicht gefragt: Zeile "Mitteilungen erlauben" in `action` (schlicht) mit Unterzeile "Erfahre, wenn jemand etwas hinzufügt oder einkauft." Tippen startet direkt die Systemabfrage (Erklärung steht schon am Ort, 17 Kap. 6.2).
     - abgelehnt: `StatusRow` mit `exclamationmark.triangle.fill` in `warning`: "Mitteilungen sind in iOS ausgeschaltet. Deine Auswahl hier gilt, sobald du sie erlaubst." mit schlicht "In Einstellungen erlauben" (öffnet die iOS-Einstellungen der App). Die Schalter darunter bleiben bedienbar.
     - erlaubt: keine Statuszeile.
  2. Sektion ohne Titel: `ToggleRow` "Mitteilungen von {app}" (kontoweit, entfernt bei Aus das Gerät aus `user_devices`). Bei Aus klappen die Sektionen 3 bis 6 mit `springStandard` zusammen (statt 40 % Deckkraft, heute).
  3. Sektion "Geteilte Listen": "Jemand kauft ein" (`shopping_started`, an); "Änderungen an Listen" (Unterzeile "Gebündelt, z. B. „Lena hat 5 Artikel abgehakt“", an, K-39); "Einkauf abgeschlossen" (an); "Einladungen und neue Mitglieder" (an).
  4. Sektion "Erinnerungen": "Nachkauf-Erinnerung" (an) und bei an darunter `ValueRow` "Uhrzeit" "9:00" mit aufklappbarem Uhrzeit-Rad in der Zeile; "Kochtimer" (an; Unterzeile "Zeitkritisch, auch im Fokus-Modus").
  5. Sektion "Module" (nur eingeschaltete Module, Inhalt aus Teil B): Wochenplan "An die nächste Woche erinnern" mit Uhrzeit "So., 18:00" (dieselbe Einstellung wie 14 Kap. 12.1, nicht zwei); Kalorien "Ideen fürs Abendessen" mit Uhrzeit "18:00"; Kosten teilen "Offene Beträge". Ohne eingeschaltete Module entfällt die Sektion.
  6. Sektion "Rezepte": "Bewertungen und Likes" (an); "Kommentare" (an); "Neue Rezepte von Erstellern, denen du folgst" (aus).
  7. Sektionsfuß der letzten Sektion: "Die Auswahl gilt auf all deinen Geräten."
- **Beispiel:** iOS erlaubt, alles an wie oben, Nachkauf 9:00, Wochenplan-Erinnerung aus.
- **Verhalten:** Kategorien werden im Konto gespeichert (heute nur lokal) und serverseitig beim Versand geprüft (Edge Function `send-push-notification` liest sie; heute zählt nur der Hauptschalter). Lokale Erinnerungen werden bei jeder Änderung neu geplant. Änderungen ohne Haptik.
- **Zustände:** Lädt: sofort aus dem lokalen Stand (heute Vollbild-Spinner und neun einzelne SharedPreferences-Aufrufe), iOS-Status wird beim Öffnen und bei Rückkehr aus den iOS-Einstellungen neu gelesen (Zeile wechselt mit `springStandard`). Offline: lokal, Sync später. Modul aus: Sektion 5 ohne dessen Zeile. Pro: nie.
- **AX / 320 pt:** Unterzeilen umbrechen; die Uhrzeit-Zeile stapelt; das Rad wird ab AX3 zu einem Uhrzeitfeld mit Ziffernblock.
- **Änderung, Dateien:** `notifications_screen.dart` (Kicker AVO/LISTEN/REZEPTE/ALLGEMEIN, Vollbild-Spinner, Deckkraft-Sperre), `notification_preferences_service.dart` (Kategorien ins Konto), `mascot_notification_service.dart` (Uhrzeiten), Edge Function `send-push-notification` (Teil B). "Wochenzusammenfassung" (Allgemein) entfällt als eigene Mitteilung (heute ohne Inhalt; Monatsrückblick lebt im Verlauf). Uhrzeiten neu.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Mitteilungen". Oben eine weiße Zeile mit orangem Warndreieck #A85400 und schwarzem Text "Mitteilungen sind in iOS ausgeschaltet. Deine Auswahl hier gilt, sobald du sie erlaubst." und darunter grünem Textknopf "In Einstellungen erlauben" #3F7A1F. Darunter Gruppe mit Schalter "Mitteilungen von Avo" an. Gruppe "Geteilte Listen" mit vier grünen Schaltern ("Jemand kauft ein", "Änderungen an Listen" mit grauer Unterzeile, "Einkauf abgeschlossen", "Einladungen und neue Mitglieder"). Gruppe "Erinnerungen" mit "Nachkauf-Erinnerung" an und darunter "Uhrzeit" mit grauem Wert "9:00", dann "Kochtimer" an. Sektionstitel fett schwarz, gemischte Schreibweise.

### 5.6 Darstellung (`/settings/appearance`)

- **Hauptfrage:** Hell, dunkel oder wie das iPhone?
- **Aufbau:**
  1. Sektion ohne Titel, drei Auswahlzeilen mit `checkmark` rechts in `action` (iOS-Muster): "System" (Unterzeile "Folgt dem iPhone"), "Hell", "Dunkel". Standard "System" (K-32).
  2. Sektionsfuß: "Textgröße, fetter Text und Kontrast stellst du in den iOS-Einstellungen ein. {app} folgt ihnen." mit schlicht "iOS-Einstellungen öffnen".
- **Verhalten:** Wechsel überblendet die ganze App in 0,2 s (`fadeReduced`, ohne Neuaufbau, 00 17.2), Häkchen springt mit `springQuick`. Wird lokal und in `user_preferences.theme_mode` gespeichert; die lokale Wahl dieser Sitzung gewinnt (Inventar 6).
- **Zustände:** Offline: lokal. Pro: nie (kein "erweitertes Theme" als Pro, `isAdvancedTheme` entfällt).
- **Änderung, Dateien:** `theme_customization_screen.dart`, `theme_provider.dart` (Standard System statt Hell), `theme_service.dart`, `user_preferences_model.dart` (`accent_color`, `theme_variant` werden nicht mehr gelesen; Avo-Schlüssel `accent_color` entfällt, K-06). Doppelte Quelle `users.theme` wird nicht mehr geschrieben.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot im dunklen Modus, Hintergrund Schwarz #000000, großer weißer Titel "Darstellung". Eine dunkelgraue Gruppe #1C1C1E mit Radius 26 und drei Zeilen "System" (graue Unterzeile #98989F "Folgt dem iPhone", rechts grünes Häkchen #A6D45F), "Hell", "Dunkel". Darunter graue Fußnote mit hellgrünem Textknopf "iOS-Einstellungen öffnen". Keine Farbauswahl, keine Vorschaukacheln.

### 5.7 Sprache (`/settings/language`)

- **Hauptfrage:** In welcher Sprache spricht die App mit mir?
- **Aufbau:** Satz "Gilt für die App, Mitteilungen und Avo. Was du in Listen schreibst, bleibt, wie es ist." Sektion mit drei Auswahlzeilen und `checkmark`: "System" (Unterzeile "Deutsch, wie dein iPhone"), "Deutsch", "English" (Eigennamen in der eigenen Sprache).
- **Verhalten:** Sofort, Überblendung ohne Neuaufbau (00 17.2); gespeichert lokal **und** in `users.language` (heute nur lokal, Zweitgerät startet falsch); Mitteilungen des Servers nutzen `users.language`. Zusätzlich Hinweis im Fuß: "Du kannst die Sprache auch in den iOS-Einstellungen pro App festlegen."
- **Zustände:** Offline: lokal, Server später. Pro: nie.
- **Änderung, Dateien:** `language_screen.dart`, `language_provider.dart` (Server-Abgleich).
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Sprache", schwarzer Satz "Gilt für die App, Mitteilungen und Avo. Was du in Listen schreibst, bleibt, wie es ist." Weiße Gruppe mit "System" (graue Unterzeile "Deutsch, wie dein iPhone", grünes Häkchen rechts #3F7A1F), "Deutsch", "English". Graue Fußnote darunter.

### 5.8 Hilfe (`/settings/help`)

- **Hauptfrage:** Wie komme ich weiter, wenn etwas nicht klappt?
- **Aufbau:**
  1. Sektion "Häufige Fragen": aufklappbare Zeilen (Titel `body`, `chevron.down` rechts, dreht sich beim Aufklappen mit `springStandard`; Antwort in `body` `label`, nie blassgrau): "Wie teile ich eine Liste?", "Wie funktioniert der Einkaufsmodus?", "Wie kommt die Kategorie zustande?", "Woher kommen die Angebote?" (nur Modul Angebote), "Wie kündige ich {pro}?", "Wie lösche ich mein Konto?". Antworten nennen Pfade als schlichte Links ("Profil › Konto") und öffnen sie.
  2. Sektion "Kontakt": "E-Mail an den Support" (`envelope`, öffnet Mail mit Betreff "{app} Support"; ohne Mail-App: Adresse wird kopiert, `UndoToast` "Adresse kopiert"); "Fehler melden" (`ant`, öffnet Mail mit vorausgefüllten, sichtbaren Angaben: Version, iPhone-Modell, iOS; nichts wird ohne Senden übertragen); "{app} bewerten" (`star`, öffnet direkt die App-Store-Bewertung, ohne Vor-Dialog, heute markiert sie fälschlich "bewertet").
  3. Sektion "Tipps": schlicht "Tipps zurücksetzen" (Unterzeile "Zeigt die kurzen Erklärungen in der App noch einmal."); Tippen setzt `TipService` zurück, `UndoToast` "Tipps zurückgesetzt · Widerrufen". "Anleitung" (öffnet die Web-Anleitung im In-App-Browser, 5.9).
  4. Fuß: "{app} · Version 1.1.4 (31)". In Debug-Builds öffnet Langdruck darauf das Entwicklermenü (00 15.2).
- **Zustände:** Offline: FAQ funktioniert (lokal), Mail wird vom System in den Postausgang gelegt, Anleitung zeigt "Braucht eine Verbindung". Modul aus: Angebots-Frage entfällt; Kill-Switch ebenso.
- **AX / 320 pt:** Fragen umbrechen; Chevron oben bündig.
- **Änderung, Dateien:** `help_support_screen.dart` (Material-Dialoge, Serifen-Fußzeile, "Fehler melden" ohne Aktion, feste Version 1.0.0, Vor-Dialog zur Bewertung). "Tutorial neu starten" wird "Tipps zurücksetzen" (K-21).
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Hilfe". Weiße Gruppe "Häufige Fragen" mit fünf Zeilen, die zweite "Wie funktioniert der Einkaufsmodus?" ist aufgeklappt und zeigt einen schwarzen Absatz Antworttext, der Chevron zeigt nach oben. Gruppe "Kontakt" mit "E-Mail an den Support", "Fehler melden", "Avo bewerten", jeweils mit grauem SF Symbol. Gruppe "Tipps" mit grünem Text "Tipps zurücksetzen" und "Anleitung". Unten zentriert grau "Avo · Version 1.1.4 (31)".

### 5.9 Rechtliches (`/settings/legal`) und Datenquellen (`/settings/legal/sources`)

- **Hauptfrage:** Welche Regeln gelten, und woher kommen die Daten?
- **Aufbau Rechtliches:** Sektion mit `NavRow`s "Datenschutz", "Impressum", "Nutzungsbedingungen" (öffnen je einen Push mit In-App-Browser: Webseite unter der Navigationsleiste, Glas-Zurück, rechts `square.and.arrow.up` "In Safari öffnen"; kein von unten einfahrendes Safari-Fenster), "Datenquellen" (> eigene Seite), "Lizenzen" (Open-Source-Lizenzen, Flutter-Lizenzseite im neuen Stil).
- **Aufbau Datenquellen:** je Quelle eine Sektion mit Titel und Text in `body` `label`: "Produktfotos und Nährwerte: Open Food Facts (ODbL, Fotos CC BY-SA)"; "Preise: Open Prices (ODbL)"; "Märkte und Standorte: OpenStreetMap-Mitwirkende (ODbL)"; "Angebote: {Angebotsquelle}, Preise laut Händler, können veraltet sein" (nur Modul Angebote an und kein Kill-Switch; F12-1). Jede Quelle mit Link.
- **Zustände:** Offline: Webseiten zeigen im Browser-Bereich `EmptyState` "Braucht eine Verbindung." mit "Erneut versuchen"; Datenquellen sind lokal. Kill-Switch: Angebotsquelle entfällt, ODbL-Hinweise bleiben, solange Open-Prices-Daten gezeigt werden.
- **Änderung, Dateien:** neu `legal/legal_screen.dart`, `legal/data_sources_screen.dart` (ersetzt das Sheet "Datenquellen" in `profile_screen.dart`); `core/constants/legal_links.dart` auf eine Domain (F18-06).
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Rechtliches", eine weiße Gruppe mit fünf Zeilen "Datenschutz", "Impressum", "Nutzungsbedingungen", "Datenquellen", "Lizenzen", jeweils grauer Chevron. Kein Text in Großbuchstaben, keine Serifen.

---

## 6. Seiten von Teil B (Einordnung)

Diese Seiten liegen im Profil, folgen dem Rahmen aus Kapitel 5 und sind in ihren Bereichskapiteln vollständig beschrieben. Teil A stellt Route, Profilzeile, Suchindex-Eintrag und Avo-Schlüssel bereit; Teil B baut die Seite.

| Seite | Route | Profilzeile sichtbar | Inhalt (Kurz) | Kapitel |
|---|---|---|---|---|
| Preise & Angebote (Kill-Switch: Märkte) | `/settings/offers` | immer | Modul-Schalter, Region, Lieblingsmärkte, Markt-Erkennung, Einzel-Schalter, ausgeblendete Listen, Datenquellen | 12 Kap. 6.3, 6.4 |
| Kalorien & Gesundheit | `/settings/health` | Modul Kalorien an | Ziele, Apple Health lesen und schreiben, Wasserziel (Stepper), Einheiten | 15 Kap. 3.23 |
| Wochenplan | `/settings/plan` | Modul Wochenplan an | Standard-Portionen, Ziel-Liste, "Hast du meistens da", Erinnerung | 14 Kap. 12 |
| Avo | `/settings/avo` | Modul Avo an | Stimme, Sprachausgabe, Gespräch löschen, was Avo einbeziehen darf | 16 Kap. 13 |
| Siri & Kurzbefehle | `/settings/siri` | immer | verfügbare Sätze mit "{app}", Action Button, Link zur Kurzbefehle-App | 19 |
| Widgets | `/settings/widgets` | immer | Vorschau der Widget-Arten, Anleitung zum Hinzufügen | 19 |

Regeln für diese Seiten aus Sicht des Profils:
- Ohne Pro-Kennzeichnung, außer die Seite schaltet eine Pro-Funktion frei (z. B. Apple Health, falls Pro): dann `ProBadge` hinter der Zeile in der Seite, nie hinter der Zeile im Profil.
- Die Mitteilungs-Schalter der Module stehen einmal in Mitteilungen (5.5, Sektion "Module"); die Modulseiten verlinken dorthin oder zeigen denselben Schalter (eine Einstellung, zwei Orte).
- Avo-Schlüssel: `offers_*`, `region`, `favorite_stores`, `health_*`, `plan_*`, `avo_voice`, `avo_speech` (Teil B registriert, Teil A sorgt für die Sichtbarkeit nach Regel 3).

---
## 7. Konto, Abmelden, Konto löschen

### 7.1 Konto (`/settings/account`)

- **Hauptfrage:** Mit welchem Konto bin ich angemeldet, und wie komme ich raus?
- **Wann:** Profil > Konto; Profil bearbeiten > "Konto"; Hilfe ("Wie lösche ich mein Konto?"); Suche ("abmelden", "löschen", "E-Mail", "Passwort").
- **Aufbau:**
  1. Sektion ohne Titel: `ValueRow` "E-Mail" "jannis.d@beispiel.de"; `ValueRow` "Angemeldet mit" "Apple" (Symbol `apple.logo` nur als Text-Symbol der Systemschrift, keine Marke als Bild). Für E-Mail-Konten zusätzlich `NavRow` "E-Mail ändern" (neue Adresse, dann 6-stelliger Code, Vollbild-Push wie Onboarding 17 Kap. 3.7) und `NavRow` "Passwort" mit Wert "Nicht festgelegt" bzw. "Festgelegt" (F-17-01).
  2. Sektion ohne Titel: `NavRow` "Daten exportieren" (Unterzeile "Listen, Rezepte und Verlauf als Datei", F18-07; nur wenn der Owner zustimmt).
  3. Sektion ohne Titel: destruktive Zeile "Abmelden" (Text `danger`, zentriert wie in iOS).
  4. Sektion ohne Titel: destruktive Zeile "Konto löschen" (Text `danger`) > 7.3. Fuß: "Löscht dein Konto und deine Daten endgültig."
- **Zustände:** Offline: "Abmelden" geht (lokal); "Konto löschen" und "E-Mail ändern" zeigen beim Öffnen "Braucht eine Verbindung" am Ort. Pro: nie gesperrt.
- **AX / 320 pt:** Werte unter den Titel; E-Mail bricht an "@" um.
- **Änderung, Dateien:** neu `profile/settings/account_screen.dart`. Abmelden war ein umrandeter roter 52-pt-Knopf ohne Rückfrage und ohne Fehlerbehandlung am Ende des Profils.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, großer Titel "Konto". Weiße Gruppe mit "E-Mail" und grauem Wert "jannis.d@beispiel.de", "Angemeldet mit" und grauem Wert "Apple". Darunter eine einzelne weiße Zeile mit zentriertem rotem Text "Abmelden" #D70015, darunter eine weitere einzelne Zeile "Konto löschen" in Rot mit grauer Fußnote "Löscht dein Konto und deine Daten endgültig."

### 7.2 Abmelden

- Tippen auf "Abmelden": Gibt es ungesendete Änderungen (Warteschlange nicht leer), zuerst `confirmDestructive`: Titel "Abmelden?", Nachricht "3 Änderungen sind noch nicht gesendet und gehen verloren, wenn du dich jetzt abmeldest.", Knöpfe "Abbrechen" und rot "Abmelden". Sonst ohne Rückfrage (umkehrbar durch Anmelden, 00 12.34).
- Ablauf: Knopf zeigt "Abmelden" mit kleinem Fortschritt (Breite bleibt), dann Überblendung zu `/welcome` in der Variante "Anmelden" (17 Kap. 3.2). Kein Erfolgsmoment.
- Aufräumen: Widget-Daten, Offline-Cache, Erinnerungen, Kategorie-Cache (heute schon), **zusätzlich** alle kontogebundenen lokalen Werte (Module, Mitteilungs-Kategorien, Region, Lieblingsmärkte, Pro-Cache, Avo-Gespräch, Tipp-Zähler, Pro-Hinweis-Zähler). Gerätebezogen bleiben: Darstellung und Sprache (heute bleiben auch Kalorien-Schalter und PLZ für das nächste Konto stehen, Inventar 4.6). FCM-Token des Geräts wird entfernt.
- Fehler beim Abmelden am Server: lokal trotzdem abmelden (Sitzung verwerfen), Token-Entfernung beim nächsten Start nachholen. Kein Fehlerdialog.

### 7.3 Konto löschen (`/settings/account/delete`)

- **Hauptfrage:** Was passiert mit meinen Daten, wenn ich mein Konto lösche?
- **Wann:** Konto > "Konto löschen"; Hilfe; Avo ("Lösch mein Konto": Avo führt nicht aus, sondern zeigt die Ergebniszeile "Konto löschen geht nur in den Einstellungen · Öffnen", weil es endgültig ist und eine erneute Anmeldung braucht).
- **Pflicht:** App Store Richtlinie 5.1.1(v): Löschung in der App, nicht nur per Mail; bei "Mit Apple anmelden" Widerruf des Apple-Tokens über die REST-API; Hinweis auf laufende Abos.
- **Aufbau (Vollbild-Push, Inline-Titel "Konto löschen", Glas-Zurück):**
  1. Satz (`body`, `label`): "Dein Konto und alles, was nur dir gehört, wird endgültig gelöscht. Das lässt sich nicht rückgängig machen."
  2. Sektion "Was gelöscht wird" (Zeilen aus echten Zahlen des Kontos, `ValueRow` mit Symbol): `checklist` "3 Listen, die nur dir gehören"; `fork.knife` "2 eigene Rezepte, davon 1 veröffentlicht"; `clock.arrow.circlepath` "Verlauf mit 41 Einkäufen"; `person.crop.circle` "Profil, Foto und Einstellungen". Mit Modul Kalorien: `flame` "Kalorien-Tagebuch"; Daten in Apple Health bleiben in Health (Fuß).
  3. Sektion "Geteilte Listen": "Wocheneinkauf geht an Lena über." (Liste mit Mitgliedern wechselt an das am längsten beteiligte Mitglied; F18-08). Für Listen, in denen man nur Mitglied ist: "Du verlässt 1 geteilte Liste. Was du dort hinzugefügt hast, bleibt für die anderen ohne deinen Namen."
  4. Nur mit Pro (nicht über Familie): `StatusRow` mit `exclamationmark.triangle.fill` in `warning`: "Dein {pro}-Abo läuft weiter, bis du es bei Apple kündigst. Es verlängert sich am 7. Nov. 2027." und grauer Button "Abo verwalten" (Systemblatt). Offene Beträge (Modul Kosten teilen): Zeile "2 offene Beträge werden für die anderen als beglichen markiert."
  5. Prominent in `danger` (gefüllt erlaubt, weil Löschen-Rückfrage, 00 12.20): "Konto löschen". Darunter schlicht "Abbrechen".
- **Ablauf:**
  1. "Konto löschen" verlangt eine frische Anmeldung (unter 5 Minuten alt): Apple bzw. Google als Systemabfrage, E-Mail-Konten bekommen einen Code (Vollbild-Schritt wie 17 Kap. 3.7, Titel "Bestätige, dass du es bist").
  2. Danach `confirmDestructive`: Titel "Konto endgültig löschen?", Nachricht "Jannis, dein Konto und deine Daten werden gelöscht. Wocheneinkauf geht an Lena über.", Knöpfe "Abbrechen" und rot "Löschen".
  3. Löschen läuft: Knopf zeigt Fortschritt, Zurück und Knöpfe deaktiviert. Edge Function `delete-account` (Teil A, 12.4 E18-09) erledigt alles serverseitig in einem Aufruf.
  4. Erfolg: Überblendung zu Willkommen (17 Kap. 3.2) mit `StatusRow` "Dein Konto wurde gelöscht." Kein Maskottchen, kein Erfolgsmoment, keine Haptik außer Erfolg (00 11).
  5. Fehler: Seite bleibt, `StatusRow` oben "Das Löschen hat nicht geklappt. Es wurde nichts gelöscht. Erneut versuchen" und Fehler-Haptik. Teilweise Löschung darf es nicht geben (Transaktion).
- **Zustände:** Lädt: Zahlen kommen aus dem lokalen Stand; fehlt einer (Verlauf nie geladen), steht die Zeile ohne Zahl ("Dein Verlauf"). Offline: Satz und Zeilen sichtbar, `StatusRow` "Braucht eine Verbindung.", Knopf deaktiviert. Modul aus: Kalorien-Zeile entfällt bzw. bleibt, wenn Daten da sind ("Kalorien-Tagebuch (ausgeschaltet)"). Pro: siehe Punkt 4.
- **Bewegung, Haptik:** Push normal; Fehler-Haptik bei Fehler; Erfolg-Haptik beim Abschluss.
- **AX / 320 pt:** Zeilen stapeln, der rote Knopf bricht um und wächst; "Abbrechen" darunter (nie nebeneinander).
- **Änderung, Dateien:** neu (heute fehlt die Funktion, Inventar 4.1). Neu: `profile/settings/delete_account_screen.dart`, Edge Function `supabase/functions/delete-account`, Apple-Token-Widerruf, Löschung des Speicher-Ordners im Bucket `profile-pictures`.
- **Bildbeschreibung für ChatGPT:** iPhone-Screenshot hell, #F2F2F7, oben Glas-Zurück und klein "Konto löschen". Schwarzer Absatz "Dein Konto und alles, was nur dir gehört, wird endgültig gelöscht. Das lässt sich nicht rückgängig machen." Weiße Gruppe "Was gelöscht wird" mit vier Zeilen und grauen Symbolen: "3 Listen, die nur dir gehören", "2 eigene Rezepte, davon 1 veröffentlicht", "Verlauf mit 41 Einkäufen", "Profil, Foto und Einstellungen". Gruppe "Geteilte Listen" mit "Wocheneinkauf geht an Lena über." Eine weiße Zeile mit orangem Warndreieck #A85400: "Dein Avo-Pro-Abo läuft weiter, bis du es bei Apple kündigst." und grauer Kapsel "Abo verwalten". Unten eine volle breite rote Kapsel #D70015 mit weißem Text "Konto löschen" und darunter grüner Text "Abbrechen". Kein Maskottchen.

---

## 8. Paywall (`/pro`, `?feature=<id>`)

### 8.1 Zweck und Einstieg

- **Hauptfrage:** Lohnt sich {pro} für mich, und was kostet es genau?
- **Wann:** Tipp auf eine `ProBadge` oder eine gesperrte Pro-Aktion (9.2); "Ansehen" in einer kontextuellen Hinweis-Zeile oder einem Sektionsfuß (9.3); Avo-Ergebniszeile "Mit {pro} verfügbar · Ansehen"; Profil > {pro}; Deep Link `shoply://pro`; Siri/Avo ("Was kostet Pro?" öffnet nach der Antwort auf Wunsch die Paywall). Nie von selbst, nie beim Start, nie im Onboarding, nie im Einkaufs- oder Kochmodus ohne Tipp auf eine Pro-Aktion.

### 8.2 Form (Abweichung von 00 12.31 wegen der Owner-Regel)

Vollbild-Seite, die **aus dem auslösenden Element wächst** (Zoom-Übergang, `springMorph`): Ursprung ist die Zeile, die Kapsel oder der Knopf, den man angetippt hat; beim Schließen schrumpft sie dorthin zurück. Kein Sheet, kein Hochschieben von unten. Ohne Ursprung (Deep Link, Avo-Sprachantwort) wächst sie aus der Bildschirmmitte von 0,96 auf 1 mit Deckkraft. Tab-Bar und Avo-Kreis sind ausgeblendet (01 3). Schließen: `xmark` oben links (sofort sichtbar, K-23) oder Zurück-Wischen vom linken Rand, das der Hand 1:1 folgt und die Seite zum Ursprung schrumpfen lässt (wie die Zoom-Navigation von iOS 18). Hintergrund `bgGrouped`, `radiusSheetFull` entfällt (Vollbild mit Geräteecken).

### 8.3 Aufbau von oben nach unten

1. **Schließen:** Glas-Knopf `xmark` (44 pt) oben links über dem Foto, Glas-Variante `clear` mit Verlauf am oberen Bildrand (00 8.2). Keine weitere Toolbar.
2. **`PaywallHero`:** eigenes, kuratiertes Essensfoto 16:10 randlos bis unter die Statusleiste (F-07), mit `photo_color` als erster Fläche; unten weicher Verlauf in `bgGrouped`. Ab AX1 2:1, ab AX3 entfällt das Foto (Inhalt vor Schmuck).
3. **Titel:** "{pro}" (`title1`, `label`), darunter ein Satz Nutzen (`body`, `label`), Text legt der Owner fest; Vorschlag: "Mehr Zeit beim Planen, weniger beim Einkaufen."
4. **Vorteile** (`InsetSection` ohne Titel, `ProFeatureRow`s aus `pro_features`, sortiert nach `order`): Symbol 22 pt Medium in `action`, frei; Titel `headline`; ein Satz `subheadline` `labelSecondary`. Kommt man über ein Feature (`?feature=meal_plan`), steht es oben, mit `actionFill` hinterlegt und einer zweiten Unterzeile in `label`, was gleich passiert: "Danach kommen deine 17 Zutaten auf Wocheneinkauf." Höchstens 5 Zeilen; weitere hinter schlicht "Alle Vorteile" (klappt auf).
5. **Pläne** (`InsetSection` "Plan wählen", Auswahlgruppe, `PlanRow`s):
   - "Jährlich" · "29,99 € pro Jahr · 2,50 € im Monat", rechts Kapsel "16 % günstiger" (`caption2` Semibold, `action` auf `actionFill`, aus den StoreKit-Preisen berechnet und abgerundet; fehlt einer der Preise, entfällt die Kapsel).
   - "Monatlich" · "2,99 € im Monat".
   - Gewählt: `checkmark.circle.fill` in `action` links, sonst Ring `controlOutline` (gleiches Bild wie `SelectCircle`, 12 Kap. 15 E-08). Jährlich vorausgewählt. Ganze Zeile ist die Trefferfläche.
6. **`TrialTimeline`** (nur bei Testphasen-Berechtigung, eigene Sektion "So läuft die Testphase"): drei Punkte auf 2-pt-Linie in `fill`, Punkt 1 gefüllt `action`: "Heute: Alles freigeschaltet" · "Do., 19. Nov.: Erinnerung per Mitteilung" · "Sa., 21. Nov.: Abo beginnt, 29,99 €". Monatlich gewählt: letzter Punkt "… Abo beginnt, 2,99 € im Monat". Sind Mitteilungen in iOS aus, heißt Punkt 2 "Do., 19. Nov.: Hinweis in der App" (die Zusage muss einlösbar sein). Daten aus dem Kaufdatum plus Testdauer aus StoreKit, nicht fest 14.
7. **Aktionsleiste** (angeheftet unten auf `bgGrouped` mit Scroll-Edge-Verlauf, kein Glas; Regel aus 17 Kap. 9.1: angeheftet, solange sie höchstens 25 % der Höhe braucht, sonst im Fluss am Ende):
   - Prominent `AppButton`: "14 Tage gratis testen" bzw. "Abonnieren" (Testphase genutzt) bzw. "Für 2,99 € im Monat abonnieren" (Monatlich ohne Test). Einzige gefüllte Akzent-Kapsel.
   - Fußnote (`footnote`, `labelSecondary`): "Danach 29,99 € pro Jahr. Verlängert sich automatisch. Jederzeit in den iPhone-Einstellungen kündbar."
   - Links (schlicht, `footnote`, je Trefferfläche 44): "Käufe wiederherstellen · Nutzungsbedingungen · Datenschutz" (App Review 3.1.2). Nutzungsbedingungen und Datenschutz öffnen den In-App-Browser als Push auf der Paywall (5.9).
8. Mit Familienfreigabe (F-11): Zeile unter den Plänen "Mit der Familienfreigabe für bis zu 5 weitere Personen" (`subheadline`, `label`, Symbol `person.2`).

Verboten (00 12.31, 16.5): Countdown, durchgestrichene Preise, verzögertes `xmark`, Maskottchen, Angebote als Vorteil, Bewertungssterne oder Nutzerzahlen ohne Beleg, "Beste Wahl"-Großbuchstaben.

### 8.4 Beispielinhalt (aus dem Wochenplan)

`xmark` · Foto: Ofengemüse mit Feta auf einem Blech, von oben · **Avo Pro** · "Mehr Zeit beim Planen, weniger beim Einkaufen." · Vorteile: [hinterlegt] `calendar` "Wochenplan auf die Liste" / "Alle Zutaten der Woche mit einem Tipp, zusammengefasst." / "Danach kommen deine 17 Zutaten auf Wocheneinkauf." · `waveform` "Avo mit Stimme" / "Sprich mit Avo, er antwortet mit Stimme." · `heart` "Kalorien mit Apple Health" / "Essen, Gewicht und Workouts in Health." · `chart.bar` "Monatsrückblick" / "Deine Einkäufe und Ausgaben über sechs Monate." · `frying.pan` "Kochmodus" / "Schritt für Schritt mit Timern, Bildschirm bleibt an." · Plan wählen: (●) Jährlich 29,99 € pro Jahr · 2,50 € im Monat [16 % günstiger] / ( ) Monatlich 2,99 € im Monat · So läuft die Testphase: Heute / Do., 19. Nov. / Sa., 21. Nov. · [14 Tage gratis testen] · Fußnote · Links.

### 8.5 Zustände

| Zustand | Bild |
|---|---|
| Produkte laden, Preise im Cache | Preise aus dem letzten erfolgreichen Abruf sofort (lokal gespeichert mit Ländercode), Abgleich im Hintergrund; ändern sie sich, rollen die Ziffern (`RollingNumber`). Hauptaktion aktiv, sobald StoreKit die Produkte liefert (meist vor dem ersten Blick), bis dahin deaktiviert mit gleicher Beschriftung. Kein Spinner. |
| Produkte laden, kein Cache (erste Öffnung) | Preise als "…" im reservierten Platz (gleiche Zeilenhöhe), "16 % günstiger" ausgeblendet ohne Lücke (Kapsel erscheint mit `fadeReduced`), Zeitleiste ohne Datum ("Tag 12", "Tag 14"), Hauptaktion deaktiviert. |
| Fehler beim Laden | `StatusRow` über den Plänen: "Der App Store ist gerade nicht erreichbar. Erneut versuchen" (schlicht, lädt neu). Pläne zeigen den Cache, wenn vorhanden, sonst "…". Nie ewig "Lade Abo-Optionen …" (heute). |
| Offline | `StatusRow` "Offline. Für den Kauf brauchst du eine Verbindung." Vorteile und gecachte Preise sichtbar, Hauptaktion deaktiviert. |
| Kauf läuft | Hauptaktion zeigt Fortschritt (Breite bleibt), Pläne, Links und `xmark` deaktiviert, bis StoreKit antwortet (heute bleibt X aktiv). Das System-Kaufblatt liegt darüber. |
| Abbruch im Kaufblatt | sofort zurück in den Ausgangszustand, keine Meldung. |
| Kauf fehlgeschlagen | `StatusRow` "Der Kauf hat nicht geklappt. Es wurde nichts abgebucht. Erneut versuchen", Fehler-Haptik. Nie roher StoreKit-Text (heute englisch in roter SnackBar). |
| Ausstehend (Kaufen anfragen) | Hauptaktion ersetzt durch Zeile `clock` "Wartet auf Freigabe. Sobald zugestimmt ist, wird {pro} aktiv." Profilzeile zeigt dasselbe. Mitteilung bei Freigabe. |
| Erfolg | 8.7 |
| Testphase genutzt | `TrialTimeline` entfällt, statt ihrer Satz "Die Testphase hast du schon genutzt." Hauptaktion "Abonnieren". Berechtigung aus StoreKit (`isEligibleForIntroOffer`), nicht geraten (heute immer "14 Tage gratis"). |
| Schon Pro | 8.6 |
| Pro-Status unbekannt | Paywall zeigt den Kaufzustand; kauft man, prüft StoreKit selbst ("Du hast dieses Abo bereits" wird als Wiederherstellen behandelt, Ergebnis wie 8.7). |
| Modul aus | Vorteile von Modulen, die aus sind, stehen trotzdem in der Liste (man kauft für die App), mit Unterzeile "Schaltest du unter Module ein." Kommt man über ein Feature, ist das Modul ohnehin an. |
| Kill-Switch | ohne Wirkung (Angebote sind nie Vorteil). |

### 8.6 Zustand "Du hast {pro}" (Status und Verwaltung)

- Gleiche Seite, gleicher Ursprung, kein Kauf: Foto, Titel "Du hast {pro}", Status in `body`: "Jährlich · verlängert sich am 7. Nov. 2027" bzw. "Testphase bis Sa., 21. Nov. · danach 29,99 € pro Jahr" bzw. "Gekündigt · aktiv bis 7. Nov. 2027" bzw. "Über die Familienfreigabe von Lena".
- Vorteile ohne Hervorhebung (Übersicht, was enthalten ist).
- Grauer Button "Abo verwalten" (System-Verwaltungsblatt von Apple; eigene Anzeige ist das nicht, deshalb keine Regelfrage). Fehlt bei Familienfreigabe.
- Zahlung fehlgeschlagen: `StatusRow` mit `warning` "Die letzte Zahlung hat nicht geklappt. {pro} bleibt bis 14. Nov. aktiv." plus "Zahlungsdaten prüfen" (Systemblatt).
- Links unten: "Käufe wiederherstellen · Nutzungsbedingungen · Datenschutz".

### 8.7 Erfolg und Fortsetzung

1. StoreKit meldet den Kauf, der Server bestätigt ihn (Belegprüfung, 12.4 E18-10). Bis zur Bestätigung zeigt die Hauptaktion Fortschritt; spätestens nach 5 s gilt die lokale StoreKit-Berechtigung (Transaktion ist von Apple signiert), der Server gleicht nach.
2. Die Paywall schrumpft zurück zum Ursprung (`springMorph`).
3. Danach `SuccessMoment` mit feierndem Maskottchen (Pose "feiernd" ist für "Pro gekauft" erlaubt, 00 3.3), Titel "{pro} ist aktiv.", Unterzeile "Testphase bis Sa., 21. Nov." bzw. "Jährlich, verlängert sich am 7. Nov. 2027"; Erfolgs-Haptik im selben Frame; 1,5 s.
4. Die ursprünglich gewünschte Aktion läuft weiter, ohne erneutes Tippen: "17 Zutaten zu Wocheneinkauf · Widerrufen" (Wochenplan), der Sprachmodus beginnt zuzuhören, der Kochmodus geht auf Schritt 2. Grundlage ist `ProGate` (12.4 E18-02).
5. Kam man ohne Feature (Profil), entfällt Schritt 4; die Pro-Zeile im Profil zeigt den neuen Status.
6. Lokale Erinnerung für Tag 12 wird geplant (nur Testphase): "Deine {pro}-Testphase endet übermorgen. Danach 29,99 € pro Jahr." Tippen öffnet 8.6. Ohne Mitteilungs-Erlaubnis: einmalige Hinweis-Zeile auf der Startseite am Tag 12.

### 8.8 Wiederherstellen

- "Käufe wiederherstellen" zeigt Fortschritt am Link selbst (Text bleibt, kleiner Indikator davor), sonst bleibt alles bedienbar.
- Ergebnis als schwebender Status-Hinweis (`UndoToast`, reiner Status): "{pro} wiederhergestellt." (dann wie 8.7 ohne Maskottchen, Paywall wechselt zu 8.6) bzw. "Kein Abo für diese Apple-ID gefunden." bzw. bei Fehler `StatusRow` "Wiederherstellen hat nicht geklappt. Erneut versuchen".
- Abgelaufene Abos werden nicht als neu gekauft gewertet (heute schenkt Wiederherstellen eine volle Laufzeit, Inventar 4.4); keine feste Wartezeit von 2 s.

### 8.9 Interaktionen, Bewegung, Haptik

- Öffnen und Schließen: `springMorph` aus dem Ursprung und zurück, unterbrechbar; Zurück-Wischen 1:1 mit Wurfprojektion (loslassen über 30 % oder mit Schwung schließt, `springFling`). Reduce Motion: Überblendung (`fadeReduced`).
- Plan wählen: Kreis füllt sich mit `springQuick`; Fußnote, Zeitleiste und Button-Text wechseln mit rollenden Ziffern bzw. Überblendung. Keine Haptik.
- Haptik nur bei Erfolg (Kauf, Wiederherstellen) und Fehler.
- VoiceOver: Fokus startet auf dem Titel, nicht auf dem Foto (dekorativ); Pläne als Auswahlgruppe ("Jährlich, 29,99 Euro pro Jahr, 2,50 Euro im Monat, 16 Prozent günstiger, ausgewählt, 1 von 2"); Zeitleiste als Liste; `xmark` "Schließen"; Zwei-Finger-Z schließt.

### 8.10 Große Schrift (AX) und 320 pt

- 320 pt: Pläne untereinander mit Preis unter dem Plan-Namen (00 6.3), Kapsel "16 % günstiger" unter dem Preis; Zeitleiste einspaltig; Hauptaktion volle Breite.
- AX1+: Foto 2:1, ab AX3 ohne Foto; Vorteile zeigen nur Titel und Satz (Symbol bleibt, wächst bis AX2); Aktionsleiste ist nicht mehr angeheftet, sobald sie mehr als 25 % der Höhe bräuchte, und steht dann am Ende im Fluss; `xmark` bleibt immer oben sichtbar (schwebt). Kein Text wird abgeschnitten, die Fußnote bricht um.

### 8.11 Was sich gegenüber heute ändert, betroffene Dateien

- Vollbild-Material-Route mit Kicker "AVO PREMIUM", Serifen-Headline, zwei Plan-Karten nebeneinander (126 pt bei 320 pt), Badge "BESTE WAHL" mit negativem Versatz, Ink-Pille 54 pt, 24-pt-`X` ohne Polster, Spinner beim Laden und rohen Fehlern entfällt.
- Vorteile kommen aus `pro_features`, nicht aus festen Texten; "Angebote deiner Märkte" und "Unbegrenzt geteilte Listen" verschwinden als Versprechen (Angebote nie Pro; Teilen ist Kern).
- Neu: Zoom aus dem Ursprung, Fortsetzung der Aktion, Testphasen-Berechtigung, Zeitleiste, Links zu Nutzungsbedingungen und Datenschutz, Zustände ausstehend, schon Pro, Zahlung fehlgeschlagen.
- Dateien: `subscription/subscription_screen.dart` (neu `paywall_screen.dart` mit `PaywallHero`, `ProFeatureRow`, `PlanRow`, `TrialTimeline`), `showSubscriptionSheet()` wird `ProGate.open(context, feature:, origin:)` (Rückgabe `true` bei Erfolg bleibt für alte Aufrufer), `subscription_service.dart` (StoreKit 2, Berechtigung, Belegprüfung über Server, an Nutzer gebundener Cache), `subscription_provider.dart`, `app_translations.dart` (`premium_*` raus, `pro_*` mit `{pro}`), `avo_app_knowledge.dart` (liest `pro_features`).

### 8.12 Bildbeschreibung für ChatGPT

iPhone-17-Pro-Screenshot im hellen Modus, ohne Tab-Bar. Oben ein randloses Foto im Format 16:10 bis unter die Statusleiste: Ofengemüse mit Feta auf einem dunklen Blech, natürliches Tageslicht, von oben fotografiert; unten verläuft es weich in Hellgrau #F2F2F7. Oben links über dem Foto ein runder, klarer Liquid-Glass-Knopf mit X. Darunter linksbündig "Avo Pro" in SF Pro Bold 28 pt Schwarz und der Satz "Mehr Zeit beim Planen, weniger beim Einkaufen." in 17 pt Schwarz. Eine weiße Gruppe (Radius 26) mit fünf Vorteilszeilen, jeweils ein grünes SF Symbol #3F7A1F ohne Hintergrund, fetter schwarzer Titel und grauer Satz #636366; die erste Zeile "Wochenplan auf die Liste" ist hellgrün #EEF5E4 hinterlegt und hat eine zusätzliche schwarze Zeile "Danach kommen deine 17 Zutaten auf Wocheneinkauf." Darunter Gruppe "Plan wählen" mit zwei Zeilen: "Jährlich" mit grün gefülltem Häkchen-Kreis, "29,99 € pro Jahr · 2,50 € im Monat" und rechts einer kleinen hellgrünen Kapsel "16 % günstiger" mit grünem Text; "Monatlich", "2,99 € im Monat" mit leerem grauem Ring. Darunter eine Zeitleiste mit drei Punkten auf einer grauen Linie: "Heute: Alles freigeschaltet", "Do., 19. Nov.: Erinnerung per Mitteilung", "Sa., 21. Nov.: Abo beginnt, 29,99 €". Unten angeheftet eine volle breite grüne Kapsel #3F7A1F mit weißem "14 Tage gratis testen", darunter graue 13-pt-Fußnote "Danach 29,99 € pro Jahr. Verlängert sich automatisch. Jederzeit in den iPhone-Einstellungen kündbar." und eine Zeile grüner Links "Käufe wiederherstellen · Nutzungsbedingungen · Datenschutz". Kein Maskottchen, kein Countdown, keine durchgestrichenen Preise.

**Variante "Du hast Avo Pro" (dunkel):** gleiches Foto, Hintergrund Schwarz #000000, Titel "Du hast Avo Pro" in Weiß, darunter "Jährlich · verlängert sich am 7. Nov. 2027" in Weiß; dunkelgraue Gruppe #1C1C1E mit den Vorteilen und hellgrünen Symbolen #A6D45F; darunter eine graue Kapsel #2C2C2E mit weißem "Abo verwalten"; unten hellgrüne Links. Keine grüne Hauptaktion.

---
## 9. Pro-Flächen in der App

Ziel: Jedes Feature lässt sich durch einen Eintrag in `pro_features` (`is_pro = true`) zu Pro machen, ohne dass ein Screen neu gestaltet wird. Die Bereichskapitel beschreiben die Vorschau ihres Features (Wochenplan 14, Kalorien 15, Avo 16, Kochmodus 13); hier stehen die gemeinsamen Muster.

### 9.1 Kennzeichnung (`ProBadge`)

- Kapsel "Pro" hinter dem Feature-Namen (00 12.30): in Zeilen, Menüeinträgen, Sektionstiteln und auf der gesperrten Aktion selbst. Nie bei Angeboten, nie im Onboarding, nie im Einkaufsmodus (dort gibt es keine Pro-Funktionen), nie bei Pro-Nutzern.
- **Antippbar nur, wenn sie allein steht** (z. B. hinter einem Sektionstitel). In einer Zeile ist die Zeile das Ziel; die Kapsel ist dann Teil des Labels (sie ist nur 18 pt hoch, eine eigene Trefferfläche würde Fehltipps erzeugen, E18-03).
- Erscheint erst, wenn der Pro-Status bekannt ist (00 13). Wechselt der Status auf Pro, verschwinden alle Kapseln ohne Lücke mit `springStandard`.
- VoiceOver: ", Pro-Funktion" wird an das Label angehängt.
- **Bildbeschreibung für ChatGPT:** Ausschnitt einer weißen iOS-Gruppe auf #F2F2F7: Zeile mit grauem Kalender-Symbol, schwarzem Text "Wochenplan auf die Liste" und direkt dahinter einer kleinen hellgrünen Kapsel #EEF5E4 mit grünem Semibold-Text "Pro" #3F7A1F in 11 pt; rechts ein grauer Chevron.

### 9.2 Gesperrte Aktion mit echter Vorschau

- Der Bereich ist voll sichtbar und mit eigenen Daten benutzbar; gesperrt ist genau **eine** Aktion, die den Nutzen einlöst (Wochenplan: "17 Zutaten auf Wocheneinkauf"; Sprachmodus: Sprechen; Kochmodus: "Weiter" ab Schritt 1; Kalorien: "Mit Health verbinden"; Monatsrückblick: ältere Monate).
- Die Aktion behält ihre Beschriftung und ihre Form (auch getönt), dahinter `ProBadge`. Tippen öffnet die Paywall aus genau diesem Knopf mit `?feature=<id>`; nach dem Kauf läuft die Aktion weiter (8.7). Kein Schloss-Symbol, kein Schloss-Bildschirm, kein Ausgrauen.
- Abbruch (Paywall geschlossen): Die Aktion bleibt verfügbar, nichts ist verloren (der gefüllte Plan, das Foto, der Kochfortschritt bleiben).
- Avo: Bittet man Avo um eine Pro-Aktion, zeigt er die Ergebniszeile "Mit {pro} verfügbar · Ansehen" (Kapitel 16); "Ansehen" öffnet die Paywall aus der Zeile; nach dem Kauf führt Avo die Bitte aus.

### 9.3 Kontextuelle Hinweise

| Form | Wo | Text (Beispiel) | Aktion |
|---|---|---|---|
| Sektionsfuß | unter der Sektion, deren Inhalt Pro erweitern würde | "Mit {pro} kommen alle Zutaten der Woche mit einem Tipp auf die Liste." | schlicht "Ansehen" → Paywall aus dem Fuß |
| Hinweis-Zeile Startseite (Pro-Angebot) | Sektion "Für heute" (Kapitel 10, Hinweis-Zeile Nr. 9) | "14 Tage {pro} gratis testen" (`ProBadge` statt Symbol) | "Ansehen" → Paywall aus der Zeile |
| Avo-Ergebniszeile | im Avo-Verlauf | "Mit {pro} verfügbar" | "Ansehen" |

Regeln (00 16.5, verbindlich):
- Höchstens ein Hinweis pro Feature und Woche, höchstens einer pro Tag insgesamt (lokaler Zähler `ProHintCounter`, kontogebunden, beim Abmelden gelöscht).
- Das erste Pro-Angebot nur nach einem Aha-Moment (erster abgeschlossener Einkauf, erster Wochenplan auf der Liste), als Hinweis-Zeile, nie als Pop-up.
- Nie beim App-Start, nie im Onboarding, nie im Einkaufs- oder Kochmodus, nie in Sheets oder Alerts, nie bei Angeboten, nie bei unbekanntem Pro-Status, nie wenn die Testphase genutzt und das Abo vor weniger als 30 Tagen gekündigt wurde (F18-04).
- Wischen nach links "Nicht mehr zeigen" gilt dauerhaft für dieses Feature; Hilfe > "Tipps zurücksetzen" setzt Pro-Hinweise nicht zurück.
- Hinweise erscheinen erst beim nächsten Öffnen eines Screens, nie während man liest (00 12.12).
- Keine "Das hättest du mit Pro gespart"-Zahlen (Angebote nie Pro, keine erfundenen Zahlen).

### 9.4 Pro im Profil

Die Pro-Zeile (3.4) ist der ruhige, immer gleiche Ort für Status, Testphase und Verwaltung. Es gibt keine Pro-Karte, kein Banner und keine Pro-Kapsel im Avo-Kopf (heute "Premium", `avo_chat_widgets.dart`).

### 9.5 Pro-Kandidaten (Vorlage für die Owner-Entscheidung F-05)

| Kandidat | Warum Pro passt | Risiko | Vorschlag |
|---|---|---|---|
| Wochenplan auf die Liste | spart wöchentlich Zeit, klarer Aha-Moment | Plan ist auch Bindung für Free | Planen frei, "Auf die Liste" Pro |
| Avo mit Stimme | teuer im Betrieb (Sprache, starkes Modell) | Text-Avo muss frei gut sein | Sprachmodus Pro, Text frei |
| Kalorien mit Apple Health und Foto-Schätzung | Wert für Nutzer mit Ziel, Kosten pro Foto | Tagebuch selbst muss frei funktionieren | Health und Foto Pro, Tagebuch frei |
| Monatsrückblick über 6 Monate | Statistiken sind klassisch Pro | wenig Nutzen ohne Beträge | aktueller Monat frei, ältere Pro |
| Kochmodus | heute die einzige Sperre | wirkt kleinlich (F-10) | freigeben |
| Nie Pro | Listen, Teilen, Präsenz, Einkaufsmodus, Rezepte, Verlauf, Angebote, Allergien | – | frei |

### 9.6 Daten und Logik (Vorgaben)

- `pro_features` (Supabase, gecacht, Teil A): `id`, `symbol`, `title_key`, `body_key`, `order`, `is_pro`, optional `continue_key` (Satz "Danach …"). Avo-Wissen und Paywall lesen dieselbe Quelle. Ein Feature ohne `is_pro` zeigt nirgends eine Kapsel.
- `proFeatureProvider(id)` → `free | pro | locked` aus `pro_features` und dem Abo-Status; `ProGate` (E18-02) kapselt Prüfen, Paywall öffnen, Fortsetzen.
- Abo-Status: Quelle ist der Server (`users.subscription_status`, `subscription_expires_at`), bestätigt durch Belegprüfung mit Apples signierten Transaktionen (App Store Server API oder JWS-Prüfung in einer Edge Function) und App Store Server Notifications (Verlängerung, Kündigung, Kulanzzeit, Erstattung). Lokal: StoreKit-2-Berechtigung als schnelle Antwort. Der Cache ist an die Nutzer-ID gebunden.
- Sicherheit (Pflicht vor dem Start von Pro): `activate_subscription` darf nicht mehr vom Client mit eigenem Ablaufdatum aufrufbar sein (heute `SECURITY DEFINER` ohne `auth.uid()`-Prüfung, Inventar 4.4); Ablauf wird nie im Client geraten.
- Produkt-IDs bleiben `shoply_premium_monthly`, `shoply_premium_yearly` (00 3.1). Anzeigename immer `{pro}`.

---

## 10. Dialoge und Sonderzustände

### 10.1 Übersicht

| Dialog | Form | Titel / Text | Knöpfe |
|---|---|---|---|
| Abmelden mit ungesendeten Änderungen | `confirmDestructive` | "Abmelden?" / "3 Änderungen sind noch nicht gesendet und gehen verloren, wenn du dich jetzt abmeldest." | "Abbrechen", rot "Abmelden" |
| Konto endgültig löschen | `confirmDestructive` | "Konto endgültig löschen?" / "Jannis, dein Konto und deine Daten werden gelöscht. Wocheneinkauf geht an Lena über." | "Abbrechen", rot "Löschen" |
| Modul ist ausgeschaltet (Deep Link, Widget, Mitteilung, Siri auf eine Modul-Route) | zentrierter Alert (ersetzt das Modul-Sheet aus 00 13) | "Kalorien & Gesundheit ist ausgeschaltet" / "Schalte es ein, um Essen einzutragen. Deine Daten sind noch da." | "Nicht jetzt", "Einschalten" (fett, Standard) |
| Profilbild | Pull-down-Menü aus dem Avatar | – | "Foto auswählen", "Foto aufnehmen", "Foto entfernen" (rot) |
| Geschlecht, Liste beim Start | Pull-down-Menü aus dem Wert | – | Auswahl mit `checkmark` |
| Kauf | System-Kaufblatt (Apple) | – | – |
| Abo verwalten | System-Verwaltungsblatt (Apple) | – | – |

Es gibt in diesem Bereich **keinen** Dialog "Änderungen verwerfen?": Einstellungen wirken sofort, der Name übernimmt beim Verlassen.

### 10.2 Modul ist ausgeschaltet

- Nach "Einschalten": Modul an (wie 5.1), dann öffnet die ursprünglich angefragte Route (z. B. `/calories/add`). Nach "Nicht jetzt": man bleibt, wo man war; kam der Aufruf von außen (Widget, Siri), landet man auf der Liste von heute.
- Avo aus und Siri "Frag Avo": Alert "Avo ist ausgeschaltet" / "Schalte Avo ein, um ihn zu fragen."
- Kill-Switch Angebote: kein Alert, Fehlerseite ohne Hinweis auf Angebote (01 7).
- VoiceOver liest Titel und Text; "Einschalten" ist die Standardaktion.

**Bildbeschreibung für ChatGPT:** iPhone hell, dahinter abgedunkelt (Schwarz 20 %) die Liste "Wocheneinkauf". In der Mitte ein nativer iOS-Alert aus Glas mit fettem Titel "Kalorien & Gesundheit ist ausgeschaltet", darunter "Schalte es ein, um Essen einzutragen. Deine Daten sind noch da." und zwei Knöpfen nebeneinander: "Nicht jetzt" und fett "Einschalten" in Grün #3F7A1F.

### 10.3 Berechtigungen aus diesem Bereich

| Berechtigung | Auslöser | Erklärung am Ort | Abgelehnt |
|---|---|---|---|
| Mitteilungen | "Mitteilungen erlauben" in 5.5; Erinnerung einschalten; Testphase (Tag-12-Erinnerung) | Unterzeile der Zeile bzw. Zeitleiste ("Erinnerung per Mitteilung") | `StatusRow` "In Einstellungen erlauben"; Zeitleiste sagt "Hinweis in der App" |
| Kamera | "Foto aufnehmen" (4.3) | Menü-Unterzeile | `StatusRow` unter dem Avatar |
| Fotos | keine (System-Auswahl braucht keine Erlaubnis) | – | – |
| Standort, Health, Mikrofon | in den Seiten von Teil B | 12, 15, 16 | dort |

---

## 11. Abläufe

### 11.1 Einstellung über die Suche ändern (Region)

1. Tab Liste > Avatar oben rechts. Profil pusht, Tab-Bar bleibt.
2. Ins Suchfeld "plz" tippen. Sofort Treffer "Region" mit Pfad "Preise & Angebote › Region".
3. Tippen: Push "Preise & Angebote", die Zeile "Region" leuchtet kurz auf, dann öffnet sich die Region-Eingabe (12 Kap. 6.1).
4. "79100" eintragen, übernehmen. Wert in der Zeile und im Profil "79100 Freiburg"; alle Angebotsflächen nutzen sofort die neue Region.
5. Zurück zu den Treffern, Zurück zum Profil, Zurück zur Liste (oder Tab erneut tippen).

### 11.2 Modul ausschalten und wieder einschalten

1. Profil > Module > "Kalorien & Gesundheit" aus (falls an). Tab Kalorien verschwindet mit `springStandard` aus der Tab-Bar, unten "Kalorien ausgeschaltet · Widerrufen".
2. Die Zeile "Kalorien & Gesundheit" im Profil fehlt beim Zurückgehen; Apple-Health-Abgleich pausiert, Daten bleiben.
3. Später: Kalorien-Widget antippen → Alert "Kalorien & Gesundheit ist ausgeschaltet" → "Einschalten" → Tab erscheint, `/calories` öffnet mit dem alten Tagebuch.

### 11.3 Allergie eintragen

1. Tab Rezepte zeigt Tipp-Zeile T7 "Tipp: Stell Ernährung und Allergien ein …" > "Einstellen" (oder Profil > Ernährung & Allergien).
2. Chip "Erdnüsse" tippen: grün, sofort gespeichert (beide Felder, 17 Kap. 9.7).
3. Zurück zu Rezepten: Rezepte mit Erdnüssen zeigen beim nächsten Aufbau "Enthält Erdnuss" in `warning` mit Symbol; mit "Rezepte automatisch anpassen" schlägt das Rezept einen Ersatz vor. Avo kennt die Allergie ab der nächsten Nachricht.

### 11.4 Mitteilungen nachträglich erlauben

1. Profil zeigt bei Mitteilungen "In iOS aus" mit Warnsymbol.
2. Mitteilungen > `StatusRow` "In Einstellungen erlauben" > iOS-Einstellungen der App > Mitteilungen erlauben > zurück in die App.
3. Die Statuszeile verschwindet mit `springStandard`; die vorher gewählten Kategorien gelten sofort; Erinnerungen werden neu geplant.

### 11.5 Profilbild ändern und versehentlich entfernen

1. Profil > Kopfzeile > Profil bearbeiten > Avatar > "Foto auswählen" > Foto wählen > zuschneiden.
2. Neues Foto steht sofort; Sync-Zeichen am Avatar, bis der Upload fertig ist; geteilte Listen zeigen es danach.
3. Avatar > "Foto entfernen": Initialen, "Foto entfernt · Widerrufen". Widerrufen innerhalb von 4 s stellt das Foto ohne neuen Upload wieder her.

### 11.6 Pro aus einer gesperrten Aktion kaufen

1. Tab Plan, Woche gefüllt. Aktionsleiste "17 Zutaten auf Wocheneinkauf" trägt `ProBadge` (Wochenplan ist Pro, Beispiel).
2. Tippen: Paywall wächst aus der Aktionsleiste. "Wochenplan auf die Liste" steht oben, hinterlegt, mit "Danach kommen deine 17 Zutaten auf Wocheneinkauf."
3. Jährlich ist gewählt; Zeitleiste "Heute / Do., 19. Nov. / Sa., 21. Nov."
4. "14 Tage gratis testen" > System-Kaufblatt > Face ID.
5. Paywall schrumpft zur Aktionsleiste zurück; Erfolgsmoment "{pro} ist aktiv.", Erfolgs-Haptik.
6. Das Sheet "Zutaten der Woche" (14) öffnet sich bzw. die Zutaten landen auf der Liste; Rückgängig-Hinweis "17 Zutaten zu Wocheneinkauf · Widerrufen".
7. Do., 19. Nov., 9:00: Mitteilung "Deine {pro}-Testphase endet übermorgen. Danach 29,99 € pro Jahr."

Sonderfälle: Abbruch im Kaufblatt → Paywall bleibt, nichts passiert; Zurück-Wischen → Paywall schrumpft zur Leiste, der Plan ist unverändert. Ausstehend (Kind) → "Wartet auf Freigabe", die Leiste behält ihre Kapsel; nach Freigabe Mitteilung, beim nächsten Tipp läuft die Aktion direkt.

### 11.7 Pro verwalten und kündigen

1. Profil > {pro} ("Testphase bis Sa., 21. Nov.") > Paywall im Zustand "Du hast {pro}".
2. "Abo verwalten" > System-Verwaltungsblatt > kündigen.
3. Zurück: Status "Gekündigt · aktiv bis Sa., 21. Nov."; Profilzeile "Aktiv bis 21. Nov.". Keine Rückhalte-Dialoge, keine Rabatt-Angebote.
4. Nach Ablauf: Pro-Funktionen zeigen wieder ihre Kapseln; erstellte Inhalte (Plan, Einträge) bleiben sichtbar und nutzbar, nur die Pro-Aktion ist wieder gesperrt.

### 11.8 Käufe wiederherstellen (neues iPhone)

1. Profil > {pro} ("14 Tage gratis testen", Server kennt das Abo noch nicht, z. B. anderes Konto) > Paywall > "Käufe wiederherstellen".
2. Fortschritt am Link; Ergebnis "{pro} wiederhergestellt." und Wechsel zu "Du hast {pro}". Kein Abo: "Kein Abo für diese Apple-ID gefunden."

### 11.9 Abmelden

1. Profil > Konto > "Abmelden".
2. Ungesendete Änderungen: Alert, sonst direkt.
3. Überblendung zu Willkommen ("Anmelden"); kontogebundene lokale Werte sind gelöscht, Darstellung und Sprache bleiben.

### 11.10 Konto löschen

1. Profil > Konto > "Konto löschen". Seite zeigt, was gelöscht wird, dass Wocheneinkauf an Lena geht und dass das Abo bei Apple weiterläuft ("Abo verwalten").
2. "Konto löschen" > Bestätigen mit Apple (Face ID).
3. Alert "Konto endgültig löschen?" > "Löschen".
4. Fortschritt im Knopf; Erfolg: Willkommen mit "Dein Konto wurde gelöscht."; Lena sieht Wocheneinkauf weiter, Jannis' Avatar verschwindet aus der Liste, seine Artikel zeigen keinen Namen mehr.
5. Fehler: nichts gelöscht, `StatusRow` mit "Erneut versuchen".

### 11.11 Kontextuelles Pro-Angebot nach dem ersten Einkauf

1. Erster Einkauf abgeschlossen (01 10.4), Erfolgsmoment.
2. Beim nächsten Öffnen der Startseite (nicht sofort) steht in "Für heute" die Zeile "14 Tage {pro} gratis testen" mit `ProBadge` und "Ansehen".
3. Wischen "Nicht mehr zeigen" → kommt nie wieder; "Ansehen" → Paywall aus der Zeile ohne Feature oben; Schließen → Zeile bleibt für heute, danach höchstens wieder nach einer Woche (Regel 9.3).

---

## 12. Entscheidungen, offene Fragen, Ergänzungen zum Fundament

### 12.1 Entscheidungen dieses Kapitels

| Nr. | Entscheidung | Grund |
|---|---|---|
| K18-01 | Profil ist ein Vollbild-Push aus dem Avatar in den aktuellen Tab, kein großes Sheet; Einstellungsseiten sind weitere Pushes | Owner-Regel "keine Slider"; Push mit Zurück ist ausdrücklich erlaubt; dieselbe Seite taugt als Tab-Wurzel (D2) |
| K18-02 | Paywall als Vollbild mit Zoom-Übergang aus dem Element; Schließen per `xmark` oder Zurück-Wischen zum Ursprung | erfüllt "wächst aus dem Element" (00 16.2) ohne hereingleitendes Panel |
| K18-03 | Einstellungen wirken sofort; kein Speichern-Knopf; Name übernimmt beim Verlassen | iOS-Einstellungen-Muster; behebt Speichern-Pillen und verlorene Eingaben (Inventar 4.7) |
| K18-04 | Seitentitel "Profil" (nicht "Einstellungen"); Sektionen "App", "Module", "Für dich", "Allgemein", "iPhone", "Hilfe und Rechtliches", "Konto" | behebt doppeltes "Einstellungen"; Gruppierung nach Bedeutung |
| K18-05 | Allergien stehen vor der Ernährung und sind Chips mit sofortiger Wirkung | Sicherheit zuerst (Responsibility); gleiche Darstellung wie im Onboarding |
| K18-06 | Mitteilungs-Kategorien kontoweit gespeichert und serverseitig geprüft; Uhrzeiten wählbar; "Wochenzusammenfassung" entfällt | Inventar 4.6; heute wirken Kategorien nur lokal |
| K18-07 | Neuer Schalter "Anderen zeigen, dass ich einkaufe" (Standard an) | Präsenz ist personenbezogen; Agency |
| K18-08 | Konto löschen mit erneuter Anmeldung, Zusammenfassung aus echten Zahlen, Übergabe geteilter Listen, Alert am Ende, Edge Function als Transaktion | App Store 5.1.1(v); Mitglieder verlieren keine Liste |
| K18-09 | Abmelden löscht alle kontogebundenen lokalen Werte; Darstellung und Sprache bleiben | Inventar 4.6 (Werte des alten Kontos bleiben stehen) |
| K18-10 | Paywall zeigt Preise aus dem letzten StoreKit-Abruf sofort und gleicht im Hintergrund ab | "nie sichtbares Laden" ohne falsche Preise (Cache mit Ländercode) |
| K18-11 | Tag-12-Zusage der Zeitleiste passt sich der Mitteilungs-Erlaubnis an | jede Zusage muss einlösbar sein |
| K18-12 | `ProBadge` in Zeilen ist Teil des Labels, nicht eigene Trefferfläche | 18-pt-Kapsel unter 44 pt Trefferfläche |
| K18-13 | Keine Pro-Karte, keine Pro-Kapsel im Avo-Kopf; der einzige feste Pro-Ort ist die Profilzeile | Ruhe; gegen Banner (00 1.5) |
| K18-14 | Vorteile von ausgeschalteten Modulen bleiben auf der Paywall, mit Hinweis "Schaltest du unter Module ein" | man kauft für die App, nicht für den aktuellen Zustand |
| K18-15 | Rechtstexte und Anleitung im In-App-Browser als Push mit "In Safari öffnen" | kein von unten einfahrendes Safari-Fenster; Wayfinding |

### 12.2 Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| F18-01 | Navigationsmodell: Avatar in der Titelzeile (01, K-05) oder Tab "Profil" (D2 in `docs/DESIGN-STATUS.md`, 5 Tabs ohne Avatar)? | Das Kapitel funktioniert in beiden: Die Profilseite ist dieselbe, nur ihr Einstieg wechselt. Owner entscheidet zusammen mit F-17-06 |
| F18-02 | Gilt die Owner-Regel "keine Slider" auch für die Paywall, oder ist ein großes Sheet dort erlaubt? | Regel gilt; Zoom-Vollbild (K18-02) |
| F18-03 | Maskottchen im Erfolgsmoment "Pro gekauft": neu gezeichnet und flach (00 3.3) oder die echte 3D-Figur (`DESIGN-STATUS.md`, Commit f872961)? | Owner entscheidet einmal für die ganze App; dieses Kapitel nutzt nur die Pose "feiernd" |
| F18-04 | Nach Kündigung: 30 Tage keine Pro-Hinweise? Rückkehr-Angebot (Win-back-Angebot von StoreKit) erlaubt? | 30 Tage Pause; Win-back-Angebote später und nur über die Paywall, nie als Pop-up |
| F18-05 | Text des Nutzen-Satzes unter "{pro}" auf der Paywall (00 12.31 überlässt ihn dem Owner) | "Mehr Zeit beim Planen, weniger beim Einkaufen." |
| F18-06 | Eine Domain für Datenschutz, Impressum, Nutzungsbedingungen, Support (heute `joinavo.app` und `shoplyai.app` gemischt) | die Domain des finalen App-Namens (F-01) |
| F18-07 | Daten exportieren (DSGVO Art. 20) in der App anbieten oder per Support-Mail? | in der App als Datei (JSON plus lesbare CSV), Teil A; kann nach Version 1 kommen |
| F18-08 | Beim Konto löschen: Geteilte Listen an das am längsten beteiligte Mitglied übergeben oder für alle löschen? | übergeben; ohne andere Mitglieder löschen |
| F18-09 | Veröffentlichte Community-Rezepte beim Konto löschen: löschen oder anonymisiert behalten? | löschen (Daten der Person); Bewertungen anderer daran verfallen |
| F18-10 | Pro-Status bei Familienfreigabe: auch die Profilzeile "Aktiv über Familienfreigabe" ohne "Abo verwalten"? | ja |
| F18-11 | Persönliche Daten nur mit Modul Kalorien zeigen? | nein, Seite bleibt mit erklärendem Fuß (Avo kann die Werte setzen) |

### 12.3 Abweichungen von 00 und 01 wegen der Owner-Regel "keine Slider"

| Stelle in 00/01 | Dort | Hier |
|---|---|---|
| 01 4, 01 6 "Profil und Einstellungen als Sheet groß" | Sheet mit Suchfeld | Vollbild-Push aus dem Avatar mit Suchfeld (K18-01); Routen und Reihenfolge bleiben |
| 01 6, 01 7 Einstellungsseiten "Push im Sheet" | Push innerhalb eines Sheets | normaler Push im Tab |
| 00 12.31, 00 16.2, 01 10.10 Paywall "Sheet groß", "wächst als Sheet" | Sheet | Vollbild mit Zoom aus dem Element (K18-02) |
| 00 13, 01 7 "Modul-Sheet" | Sheet | zentrierter Alert (10.2), wie 17 Kap. 9.10 |
| 00 13 "Berechtigung nötig: kurzes Sheet" | Sheet | Erklärung am Ort (Unterzeile), dann Systemabfrage (10.3) |
| 00 12.23 Aktionsblatt "Änderungen verwerfen?" | Aktionsblatt | entfällt in diesem Bereich (K18-03) |
| 00 12.22 Einstellungszeilen | ohne Auswahl-Muster | Werte über Pull-down-Menü oder aufklappenden Picker in der Zeile (E18-04) |

### 12.4 Ergänzungen zum Fundament

| Nr. | Ergänzung | Inhalt | Wer |
|---|---|---|---|
| E18-01 | Symbole für 00 9.2 | `sparkles` ({pro}-Zeile), `person.text.rectangle` (Persönliche Daten), `person.crop.circle` (Konto), `photo` (Foto auswählen), `envelope` (Support, 17 9.3), `ant` (Fehler melden), `star` (Bewerten), `apple.logo` (Anmeldeweg, nur als Text-Symbol), `clock` (wartet auf Freigabe), `lightbulb` (Tipp, 17 9.3). `sparkles` auch in Paywall-Vorteilen erlaubt | A (Manifest) |
| E18-02 | `ProGate` | `ProGate.run(context, feature: 'meal_plan', origin: GlobalKey, onUnlocked: () {...})`: ist das Feature frei oder Pro aktiv, läuft `onUnlocked` sofort; sonst öffnet die Paywall aus `origin` mit `?feature=`, nach Erfolg läuft `onUnlocked` genau einmal; Abbruch tut nichts. Ersetzt `showSubscriptionSheet`. Liest `proFeatureProvider(id)` | A, B nutzt |
| E18-03 | `ProBadge` in Zeilen | Ergänzung zu 00 12.30: in Zeilen und auf Knöpfen Teil des Labels, keine eigene Trefferfläche; einzeln antippbar nur, wenn sie allein steht (K18-12) | A |
| E18-04 | `PickerRow` | Variante von `ValueRow`: Tippen klappt in der Zeile einen Rad-Picker (Zahl, Uhrzeit, Größe mit Einheit) auf (`springStandard`), erneutes Tippen klappt zu; ab AX3 Zahlenfeld mit Ziffernblock statt Rad; ersetzt jede Art von Schieberegler und Picker-Sheet. Und `MenuValueRow`: Wert mit `chevron.up.chevron.down`, Tippen öffnet `AppMenu` aus dem Wert | A |
| E18-05 | `ChipSection` | `InsetSection`-Variante, deren Inhalt ein `Wrap` aus `FilterChip`s mit Innenabstand 16 ist, plus optional schlicht "Weitere anzeigen" am Ende; gleiche Komponente in Onboarding (17 3.9) und Ernährung & Allergien | A |
| E18-06 | Zoom-Übergang (`ZoomRoute`) | Vollbild-Route, die aus einem `GlobalKey`-Ursprung wächst (`springMorph`), sich per Zurück-Wischen 1:1 zum Ursprung schrumpft, ohne Ursprung aus der Mitte von 0,96; Reduce Motion: Überblendung. Für Paywall und die Rezeptkarte (00 10.2) dieselbe Mechanik | A |
| E18-07 | `PlanRow`, `TrialTimeline` als eigene Komponenten | `PlanRow` = Auswahlzeile mit `SelectCircle` (12 Kap. 15 E-08), Titel, Preiszeile, optional Kapsel (gleiche Optik wie `ProBadge`, Text frei); `TrialTimeline` = senkrechte Punkte auf 2-pt-Linie in `fill`, erster Punkt `action`, Texte `body`/`subheadline` | A |
| E18-08 | `InAppBrowserPage` | Push mit Webinhalt unter `LargeTitleNavBar` (Inline-Titel), Toolbar `square.and.arrow.up` "In Safari öffnen"; offline `EmptyState` | A |
| E18-09 | Edge Function `delete-account` | löscht bzw. überträgt in einer Transaktion: Listen (Übergabe), Artikel-Zuordnung (Name entfernen), Rezepte, Verlauf, Kosten-Anteile (als beglichen), Kalorien-Daten, Geräte, Storage-Ordner, `auth.users`; widerruft das Apple-Token; Rückgabe ok oder Fehler ohne Teilzustand | A (Supabase) |
| E18-10 | Abo-Belegprüfung | Edge Function `verify-subscription` (signierte StoreKit-2-Transaktionen) und Endpunkt für App Store Server Notifications V2; `activate_subscription` nur noch vom Server; `users.subscription_status` um `in_grace_period`, `in_billing_retry`, `pending`, `family_shared` erweitern | A (Supabase) |
| E18-11 | Routen | `/settings/account/delete`, `/settings/legal/sources`, `/settings/legal/:doc` (`privacy`, `imprint`, `terms`, `licenses`), `/settings/profile` (Name, Foto) in 01 7 aufnehmen; `/settings/<seite>` baut den Stapel "aktiver Tab > Profil > Seite" | A |
| E18-12 | Einstellungs-Suchindex | `SettingsSearchEntry(route, titleKey, keywordsKeys, rowId)` je Seite und Zeile, beide Sprachen; B registriert seine Seiten (`offers`, `health`, `plan`, `avo`, `siri`, `widgets`); Kill-Switch filtert Angebots-Begriffe | A (Basis), B (Einträge) |
| E18-13 | Daten | `users.language` wieder schreiben; `user_notification_prefs` (Kategorien, Uhrzeiten) im Konto; `users.share_presence`; `user_preferences.accent_color`/`theme_variant` nicht mehr lesen; Bucket `profile-pictures` mit signierten URLs; `pro_features` (9.6) | A |
| E18-14 | Zeilen-Hervorhebung nach Suche | `InsetSection`-Zeilen bekommen einen Zustand "hervorgehoben" (`fillPressed`, blendet nach 1 s aus), ansteuerbar über `rowId` in der Route (`/settings/offers?row=region`) | A |
