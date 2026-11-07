# 20 Qualität: Tempo, Zustände und Geräte-Robustheit

Stand: 07.11.2026. Verbindlich für Teil A und Teil B. Baut auf `00-grundlagen.md` (Verweise "00 x.y") und `01-navigation-und-struktur.md` (Verweise "01 x.y") auf und ist mit den Bereichskapiteln 10 bis 18 abgestimmt (dortige Ergänzungen wie E10-03, E10-05, E-03, E-05 werden übernommen, nicht neu erfunden). Quellen: Plan 3, Verbesserungsliste 2 und 3, Inventare `perf.md` und `shell.md`.

**Besitz** (nach `arbeitsteilung.md`):
- **Teil A:** lokaler Stand und optimistische Updates für Listen, Artikel und Rezepte; die dauerhafte Schreib-Warteschlange (`offline_cache_service.dart` und neue Sync-Schicht); Eingabeleisten-Bug; Prüfgerüst `test/layout/`; `tool/design_check.sh`; Fehlerseite; Debug-Prüfansicht.
- **Teil B:** App-Start in `main.dart` (Dienste parallel oder bei Bedarf), Verbindungszustand (`connectivity_service.dart`), Timeouts im Supabase-Kern und bei KI, KI-Latenz, Push-Bündelung serverseitig, lokaler Stand für Kalorien, Wochenplan, Verlauf, Angebote und Avo.

**Owner-Regel "keine Slider" (`CLAUDE.md`, 07.11.2026) gilt in diesem Kapitel ohne Ausnahme:** keine Bottom-Sheets, keine halbhohen Modals, keine Drawer, keine Schieberegler. Alles, was hier entworfen wird, ist eine Zeile am Ort, ein zentrierter Alert, ein Pull-down-Menü oder ein Vollbild-Screen. Wo 00 und 01 für diesen Bereich ein Sheet nennen ("Modul-Sheet", "Vorab-Erklärung als Sheet"), steht hier dieselbe Lösung wie in Kapitel 17 (9.10). Die Abweichungen sind in Abschnitt 11 gesammelt.

Inhalt: 1 Überblick und Ziele · 2 Laden: lokaler Stand zuerst · 3 Schreiben: optimistisch und offline-fest · 4 Zustände als Oberflächen · 5 Leistungsbudget · 6 Geräte- und Schriftmatrix · 7 Prüfverfahren · 8 Was sich ändert (Dateien) · 9 Abläufe · 10 Offene Fragen · 11 Ergänzungen zum Fundament

---

## 1. Überblick und Ziele

### 1.1 Die eine Frage dieses Bereichs

"Ist die App sofort da, und stimmt sie auf meinem iPhone?" Jeder Screen der App muss beides beantworten, ohne dass jemand darüber nachdenkt. Dieser Bereich hat deshalb kaum eigene Screens; er legt die Regeln fest, nach denen alle anderen Screens laden, speichern, Fehler zeigen und sich bei jeder Breite und Schrift verhalten, und er legt fest, wie das geprüft wird.

### 1.2 Messbare Ziele

| Ziel | Messung | Wo geprüft |
|---|---|---|
| Kein sichtbares Laden beim zweiten Öffnen | Tab Liste, Alle Listen, Einkaufsmodus, Rezepte, Rezeptdetail aus Karte, Plan, Kalorien, Verlauf, Profil zeigen nach einem Kaltstart mit lokalem Stand im ersten Frame Inhalt; kein `CupertinoActivityIndicator`, kein Skelett | Widget-Test "Zweites Öffnen" (7.4), Gerät |
| Kein Vollbild-Spinner in der ganzen App | `tool/design_check.sh` findet 0 Spinner außerhalb von `AppButton` | Skript (7.8) |
| Keine Layout-Sprünge oberhalb der Leseposition | Sprungtest: Position der ersten sichtbaren Zeile vor und nach dem Abgleich gleich (Abweichung 0 pt) | Widget-Test (7.4) |
| Flüssig | iPhone 13 Pro, Profile-Modus: 90. Perzentil Build und Raster je höchstens 8,3 ms; kein einziger Frame über 16 ms in den Szenarien S1 bis S9 (5.1) | Messlauf (7.7) |
| Abhaken offline geht nie verloren | Abhaken im Flugmodus, App beenden, neu starten, Netz an: alle Häkchen auf dem Server | Verhaltenstest (7.4), Gerät |
| Ein Häkchen kostet einen Schreibaufruf | Netzprotokoll beim Abhaken einer privaten Liste: 1 Request vom Gerät (heute ca. 10) | Gerät mit Proxy bzw. Supabase-Logs |
| Kein abgeschnittener Text | Prüfmatrix (6.3) ohne Befund für jeden Screen aus 01 Kap. 5 | `test/layout/` (7.1 bis 7.3) |
| Bug der Mutter behoben | iPhone 13 Pro mit Anzeigezoom "Größerer Text", AX3, fetter Text: Eingabe "Artikel hinzufügen" vollständig lesbar | Geräte-Abnahme (7.6) |
| Start ohne Flackern | Kein Farbsprung zwischen Launch-Screen und erstem Frame; kein Neuaufbau der App nach dem ersten Frame (Zähler im Debug-Build: `AvoApp` wird genau einmal gebaut) | Gerät, Debug-Zähler |

Die Zeitwerte für den Start (5.5) sind Zielwerte. Sie werden nach der ersten Messung auf dem iPhone 13 Pro (Ausgangswert) bestätigt oder angepasst und mit Ist-Wert in der Status-Datei festgehalten.

### 1.3 Ursachen heute und die Antwort dieses Kapitels

| Ursache heute (`perf.md`) | Antwort | Abschnitt |
|---|---|---|
| Listen kommen beim Kaltstart immer zuerst aus dem Netz | Startstand vor `runApp`, Liste von heute aus dem lokalen Speicher | 2.1, 2.2 |
| Kein Schreiben ohne Netz, stilles Zurückspringen | dauerhafte Warteschlange, Sync-Zeichen, sichtbarer Fehler nur bei endgültigem Scheitern | 3.3, 3.4 |
| Remount der ganzen App nach dem ersten Frame | Theme und Sprache aus dem Startstand; Remount-Schlüssel entfällt | 2.2 |
| Inhalte springen nachträglich ins Layout | Hinweis-Zeilen stehen beim ersten Frame fest; Scroll-Anker; nachgeladene Inhalte nur unterhalb oder in reservierter Fläche | 2.4, 4.3 |
| Hinzufügen wartet auf die KI | lokales Parsen und lokale Kategorie sofort, KI bestätigt im Hintergrund | 3.5 |
| Ein Häkchen kostet etwa zehn Netzaufrufe | ein Schreibaufruf, Rest serverseitig, Realtime-Ereignisse als Patch statt Neuladen | 3.6 |
| Keine Timeouts, 62 Spinner | Timeouts auf jedem Netzaufruf, Zustandsregeln statt Spinner | 2.5, 4 |

---

## 2. Laden: lokaler Stand zuerst

### 2.1 Was lokal liegt

Zwei Speicher mit klar getrennten Aufgaben. SharedPreferences hält nur noch kleine Werte; große Blobs (heute alle Rezepte, alle Artikel, der Kategorie-Cache als ein String) wandern in Dateien.

| Speicher | Inhalt | Größe | Gelesen |
|---|---|---|---|
| **Startstand** (SharedPreferences, einmal vorgeladen) | Theme-Modus, Sprache, Module (inklusive Kill-Switch-Stand), Pro-Status (zuletzt bekannt, mit Datum), Onboarding erledigt, ID der Liste von heute, Liste "Beim Start zeigen", Zähler für Pro-Hinweise und Tipp-Zeilen, Hinweis-Zeilen für den nächsten Start | wenige KB | vor `runApp`, synchron danach |
| **Inhaltsspeicher** (Dateien in Application Support, pro Konto ein Ordner) | Listen mit Zählern und Metadaten, Artikel pro Liste, Mitglieder und Avatare (URLs), Reihenfolge im Markt, Rezepte (gespeicherte, eigene, zuletzt angesehene, Abschnitte des Rezepte-Tabs, höchstens 200), Wochenplan (aktuelle und nächste Woche), Kalorien-Tagebuch (heute und 14 Tage zurück), Verlauf (letzte 50 Einkäufe), Angebote pro Markt mit Gültigkeit, Avo-Gespräch (24 h), Kategorie-Zuordnungen | bis einige MB | Liste von heute vor `runApp`; Rest beim ersten Zugriff, im Hintergrund vorgewärmt |
| **Schreib-Warteschlange** (eine Journal-Datei im Kontoordner) | ausstehende Änderungen in Reihenfolge (3.3) | klein | vor `runApp` (Zähler für die `StatusRow`) |
| **Bild-Cache** (`cached_network_image`, Festplatte) | Rezeptfotos, Avatare, Produktfotos in Anzeigegröße | systemverwaltet | bei Bedarf |

Regeln:
- Jeder Kontoordner wird bei Abmelden und Kontowechsel vollständig gelöscht (heute `clearCache`, muss erhalten bleiben). Ausnahme: Ausstehende Änderungen; vor dem Abmelden gilt 4.10.
- Schreiben in den Inhaltsspeicher passiert gebündelt (höchstens alle 500 ms pro Datei) und atomar (in eine temporäre Datei schreiben, dann umbenennen), nie auf dem Pfad einer Geste.
- Der Kategorie-Cache bekommt eine Obergrenze (2.000 Einträge, zuletzt benutzt bleibt) und einen sprachunabhängigen Schlüssel (normalisierter Name), behebt `perf.md` 4.4 Punkt 6.
- Technik: Dateien mit JSON pro Liste und ein Journal sind ohne neues natives Paket möglich (`path_provider` direkt in `pubspec.yaml` aufnehmen; heute nur transitiv). Ob stattdessen eine Datenbank (sqflite/drift) kommt, ist offene Frage Q-01.

### 2.2 Start-Sequenz

**Vor `runApp`** (Teil B in `main.dart`, Bausteine von Teil A):
1. Hochformat setzen (wie heute).
2. Parallel: `SharedPreferences.getInstance()` (einmal, Ergebnis als Provider-Override), Supabase-Initialisierung mit gespeicherter Sitzung (ohne Netz), Startstand lesen, Journal der Warteschlange lesen.
3. Mit Sitzung: Kontoordner öffnen und die Artikel der Liste von heute lesen (eine Datei). Ohne Sitzung: Onboarding-Stand lesen (Kap. 17, 3.1).
4. `runApp` mit Provider-Overrides: `bootStateProvider` (Startstand), `localListSnapshotProvider` (Liste von heute), `syncQueueCountProvider`.

**Erster Frame:** sofort richtiges Theme (System, Hell oder Dunkel aus dem Startstand), richtige Sprache, richtige Tabs (Module), Pro-Status zuletzt bekannt, Tab Liste mit allen Artikeln der Liste von heute, Hinweis-Zeilen aus dem Startstand. Der Router entscheidet synchron (kein async `redirect` mehr für das Onboarding-Flag).

**Nach dem ersten Frame**, gestaffelt, damit die ersten Frames frei bleiben:

| Zeitpunkt | Aufgabe | Teil |
|---|---|---|
| sofort (Microtask) | Realtime für die Liste von heute verbinden; Warteschlange senden; Listen und Artikel der Liste von heute abgleichen | A |
| sofort | Firebase/Analytics, Crash-Reporting (falls eingerichtet, Q-07) | B |
| nach 1 s | übrige Listen und Rezepte-Tab-Abschnitte im Hintergrund vorwärmen; Kategorie-Zuordnungen laden | A |
| nach 2 s | `app_flags` (Kill-Switch), `pro_features`, Pro-Status vom Server; StoreKit-Produkte im Hintergrund holen (damit die Paywall selten "…" zeigt) | B, A |
| nach 3 s | Hinweis-Zeilen für den **nächsten** Start berechnen (Nachkauf, Prospekt, Kalorien-Hinweis, Beträge) | A ordnet, B liefert |
| bei Bedarf | Claude-Client, Foto-Analyse, Sprachdienste, Health, Standort | B |
| nie beim Start | Berechtigungsabfragen (Mitteilungen, Standort); sie kommen im Moment des Nutzens (00 Kap. 13) | B |

Was heute nach dem ersten Frame korrigiert wird (Theme hell, dann gespeichert, dann Server; Sprache; Kalorien-Tab; Pro-Status `unknown`), steht jetzt im ersten Frame richtig. Gibt der Server später einen anderen Theme-Wert zurück, gewinnt die in dieser Sitzung getroffene Wahl (wie heute); andernfalls wechselt das Theme mit Überblendung (`fadeReduced`) im `DesignScope`, ohne Neuaufbau (00 17.2).

### 2.3 Lade-Strategie je Screen

"Abgleich" heißt: im Hintergrund vom Server holen und als Unterschied in den lokalen Stand einspielen (2.4). "Ohne lokalen Stand" gilt nur beim allerersten Laden auf einem Gerät oder nach dem Löschen des Speichers.

| Screen | Erster Frame zeigt | Abgleich | Ohne lokalen Stand | Teil |
|---|---|---|---|---|
| Tab Liste (Liste von heute) | alle Artikel, Markt-Chip, Metazeile, Hinweis-Zeilen, "Vielleicht auch" aus dem Startstand | sofort nach dem ersten Frame, dann Realtime | Skelett (4.2), nach 10 s Vollflächen-Fehler | A |
| Titelmenü, Alle Listen | Listen mit offener Anzahl, Avatare, Ungelesen-Punkte | beim Öffnen, wenn der letzte Abgleich älter als 60 s ist | Skelett mit 4 Zeilen | A |
| Liste wechseln | die gewählte Liste aus dem Inhaltsspeicher (vorgewärmt); Überblendung | sofort, Realtime umhängen | Skelett im Inhalt, Titel schon richtig (Name aus der Listenzeile) | A |
| Einkaufsmodus | derselbe Stand wie die Liste, Gang-Reihenfolge aus dem Speicher | Realtime läuft weiter; Präsenz | nie (startet nur aus einer geladenen Liste) | A |
| Listen-Info, Teilen | Name, Farbe, Mitglieder, Schalter | beim Öffnen; "Zuletzt geändert" lädt unterhalb und blendet ein | Mitglieder-Sektion als Skelett | A |
| Tab Rezepte | alle Abschnitte aus dem Speicher; Fotos zuerst als `photo_color` | nach dem ersten Frame; Abschnitte werden nur ersetzt, wenn ihre Form gleich bleibt (Karten mit festem Seitenverhältnis); neue Abschnitte nur unterhalb | Skelett in Form der Abschnitte (Hero 16:10, Reihe 4:3) | A |
| Rezeptdetail | aus der angetippten Karte bzw. dem Speicher | Zutaten, Bewertung, Kommentare im Hintergrund | per Deep Link ohne Speicher: Foto-Fläche `fill`, Titel und Text als Skelett | A |
| Kochmodus | vollständig lokal | – | nie | A |
| Tab Plan | Woche aus dem Speicher | nach dem ersten Frame | Skelett der Tage (Kap. 14) | B |
| Tab Kalorien | Tag heute, Ziele, Ring | nach dem ersten Frame; Nachbartage (±7) vorgewärmt, Tageswechsel ohne Spinner | Skelett (Kap. 15) | B |
| Verlauf, Einkauf | letzte 50 Einkäufe | beim Öffnen | Skelett mit 5 Zeilen | B |
| Angebote der Woche | letzte Ergebnisse des Listen-Markts, nur noch gültige; Fußnote "Stand: Mo., 9. Nov." wenn älter als 6 h | beim Öffnen | Skelett; offline ohne Speicher: "Braucht eine Verbindung" (4.6) | B |
| Avo | Gespräch der letzten 24 h | Antworten gestreamt; Kern `denkt` statt Spinner | – | B |
| Profil und Einstellungen | alles aus Startstand und Speicher | Profil im Hintergrund | Name und E-Mail aus der Sitzung | A |
| Paywall | Feature-Liste aus `pro_features` (gecacht) | StoreKit-Produkte | Preise als "…" im reservierten Platz (00 12.31) | A |
| Widgets, Siri | App-Group-Schnappschuss | beim Abhaken im Widget, bei jedem Abgleich (gedrosselt, 2 s) | Widget: "Öffne {app}, um deine Liste zu sehen." | B |

### 2.4 Abgleich, Realtime und Rückkehr aus dem Hintergrund

**Unterschiede einspielen statt neu laden.** Ein Abgleich vergleicht Server- und lokalen Stand pro Zeile (ID, `updated_at`) und spielt nur Unterschiede ein:
- Neue Zeilen wachsen an ihrem Platz ein (`springStandard`), entfernte schrumpfen weg, geänderte ändern sich an Ort und Stelle (Zahlen rollen).
- Zeilen mit ausstehender eigener Änderung behalten den lokalen Wert, bis die Warteschlange sie bestätigt (heute `_pendingWrites`, bleibt).
- **Scroll-Anker (E10-05):** Liegt eine eingefügte oder entfernte Zeile oberhalb der ersten sichtbaren Zeile, wird der Scroll-Versatz um ihre Höhe ausgeglichen. Die Zeile, die man gerade liest, bewegt sich um 0 pt. Ausnahme: Steht man ganz oben (Versatz 0), wächst der Inhalt sichtbar ein.
- Hinweis-Zeilen der Startseite ändern sich nie während des Lesens; neue Werte gelten ab dem nächsten Öffnen des Tabs (00 12.12).

**Realtime.**
- Ein Kanal pro sichtbarer Liste (Artikel dieser Liste) und ein Kanal für die Listen des Nutzers, gefiltert auf seine Listen-IDs. Der heutige ungefilterte globale Kanal `db_changes` entfällt (`perf.md` 4.3 Punkt 9).
- Ereignisse werden als Patch in den lokalen Stand eingespielt, nicht als Anlass für ein komplettes Neuladen. Eigene Echos (Ereignis entspricht dem lokalen Stand) ändern nichts und kosten keinen Aufruf.
- Ereignisse werden 300 ms gebündelt (wie heute), damit fünf Häkchen von Lena als ein Rebuild ankommen.
- Präsenz über Realtime Presence ohne Tabelle (E-15 in Kap. 11).
- Bricht Realtime ab oder baut sich nicht innerhalb von 10 s auf, fragt die offene Liste alle 30 s ab, solange sie sichtbar ist (Polling-Rückfall), und versucht den Kanal mit wachsender Pause neu.

**Rückkehr aus dem Hintergrund** (`AppLifecycleState.resumed` nach mehr als 2 s, `perf.md` 4.3 Punkt 8):
1. Warteschlange senden.
2. Die sichtbare Liste vollständig holen (eine Abfrage, höchstens einige hundert Zeilen) und als Unterschied einspielen; Listen-Zähler holen.
3. Realtime-Kanäle neu verbinden.
4. Sichtbarer Tab Kalorien oder Plan: dasselbe für den sichtbaren Tag bzw. die Woche (B).
5. Hinweis-Zeilen für den nächsten Start neu berechnen.

Kein Indikator dabei. Ist man mehr als 30 Minuten weg gewesen und hat sich die Liste von heute nach 01 2.2 geändert (z. B. gelöscht), gilt 4.4 in Kap. 10 (Rückgängig-Hinweis ohne Aktion).

**Hintergrund-Tabs:** Nicht sichtbare Tabs beobachten keine teuren Provider (`TickerMode` aus, Abfragen pausiert, 00 17.8). Die Liste von heute bleibt im Speicher; ihr Realtime-Kanal bleibt verbunden, solange die App im Vordergrund ist, damit der Tab-Wechsel zurück nichts nachladen muss.

### 2.5 Netzregeln: Timeouts, Verbindungszustand, Wiederholung

**Timeouts** (zentral in `NetworkPolicy`, 11.6; kein Aufruf ohne Timeout):

| Aufruf | Timeout | Danach |
|---|---|---|
| Supabase lesen (Listen, Artikel, Rezepte, Plan, Kalorien, Verlauf) | 8 s | lokaler Stand bleibt; zählt für "Verbindung schlecht" |
| Supabase schreiben (über die Warteschlange) | 10 s | bleibt in der Warteschlange, Wiederholung nach Plan unten |
| Realtime-Aufbau | 10 s | Polling-Rückfall (2.4) |
| Claude-Kategorie (Edge Function) | 8 s | lokale Kategorie bleibt, kein Hinweis |
| Claude-Parse "2 Milch" | entfällt im Normalfall (lokal); nur bei unklarer Eingabe 6 s | lokales Ergebnis bleibt |
| Avo-Antwort | erstes Wort nach 8 s, gesamt 60 s | Zeile "Avo antwortet gerade nicht. Erneut versuchen" (Kap. 16) |
| Foto-Import, Essen-Foto | 30 s; Abbrechen ab Start sichtbar | "Das Foto konnte nicht gelesen werden. Erneut versuchen" |
| Angebote (marktguru, heute 12 s) | 12 s | Schilder entfallen still |
| StoreKit-Produkte | 10 s | Paywall-Zustand "App Store nicht erreichbar" (00 12.31) |
| Bilder | 15 s | `photo_color` bzw. Typo-Karte bleibt |
| Push-Versand | serverseitig, für das Gerät 0 Aufrufe (3.6) | – |

**Verbindungszustand** (Teil B, `connectivity_service.dart`, Provider `connectionStateProvider`):

| Zustand | Erkannt an | Sichtbar |
|---|---|---|
| online | Netz da und letzter Aufruf erfolgreich | nichts |
| offline | `connectivity_plus` meldet kein Netz | `StatusRow` offline |
| eingeschränkt | Netz da, aber 2 Aufrufe nacheinander im Timeout oder Erreichbarkeits-Probe (HEAD auf die Supabase-REST-Adresse, 3 s) scheitert; deckt Funkloch im Markt und Captive Portal ab (`perf.md` 2.3) | `StatusRow` eingeschränkt |

Zurück auf online beim ersten erfolgreichen Aufruf. Die Probe läuft nur nach einem Fehlschlag und höchstens alle 15 s, nie dauernd.

**Wiederholung beim Schreiben:** 2, 4, 8, 16, 30 s, danach alle 60 s, solange die App im Vordergrund ist; sofort bei Wechsel auf online, bei Rückkehr aus dem Hintergrund und beim Tipp auf "Erneut versuchen". Lesen wird nicht automatisch wiederholt, außer beim nächsten Anlass (Öffnen, Rückkehr, Wechsel auf online).

---

## 3. Schreiben: optimistisch und offline-fest

### 3.1 Grundsatz

Jede Nutzer-Aktion wirkt im selben Frame, in dem der Finger loslässt: lokal anwenden, Haptik, Animation, dann in die Warteschlange. Der Server bestätigt im Hintergrund. Sichtbar wird das Netz nur, wenn es endgültig scheitert (3.4) oder wenn man offline ist (Sync-Zeichen, `StatusRow`).

Neue Artikel, Listen, Einträge und Planungen bekommen ihre endgültige ID im Gerät (UUID v4, Paket `uuid` ist vorhanden; E-03 in Kap. 11). Die heutigen `pending-…`-IDs entfallen und mit ihnen der Bug, dass frische Artikel 1 bis 3 s nicht bedienbar sind (`perf.md` 4.3 Punkt 4).

### 3.2 Aktionen

| Aktion | Sofort sichtbar | Warteschlange | Endgültiger Fehler | Teil |
|---|---|---|---|---|
| Artikel hinzufügen | Zeile wächst in ihrer Kategorie ein, Menge geparst | ja (Insert mit Geräte-ID, als Upsert) | Zeile "Nicht gespeichert" | A |
| Abhaken, zurückholen | Kreis füllt sich, Zeile wandert nach 0,6 s | ja (Patch `is_checked`) | Kreis springt mit `springQuick` zurück, Zeile "Nicht gespeichert", Fehler-Haptik | A |
| Menge, Name, Notiz, Kategorie ändern | an Ort und Stelle, Zahl rollt | ja (Patch nur der geänderten Felder) | alter Wert zurück, Zeile "Nicht gespeichert" | A |
| Artikel löschen | Zeile schrumpft weg, Rückgängig-Hinweis | ja (nach Ablauf des Hinweises, 4 s) | Zeile wächst wieder ein, "Nicht gespeichert" | A |
| Umsortieren | Zeile rastet ein | ja (eine Operation mit allen neuen Positionen der Kategorie) | alte Reihenfolge zurück mit `springStandard` | A |
| Liste anlegen, umbenennen, Farbe, Symbol | sofort im Titelmenü | ja | Name zurück, `StatusRow` in Listen-Info | A |
| Erledigte entfernen | Sektion "Erledigt" schrumpft weg, Rückgängig-Hinweis | ja (nach 4 s) | Zeilen kommen zurück, `StatusRow` | A |
| Einkauf abschließen | Abschluss sofort, Erfolgsmoment | ja, atomar als eine Server-Funktion (E-09 in Kap. 11) | `StatusRow` "Der Einkauf wurde nicht gespeichert. Erneut versuchen"; Artikel bleiben im Wagen-Zustand | A, B |
| Liste löschen, verlassen, Mitglied entfernen | erst nach Bestätigung, dann sofort | **nein**, braucht Verbindung (offline deaktiviert mit "Braucht eine Verbindung") | `StatusRow` | A |
| Beitreten, Code erzeugen | – | nein, braucht Verbindung | ein Satz am Ort | A |
| Rezept merken, bewerten | `bookmark.fill` bzw. Sterne sofort | ja | Symbol zurück, Rückgängig-Hinweis ohne Aktion "Nicht gespeichert" | A |
| Rezept anlegen, bearbeiten | Entwurf lokal, automatisch gespeichert | Veröffentlichen braucht Verbindung | Entwurf bleibt, `StatusRow` im Editor | A |
| Wochenplan ändern, Zutaten auf die Liste | sofort | ja | Kap. 14 | B |
| Essen, Wasser, Gewicht eintragen | sofort, Ring und Zahl rollen | ja | Kap. 15 | B |
| Modul schalten, Einstellungen | sofort wirksam | ja (Konto-Synchronisierung) | Wert bleibt lokal, nächster Versuch beim Start; kein Hinweis | A |
| Avo-Aktionen | Ergebniszeile | Schreibwerkzeuge nutzen dieselbe Warteschlange; Löschen nie (Kap. 16) | Ergebniszeile mit Teilfehler | B |
| Pro kaufen | StoreKit-Ablauf | nein | Paywall-Zustand | A |

### 3.3 Die Schreib-Warteschlange

**Aufbau** (Teil A, `lib/data/sync/write_queue.dart`, Vertrag für B in 11.6):
- Eine Journal-Datei im Kontoordner, eine Zeile pro Operation: `opId` (UUID), `entity` (`item`, `list`, `diary_entry` …), `entityId`, `scope` (z. B. `listId`), `kind` (`upsert`, `patch`, `delete`, `reorder`, `rpc`), `payload`, `createdAt`, `attempts`, `lastError`.
- Wird vor dem lokalen Anwenden geschrieben (eine Zeile anhängen, kein Umschreiben der Datei); nach Bestätigung wird die Zeile als erledigt markiert und das Journal beim nächsten Start verdichtet.
- Übersteht App-Ende, Absturz und Neustart. Gesendet wird pro `scope` streng in Reihenfolge, über verschiedene `scope`s höchstens zwei parallel.

**Zusammenfassen** (vor dem Senden, nur innerhalb eines `scope`):
- Insert gefolgt von Patches: ein Upsert mit dem Endstand.
- Insert gefolgt von Delete: beide entfallen (nichts ging je an den Server).
- Mehrere Patches derselben Zeile: zu einem Patch der zuletzt gesetzten Felder.
- Abhaken, Zurückholen, Abhaken: nur der Endstand.
- Mehrere Umsortierungen derselben Kategorie: nur die letzte.

**Idempotenz:** Inserts sind Upserts auf die Geräte-ID; Patches setzen Werte (keine Zähler-Erhöhung auf dem Server); Deletes sind wiederholbar. Eine Wiederholung nach Timeout erzeugt so nie Doppel (heute doppelte Mengen beim Import).

**Konflikte** (mehrere Mitglieder, mehrere Geräte):

| Fall | Regel | Sichtbar |
|---|---|---|
| Zwei ändern dasselbe Feld | der letzte Schreiber gewinnt (Serverzeit) | Feld aktualisiert sich live |
| Zwei ändern verschiedene Felder | beide bleiben (Patch nur geänderter Felder) | – |
| Man ändert einen Artikel, den ein anderer gelöscht hat | Löschen gewinnt; die eigene Operation entfällt | Zeile verschwindet ohne Fehler (00 13); im offenen Artikel-Screen "Dieser Artikel wurde gelöscht." mit "Wieder hinzufügen" (Kap. 11) |
| Liste wurde gelöscht oder man wurde entfernt, Operationen warten | alle Operationen dieses `scope` entfallen | Rückgängig-Hinweis ohne Aktion "„Grillabend“ gibt es nicht mehr." (Kap. 10) |
| Sitzung abgelaufen | Token erneuern, dann weiter; scheitert das, bleiben die Operationen stehen | `StatusRow` "Bitte melde dich erneut an." mit "Anmelden" |

**Endgültige Fehler** (nicht wiederholbar): Rechte fehlen (RLS), ungültige Daten (Prüfung im Server), unbekannte Liste. Alles andere (Timeout, 5xx, kein Netz) ist vorläufig und wird wiederholt, ohne dass die Zeile einen Fehler zeigt.

### 3.4 Rückrollen und Fehleranzeige

- **Pro Operation statt Schnappschuss.** Scheitert eine Operation endgültig, wird nur ihr Feld auf den bestätigten Serverwert zurückgesetzt. Schnelle Folgeänderungen anderer Zeilen bleiben stehen (heute überschreibt der Schnappschuss `before` alle parallelen Änderungen, `perf.md` 4.3 Punkt 3).
- **Sichtbar an der Zeile:** Zustand "Nicht gespeichert" (00 12.8) mit `exclamationmark.circle` in `danger`, Unterzeile "Nicht gespeichert · Tippen zum Wiederholen". Wischen nach links "Verwerfen" setzt die Zeile auf den Serverstand.
- **Sichtbar oben:** `StatusRow` "1 Änderung konnte nicht gespeichert werden. Erneut versuchen" (4.3), solange mindestens eine Zeile im Fehlerzustand ist.
- **Haptik:** Fehler, einmal pro Ereignis, im selben Frame wie der Wechsel des Kreises.
- **VoiceOver:** Ansage "Milch nicht gespeichert".
- **Nie:** stilles Zurückspringen, rote Snackbars, rohe Ausnahmen, ein Alert.
- Der Aufrufer wartet nie auf den Server (heute `list_item_tile.dart:88-93` ohne `await` und ohne `catch`, die Ausnahme geht ins Leere). Die Warteschlange fängt alles und meldet über `syncStatusProvider`.

### 3.5 Hinzufügen ohne Warten auf die KI

1. Return im Accessory: lokales Parsen ("2 Milch", "Milch 2", "2x Milch", "500 g Mehl", "1,5 l Wasser") liefert Menge, Einheit, Name (00 12.4).
2. Lokale Kategorie sofort: gelernte Zuordnung des Nutzers (Konto, E-07 in Kap. 11), sonst Kategorie-Speicher, sonst Schlüsselwörter (`ProductClassifierService`, heute nur Rückfall), sonst `other`.
3. Zusammenführen mit einem offenen Artikel gleicher Einheit lokal ("Milch: Menge jetzt 3 · Widerrufen").
4. Zeile wächst ein, Warteschlange bekommt den Upsert. Fertig aus Sicht des Nutzers, in einem Frame.
5. Im Hintergrund (Teil B, Claude über die Edge Function): Kategorie nur prüfen, wenn Schritt 2 aus Schlüsselwörtern oder `other` kam. Weicht das Ergebnis ab, wandert die Zeile mit `springStandard` (00 10.3) und die Zuordnung wird gemerkt.
6. Foto-Import: alle Artikel eines Zettels in **einem** KI-Aufruf (heute einzeln hinter dem 1,1-s-Tor, 20 Artikel mindestens 22 s); Kategorien danach lokal.

Projektregel 1.100 ms Abstand gilt, solange Gemini im Einsatz ist, für alle Gemini-Aufrufe (heute nur in einem Dienst). Mit dem Umstieg auf Claude regelt die Edge Function die Drossel pro Nutzer (Teil B).

### 3.6 Kosten pro Häkchen

Ziel: ein Aufruf vom Gerät.

| Heute (`perf.md` 4.3 Punkt 6) | Neu | Teil |
|---|---|---|
| `update` | Patch über die Warteschlange | A |
| `_touchList` (zweiter Aufruf) | Datenbank-Trigger setzt `shopping_lists.updated_at` | B (Migration), A (Aufruf entfernen) |
| Push-Fan-out vom Gerät (Listenname, Anzeigename, Mitglieder, Nutzer, Edge Function pro Token) | serverseitig: Trigger schreibt in `list_events` (E-12 in Kap. 11), eine Edge Function bündelt (K-39) | B |
| Eigenes Realtime-Echo lädt Artikel neu | Echo wird als "nichts geändert" erkannt | A |
| Globaler Kanal lädt alle Listen mit Zählern neu | Zähler lokal nachgeführt; Listen-Kanal nur als Patch | A |
| `item_purchase_stats` und Widget-Reload | Widget-Schnappschuss gedrosselt (2 s), Statistik beim Abschluss | B |
| Startseiten-Angebote laufen erneut (zwei Scans) | Angebots-Provider hängen am Modul und nur am sichtbaren Screen; geänderte offene Anzahl löst keinen Scan aus | B |

---

## 4. Zustände als Oberflächen

Alle Beispiele nutzen dieselbe Liste: **"Wocheneinkauf"**, Markt Lidl, geteilt mit Lena, 11 Artikel. Obst & Gemüse: Bananen, Gurke, Cherrytomaten 250 g, Avocados 2. Milch & Käse: Milch 2, Butter, Gouda. Brot & Backwaren: Vollkornbrot. Getränke: Mineralwasser 6. Haushalt & Drogerie: Backpapier, Spülmittel. Kategorienamen nach E-01 in Kap. 11.

### 4.1 Kaltstart mit Konto (Launch bis erster Frame)

**Zweck.** Keine eigene Hauptfrage; der Übergang muss unsichtbar sein. Die Hauptfrage des ersten Frames ist die von Tab Liste: "Was muss ich als Nächstes kaufen?"

**Wann.** Jeder Kaltstart mit gespeicherter Sitzung (Symbol tippen, Widget, Mitteilung, Siri, Link). Ohne Sitzung gilt Kap. 17, 3.1.

**Aufbau von oben nach unten.**
1. Launch-Screen: `systemBackground`, ohne Bild (00 3.5).
2. Erster Flutter-Frame: Tab Liste wie zuletzt verlassen, auf `bgGrouped`. `LargeTitleNavBar` mit "Wocheneinkauf", `chevron.down`, Avatar; Metazeile mit `StoreChip` "Lidl" und "11 offen"; Sektion "Für heute" mit höchstens zwei `HintRow`s aus dem Startstand; `AisleSection`s mit `ItemRow`s; `AddItemAccessory`; `AppTabBar`.
3. Kein weiteres Element erscheint nachträglich oberhalb der Leseposition.

Der Farbwechsel vom Launch-Screen (`systemBackground` #FFFFFF) zu `bgGrouped` (#F2F2F7) im Hellmodus ist der einzige sichtbare Wechsel; im Dunkelmodus sind beide #000000. Prüfen, ob er stört (Q-08); Alternative: Launch-Screen in `systemGroupedBackground`.

**Beispielinhalt.** "Wocheneinkauf", "● Lidl", "11 offen", Hinweis-Zeile "Heute im Plan: Ofengemüse mit Feta", Sektion "Obst & Gemüse 4" mit Bananen, Gurke, Cherrytomaten "250 g", Avocados "2".

**Zustände.**
- Lokaler Stand da (Normalfall): wie oben, kein Indikator.
- Liste von heute wurde inzwischen auf einem anderen Gerät gelöscht: erster Frame zeigt sie noch; der Abgleich wechselt per Überblendung nach 01 2.2 Regel 1 und zeigt den Rückgängig-Hinweis ohne Aktion (Kap. 10).
- Offline: identisch plus `StatusRow` offline (4.3).
- Kein lokaler Stand (neues Gerät): 4.2.
- Modul aus, Pro gesperrt: nicht betroffen; Tabs und Pro-Status kommen richtig aus dem Startstand.
- Start über Widget-Tipp auf eine andere Liste: erster Frame zeigt direkt diese Liste, wenn sie im Speicher ist; sonst die Liste von heute und Überblendung, sobald sie gelesen ist (unter 100 ms, kein Skelett).

**Interaktionen, Bewegung, Haptik.** Ab dem ersten Frame voll bedienbar: Abhaken und Hinzufügen gehen sofort (Warteschlange). Keine Einblend-Animation des Inhalts, kein Maskottchen, keine Haptik.

**AX und 320 pt.** Startstand enthält keine Layoutwerte; alles fließt nach 00 6.3 und 6.4. Bei AX5 auf 320 pt (iPhone SE mit Anzeigezoom, 320 × 568) beginnt die erste Artikelzeile spätestens im oberen Drittel: Hinweis-Zeilen werden ab AX3 auf eine reduziert (E-Ergänzung 11.3).

**Was sich ändert.** Heute: Launch mit 168-pt-Bild, Creme-Frame, Theme hell, Remount bis zu zweimal, Listen aus dem Netz mit Spinner in 140-pt-Box, Kalorien-Tab springt in die Leiste, Pro-Sperren flackern. Betroffen: `lib/main.dart` (B), `lib/app.dart` (A, Remount-Schlüssel entfällt), `routes/app_router.dart` (A, synchroner Redirect), `state/theme_provider.dart`, `language_provider.dart`, `lists_provider.dart`, `items_provider.dart`, `subscription_provider.dart` (A), `calorie_tracking_provider.dart` (B, wird Modulsystem), `offline_cache_service.dart` (A), `LaunchScreen.storyboard` (B laut `owner.sh`, Bild-Asset A).

**Bildbeschreibung für ChatGPT.** Zwei iPhone-17-Pro-Screens nebeneinander im Hellmodus, links der Launch-Screen als vollständig leere weiße Fläche #FFFFFF ohne Logo und Text, rechts der erste Frame der App ohne jede Ladeanzeige. Rechts: hellgrauer Hintergrund #F2F2F7, oben links großer fetter schwarzer Titel "Wocheneinkauf" mit kleinem grauem Chevron #636366, rechts ein runder Profil-Avatar ohne Rahmen. Darunter eine graue Kapsel #E9E9EE mit blauem Punkt #0050AA und "Lidl", daneben grau "11 offen". Darunter eine weiße Sektion #FFFFFF mit 26 pt Radius unter dem Titel "Für heute" (17 pt halbfett schwarz) mit einer Zeile "Heute im Plan: Ofengemüse mit Feta" und grauem Chevron. Darunter die Sektion "Obst & Gemüse" mit grauer Zahl "4" rechts und vier Zeilen mit leeren grauen Kreisen #8A8A8E: "Bananen", "Gurke", "Cherrytomaten" mit "250 g" rechts, "Avocados" mit "2" rechts. Unten schwebt eine Glas-Kapsel "Artikel hinzufügen" mit grün getönter Glas-Kapsel "Einkaufen" #3F7A1F, darunter die Glas-Tab-Bar mit vier Tabs und abgesetztem runden Avo-Kreis.

---

### 4.2 Allererstes Laden ohne lokalen Stand (Skelett)

**Zweck.** "Kommt gleich etwas?" Die einzige Situation, in der der Nutzer überhaupt sieht, dass Daten unterwegs sind.

**Wann.** Erste Anmeldung auf einem neuen iPhone mit bestehendem Konto; nach Neuinstallation; nach "Speicher löschen". Gilt pro Screen, der keinen lokalen Stand hat (Tabelle 2.3). Nie beim zweiten Öffnen.

**Aufbau von oben nach unten (Tab Liste; Form gleich für andere Screens).**
1. Titelzeile: Tonfläche `fill` in Höhe einer `largeTitle`-Zeile bei aktueller Textgröße, 50 % der Breite, Kapselform. Avatar schon echt (aus der Sitzung).
2. Metazeile: Kapsel-Tonfläche `fill` in Höhe des `StoreChip` (Mindesthöhe 32), 80 pt breit.
3. Eine `InsetSection` auf `surface` mit 5 Zeilen: leere Kreise 24 pt in `fill` (nicht `controlOutline`, damit sie nicht wie echte Kreise wirken), Balken in `fill` mit Höhe einer `body`-Zeile und Breiten 55, 40, 70, 35, 60 %.
4. Keine Hinweis-Zeilen, kein "Vielleicht auch".
5. `AddItemAccessory` sichtbar, aber deaktiviert: `plus` und Platzhalter in `labelTertiary`, nicht antippbar; "Einkaufen" ausgeblendet.
6. `AppTabBar` normal und bedienbar (andere Tabs haben ihre eigenen Zustände).

Komponente: `SkeletonSection` (11.4). Kein Schimmer, kein Pulsieren, keine Bewegung.

**Beispielinhalt.** Keiner (das ist der Punkt). Nach der Antwort: "Wocheneinkauf" mit 11 Artikeln.

**Zustände.**
- Antwort kommt: Skelett und Inhalt überblenden in `fadeReduced` (0,2 s). Die Skelett-Zeilen haben dieselbe Mindesthöhe wie `ItemRow`, deshalb verschiebt sich der Inhalt bei normaler Liste kaum; längere Inhalte wachsen nach unten.
- Keine Liste im Konto: direkt der Zustand "Erste Liste" (01 2.4).
- 10 s ohne Antwort: Vollflächen-Fehler (4.7, Variante Fehler).
- Offline beim allerersten Laden: Vollflächen-Fehler, Variante offline; lädt automatisch, sobald eine Verbindung da ist.
- Modul aus, Pro gesperrt: nicht betroffen.

**Interaktionen.** Nichts im Skelett ist antippbar. VoiceOver liest einmal "Wird geladen" (ein Element für das ganze Skelett, Eigenschaft "beschäftigt"), danach den echten Inhalt. Keine Haptik.

**AX und 320 pt.** Balkenhöhen kommen aus der Zeilenhöhe des Textstils bei aktueller Größe; ab AX1 wird die Sektion randlos auf `bgPlain` (00 6.4), die Kreise bleiben 24 pt und oben bündig. Breiten in Prozent, deshalb ohne Überlauf bei 320 pt.

**Was sich ändert.** Heute: `CupertinoActivityIndicator` in fester 140-pt-Box (`home_screen.dart:465-468`), "Artikel werden geladen…" (`list_detail_screen.dart:385`), 18 Material-Spinner in Kalorien und Verlauf. Betroffen: `home_screen.dart`, `list_detail_screen.dart` (A, werden Tab Liste), `loading_indicator.dart` (entfällt), Kalorien- und Verlaufs-Screens (B nutzen `SkeletonSection`).

**Bildbeschreibung für ChatGPT.** iPhone-17-Pro-Screen im Hellmodus auf hellgrauem Grund #F2F2F7. Oben links statt eines Titels eine ruhige hellgraue Kapsel #E9E9EE in Höhe einer großen Überschrift und halber Bildschirmbreite, rechts ein echter runder Profil-Avatar. Darunter eine kleine graue Kapsel #E9E9EE als Platzhalter für den Markt. Darunter eine weiße Sektion #FFFFFF mit 26 pt Radius und fünf Zeilen, jede mit einem hellgrauen Kreis #E9E9EE links und einem hellgrauen abgerundeten Balken unterschiedlicher Länge, getrennt durch feine Linien #C6C6C8. Keine Spinner, kein Schimmer, keine Farbe außer Grautönen. Unten eine Glas-Kapsel mit blassgrauem Platzhalter "Artikel hinzufügen" #AEAEB2 und die Glas-Tab-Bar mit Avo-Kreis.

---

### 4.3 `StatusRow` in Tab Liste: offline, eingeschränkt, ausstehend, Fehler

**Zweck.** "Kommen meine Änderungen an?" Ein Satz, der sagt, was gerade mit dem Netz los ist und was trotzdem geht.

**Wann.** Automatisch, sobald einer der Zustände eintritt; in jedem Screen mit Daten, ausdrücklich auch in Tab Liste und Einkaufsmodus (00 12.27).

**Aufbau.** `StatusRow` direkt unter der Metazeile (Tab Liste) bzw. unter dem Titel (andere Screens), vor der ersten Sektion, ohne Fläche: Symbol 15 pt, Text `subheadline` in `label`, optional schlichte Aktion in `action`. Mindesthöhe 44. Immer nur **eine** `StatusRow` pro Screen; bei mehreren Lagen gilt die Priorität:

| Prio | Lage | Symbol | Text (Deutsch) | Aktion |
|---|---|---|---|---|
| 1 | Sitzung abgelaufen | `exclamationmark.circle` `danger` | "Bitte melde dich erneut an." | "Anmelden" |
| 2 | Änderungen endgültig gescheitert | `exclamationmark.circle` `danger` | "1 Änderung konnte nicht gespeichert werden." | "Erneut versuchen" |
| 3 | offline, nichts ausstehend | `icloud.slash` `labelSecondary` | "Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist." | – |
| 3 | offline, ausstehend | `icloud.slash` | "Offline. 3 Änderungen warten." | – |
| 4 | eingeschränkt | `wifi.exclamationmark` `labelSecondary` | "Verbindung schlecht. 3 Änderungen werden gesendet, sobald es wieder geht." (ohne Ausstehendes: "Verbindung schlecht. Es wird der letzte Stand gezeigt.") | – |
| 5 | online, Senden dauert länger als 3 s | `arrow.triangle.2.circlepath` `labelSecondary` | "3 Änderungen werden gesendet." | – |
| 6 | Abgleich gescheitert, lokaler Stand da | `exclamationmark.circle` `danger` | "Die Liste konnte nicht aktualisiert werden." | "Erneut versuchen" |

Englisch entsprechend über die Übersetzungen (Bereich `system`, Teil B); Zahlen über ICU-Plural ("1 Änderung wartet", "3 Änderungen warten").

Dazu (E10-03): Ist der große Titel eingeklappt, steht hinter dem Inline-Titel ein Symbol 13 pt (`icloud.slash`, `wifi.exclamationmark` bzw. `exclamationmark.circle` in `danger`); Tippen scrollt nach oben zur `StatusRow`.

**Beispielinhalt.** Im Markt ohne Netz: "Offline. 2 Änderungen warten." Bananen ist abgehakt und trägt das Sync-Zeichen; die neue Zeile "Backpapier" in "Haushalt & Drogerie" ebenso.

**Zustände.**
- Erscheinen: an Versatz 0 wächst die Zeile ein (`springStandard`); ist gescrollt, gilt der Scroll-Anker und es erscheint nur das Symbol im eingeklappten Titel. Verschwinden genauso. Reduce Motion: Überblendung.
- Verzögerung gegen Flackern: offline erscheint nach 1 s Dauer (kurze Netzwechsel im Aufzug zeigen nichts); "werden gesendet" erst nach 3 s; Fehler sofort.
- Nach erfolgreichem Senden: Zeile verschwindet ohne Erfolgsmeldung; das Sync-Zeichen an den Zeilen verschwindet mit `springQuick`.
- Modul aus, Pro gesperrt: nicht betroffen.

**Interaktionen.** Aktion "Erneut versuchen" sendet sofort; während des Versuchs ist sie deaktiviert (`labelTertiary`), die Beschriftung bleibt stehen. Das Ergebnis zeigt die Zeile selbst (sie verschwindet oder bleibt). Tippen auf eine `StatusRow` ohne Aktion tut nichts. Haptik: Fehler nur beim Übergang in Prio 1 oder 2, nicht beim Erscheinen von offline.

**VoiceOver.** Die `StatusRow` ist ein Element mit vollem Satz und wird beim Erscheinen höflich angesagt (nicht bei jedem Zählerwechsel).

**AX und 320 pt.** Text bricht um, Symbol bleibt oben bündig zur ersten Zeile, Aktion rutscht ab AX1 unter den Text. Bei AX5 auf 320 pt bis zu 6 Zeilen; deshalb kurze Texte (alle unter 80 Zeichen).

**Was sich ändert.** Heute: schwebende Kapsel "Offline" (Deutsch fest, `Icons.cloud_off_rounded`, `IgnorePointer`), nur in der Shell, nie in der Liste; kein Zustand für ausstehend oder schlecht; Fehler still. Betroffen: `main_scaffold.dart` (`_OfflineBanner` entfällt, A), `connectivity_service.dart` (B, drei Zustände), `items_provider.dart`, `lists_provider.dart` (A, `syncStatusProvider`), Komponente `status_row.dart` (A, neu in `widgets/design/`).

**Bildbeschreibung für ChatGPT.** iPhone-13-Pro-Screen im Hellmodus, Liste "Wocheneinkauf" auf #F2F2F7 mit großem fetten Titel, darunter die graue Markt-Kapsel #E9E9EE mit blauem Punkt #0050AA "Lidl" und grau "10 offen". Direkt darunter eine Zeile ohne Hintergrund: links ein graues Wolken-durchgestrichen-Symbol #636366, daneben schwarzer 15-pt-Text "Offline. 2 Änderungen warten." In der weißen Sektion "Obst & Gemüse" (Radius 26 pt) ist "Bananen" abgehakt: gefüllter grüner Kreis #3F7A1F mit weißem Häkchen, Text grau #636366 durchgestrichen, unten rechts am Kreis ein winziges graues Kreispfeil-Symbol; die anderen Zeilen "Gurke", "Cherrytomaten 250 g", "Avocados 2" haben leere graue Kreise #8A8A8E. Kein rotes Banner, keine Kapsel oben, keine Spinner. Unten die Glas-Kapsel "Artikel hinzufügen" mit grüner Glas-Kapsel "Einkaufen" und die Glas-Tab-Bar.

---

### 4.4 Einkaufsmodus: offline und ausstehend

**Zweck.** "Kann ich weiter abhaken, auch ohne Netz?" Antwort: ja, und man sieht es.

**Wann.** Im Einkaufsmodus (`/lists/:listId/shopping`), sobald die Verbindung fehlt oder schlecht ist. Im Markt der häufigste Fall.

**Aufbau von oben nach unten.**
1. Toolbar-Gruppe oben: `chevron.down` links (Glas).
2. Kopf: großer Titel "Lidl", rechts "5 von 11" (`numberXL`, `label`), darunter die Fortschrittslinie in `label`.
3. `StatusRow` (randlos auf `bgPlain`): "Offline. Abhaken wird gespeichert und später gesendet." (Text aus Kap. 11); mit Ausstehendem zusätzlich "3 Änderungen warten." als zweiter Satz. Präsenz-Zeile ("Lena kauft auch gerade ein") entfällt offline; die eigene Präsenz pausiert und meldet sich beim Wiederverbinden neu (Kap. 11).
4. Haftende Gang-Titel und randlose `ItemRow`s im Einkaufsmodus-Maß; abgehakte Zeilen mit Sync-Zeichen am 36-pt-Kreis.
5. Bodenleiste (Glas): "+" links, "Einkauf beenden" getönt, Avo-Kreis rechts. Avo offline: siehe 4.6.

**Beispielinhalt.** "Lidl", "5 von 11". Im Wagen: Bananen, Gurke, Avocados, Milch, Butter (Sync-Zeichen an den letzten drei). Offen: "Milch & Käse 1" mit Gouda; "Getränke 1" mit Mineralwasser "6".

**Zustände.**
- Netz kommt zurück: `StatusRow` wechselt zu "3 Änderungen werden gesendet." (nur, wenn es länger als 3 s dauert), dann verschwindet sie; Lenas Häkchen aus der Zwischenzeit kommen als ein Bündel herein (ihr Avatar 2 s am Kreis, 00 10.3).
- Lena hat offline dasselbe abgehakt: kein Konflikt (gleicher Endstand).
- Einkauf beenden offline: geht (Warteschlange, atomar beim Senden, E-09); der Erfolgsmoment erscheint sofort; die Ersparnis-Zeile nur aus gecachten Angeboten, sonst entfällt sie.
- Bildschirm bleibt an (`wakelock_plus`, heute nur im Kochmodus).

**Interaktionen, Bewegung, Haptik.** Abhaken unverändert: ganze Zeile, leichter Impuls, Kreis füllt sich (`springQuick`), "5 von 11" rollt (`springDigits`), nach 0,6 s wandert die Zeile (`springMove`). Das Sync-Zeichen erscheint offline sofort, online erst, wenn die Operation länger als 2 s aussteht (11.2), damit es bei gutem Netz nie aufblitzt.

**AX und 320 pt.** `StatusRow` im Einkaufsmodus in `callout` statt `subheadline` (größer, man liest im Gehen); bricht um. Bei 320 pt und AX3 steht der Kopf zweizeilig ("Lidl" oben, "5 von 11" darunter, `numberXL` gedeckelt auf 51 pt).

**Was sich ändert.** Heute gibt es keinen Einkaufsmodus und in der Liste keinen Offline-Hinweis; Abhaken ohne Netz springt still zurück. Betroffen: neuer Screen `lists/shopping_mode_screen.dart` (A, Kap. 11), `items_provider.dart`, Warteschlange (A).

**Bildbeschreibung für ChatGPT.** iPhone-13-Pro-Screen im Dunkelmodus, randlose Liste auf Schwarz #000000. Oben links ein runder Glas-Knopf mit nach unten zeigendem Chevron. Darunter großer weißer fetter Titel "Lidl" und rechts groß in gerundeten Ziffern "5 von 11" in Weiß, darunter eine dünne weiße Fortschrittslinie zu 45 % gefüllt auf dunkelgrauer Spur #2C2C2E. Darunter eine Zeile ohne Hintergrund mit grauem Wolken-durchgestrichen-Symbol #98989F und weißem 16-pt-Text "Offline. Abhaken wird gespeichert und später gesendet. 3 Änderungen warten." Darunter ein haftender Gang-Titel "Milch & Käse" mit grauer "1" und eine große Zeile "Gouda" mit leerem 36-pt-Kreis in Grau #7C7C80; weiter unten "Getränke" mit "Mineralwasser" und "6". Ganz unten eine eingeklappte Zeile "Im Wagen (5)". Unten schwebt eine Glas-Leiste: links ein runder "+"-Knopf, in der Mitte eine grün getönte Glas-Kapsel #A6D45F mit dunklem Text "Einkauf beenden", rechts der runde Avo-Kreis mit braunem Kern und hellgrünem Ring.

---

### 4.5 Zeilen-Zustände: ausstehend, nicht gespeichert, von anderen geändert

**Zweck.** "Ist dieser eine Artikel gespeichert?" Die Antwort sitzt am Kreis, nicht in einem Banner.

**Wann.** In jeder `ItemRow` (Liste, Einkaufsmodus), sinngemäß in Kalorien-Einträgen, Plan-Zeilen und Avo-Ergebniszeilen (dort von Teil B nach demselben Muster).

**Aufbau (eine `ItemRow`, 00 12.8).**
- **Ausstehend:** am `CheckCircle` unten rechts `arrow.triangle.2.circlepath` 10 pt in `labelSecondary` auf einem 14-pt-Kreis in Flächenfarbe (damit es auf dem grünen Häkchen lesbar bleibt). Sonst unverändert.
- **Nicht gespeichert:** Kreis zeigt den Serverstand, rechts neben der Menge `exclamationmark.circle` 17 pt in `danger`; Unterzeile `subheadline` in `label`: "Nicht gespeichert · Tippen zum Wiederholen". Die Zeile bleibt in ihrer Kategorie stehen.
- **Von anderen geändert:** Avatar 16 pt am Kreis für 2 s (00 12.7), geänderte Menge rollt.
- **Von anderen gelöscht:** Zeile schrumpft weg (`springStandard`), keine Meldung.

**Beispielinhalt.** "Backpapier" ausstehend (offline hinzugefügt). "Spülmittel": "Nicht gespeichert · Tippen zum Wiederholen" (der Server hat die Änderung abgelehnt, z. B. weil die Prüfung im Server den Namen nicht annimmt). "Milch" Menge 2 rollt auf 3, Lenas Avatar 2 s am Kreis.

**Zustände.** Offline: alle neuen Änderungen ausstehend. Modul aus, Pro: nicht betroffen. Leere Liste: nicht anwendbar.

**Interaktionen.**
- Ausstehende Zeilen sind voll bedienbar (abhaken, ändern, löschen); die Warteschlange fasst zusammen (3.3).
- Nicht gespeichert: Tippen auf die Zeile wiederholt (nicht das Artikel-Screen öffnen, solange der Fehler steht); Wischen nach links "Verwerfen" setzt auf den Serverstand; Kontextmenü zusätzlich "Bearbeiten".
- Haptik: Fehler einmal beim Wechsel in "Nicht gespeichert".
- VoiceOver: "Spülmittel, nicht gespeichert, Doppeltippen zum Wiederholen"; ausstehend: Zusatz "wird gesendet" am Ende des Zeilensatzes.

**AX und 320 pt.** Ab AX1 steht die Unterzeile unter dem Namen, `exclamationmark.circle` wandert an den Anfang der Unterzeile (nicht rechts außen, wo bei 320 pt kein Platz ist). Das Sync-Zeichen wächst nicht über 14 pt (Deko am Kreis), seine Bedeutung trägt der VoiceOver-Text.

**Was sich ändert.** Heute: `pending-…`-IDs, frische Zeilen nicht bedienbar, Fehler unsichtbar. Betroffen: `list_item_tile.dart` (A, wird `ItemRow`), `items_provider.dart`, `item_repository.dart` (A).

**Bildbeschreibung für ChatGPT.** Nahaufnahme einer weißen Sektion #FFFFFF mit 26 pt Radius auf #F2F2F7 im Hellmodus, Titel "Haushalt & Drogerie" in 17 pt halbfett schwarz darüber, rechts "2" in Grau. Erste Zeile: leerer grauer Kreis #8A8A8E mit winzigem grauem Kreispfeil-Symbol unten rechts am Kreis, Name "Backpapier" in Schwarz. Zweite Zeile: leerer grauer Kreis, Name "Spülmittel" in Schwarz, rechts ein rotes Ausrufezeichen-im-Kreis-Symbol #D70015, darunter in Schwarz 15 pt "Nicht gespeichert · Tippen zum Wiederholen". Darüber eine dritte Sektion "Milch & Käse" mit der Zeile "Milch", rechts die gerundete Zahl "3", und am Kreis unten rechts ein kleiner runder Avatar einer Frau. Keine Banner, keine Karten.

---

### 4.6 "Braucht eine Verbindung": Funktionen, die nur online gehen

**Zweck.** "Warum geht das gerade nicht?" Die Antwort steht an der Funktion selbst, nicht in einem Dialog.

**Wann.** Offline oder eingeschränkt bei Funktionen ohne lokalen Weg: Avo, Zettel importieren, Essen-Foto, Rezeptsuche über den Speicher hinaus, Angebote ohne Cache, Liste beitreten, Code erzeugen, Mitglied entfernen, Liste löschen oder verlassen, Rezept veröffentlichen, Pro kaufen.

**Aufbau, je nach Ort.**

| Ort | Darstellung | Text |
|---|---|---|
| Menüeintrag (z. B. `text.viewfinder` > Kamera) | Eintrag deaktiviert (`labelTertiary`), Unterzeile `footnote` | "Braucht eine Verbindung" |
| Zeile in Listen-Info ("Liste verlassen") | Zeile deaktiviert mit Unterzeile | "Braucht eine Verbindung" |
| Avo (Kap. 16) | Kern `neutral`; `StatusRow` im Avo-Bereich | "Offline. Avo braucht eine Verbindung." |
| Suche (01 9) | lokale Treffer; `StatusRow` darüber | "Offline. Es werden nur gespeicherte Ergebnisse gezeigt." |
| Angebote der Woche ohne Cache | Vollflächen-Zustand (4.7, Variante offline) | "Offline. Angebote erscheinen, sobald du wieder online bist." |
| Paywall | `StatusRow` im Plan-Bereich, Hauptaktion deaktiviert | "Offline. Der Kauf braucht eine Verbindung." |

Nie wird eine Funktion versteckt, nur weil man offline ist; sie bleibt an ihrem Platz und sagt, was fehlt. Kommt die Verbindung zurück, wird sie ohne Meldung wieder aktiv.

**Beispielinhalt.** Im Markt: Tipp auf `text.viewfinder` zeigt das Menü mit "Kamera", "Fotos", "Dateien" grau und darunter je "Braucht eine Verbindung".

**Zustände.** eingeschränkt: wie offline, aber Aktion wird trotzdem versucht, wenn man sie antippt (mit Timeout); Modul aus: Funktion gar nicht da (00 15).

**Interaktionen.** Deaktivierte Einträge lösen keine Haptik aus. VoiceOver: "Kamera, nicht verfügbar, braucht eine Verbindung".

**AX und 320 pt.** Unterzeilen brechen um; Menüs werden bei AX3 bis AX5 bildschirmhoch und scrollen (00 12.24).

**Was sich ändert.** Heute schlagen diese Funktionen offline mit englischen Rohtexten fehl ("I'm not ready yet"), Angebote zeigen Spinner. Betroffen: `attachment_sheet.dart` (A, wird Menü), `avo_chat_screen.dart` (B), `weekly_deals_screen.dart` (B), `subscription_screen.dart` (A).

**Bildbeschreibung für ChatGPT.** iPhone-Screen im Hellmodus, Liste "Wocheneinkauf" leicht im Hintergrund. Unten links aus dem Scan-Symbol der Glas-Eingabeleiste ist ein Glas-Menü mit abgerundeten Ecken (20 pt) nach oben gewachsen. Drei Einträge: "Kamera", "Fotos", "Dateien", jeweils mit Symbol rechts, alle in blassem Grau #AEAEB2, darunter jeweils klein grau "Braucht eine Verbindung". Über der Liste oben die Zeile mit Wolken-durchgestrichen-Symbol und "Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist." Keine Fehlermeldung, kein Dialog.

---

### 4.7 Fehler einer Sektion und Vollflächen-Fehler

**Zweck.** "Was ist schiefgegangen, und was kann ich tun?" Ein Satz, eine Aktion.

**Wann.**
- **Sektionsfehler:** ein Teil eines Screens kann nicht geladen werden und hat keinen lokalen Stand (z. B. "Beliebt diese Woche" im Tab Rezepte auf einem neuen Gerät), der Rest ist da.
- **Vollflächen-Fehler:** ein ganzer Screen hat keinen lokalen Stand und die erste Antwort scheitert oder bleibt 10 s aus (00 12.27: nur dann).

**Aufbau.**
- **Sektionsfehler:** An der Stelle der Sektion steht ihr Titel ("Beliebt diese Woche") und darunter eine `StatusRow`: `exclamationmark.circle` in `danger`, "Beliebte Rezepte konnten nicht geladen werden.", schlicht "Erneut versuchen". Keine leere Sektionsfläche, kein Rahmen.
- **Vollflächen-Fehler:** Layout des `EmptyState` (00 12.26) an der Stelle des Inhalts (nicht zwingend bildschirmmittig), ohne Maskottchen (00 3.3): Symbol 48 pt Light in `labelSecondary` (`exclamationmark.circle` bzw. `icloud.slash`), Titel `title3`, ein Satz `body` in `label`, prominente Aktion "Erneut versuchen". Titelzeile und Tab-Bar bleiben bedienbar.

| Screen | Variante Fehler | Variante offline | Zweite Aktion |
|---|---|---|---|
| Tab Liste | "Deine Listen konnten nicht geladen werden." | "Offline. Deine Listen erscheinen, sobald du wieder online bist." | schlicht "Neue Liste anlegen" (lokal, Warteschlange) |
| Tab Rezepte | "Rezepte konnten nicht geladen werden." | "Offline. Rezepte erscheinen, sobald du wieder online bist." | schlicht "Eigenes Rezept schreiben" |
| Tab Kalorien (Kap. 15) | "Das Tagebuch konnte nicht geladen werden." | "Offline. Dein Tagebuch erscheint, sobald du wieder online bist." | Toolbar `plus` bleibt nutzbar |
| Verlauf | "Deine Einkäufe konnten nicht geladen werden." | "Offline. Deine Einkäufe erscheinen, sobald du wieder online bist." | – |

Die Variante offline hat keine Aktion "Erneut versuchen" (es gibt nichts zu versuchen); sie lädt automatisch, sobald eine Verbindung da ist, und überblendet in den Inhalt.

**Beispielinhalt.** Neues iPhone, Tab Rezepte, im Zug: Hero "Rezept der Woche" kommt aus dem öffentlichen Cache der Edge Function, "Beliebt diese Woche" scheitert: Sektionsfehler darunter, die übrigen Abschnitte sind da.

**Zustände.** Nach "Erneut versuchen": Beschriftung bleibt, der Knopf zeigt den Arbeitszustand (00 12.20), höchstens 8 s; Erfolg: Überblendung in den Inhalt; erneuter Fehler: Fehler-Haptik, Zustand bleibt. Modul aus: Screen ist nicht erreichbar (4.9). Pro gesperrt: nicht betroffen.

**AX und 320 pt.** Ab AX1 ohne Symbol (wie das Maskottchen in leeren Zuständen), damit Text und Knopf ohne Scrollen sichtbar sind. Der prominente Knopf ist volle Breite minus `pageMargin`, Text bricht um, Höhe wächst.

**Was sich ändert.** Heute: "Fehler beim Laden" in 140-pt-Box ohne Aktion (`home_screen.dart:469-482`), zentrierter Text in der Liste, fachlich falscher Text im Kalorien-Tab, Rezepte offline werden durch eine leere Liste ersetzt und der Cache überschrieben (`recipe_service.dart:91-95`, `recipes_provider.dart:23`). Betroffen: `home_screen.dart`, `list_detail_screen.dart`, `recipes_screen.dart`, `recipe_service.dart`, `recipes_provider.dart` (A; Fehler werfen statt `[]`, nie leeren Inhalt in den Speicher schreiben), `calories_screen.dart`, `shopping_history_screen.dart` (B).

**Bildbeschreibung für ChatGPT.** iPhone-SE-Screen im Hellmodus auf #F2F2F7, Tab Rezepte: oben großer fetter Titel "Rezepte" und rechts der Profil-Avatar, darunter ein graues Suchfeld #E9E9EE "Rezepte suchen". Darunter ein großes Essensfoto 16:10 mit weichem dunklem Verlauf unten und weißem Text "Rezept der Woche · Ofengemüse mit Feta". Darunter der Sektionstitel "Beliebt diese Woche" in 17 pt halbfett schwarz und direkt darunter eine Zeile ohne Fläche mit rotem Ausrufezeichen-im-Kreis #D70015 und schwarzem Text "Beliebte Rezepte konnten nicht geladen werden." und grünem Textknopf #3F7A1F "Erneut versuchen". Darunter die nächste Sektion "Schnell unter 20 Min" mit drei weißen Rezept-Zeilen mit quadratischen Fotos. Unten die Glas-Tab-Bar mit Avo-Kreis. Kein Spinner, keine leere Box.

---

### 4.8 Fehlerseite (unbekannte oder veraltete Route)

**Zweck.** "Wo bin ich gelandet, und wie komme ich weiter?" Wayfinding für Links, die ins Leere zeigen.

**Wann.** Unbekannter Pfad (`errorBuilder` des Routers, heute fehlt er; `shoply:///irgendwas`); Rezept wurde entfernt; Liste existiert nicht mehr oder man ist kein Mitglied (öffnet bei Nicht-Mitgliedern "Bitte um eine Einladung" nach E-11 in Kap. 11, die Fehlerseite nur, wenn die Liste gelöscht ist); Route eines Angebots-Screens bei aktivem Kill-Switch (ohne Hinweis auf Angebote, 01 7).

**Aufbau von oben nach unten.** Vollbild (01 7) auf `bgGrouped`, ohne Tab-Bar:
1. Glas-Knopf `xmark` oben links (schließt zu `/home`).
2. Im oberen Drittel: Symbol `questionmark.circle` 48 pt Light in `labelSecondary` (ab AX1 entfällt es).
3. Titel `title3`, ein Satz `body` in `label`.
4. Prominent eine Aktion, darunter optional eine schlichte.

| Fall | Titel | Satz | Aktionen |
|---|---|---|---|
| unbekannter Pfad, Kill-Switch | "Diese Seite gibt es nicht." | "Der Link ist veraltet oder unvollständig." | "Zur Liste" |
| Rezept entfernt | "Dieses Rezept gibt es nicht mehr." | "Es wurde von der Person entfernt, die es geteilt hat." | "Zu den Rezepten" |
| Liste gelöscht | "Diese Liste gibt es nicht mehr." | "Sie wurde gelöscht." | "Zur Liste", schlicht "Liste beitreten" |
| Offline und Ziel nicht im Speicher | "Offline." | "Diese Seite braucht eine Verbindung. Sie öffnet sich, sobald du wieder online bist." | "Zur Liste" |

**Beispielinhalt.** Lena schickt einen alten Link `https://shoplyai.app/recipe/…` auf ein gelöschtes Rezept: "Dieses Rezept gibt es nicht mehr." mit "Zu den Rezepten".

**Zustände.** Offline-Variante wechselt automatisch zum Ziel, sobald es geladen ist. Abgemeldet: private Ziele werden gemerkt und nach der Anmeldung fortgesetzt (01 7); die Fehlerseite erscheint erst danach, falls das Ziel dann noch fehlt.

**Interaktionen.** `xmark` und Wischen vom linken Rand führen zu `/home`. Keine Haptik. VoiceOver: Titel als Überschrift, Fokus beginnt dort.

**AX und 320 pt.** Inhalt scrollt, Knöpfe in voller Breite untereinander.

**Was sich ändert.** Heute: go_router-Standardfehlerseite (englisch, Material). Betroffen: `routes/app_router.dart` (A, `errorBuilder`), neue Datei `screens/common/route_error_screen.dart` (A), `deep_link_service.dart` (A, ungeprüftes `uri.path`).

**Bildbeschreibung für ChatGPT.** iPhone-Screen im Dunkelmodus auf Schwarz #000000. Oben links ein runder Glas-Knopf mit "x". Im oberen Drittel mittig ein dünnes graues Fragezeichen-im-Kreis-Symbol #98989F, darunter in Weiß halbfett 20 pt "Dieses Rezept gibt es nicht mehr." und in Weiß 17 pt "Es wurde von der Person entfernt, die es geteilt hat." Darunter eine breite gefüllte Kapsel in Hellgrün #A6D45F mit dunklem Text #0E1A06 "Zu den Rezepten". Kein Maskottchen, keine Tab-Bar, keine Illustration.

---

### 4.9 Modul ist aus (Alert)

**Zweck.** "Warum öffnet sich nicht, was ich angetippt habe?" Und: mit einem Tipp einschalten.

**Wann.** Ein direkter Aufruf einer Modul-Route bei ausgeschaltetem Modul: Deep Link (`shoply://calories/add`), Widget eines ausgeschalteten Moduls, Mitteilung, Siri-Satz, Avo-Kurzbefehl (00 13, 01 7).

**Aufbau.** Statt des Sheets aus 00 13 ein zentrierter nativer Alert (Owner-Regel, wie Kap. 17 9.10), über dem Screen, auf dem man gerade ist (beim Kaltstart über Tab Liste):
- Titel: "Kalorien ist ausgeschaltet"
- Nachricht: "Schalte das Modul ein, um dein Tagebuch zu öffnen. Deine Einträge sind noch da."
- Knöpfe: "Nicht jetzt" (Abbrechen) und "Einschalten" (Standard, fett).

| Modul | Titel | Nachricht |
|---|---|---|
| Kalorien & Gesundheit | "Kalorien ist ausgeschaltet" | "Schalte das Modul ein, um dein Tagebuch zu öffnen. Deine Einträge sind noch da." |
| Wochenplan | "Wochenplan ist ausgeschaltet" | "Schalte das Modul ein, um deinen Plan zu öffnen. Deine Planung ist noch da." |
| Avo | "Avo ist ausgeschaltet" | "Schalte Avo ein, um Fragen zu stellen und mit Avo zu sprechen." |
| Kosten teilen | "Kosten teilen ist ausgeschaltet" | "Schalte das Modul ein, um offene Beträge zu sehen. Gespeicherte Beträge sind noch da." |
| Preise & Angebote | "Angebote sind ausgeschaltet" | "Schalte das Modul ein, um Angebote für deine Listen zu sehen." |

Bei aktivem Kill-Switch gibt es diesen Alert für Angebote nicht; die Route zeigt die Fehlerseite (4.8).

**Zustände.** "Einschalten": Modul an (sofort, 00 15.2), Tab blendet mit `springStandard` ein, dann wird das ursprüngliche Ziel geöffnet. "Nicht jetzt": Alert schließt, man bleibt, wo man war. Offline: Einschalten wirkt lokal sofort, der Konto-Abgleich folgt.

**Interaktionen.** Systemalert, keine eigene Haptik. VoiceOver und Sprachsteuerung nativ.

**AX und 320 pt.** Systemalert, skaliert selbst.

**Was sich ändert.** Heute springt die Shell bei ausgeschaltetem Kalorien-Tab nach dem Frame auf Home (`main_scaffold.dart:204-210`); Modul-Routen anderer Module gibt es nicht. Betroffen: Router-Gerüst (A), Bereichsrouten (B), `confirm_dialog.dart` bzw. `AdaptiveAlertDialog` (A).

**Bildbeschreibung für ChatGPT.** iPhone-Screen im Hellmodus: im Hintergrund leicht abgedunkelt die Liste "Wocheneinkauf". In der Mitte ein nativer iOS-26-Alert mit abgerundeten Glas-Ecken, Titel halbfett "Kalorien ist ausgeschaltet", darunter "Schalte das Modul ein, um dein Tagebuch zu öffnen. Deine Einträge sind noch da." Zwei Knöpfe nebeneinander: "Nicht jetzt" und fett "Einschalten" in Grün #3F7A1F. Kein Sheet von unten, kein Maskottchen.

---

### 4.10 Abmelden mit ungesendeten Änderungen (Alert)

**Zweck.** "Geht etwas verloren, wenn ich mich jetzt abmelde?" Der einzige Fall, in dem die Warteschlange zu einer Rückfrage führt (00 12.34 nennt ihn).

**Wann.** Einstellungen > Konto > "Abmelden" (bzw. Konto wechseln), während die Warteschlange nicht leer ist.

**Aufbau.**
1. Tipp auf "Abmelden": Ist man online, versucht die App zuerst zu senden; die Zeile "Abmelden" zeigt den Arbeitszustand (Text bleibt, kleiner Fortschritt rechts), höchstens 10 s. Gelingt es, folgt die normale Abmeldung ohne Rückfrage.
2. Gelingt es nicht oder ist man offline: nativer Alert `confirmDestructive`:
   - Titel: "Abmelden?"
   - Nachricht: "3 Änderungen sind noch nicht gesendet. Wenn du dich jetzt abmeldest, gehen sie verloren."
   - Knöpfe: "Abbrechen" und rot "Trotzdem abmelden".

**Zustände.** Leere Warteschlange: keine Rückfrage (00 12.34). Nach "Trotzdem abmelden": Kontoordner und Warteschlange gelöscht, Widget-App-Group geleert (wie heute).

**AX und 320 pt.** Systemalert.

**Was sich ändert.** Heute: Abmelden ohne Rückfrage, und offline gemachte Änderungen gibt es nicht. Betroffen: `profile_screen.dart` bzw. neue Seite `/settings/account` (A, Kap. 18), Warteschlange (A), `main.dart` (B, Auth-Seiteneffekte).

**Bildbeschreibung für ChatGPT.** iPhone-Screen im Dunkelmodus: im Hintergrund abgedunkelt die Einstellungsseite "Konto" mit einer roten Zeile "Abmelden". In der Mitte ein nativer iOS-Alert, Titel "Abmelden?", Text "3 Änderungen sind noch nicht gesendet. Wenn du dich jetzt abmeldest, gehen sie verloren." Zwei Knöpfe: "Abbrechen" und in Rot #FF453A "Trotzdem abmelden".

---

### 4.11 Berechtigung abgelehnt

**Zweck.** "Warum geht der Standort (bzw. Kamera, Mikrofon, Mitteilungen, Health) nicht?" und der Weg dorthin.

**Wann.** Die Funktion wird benutzt, die iOS-Erlaubnis ist abgelehnt oder eingeschränkt. Die Erklärung vor der ersten Systemabfrage steht am Ort (Zeile bzw. Unterzeile, Kap. 17 6.2), nicht als Sheet.

**Aufbau.** `StatusRow` an der Stelle der Funktion: Symbol der Funktion in `labelSecondary` (`location`, `camera`, `mic.slash`, `bell`, `heart`), Satz in `label`, schlicht "In Einstellungen erlauben" (öffnet die iOS-Einstellungen der App).

| Funktion | Text |
|---|---|
| Standort | "Standort ist aus. Postleitzahl eintragen oder in Einstellungen erlauben" |
| Kamera | "Kamera ist nicht erlaubt. In Einstellungen erlauben" |
| Mikrofon, Spracherkennung | "Mikrofon ist nicht erlaubt. In Einstellungen erlauben" |
| Mitteilungen | "Mitteilungen sind aus. In Einstellungen erlauben" |
| Apple Health | "Apple Health ist nicht erlaubt. In Health erlauben" (Kap. 15) |

**Zustände.** Kehrt man aus den Einstellungen zurück und die Erlaubnis ist da: Zeile verschwindet, die Funktion startet nicht von selbst (man tippt erneut).

**AX und 320 pt.** wie 4.3.

**Was sich ändert.** Heute: Mitteilungsabfrage beim ersten Start, Standortabfrage beim ersten Startseiten-Besuch ohne Erklärung (`perf.md` 2.6). Betroffen: `notification_service.dart`, `user_location_service.dart`, `price_comparison_provider.dart` (B; `allowPermissionPrompt` nur auf Nutzer-Tipp).

**Bildbeschreibung für ChatGPT.** Ausschnitt einer Einstellungsseite "Preise & Angebote" im Hellmodus auf #F2F2F7: eine weiße Sektion "Region" mit der Zeile "Postleitzahl" und dem Wert "80331" in Grau rechts. Darüber eine Zeile ohne Fläche mit grauem Standortpfeil-Symbol #636366 und schwarzem Text "Standort ist aus. Postleitzahl eintragen oder in Einstellungen erlauben", wobei "In Einstellungen erlauben" grün #3F7A1F ist. Keine Warnfarbe, kein Dialog.

---

### 4.12 Entwickler: Prüfansicht und Leistungsanzeige (nur Debug-Build)

**Zweck.** "Sieht dieser Screen bei 320 pt mit AX5 und fettem Text richtig aus?" Ohne für jede Kombination den Simulator umzustellen.

**Wann.** Nur in Debug- und Profile-Builds, über das Entwicklermenü (Langdruck auf die Versionsnummer in Hilfe, 00 15.2) bzw. Route `/debug/matrix`. In Release-Builds nicht vorhanden (kein Code im Bundle, `kReleaseMode`-Weiche).

**Aufbau.**
- Ein Push-Screen "Prüfansicht" mit `InsetSection`s: "Breite" (`SegmentedControl` 320, 375, 390, 402, 440 bzw. bei AX als Pull-down-Menü), "Höhe" (Gerät des gewählten Rasters: SE 568/667, 13 Pro 693/844 …), "Textgröße" (Pull-down: xS bis AX5), `ToggleRow`s "Fetter Text", "Dunkel", "Kontrast erhöhen", "Bewegung reduzieren", "Transparenz reduzieren", "Abgeschnittenen Text markieren", "Trefferflächen unter 44 pt markieren", "Leistungsanzeige".
- Schaltfläche prominent "Übernehmen": Die ganze App läuft danach in einem zentrierten Rahmen der gewählten Größe (Rest schwarz), mit überschriebenem `MediaQuery` unter dem `DesignScope`.
- Eine kleine, Flutter-gezeichnete Kapsel oben rechts "390 · AX3 · fett" zeigt den aktiven Zustand; Tippen öffnet die Prüfansicht wieder, Langdruck setzt zurück.

Native Views (Glas, Tab-Bar, Symbole) kennen den Rahmen nicht; in der Prüfansicht werden sie durch ihre Flutter-Rückfälle ersetzt (`glassFallback`, Flutter-Tabs, Symbol-Platzhalter in richtiger Größe). Deshalb ersetzt die Prüfansicht nicht die Geräte-Abnahme (7.6), sondern macht Fehler schnell sichtbar.

**Markierungen.**
- Abgeschnittener Text: jeder `RenderParagraph`, dessen nötige Höhe größer ist als seine Größe, oder der mit Ellipse außerhalb der erlaubten Orte (00 5.3) abschneidet, bekommt einen 2-pt-Rahmen in `danger`.
- Trefferflächen: jedes antippbare Element unter 44 × 44 pt bekommt eine Fläche in `warning` mit 30 % Deckung.
- Leistungsanzeige: Flutters `PerformanceOverlay` (UI- und Raster-Thread).

**Beispielinhalt.** "390 · AX3 · fett · dunkel" über der Liste "Wocheneinkauf".

**Zustände.** Nicht persistent über Neustarts (damit niemand versehentlich so testet und vergisst). Kein Netzbezug.

**Was sich ändert.** Neu. Ergänzt die Komponenten-Galerie `/debug/components` (00 17.4). Betroffen: neue Dateien `lib/presentation/screens/debug/layout_matrix_screen.dart` und `lib/core/design/debug_matrix_scope.dart` (A).

**Bildbeschreibung für ChatGPT.** Kein Bild nötig (nur Entwickler). Falls doch: iPhone-Screen im Dunkelmodus, in der Mitte die App-Liste "Wocheneinkauf" in einem schmaleren Rahmen von 320 pt Breite mit sehr großer Schrift, links und rechts schwarze Ränder; oben rechts eine kleine graue Kapsel "320 · AX5 · fett"; ein Artikelname ist rot umrahmt.

---

## 5. Leistungsbudget

### 5.1 Frame-Budget und Messszenarien

Gemessen auf dem iPhone 13 Pro (120 Hz), Profile-Modus, Impeller (Standard auf iOS; dadurch kein Shader-Ruckeln beim ersten Mal). Grenzen gelten für Build (UI-Thread) und Raster getrennt.

| Nr. | Szenario | Ablauf | Ziel | Grenze |
|---|---|---|---|---|
| S1 | Liste scrollen | "Wocheneinkauf" mit 60 Artikeln in 8 Kategorien, mit Artikelbildern, je 3 Würfe hoch und runter | 90. Perzentil ≤ 8,3 ms | kein Frame > 16 ms |
| S2 | Abhaken in Serie | Einkaufsmodus, 20 Artikel im Abstand von 300 ms abhaken | ≤ 8,3 ms | > 16 ms nie, auch nicht beim Wandern nach "Im Wagen" |
| S3 | Hinzufügen | 10 Artikel per Return mit offenem Vorschlags-Panel | ≤ 8,3 ms | Tastatur und Panel ruckeln nie |
| S4 | Tab-Wechsel | Liste, Rezepte, Plan, Kalorien, Liste, 10 Runden | erster Frame des Ziel-Tabs ≤ 8,3 ms | ≤ 16 ms |
| S5 | Rezepte-Tab scrollen | alle Abschnitte mit Fotos, kalter Bild-Cache | ≤ 8,3 ms | ≤ 16 ms; Dekodierung nie auf dem UI-Thread |
| S6 | Einkaufsmodus starten und beenden | Morph der Bodenebene, Zeilen wachsen auf Einkaufsmaß | ≤ 8,3 ms | ≤ 16 ms; sonst Rückfall Überblendung (00 10.2) |
| S7 | Rückkehr aus dem Hintergrund | Liste offen, 60 s Hintergrund, Lena hat 5 Artikel abgehakt | keine Frames > 16 ms beim Einspielen | Liste aktuell innerhalb von 1 s nach Rückkehr (mit Netz) |
| S8 | Geteilte Liste live | zweites Gerät hakt 10 Artikel im Abstand von 1 s ab | ≤ 8,3 ms | ≤ 16 ms |
| S9 | Menü öffnen | Titelmenü mit 8 Listen, `ellipsis`-Menü | ≤ 8,3 ms | ≤ 16 ms |

Zusätzlich: Speicher nach 10 Wiederholungen von S1 bis S5 stabil (kein stetiges Wachstum; Instruments "Allocations"), keine Hänger über 250 ms (Instruments "Hangs").

### 5.2 Glas-Budget je Screen

Regel aus 00 8.5: höchstens drei native Glas-Views gleichzeitig, kein `BackdropFilter`. Präzisierung (11.1): Der Rückgängig-Hinweis ist keine eigene View, sondern eine Form in der Glasgruppe der Bodenebene (E-05 in Kap. 11); ein offenes Menü zählt als vorübergehende vierte View und ist erlaubt, solange es offen ist, wenn sich darunter nichts animiert.

| Screen | Dauerhafte Glas-Views | Vorübergehend | Summe |
|---|---|---|---|
| Tab Liste (Wurzel) | Tab-Bar mit Avo-Kreis, Accessory (mit Rückgängig-Form), Toolbar oben | Menü (Titel, `ellipsis`, `text.viewfinder`) | 3 (+1) |
| Tab Liste, Accessory fokussiert | Accessory (Tab-Bar ausgeblendet und aus dem Baum genommen), Toolbar oben | – | 2 |
| Einkaufsmodus | Bodenleiste (mit "+", "Einkauf beenden", Avo-Kreis; Tab-Bar-View im Modus `shopping`), Toolbar oben | Rückgängig-Hinweis (eigene Fläche erlaubt, E-05) | 2 (+1) |
| Alle Listen, Verlauf, Angebote der Woche (Push) | Tab-Bar, Toolbar oben (Zurück und Aktionen als eine Gruppe) | Menü | 2 (+1) |
| Tab Rezepte | Tab-Bar, Toolbar oben | Menü | 2 (+1) |
| Rezeptdetail | Tab-Bar, Toolbar oben (Variante `clear`), Aktionsleiste (mit Rückgängig-Form) | Menü | 3 (+1) |
| Kochmodus | Steuerung, Toolbar oben, Avo-Kreis (Tab-Bar-View im Modus nur Kreis) | – | 3 |
| Tab Plan | Tab-Bar, Toolbar oben, Aktionsleiste "Zutaten auf …" (mit Rückgängig-Form) | Menü | 3 (+1) |
| Tab Kalorien | Tab-Bar, Toolbar oben | Menü | 2 (+1) |
| Onboarding, Fehlerseite | Toolbar oben (bzw. Zurück) | – | 1 |
| Einstellungen (Push-Seiten) | Toolbar oben; Tab-Bar verdeckt bzw. nicht vorhanden je nach Kap. 18 | – | 1 bis 2 |

Kapitel, die Sheets wegen der Owner-Regel durch Vollbild-Pushes ersetzen, landen damit automatisch bei 1 bis 2 Views; das entlastet das Budget.

**Weitere Regeln:**
- Glas-Views ändern ihre Größe nur, wenn sich ihr Inhalt ändert (Textlänge, Dynamic Type, Modus), und dann über den Update-Kanal (00 8.4), nie in jedem Frame einer Scroll- oder Listen-Animation.
- Während eines Push-Übergangs und des Zurück-Wischens bleiben Glas-Views stehen; die Tab-Bar animiert nicht mit dem Inhalt.
- Kein Glas in scrollenden Zeilen; keine Platform View in Zeilen (Schalter, Segmente, Menüinhalte sind Flutter, K-31).
- Unsichtbare Glas-Views werden aus dem Baum genommen, nicht nur verdeckt (00 8.4).
- Ein viertes dauerhaftes Glas-Element braucht eine Messung (S1, S4) auf dem iPhone 13 Pro und eine Begründung in der Status-Datei (00 8.5).

### 5.3 Animationen

- Nur Federn aus `AppMotion` (00 10.1); feste Dauern nur `fadeReduced`.
- **Was neu zeichnet, bekommt eine `RepaintBoundary`:** `CheckCircle`, `RollingNumber`, `ProgressRing`, jede `ItemRow`, die Fortschrittslinie. Ein Häkchen zeichnet nur seinen Kreis und den Zähler neu, nicht die Liste.
- **Wandern und Einwachsen** über die Sliver-Liste (animierte Höhe einer Zeile), nicht über `AnimatedSize` um ganze Sektionen. Gleichzeitig animieren höchstens die betroffenen Zeilen und ihre direkten Nachbarn; was außerhalb des sichtbaren Bereichs liegt, springt ohne Animation.
- **Einkaufsmodus-Morph (S6):** die Zeilenmaße wechseln über einen einzigen Wert (0 bis 1), der Höhe, Schrift und Kreis interpoliert. Liegt das Layout dabei über 4 ms pro Frame, gilt der Rückfall: beide Listen fertig gelayoutet und in 0,25 s überblendet (00 10.2).
- **Rollende Ziffern** zeichnen pro Ziffer in einem `ClipRect`, ohne Text neu zu setzen.
- **Keine Endlos-Animationen** außer dem Avo-Kern im Zustand `denkt` (nativ in der Tab-Bar-View bzw. als eigene `RepaintBoundary`).
- **Haptik** im selben Frame wie die sichtbare Änderung (00 11), ausgelöst vom Animationsstart, nicht vom Netz-Ergebnis.
- **Reduce Motion** (00 10.4) ist auch eine Leistungsentlastung; trotzdem gelten dieselben Grenzen.

### 5.4 Listen, Bilder, Speicher

- Listen nur als Slivers mit Builder; keine `Column` mit allen Zeilen, keine `shrinkWrap`-Listen in Scrollviews.
- Riverpod `select` pro Artikel (00 17.8); ein Häkchen baut eine Zeile, den Zähler und die Sektionsanzahl neu, sonst nichts.
- Keine Netzaufrufe, Dateizugriffe oder JSON-Dekodierung während `build`. Große JSON-Dateien werden mit `compute` (Hintergrund-Isolate) dekodiert, wenn sie größer als 100 KB sind (Rezepte).
- Bilder: `CachedNetworkImage` mit `memCacheWidth` = logische Breite × Pixelverhältnis; nie `Image.network` in scrollenden Listen (heute 11 Stellen). Die nächsten zwei Fotos einer Reihe vorladen (`precacheImage`). Mahlzeitenfotos als Vorschau in Anzeigegröße speichern, nicht 1024 px in eine 32-pt-Zeile dekodieren.
- Avatare über denselben Cache (heute `NetworkImage`), Google-Logo als gebündeltes Asset (heute bei jedem Login geladen).
- Artikel-Notifier: die Liste von heute und die drei zuletzt geöffneten bleiben im Speicher; alle anderen werden 30 s nach dem letzten Beobachter freigegeben (heute nie, `perf.md` 4.3 Punkt 11).
- SF Symbols aus dem Cache des Kanals `shoply/symbols`, vorgerendert beim Start (00 9.3); beim Scrollen wird nie gerendert.

### 5.5 Start- und Netzbudget

| Messgröße | Zielwert (vor Baseline-Messung) | Gemessen mit |
|---|---|---|
| Arbeit vor `runApp` (Startstand, Liste von heute, Journal) | ≤ 150 ms | Zeitstempel im Profile-Build |
| Prozessstart bis erster Frame mit Inhalt (Kaltstart, Release) | ≤ 800 ms | `flutter run --profile --trace-startup` (`timeToFirstFrameMicros`), Instruments "App Launch" |
| Warmstart bis bedienbar | ≤ 200 ms | Instruments |
| Erster Frame bis Abgleich der Liste von heute fertig (gutes Netz) | ≤ 1,5 s, unsichtbar | Log |
| Netzaufrufe vom Gerät pro Häkchen (private Liste) | 1 | Supabase-Logs |
| Netzaufrufe beim Kaltstart bis zum ersten Abgleich | ≤ 4 (Listen mit Zählern, Artikel der Liste von heute, Pro-Status, `app_flags`) | Supabase-Logs |

---

## 6. Geräte- und Schriftmatrix

### 6.1 Geräte

| Breite | Gerät (Beispiel) | Logische Größe (pt) | Pixelverhältnis | Sicherer Bereich oben / unten (pt, Startwert) | Warum in der Matrix |
|---|---|---|---|---|---|
| 320 | iPhone SE 3 mit Anzeigezoom | 320 × 568 | 2 | 20 / 0 | schmalster und niedrigster Fall: Accessory, Tastatur und Tab-Bar zusammen |
| 320 | iPhone 13 Pro mit Anzeigezoom "Größerer Text" | 320 × 693 | 3 | 47 / 34 | Gerät der Mutter |
| 375 | iPhone SE 3. Gen | 375 × 667 | 2 | 20 / 0 | Home-Taste, kein Home-Indikator |
| 375 | iPhone 13 mini | 375 × 812 | 3 | 50 / 34 | schmal mit Notch |
| 390 | iPhone 13 / 13 Pro / 14 | 390 × 844 | 3 | 47 / 34 | Leistungs-Referenzgerät |
| 402 | iPhone 17 Pro | 402 × 874 | 3 | 62 / 34 | aktuelles Standardgerät mit Dynamic Island |
| 440 | iPhone 17 Pro Max | 440 × 956 | 3 | 62 / 34 | breit: `pageMargin` 20 (00 6.2) |

Die sicheren Bereiche sind Startwerte für die Tests; Teil A misst sie einmal im Simulator nach (`MediaQuery.paddingOf` ausgeben) und trägt die Ist-Werte in `test/layout/devices.dart` ein. 393 pt (iPhone 15, 16) liegt zwischen 390 und 402 und wird über diese abgedeckt.

### 6.2 Textgrößen

Flutter bekommt auf iOS einen linearen Faktor = Body-Größe / 17 (00 5.3). Für die Tests wird genau dieser Faktor gesetzt; der `DesignScope` leitet daraus die Kategorie ab.

| Kategorie | xS | S | M | **L** | xL | xxL | **xxxL** | AX1 | AX2 | **AX3** | AX4 | **AX5** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Body (pt) | 14 | 15 | 16 | 17 | 19 | 21 | 23 | 28 | 33 | 40 | 47 | 53 |
| Faktor | 0,824 | 0,882 | 0,941 | 1,000 | 1,118 | 1,235 | 1,353 | 1,647 | 1,941 | 2,353 | 2,765 | 3,118 |

Fett gesetzt = Pflichtstufen der Matrix (00 14.3): Standard (L), größte normale Stufe (xxxL), AX3 und die größte Bedienungshilfen-Stufe AX5. xS wird einmal pro Screen als Sichtprobe mitgenommen (zu kleine Trefferflächen, zu viel Leerraum).

### 6.3 Kombinationen

Volle Matrix für die harten Prüfungen (Überlauf, abgeschnittener Text, Trefferflächen, Labels), Golden-Bilder nur für eine Auswahl.

| Dimension | Werte | Anzahl |
|---|---|---|
| Gerät | 320 × 568, 320 × 693, 375 × 667, 390 × 844, 402 × 874, 440 × 956 | 6 |
| Textgröße | L, xxxL, AX3, AX5 | 4 |
| Fetter Text | aus, an | 2 |
| Darstellung | hell, dunkel | 2 |

Das ergibt 96 Läufe pro Screen-Zustand für die harten Prüfungen (schnell, ohne Bilder). Kontrast erhöhen, Reduce Motion und Reduce Transparency laufen zusätzlich je einmal pro Screen bei 390 × 844, L, hell und dunkel (Kontrast-Prüfung mit `textContrastGuideline` in allen vier Darstellungen).

**Golden-Diagonale** (Bilder zur Sichtprüfung, pro Screen 6):

| Nr. | Gerät | Text | Fett | Darstellung |
|---|---|---|---|---|
| G1 | 390 × 844 | L | aus | hell |
| G2 | 402 × 874 | L | aus | dunkel |
| G3 | 375 × 667 | xxxL | aus | hell |
| G4 | 320 × 693 | AX3 | an | hell (Gerät der Mutter) |
| G5 | 320 × 568 | AX5 | an | dunkel |
| G6 | 440 × 956 | AX3 | aus | dunkel, Kontrast erhöht |

**Welche Zustände je Screen:** der Normalzustand mit dem Beispielinhalt des Kapitels, der leere Zustand, der Offline-Zustand mit `StatusRow`, und für Listen zusätzlich "Zeile nicht gespeichert" und ein Artikel mit langem Namen ("Bio-Vollmilch 3,8 % Fett, länger haltbar, 1 l") und Notiz.

### 6.4 Kritische Stellen je Breite und Textgröße

Was in der Prüfung besonders angeschaut wird (Abnahme-Checkliste, ergänzt die Regeln aus 00 6.3 und 6.4):

| Stelle | 320 pt | AX3 und AX5 |
|---|---|---|
| `AddItemAccessory` (Bug der Mutter) | Feld mindestens 160 pt breit, sonst wandert `text.viewfinder` ins Panel (E-04 in Kap. 11); "Einkaufen" nur als Symbol | Höhe aus Textmetrik, ab AX3 höchstens 2 Zeilen, Text nie oben oder unten angeschnitten; mit Tastatur bleibt mindestens eine Artikelzeile sichtbar (bei 320 × 568 und AX5: Tastatur-Vorschläge des Systems berücksichtigen) |
| `AppTabBar` | nur Symbole, Large Content Viewer | nur Symbole ab AX1; Höhe wie System |
| Großer Titel mit `chevron.down` | bis 2 Zeilen, dann Ellipse; Chevron nach dem letzten Wort, nie allein in einer Zeile | gleich; Avatar bleibt 36 pt |
| Metazeile (Markt-Chip, "11 offen", Präsenz) | bricht in 2 Zeilen | `Wrap`, Chip-Punkt bis AX2 |
| `ItemRow` | Menge und Schild rechts; langer Name bricht um | Menge unter dem Namen, Bild entfällt, Kreis oben bündig |
| Haftende Gang-Titel (Einkaufsmodus) | kurze Namen (E-01) einzeilig | bricht um; Haft-Kopf darf höchstens 25 % der Höhe einnehmen, sonst haftet er nicht |
| Bodenleiste Einkaufsmodus | "Einkauf beenden" ab AX3 nur Symbol (E-08) | "Beenden" ab AX1 |
| `StatusRow` | bricht um | Aktion unter dem Text |
| Rückgängig-Hinweis | Text und "Widerrufen" untereinander, wenn nötig | ebenso; bleibt über der Bodenebene, verdeckt nie das Accessory |
| Alerts, Menüs | System bzw. bildschirmhoch scrollend | ebenso |
| Paywall-Pläne | untereinander (00 6.3) | untereinander, Preis unter dem Namen |
| Zwei Buttons nebeneinander | untereinander, sobald einer umbrechen müsste | ab AX1 immer untereinander |

---

## 7. Prüfverfahren

### 7.1 Das Gerüst `test/layout/` (Teil A, bis S2)

**Dateien:**

| Datei | Inhalt |
|---|---|
| `test/layout/devices.dart` | die Geräte aus 6.1 (Größe, Pixelverhältnis, sichere Bereiche) |
| `test/layout/text_sizes.dart` | Kategorien und Faktoren aus 6.2 |
| `test/layout/matrix.dart` | `layoutMatrix(...)`: erzeugt pro Kombination einen `testWidgets`-Lauf |
| `test/layout/checks.dart` | Prüfungen aus 7.2 |
| `test/layout/fakes.dart` | Ersatz für native Kanäle (Glas, Tab-Bar, Symbole, Haptik, Gerät), lokaler Speicher im Arbeitsspeicher, Fake-Warteschlange, Fake-Verbindung |
| `test/layout/fonts/` | Inter (SIL Open Font License) als Ersatz für SF Pro, geladen unter den Familiennamen `CupertinoSystemText` und `CupertinoSystemDisplay` |
| `test/layout/screens/*_matrix_test.dart` | ein Test pro Screen; Teil B legt seine in `test/layout/screens/b/` an (Besitz B, 11.7) |

**Verwendung (Beispiel):**

```dart
layoutMatrix(
  'Tab Liste',
  build: (fixture) => ListTabScreen(listId: fixture.weeklyShop.id),
  states: {
    'normal': Fixture.weeklyShop(),
    'leer': Fixture.emptyList(),
    'offline': Fixture.weeklyShop(connection: Connection.offline, pending: 2),
    'nicht gespeichert': Fixture.weeklyShop(failedItem: 'Spülmittel'),
    'langer Name': Fixture.weeklyShop(extraItem: 'Bio-Vollmilch 3,8 % Fett, länger haltbar, 1 l'),
  },
);
```

**Wie ein Lauf aufgebaut ist:**
1. `tester.view.physicalSize` und `devicePixelRatio` nach Gerät; `tester.view.padding` nach sicherem Bereich (in physischen Pixeln).
2. Über der App ein `MediaQuery` mit `textScaler: TextScaler.linear(faktor)`, `boldText`, `platformBrightness`, `highContrast`, `disableAnimations`; darunter der echte `DesignScope` (er neutralisiert den Faktor und setzt Endgrößen, 00 17.2), damit genau der Produktionsweg geprüft wird.
3. Native Views rendern im Test ihren Flutter-Rückfall (`glassFallback`); der Symbol-Kanal liefert graue Platzhalter in der richtigen Größe; Haptik wird gezählt, nicht ausgeführt.
4. Daten kommen aus Fixtures im lokalen Speicher (Arbeitsspeicher), Netz ist ein Fake mit steuerbarer Antwortzeit.
5. `pumpAndSettle` mit Zeitgrenze; Endlos-Animationen sind in Tests aus.

**Schrift:** SF Pro darf nicht gebündelt werden (00 5.1, Lizenz), Flutters Testschrift (Kästchen) liefert falsche Breiten. Inter hat ähnliche Laufweiten und Höhen wie SF Pro; Abweichungen von wenigen Prozent in der Breite sind möglich. Deshalb: der Test ist die schnelle Schranke, die Simulator- und Geräteprüfung (7.5, 7.6) die Bestätigung mit echter Schrift.

### 7.2 Prüfungen je Kombination

| Prüfung | Umsetzung | Schlägt fehl bei |
|---|---|---|
| Kein Überlauf | Flutter meldet Überläufe als Fehler; `tester.takeException()` muss `null` sein | gelb-schwarzer Streifen, `RenderFlex overflowed` |
| Kein abgeschnittener Text | Baum ablaufen: für jeden `RenderParagraph` gilt `getMinIntrinsicHeight(size.width) <= size.height + 0,5` und `didExceedMaxLines == false`, außer an erlaubten Ellipsen-Orten (Markierung `AllowEllipsis` an Listenname im eingeklappten Titel, Rezepttitel in kleinen Karten, großem Titel ab der 3. Zeile) | Text höher als sein Kasten (genau der Eingabeleisten-Bug), unerlaubte Ellipse |
| Kein horizontales Scrollen | keine waagerecht scrollbare Fläche außer markierten (Chip-Reihen bis xxL, Rezept-Reihen) | Inhalt breiter als der Screen |
| Trefferflächen | `meetsGuideline(iOSTapTargetGuideline)` (44 × 44) und `meetsGuideline(labeledTapTargetGuideline)`; im Einkaufsmodus zusätzlich eigene Prüfung 56 pt für den Kreis | zu kleine oder unbeschriftete Ziele |
| Kontrast | `meetsGuideline(textContrastGuideline)` in hell, dunkel und beiden Kontrastvarianten | Text unter 4,5:1 bzw. 3:1 |
| Kein Spinner | `find.byType(CupertinoActivityIndicator)` und `CircularProgressIndicator` finden nichts (außer `AppButton` im Arbeitszustand) | Ladeanzeige im Zustand "lokaler Stand vorhanden" |
| Reduce Motion | mit `disableAnimations: true` abhaken; die Zeile bleibt an ihrer Position, bis 1 s ohne Eingabe vergangen ist (00 10.4) | Zeile springt unter dem Finger weg |

### 7.3 Golden-Bilder

- Sechs Bilder pro Screen-Zustand nach der Diagonale (6.3), Ordner `test/layout/goldens/<screen>/`.
- Zweck ist die **Sichtprüfung im Review**, nicht der pixelgenaue Vergleich auf jedem Rechner. Goldens tragen das Tag `golden`; die CI (`.github/workflows/check.yml`, Ubuntu) läuft mit `flutter test --exclude-tags golden`, weil die Schriftdarstellung zwischen macOS und Linux abweicht.
- Erzeugt und verglichen werden sie auf den Macs: `flutter test --tags golden --update-goldens` nach einer bewussten Änderung; der Diff der PNGs ist Teil des Commits und wird im Review angesehen.
- Beide Macs nutzen dieselbe Flutter-Version (laut Repo 3.47 gepinnt), damit die Bilder gleich ausfallen. Weichen sie trotzdem ab, gilt der Mac des Besitzers der Datei.

### 7.4 Verhaltenstests für Tempo und Zustände

Diese Tests gehören dem Besitzer der getesteten Datei (`arbeitsteilung.md`), nutzen aber die Fakes aus `test/layout/fakes.dart`.

| Test | Ablauf | Erwartung |
|---|---|---|
| Zweites Öffnen | Speicher mit "Wocheneinkauf" füllen, App starten, Netz antwortet erst nach 5 s | erster Frame zeigt 11 Artikel; kein Spinner, kein Skelett |
| Sprungtest | lokaler Stand, ans Ende von "Obst & Gemüse" scrollen, Abgleich bringt 2 neue Artikel in "Brot & Backwaren" (oberhalb) und 1 in "Getränke" (unterhalb) | `getTopLeft` der ersten sichtbaren Zeile vor und nach dem Abgleich gleich |
| Hinweis-Zeilen fest | Startstand mit einer Hinweis-Zeile, Abgleich berechnet zwei neue | sichtbar bleibt die alte, die neuen erst beim nächsten Öffnen |
| Abhaken offline | Verbindung offline, 5 Artikel abhaken, App-Neustart simulieren (Journal neu lesen), Verbindung online | 5 Patches gesendet, Sync-Zeichen weg, `StatusRow` weg |
| Zusammenfassen | offline: hinzufügen, Menge ändern, löschen | 0 Aufrufe beim Senden |
| Endgültiger Fehler | Server lehnt Patch für "Spülmittel" ab, parallel wird "Gurke" abgehakt | nur "Spülmittel" zurück und "Nicht gespeichert"; "Gurke" bleibt abgehakt; Fehler-Haptik genau einmal |
| Idempotenz | Upsert läuft in Timeout, Wiederholung | genau eine Zeile auf dem Server |
| Hinzufügen ohne KI | "2 Milch" eingeben, KI-Fake antwortet nach 5 s mit anderer Kategorie | Zeile nach einem Frame mit Menge 2 in "Milch & Käse"; nach 5 s wandert sie ohne Sprung |
| Kein Remount | Theme im Startstand dunkel, Server sagt hell (ältere Wahl) | `AvoApp` einmal gebaut, Theme bleibt dunkel |
| Modul-Route | Kalorien aus, `/calories/add` öffnen | Alert 4.9, nach "Einschalten" Ziel offen |
| Fehlerseite | `/irgendwas` öffnen | Fehlerseite 4.8, `xmark` führt zu `/home` |
| Timeout | Lesen hängt | nach 8 s Zustand "eingeschränkt", lokaler Stand bleibt |

### 7.5 Simulator-Prüfung (echte SF-Schrift, echtes Glas)

Auf dem Mac mit knappem Speicher genügen drei Simulatoren: iPhone SE (3. Generation), iPhone 17 Pro, iPhone 17 Pro Max (vorher `df -h /System/Volumes/Data`, siehe `CLAUDE.md`).

Umschalten ohne die Einstellungs-App:

```bash
xcrun simctl ui booted appearance dark                 # bzw. light
xcrun simctl ui booted content_size accessibility-extra-large            # AX3
xcrun simctl ui booted content_size accessibility-extra-extra-extra-large  # AX5
xcrun simctl ui booted content_size extra-extra-extra-large              # xxxL
xcrun simctl ui booted content_size large                                # L
xcrun simctl ui booted increase_contrast enabled       # bzw. disabled
xcrun simctl io booted screenshot ~/Desktop/liste_ax5_dunkel.png
```

Fetter Text, Transparenz reduzieren, Bewegung reduzieren und Anzeigezoom werden in der Einstellungs-App des Simulators gesetzt (Bedienungshilfen bzw. Anzeige & Helligkeit). Ob der Anzeigezoom im Simulator für SE 3 und 13 Pro verfügbar ist, prüft Teil A einmal und vermerkt es in der Status-Datei; sonst dient die Prüfansicht (4.12) für 320 pt und das echte Gerät (7.6) als Nachweis.

Pro umgebautem Screen: Screenshots der Golden-Diagonale (6.3) mit echter Schrift in die Status-Datei bzw. `docs/redesign/abnahme/<screen>/` (Ordner von dem Teil, dem der Screen gehört).

### 7.6 Abnahme auf echten Geräten

| Gerät | Einstellung | Pflicht-Abläufe |
|---|---|---|
| iPhone 13 Pro (Gerät der Mutter oder gleiches Modell) | Anzeigezoom "Größerer Text", Textgröße AX3, Fetter Text an | Artikel hinzufügen ("2 Milch", langer Name, 3 Zeilen), Liste wechseln, Einkaufsmodus mit 11 Artikeln, Abschluss, Rezept auf die Liste, Avo-Feld öffnen, Einstellungen > Module, Paywall öffnen und schließen |
| iPhone 13 Pro | Standard, Hell und Dunkel | Leistungsmessung (7.7) |
| iPhone SE (2. oder 3. Gen.) | Standard und AX5, Anzeigezoom an | Hinzufügen mit Tastatur (niedrigster Bildschirm), Einkaufsmodus, Onboarding |
| beliebiges iPhone | VoiceOver an | Startseite, Liste, Einkaufsmodus, Rezeptdetail, Avo, Paywall, Onboarding (00 14.3) |
| beliebiges iPhone | Flugmodus im Einkaufsmodus | 10 Artikel abhaken, App beenden, neu öffnen, Flugmodus aus: alles auf dem Server, zweites Gerät sieht die Häkchen |

Ergebnis: Screenshots und ein Satz pro Ablauf in der Status-Datei. **Der Bug der Mutter gilt erst als behoben, wenn der Screenshot der Eingabeleiste auf ihrem Gerät (oder einem iPhone 13 Pro mit identischen Einstellungen) die Eingabe vollständig lesbar zeigt.**

### 7.7 Leistungsmessung

1. Echtes iPhone 13 Pro per Kabel, `flutter run --profile` (nie Debug, nie Simulator für Zahlen).
2. Automatisch: Integrationstests unter `integration_test/perf/` (neuer Ordner, Besitz A; B legt eigene unter `integration_test/perf/b/` an) mit `IntegrationTestWidgetsFlutterBinding.watchPerformance` für die Szenarien S1 bis S9; die Zusammenfassung (Durchschnitt, 90. und 99. Perzentil, schlechtester Frame, getrennt nach Build und Raster) wird als JSON ausgegeben. Start: `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf/s1_scroll_list_test.dart -d <iPhone>`.
3. Von Hand: Flutter DevTools > Performance, für Ausreißer die Zeitleiste; Instruments für Start (App Launch), Speicher (Allocations) und Hänger.
4. Ergebnis mit Datum, Commit und Gerät in die Status-Datei; Regression = schlechtester Frame über 16 ms oder 90. Perzentil über 8,3 ms in einem Szenario, das vorher drunter lag.
5. Wann: vor jedem Merge, der Listen, Einkaufsmodus, Tab-Bar, Glas oder Datenschicht berührt; sonst einmal pro Woche.

Die Messung läuft nicht in der CI (kein echtes Gerät dort).

### 7.8 `tool/design_check.sh` (Teil A)

Läuft vor jedem Commit beider Teile (zusätzlich zu `check-ownership.sh`) und in der CI. Prüft `lib/presentation` und `lib/core/widgets`, ausgenommen die Token-Dateien und die Komponenten, die einen Baustein ausdrücklich kapseln.

| Regel | Muster | Quelle |
|---|---|---|
| Keine hart codierten Farben | `Color(0x`, `Colors.` außer `Colors.transparent` | 00 17.6 |
| Keine festen Schriftgrößen und Laufweiten | `fontSize:`, `letterSpacing:`, `FontWeight.` | 00 17.6 |
| Keine festen Dauern | `Duration(milliseconds` in Animationen, außer in `app_motion.dart` | 00 17.6 |
| Nur SF Symbols | `Icons.`, `CupertinoIcons.`, `LucideIcons.` | 00 17.6 |
| Haptik nur zentral | `HapticFeedback.` außer `app_haptics.dart` | 00 11 |
| Keine Snackbars, Material-Spinner, Unschärfe | `SnackBar(`, `CircularProgressIndicator`, `BackdropFilter` | 00 17.6 |
| Cupertino-Spinner nur im Button | `CupertinoActivityIndicator` außer `app_button.dart` | 00 13 |
| Keine Paper-Reste | `PaperColors`, `PaperTextStyles`, `PaperKicker`, `toUpperCase()` in Anzeigetexten | 00 17.6 |
| Keine festen Höhen um Text | `SizedBox(height:` direkt um `Text`/`TextField` (Heuristik) | 00 17.6 |
| **Keine Slider** (Owner-Regel) | `showModalBottomSheet`, `showCupertinoModalPopup`, `DraggableScrollableSheet`, `BottomSheet(`, `Slider(`, `CupertinoSlider(`, `RangeSlider(`, `Drawer(` | `CLAUDE.md` |
| Keine Netzbilder in Listen | `Image.network`, `NetworkImage(` | 5.4 |
| Kein Netz im Widget-Code | `Supabase.instance`, `.from('` in `lib/presentation` | 3.1 |
| Kein Remount der App | `ValueKey('$themeMode` bzw. `ValueKey(` mit Theme oder Sprache in `app.dart` | 2.2 |

Bestehende Treffer stehen in einer Ausnahmeliste `tool/design_check_allowlist.txt` pro Datei und schrumpfen mit jedem umgebauten Screen; neue Treffer brechen ab. Eine Datei, die umgebaut wurde, darf nicht mehr in der Ausnahmeliste stehen.

### 7.9 Definition of Done je Screen

Ein Screen gilt als fertig umgebaut, wenn:
1. `dart analyze`: 0 Errors, 0 Warnings; `tool/design_check.sh` ohne Treffer für seine Dateien.
2. Matrix-Test (7.1, 7.2) grün für alle Zustände des Screens; Goldens erzeugt und im Commit.
3. Verhaltenstests (7.4), soweit der Screen Daten zeigt oder schreibt.
4. Simulator-Screenshots der Diagonale mit echter Schrift (7.5).
5. Erster Frame mit lokalem Stand ohne Ladeanzeige; Offline-Zustand mit `StatusRow` geprüft.
6. Glas-Budget eingehalten (5.2), keine Platform View in Zeilen.
7. Bei Listen, Einkaufsmodus, Tab-Bar, Rezepte: Leistungsmessung (7.7) im Rahmen.
8. VoiceOver-Stichprobe: Reihenfolge, Labels, Aktionen.
9. Eintrag in der Status-Datei mit Screenshots.

---

## 8. Was sich gegenüber heute ändert (Dateien)

| Datei | Änderung | Teil |
|---|---|---|
| `lib/main.dart` | SharedPreferences einmal vorladen, Startstand und Liste von heute vor `runApp`, Provider-Overrides, gestaffelte Dienste (2.2), keine Mitteilungsabfrage beim Start | B |
| `lib/app.dart` | Remount-Schlüssel entfällt, `DesignScope`, `SystemChrome` nicht im `builder`, Lebenszyklus "resumed" für Abgleich (2.4) | A |
| `lib/routes/app_router.dart` | synchroner Redirect aus dem Startstand, `errorBuilder` (4.8), Modul-Routen öffnen den Alert (4.9) | A (Bereichsrouten B) |
| `lib/presentation/screens/main_scaffold.dart` | `_OfflineBanner` und `SlidingTabsContainer` entfallen (K-35) | A |
| `lib/data/services/offline_cache_service.dart` | wird Inhaltsspeicher in Dateien pro Konto; Rezepte nicht mehr als ein Blob in SharedPreferences | A |
| `lib/data/sync/` (neu): `local_store.dart`, `write_queue.dart`, `sync_status.dart`, `boot_state.dart` | Abschnitte 2.1, 3.3, 3.4 | A (Besitz in `owner.sh` eintragen, 11.7) |
| `lib/data/services/network_policy.dart` (neu) | Timeouts und Wiederholung (2.5) | B |
| `lib/data/services/connectivity_service.dart` | drei Zustände mit Erreichbarkeits-Probe | B |
| `lib/data/services/supabase_service.dart` | Aufrufe nur mit Timeout | B |
| `lib/data/repositories/item_repository.dart`, `list_repository.dart` | Geräte-IDs, Upserts, Patches nur geänderter Felder, kein `_touchList`, kein Push-Fan-out, gefilterte Realtime-Kanäle, Ereignisse als Patch | A |
| `lib/presentation/state/items_provider.dart`, `lists_provider.dart` | Seed aus dem Startstand, Warteschlange statt direktem Schreiben, Rückrollen pro Operation, `select` pro Artikel, autoDispose außer Liste von heute und drei zuletzt geöffneten | A |
| `lib/presentation/state/theme_provider.dart`, `language_provider.dart`, `subscription_provider.dart` | Startwert aus dem Startstand statt fest hell / `unknown` | A |
| `lib/presentation/state/recipes_provider.dart`, `data/services/recipe_service.dart` | Fehler werfen statt `[]`; nie leeren Inhalt in den Speicher schreiben; Rezept-Cache begrenzt | A |
| `lib/data/services/gemini_categorization_service.dart` (bzw. Claude-Nachfolger) | Kategorie im Hintergrund nach lokalem Ergebnis; Cache mit Obergrenze; Foto-Import in einem Aufruf; Timeouts | B |
| `lib/data/services/avo_assistant_service.dart`, `meal_photo_analysis_service.dart` | Streaming, Timeouts, Drossel | B |
| `lib/data/services/push_notification_service.dart`, `supabase/functions/*`, Migrationen | Push-Bündelung serverseitig; Trigger für `updated_at` und `list_events` | B |
| `lib/presentation/state/nutrition_provider.dart`, `shopping_history_provider.dart` und weitere B-Provider | lokaler Stand pro Tag bzw. Verlauf, keine autoDispose-Netzketten ohne Cache, optimistisch über die Warteschlange | B |
| `lib/presentation/providers/price_comparison_provider.dart` | hinter Modul und Sichtbarkeit; keine Standortabfrage ohne Nutzer-Tipp; `basketComparisonProvider` entfällt (Plan 8) | B |
| `lib/presentation/widgets/common/loading_indicator.dart`, `empty_state.dart` | entfallen bzw. ersetzt durch `EmptyState`, `SkeletonSection`, `StatusRow` | A |
| `lib/presentation/screens/lists/widgets/add_item_composer.dart` | wird `AddItemAccessory`; kein `SizedBox(height:)`, keine Messung nach dem Frame (Bug der Mutter) | A |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard`, `LaunchImage.imageset` | nur Systemhintergrund | B bzw. A (Asset) |
| `test/layout/*`, `integration_test/perf/*`, `tool/design_check.sh`, `tool/design_check_allowlist.txt` | neu | A (B-Unterordner B) |
| `pubspec.yaml` | `path_provider` direkt, `integration_test` als Dev-Abhängigkeit; Inter nur unter `test/` (kein App-Asset) | geteilt, eigener kleiner Commit |
| `.github/workflows/check.yml` | `flutter test --exclude-tags golden`, `tool/design_check.sh` | geteilt (nach Absprache) |

---

## 9. Abläufe

### 9.1 Kaltstart im Markt ohne Netz

1. Jannis steht bei Lidl im Keller, kein Netz. Tippt auf das App-Symbol.
2. Launch-Screen weiß, dann sofort Tab Liste "Wocheneinkauf" mit allen 11 Artikeln aus dem lokalen Stand.
3. Nach 1 s erscheint unter der Metazeile "Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist."
4. Tipp auf "Einkaufen": Morph in den Einkaufsmodus, Bildschirm bleibt an. `StatusRow` "Offline. Abhaken wird gespeichert und später gesendet."
5. Bananen, Gurke, Avocados abhaken: Kreise füllen sich, leichter Impuls, "3 von 11" rollt, Sync-Zeichen an den Kreisen.
6. Vergessen: "+" > "Backpapier" > Return: erscheint in "Haushalt & Drogerie" mit Sync-Zeichen.
7. An der Kasse kommt Netz: nach 1 bis 2 s verschwinden Sync-Zeichen und `StatusRow` ohne Meldung. Lena sieht auf ihrem iPhone die drei Häkchen in einem Bündel und eine gebündelte Mitteilung.

### 9.2 Abhaken im Funkloch und Neustart

1. Einkaufsmodus, Verbindung "eingeschränkt" (Netz da, Antworten bleiben aus).
2. Zwei Lesevorgänge laufen in den Timeout: `StatusRow` "Verbindung schlecht. 4 Änderungen werden gesendet, sobald es wieder geht."
3. Das iPhone beendet die App im Hintergrund (Speicher).
4. Neustart: Journal wird vor `runApp` gelesen; erster Frame zeigt die 4 Häkchen mit Sync-Zeichen.
5. Sobald eine Antwort durchkommt, sendet die Warteschlange in Reihenfolge; eine Wiederholung nach Timeout erzeugt keine Doppel.

### 9.3 Eine Änderung scheitert endgültig

1. Lena entfernt Jannis aus der Liste "Grillabend", während Jannis offline "Grillkohle" hinzufügt.
2. Netz zurück: Der Server lehnt ab (keine Rechte); alle Operationen dieser Liste entfallen.
3. Die Liste von heute wechselt nach 01 2.2 Regel 1 (Überblendung), Rückgängig-Hinweis ohne Aktion "„Grillabend“ gibt es für dich nicht mehr."
4. Anderer Fall, Liste noch da, nur eine Zeile abgelehnt: "Spülmittel" zeigt "Nicht gespeichert · Tippen zum Wiederholen", `StatusRow` "1 Änderung konnte nicht gespeichert werden. Erneut versuchen", Fehler-Haptik einmal. Tippen auf die Zeile wiederholt; Wischen "Verwerfen" setzt sie auf den Serverstand.

### 9.4 Rückkehr aus dem Hintergrund bei geteilter Liste

1. Jannis hat "Wocheneinkauf" offen, wechselt 20 Minuten zu einer anderen App.
2. Lena kauft bei REWE ein und hakt 5 Artikel ab; Realtime-Ereignisse hat Jannis' App nicht bekommen.
3. Rückkehr: Warteschlange senden, Liste in einer Abfrage holen, Unterschiede einspielen. Die 5 Zeilen bekommen Lenas Avatar für 2 s und wandern nach "Erledigt (5)"; liegt eine davon oberhalb der Leseposition, gleicht der Scroll-Anker aus.
4. VoiceOver sagt einmal "Lena hat 5 Artikel abgehakt".

### 9.5 Erste Anmeldung auf einem neuen iPhone

1. Willkommen > "Ich habe schon ein Konto" > Mit Apple fortfahren (Kap. 17).
2. Tab Liste zeigt das Skelett (4.2), Accessory sichtbar, deaktiviert.
3. Nach 0,8 s kommen die Listen: Überblendung in "Wocheneinkauf" (angeheftete Liste aus dem Konto).
4. Im Hintergrund werden die übrigen Listen, Rezepte und (mit Modulen) Plan und Kalorien vorgewärmt. Wer sofort in Rezepte wechselt, sieht dort ggf. das Rezepte-Skelett, nie einen Spinner.
5. Ab jetzt ist jeder weitere Start ohne Skelett.

### 9.6 Darstellung oder Sprache wechseln

1. Einstellungen > Darstellung > "Dunkel".
2. Der `DesignScope` blendet in 0,2 s um; Scrollposition, offene Seiten und Eingaben bleiben (heute: Neuaufbau, alles weg).
3. Sprache wechseln: Texte wechseln an Ort und Stelle; Stapel und Eingaben bleiben.

### 9.7 Einen umgebauten Screen prüfen (Entwickler)

1. Screen umbauen, `dart analyze`, `tool/design_check.sh`.
2. Matrix-Test anlegen (`test/layout/screens/…_matrix_test.dart`) mit den Zuständen aus 6.3; `flutter test test/layout/screens/…` grün.
3. Goldens erzeugen (`--tags golden --update-goldens`), PNGs ansehen, besonders G4 und G5.
4. Im Simulator mit `simctl` (7.5) die Diagonale mit echter Schrift durchgehen; Auffälliges zusätzlich in der Prüfansicht (4.12) bei 320 pt nachstellen.
5. Bei Listen, Einkaufsmodus, Tab-Bar, Rezepte: Leistungsmessung (7.7).
6. Definition of Done (7.9) abhaken, Status-Datei, Commit.

### 9.8 Leistungsmessung durchführen

1. iPhone 13 Pro anschließen, Akku über 50 %, kein Energiesparmodus.
2. Testdaten-Konto mit "Wocheneinkauf" (60 Artikel) und 30 Rezepten.
3. `flutter drive --profile` für S1 bis S9 nacheinander; JSON-Ergebnisse sammeln.
4. Ausreißer über 16 ms in DevTools öffnen, Ursache (Build, Layout, Raster, Platform View) notieren.
5. Ergebnis-Tabelle mit Commit in die Status-Datei.

### 9.9 Abnahme des Eingabeleisten-Bugs

1. iPhone 13 Pro: Anzeigezoom "Größerer Text", Textgröße AX3, Fetter Text an, Hell.
2. Tab Liste > "Artikel hinzufügen" antippen, "2 Milch" tippen: Text vollständig lesbar, weder oben noch unten angeschnitten; Vorschau-Zeile "Milch · Menge 2 · Milch & Käse" lesbar.
3. Langen Namen tippen ("Bio-Vollmilch 3,8 % Fett, länger haltbar, 1 l"): Feld wächst auf 2 Zeilen, dann scrollt es.
4. Dasselbe mit AX5, im Dunkelmodus und auf dem iPhone SE mit Anzeigezoom (320 × 568).
5. Screenshots in die Status-Datei; danach den Matrix-Test des Accessory als Regressionsschutz behalten.

---

## 10. Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| Q-01 | Lokaler Speicher: JSON-Dateien und Journal (kein neues natives Paket) oder Datenbank (sqflite/drift)? `pubspec.yaml` nennt frühere macOS-Build-Probleme mit sqflite (über `tflite_flutter`) und Hive. | Dateien zuerst; Datenbank nur, wenn Messung oder Funktionen (Suche über alle Artikel) es verlangen |
| Q-02 | Erlaubt die RLS auf `shopping_items` und `shopping_lists` vom Gerät gesetzte UUIDs und Upserts? | prüfen (Teil A mit B für Migrationen); sonst Migration |
| Q-03 | `DESIGN-STATUS.md` beschreibt die gewählte Richtung "D2 Glas" mit 5 Tabs (Home, Listen, Avo, Rezepte, Profil) ohne abgesetzten Avo-Knopf, mit Ausgaben- und Kalorien-Blöcken auf Home; 00 und 01 beschreiben Tab Liste plus 2 bis 4 Tabs und Avo-Kreis. Dieses Kapitel folgt 00 und 01. Welche Struktur gilt? | vor S2 klären; die Prüfmatrix und das Glas-Budget gelten für beide, die Tab-Bar-Zeile in 6.4 und 5.2 wäre anzupassen |
| Q-04 | `DESIGN-STATUS.md` sagt, Avo sei immer die echte 3D-Figur aus `assets/avo/`; 00 3.3 plant ein neu gezeichnetes flaches Vektor-Maskottchen. Betrifft Leistung (PNG-Dekodierung in Anzeigegröße) und Schärfe bei AX. | klären; bei PNG: Dekodierung in Anzeigegröße, nie größer als 2 × 160 pt |
| Q-05 | Wer stellt ein iPhone 13 Pro für Messungen und Abnahme (das Gerät der Mutter oder ein eigenes)? | ein festes Messgerät pro Team, Ergebnisse vergleichbar |
| Q-06 | Darf die Schrift Inter (OFL) als Testschrift in `test/layout/fonts/` ins Repo? | ja, nur unter `test/`, nicht im App-Bundle |
| Q-07 | Crash-Reporting: Firebase ist im Build teils Platzhalter (`perf.md` 6). Crashlytics einrichten? | ja (Plan 3 "Crash-Reporting prüfen"), Teil B |
| Q-08 | Stört der Wechsel von `systemBackground` (#FFFFFF) im Launch-Screen zu `bgGrouped` (#F2F2F7) im ersten Frame? | am Gerät ansehen; falls ja, Launch-Screen in `systemGroupedBackground` |
| Q-09 | Golden-Bilder in der CI auf macOS-Runnern laufen lassen (kosten mehr) oder nur lokal? | nur lokal, CI prüft Überlauf und Regeln |
| Q-10 | Soll bei endgültig gescheiterten Änderungen zusätzlich eine Seite "Nicht gesendete Änderungen" existieren (Liste aller Fehler über alle Listen)? | nein für Version 1; die Fehler stehen an ihren Zeilen, die `StatusRow` nennt die Anzahl |
| Q-11 | Sind die Zielwerte für den Start (5.5) realistisch? | nach der Baseline-Messung bestätigen oder anpassen |

---

## 11. Ergänzungen zum Fundament

Was dieses Kapitel braucht und in 00 bzw. 01 fehlt oder dort anders steht. Teil A übernimmt es in 00, bevor die betroffenen Bausteine gebaut werden.

### 11.1 Glas-Budget präzisieren (00 8.5)

- Der Rückgängig-Hinweis (00 12.28) ist eine Form in der Glasgruppe der jeweiligen Bodenebene (Accessory, Aktionsleiste Rezeptdetail, Aktionsleiste Plan) und morpht aus ihr nach oben (wie E-05 in Kap. 11). Nur wo die Bodenebene Budget frei hat (Einkaufsmodus, Screens mit 2 Views), darf er eine eigene Glasfläche sein.
- Ein offenes Menü (00 12.24) darf vorübergehend die vierte Glas-View sein, solange darunter nichts animiert; ein Menü und ein Rückgängig-Hinweis gleichzeitig als eigene Views sind nicht erlaubt (ein neuer Hinweis wartet, bis das Menü zu ist).

### 11.2 `StatusRow` und Sync-Zeichen erweitern (00 12.27, 12.7)

- Neue Variante **eingeschränkt** mit Symbol `wifi.exclamationmark` (in 00 9.2 ergänzen) und Texten aus 4.3.
- **Priorität** und **eine Zeile pro Screen** (Tabelle 4.3).
- **Verzögerungen gegen Flackern:** offline nach 1 s, "werden gesendet" nach 3 s, Fehler sofort; Sync-Zeichen an Zeilen online erst nach 2 s ausstehend, offline sofort.
- **Einkaufsmodus:** Text in `callout`.
- Das Sync-Zeichen sitzt auf einem 14-pt-Kreis in Flächenfarbe und wächst nicht mit Dynamic Type.
- Übernahme von E10-03 (Symbol im eingeklappten Titel) und E10-05 (Scroll-Anker) als allgemeine Regeln in 00 Kap. 13.

### 11.3 Hinweis-Zeilen bei großer Schrift (00 12.12, K-38)

Ab AX3 höchstens **eine** Hinweis-Zeile auf der Startseite (statt zwei), damit auf 320 × 568 die erste Artikelzeile im oberen Drittel beginnt. Welche, bestimmt die bestehende Relevanz-Reihenfolge.

### 11.4 Komponente `SkeletonSection` (neu, Teil A)

00 13 erlaubt ein Skelett, Kap. 12 hat keine Komponente dafür. Vorschlag: `SkeletonSection(rows:, variant: list | recipeRow | recipeHero | header)`: Tonflächen in `fill`, Höhen aus der Zeilenhöhe des passenden Textstils bei aktueller Textgröße, Breiten in Prozent, Kreise 24 pt in `fill`, Kapselform; ab AX1 randlos; keine Animation; VoiceOver ein Element "Wird geladen" mit Eigenschaft "beschäftigt"; Übergang zum Inhalt `fadeReduced`. Ersetzt `loading_indicator.dart`.

### 11.5 Zustands-Regeln ergänzen (00 Kap. 13)

| Zustand | Ergänzung |
|---|---|
| Nutzer-Aktionen | Geräte-IDs (E-03); Warteschlange mit Zusammenfassen und Idempotenz (3.3); Rückrollen pro Operation, nie Schnappschuss (3.4) |
| Fehler | Unterscheidung vorläufig (still wiederholen) und endgültig (an der Zeile zeigen) |
| Offline | dritter Verbindungszustand "eingeschränkt" (2.5) |
| Vollflächen-Fehler | Variante offline ohne Aktion, lädt automatisch (4.7) |
| Modul aus | **zentrierter Alert statt Sheet** (Owner-Regel, wie Kap. 17 9.10), Texte 4.9 |
| Berechtigung nötig | Erklärung am Ort statt Sheet (wie Kap. 17 6.2) |
| Abmelden | Senden versuchen, erst dann Rückfrage (4.10) |
| Unbekannte Route | Fehlerseite mit Fällen aus 4.8 |

### 11.6 Daten-Verträge zwischen A und B (Ergänzung zu `arbeitsteilung.md` Abschnitt 3)

| Baustein | Liefert | Nutzt | Signatur (stabil halten) |
|---|---|---|---|
| `bootStateProvider` | A (Bausteine), B (Laden in `main.dart`) | beide | Theme, Sprache, Module, Pro-Status mit Datum, Liste von heute, Onboarding-Flag, Hinweis-Zeilen |
| `LocalStore` | A | B für Kalorien, Plan, Verlauf, Angebote, Avo | `read<T>(scope, key)`, `write<T>(scope, key, value)`, `clearAccount()` |
| `WriteQueue` | A | B für alle eigenen Schreibvorgänge | `enqueue(op)`, `pendingCount(scope)`, `statusFor(entityId)`, `retry(entityId)`, `discard(entityId)` |
| `syncStatusProvider(scope)` | A | beide (`StatusRow`, Zeilen) | Anzahl ausstehend, Anzahl gescheitert, letzter Fehler |
| `connectionStateProvider` | B | beide | `online`, `offline`, `eingeschraenkt` |
| `NetworkPolicy` | B | A in den Repositories | Timeouts je Aufrufart (2.5), `guarded(call, kind)` |
| Server-Funktionen | B | A | Trigger `updated_at`, `list_events`, Push-Bündelung, atomarer Abschluss (E-09) |

### 11.7 Besitz neuer Ordner (`owner.sh`)

- `lib/data/sync/` → A
- `lib/data/services/network_policy.dart` → B
- `test/layout/screens/b/`, `integration_test/perf/b/` → B; übriges `test/layout/`, `integration_test/perf/`, `test_driver/` → A
- `tool/` → A
- `docs/redesign/abnahme/<screen>/` → Besitzer des Screens

### 11.8 Route und Komponente für die Prüfansicht

Route `/debug/matrix` (nur Debug und Profile) neben `/debug/components` in 01 7; `DebugMatrixScope` in `lib/core/design/` überschreibt `MediaQuery` unter dem `DesignScope` und schaltet native Views auf ihre Flutter-Rückfälle (4.12). Dieselbe Weiche nutzt das Testgerüst (7.1).

### 11.9 `design_check.sh` erweitern (00 17.6)

Zusätzlich zu 00 17.6: Owner-Regel "keine Slider" (Muster in 7.8), `Image.network`/`NetworkImage(`, Supabase-Zugriffe in `lib/presentation`, `CupertinoActivityIndicator` außerhalb von `AppButton`, Remount-Schlüssel; Ausnahmeliste pro Datei, die nur schrumpfen darf.

### 11.10 Symbole, die in 00 9.2 fehlen

| Funktion | Symbol |
|---|---|
| Verbindung schlecht | `wifi.exclamationmark` |
| Seite nicht gefunden | `questionmark.circle` (schon für Hilfe vergeben; hier 48 pt Light als Deko) |
| Entwickler-Prüfansicht | `ruler` |

### 11.11 Testschrift

Inter (OFL) unter `test/layout/fonts/` als Ersatz für SF Pro in Widget-Tests (7.1), registriert unter den Familien `CupertinoSystemText` und `CupertinoSystemDisplay`; nie im App-Bundle.
