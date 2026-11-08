# Verlauf, Einkauf abschließen und Kosten teilen: Screen-Spezifikation (Teil B, Paket B8)

Stand 08.11.2026. Bauplan für alle Screens rund um abgeschlossene Einkäufe: Einkauf abschließen, Erfolgsmoment,
Verlauf mit Monatsrückblick, Einkauf-Detail, Betrag, Kosten teilen (gleich und individuell, Erinnern), Offene Beträge,
dazu die drei Home-Abschnitte „Dein November“, „Ausgaben im Vergleich“ und „Letzte Einkäufe“ und die Hinweise zum
Kosten teilen. Damit kann B8 direkt gebaut werden, sobald Teil A mit S2 die Komponenten liefert. Diese Datei enthält
keinen Code.

Quellen und Rang: Aussehen aus D2 · Glas (`D2-Komponenten`, `X-Einkaufsmodus` für den Knopf „Einkauf abschließen“,
`D2-FuerDich` Abschnitte 3, 4 und 9, `X-Profil` für den Modul-Schalter). Funktion, Zustände, Texte und
Barrierefreiheit aus `docs/redesign/konzept/12-angebote-verlauf.md` (Abschnitte 1, 7 bis 10, 12.7 bis 12.10, 13),
dazu Kapitel 00, 01 und 20. Verträge aus `status-A.md` (Routen, Module, Übersetzungen), Regeln aus dem Plan Teil B
(Global Constraints) und `status-B.md`. Die Owner-Regeln gehen allem vor: keine Bottom-Sheets, keine Slide-in-Panels,
keine Drawer, keine Schieberegler, Bearbeiten im Vollbild, Avo nur als echte 3D-Figur und höchstens einmal pro
Bildschirmhöhe, Trefferflächen mindestens 44 pt. Wo D2 und Konzept sich widersprechen, steht in Abschnitt 5 eine
Empfehlung; sie gilt, bis der Owner entscheidet.

Komponentennamen in `Code-Schrift` sind Bausteine, die Teil A schon geliefert hat (S2a, `lib/presentation/widgets/
design/`) oder mit S2b liefert, oder B-eigene Bausteine aus Abschnitt 2.3. Was fehlt, steht als Anfrage in Abschnitt 6.
Alle Texte stehen Deutsch und Englisch hier und kommen in `lib/core/localization/translations/history.dart` (Präfix
`hist_`) bzw. `notifications.dart` (`notif_`). Wiederverwendet werden die A-Schlüssel `common_undo` („Widerrufen“),
`common_try_again` („Erneut versuchen“), `common_not_saved`, `common_offline`, `common_all`, `common_close`, `cancel`,
`common_not_now`, `common_discard_changes_title`, `common_discard`, `common_keep_editing`, `common_module_cost_split`.
Alle Texte sind mit `design:ux-copy` und `humanizer` geprüft: Du-Form, keine Ausrufezeichen, keine Emojis, keine
Werbesprache, „Markt“ statt „Laden“, „Mitteilungen“, „Pro“; Ersparnis nur mit „ca.“ und „laut Händler“, Angebote nur
„in deiner Region“. Die Bestandsschlüssel des alten Verlaufs (`history_savings_*`, `owed_to_me_line`, `i_owe_line`,
`payment_reminder_message`, `split_trip_nudge_*`, `copy_reminder`, `reminder_copied`, `delete_entry*`,
`no_shopping_history`, `shopping_day_line`, `activities_label` und die übrigen in `history.dart`) entfallen mit den
Screens, die sie heute nutzen.

## Inhalt

0. Überblick
1. Routen und Navigation
2. Bausteine und Maße aus D2
3. Regeln für alle Screens
4. Screens V1 bis V14
5. Konflikte zwischen D2 und Konzept
6. Anfragen an Teil A
7. Datenquellen und Lücken
8. Prüfliste für Screenshots

---

## 0. Überblick

Die Frage des ganzen Bereichs: **Was habe ich eingekauft, was hat es gekostet, und schuldet noch jemand etwas?** Die
häufigste Aufgabe ist der Abschluss im Laden: ein Tipp auf „Einkauf abschließen“, ein Tipp auf „Einkauf speichern“,
fertig. Alles andere (Betrag, Markt, Kosten teilen) ist vorausgefüllt oder freiwillig.

| Nr. | Screen | Route | Art |
|---|---|---|---|
| V1 | Einkauf abschließen | `/checkout/:listId` | Vollbild über der Tab-Leiste |
| V2 | Markt für diesen Einkauf | `/stores/pick?mode=trip` (Screen aus dem Paket Märkte) | Vollbild, Folgeschritt von V1 und V5 |
| V3 | Erfolgsmoment und Rückgängig | keine Route | Überlagerung `showSuccessMoment`, danach `AvoToast` |
| V4 | Verlauf mit Monatsrückblick | `/history?list=` | Push im Listen-Tab |
| V5 | Einkauf-Detail | `/history/:tripId` | Push im Listen-Tab |
| V6 | Betrag | `/history/:tripId/amount` | Vollbild |
| V7 | Kosten teilen | `/history/:tripId/split` | Vollbild |
| V8 | Offene Beträge | `/splits` | Push im Listen-Tab |
| V9 | Home „Dein November“ | Slot `HomeMonthCard` | B-Widget, A ordnet |
| V10 | Home „Ausgaben im Vergleich“ | Slot `HomeSpendingComparison` | B-Widget, A ordnet |
| V11 | Home „Letzte Einkäufe“ | Slot `HomeRecentTrips` | B-Widget, A ordnet |
| V12 | Hinweise Kosten teilen | Slot `HomeSplitHint` (neu, Anfrage A-V13) | B-Widget, A ordnet |
| V13 | Dialoge | keine Route | zentrierte Alerts |
| V14 | Mitteilungen | keine Route | Texte und Ziele |

„Erinnern“ ist kein eigener Screen: Es öffnet das System-Teilen aus V5 und V8 (Owner-Frage 7). Avo-Antwortkarten für
Verlauf und Kosten teilen stehen in `docs/redesign/b-screens/avo.md` Abschnitt 5.2; hier nur, wohin „Ansehen“ führt.

---

## 1. Routen und Navigation

### 1.1 Arten von Routen (Vertrag aus `status-A.md`, Datei `lib/routes/areas/history_routes.dart`)

| Art | Liste in der Bereichsdatei | Wo es öffnet | Kopf | Tab-Leiste |
|---|---|---|---|---|
| W (Wurzel) | `buildHistoryRoot` | A hängt `/history` als Push in den Listen-Branch | Glas-Knopf 44 `chevron.left` „Zurück“ | sichtbar |
| K (Kind) | `historyChildRoutes`, relativ (`':tripId'`) | im Listen-Branch über dem Verlauf | Glas-Knopf 44 `chevron.left` | sichtbar |
| V (Vollbild) | Kind mit `parentNavigatorKey: rootNavigatorKey` (`':tripId/amount'`, `':tripId/split'`) oder `historyRootRoutes` (absolut, `'/checkout/:listId'`) | Root-Navigator über der Tab-Leiste | `xmark` „Schließen“ (Beginn eines Ablaufs) bzw. `chevron.left` (Folgeschritt) | nicht sichtbar |
| B (Branch) | `historyBranchRoutes[AppBranch.lists]` (absolut, `'/splits'`) | Listen-Branch | Glas-Knopf 44 `chevron.left` | sichtbar |

Übergang: Jede Route öffnet mit dem iOS-Push von rechts und schließt per Zurück-Wischen vom linken Rand. Nichts gleitet
von unten herein. Auf V1, V6 und V7 ist das Zurück-Wischen gesperrt, solange es ungespeicherte Änderungen gibt; dann
fragt „Schließen“ mit dem Dialog „Änderungen verwerfen?“ (V13).

### 1.2 Alle Pfade

| Nr. | Pfad | Art | Parameter | Zurück führt zu |
|---|---|---|---|---|
| V1 | `/checkout/:listId` | V | `source=shopping_mode\|menu\|avo` (nur Analytics) | Liste, Einkaufsmodus bleibt |
| V2 | `/stores/pick` | V, Folgeschritt | `mode=trip`, `listId=`, `tripId=` (nur aus V5), `selected=<chainId>`; Rückgabe per `pop(chainId)` | V1 bzw. V5 |
| V4 | `/history` | W | `list=<listId>` setzt den Filter | Listen-Übersicht bzw. Home |
| V5 | `/history/:tripId` | K | keine | V4 |
| V6 | `/history/:tripId/amount` | V | keine | V5 bzw. V4 |
| V7 | `/history/:tripId/split` | V | `amount=<Cent>` (vorbefüllt), `from=checkout` | V5, nach V1 die Liste |
| V8 | `/splits` | B | `done=1` klappt „Erledigt“ auf | Listen-Übersicht bzw. Home |

`openCheckoutFlow(context, listId)` (Vertrag `b_slots.dart`, `Future<bool>`) pusht künftig `/checkout/:listId` über
`context.push<bool>` statt heute `Navigator.push(MaterialPageRoute)`. Das `Future` endet erst, wenn die ganze Kette
vorbei ist (V1, V3, optional V7), und liefert `true`, wenn ein Einkauf gespeichert wurde. A beendet danach den
Einkaufsmodus (Morph zurück) und zeigt nur noch offene Artikel.

Ein unbekannter `tripId` (gelöscht, kein Mitglied mehr) öffnet nicht die Fehlerseite, sondern den Verlauf mit dem
Hinweis „Dieser Einkauf wurde gelöscht.“ (`AvoToast` ohne Aktion). Unbekannte Unterpfade (`/history/x/y`) zeigen die
Fehlerseite von A.

### 1.3 Einstiege

| Einstieg | Ziel |
|---|---|
| Einkaufsmodus, Knopf „Einkauf abschließen“ (A, D2 `X-Einkaufsmodus`) | V1 |
| Listenmenü „Einkauf abschließen“ (A, sichtbar ab einem abgehakten Artikel) | V1 |
| Avo `complete_list` | speichert selbst; Ergebniszeile „Ansehen“ öffnet V5 |
| Listen-Übersicht, Gruppe „Verlauf“: Zeile „Einkäufe“ (A baut die Zeile, Anfrage A-V12) | V4 |
| Listen-Übersicht, Zeile „Offene Beträge“ (nur Modul Kosten teilen) | V8 |
| Home „Dein November“, „Ausgaben im Vergleich“, „Letzte Einkäufe · Alle anzeigen“ | V4 |
| Home „Letzte Einkäufe“, eine Zeile | V5 (wechselt in den Listen-Tab, Anfrage A-V14) |
| Hinweis „Einkauf teilen“ | V7 |
| Hinweis „Offene Beträge“ (mehrere) | V8 |
| Mitteilung `shopping_complete`, `expense_split` | V5 (Anfrage A-V11, `navigation_service.dart` gehört A) |
| `shoply://history`, `shoply://history/<id>`, `shoply://splits` | V4, V5, V8 |
| Avo „Ansehen“ (Verlauf, Aufteilung, „bezahlt“) | V4 bzw. V5 |

Modul-Wächter: `/splits` und `/history/:tripId/split` prüfen `moduleEnabledProvider(AppModule.costSplit)`. Ist das
Modul aus, kommt zuerst der Dialog „Kosten teilen ist ausgeschaltet“ (V13). „Einschalten“ öffnet danach das Ziel,
„Nicht jetzt“ bleibt, wo man war (bei Kaltstart: Wurzel des Listen-Tabs). Der Verlauf selbst ist Kern und hat keinen
Wächter. Doppelte Zustellung unter 2 s wird verworfen, ein Kaltstart-Link genau einmal ausgeführt (01 §8.1).

Höchstens drei Ebenen im Tab: Listen-Übersicht > Verlauf > Einkauf-Detail; darüber höchstens ein V-Ablauf mit zwei
Schritten (V1 > V2, V5 > V2).

---

## 2. Bausteine und Maße aus D2

### 2.1 Grundmaße

| Element | D2-Wert |
|---|---|
| Hintergrund | `groupedBg` #F2F2F7 (`context.colors.background`) |
| Seitenrand | 16 pt (`AvoSpacing.screen`) |
| Großer Titel | 34/41 Bold, +0,2; Inhalt beginnt 106 pt von oben unter der Toolbar |
| Inline-Titel | 17/22 Semibold, Mitte der `GlassToolbar`, eine Zeile mit Ellipse |
| Toolbar | Oberkante 54 pt; `GlassIconButton` 44 (Kreis, Radius 22, Symbol 22); `GlassButtonGroup` (44 hoch, Knöpfe 40 × 44); getönter Primär-Kreis 44 (`GlassIconButton(tinted: true)`) |
| Scroll-Kante | `ScrollEdgeFade` 110 pt von #F2F2F7 (30 %) zu transparent, nur wo Inhalt unter der Toolbar durchläuft |
| Gruppe | `InsetSection`: weiß, Radius 26, 16 pt vom Rand, Trenner 0,5 pt #E5E5EA ab der Textkante, 24 pt zwischen Gruppen |
| Gruppenkopf | `SectionCaps`: GROSS 13/18 Semibold #6C6C70, +0,3, Text bei 32 pt vom Rand, Zahl rechts 13/18 tabellarisch regular |
| Karte | weiß, Radius 20, Innenabstand 12 × 14 (Spar-Karte wie `X-Einkaufsmodus`) bzw. Radius 26, Innenabstand 16 (Monatskarte wie `D2-FuerDich` §4) |
| Zeile mit Kachel | mindestens 64 hoch, Innenrand 10 × 16, Abstand 12; Kachel 40 × 40 Radius 10; Titel 17/22 Semibold; Unterzeile 15/20 #6C6C70; Betrag rechts 17/22 Semibold tabellarisch; Chevron 8 × 14 #C7C7CC; Trenner ab 68 pt (`D2-FuerDich` `.row`) |
| Artikelzeile | mindestens 60 hoch, Abstand 12; Bild 44 Radius 10; Name 17/22; Menge 15/20 #6C6C70; Angebots-Pille rechts 11/13 600 #1F7A3A auf #E7F3EA, Innenrand 3 × 8 |
| Zahl groß | `numberXL` 34/41 Bold tabellarisch, wächst bis höchstens 51 pt |
| Kennzahl | 20/25 Bold tabellarisch über 13/18 #6C6C70, Symbol 22 darüber, Spalten durch 0,5 pt rgba(60,60,67,.18) getrennt (`D2-FuerDich` §3) |
| Balken | Spalte 48 breit, 128 hoch; Wert 12/16 #3A3A3C 4 pt über dem Balken; Balken Radius 10, #ECECF0; Monat 13/18 #6C6C70 6 pt darunter; gewählter Monat #34A853, Wert #1F7A3A 600, Monat #1C1C1E 600 (`D2-FuerDich` §4) |
| Filter-Chip | `AppFilterChip`: sichtbar 34 hoch in 44-pt-Ziel, 15/20 500, Innenrand 14; gewählt #1C1C1E mit Weiß, sonst `fill` |
| Segmented Control | `AppSegmentedControl`: 44 hoch, Spur `fill`, Innenabstand 3, Daumen weiß 38 Radius 19, 15/20 600 |
| Schalter | `ToggleRow` (51 × 31, System) |
| Getönte Kapsel unten | `AppButton.primary(size: large)`: 54 hoch, Radius 27, 17/22 600, Symbol 18 `check` (`X-Einkaufsmodus`), 16 pt vom Rand, 28 pt über der unteren Kante bzw. über der Tastatur |
| Getönte Kapsel im Inhalt | `AppButton.primary(size: regular)`: 44 hoch, 15/20 600, Symbol 18 |
| Text-Knopf | `AppButton.plain`: 17/22 #1F7A3A, mindestens 44 × 44; destruktiv #D70015 |
| Avatar | 20 (Kopf V5), 28 (Zeilen in V7), 40 (Zeilen in V8); Fläche `tintSoft`, Initiale 600 in `tint` (D2 Listenkarte „mit Lena“) |
| Markt | `StoreBadge` 40 × 40 Radius 10 bzw. `StoreLabel` (8-pt-Punkt plus Name in der Schrift der Zeile), Abschnitt 2.3 |

### 2.2 Farben im Bereich (D2, als Tokens von A)

| Rolle | D2-Wert | Token | Einsatz | Hinweis |
|---|---|---|---|---|
| Text | #1C1C1E | `label` | alles Lesbare, auch Schulden | |
| Sekundär | #6C6C70 | `secondaryLabel` | Unterzeilen, Fußnoten, Werte | nicht auf `fill` über #F2F2F7 (4,09:1), siehe 3.7 |
| Akzent | #1F7A3A | `tint` | Text-Knöpfe, Kapseln, Ersparnis-Zahl, Auswahl-Kreis | |
| Akzent hell | #E7F3EA | `tintSoft` | Angebots-Pille, Avatar-Fläche | |
| Balken | #ECECF0 | fehlt (Anfrage A-V4) | Monatsbalken | trägt keine Information allein, Wert steht als Text daneben |
| Balken gewählt | #34A853 | fehlt (Anfrage A-V4) | gewählter Monat | 3,06:1 auf Weiß, reicht für Grafik |
| Destruktiv | #D70015 | `destructive` | „Löschen“, „Nicht gespeichert“ | nie #FF3B30 für Text |
| Monatskarte Home | Verlauf #EEF7EF → #FFFFFF 70 %, 135° | fehlt (Anfrage A-V4) | nur V9 | |
| Marktfarben | aus dem Ketten-Verzeichnis (Daten von B) | keine Tokens | `StoreBadge`, `StoreLabel` | Abschnitt 2.3 |

Geld bekommt keine eigene Farbe. Schulden stehen in `label`, nie in Rot, nie mit Pfeilen. Grün trägt nur die
Ersparnis und Bedienelemente. Dunkel und erhöhter Kontrast kommen aus dem Token-Set von A (D2 ist nur hell).

### 2.3 B-eigene Bausteine (Ordner `lib/presentation/screens/history/widgets/`)

Aus A-Tokens gebaut, ohne eigene Farben, Größen oder Dauern:

- `StoreBadge` (40 × 40, Radius 10): Fläche = Markenfarbe der Kette mit 12 % Deckkraft auf `surface`, darin der erste
  Buchstabe des Kurznamens 17/22 Bold in der Markenfarbe, so weit abgedunkelt (hell) bzw. aufgehellt (dunkel), bis er
  4,5:1 gegen die Fläche erreicht. Ohne Kette: Fläche `fill`, Symbol `cart` 20 in `secondaryLabel`. Eigener Markt ohne
  Kette: Fläche `fill`, Buchstabe in `label`. Dekorativ für VoiceOver; der Name steht daneben. Owner-Frage 1 entscheidet,
  ob es bei diesem D2-Stil bleibt oder ob der Punkt aus dem Konzept kommt.
- `StoreLabel`: 8-pt-Punkt in Markenfarbe plus Kettenname in der Schrift der Zeile, ohne Kapsel. Helle Marken (Edeka
  #FFD400 1,43:1, Netto #FFE500 1,28:1) bekommen eine Kontur 0,5 pt in `uncheckedRing` #8A8A8E. VoiceOver „Markt
  Lidl“ / „Store Lidl“. Nicht antippbar.
- `TripRow` (Einkauf wie eine Wallet-Buchung), Varianten `full` (Verlauf) und `compact` (Home): Abschnitt V4.
- `MonthReview` (Monatskarte im Verlauf) mit `SpendingBars` (Konfiguration des A-Diagramms, keine eigene Zeichnung)
  und `StatStrip` (drei Kennzahlen wie `D2-FuerDich` §3).
- `SavingsLine`: weiße Karte Radius 20, Innenabstand 12 × 14, Symbol `tag` 20 in `tint`, Satz 15/20 in `label`
  (Vorbild: die Spar-Karte in `X-Einkaufsmodus`). Rendert `SizedBox.shrink()`, wenn `offersAvailableProvider` false
  ist, keine echte Region vorliegt, der Einzel-Schalter „Ersparnis im Verlauf und nach dem Einkauf“ aus ist oder die
  gerundete Ersparnis `null` ist.
- `StoreChoiceChips` (V1), `HistoryItemRow` (V5), `SplitParticipantRow` (V5, V7), `BalanceRow` (V8).

---

## 3. Regeln für alle Screens

### 3.1 Lokal zuerst

- Der Verlauf liegt lokal im Konto-Speicher (`LocalStore` von A, Bereich `history`): die letzten 3 Monate, mindestens
  50 Einkäufe, mit Aufteilungen und Preis-Schnappschüssen. V4, V5, V8 und die Home-Abschnitte zeigen im ersten Frame
  diesen Stand. Der Abgleich mit Supabase läuft danach unsichtbar; Zahlen rollen an Ort und Stelle, neue Zeilen wachsen
  ein. Kein Spinner, kein Skelett beim zweiten Öffnen.
- Skelett (`SkeletonSection`, ruhige Tonflächen in `fill`, ohne Animation, VoiceOver ein Element „Wird geladen“) nur
  beim allerersten Öffnen ohne lokalen Stand, etwa nach einer Mitteilung im Kaltstart. Nach 10 s ohne Antwort kommt der
  Fehler-Zustand des Screens.
- Home liest aus einem synchronen Schnappschuss (`homeHistorySnapshotProvider`), damit `homeMonthHasContentProvider`,
  `homeSpendingHasContentProvider` und `homeRecentTripsHasContentProvider` beim ersten Frame feststehen und nichts
  nachträglich einspringt.
- Schreiben ist optimistisch und geht durch die dauerhafte Warteschlange (`WriteQueue` von A): Abschluss, Betrag,
  Markt, Aufteilung, „bezahlt“, Löschen, „Alle wieder auf die Liste“. Ein Netzfehler lässt nie etwas still verschwinden.
- Mitteilungen an Mitglieder sind eine eigene Aufgabe in der Warteschlange mit „frühestens nach Ablauf des
  Rückgängig-Hinweises“. Widerrufen streicht sie. Wird die App im Fenster beendet, gehen sie beim nächsten Start raus
  (K12-14).

### 3.2 Zustände, die überall gleich aussehen

| Zustand | Darstellung | Schlüssel | Deutsch | English |
|---|---|---|---|---|
| Offline (V5, V6, V7, V8) | `StatusRow(kind: offline)` unter dem Titel, erscheint nach 1 s | `common_offline` | Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist. | Offline. Your changes will be saved when you're back online. |
| Offline (V4) | wie oben, eigener Satz | `hist_status_offline` | Offline. Neue Einkäufe erscheinen, sobald du wieder online bist. | You're offline. New trips will show up once you're back online. |
| Wartet | `StatusRow(kind: pending)`, ab 3 s | `common_changes_waiting` | Offline. {count} Änderungen warten. | Offline. {count} changes waiting. |
| Verbindung schlecht | `StatusRow`, Bereich `system` (Schlüssel neu, gleicher Text wie in `kalorien.md`) | `sys_status_poor` | Verbindung schlecht. Es wird der letzte Stand gezeigt. | Poor connection. Showing the last saved data. |
| Zeile wird gesendet | Symbol `arrow.triangle.2.circlepath` 10 pt hinter dem Betrag | `hist_row_sending_a11y` | wird gespeichert | saving |
| Zeile nicht gespeichert | `exclamationmark.circle` 15 in #D70015 statt Betrag, Text darunter, Tippen wiederholt, Fehler-Haptik beim Scheitern | `common_not_saved` | Nicht gespeichert | Not saved |
| | VoiceOver-Zusatz | `hist_row_not_saved_a11y` | nicht gespeichert. Doppeltippen zum Wiederholen. | not saved. Double-tap to try again. |
| Modul Kosten teilen aus | Abschnitte, Unterzeilen und Hinweise zum Teilen verschwinden ohne Lücke; Routen V7, V8 zeigen den Dialog aus V13; gespeicherte Aufteilungen bleiben | | | |
| Modul Angebote aus oder Kill-Switch | jede Ersparnis-Zeile, -Zahl und Angebots-Pille verschwindet ohne Lücke; Markt-Angaben bleiben (Kern) | | | |
| Ohne echte Region | wie Modul Angebote aus (K12-01) | | | |
| Pro gesperrt | heute nichts gesperrt. Falls der Owner „Kosten teilen“ oder „Statistiken“ zu Pro macht (F12-5, Owner-Frage 6): `ProBadge` an der Aktion, echte Vorschau, Paywall `/pro?feature=cost_split` bzw. `stats` über `ProGate.run` erst beim Auslösen | | | |
| Berechtigung Standort | nur in V1, Abschnitt V1 | | | |

### 3.3 Geld, Zahlen und Wortlaut

- Beträge über `NumberFormat.currency(locale:)`: „42,80 €“ mit geschütztem Leerzeichen bzw. „€42.80“. Nie
  „42.80 €“, nie „€ 42,80“, nie fest „{amount} €“ im Text: `{amount}` ist immer schon formatiert.
- Eingabe nimmt „42,8“, „42,80“, „42.80“, „1.234,56“ und „1234,5“ (`parseLocaleDouble`) und zeigt beim Verlassen
  „42,80 €“ (behebt Bug 14). Ungültig heißt nie still 0, sondern ein Satz unter dem Feld (V1, V6, V7).
- Der Gesamtbetrag eines Einkaufs entsteht nur durch Eingabe (V1, V6, V7, Avo), nie aus Angebotspreisen (Regel 14,
  K12-07). Ohne Betrag steht nichts an seiner Stelle, keine „0,00 €“.
- Ersparnis nur über die gemeinsame Funktion in `offer_savings.dart` (`summarizeListOffers`, `roundedSavingsCents`):
  Händler-Vergleichspreis, Grundpreis mal Menge, nur der Markt des Einkaufs, nur mit echter Region, unter 0,50 €
  entfällt sie, sonst auf 10 Cent gerundet mit „ca.“. Summen (Monat) werden aus den ungerundeten Werten gebildet und erst
  am Ende gerundet. Steht die Ersparnis als eigener Satz, heißt sie „Ca. 3,20 € durch Angebote gespart, laut Händler“;
  als Zusatz in einer Zeile „ca. 3,20 € gespart“, und VoiceOver liest den ganzen Satz.
- Kein „Spare“, kein Prozent bei Angeboten, kein Minuszeichen vor einer Ersparnis (D2 „−3,20 €“ wird „ca. 3,20 €
  gespart“, Abschnitt 5).
- Aufteilungen gehen auf den Cent auf. Gleich geteilt: ganze Cent, der Restcent geht an die erste Person in „Wer
  teilt?“ (die Reihenfolge wird mit der Aufteilung gespeichert; wer sie anlegt, steht oben). 10,00 € durch 3 = 3,34 €
  + 3,33 € + 3,33 €.
- Summen in Gruppenköpfen werden aus den sichtbaren Zeilen berechnet und bei jedem Wechsel neu.
- Datum: „Heute, 18:40“, „Gestern, 19:05“, sonst „Mi., 4. Nov.“ / „Wed, Nov 4“; relativ nur bis 7 Tage; Jahr nur,
  wenn es nicht das laufende ist („Mo., 2. Nov. 2025“). Uhrzeit nur bei heute, gestern und im Kopf von V5.
- Kein Maskottchen und kein Avo-Glanz bei Beträgen, Schulden, Ersparnis-Details und Fehlern (Regel 12). Einzige
  Ausnahme ist der Erfolgsmoment V3, dort steht die Ersparnis nur als Unterzeile.
- Markenname der App nur über `AppBrand` (`{app}` = Avo, `{pro}` = Avo Pro).

### 3.4 Bewegung (Federn aus `AvoMotion` von A)

| Was | Feder | Reduce Motion |
|---|---|---|
| Beträge, Summen, Anteile, Monatswerte | `RollingNumber` auf `AvoMotion.digits` | ganze Zahl blendet über |
| Neue Zeile, gelöschte Zeile, Abschnitt erscheint oder verschwindet | wächst bzw. schrumpft auf `AvoMotion.standard` | Überblendung (`AvoMotion.fadeReduced`) |
| Zeile wandert („Bezahlt“ in V8 nach „Erledigt“) | `AvoMotion.move` vom aktuellen Platz aus | Überblendung an beiden Orten |
| Balken des gewählten Monats | Farbe und Gewicht wechseln auf `AvoMotion.quick` | sofort |
| Ziehen über das Diagramm | Auswahl folgt dem Finger 1:1 von Balken zu Balken | gleich (kein Weg, nur Zustandswechsel) |
| Wischaktion auf einer Zeile | folgt dem Finger 1:1, rastet mit Wurfprojektion (`AvoMotion.fling`) ein oder federt zurück | Aktionen nur über VoiceOver bzw. Kontextmenü, Wischen bleibt |
| Chip „REWE (hier)“ kommt dazu | blendet am Ende der Reihe ein, nichts davor verschiebt sich | Überblendung |
| „Erledigt“ auf- und zuklappen (V8) | `AvoMotion.standard`, Chevron dreht mit | Überblendung |
| Menüs aus Knopf oder Zeile | Menü-Übergang von A (`AvoMotion.menu`), wächst aus dem Auslöser | Überblendung |
| Erfolgsmoment | `showSuccessMoment` von A (`AvoMotion.celebrate`, aus 0,9) | nur Einblenden |

Keine Endlos-Animation, kein Schimmern, kein Konfetti. Jede Bewegung startet vom aktuellen Wert und lässt sich
unterbrechen.

### 3.5 Haptik (über `AvoHaptics` von A, nie `HapticFeedback` im Screen)

| Ereignis | Haptik |
|---|---|
| Einkauf gespeichert (Erfolgsmoment, im selben Frame) | Erfolg (macht `showSuccessMoment`) |
| Ziehen über das Diagramm, pro neuem Balken; Wischen des Segment-Daumens über ein Segment | Auswahl |
| Wischaktion überschreitet die Schwelle | leichter Impuls |
| Speichern endgültig gescheitert (Abschluss, Aufteilung, „bezahlt“, Löschen) | Fehler |
| „Bezahlt“, Aufteilung gespeichert, Markt gewählt, Chips, Schalter, Betrag, „Alle wieder auf die Liste“, Öffnen von Screens und Menüs | keine (Geld ist kein Erfolgsmoment, E-14) |

### 3.6 Rückgängig-Hinweis (`AvoToast` von A)

- Glas-Kapsel über der Tab-Leiste (bzw. über der Tastatur), ein Satz plus „Widerrufen“ (`common_undo`).
- Sichtbar 4 s, mit VoiceOver 10 s, dazu eine höfliche Ansage; die Zeit läuft nicht, solange der VoiceOver-Fokus auf
  dem Hinweis liegt (Anfrage A-V10, falls `AvoToast` das noch nicht kann). Wischen nach unten schließt ihn.
- Solange er steht, ist „Widerrufen“ auch als eigene Aktion am geänderten Element erreichbar (Zeile, Kopf von V5).
- Ein neuer Hinweis ersetzt den alten. In der Kette V1 → V3 → V7 erscheint genau einer: „Einkauf gespeichert ·
  Widerrufen“, und Widerrufen nimmt den Einkauf samt der eben gespeicherten Aufteilung zurück.
- Rückgängig statt Rückfrage für „bezahlt“, „wieder offen“, Aufteilung, Betrag, Markt, Abschluss, „Alle wieder auf die
  Liste“. Rückgefragt wird nur beim Löschen eines Einkaufs (endgültig, betrifft alle Mitglieder).

### 3.7 Kontrast (WCAG 2.1 AA, berechnet aus den D2-Werten)

| Element | Vorne | Hinten | Wert | Nötig | Ergebnis und Lösung |
|---|---|---|---|---|---|
| Destruktiver Text („Löschen“, „Nicht gespeichert“) | #FF3B30 | #FFFFFF / #F2F2F7 | 3,55 / 3,18:1 | 4,5:1 | nicht für Text. Immer `destructive` #D70015 (5,38 / 4,83:1) |
| Weiße Schrift auf getönter Kapsel 88 % über Weiß („Einkauf speichern“, „Alle wieder auf die Liste“) | #FFFFFF | #3A8A52 | 4,25:1 | 4,5:1 (17 pt Semibold ist kein großer Text) | Kapsel über hellem Inhalt mit 96 % Deckkraft (≈ 4,99:1) oder voll #1F7A3A (5,38:1); gleiche Anfrage wie A-T2 in `kalorien.md`, hier A-V5 |
| Monatsbalken | #ECECF0 | #FFFFFF | 1,18:1 | 3:1 (Grafik) | Balken tragen die Information nicht allein: Jeder Wert steht als Text darüber, und VoiceOver liest die Werte. Bei erhöhtem Kontrast Balken in #8A8A8E (3,44:1). Ohne Wertebeschriftung (siehe 3.9) muss der Balken #8A8A8E sein |
| Gewählter Balken | #34A853 | #FFFFFF | 3,06:1 | 3:1 | knapp gut; Wert in #1F7A3A 600 trägt die Zahl |
| Sekundärtext auf `fill` über #F2F2F7 (Segment-Labels, Chip-Text außerhalb weißer Gruppen) | #6C6C70 | #E3E3E9 | 4,09:1 | 4,5:1 | Bedienelemente immer in #1C1C1E (13,3:1); Chips in V1 stehen in einer weißen Gruppe (#6C6C70 auf #EFEFF0 = 4,55:1, trotzdem Text #1C1C1E) |
| Sekundärtext auf Monatskarte Home | #6C6C70 | #EEF7EF | 4,78:1 | 4,5:1 | gut |
| Ersparnis in Grün | #1F7A3A | #FFFFFF / #EEF7EF | 5,38 / 4,92:1 | 4,5:1 | gut |
| Angebots-Pille | #1F7A3A | #E7F3EA | 4,72:1 | 4,5:1 | gut (11/13 600 ist klein, deshalb wichtig) |
| Abhak- und Auswahl-Ring leer | #8A8A8E | #FFFFFF | 3,44:1 | 3:1 | gut (Owner, 07.11.); D2 #C7C7CC (1,68:1) wird nicht verwendet |
| Chevron in Zeilen | #C7C7CC | #FFFFFF | 1,68:1 | keine | dekorativ, die ganze Zeile ist der Knopf und hat ein Label |
| `StoreBadge`-Buchstabe | z. B. #1A56DB / #B42318 / #8A5A00 | Pastellfläche | 5,39 / 5,76 / 5,49:1 | 4,5:1 | berechnet, nie unter 4,5:1 (2.3) |
| Heller Markenpunkt | #FFD400 / #FFE500 | #FFFFFF | 1,43 / 1,28:1 | keine | dekorativ neben dem Namen; Kontur #8A8A8E, damit er sichtbar bleibt |
| Akzent-Text in Text-Knöpfen | #1F7A3A | #FFFFFF / #F2F2F7 | 5,38 / 4,82:1 | 4,5:1 | gut |
| Sekundär | #6C6C70 | #FFFFFF / #F2F2F7 | 5,23 / 4,69:1 | 4,5:1 | gut |

Erhöhter Kontrast: Glas bekommt eine 1-pt-Kontur, Sekundärtext #3A3A3C, Balken #8A8A8E, Trenner kräftiger (Token-Set
von A). Dunkle Werte prüft A beim Token-Set; `StoreBadge` rechnet seine Tinte in jedem Modus selbst nach.

### 3.8 Trefferflächen

Alles Antippbare hat mindestens 44 × 44 pt. Die D2-Chips (34 sichtbar) sitzen in 44-pt-Zielen (`AppFilterChip`),
Segmented Control und Stepper sind 44 hoch. Text-Aktionen in Zeilen („Bezahlt“, „Zurückgezahlt“, „Ändern“, „Alle“)
haben 44 pt Höhe und mindestens 44 pt Breite (heute 15 bis 20 pt hohe Pillen, Bug in `pending_splits_banner.dart`).
Der Auswahl-Kreis in V7 ist 22 pt in einem 44-pt-Ziel. Jeder Balken im Diagramm ist mindestens 44 pt hoch antippbar
(die Spalte inklusive Beschriftung, nicht nur der Balken). Zwischen benachbarten Zielen mindestens 8 pt.

### 3.9 Große Schrift und 320 pt

- Kein abgeschnittener Text bei 320, 375, 390, 402 und 440 pt Breite und L, xxxL, AX3, AX5 (`layoutMatrix` von A,
  B-Tests in `test/layout/screens/b/history_*_test.dart`), mit und ohne fetten Text, hell und dunkel. Ellipse nur im
  Inline-Titel der Toolbar.
- `numberXL` höchstens 51 pt.
- Ab xxL: Segmente, die nicht passen, werden ein Pull-down mit `chevron.up.chevron.down` (macht `AppSegmentedControl`
  selbst). Zwei Knöpfe nebeneinander stehen untereinander.
- Ab AX1: Gruppen randlos (macht `InsetSection`), Zeilen stapeln (Betrag unter den Text, linksbündig), `StoreBadge`,
  Avatare in Zeilen und Artikelbilder entfallen, die Avo-Figur in leeren Zuständen entfällt, Kennzahlen-Spalten werden
  Zeilen (Bezeichnung links, Wert rechts, darunter umbrechend), Text-Aktionen rutschen unter den Betrag.
- Diagramm: Wertebeschriftung über den Balken nur, solange jede Beschriftung in ihre Spalte passt (gemessen, alle oder
  keine); sonst entfällt sie und die Balken werden #8A8A8E. Monatskürzel bis xxxL; ab AX1 entfallen die Achsen, das
  Diagramm bleibt als Grafik (VoiceOver ausgeblendet) und darunter stehen die Monate als Zeilen („Juni · 240,10 €“), die
  zugleich die Auswahl sind.
- 320 pt bei L: Spaltenbreite = (Innenbreite − 5 × 8) / 6, also 36 pt bei 256 pt Innenbreite, mindestens 24 pt;
  Monatskürzel „Jun“, „Jul“. Kennzahlen-Leiste bleibt dreispaltig bis xL, ab xxL Zeilen.

### 3.10 VoiceOver-Grundregeln

- Jede Zeile ist ein Element mit einem vollen Satz; Wisch- und Kontextmenü-Aktionen sind eigene Aktionen
  (`customSemanticsActions`) mit denselben Namen wie sichtbar.
- Großbuchstaben-Köpfe werden in normaler Schreibung vorgelesen (`SectionCaps` macht das) und als Überschrift
  gekennzeichnet, damit der Rotor „Überschriften“ von Monat zu Monat springt.
- Beträge werden als „42,80 Euro“ / „42 euros 80“ vorgelesen (Zahl plus Währung, nicht „Komma“), „ca.“ als „circa“ /
  „about“.
- Dekorativ und ausgeblendet: `StoreBadge`, Markenpunkt (der Name trägt die Information), Symbole vor Text, Chevrons,
  Balken, wenn die Werte darüber stehen, Avo-Figur.
- Live-Änderungen (Einkauf gespeichert, „bezahlt“, Summe neu) sagt `SemanticsService.announce` einmal nach dem ganzen
  Satz an. `StatusRow` kündigt sich selbst an.
- Fokus-Reihenfolge folgt der Leserichtung: Toolbar links, Titel, Toolbar rechts, Inhalt von oben nach unten, untere
  Kapsel zuletzt. Nach dem Öffnen liegt der Fokus auf dem Titel, nach dem Schließen eines V-Screens auf dem Element, das
  ihn geöffnet hat.

### 3.11 Reduce Motion, Transparenz reduzieren, fetter Text

- Reduce Motion: siehe 3.4.
- Transparenz reduzieren (Kanal `shoply/accessibility`, B registriert ihn, A nutzt ihn in `GlassSurface`): Glas-Knöpfe,
  Toast und Tab-Leiste werden feste Flächen mit klarer Kontur, die getönte Kapsel wird voll #1F7A3A, die Scroll-Kante eine
  feste #F2F2F7-Fläche, die Monatskarte auf Home verliert den Verlauf und wird weiß.
- Fetter Text (`MediaQuery.boldTextOf`): Prüfmatrix läuft mit und ohne; Betragsspalten bekommen dadurch mehr Breite,
  nichts darf abschneiden.

### 3.12 Avo-Figur

| Ort | Pose | Größe | Ab |
|---|---|---|---|
| V3 Erfolgsmoment | `AvoPose.celebrating` | 120 pt (A zeigt ab AX1 72 pt) | ab AX3 ohne Figur (Anfrage A-V7) |
| V4 Verlauf leer (kein Geld sichtbar) | `AvoPose.waving` | 96 pt (`EmptyState`) | ab AX1 ohne Figur (macht `EmptyState`) |
| alle anderen Screens, Zustände, Home-Abschnitte und Hinweise dieses Bereichs | keine | | |

Begründung: Geld, Schulden, Ersparnis-Details, Fehler, Offline und Löschen bekommen nie eine Figur (Regel 12). Die
Home-Abschnitte V9 bis V11 tragen keine Figur, weil Home seine Avo-Karte schon oben hat; A achtet auf eine Figur pro
Bildschirmhöhe.

### 3.13 Glas pro Screen

Höchstens drei Glas-Flächen gleichzeitig. V1: `xmark` und untere Kapsel. V4: Zurück, Filter, Tab-Leiste. V5: Zurück,
„Mehr“, Tab-Leiste. V6 und V7: `xmark` und getönter Primär-Kreis. V8: Zurück, Tab-Leiste. Der Rückgängig-Hinweis ist auf
V4 und V5 die vierte Fläche für 4 s; ob er mitzählt, entscheidet A (E-18, Anfrage A-V15). Getönte Kapsel bzw. getönter
Kreis: genau einer pro Screen.

### 3.14 Prüfregeln Kill-Switch und Modul

Mit `offers_enabled = false`, mit Modul Angebote aus und ohne echte Region enthält kein Screenshot dieses Bereichs die
Wörter „Angebot“, „gespart“ oder „laut Händler“ und keine Angebots-Pille (#E7F3EA mit grüner Schrift). Mit Modul
Kosten teilen aus enthält kein Screenshot „schuldet“, „Anteil“, „Kosten teilen“ oder „bezahlt“ außer dem Dialog V13.
Beides läuft als eigener Durchgang in `test/layout/screens/b/` (E-15).

---

## 4. Screens

Jeder Screen: Zweck, Route, Aufbau von oben nach unten, Zustände, Texte, Interaktion, Barrierefreiheit, Daten, Avo.
Was in Abschnitt 3 steht, gilt zusätzlich und wird nicht wiederholt.

### V1 Einkauf abschließen `/checkout/:listId`

**Zweck.** Wo war ich, und was kommt in den Verlauf? Ein Tipp speichert; Markt ist vorausgewählt, Betrag und Kosten
teilen sind freiwillig.

**Route.** V-Route (`historyRootRoutes`, absolut), Vollbild über der Tab-Leiste, geöffnet über `openCheckoutFlow`.
Kein Bestätigungs-Alert davor (heute „Einkauf abschließen?“ in `shopping_trip_completion.dart:54-79`, A-Datei, entfällt
mit Anfrage A-V9). Ersetzt die Kombination aus Alert, `checkout_store_sheet.dart` (Sheet, wartete bis 30 s unsichtbar auf
GPS) und Snackbar „Kosten teilen“.

**Aufbau.**

1. Toolbar (54 pt): links `GlassIconButton` `xmark` „Schließen“; Mitte Inline-Titel „Einkauf abschließen“; rechts
   nichts. Darunter `ScrollEdgeFade`.
2. Zusammenfassung, `InsetSection` ohne Kopf, eine Zeile mit Innenrand 16:
   - „9 Artikel im Wagen“ 17/22 Semibold (Zahl als `RollingNumber`, falls Lena während des Öffnens noch abhakt).
   - darunter 15/20 `label`: „2 bleiben auf Wocheneinkauf: Brokkoli, Gouda in Scheiben“. Höchstens drei Namen, dann
     „und 4 weitere“. Ist alles abgehakt, entfällt die Zeile.
3. `SectionCaps` „WO WARST DU?“, darunter `InsetSection` ohne Trenner mit `StoreChoiceChips` (Innenrand 12 × 16, `Wrap`,
   Abstand 8 waagerecht und senkrecht):
   - Chips (`AppFilterChip` mit führendem 8-pt-Markenpunkt, Anfrage A-V1), Einfachauswahl, erneutes Tippen hebt die
     Auswahl auf. Reihenfolge: vorausgewählter Markt, Lieblingsmärkte, Märkte aus dem Verlauf dieser Liste (höchstens 4
     Chips bis hier), zuletzt „Anderer Markt …“ ohne Punkt, mit `chevron.right` 11 pt. Gewählt: #1C1C1E mit weißer
     Schrift, der Markenpunkt bekommt einen 1-pt-Ring in Weiß, damit dunkle Marken auf Dunkel sichtbar bleiben.
   - Kommt während des Öffnens ein eindeutiger Standort-Treffer, hängt sich am Ende vor „Anderer Markt …“ ein Chip
     „● REWE (hier)“ an (blendet ein). Er wird nie von selbst gewählt, wenn schon etwas gewählt ist.
   - Fußnote 13/18 #6C6C70 unter der Gruppe: Herkunft der Vorauswahl.
4. `SectionCaps` „BETRAG“, `InsetSection` mit einer Zeile: Titel „Betrag“ 17/22 links, rechts `AmountField` kompakt
   (Anfrage A-V3): Platzhalter „optional“ in `placeholder`, 17/22 tabellarisch, rechtsbündig, Ziffernblock mit Komma.
   Fußnote „Für deinen Monatsrückblick.“ bzw. mit Kosten teilen „Für deinen Monatsrückblick und zum Teilen.“ Platz für
   einen späteren Knopf „Bon scannen“ (F12-3) links neben dem Feld bleibt frei, wird aber nicht gezeichnet.
5. Nur mit Modul Kosten teilen und einer Liste mit mindestens 2 Mitgliedern: `InsetSection` mit `ToggleRow`, Symbol
   `eurosign.circle` 20 #6C6C70 (Anfrage A-V16), Titel „Kosten teilen“, Unterzeile „Mit Lena. Danach legst du die
   Anteile fest.“ Standard aus; an, wenn beim letzten Einkauf dieser Liste geteilt wurde.
6. `SavingsLine` (Abschnitt 2.3): „Ca. 3,20 € durch Angebote gespart, laut Händler“. Gerechnet nur über die abgehakten
   Artikel mit einem Angebot des gewählten Markts. Wechselt der Chip auf einen anderen Markt oder auf keinen, schrumpft
   die Karte weg (`AvoMotion.standard`), weil die Angebote dort nicht galten.
7. Unterer Rand: so viel Abstand, dass die letzte Gruppe 16 pt über der Kapsel endet.
8. Schwebend unten: `AppButton.primary(size: large)` „Einkauf speichern“ mit `check` 18, 16 pt vom Rand, 28 pt über
   der unteren Kante; bei offener Tastatur 8 pt über der Tastatur. Er steht genau dort, wo im Einkaufsmodus „Einkauf
   abschließen“ stand: Der Daumen bleibt am selben Ort.

**Vorauswahl des Markts.** In dieser Reihenfolge, beim ersten Frame aus lokalen Daten festgelegt und danach nie mehr
von selbst geändert: Markt der Liste (`storeForListProvider`, bestätigt) → gelernter Markt (zweimal in Folge derselbe
bei dieser Liste, `storeGuessForListProvider` mit Quelle `learned`) → nichts. Der Standort fügt höchstens den Chip
„(hier)“ an. Gibt es keine Vorauswahl und ist der Standort eindeutig (innerhalb 80 m, nächste andere Kette mindestens
50 m entfernt, Regel aus `checkout_store_resolver.dart`), wird der Standort-Chip gewählt, sobald er da ist, aber nur,
solange der Nutzer noch nichts angetippt hat. Speichern geht immer, auch ohne Markt.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Normal | wie oben |
| Alles abgehakt | Zeile „bleiben auf …“ entfällt |
| Nichts abgehakt (Lena hat zurückgenommen, Avo, Rennen) | statt der Gruppen 2 bis 6 eine Gruppe mit „Noch nichts im Wagen.“ 17/22 Semibold und einem Satz 15/20; Kapsel „Zurück zur Liste“ (schließt, `false`). Kein Verlaufseintrag. Im Einkaufsmodus mit 0 abgehakten Artikeln ruft A diesen Screen gar nicht erst auf (Anfrage A-V9) |
| Ein Mitglied hat die Liste gerade abgeschlossen | Antwort der Abschluss-Funktion „schon abgeschlossen“: Gruppe mit „Lena hat diesen Einkauf gerade abgeschlossen.“, Kapsel „Zum Verlauf“ (öffnet V5 von Lenas Einkauf), Text-Knopf „Zurück zur Liste“ |
| Liste gelöscht, während V1 offen ist | „Diese Liste gibt es nicht mehr.“ mit „Zu den Listen“ |
| Standort nie gefragt, keine Vorauswahl | einmal im Leben (lokal gemerkt) Fußnote „Mit deinem Standort erkennt Avo den Markt selbst.“ und Text-Knopf „Standort verwenden“: öffnet die Vorab-Erklärung (V13), dann die Systemabfrage. Nie eine Systemabfrage ohne Erklärung, nie beim Öffnen |
| Standort abgelehnt, keine Vorauswahl | einmal im Leben dieselbe Fußnote mit „In Einstellungen erlauben“ (öffnet die App-Einstellungen von iOS). Danach nie wieder |
| Standort erlaubt, aber nicht ermittelt (3 s Zeitlimit, Fehler, offline) | kein Hinweis, kein Standort-Chip (heute meldet das Sheet fälschlich „Ohne Standortzugriff“) |
| „Markt automatisch erkennen“ aus (Einstellungen) | keine Standort-Abfrage, kein gelernter Markt; nur der Markt der Liste |
| Offline | alles wie online, kein Standort-Chip (Overpass braucht Netz); Speichern geht in die Warteschlange, der Einkauf steht sofort mit Sync-Zeichen im Verlauf |
| Speichern scheitert später beim Abgleich | Zeile im Verlauf „Nicht gespeichert“, Tippen wiederholt; die Artikel bleiben bis zur Bestätigung lokal als erledigt markiert und gehen nicht verloren |
| Betrag ungültig („abc“, negativ) | Satz 13/18 in `label` mit `exclamationmark.circle` in #D70015 unter der Gruppe; die Kapsel ist gedimmt, solange das Feld etwas Ungültiges enthält. Korrigieren oder Leeren gibt sie frei (leer heißt: Einkauf ohne Betrag) |
| Betrag ungewöhnlich hoch (über 1.000 €) | Hinweis 13/18 `secondaryLabel` „Stimmt der Betrag? 1.428,00 €“, blockiert nicht |
| Modul Kosten teilen aus | Gruppe 5 entfällt ohne Lücke; Fußnote ohne „und zum Teilen“ |
| Liste mit nur dir | Gruppe 5 entfällt (Kosten teilen für Namens-Personen geht später in V5, F12-6) |
| Modul Angebote aus, Kill-Switch, ohne echte Region, Schalter aus, Ersparnis unter 0,50 € | `SavingsLine` entfällt ohne Lücke |
| Pro (falls Kosten teilen Pro wird) | `ToggleRow` mit `ProBadge`; Einschalten läuft über `ProGate.run` zur Paywall, nach dem Kauf steht der Schalter an |
| Ungespeicherte Eingabe und „Schließen“ | nur wenn ein Betrag getippt oder der Markt geändert wurde: Dialog „Änderungen verwerfen?“; sonst schließt V1 sofort, der Einkaufsmodus bleibt |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_checkout_title` | Einkauf abschließen | Finish shopping |
| `hist_checkout_in_cart` | {n, plural, =1{1 Artikel im Wagen} other{# Artikel im Wagen}} | {n, plural, =1{1 item in the cart} other{# items in the cart}} |
| `hist_checkout_left` | {n, plural, =1{1 bleibt auf {list}: {names}} other{# bleiben auf {list}: {names}}} | {n, plural, =1{1 stays on {list}: {names}} other{# stay on {list}: {names}}} |
| `hist_names_more` | {names} und {n} weitere | {names} and {n} more |
| `hist_checkout_where` | Wo warst du? | Where did you shop? |
| `hist_checkout_other_store` | Anderer Markt … | Other store … |
| `hist_checkout_store_here` | {store} (hier) | {store} (here) |
| `hist_checkout_source_list` | Markt dieser Liste | This list's store |
| `hist_checkout_source_learned` | Wie beim letzten Mal | Same as last time |
| `hist_checkout_source_location` | Erkannt über deinen Standort | Found from your location |
| `hist_checkout_location_hint` | Mit deinem Standort erkennt {app} den Markt selbst. | With your location, {app} can tell which store you're in. |
| `hist_checkout_location_use` | Standort verwenden | Use location |
| `hist_checkout_location_settings` | In Einstellungen erlauben | Allow in Settings |
| `hist_checkout_amount` | Betrag | Amount |
| `hist_checkout_amount_placeholder` | optional | optional |
| `hist_checkout_amount_note` | Für deinen Monatsrückblick. | For your monthly review. |
| `hist_checkout_amount_note_split` | Für deinen Monatsrückblick und zum Teilen. | For your monthly review and for splitting. |
| `hist_amount_invalid` | Gib den Betrag als Zahl ein, zum Beispiel 42,80. | Enter the amount as a number, for example 42.80. |
| `hist_amount_check` | Stimmt der Betrag? {amount} | Is this amount right? {amount} |
| `hist_checkout_split` | Kosten teilen | Split costs |
| `hist_checkout_split_one` | Mit {a}. Danach legst du die Anteile fest. | With {a}. You'll set the shares next. |
| `hist_checkout_split_two` | Mit {a} und {b}. Danach legst du die Anteile fest. | With {a} and {b}. You'll set the shares next. |
| `hist_checkout_split_many` | Mit {a}, {b} und {n} weiteren. Danach legst du die Anteile fest. | With {a}, {b} and {n} others. You'll set the shares next. |
| `hist_savings_sentence` | Ca. {amount} durch Angebote gespart, laut Händler | About {amount} saved through offers, according to the retailer |
| `hist_checkout_save` | Einkauf speichern | Save trip |
| `hist_checkout_empty_title` | Noch nichts im Wagen. | Nothing in the cart yet. |
| `hist_checkout_empty_body` | Hake ab, was du in den Wagen legst. Erst dann kommt ein Einkauf in deinen Verlauf. | Check off what goes into your cart. Only then does a trip go into your history. |
| `hist_back_to_list` | Zurück zur Liste | Back to the list |
| `hist_checkout_done_by_other` | {name} hat diesen Einkauf gerade abgeschlossen. | {name} just finished this trip. |
| `hist_to_history` | Zum Verlauf | Go to history |
| `hist_checkout_list_gone` | Diese Liste gibt es nicht mehr. | This list doesn't exist anymore. |
| `hist_to_lists` | Zu den Listen | Go to lists |

„Einkauf abschließen“ heißt überall gleich: Knopf im Einkaufsmodus (D2), Eintrag im Listenmenü, Titel dieses Screens,
leerer Verlauf (Owner-Frage 5). Die Kapsel heißt „Einkauf speichern“, der Hinweis danach „Einkauf gespeichert“.

**Interaktion.**

- „Einkauf speichern“ speichert sofort optimistisch über die atomare Abschluss-Funktion (`complete_shopping_trip`,
  Abschnitt 7) und schließt V1 mit dem Push-Übergang rückwärts. Danach V3. Kein Warten auf das Netz, kein Spinner an der
  Kapsel, außer der Aufruf wird synchron abgelehnt (Liste weg, schon abgeschlossen); dann bleibt V1 offen und zeigt den
  passenden Zustand.
- Chips: `AvoMotion.quick`, keine Haptik. „Anderer Markt …“ pusht V2; die Wahl kommt als gewählter Chip vorn in die
  Reihe zurück und setzt nur den Markt dieses Einkaufs, nicht den der Liste.
- Betrag: Fokus öffnet den Ziffernblock mit Komma; Ziehen im Inhalt schließt die Tastatur (`keyboardDismissBehavior`
  `onDrag`). Beim Verlassen wird „42,8“ zu „42,80 €“.
- Zurück-Wischen und `xmark` ohne Änderungen schließen sofort, `openCheckoutFlow` liefert `false`, der Einkaufsmodus
  bleibt.

**Barrierefreiheit.**

| Element | Vorgelesen (Deutsch) | English |
|---|---|---|
| Titel | Einkauf abschließen, Überschrift | Finish shopping, heading |
| Zusammenfassung | 9 Artikel im Wagen. 2 bleiben auf Wocheneinkauf: Brokkoli, Gouda in Scheiben. | 9 items in the cart. 2 stay on Weekly shop: broccoli, sliced Gouda. |
| Markt-Chip gewählt | Lidl, ausgewählt. Taste. Markt dieser Liste. | Lidl, selected. Button. This list's store. |
| Markt-Chip Standort | REWE, hier. Taste. | REWE, here. Button. |
| Chip „Anderer Markt …“ | Anderer Markt. Taste. Öffnet die Marktauswahl. | Other store. Button. Opens store picker. |
| Betrag | Betrag, optional. Textfeld. Für deinen Monatsrückblick. | Amount, optional. Text field. For your monthly review. |
| Kosten teilen | Kosten teilen, aus. Schalter. Mit Lena. Danach legst du die Anteile fest. | Split costs, off. Switch. With Lena. You'll set the shares next. |
| Ersparnis | Circa 3,20 Euro durch Angebote gespart, laut Händler. | About 3 euros 20 saved through offers, according to the retailer. |
| Kapsel | Einkauf speichern. Taste. | Save trip. Button. |

Die Chips bilden eine Gruppe mit dem Namen „Wo warst du?“ (Auswahl eines Elements). Fokus-Reihenfolge: Schließen, Titel,
Zusammenfassung, „Wo warst du?“ und Chips, Fußnote, Betrag, Fußnote, Kosten teilen, Ersparnis, Kapsel.

Große Schrift: ab xxxL stapelt „Betrag“ den Titel über dem Feld (Feld volle Breite, linksbündig); Chips brechen um
(bei 320 pt und L zwei Chips pro Zeile); ab AX1 Gruppen randlos, `ToggleRow` mit Unterzeile unter dem Titel. Die Kapsel
wächst in der Höhe mit, ihr Text bricht um statt abzuschneiden. Bei AX5 und 320 × 568 muss alles bis zur Kapsel
scrollbar sein und die Kapsel darf höchstens 25 % der Höhe einnehmen; sonst rutscht sie ans Ende des Inhalts statt zu
schweben.

**Daten.** `itemsNotifierProvider(listId)` (A, abgehakte und offene Artikel), Mitglieder über
`splitCandidateMembersProvider(listId)` (lokal zuerst, Lücke L7), `storeForListProvider(listId)` und
`storeGuessForListProvider(listId)` (B-Slots), Ketten-Verzeichnis (`store_chain_directory.dart`) und Lieblingsmärkte
(`user_offer_prefs`, E-13, Paket Angebote), Standort über `CheckoutStoreResolver` (frisch, Zeitlimit 3 s, Overpass `node`
und `way` im Umkreis 250 m), Ersparnis über `summarizeListOffers` mit dem gewählten Markt und `regionProvider` (echte
Region; B2.1, noch nicht gebaut), `offersAvailableProvider`,
`moduleEnabledProvider(AppModule.costSplit)`. Schreiben: neue RPC `complete_shopping_trip` (Lücke L1).

**Avo.** Keine Figur (Geld, Arbeits-Screen).

---

### V2 Markt für diesen Einkauf `/stores/pick?mode=trip`

**Zweck.** Den Markt eines Einkaufs wählen, wenn er unter den Chips fehlt, oder ihn nachträglich ändern.

**Route.** V, Folgeschritt mit `chevron.left`, unter der für B reservierten Wurzel `/stores` (Bereichsdatei des Pakets
Märkte, `offersRootRoutes`). Der Screen selbst ist die Marktauswahl aus dem Paket Märkte (Konzept 12 §3.3 als Vollbild
statt Sheet, eigene Spezifikation). Dieser Abschnitt legt nur fest, was im Modus `trip` anders ist.

**Unterschiede im Modus `trip`.**

- Inline-Titel „Markt für diesen Einkauf“.
- Die letzte Zeile heißt „Ohne Markt“ statt „Kein fester Markt“.
- Fußnote unter „Deine Märkte“: „Ändert nur diesen Einkauf. Den Markt der Liste änderst du in der Liste.“
- Tippen wählt und kehrt sofort zurück (`pop(chainId)`), kein Speichern-Knopf. Aus V5 kommend speichert die Wahl sofort
  optimistisch und zeigt „Markt: REWE“ mit „Widerrufen“.
- Ein eigener Markt aus der Suche („Bio Kaiser“) hat keine Markenfarbe; sein Punkt ist ein Ring in `uncheckedRing`.

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_store_pick_title` | Markt für diesen Einkauf | Store for this trip |
| `hist_store_none` | Ohne Markt | No store |
| `hist_store_pick_note` | Ändert nur diesen Einkauf. Den Markt der Liste änderst du in der Liste. | Only changes this trip. Change the list's store in the list. |
| `hist_store_changed` | Markt: {store} | Store: {store} |

**Avo.** Keine.

---

### V3 Erfolgsmoment und Rückgängig (keine Route)

**Zweck.** Bestätigen, dass der Einkauf sicher im Verlauf liegt, und für ein paar Sekunden das Zurücknehmen erlauben.

**Ablauf.**

1. V1 schließt. Erst danach, über der Liste im Einkaufsmodus: `showSuccessMoment(context, title:, subtitle:,
   pose: AvoPose.celebrating)` von A. Weiße Karte (höchstens 320 breit, Radius 20, D2-Schatten) mittig, Avo feiernd
   120 pt, Titel „Einkauf gespeichert.“ 22/28 Bold (`title2`), Unterzeile 15/20 `secondaryLabel`. Erfolgs-Haptik im
   selben Frame, Feder `celebrate` aus 0,9, steht 1,5 s, Tippen schließt früher. Einmal pro Einkauf.
2. War in V1 „Kosten teilen“ an: Danach pusht B V7 mit `amount` und `from=checkout`.
3. Erst wenn alles zu ist, endet `openCheckoutFlow` mit `true`; A beendet den Einkaufsmodus (Morph zurück) und zeigt die
   Liste mit den offenen Artikeln.
4. Dann `AvoToast`: „Einkauf gespeichert“ mit „Widerrufen“ (4 s, mit VoiceOver 10 s).

**Unterzeile.**

| Fall | Text |
|---|---|
| Markt und Ersparnis (Modul, echte Region, Schalter, mindestens 0,50 €) | 9 Artikel bei Lidl · ca. 3,20 € durch Angebote gespart, laut Händler |
| Markt, keine Ersparnis | 9 Artikel bei Lidl |
| ohne Markt | 9 Artikel |

**Widerrufen.** Nimmt den Verlaufseintrag samt einer in dieser Kette gespeicherten Aufteilung zurück, stellt die
Artikel als abgehakt wieder her (man ist in der normalen Liste mit „Erledigt (9)“, der Einkaufsmodus öffnet nicht neu)
und streicht die geplanten Mitteilungen. Danach kurzer Hinweis ohne Aktion „Einkauf widerrufen. Die Artikel sind wieder
abgehakt.“ Scheitert das Widerrufen (Server lehnt ab, weil ein Mitglied den Einkauf schon geteilt hat): „Widerrufen hat
nicht geklappt. Der Einkauf bleibt im Verlauf.“, Fehler-Haptik.

**Erster Einkauf überhaupt.** Einmalig darf A danach die Pro-Hinweis-Zeile zeigen (00 16.4), nie als Pop-up und nie in
V3 selbst.

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_saved_title` | Einkauf gespeichert. | Trip saved. |
| `hist_saved_sub_store` | {n, plural, =1{1 Artikel bei {store}} other{# Artikel bei {store}}} | {n, plural, =1{1 item at {store}} other{# items at {store}}} |
| `hist_saved_sub` | {n, plural, =1{1 Artikel} other{# Artikel}} | {n, plural, =1{1 item} other{# items}} |
| `hist_saved_sub_savings` | {base} · ca. {amount} durch Angebote gespart, laut Händler | {base} · about {amount} saved through offers, according to the retailer |
| `hist_saved_toast` | Einkauf gespeichert | Trip saved |
| `hist_saved_undone` | Einkauf widerrufen. Die Artikel sind wieder abgehakt. | Trip undone. The items are checked off again. |
| `hist_undo_failed` | Widerrufen hat nicht geklappt. Der Einkauf bleibt im Verlauf. | Couldn't undo. The trip stays in your history. |

**Barrierefreiheit.** Ansage „Einkauf gespeichert. 9 Artikel bei Lidl, circa 3,20 Euro durch Angebote gespart, laut
Händler.“ / „Trip saved. 9 items at Lidl, about 3 euros 20 saved through offers, according to the retailer.“ Die Figur
ist ausgeblendet. Mit VoiceOver steht der Moment, bis die Ansage vorbei ist (A-Baustein), mindestens aber 1,5 s. Reduce
Motion: nur Einblenden. Große Schrift: Texte brechen um; die Figur ist bis AX2 72 pt (A) und entfällt ab AX3 (Anfrage
A-V7), damit Titel und Unterzeile bei 320 × 568 auf die Karte passen.

**Daten.** Rückgabe der Abschluss-Funktion (Einkaufs-ID, Artikelzahl, Kette, Ersparnis in Cent), Undo-Token für die
Warteschlange.

**Avo.** `AvoPose.celebrating`, die einzige Figur des Bereichs bei einem Geld-Thema (Ausnahme laut Regel 12).

---

### V4 Verlauf mit Monatsrückblick `/history`

**Zweck.** Was habe ich eingekauft und was hat es gekostet? Oben der Monat als eine Zahl mit seinem Verlauf, darunter
jeder Einkauf wie eine Buchung in Wallet.

**Route.** Wurzel des Bereichs, Push im Listen-Tab, Tab-Leiste sichtbar. `?list=<listId>` setzt den Filter. Ersetzt
`shopping_history_screen.dart` (Material-AppBar ohne Titel, Kicker „AKTIVITÄTEN“, Serifen, `_Stat` mit fester Breite 82
und Überlauf bei 320 pt, Lebenszeit-Zahl, Wochentags-Diagramm, aufklappbare Zeilen, Löschen nur per Langdruck,
Vollbild-Spinner, kein Cache, „3.20 €“ mit Punkt). Neue Datei `screens/history/history_screen.dart`.

**Aufbau.**

1. Toolbar (54 pt): links `GlassIconButton` `chevronBack` „Zurück“; rechts `GlassIconButton` Filter
   (`line.3.horizontal.decrease.circle`, gefüllt, wenn ein Filter aktiv ist; Anfrage A-V16) mit Pull-down-Menü
   (`showAvoMenu`, S2b): „Alle Listen“ (Häkchen, wenn aktiv), Trenner, je Liste mit Einkäufen ihr Name, sortiert nach
   letztem Einkauf. Darunter `ScrollEdgeFade`.
2. Großer Titel „Verlauf“ 34/41 (E-06, Anfrage A-V21).
3. Nur mit Filter: Metazeile 15/20 `secondaryLabel` „Nur Wocheneinkauf“, rechts Text-Knopf „Alle“ (44 pt).
4. `StatusRow` bei Bedarf (offline, Fehler, wartet).
5. `MonthReview` (weiße Karte Radius 26, Innenabstand 16, 12 pt unter dem Titel bzw. der Metazeile):
   - Kopfzeile 15/20 `secondaryLabel`: „Ausgaben pro Monat“ (bzw. „Einkäufe pro Monat“, siehe unten).
   - Wert des gewählten Monats in `numberXL` 34/41 Bold tabellarisch, `RollingNumber`: „168,40 €“.
   - darunter 15/20 `label`: „November, bisher“ im laufenden Monat, sonst „Oktober“ (mit Jahr, wenn nicht das laufende).
   - darunter, nur bei der Reihe „Ausgaben“ und nur wenn nicht alle Einkäufe des Monats einen Betrag haben, 13/18
     `secondaryLabel`: „aus 4 von 6 Einkäufen“.
   - darunter, nur in abgeschlossenen Monaten, wenn dieser und der Vormonat je mindestens 80 % ihrer Einkäufe mit Betrag
     haben, 13/18 `secondaryLabel`: „10,80 € weniger als im September“ (Betrag in `tint` 600 bei weniger, in `label`
     600 bei mehr; nie Rot, nie Pfeil). Unter 1 € Unterschied: „Etwa so viel wie im September“. Im laufenden Monat nie
     ein Vergleich.
   - 16 pt darunter `SpendingBars`: 6 Monate (der laufende und die 5 davor), Maße aus 2.1. Gewählter Monat: Balken
     #34A853, Wert #1F7A3A 600, Kürzel #1C1C1E 600. Der laufende Monat trägt unter seinem Kürzel eine zweite Zeile
     „bisher“ 11/13 `secondaryLabel`, statt eines gestrichelten Prognose-Umrisses (Abschnitt 5, Konflikt 4). Ein Monat
     ohne Wert hat keinen Balken und keine Wertebeschriftung, nur sein Kürzel; er ist nicht wählbar. Höhen linear zum
     größten Wert der 6 Monate, der größte Balken 84 pt, Nullbasis.
   - 16 pt darunter `StatStrip` mit zwei gleich breiten Spalten im Stil von `D2-FuerDich` §3 (Wert 20/25 Bold
     tabellarisch über der Bezeichnung 13/18 `secondaryLabel`, getrennt durch 0,5 pt rgba(60,60,67,.18)), hier ohne
     Symbole, weil das Diagramm darüber schon das Bild der Karte ist: „6“ · „Einkäufe“ und „58“ · „Artikel“. Zeigt die
     Reihe „Einkäufe pro Monat“, steht die Zahl der Einkäufe schon groß darüber; dann zeigt die erste Spalte „Ausgaben“
     (Summe der erfassten Beträge, mit „aus 1 von 6“ in der Bezeichnung) oder, ganz ohne Beträge, entfällt sie.
   - Ersparnis nur mit Angebote, echter Region, Schalter und mindestens 0,50 €: keine Spalte (sie braucht „ca.“ und
     „laut Händler“ und passt nicht in eine Spalte), sondern ein Satz 12 pt unter der Leiste: `tag` 20 in `tint`,
     „Ca. 9,80 € durch Angebote gespart, laut Händler“ 15/20 `label` (Abschnitt 5, Konflikt 3).
   - Letzte Zeile, nur mit mindestens 6 Einkäufen in den letzten 90 Tagen und einem eindeutig häufigsten Wochentag,
     15/20 `label`: „In den letzten 3 Monaten hast du meist samstags eingekauft.“
6. Nur einmal, wenn noch kein Einkauf einen Betrag hat und mindestens 2 Einkäufe gespeichert sind: `HintRow` „Tipp: Gib
   beim Abschluss den Betrag ein, dann siehst du hier deine Ausgaben.“ mit Schließen (`onDismiss`, gemerkt im Konto).
7. Einkäufe nach Monat: je Monat `SectionCaps` „NOVEMBER“ mit Zahl rechts „6“ (13/18 tabellarisch) und eine
   `InsetSection` mit `TripRow`s, neueste zuerst. Geladen sind die letzten 3 Monate aus dem lokalen Stand; beim
   Weiterscrollen lädt die nächste Seite (30 Einkäufe) unterhalb der Leseposition. Am Ende: Fußnote 13/18 „Ältere
   Einkäufe gibt es nicht.“ nur, wenn wirklich alles geladen ist.
8. Unterer Abstand `ShellInsets.bottom` (A).

**Reihe des Diagramms (K12-05).** „Ausgaben pro Monat“, wenn in mindestens 3 der 6 Monate mindestens ein Einkauf mit
Betrag liegt; sonst „Einkäufe pro Monat“ (Anzahl), und `numberXL` zeigt die Zahl der Einkäufe („6“). Die Kopfzeile nennt
immer, was die Reihe zeigt. Die Reihe wechselt nur beim Öffnen, nie unter dem Finger.

**`TripRow` (Variante `full`).**

- Mindestens 64 hoch, Innenrand 10 × 16, Abstand 12. Links `StoreBadge` 40.
- Titel 17/22 Semibold: der Markt („Lidl“); ohne Markt der Listenname.
- Unterzeile 15/20 `secondaryLabel`: Listenname · Datum · Artikelzahl: „Wocheneinkauf · Heute, 18:40 · 9 Artikel“; ohne
  Markt „Heute, 18:40 · 9 Artikel“. Fremder Einkauf hängt „· von Lena“ an.
- Zweite Unterzeile nur mit Modul Kosten teilen und offenem Anteil, 15/20 `label`: „Lena schuldet dir 21,40 €“, „Du
  schuldest Lena 11,58 €“, mehrere: „2 schulden dir 34,60 €“. Alles beglichen: keine Zeile.
- Rechts, oben bündig: Betrag 17/22 Semibold tabellarisch („42,80 €“) oder nichts; darunter mit Angebote und echter
  Ersparnis 13/18 600 `tint` „ca. 3,20 € gespart“.
- Chevron 8 × 14 #C7C7CC. Trenner ab 68 pt.
- Wird gespeichert: Sync-Symbol 10 pt hinter dem Betrag. Nicht gespeichert: statt Betrag `exclamationmark.circle` 15
  #D70015 und darunter „Nicht gespeichert“ 13/18 #D70015; Tippen wiederholt.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Lädt mit lokalem Stand | sofort sichtbar, Abgleich unsichtbar, neue Einkäufe anderer Mitglieder wachsen oben ein |
| Allererstes Laden ohne Stand | Monatskarte als ruhige Tonfläche gleicher Höhe (Zahl, Balkenreihe, Leiste), darunter `SkeletonSection(rows: 5, withImage: true)`; nach 10 s Fehler |
| Leer (noch nie ein Einkauf) | statt Karte und Abschnitten `EmptyState` mit `AvoPose.waving` 96 pt, Titel „Noch keine Einkäufe.“, Satz, Aktion „Zu den Listen“ (wechselt zur Wurzel des Listen-Tabs). Ab AX1 ohne Figur |
| Erster Monat, weniger als 2 Monate mit Daten | Balkenreihe entfällt, an ihrer Stelle 15/20 `label` „Ab dem zweiten Monat siehst du hier deinen Verlauf.“; Zahl, Leiste und Sätze bleiben |
| Keine Beträge erfasst | Reihe „Einkäufe pro Monat“, Tipp-Zeile (einmal) |
| Fehler mit lokalem Stand | `StatusRow(kind: failed)` „Der Verlauf konnte nicht aktualisiert werden.“ mit „Erneut versuchen“; Inhalt bleibt |
| Fehler ohne lokalen Stand | im Layout des leeren Zustands, ohne Figur: Symbol `exclamationmark.circle` 48 Light, „Deine Einkäufe konnten nicht geladen werden.“, Aktion „Erneut versuchen“ |
| Offline mit Stand | `StatusRow(kind: offline)` „Offline. Neue Einkäufe erscheinen, sobald du wieder online bist.“; eigene ausstehende Einkäufe mit Sync-Zeichen |
| Offline ohne Stand | „Offline. Dein Verlauf erscheint, sobald du wieder online bist.“ ohne Knopf, lädt selbst, sobald online |
| Filter ohne Treffer | statt der Abschnitte ein Satz in der Gruppe „Mit Wocheneinkauf gibt es noch keine Einkäufe.“ und Text-Knopf „Alle Listen“; Monatskarte zeigt 0 Einkäufe ehrlich („0“, keine Balken) |
| Modul Angebote aus, Kill-Switch, ohne echte Region | Ersparnis-Satz in der Karte und „ca. … gespart“ in den Zeilen entfallen ohne Lücke |
| Modul Kosten teilen aus | Schuld-Unterzeilen und Kontextmenü „Kosten teilen“ entfallen; Daten bleiben |
| Einkauf von anderswo gelöscht | Zeile schrumpft weg, Monatswerte rollen, kein Hinweis |
| Pro (falls „Statistiken“ Pro werden) | laufender Monat vollständig frei; Tippen oder Ziehen auf frühere Balken öffnet über `ProGate.run` die Paywall `/pro?feature=stats` (wächst aus dem Balken, Push), `ProBadge` hinter „Ausgaben pro Monat“; die Einkaufsliste darunter bleibt immer frei (Kern) |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_title` | Verlauf | History |
| `hist_filter_a11y` | Nach Liste filtern | Filter by list |
| `hist_filter_all` | Alle Listen | All lists |
| `hist_filter_active` | Nur {list} | Only {list} |
| `hist_filter_empty` | Mit {list} gibt es noch keine Einkäufe. | No trips with {list} yet. |
| `hist_month_spend_label` | Ausgaben pro Monat | Spending per month |
| `hist_month_trips_label` | Einkäufe pro Monat | Trips per month |
| `hist_month_running` | {month}, bisher | {month} so far |
| `hist_month_coverage` | aus {n} von {m} Einkäufen | from {n} of {m} trips |
| `hist_month_less` | {amount} weniger als im {prev} | {amount} less than in {prev} |
| `hist_month_more` | {amount} mehr als im {prev} | {amount} more than in {prev} |
| `hist_month_same` | Etwa so viel wie im {prev} | About the same as in {prev} |
| `hist_bar_running` | bisher | so far |
| `hist_stat_trips` | Einkäufe | Trips |
| `hist_stat_items` | Artikel | Items |
| `hist_stat_spend` | Ausgaben | Spending |
| `hist_weekday_line` | In den letzten 3 Monaten hast du meist {weekday} eingekauft. | Over the last 3 months you mostly shopped on {weekday}. |
| `hist_weekday_1` … `hist_weekday_7` | montags, dienstags, mittwochs, donnerstags, freitags, samstags, sonntags | Mondays, Tuesdays, Wednesdays, Thursdays, Fridays, Saturdays, Sundays |
| `hist_chart_first` | Ab dem zweiten Monat siehst du hier deinen Verlauf. | From your second month on, you'll see your history here. |
| `hist_tip_amount` | Tipp: Gib beim Abschluss den Betrag ein, dann siehst du hier deine Ausgaben. | Tip: Enter the amount when you finish shopping to see your spending here. |
| `hist_list_end` | Ältere Einkäufe gibt es nicht. | No older trips. |
| `hist_trip_sub` | {list} · {date} · {n, plural, =1{1 Artikel} other{# Artikel}} | {list} · {date} · {n, plural, =1{1 item} other{# items}} |
| `hist_trip_by` | von {name} | by {name} |
| `hist_trip_owes_you` | {name} schuldet dir {amount} | {name} owes you {amount} |
| `hist_trip_you_owe` | Du schuldest {name} {amount} | You owe {name} {amount} |
| `hist_trip_owe_you_many` | {n} schulden dir {amount} | {n} people owe you {amount} |
| `hist_trip_savings` | ca. {amount} gespart | about {amount} saved |
| `hist_date_today` | Heute, {time} | Today, {time} |
| `hist_date_yesterday` | Gestern, {time} | Yesterday, {time} |
| `hist_empty_title` | Noch keine Einkäufe. | No trips yet. |
| `hist_empty_body` | Wenn du im Einkaufsmodus auf „Einkauf abschließen“ tippst, landet dein Einkauf hier. | When you tap Finish shopping in shopping mode, the trip shows up here. |
| `hist_refresh_failed` | Der Verlauf konnte nicht aktualisiert werden. | Couldn't refresh your history. |
| `hist_load_failed` | Deine Einkäufe konnten nicht geladen werden. | Couldn't load your trips. |
| `hist_status_offline` | Offline. Neue Einkäufe erscheinen, sobald du wieder online bist. | You're offline. New trips will show up once you're back online. |
| `hist_offline_empty` | Offline. Dein Verlauf erscheint, sobald du wieder online bist. | You're offline. Your history will appear once you're back online. |
| `hist_menu_readd` | Alle wieder auf die Liste | Add all to the list again |
| `hist_menu_split` | Kosten teilen | Split costs |
| `hist_menu_split_edit` | Aufteilung ändern | Edit split |
| `hist_menu_amount_add` | Betrag eintragen | Add amount |
| `hist_menu_amount_edit` | Betrag ändern | Change amount |
| `hist_menu_store` | Markt ändern | Change store |
| `hist_menu_delete` | Löschen | Delete |
| `hist_delete_failed` | Löschen hat nicht geklappt. | Couldn't delete. |
| `hist_trip_gone` | Dieser Einkauf wurde gelöscht. | This trip was deleted. |

Monatsnamen und -kürzel kommen aus `intl` (`DateFormat.MMMM`, `DateFormat.MMM` mit Locale), nicht aus Schlüsseln. Im
Englischen steht „less than in October“ ohne Artikel; das Muster `{prev}` bekommt dort den Monatsnamen.

**Interaktion.**

- Tippen auf einen Balken (Spalte inklusive Beschriftung, mindestens 44 pt hoch) wählt den Monat. Ziehen über die
  Balkenreihe wählt den Monat unter dem Finger, Auswahl-Haptik pro neuem Monat; Loslassen lässt die Auswahl stehen.
  Zahl, Monatszeile, Abdeckung, Vergleich, Leiste und Ersparnis-Satz wechseln mit (Zahlen rollen, Sätze blenden über,
  die Kartenhöhe ändert sich mit `AvoMotion.standard`). Waagerechtes Ziehen über dem Diagramm gewinnt gegen das
  Zurück-Wischen nur, wenn es in der Balkenreihe beginnt. Erneutes Öffnen startet beim laufenden Monat.
- Monatswahl filtert die Einkäufe darunter nicht; sie scrollt auch nicht.
- Ziehen nach unten am Anfang lädt Einkäufe und Aufteilungen neu (System-Refresh, heute fehlt das).
- Tippen auf eine `TripRow` pusht V5.
- Wischen nach links auf eigenen Einkäufen: „Löschen“ (#D70015, volles Wischen löst aus, leichter Impuls an der
  Schwelle) → Dialog V13. Fremde Einkäufe haben kein Löschen (behebt stilles Scheitern, Bug 4).
- Langdruck: Kontextmenü (A-Baustein, Anfrage A-V17) „Alle wieder auf die Liste“, „Kosten teilen“ bzw. „Aufteilung
  ändern“ (Modul), „Betrag eintragen“ bzw. „Betrag ändern“ (nur Einkäufer), „Markt ändern“ (nur Einkäufer), Trenner,
  „Löschen“ (nur eigene, destruktiv). Die Vorschau im Kontextmenü ist die Zeile selbst, kein Detail.
- Filter: wirkt auf Karte, Diagramm und Abschnitte; blendet über, `?list=` wird in die Route geschrieben, damit Zurück
  aus V5 den Filter behält.

**Barrierefreiheit.**

| Element | Vorgelesen (Deutsch) | English |
|---|---|---|
| Titel | Verlauf, Überschrift | History, heading |
| Filter | Nach Liste filtern, Taste. Alle Listen | Filter by list, button. All lists |
| Monatskarte, Zahl | Ausgaben pro Monat. November bisher: 168,40 Euro, aus 4 von 6 Einkäufen. | Spending per month. November so far: 168 euros 40, from 4 of 6 trips. |
| Diagramm (Gruppe, Zusammenfassung) | Ausgaben pro Monat. Juni 240,10 Euro, Juli 286,50 Euro, August 198,30 Euro, September 262,70 Euro, Oktober 251,90 Euro, November bisher 168,40 Euro. | Spending per month. June 240 euros 10, July 286 euros 50, … November so far 168 euros 40. |
| Balken (je ein Element, Taste mit Zustand) | Oktober, 251,90 Euro. Ausgewählt. Hinweis: Doppeltippen wählt den Monat. | October, 251 euros 90. Selected. Hint: double-tap to select this month. |
| Balken ohne Wert | Juni, kein Betrag erfasst. | June, no amount recorded. |
| Leiste | Einkäufe 6. Artikel 58. | Trips 6. Items 58. |
| `TripRow` | Lidl, Wocheneinkauf, heute 18 Uhr 40, 9 Artikel, 42,80 Euro, circa 3,20 Euro gespart, Lena schuldet dir 21,40 Euro. Aktionen: Alle wieder auf die Liste, Kosten teilen, Betrag ändern, Löschen | Lidl, Weekly shop, today 6:40 PM, 9 items, 42 euros 80, about 3 euros 20 saved, Lena owes you 21 euros 40. Actions: Add all to the list again, Split costs, Change amount, Delete |
| Monatskopf | November, 6 Einkäufe, Überschrift | November, 6 trips, heading |

Der Balkenwechsel wird nicht extra angesagt; VoiceOver liest den gewählten Balken. Mit VoiceOver wählt man den Monat
per Doppeltippen auf einen Balken oder per Wischen nach oben und unten auf der Diagrammgruppe (einstellbares Element,
`onIncrease`/`onDecrease`, kein `slider`). Fokus-Reihenfolge: Zurück, Titel, Filter, Metazeile, `StatusRow`, Kopfzeile und
Zahl, Monatszeile, Abdeckung, Vergleich, Diagramm, Leiste, Ersparnis, Wochentag, Tipp, dann die Monate.

Große Schrift: siehe 3.9. Ab AX1 `TripRow` ohne `StoreBadge`, Betrag und Ersparnis unter den Unterzeilen
(linksbündig), Chevron bleibt rechts oben bündig zur ersten Zeile. Leiste als Zeilen. Diagramm wie 3.9.

**Daten.** Neu `historyFeedProvider(listFilter)` (lokal zuerst aus `LocalStore`, Seiten zu 30, Realtime bzw. Nachladen
nach Rückkehr aus dem Hintergrund über 2 s; ersetzt `shoppingHistoryProvider`, `recentHistoryProvider`,
`shoppingHistoryNotifierProvider`), neu `monthReviewProvider(month, listFilter)` aus der reinen Funktion
`summarizeMonth(trips)` (Einkäufe, Artikel, Ausgaben mit Abdeckung, Ersparnis ungerundet, Vergleichbarkeit, Wochentag),
`tripSplitsSummaryProvider` (offene Anteile pro Einkauf), `offersAvailableProvider`, `regionProvider`,
`moduleEnabledProvider(AppModule.costSplit)`, `connectionStateProvider`, `syncStatusProvider('history')`. Löschen über
die Warteschlange mit `ShoppingHistoryService.deleteHistory`, das künftig bei einem RLS-Leertreffer einen Fehler wirft.

**Avo.** `AvoPose.waving` nur im leeren Zustand.

---

### V5 Einkauf-Detail `/history/:tripId`

**Zweck.** Was war in diesem Einkauf, und ist alles erledigt (Geld, Nachkaufen)?

**Route.** K, Push im Listen-Tab über dem Verlauf, Tab-Leiste sichtbar. Neue Datei
`screens/history/trip_detail_screen.dart`. Ersetzt die aufklappbare Zeile im alten Verlauf.

**Aufbau.**

1. Toolbar (54 pt): links „Zurück“; Mitte Inline-Titel = Listenname („Wocheneinkauf“); rechts `GlassIconButton` `more`
   „Mehr“ mit Pull-down-Menü: „Betrag eintragen“ bzw. „Betrag ändern“ (nur Einkäufer), „Markt ändern“ (nur Einkäufer),
   „Kosten teilen“ bzw. „Aufteilung ändern“ (Modul, jedes Mitglied), Trenner, „Löschen“ (nur eigene, destruktiv).
   Einträge, die nicht erlaubt sind, fehlen, statt grau zu sein.
2. Kopf, weiße Karte Radius 26, Innenabstand 20 × 16:
   - links: `StoreBadge` 40, 12 pt daneben Marktname 20/25 Semibold (`title3`); ohne Markt „Ohne Markt“ in
     `secondaryLabel`. Darunter 15/20 `secondaryLabel` „Sa., 7. Nov., 18:40“ und eine Zeile mit `Avatar` 20 und
     „Eingekauft von dir“ bzw. „Eingekauft von Lena“.
   - rechts, oben bündig: Betrag in `numberXL` („42,80 €“). Ohne Betrag statt der Zahl Text-Knopf „Betrag eintragen“
     (nur Einkäufer; sonst nichts).
3. Hauptaktion, 16 pt unter dem Kopf: Reihe aus `AppButton.primary(size: regular)` „Alle wieder auf die Liste“ mit
   Symbol `cart.badge.plus` (Anfrage A-V16), volle Breite minus 52, und 8 pt daneben ein runder Knopf 44 auf `fill` mit
   `chevronDown` „Andere Liste wählen“ (Pull-down-Menü mit allen Listen, Ziel-Liste mit Häkchen). Darunter Fußnote
   13/18 `secondaryLabel`: „Auf Wocheneinkauf. 2 Artikel stehen dort schon.“ bzw. „Auf Wocheneinkauf.“
4. Nur mit Modul Kosten teilen: Abschnitt „KOSTEN TEILEN“ mit Text-Knopf „Ändern“ rechts im Kopf (öffnet V7), Gruppe:
   - je Teilnehmer außer dem Zahler eine `SplitParticipantRow` (mindestens 60 hoch): `Avatar` 28, Name 17/22,
     Unterzeile 15/20 `secondaryLabel` „offen“ bzw. „bezahlt am 8. Nov.“, bei Namens-Personen zusätzlich „ohne Konto“;
     rechts Betrag 17/22 tabellarisch und dahinter Text-Knopf „Bezahlt“ (wenn du gezahlt hast) bzw. „Zurückgezahlt“
     (wenn du schuldest). Bezahlte Zeilen haben keinen Knopf.
   - Fußnote: „Bezahlt von dir · 42,80 € · gleich aufgeteilt“ (bzw. „individuell aufgeteilt“).
   - Ohne Aufteilung statt der Gruppe eine Zeile `eurosign.circle` in `tint`, „Kosten teilen“ 17/22 in `tint`, Unterzeile
     „Mit Lena“ (bei Listen ohne Mitglieder „Mit Personen ohne Konto“); öffnet V7.
5. Nur mit Angebote, echter Region und echtem Wert: Abschnitt „GESPART“, `SavingsLine` „Ca. 3,20 € durch Angebote
   gespart, laut Händler“, Fußnote „4 Artikel im Angebot bei Lidl“.
6. Abschnitt „ARTIKEL“ mit Zahl „9“, Gruppe aus `HistoryItemRow`s (D2-Artikelzeile ohne Abhak-Kreis): `ArticleImage`
   44 Radius 10, Name 17/22, Menge 15/20 `secondaryLabel` („2“, „1 kg“); rechts nur mit Angebote die Pille „0,99 €“ (der
   Markt steht schon im Kopf); weitere Unterzeile 15/20 `secondaryLabel`, wenn der Händler einen Vergleichspreis nannte:
   „laut Händler statt 1,19 €“; Unterzeile „Steht auf Wocheneinkauf“, wenn der Artikel dort gerade offen ist.
7. Nur wenn Artikel auf der Liste geblieben sind: Abschnitt „GEBLIEBEN“, Gruppe mit einem Satz 17/22 „Brokkoli, Gouda in
   Scheiben“ und Text-Knopf „Zur Liste“ rechts bzw. darunter.
8. Unterer Abstand `ShellInsets.bottom`.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Eigener Einkauf | alles wie oben |
| Fremder Einkauf (Lena) | „Eingekauft von Lena“; kein Löschen, kein Betrag ändern, kein Markt ändern (Menüeinträge fehlen); Kosten teilen darf jedes Mitglied (serverseitig geprüft) |
| Alle Artikel stehen schon offen auf der Ziel-Liste | Hauptaktion deaktiviert (40 % Deckkraft, VoiceOver „gedimmt“), Fußnote „Alles steht schon auf Wocheneinkauf.“ |
| Ziel-Liste gelöscht oder kein Mitglied mehr | Ziel ist die Liste von heute (A), Fußnote nennt sie |
| Altdaten ohne Liste | Titel „Einkauf“, Ziel die Liste von heute, Kosten teilen nur mit Namens-Personen |
| Aufteilung lädt ohne Stand | zwei Platzhalter-Zeilen in `fill` |
| Aufteilung lädt nicht | in der Gruppe `StatusRow(kind: failed)` „Die Aufteilung konnte nicht geladen werden.“ mit „Erneut versuchen“ (heute verschwindet sie still) |
| „Bezahlt“ scheitert | Zeile rollt zurück, in der Zeile `StatusRow` „Nicht gespeichert.“ mit „Erneut versuchen“, Fehler-Haptik (behebt Bug 6) |
| Lädt ohne lokalen Stand (Mitteilung im Kaltstart) | Tonfläche in Kopfgröße, Hauptaktion als Tonfläche, `SkeletonSection(rows: 5)` |
| Offline | alles lesbar; Aktionen in die Warteschlange, Sync-Zeichen an der betroffenen Zeile bzw. am Betrag |
| Von anderswo gelöscht | zurück zum Verlauf, Hinweis „Dieser Einkauf wurde gelöscht.“ |
| Modul Kosten teilen aus | Abschnitt 4 und Menüeintrag entfallen ohne Lücke |
| Modul Angebote aus, Kill-Switch, ohne echte Region | Abschnitt 5, Pillen und „laut Händler statt“ entfallen |
| Pro (falls Kosten teilen Pro wird) | Zeile „Kosten teilen“ mit `ProBadge`, öffnet über `ProGate.run` die Paywall; bestehende Aufteilungen bleiben sichtbar und „Bezahlt“ funktioniert weiter |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_detail_untitled` | Einkauf | Trip |
| `hist_detail_by_you` | Eingekauft von dir | Shopped by you |
| `hist_detail_by` | Eingekauft von {name} | Shopped by {name} |
| `hist_detail_add_amount` | Betrag eintragen | Add amount |
| `hist_readd` | Alle wieder auf die Liste | Add all to the list again |
| `hist_readd_pick` | Andere Liste wählen | Choose another list |
| `hist_readd_target` | Auf {list}. | To {list}. |
| `hist_readd_some_open` | Auf {list}. {n, plural, =1{1 Artikel steht dort schon.} other{# Artikel stehen dort schon.}} | To {list}. {n, plural, =1{1 item is already there.} other{# items are already there.}} |
| `hist_readd_all_open` | Alles steht schon auf {list}. | Everything is already on {list}. |
| `hist_readd_done` | {n, plural, =1{1 Artikel auf {list}} other{# Artikel auf {list}}} | {n, plural, =1{1 item added to {list}} other{# items added to {list}}} |
| `hist_item_readd` | Auf die Liste | Add to list |
| `hist_item_readd_other` | Auf andere Liste … | Add to another list … |
| `hist_item_readd_done` | {name} auf {list} | {name} added to {list} |
| `hist_item_on_list` | Steht auf {list} | On {list} |
| `hist_item_was` | laut Händler statt {old} | was {old}, according to the retailer |
| `hist_split_section` | Kosten teilen | Split costs |
| `hist_split_edit` | Ändern | Edit |
| `hist_split_open` | offen | open |
| `hist_split_paid_on` | bezahlt am {date} | paid on {date} |
| `hist_split_no_account` | ohne Konto | no account |
| `hist_split_mark_paid` | Bezahlt | Paid |
| `hist_split_mark_repaid` | Zurückgezahlt | Paid back |
| `hist_split_reopen` | Wieder als offen markieren | Mark as open again |
| `hist_split_footer_equal` | Bezahlt von {payer} · {amount} · gleich aufgeteilt | Paid by {payer} · {amount} · split equally |
| `hist_split_footer_custom` | Bezahlt von {payer} · {amount} · individuell aufgeteilt | Paid by {payer} · {amount} · split individually |
| `hist_payer_you` | dir | you |
| `hist_split_start_with` | Mit {names} | With {names} |
| `hist_split_start_names_only` | Mit Personen ohne Konto | With people without an account |
| `hist_split_paid_toast` | {name}: bezahlt | {name}: paid |
| `hist_split_repaid_toast` | Zurückgezahlt an {name} | Paid back to {name} |
| `hist_split_reopened_toast` | {name}: wieder offen | {name}: open again |
| `hist_split_load_failed` | Die Aufteilung konnte nicht geladen werden. | Couldn't load the split. |
| `hist_row_not_saved` | Nicht gespeichert. | Not saved. |
| `hist_remind` | Erinnern | Remind |
| `hist_remind_text` | Kleine Erinnerung: {amount} für unseren Einkauf „{list}“ bei {store} am {date}. Danke. | Quick reminder: {amount} for our “{list}” shop at {store} on {date}. Thanks. |
| `hist_remind_text_no_store` | Kleine Erinnerung: {amount} für unseren Einkauf „{list}“ am {date}. Danke. | Quick reminder: {amount} for our “{list}” shop on {date}. Thanks. |
| `hist_saved_section` | Gespart | Saved |
| `hist_detail_savings_count` | {n, plural, =1{1 Artikel im Angebot bei {store}} other{# Artikel im Angebot bei {store}}} | {n, plural, =1{1 item on offer at {store}} other{# items on offer at {store}}} |
| `hist_items_section` | Artikel | Items |
| `hist_left_section` | Geblieben | Left on the list |
| `hist_left_to_list` | Zur Liste | Open list |

**Interaktion.**

- „Alle wieder auf die Liste“ fügt über `ItemRepository.instance.addItems` alle Artikel hinzu, die nicht schon offen auf
  der Ziel-Liste stehen, mit ihren Mengen und ohne alte Preise (aktuelle Angebote hängen sich dort von selbst an). Kein
  Zusammenführen in vorhandene offene Artikel (Anfrage A-V19). Der Screen bleibt stehen; die Artikelzeilen bekommen
  „Steht auf Wocheneinkauf“ (wächst ein), die Fußnote wechselt, Hinweis „9 Artikel auf Wocheneinkauf“ mit „Widerrufen“
  (`undoAddItems`). Beim Einkauf vom 4. Nov. mit 2 schon offenen Artikeln: „5 Artikel auf Wocheneinkauf“. Keine Haptik.
- Pull-down am Chevron-Knopf: wählt die Ziel-Liste nur für diese Aktion; die Fußnote nennt sie sofort.
- Artikelzeile nach rechts wischen: „Auf die Liste“ (`tint`, leichter Impuls an der Schwelle, volles Wischen löst aus).
  Langdruck: Kontextmenü „Auf die Liste“, „Auf andere Liste …“ (Untermenü mit den Listen).
- „Bezahlt“ bzw. „Zurückgezahlt“: wirkt sofort optimistisch, Unterzeile wird „bezahlt am 7. Nov.“, der Knopf verschwindet,
  Hinweis „Lena: bezahlt“ mit „Widerrufen“. Keine Haptik. Die Mitteilung an die Gegenseite geht nach Ablauf des
  Hinweises raus, nie an den Auslöser, nie an Namens-Personen.
- Teilnehmerzeile nach links wischen (nur offene Anteile, die dir geschuldet werden): „Erinnern“ (`share`) öffnet das
  System-Teilen mit dem Erinnerungstext (Owner-Frage 7). Für Anteile, die du schuldest, und für bezahlte Anteile gibt es
  kein „Erinnern“. Langdruck auf bezahlte Zeilen: „Wieder als offen markieren“ mit Rückgängig-Hinweis.
- Betrag im Kopf oder Menü „Betrag ändern“: öffnet V6. Nach dem Speichern rollen die Ziffern im Kopf und im Verlauf.
- „Markt ändern“: öffnet V2 im Modus `trip` mit `tripId`; die Wahl speichert sofort, Hinweis „Markt: REWE“ mit
  „Widerrufen“. Die Ersparnis wird für den neuen Markt neu berechnet (meist entfällt sie dann).
- „Löschen“: Dialog V13. Nach dem Löschen zurück zum Verlauf, die Zeile ist schon weg, kein Rückgängig.
- „Zur Liste“ in „Geblieben“: wechselt zur Liste (A-Route `/lists/:listId`).

**Barrierefreiheit.**

| Element | Vorgelesen (Deutsch) | English |
|---|---|---|
| Kopf (ein Element) | Lidl, Samstag, 7. November, 18 Uhr 40, eingekauft von dir, 42,80 Euro | Lidl, Saturday, November 7, 6:40 PM, shopped by you, 42 euros 80 |
| Hauptaktion | Alle wieder auf die Liste. Taste. Auf Wocheneinkauf, 2 Artikel stehen dort schon. | Add all to the list again. Button. To Weekly shop, 2 items are already there. |
| Ziel-Knopf | Andere Liste wählen. Taste. Ziel: Wocheneinkauf | Choose another list. Button. Target: Weekly shop |
| Teilnehmerzeile | Lena, 21,40 Euro, offen. Aktionen: Bezahlt, Erinnern | Lena, 21 euros 40, open. Actions: Paid, Remind |
| Teilnehmerzeile bezahlt | Lena, 21,40 Euro, bezahlt am 8. November. Aktion: Wieder als offen markieren | Lena, 21 euros 40, paid on November 8. Action: Mark as open again |
| Ersparnis | Circa 3,20 Euro durch Angebote gespart, laut Händler. 4 Artikel im Angebot bei Lidl. | About 3 euros 20 saved through offers, according to the retailer. 4 items on offer at Lidl. |
| Artikelzeile | Milch, 2, im Angebot gekauft für 0,99 Euro, laut Händler statt 1,19 Euro. Steht auf Wocheneinkauf. Aktionen: Auf die Liste, Auf andere Liste | Milk, 2, bought on offer for 99 cents, was 1 euro 19 according to the retailer. On Weekly shop. Actions: Add to list, Add to another list |

Die Knöpfe „Bezahlt“ sind zusätzlich eigene Elemente nach ihrer Zeile, damit Schaltersteuerung und Tastatur sie
erreichen. Fokus-Reihenfolge: Zurück, Titel, Mehr, Kopf, Betrag eintragen, Hauptaktion, Ziel-Knopf, Fußnote, Kosten
teilen (Kopf, Ändern, Zeilen), Gespart, Artikel, Geblieben.

Große Schrift: ab xxxL stapelt der Kopf (Markt, Datum, Person, darunter der Betrag `numberXL` linksbündig, höchstens
51 pt); bei 320 pt und L steht der Betrag schon unter dem Markt, sobald Markt und Betrag zusammen nicht in eine Zeile
passen (gemessen). Hauptaktion bricht um; ab xxL rutscht der Ziel-Knopf unter die Kapsel (volle Breite, Text „Andere
Liste wählen“ statt nur Chevron). Ab AX1 Teilnehmer- und Artikelzeilen ohne Avatar und Bild, Betrag und Knopf unter dem
Namen.

**Daten.** `tripProvider(tripId)` (neu, lokal zuerst, aus `historyFeedProvider` oder einzeln geladen), `tripSplitsProvider(tripId)`
(heute `FutureProvider.autoDispose`, künftig lokal zuerst und mit Modus, Zahler und Reihenfolge), `itemsNotifierProvider(targetListId)`
(A, für „Steht auf …“), `listsNotifierProvider` (A, Ziel-Listen), `ExpenseSplitService.setPaid` (wirft heute, künftig über die
Warteschlange mit Zurückrollen), `ItemRepository.addItems`/`undoAddItems` (A), Preis-Schnappschuss pro Artikel
(`ShoppingHistoryItem.price`, `priceRetailer`, `priceOldValue`; Grundpreis fehlt, Lücke L4), `offersAvailableProvider`,
`regionProvider`, `moduleEnabledProvider(AppModule.costSplit)`, `share_plus` (vorhanden) für „Erinnern“.

**Avo.** Keine Figur (Geld).

---

### V6 Betrag `/history/:tripId/amount`

**Zweck.** Den Gesamtbetrag eines Einkaufs eintragen, ändern oder entfernen. Ersetzt das konzeptionelle „Betrag-Sheet“.

**Route.** V (Kind von `':tripId'` mit `parentNavigatorKey: rootNavigatorKey`), Vollbild über der Tab-Leiste. Nur der
Einkäufer kommt hierher; ein Deep Link eines anderen Mitglieds zeigt V5 mit dem Hinweis „Nur Lena kann den Betrag
ändern.“ (`AvoToast` ohne Aktion).

**Aufbau.** `FullScreenEditor` von A (S2b, Anfrage A-V20):

1. Toolbar: links `xmark` „Schließen“; Mitte Inline-Titel „Betrag“; rechts getönter Primär-Kreis 44 `check` „Betrag
   speichern“, deaktiviert, solange der Wert ungültig oder unverändert ist.
2. Weiße Gruppe Radius 26, Innenabstand 16: Beschriftung „Gesamtbetrag“ 15/20 `secondaryLabel`, darunter `AmountField`
   groß (`numberXL`, linksbündig, höchstens 51 pt, Fokus beim Öffnen, Ziffernblock mit Komma). Fußnote unter der Gruppe:
   „Wocheneinkauf · ● Lidl · Sa., 7. Nov.“ (`StoreLabel` im Satz).
3. Nur wenn es eine Aufteilung gibt: Satz 15/20 `label` mit `exclamationmark.circle` 15 in `secondaryLabel` davor: „Die
   Anteile werden neu berechnet. Wer schon bezahlt hat und einen neuen Anteil bekommt, gilt wieder als offen.“ Bei
   individueller Aufteilung stattdessen: „Die Aufteilung ist individuell. Prüf die Anteile danach unter Kosten teilen.“
   (die Anteile bleiben, bis man sie in V7 anpasst; V5 zeigt dann „Noch 3,20 € zu verteilen“, siehe V7).
4. Ist das Feld leer und gab es vorher einen Betrag: Satz 15/20 `secondaryLabel` „Ohne Betrag zählt dieser Einkauf
   nicht zu deinen Ausgaben.“ Speichern entfernt dann den Betrag.

**Zustände.** Ungültig: Satz `hist_amount_invalid` unter dem Feld, Speichern aus. Ungewöhnlich hoch: `hist_amount_check`,
blockiert nicht. Offline: Speichern geht in die Warteschlange. Ungespeichert und „Schließen“: Dialog „Änderungen
verwerfen?“. Speichern scheitert später: Kopf in V5 zeigt den alten Betrag, Hinweis „Betrag nicht gespeichert“ mit
„Erneut versuchen“, Fehler-Haptik.

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_amount_title` | Betrag | Amount |
| `hist_amount_label` | Gesamtbetrag | Total |
| `hist_amount_save` | Betrag speichern | Save amount |
| `hist_trip_context` | {list} · {store} · {date} | {list} · {store} · {date} |
| `hist_amount_split_note` | Die Anteile werden neu berechnet. Wer schon bezahlt hat und einen neuen Anteil bekommt, gilt wieder als offen. | The shares will be recalculated. Anyone who already paid and gets a new share counts as open again. |
| `hist_amount_split_custom_note` | Die Aufteilung ist individuell. Prüf die Anteile danach unter Kosten teilen. | The split is custom. Check the shares under Split costs afterwards. |
| `hist_amount_clear_note` | Ohne Betrag zählt dieser Einkauf nicht zu deinen Ausgaben. | Without an amount, this trip isn't counted in your spending. |
| `hist_amount_saved` | Betrag gespeichert | Amount saved |
| `hist_amount_save_failed` | Betrag nicht gespeichert | Amount not saved |
| `hist_amount_not_yours` | Nur {name} kann den Betrag ändern. | Only {name} can change the amount. |

**Interaktion.** Speichern schließt V6 sofort, Hinweis „Betrag gespeichert“ mit „Widerrufen“, Ziffern rollen in V5 und
V4, keine Haptik. Ziehen im Inhalt schließt die Tastatur nicht (ein Feld, es soll offen bleiben).

**Barrierefreiheit.** Feld: „Gesamtbetrag, 42,80 Euro. Textfeld.“ / „Total, 42 euros 80. Text field.“ Der Hinweis zur
Aufteilung folgt dem Feld in der Fokus-Reihenfolge. Speichern deaktiviert: „Betrag speichern, gedimmt“. Große Schrift:
Feld wächst bis 51 pt, darüber bricht die Zahl nicht um, sondern das Feld scrollt waagerecht in sich.

**Daten.** `tripProvider(tripId)`, `tripSplitsProvider(tripId)`, Schreiben `ShoppingHistoryService.updateTotalCost`
(neu, mit `total_cost_source = user`, Lücke L2) über die Warteschlange; Neuberechnung gleicher Anteile serverseitig in
derselben Transaktion (Lücke L6).

**Avo.** Keine.

---

### V7 Kosten teilen `/history/:tripId/split`

**Zweck.** Wer bekommt wie viel von diesem Einkauf? Gleich oder individuell, mit Mitgliedern und Personen ohne Konto.

**Route.** V (Kind von `':tripId'` mit `parentNavigatorKey: rootNavigatorKey`), Vollbild über der Tab-Leiste. Wächter:
Modul Kosten teilen (V13). Parameter `amount=` (Cent, aus V1) und `from=checkout`. Ersetzt `split_cost_sheet.dart`
(Material-Sheet ohne Scroll, Serifen, Kicker, `Checkbox`, `OutlineInputBorder`, Betrag mit „€ “ davor und fester Breite
84, `ElevatedButton`, unsichtbar bei Fehler, Seiteneffekt im Build). Neue Datei `screens/history/split_editor_screen.dart`.

**Aufbau.** `FullScreenEditor` von A:

1. Toolbar: links `xmark` „Schließen“; Mitte Inline-Titel „Kosten teilen“; rechts getönter Primär-Kreis 44 `check`
   „Aufteilung speichern“, deaktiviert, bis alles gültig ist (der Grund steht immer sichtbar im Summen-Fuß).
2. Weiße Gruppe Radius 26, Innenabstand 16: „Gesamtbetrag“ 15/20 `secondaryLabel`, darunter `AmountField` groß
   (`numberXL`, linksbündig). Fußnote: „Wocheneinkauf · ● Lidl · Sa., 7. Nov.“ Unter dem Feld, falls leer oder 0: Satz
   13/18 mit `exclamationmark.circle` in `secondaryLabel` „Gib den Betrag ein.“
3. Gruppe mit einer Zeile „Bezahlt von“ (Zeile mit Wert und Pull-down, Anfrage A-V6): Titel links, Wert „Du“ 17/22
   `secondaryLabel` mit `chevron.up.chevron.down` 13 rechts. Menü: alle Teilnehmer, der aktuelle mit Häkchen.
4. `AppSegmentedControl` „Gleich“ | „Individuell“, volle Breite, 16 pt Rand, 24 pt Abstand nach oben und unten.
5. `SectionCaps` „WER TEILT?“ mit Zahl rechts („2“), Gruppe aus `SplitParticipantRow`s (mindestens 60 hoch):
   - links Auswahl-Kreis 22 in 44-pt-Ziel (`SelectCircle`, Anfrage A-V2): gewählt `checkmark.circle.fill` in `tint`, sonst
     Ring 1,6 pt in `uncheckedRing`. Bewusst anders als der Abhak-Kreis der Liste.
   - `Avatar` 28, Name 17/22, Unterzeile 15/20 `secondaryLabel` „hat bezahlt“ beim Zahler, „ohne Konto“ bei
     Namens-Personen, sonst keine.
   - rechts bei „Gleich“: Anteil 17/22 tabellarisch (`RollingNumber`); nicht gewählte Personen ohne Betrag. Bei
     „Individuell“: `AmountField` kompakt als Kapsel auf `fill` (wächst mit dem Inhalt, mindestens 88 pt breit, 44 hoch),
     Text in `label`.
6. Letzte Zeile der Gruppe: `person.badge.plus` 20 in `tint`, „Person hinzufügen“ 17/22 in `tint`. Tippen macht daraus eine
   neue Zeile mit Textfeld „Name“ (Fokus, Tastatur mit Großschreibung); Return übernimmt, leeres Return verwirft. Doppelter
   Name: Satz 13/18 in `label` mit `exclamationmark.circle` in #D70015 unter dem Feld „Lena ist schon dabei.“ (Feld
   bleibt offen).
7. Summen-Fuß 13/18 unter der Gruppe, in dieser Reihenfolge der Gründe:
   - kein Betrag: „Gib den Betrag ein.“
   - weniger als 2 gewählt: „Wähl mindestens zwei Personen aus.“
   - gleich, glatt teilbar: „Je 21,40 €.“ (`label`)
   - gleich mit Rest: „13,34 € und 2 × 13,33 €. Der Restcent geht an die erste Person.“
   - individuell, stimmt: „Verteilt: 42,80 € von 42,80 €“ (`label`)
   - individuell, zu wenig: `exclamationmark.circle` in `secondaryLabel` plus „Noch 3,20 € zu verteilen“ (Symbol plus
     Text, nie nur Farbe; behebt Bug 2)
   - individuell, zu viel: gleiches Symbol plus „1,20 € mehr verteilt als der Gesamtbetrag“
   - darunter, falls zutreffend, eine Zeile je betroffener Person: „Der Anteil von Lena ändert sich. Er gilt danach
     wieder als offen.“ (vor dem Speichern sichtbar, kein Dialog, K12-10)
8. Unterer Abstand bis über die Tastatur; der Screen scrollt immer (behebt den Überlauf ab 4 Teilnehmern mit Tastatur).

**Anfangswerte.**

| Fall | Teilnehmer | Zahler | Betrag | Modus |
|---|---|---|---|---|
| Neu aus V1 | alle Mitglieder der Liste plus du, du oben | Einkäufer | aus V1 (`amount=`); leer, wenn keiner eingegeben wurde (Feld fokussiert) | Gleich |
| Neu aus V5 oder Hinweis | wie oben | Einkäufer | Betrag des Einkaufs, sonst leer und fokussiert | Gleich |
| Bearbeiten | alle gespeicherten Teilnehmer inklusive Namens-Personen in gespeicherter Reihenfolge, individuelle Beträge, Modus, Zahler (behebt Bug 1) | gespeichert | gespeichert | gespeichert |
| Liste nur mit dir (Altdaten, nachträglich) | du und „Person hinzufügen“ | du | wie oben | Gleich |

Bezahlt-Status bleibt für jede Person, deren Anteil gleich bleibt.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Mitglieder laden mit lokalem Stand | sofort, kein Spinner; nie wird nachträglich über schon gesetzte Werte eingefügt |
| Mitglieder laden ohne Stand | zwei Platzhalter-Zeilen in `fill` unter „du“ |
| Mitglieder laden nicht | Gruppe zeigt dich und „Person hinzufügen“, darüber `StatusRow(kind: failed)` „Die Mitglieder konnten nicht geladen werden.“ mit „Erneut versuchen“ (heute bleibt das Sheet leer, Bug 15) |
| Speichern | optimistisch, V7 schließt sofort; Hinweis „Aufteilung gespeichert“ mit „Widerrufen“ (stellt die vorige Aufteilung inklusive Bezahlt-Status wieder her). Keine Erfolgs-Haptik, keine Figur. Aus V1 kommend: kein eigener Hinweis, der Hinweis aus V3 nimmt beides zurück |
| Speichern scheitert | Hinweis wird „Aufteilung nicht gespeichert“ mit „Erneut versuchen“, Fehler-Haptik; V5 zeigt den alten Stand |
| Offline | Speichern in die Warteschlange, Mitteilungen beim Abgleich (nach Ablauf des Hinweises) |
| Ungespeichert und „Schließen“ oder Zurück-Wischen | Zurück-Wischen gesperrt; „Schließen“ fragt „Änderungen verwerfen?“. Aus V1 kommend heißt Schließen ohne Speichern: Einkauf ist gespeichert, nicht geteilt |
| Modul aus | Route zeigt zuerst den Dialog V13 |
| Pro (falls) | V7 öffnet erst nach dem Kauf; Auslöser ist die Zeile oder der Schalter, der `ProGate.run` aufruft |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_split_title` | Kosten teilen | Split costs |
| `hist_split_save` | Aufteilung speichern | Save split |
| `hist_split_total` | Gesamtbetrag | Total |
| `hist_split_paid_by` | Bezahlt von | Paid by |
| `hist_split_you` | Du | You |
| `hist_split_mode` | Aufteilen | Split |
| `hist_split_equal` | Gleich | Equal |
| `hist_split_custom` | Individuell | Custom |
| `hist_split_who` | Wer teilt? | Who's sharing? |
| `hist_split_has_paid` | hat bezahlt | paid |
| `hist_split_add_person` | Person hinzufügen | Add person |
| `hist_split_name_placeholder` | Name | Name |
| `hist_split_name_taken` | {name} ist schon dabei. | {name} is already included. |
| `hist_split_remove` | Entfernen | Remove |
| `hist_split_need_amount` | Gib den Betrag ein. | Enter the total. |
| `hist_split_need_two` | Wähl mindestens zwei Personen aus. | Choose at least two people. |
| `hist_split_each` | Je {amount}. | {amount} each. |
| `hist_split_remainder` | {first} und {n} × {rest}. Der Restcent geht an die erste Person. | {first} and {n} × {rest}. The extra cent goes to the first person. |
| `hist_split_assigned` | Verteilt: {assigned} von {total} | Assigned: {assigned} of {total} |
| `hist_split_left` | Noch {amount} zu verteilen | {amount} left to assign |
| `hist_split_over` | {amount} mehr verteilt als der Gesamtbetrag | {amount} more than the total assigned |
| `hist_split_paid_changes` | Der Anteil von {name} ändert sich. Er gilt danach wieder als offen. | {name}'s share changes. It will count as open again. |
| `hist_split_members_failed` | Die Mitglieder konnten nicht geladen werden. | Couldn't load the members. |
| `hist_split_saved` | Aufteilung gespeichert | Split saved |
| `hist_split_save_failed` | Aufteilung nicht gespeichert | Split not saved |

**Interaktion.**

- Betrag tippen: Anteile rollen live (`RollingNumber`), ganze Cent mit exakter Summe.
- Kreis antippen (oder die ganze Zeile außer dem Betragsfeld): Person an oder aus, `AvoMotion.quick`, Anteile rollen,
  keine Haptik. Der Zahler lässt sich abwählen (er zahlte, teilt aber nicht mit).
- Segment wechseln: tippen ohne Haptik; den Daumen ziehen mit Auswahl-Haptik pro Segment (A-Baustein). Wechsel von
  „Gleich“ zu „Individuell“ übernimmt die gleichen Anteile als Startwerte; zurück zu „Gleich“ verwirft individuelle
  Werte erst beim Speichern (bis dahin kommen sie beim Zurückwechseln wieder).
- Namens-Person: Wischen nach links „Entfernen“ (destruktiv, mit Rückgängig-Hinweis im Editor). Mitglieder lassen sich
  nur abwählen, nicht entfernen.
- Speichern: V7 schließt (Push rückwärts), danach Hinweis. Mitteilung an die Mitglieder („Jannis hat den Einkauf geteilt:
  dein Anteil 21,40 €.“) nach Ablauf des Hinweises.

**Barrierefreiheit.**

| Element | Vorgelesen (Deutsch) | English |
|---|---|---|
| Gesamtbetrag | Gesamtbetrag, 42,80 Euro. Textfeld. Wocheneinkauf, Lidl, 7. November. | Total, 42 euros 80. Text field. Weekly shop, Lidl, November 7. |
| Bezahlt von | Bezahlt von, Du. Taste. Öffnet ein Menü. | Paid by, You. Button. Opens a menu. |
| Segment | Gleich, ausgewählt, 1 von 2 | Equal, selected, 1 of 2 |
| Teilnehmer (gleich) | Lena, teilt mit, 21,40 Euro. Taste. | Lena, sharing, 21 euros 40. Button. |
| Teilnehmer abgewählt | Tom, ohne Konto, teilt nicht mit. Taste. | Tom, no account, not sharing. Button. |
| Teilnehmer (individuell) | Lena, teilt mit. Anteil, 21,40 Euro, Textfeld. | Lena, sharing. Share, 21 euros 40, text field. |
| Summen-Fuß (Live-Region) | Noch 3,20 Euro zu verteilen. | 3 euros 20 left to assign. |
| Speichern deaktiviert | Aufteilung speichern, gedimmt. Noch 3,20 Euro zu verteilen. | Save split, dimmed. 3 euros 20 left to assign. |

Der Auswahl-Kreis ist ein Schalter mit Zustand („teilt mit“ / „teilt nicht mit“), kein Häkchen „erledigt“. Fokus nach dem
Hinzufügen einer Person: auf der neuen Zeile. Fokus-Reihenfolge: Schließen, Titel, Speichern, Gesamtbetrag, Fußnote,
Bezahlt von, Segment, „Wer teilt?“, Teilnehmer, Person hinzufügen, Summen-Fuß.

Große Schrift: ab xxL wird das Segment ein Pull-down „Aufteilen: Gleich“ (A-Baustein). Ab AX1 stapeln die Zeilen:
Name oben, Anteil bzw. Feld volle Breite darunter, Avatar entfällt. Bei 320 pt und L bleibt das Feld rechts, solange der
Name mindestens 100 pt Platz behält (gemessen), sonst darunter.

**Daten.** `tripProvider(tripId)`, `splitCandidateMembersProvider(listId)` (lokal zuerst, Lücke L7),
`tripSplitsProvider(tripId)`, reine Funktion `splitEqually(totalCents, participants)` (Cent-genau, Restcent an Position
0) und `validateCustomSplit(...)`, Schreiben über `ExpenseSplitService.saveSplit` (neu: ersetzt `createSplits`, das heute
erst einfügt und dann löscht; atomar per RPC mit `split_mode`, `paid_by`, `position`, Bezahlt-Status erhalten; Lücke L5).

**Avo.** Keine (Geld).

---

### V8 Offene Beträge `/splits`

**Zweck.** Wer schuldet wem? Jede offene Schuld einzeln begleichen.

**Route.** B (`historyBranchRoutes[AppBranch.lists]`), Push im Listen-Tab, Tab-Leiste sichtbar. Wächter Modul Kosten
teilen. Neue Datei `screens/history/open_balances_screen.dart`. Ersetzt `PendingSplitsBanner` (eine Zeile pro Schuld
ohne Obergrenze auf der Startseite, Terrakotta, Material-Pfeile, Schnellaktion 15 pt hoch, ohne Rückgängig, „Du schuldest
Wocheneinkauf 3.20 €“ bei fehlendem Namen).

**Aufbau.**

1. Toolbar: „Zurück“ links, sonst nichts.
2. Großer Titel „Offene Beträge“ (E-06, Anfrage A-V21).
3. `StatusRow` bei Bedarf.
4. `SectionCaps` „SCHULDET DIR“ mit der Summe rechts 13/18 tabellarisch („34,60 €“), Gruppe aus `BalanceRow`s
   (mindestens 64 hoch, Innenrand 10 × 16, Abstand 12): `Avatar` 40, Name 17/22 Semibold, Unterzeile 15/20
   `secondaryLabel` „Wocheneinkauf · ● Lidl · Heute“ (bei Namens-Personen „· ohne Konto“); rechts Betrag 17/22 Semibold
   tabellarisch und darunter Text-Knopf „Bezahlt“ 15/20 600 `tint` (44-pt-Ziel). Trenner ab 68 pt.
5. `SectionCaps` „DU SCHULDEST“ mit Summe („11,58 €“), gleiche Zeilen, Knopf „Zurückgezahlt“.
6. Kopfzeile „Erledigt (1)“ als Taste 17/22 mit Chevron, der sich beim Aufklappen dreht; eingeklappt beim ersten Öffnen,
   Zustand gemerkt. Aufgeklappt: Gruppe mit den beglichenen Anteilen der letzten 30 Tage, Unterzeile „bezahlt am
   2. Nov.“, ohne Knopf.
7. Unterer Abstand `ShellInsets.bottom`.

Pro Anteil eine Zeile (Einkauf × Person), nicht pro Person summiert und nie verrechnet (K12-09).

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Leer (nichts offen, nichts erledigt) | `EmptyState` ohne Figur (Geld): Symbol `checkmark.circle` 48 Light, „Alles beglichen.“, „Offene Beträge erscheinen hier, wenn du einen Einkauf teilst.“, Aktion „Zum Verlauf“ |
| Nichts offen, aber Erledigtes | Satz 17/22 „Alles beglichen.“ an Stelle der beiden Abschnitte, „Erledigt“ bleibt |
| Nur eine Richtung offen | die andere Sektion entfällt ohne Lücke |
| Altdaten, in denen der Anteil des Zahlers als offen gespeichert ist | nie als Schuld gezeigt (heutige Filterregel aus `pending_splits_banner.dart:34-38` bleibt) |
| Name fehlt | „Ein Mitglied“ als Titel (behebt Bug 10) |
| Lädt | lokal zuerst; ohne Stand `SkeletonSection(rows: 3, withImage: true)` |
| Fehler mit Stand | `StatusRow(kind: failed)` „Die offenen Beträge konnten nicht aktualisiert werden.“ mit „Erneut versuchen“ |
| Fehler ohne Stand | Symbol `exclamationmark.circle` 48 Light, „Die offenen Beträge konnten nicht geladen werden.“, „Erneut versuchen“ |
| Offline | `common_offline`; „Bezahlt“ wirkt sofort lokal, Sync-Zeichen an der Zeile |
| „Bezahlt“ scheitert | Zeile wandert zurück, Zeilen-`StatusRow` „Nicht gespeichert.“ mit „Erneut versuchen“, Fehler-Haptik |
| Modul aus | Route zeigt zuerst den Dialog V13; die Zeile in der Listen-Übersicht fehlt |
| Pro | nicht vorgesehen (Kosten teilen ganz oder gar nicht) |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_balances_title` | Offene Beträge | Open balances |
| `hist_balances_owed_to_you` | Schuldet dir | Owed to you |
| `hist_balances_you_owe` | Du schuldest | You owe |
| `hist_balances_done` | Erledigt ({n}) | Settled ({n}) |
| `hist_balance_sub` | {list} · {store} · {date} | {list} · {store} · {date} |
| `hist_member_unknown` | Ein Mitglied | A member |
| `hist_balances_all_settled` | Alles beglichen. | All settled. |
| `hist_balances_empty_body` | Offene Beträge erscheinen hier, wenn du einen Einkauf teilst. | Open balances show up here when you split a trip. |
| `hist_balances_refresh_failed` | Die offenen Beträge konnten nicht aktualisiert werden. | Couldn't refresh your open balances. |
| `hist_balances_load_failed` | Die offenen Beträge konnten nicht geladen werden. | Couldn't load your open balances. |
| `hist_balance_view_trip` | Einkauf ansehen | View trip |
| `hist_split_mark_paid_long` | Als bezahlt markieren | Mark as paid |

**Interaktion.**

- „Bezahlt“ bzw. „Zurückgezahlt“ oder Wischen nach links mit derselben Aktion (`tint`, leichter Impuls an der Schwelle,
  volles Wischen löst aus): Die Zeile wandert mit `AvoMotion.move` nach „Erledigt“ (klappt „Erledigt“ dafür nicht auf;
  die Zahl in „Erledigt (2)“ rollt), die Summe im Kopf rollt, Hinweis „Lena: bezahlt“ mit „Widerrufen“. Keine Haptik.
- Tippen auf die Zeile: V5 des Einkaufs.
- Langdruck: „Als bezahlt markieren“ bzw. „Zurückgezahlt“, „Erinnern“ (nur in „Schuldet dir“, System-Teilen),
  „Einkauf ansehen“; in „Erledigt“: „Wieder als offen markieren“, „Einkauf ansehen“.
- Ziehen nach unten aktualisiert.

**Barrierefreiheit.**

| Element | Vorgelesen (Deutsch) | English |
|---|---|---|
| Abschnittskopf | Schuldet dir, 34,60 Euro, Überschrift | Owed to you, 34 euros 60, heading |
| Zeile | Lena schuldet dir 21,40 Euro, Wocheneinkauf, Lidl, heute. Aktionen: Als bezahlt markieren, Erinnern, Einkauf ansehen | Lena owes you 21 euros 40, Weekly shop, Lidl, today. Actions: Mark as paid, Remind, View trip |
| Zeile „Du schuldest“ | Du schuldest Lena 11,58 Euro, Wocheneinkauf, REWE, Mittwoch, 4. November. Aktionen: Zurückgezahlt, Einkauf ansehen | You owe Lena 11 euros 58, Weekly shop, REWE, Wednesday, November 4. Actions: Paid back, View trip |
| „Erledigt (1)“ | Erledigt, 1 Eintrag, eingeklappt. Taste. | Settled, 1 item, collapsed. Button. |

Nach „Bezahlt“ Ansage „Lena: bezahlt. Schuldet dir jetzt 13,20 Euro.“ / „Lena: paid. You're now owed 13 euros 20.“
Der Fokus geht auf die nächste Zeile derselben Sektion, sonst auf den Abschnittskopf. Große Schrift: ab AX1 Summe im
Kopf unter dem Titel, Avatar entfällt, Betrag und Knopf unter dem Text.

**Daten.** Neu `openBalancesProvider` (eine Abfrage nur offener Anteile serverseitig statt aller bezahlten Einkäufe wie
heute `getTripsAwaitingPaymentToMe`/`getTripsIOwe`; lokal zuerst; liefert auch die Summen für A's Zeile in der
Listen-Übersicht als synchronen `openBalancesSummaryProvider`), `ExpenseSplitService.setPaid` über die Warteschlange,
erledigte Anteile der letzten 30 Tage.

**Avo.** Keine (Geld).

---

### V9 Home „Dein November“ (`HomeMonthCard`)

**Zweck.** Wie steht der laufende Monat? Drei ehrliche Zahlen auf einen Blick, Tippen führt in den Verlauf.

**Ort.** Slot auf Home (A ordnet, D2-FuerDich §3), Datei `lib/presentation/widgets/home_sections/` (B), über
`b_slots.dart` exportiert. Außen ohne Rand (A setzt 16 pt Rand und 24 pt Abstand). `homeMonthHasContentProvider` ist
synchron und true, sobald im laufenden Monat mindestens ein Einkauf gespeichert ist.

**Aufbau (D2).** Karte Radius 26, Innenabstand 20 × 16, Fläche Verlauf 135° von #EEF7EF zu #FFFFFF bei 70 %, Schatten
`0 1px 2px rgba(0,0,0,.04)`. Die ganze Karte ist eine Taste.

1. „Dein November“ 22/28 Bold (`title2`), darunter 15/20 `secondaryLabel` „Bis heute, Sa., 7. Nov.“
2. 16 pt darunter drei gleich breite Spalten, getrennt durch 0,5 pt rgba(60,60,67,.18): Symbol 22 in #3A3A3C,
   8 pt darunter Wert 20/25 Bold tabellarisch, darunter Bezeichnung 13/18 `secondaryLabel`.
   - „183,40 €“ · „Ausgaben“ (Symbol `cart`, D2); haben nicht alle Einkäufe einen Betrag: „Ausgaben aus 4 von 6“ (bricht
     in 2 Zeilen um, alle Bezeichnungen oben bündig). Gibt es im Monat noch gar keinen Betrag, entfällt die Spalte und
     die übrigen zwei teilen sich die Breite.
   - „6“ · „Einkäufe“ (Symbol Tasche, D2).
   - „58“ · „Artikel“ (Symbol Liste, Anfrage A-V16).
3. Nur mit Angebote, echter Region, Schalter „Ersparnis im Verlauf und nach dem Einkauf“ und mindestens 0,50 €: 12 pt
   darunter eine Zeile mit `tag` 18 in `tint` und 15/20 `label` „Ca. 18,60 € durch Angebote gespart, laut Händler“.
   Das ersetzt die grüne D2-Spalte „Gespart“ (Abschnitt 5, Konflikt 3).

**Zustände.** Kein Einkauf im Monat: `HasContent` false, A blendet die Karte aus (am 1. eines Monats verschwindet sie
also bis zum ersten Einkauf; kein „0 €“). Offline: zeigt den Schnappschuss, kein Hinweis (Home zeigt den Status oben,
A). Modul Angebote aus, Kill-Switch, ohne Region: Zeile 3 entfällt. Pro: nie gesperrt.

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_home_month_title` | Dein {month} | Your {month} |
| `hist_home_month_sub` | Bis heute, {date} | So far, up to {date} |
| `hist_stat_spend_partial` | Ausgaben aus {n} von {m} | Spending from {n} of {m} |

**Barrierefreiheit.** Ein Element, Taste: „Dein November, bis heute. Ausgaben 183,40 Euro aus 4 von 6 Einkäufen, 6
Einkäufe, 58 Artikel, circa 18,60 Euro durch Angebote gespart, laut Händler. Öffnet den Verlauf.“ / „Your November so
far. Spending 183 euros 40 from 4 of 6 trips, 6 trips, 58 items, about 18 euros 60 saved through offers, according to
the retailer. Opens history.“ Symbole ausgeblendet. Große Schrift: bis xL drei Spalten; ab xxL und bei 320 pt ab xL die
Spalten als Zeilen (Bezeichnung links, Wert rechts, Symbol entfällt); ab AX1 Wert unter der Bezeichnung.

**Daten.** `homeHistorySnapshotProvider` (synchron, aus dem Schnappschuss) mit `summarizeMonth` für den laufenden Monat.

**Avo.** Keine (Geld; Home hat die Avo-Karte darüber).

---

### V10 Home „Ausgaben im Vergleich“ (`HomeSpendingComparison`)

**Zweck.** Wie entwickeln sich meine Ausgaben über sechs Monate?

**Ort.** Slot auf Home (D2-FuerDich §4). `homeSpendingHasContentProvider` true, wenn in mindestens 3 der letzten 6
Monate Beträge erfasst sind (sonst gäbe es keine ehrliche Reihe; die Karte entfällt).

**Aufbau (D2).** Weiße Karte Radius 26, Innenabstand 16.

1. Kopfzeile als Taste (mindestens 44 hoch): „Ausgaben im Vergleich“ 17/22 Semibold, rechts Chevron 8 × 14 #8E8E93.
   Öffnet V4.
2. 2 pt darunter, 13/18 `secondaryLabel`, nur wenn der letzte abgeschlossene Monat und sein Vormonat je mindestens 80 %
   der Einkäufe mit Betrag haben: „Oktober: 10,80 € weniger als im September“, der Betrag in `tint` 600 bei weniger, in
   `label` 600 bei mehr, davor bei weniger der D2-Pfeil nach unten 14 in `tint` (bei mehr kein Pfeil, kein Rot). Sonst
   entfällt die Zeile. Nie ein Vergleich des laufenden Monats und nie in Prozent (Abschnitt 5, Konflikt 4).
3. 16 pt darunter `SpendingBars` wie in V4 (gleiche Komponente, gleiche Maße, ohne Auswahl): der laufende Monat ist
   hervorgehoben (#34A853, Wert #1F7A3A 600, Kürzel #1C1C1E 600, Zusatzzeile „bisher“). Werte gerundet auf ganze Euro
   („212 €“), wie D2. Monate ohne Betrag ohne Balken.

**Zustände.** Offline: Schnappschuss. Modul aus: keines betrifft die Karte. Pro: falls „Statistiken“ Pro werden, bleibt
die Home-Karte frei (sie zeigt nur, was ohnehin im Verlauf frei wäre, plus Vormonate als Vorschau); Owner-Frage 6.

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_home_spend_title` | Ausgaben im Vergleich | Spending compared |
| `hist_home_spend_less` | {month}: {amount} weniger als im {prev} | {month}: {amount} less than in {prev} |
| `hist_home_spend_more` | {month}: {amount} mehr als im {prev} | {month}: {amount} more than in {prev} |
| `hist_home_spend_same` | {month}: etwa so viel wie im {prev} | {month}: about the same as in {prev} |

**Barrierefreiheit.** Kopfzeile: „Ausgaben im Vergleich. Taste. Öffnet den Verlauf.“ Diagramm ein Element (Bild):
„Ausgaben pro Monat: Juni 212 Euro, Juli 198 Euro, August 201 Euro, September 236 Euro, Oktober 208 Euro, November bisher
183 Euro.“ (wie das D2-`aria-label`). Vergleichszeile als eigener Text. Große Schrift wie 3.9.

**Daten.** `homeHistorySnapshotProvider`.

**Avo.** Keine.

---

### V11 Home „Letzte Einkäufe“ (`HomeRecentTrips`)

**Zweck.** Die letzten drei Einkäufe mit Markt, Datum und Betrag; Einstieg in Verlauf und Detail.

**Ort.** Slot auf Home (D2-FuerDich §9). `homeRecentTripsHasContentProvider` true ab einem gespeicherten Einkauf.

**Aufbau (D2).**

1. Abschnittskopf (`.sec-h`): „Letzte Einkäufe“ 20/25 Semibold links, rechts Text-Knopf „Alle anzeigen“ 15/20 `tint`
   (44-pt-Ziel). Öffnet V4.
2. 8 pt darunter weiße Karte Radius 26 mit höchstens 3 `TripRow`s Variante `compact`: `StoreBadge` 40, Titel Markt
   17/22 Semibold (ohne Markt: Listenname), Unterzeile 15/20 nur das Datum („Mo., 2. Nov.“), bei Einkäufen aus mehr als
   einer Liste „Mo., 2. Nov. · Grillabend“; rechts Betrag 17/22 Semibold, darunter mit Angebote „ca. 3,20 € gespart“
   13/18 600 `tint` (statt D2 „−3,20 €“); Chevron; Trenner ab 68 pt. Keine Schuld-Unterzeile (gehört zu V12).
3. Nur wenn eine Zeile eine Ersparnis zeigt: Fußnote 13/18 `secondaryLabel` unter der Karte „Ersparnis laut Händler, auf
   10 Cent gerundet.“

**Interaktion.** Zeile tippen: V5 (wechselt in den Listen-Tab, Anfrage A-V14). Kein Wischen, kein Kontextmenü auf Home
(die Aktionen liegen im Verlauf).

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_home_recent_title` | Letzte Einkäufe | Recent trips |
| `hist_home_recent_all` | Alle anzeigen | See all |
| `hist_home_recent_note` | Ersparnis laut Händler, auf 10 Cent gerundet. | Savings as stated by the retailer, rounded to 10 cents. |

**Barrierefreiheit.** Kopf als Überschrift; Zeile wie `TripRow` in V4 ohne Aktionen: „Lidl, Montag, 2. November, 42,30
Euro, circa 3,20 Euro durch Angebote gespart, laut Händler. Öffnet den Einkauf.“ Große Schrift wie V4.

**Daten.** `homeHistorySnapshotProvider` (die letzten 3 Einkäufe).

**Avo.** Keine.

---

### V12 Hinweise zum Kosten teilen (`HomeSplitHint`)

**Zweck.** Zur richtigen Zeit an Teilen und offene Beträge erinnern, ohne Banner und ohne Liste von Schulden auf Home.

**Ort.** Neuer Slot `HomeSplitHint()` mit `homeSplitHintHasContentProvider` (synchron), B liefert ihn in
`home_sections`, A ordnet ihn ein (Anfrage A-V13; Vorschlag: direkt unter der Avo-Karte, weil Geld zeitkritisch ist). Er
zeigt genau einen `HintRow` (A-Baustein: weiße Karte Radius 20, 15/20, Symbol links, Aktion als Link, Schließen oben
rechts mit 44-pt-Ziel). Welche Zeile erscheint, steht beim ersten Frame aus dem Schnappschuss fest; neue erst beim
nächsten Öffnen. Leading-Symbol `eurosign.circle` 20 in `secondaryLabel`, nie eine Figur.

| Hinweis | Text | Aktion (Karte antippen) | Bedingung | Modul |
|---|---|---|---|---|
| Einkauf teilen | „Wocheneinkauf mit Lena teilen? 42,80 €“; ohne Betrag „Wocheneinkauf von heute mit Lena teilen?“ | „Teilen“ → V7 | eigener oder fremder Einkauf der letzten 7 Tage auf einer geteilten Liste, noch nicht geteilt, nicht weggewischt (pro Einkauf im Konto gemerkt; behebt Bug 12) | Kosten teilen |
| Ein offener Betrag | „Lena schuldet dir 21,40 € · Wocheneinkauf“ bzw. „Du schuldest Lena 11,58 € · Wocheneinkauf“ | „Als bezahlt markieren“ bzw. „Als zurückgezahlt markieren“, sofort, mit Rückgängig-Hinweis | genau ein offener Anteil | Kosten teilen |
| Mehrere offene Beträge | „3 offene Beträge · dir werden 34,60 € geschuldet, du schuldest 11,58 €“ (fehlt eine Richtung, entfällt ihr Teil) | „Ansehen“ → V8 | mehr als ein offener Anteil | Kosten teilen |
| Kosten teilen einschalten | „Kosten teilen einschalten? Praktisch für gemeinsame Einkäufe.“ | „Einschalten“, Rückgängig-Hinweis „Kosten teilen ist an“ | einmalig nach dem ersten Teilen einer Liste, Modul aus | Kern |

Vorrang bei mehreren: offener Betrag (einer oder mehrere) vor „Einkauf teilen“ vor „Einschalten“. Schließen (`onDismiss`)
blendet „Einkauf teilen“ für diesen Einkauf aus, offene Beträge für 3 Tage, „Einschalten“ für immer; alles pro Konto
(Regel 15). „Bezahlt“ aus dem Hinweis: Karte verschwindet mit `AvoMotion.standard`, Hinweis „Lena: bezahlt“ mit
„Widerrufen“; bei Fehler kommt die Karte zurück mit „Nicht gespeichert. Erneut versuchen“ als Aktion, Fehler-Haptik.

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_hint_share` | {list} mit {names} teilen? {amount} | Split {list} with {names}? {amount} |
| `hist_hint_share_no_amount` | {list} von {day} mit {names} teilen? | Split {list} from {day} with {names}? |
| `hist_hint_share_action` | Teilen | Split |
| `hist_hint_owes_you` | {name} schuldet dir {amount} · {list} | {name} owes you {amount} · {list} |
| `hist_hint_you_owe` | Du schuldest {name} {amount} · {list} | You owe {name} {amount} · {list} |
| `hist_hint_mark_paid` | Als bezahlt markieren | Mark as paid |
| `hist_hint_mark_repaid` | Als zurückgezahlt markieren | Mark as paid back |
| `hist_hint_balances` | {n} offene Beträge · dir werden {in} geschuldet, du schuldest {out} | {n} open balances · you're owed {in}, you owe {out} |
| `hist_hint_balances_in` | {n} offene Beträge · dir werden {in} geschuldet | {n} open balances · you're owed {in} |
| `hist_hint_balances_out` | {n} offene Beträge · du schuldest {out} | {n} open balances · you owe {out} |
| `hist_hint_view` | Ansehen | View |
| `hist_hint_enable_split` | Kosten teilen einschalten? Praktisch für gemeinsame Einkäufe. | Turn on Split costs? Handy for shared shopping. |
| `hist_hint_enable_action` | Einschalten | Turn on |
| `hist_split_enabled_toast` | Kosten teilen ist an | Split costs is on |
| `hist_hint_dismiss` | Ausblenden | Hide |

**Barrierefreiheit.** Eine Taste mit dem ganzen Satz und der Aktion als Hinweis („Lena schuldet dir 21,40 Euro,
Wocheneinkauf. Doppeltippen markiert als bezahlt.“), dazu die Aktionen „Einkauf ansehen“ und „Ausblenden“. Große Schrift
macht `HintRow` selbst.

**Daten.** `homeSplitHintProvider` (neu, aus `openBalancesProvider` und `unsplitTripNudgeProvider`, dieser künftig auch
für fremde Einkäufe und mit Ausblenden pro Einkauf im Konto statt `SplitNudgeCacheService` gerätweit).

**Avo.** Keine.

---

### V13 Dialoge (zentriert, nie von unten)

**„Einkauf löschen?“** über `showAvoConfirm(context, title:, message:, confirmLabel:, destructive: true)` von A. Einziger
Bestätigungsdialog des Bereichs, nur für eigene Einkäufe. Auslöser: Wischen und Kontextmenü in `TripRow`, Menü in V5,
Avo (`AvoConfirmCard` mit demselben Text, siehe Abschnitt 5, Konflikt 13).

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_delete_title` | Einkauf vom {date} löschen? | Delete the trip from {date}? |
| `hist_delete_body_split` | Der Einkauf und seine Aufteilung werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen. | The trip and its split will be deleted for all members. This can't be undone. |
| `hist_delete_body_shared` | Der Einkauf wird für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen. | The trip will be deleted for all members. This can't be undone. |
| `hist_delete_body` | Der Einkauf verschwindet aus deinem Verlauf und dem Monatsrückblick. Das lässt sich nicht rückgängig machen. | The trip will be removed from your history and monthly review. This can't be undone. |
| `hist_delete_confirm` | Einkauf löschen | Delete trip |

„Abbrechen“ (`cancel`) ist der fette Standard links, „Einkauf löschen“ rot rechts. Danach schrumpft die Zeile weg, die
Monatswerte rollen, kein Rückgängig. Fehler: Zeile kommt zurück, Hinweis „Löschen hat nicht geklappt.“ mit „Erneut
versuchen“, Fehler-Haptik (behebt Bug 5). Offline: Löschen wartet in der Warteschlange, die Zeile bleibt bis dahin
gedimmt mit Sync-Zeichen.

**„Änderungen verwerfen?“** in V1, V6 und V7 bei „Schließen“ mit Änderungen: Alert mit `common_discard_changes_title`,
Knöpfe `common_discard` (rot) und `common_keep_editing` (fett, Standard). Kein Aktionsblatt von unten.

**„Kosten teilen ist ausgeschaltet“** vor `/splits` und `/history/:tripId/split`: `showModuleOffAlert(context,
moduleName: tr('common_module_cost_split'), onEnable:)`. Titel kommt aus `common_module_off_title`. Der allgemeine Text
„Schalte es ein, um das zu öffnen …“ sagt nicht, wozu; deshalb Anfrage A-V8 für einen eigenen Satz:

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_split_module_off_body` | Dann teilst du Einkäufe mit Mitgliedern und siehst, wer wem etwas schuldet. Deine Aufteilungen sind noch da. | Then you can split trips with members and see who owes whom. Your splits are still there. |

„Einschalten“ wirkt sofort (auch offline) und öffnet das Ziel; „Nicht jetzt“ bleibt.

**Kill-Switch Angebote.** In diesem Bereich gibt es keine Angebots-Route, also keinen Dialog. Nur Ersparnis-Elemente
verschwinden (3.14).

**Vorab-Erklärung Standort** (aus V1, vor der Systemabfrage): zentrierter Alert.

| Schlüssel | Deutsch | English |
|---|---|---|
| `hist_location_title` | Markt per Standort erkennen? | Find your store by location? |
| `hist_location_body` | {app} fragt beim Abschluss einmal deinen Standort ab und sucht Märkte in der Nähe über OpenStreetMap. Ausschalten kannst du das in den Einstellungen. | {app} checks your location once when you finish shopping and looks up nearby stores on OpenStreetMap. You can turn this off in Settings. |
| `hist_location_continue` | Weiter | Continue |

Knöpfe „Nicht jetzt“ (`common_not_now`) und „Weiter“ (Standard). Nach „Weiter“ kommt die Systemabfrage; nach einer
Ablehnung fragt V1 nie wieder (nur der einmalige Hinweis „In Einstellungen erlauben“).

---

### V14 Mitteilungen (Texte für Kapitel 19)

Gehen an Mitglieder der Liste, nie an den Auslöser und nie an Namens-Personen, lokalisiert in der Sprache des
Empfängers (nicht des Absenders), ohne Emoji und ohne Ausrufezeichen, erst nach Ablauf des Rückgängig-Hinweises
(K12-14), gebündelt nach Kapitel 19. Titel ist der Listenname. Tippen öffnet V5 (Anfrage A-V11). Ersetzt den englischen
Push „💶 Share settled“ mit Rückfall „Someone“ aus `expense_split_service.dart:148-202`.

| Schlüssel | Deutsch | English |
|---|---|---|
| `notif_trip_done` | {name} hat bei {store} eingekauft ({n, plural, =1{1 Artikel} other{# Artikel}}). | {name} shopped at {store} ({n, plural, =1{1 item} other{# items}}). |
| `notif_trip_done_no_store` | {name} hat eingekauft ({n, plural, =1{1 Artikel} other{# Artikel}}). | {name} went shopping ({n, plural, =1{1 item} other{# items}}). |
| `notif_split_created` | {name} hat den Einkauf geteilt: dein Anteil {amount}. | {name} split the trip: your share is {amount}. |
| `notif_split_changed` | {name} hat die Aufteilung geändert: dein Anteil {amount}. | {name} changed the split: your share is {amount}. |
| `notif_split_paid` | {name} hat deinen Anteil ({amount}) als bezahlt markiert. | {name} marked your share ({amount}) as paid. |
| `notif_split_reopened` | {name} hat deinen Anteil ({amount}) wieder als offen markiert. | {name} marked your share ({amount}) as open again. |

Fehlt der Name des Auslösers: „Ein Mitglied“ / „A member“ (`hist_member_unknown`), nie „Someone“.

---

### Avo in diesem Bereich

Avo führt dieselben Abläufe aus wie die Screens, mit derselben Rechnung: Verlauf lesen, Einkauf wiederholen
(`add_history_items_to_list`), Kosten teilen (`split_trip_cost`), „bezahlt“ (`set_split_paid`), Abschluss
(`complete_list`), Ersparnis (`get_savings_summary`, gleiche Funktion wie V4). Ergebniszeilen und Texte stehen in
`avo.md` Abschnitt 5.2; „Ansehen“ öffnet V4 bzw. V5. Löschen eines Einkaufs nur über die Rückfrage-Karte mit dem Text aus
V13. Avo vergleicht keine Märkte und nennt keinen „günstigsten Markt“. Im Verlauf erscheint keine Avo-Figur außer im
leeren Zustand.

---

## 5. Konflikte zwischen D2 und Konzept

Die Empfehlung gilt, bis der Owner entscheidet. D2 gewinnt beim Aussehen; bindend bleiben die Owner-Regeln, das Recht
(Recherche, Plan 8) und die Inhalte des Konzepts.

| Nr. | D2 | Konzept, Recht | Empfehlung |
|---|---|---|---|
| 1 | Markt als Buchstaben-Kachel in Markenfarben: im Einkaufsmodus gelbes „L“ auf Lidl-Blau, auf Home Pastell-Kachel mit farbigem Buchstaben | Markenpunkt plus Name, Logos nur mit Erlaubnis (F12-9, 00 4.8) | D2-Home-Stil (Pastellfläche, Buchstabe, `StoreBadge`), nie die Logo-nahe Kombination gelb auf blau. Wenn der Owner auch das zu nah am Logo findet: `StoreLabel` (Punkt plus Name) und als Kachel `cart` auf `fill` |
| 2 | „Letzte Einkäufe“: Titel = Markt, Unterzeile nur Datum | `TripRow`: Titel = Listenname, Unterzeile Markt · Datum · Anzahl | Titel = Markt wie D2, Listenname in der Unterzeile (V4), auf Home nur bei mehreren Listen. Ein Baustein für Home und Verlauf |
| 3 | „Dein November“ mit grüner Spalte „18,60 € Gespart“; „Letzte Einkäufe“ mit „−3,20 €“ in Grün | Ersparnis nur „ca.“ und „laut Händler“, nur mit Modul und echter Region (Plan 8, Regel 3 bis 5) | Ersparnis als eigener Satz „Ca. 18,60 € durch Angebote gespart, laut Händler“ unter den Spalten (passt nicht in eine 84-pt-Spalte), Spalten Ausgaben · Einkäufe · Artikel; in Zeilen „ca. 3,20 € gespart“ ohne Minus plus Fußnote. Ohne Modul fehlt nur der Satz, die Spalten bleiben gleich |
| 4 | „Ausgaben im Vergleich“: „−12 % zum Vormonat“ im laufenden Monat; laufender Monat grün ohne Kennzeichen | Vergleich nur in abgeschlossenen, gleich gut erfassten Monaten (je ≥ 80 % mit Betrag), in Euro; laufender Monat als „läuft noch“ gekennzeichnet, keine Prognose | Vergleichszeile nur für den letzten abgeschlossenen Monat in Euro; laufender Monat behält das D2-Grün und bekommt die Zeile „bisher“ unter dem Kürzel statt des gestrichelten Umrisses aus dem Konzept (der wirkt wie eine Prognose) |
| 5 | Balken grau #ECECF0 mit Werten darüber, gewählter Monat grün, Radius 10 | Balken in `label`, Radius 4, gestrichelt für den laufenden Monat | D2-Aussehen in Home und Verlauf (ein Baustein); Kontrast über die Wertebeschriftung, ohne sie dunklere Balken (3.7) |
| 6 | Knopf „Einkauf abschließen“ im Einkaufsmodus | Knopf „Einkauf beenden“, Screen „Einkauf abschließen“ (F12-12d) | überall „Einkauf abschließen“ (Knopf, Menü, Screen, leerer Verlauf); die Kapsel im Screen heißt „Einkauf speichern“ |
| 7 | kein Abschluss-Screen | Abschluss-Sheet mittel, `checkmark` oben rechts | Vollbild V1 (Owner-Regel), Hauptaktion als 54-pt-Kapsel unten an derselben Stelle wie der Knopf im Einkaufsmodus |
| 8 | kein Kosten-teilen-Screen, kein Betrag-Screen | Sheets „Kosten teilen“ und „Betrag“ | Vollbild-Editoren V7 und V6 mit getöntem Häkchen oben rechts (D2-Toolbar) |
| 9 | Home „Sparziel mit Avo 18,60 / 25 €“ | F12-8: kein Budget oder Sparziel in Version 1; Avo-Figur und „mit Avo“ bei Geld nicht erlaubt | nicht in Version 1; falls doch, ohne „mit Avo“, mit „ca.“ und nur mit Modul Angebote. Gehört nicht zu dieser Spezifikation |
| 10 | Kosten teilen erscheint im Home-Artboard nicht | Hinweise „Einkauf teilen“, „Offener Betrag“ auf Home (6.2), `design-quelle.md`: „auf Home und in der Liste“ | neuer Slot `HomeSplitHint` (V12) mit genau einem Hinweis |
| 11 | Erfolg: kein Artboard | Figur 120 pt bis AX2, ab AX3 keine | A-Baustein zeigt ab AX1 72 pt; Empfehlung: so lassen und ab AX3 die Figur weglassen (A-V7) |
| 12 | `X-Pro`: „Essen per Foto, Barcode und Verlauf“ | Statistiken als Pro-Kandidat (F12-5) | Verlauf und Monatsrückblick frei lassen (Owner-Frage 6) |
| 13 | nichts dazu | Konzept 10.1 „für alle Mitglieder gelöscht“; `avo.md` „verschwindet aus deinem Verlauf und aus dem Monatsrückblick“ | ein Wortlaut, abhängig vom Fall (V13); `avo.md` übernimmt ihn |

### 5.1 Fragen an den Owner

Die Nummern sind die, auf die der Text oben verweist. Bis zur Antwort gilt die Empfehlung.

1. Markt in Zeilen: D2-Pastellkachel mit Buchstabe (`StoreBadge`) oder Punkt plus Name aus dem Konzept? Empfehlung:
   Pastellkachel, nie gelb auf Lidl-Blau (Konflikt 1).
2. Titel einer Einkaufszeile: Markt wie D2, Liste in der Unterzeile? Empfehlung: ja (Konflikt 2).
3. Ersparnis auf Home als Satz unter den Spalten statt grüner Spalte „Gespart“, und „ca. 3,20 € gespart“ statt
   „−3,20 €“? Empfehlung: ja, wegen „ca.“ und „laut Händler“ (Konflikt 3).
4. Monatsvergleich nur für abgeschlossene, gleich gut erfasste Monate und in Euro statt „−12 % zum Vormonat“?
   Empfehlung: ja (Konflikt 4).
5. Überall „Einkauf abschließen“ (Knopf, Menü, Screen)? Empfehlung: ja (Konflikt 6).
6. Werden „Kosten teilen“ oder „Statistiken“ (frühere Monate im Verlauf) Pro (F12-5)? Empfehlung: beides frei; Kosten
   teilen bringt neue Nutzer über geteilte Listen, und der Verlauf ist Kern.
7. „Erinnern“ öffnet das iOS-Teilen-Fenster. Das ist ein System-Fenster, das von unten hereingleitet. Ist das mit „nie
   Slider“ vereinbar, oder lieber Text kopieren mit Hinweis „Erinnerung kopiert“ bzw. direkt Nachrichten öffnen?
   Empfehlung: System-Teilen, weil es kein App-Panel ist und den Weg in jede Messenger-App offenhält.
8. „Sparziel mit Avo“ in Version 1? Empfehlung: nein (Konflikt 9, F12-8).
9. Gehört das Feld „Betrag“ zum Kern (K12-06) und nicht zum Modul Kosten teilen (00 15.1)? Empfehlung: Kern, damit der
   Monatsrückblick ohne Teilen funktioniert.
10. Kosten teilen auch für Listen ohne Mitglieder, nur mit Personen ohne Konto? Empfehlung: nicht im Abschluss, aber
    nachträglich im Einkauf-Detail (F12-6).
11. Wie weit reicht der Verlauf zurück (F12-4)? Empfehlung: alles behalten, seitenweise laden, lokal nur 3 Monate.
12. Ein Wortlaut für „Einkauf löschen?“ in App und Avo (Konflikt 13)? Empfehlung: die drei Fälle aus V13.
13. Erfolgsmoment: Figur ab AX1 72 pt (A-Baustein) statt 120 pt, ab AX3 keine? Empfehlung: ja (Konflikt 11).

---

## 6. Anfragen an Teil A

Nummern mit Präfix A-V, damit sie nicht mit den Anfragen aus `kalorien.md` (A-R, A-T) kollidieren.

| Nr. | Anfrage | Warum |
|---|---|---|
| A-V1 | `AppFilterChip` mit optionalem `leading` (8-pt-Markenpunkt mit Kontur, wächst bis AX2) und einer `ChipRow`-Variante für Einfachauswahl (Radiogruppe für VoiceOver, erneutes Tippen hebt auf) | „Wo warst du?“ (V1), E-09 |
| A-V2 | `SelectCircle` 22 pt in 44-pt-Ziel, `checkmark.circle.fill` in `tint` bzw. Ring `uncheckedRing`, VoiceOver als Schalter, keine Haptik | „Wer teilt?“ (V7), E-08; bewusst getrennt von `CheckCircle` |
| A-V3 | `AmountField` kompakt (in Zeilen, rechtsbündig, 17/22) und groß (`numberXL`, linksbündig, höchstens 51 pt), Locale-Eingabe („1.234,56“, „42,8“, Komma und Punkt), Währungszeichen nach Locale, tabellarische Ziffern, keine feste Breite, Fehlerzustand, `onChanged` in Cent | V1, V6, V7, E-04 |
| A-V4 | Balkendiagramm (S2b) im D2-Aussehen: Spalte mit Wert darüber und Kürzel darunter, optionale zweite Kürzelzeile („bisher“), hervorgehobene Spalte, Antippen und Ziehen zum Wählen mit Auswahl-Haptik pro Spalte, einstellbares VoiceOver-Element, „alle oder keine“ Wertebeschriftung nach Messung, ab AX1 Werte als Zeilen; Tokens `chartBar` (#ECECF0, erhöhter Kontrast #8A8A8E), `chartHighlight` (#34A853), `monthCardGradient` (#EEF7EF → #FFFFFF) für hell und dunkel | V4, V10 |
| A-V5 | Getönte Kapsel über hellem Inhalt mindestens 4,5:1 für weiße 17-pt-Schrift (96 % Deckkraft oder voll #1F7A3A), gleich wie A-T2 | „Einkauf speichern“, „Alle wieder auf die Liste“ |
| A-V6 | Zeile mit Wert und Pull-down (Titel, Wert in `secondaryLabel`, `chevron.up.chevron.down`, öffnet `showAvoMenu`) und `ValueRow` mit optionaler Unterzeile | „Bezahlt von“ (V7) |
| A-V7 | `showSuccessMoment`: Figur ab AX3 weglassen, Unterzeile bis 3 Zeilen; mit VoiceOver steht der Moment bis zum Ende der Ansage | V3 bei AX5 und 320 × 568 |
| A-V8 | `showModuleOffAlert` mit optionalem `message`, damit jedes Modul seinen Nutzen in einem Satz nennt | V13 |
| A-V9 | Einkaufsmodus und Listenmenü: kein Alert „Einkauf abschließen?“ mehr, Name überall „Einkauf abschließen“, bei 0 abgehakten Artikeln heißt der Knopf „Einkaufsmodus beenden“ und ruft `openCheckoutFlow` nicht auf; `shopping_trip_completion.dart` ruft nur noch `openCheckoutFlow` | V1 |
| A-V10 | `AvoToast`: Zeit läuft nicht, solange der VoiceOver-Fokus auf dem Hinweis liegt; Möglichkeit, „Widerrufen“ zusätzlich als Aktion am geänderten Element anzubieten (Callback beim Erscheinen und Ablauf) | 3.6, K12-14 |
| A-V11 | `navigation_service.dart`: Mitteilungstypen `shopping_complete` und `expense_split` öffnen `/history/:tripId` | V14 |
| A-V12 | Listen-Übersicht: Gruppe „Verlauf“ am Ende mit `NavRow` „Einkäufe“ (Wert „November · 6“) und, nur mit Modul Kosten teilen, `NavRow` „Offene Beträge“ (Wert „34,60 €“); B liefert synchron `historyEntrySummaryProvider` und `openBalancesSummaryProvider` | D2-Home hat keinen Einstieg in den Verlauf |
| A-V13 | Home: Slot `HomeSplitHint()` mit `homeSplitHintHasContentProvider`, Vorschlag direkt unter der Avo-Karte | V12 |
| A-V14 | Routen einhängen: `/checkout/:listId` aus `historyRootRoutes` vor der Shell; `/splits` aus `historyBranchRoutes[AppBranch.lists]`; Kinder `':tripId'`, `':tripId/amount'` und `':tripId/split'` (die letzten zwei mit `rootNavigatorKey`). Bestätigen, dass ein Push von `/history/:tripId` aus dem Home-Tab in den Listen-Tab wechselt und dort Verlauf und Detail stapelt | 1.1, V11 |
| A-V15 | Glas-Budget: zählt der Rückgängig-Hinweis als vierte Glasfläche (E-18)? | V4, V5 |
| A-V16 | Symbole in `AvoIcons`: `eurosign.circle`, `person.badge.plus`, Filter (`line.3.horizontal.decrease.circle`, Kontur und gefüllt), `exclamationmark.circle`, `checkmark.circle` (48 Light), `cart.badge.plus`, Einkaufstasche und Balken (D2 „Dein November“), Liste (für „Artikel“), Pfeil nach unten 14 (D2 Vergleich), Sync (`arrow.triangle.2.circlepath`), `chevron.up.chevron.down`, `storefront`, Standort | E-07 |
| A-V17 | Wischaktionen auf Zeilen (links und rechts, Schwelle mit leichtem Impuls, volles Wischen löst aus, als VoiceOver-Aktionen) und Kontextmenü per Langdruck (S2b-Menüs) als gemeinsamer Baustein | V4, V5, V7, V8 |
| A-V18 | `Avatar` 20, 28 und 40 mit Initiale auf `tintSoft` oder Foto (S2b) | V5, V7, V8 |
| A-V19 | `ItemRepository.addItems(..., skipOpenDuplicates: true)`: Artikel, die schon offen auf der Ziel-Liste stehen, werden übersprungen statt zusammengeführt; Ergebnis nennt die übersprungenen | „Alle wieder auf die Liste“ (V5) |
| A-V20 | `FullScreenEditor` (S2b): gesperrtes Zurück-Wischen und Rückfrage beim Schließen, solange `isDirty`; untere Kapsel, die über der Tastatur mitläuft | V1, V6, V7 |
| A-V21 | E-06: großer Titel für Verlauf und Offene Beträge, auch wenn sie dritte Ebene sind | V4, V8 |
| A-V22 | `LocalStore` und `WriteQueue` mit Bereich `history` und Aufgaben mit „frühestens ab“ (für Mitteilungen nach dem Rückgängig-Fenster), die beim Widerrufen gestrichen werden | 3.1 |

---

## 7. Datenquellen und Lücken

| Was | Quelle heute | Stand | Lücke |
|---|---|---|---|
| Verlauf lesen | `ShoppingHistoryService.getShoppingHistory` (lädt alles ohne Grenze), `shoppingHistoryProvider`, `shoppingHistoryNotifierProvider` | vorhanden, ohne Cache, ohne Seiten | L3 |
| Abschluss | `ShoppingHistoryService.completeShoppingTrip` (zwei getrennte Inserts, `total_cost` aus Angebotspreisen) | falsch | L1, L2 |
| Markt des Einkaufs | `shopping_history` speichert heute einen OSM-Anzeigenamen | falsch | L2 |
| Aufteilung | `ExpenseSplitService` (`createSplits` fügt vor dem Löschen ein, Zahler-Anteil als bezahlt, `setPaid` wirft), `tripSplitsProvider`, `splitCandidateMembersProvider` | vorhanden, unvollständig | L5, L7 |
| Offene Beträge | `getTripsAwaitingPaymentToMe`, `getTripsIOwe` (laden alle bezahlten Einkäufe) | vorhanden, zu breit | L8 |
| Teilen-Hinweis | `unsplitTripNudgeProvider` (nur eigene Einkäufe), `SplitNudgeCacheService` (eine ID gerätweit) | vorhanden, falsch | L9 |
| Ersparnis | `offer_savings.dart` (`summarizeListOffers`, `roundedSavingsCents`), `regionProvider` | in Arbeit (anderer Workflow) | L4 |
| Markt-Vorauswahl | `storeForListProvider`, `storeGuessForListProvider`, `CheckoutStoreResolver`, `StoreLocatorService` | vorhanden bzw. in Arbeit | Overpass mit `way`, 250 m |
| Artikelbilder | `ArticleImage(item: ShoppingItemModel)` | vorhanden als Hülle | L10 |
| Module, Kill-Switch | `moduleEnabledProvider`, `offersAvailableProvider` | vorhanden | keine |
| Verbindung | `connectionStateProvider` (Kap. 20) | fehlt | B baut es (Paket Start) |

- **L1** Atomare RPC `complete_shopping_trip(list_id, checked_item_ids, chain_id, total_cost, split_planned)`: legt
  Einkauf und Artikel-Schnappschüsse in einer Transaktion an, markiert die Artikel als erledigt und meldet „schon
  abgeschlossen“, wenn ein anderes Mitglied schneller war. Gegenstück `undo_shopping_trip(trip_id, token)` für das
  Rückgängig-Fenster (stellt die Artikel als abgehakt wieder her, löscht eine Aufteilung aus derselben Kette). Migration
  `supabase/migrations/…_b_trip_checkout.sql`, Owner wendet an.
- **L2** Spalten an `shopping_history`: `store_chain` (Ketten-ID), `store_source`, `total_cost_source` (`user`),
  `completed_by` (Nutzer-ID, heute nur `completed_by_name`); `total_cost` nur aus Eingabe (behebt Bug 7). Altdaten mit
  OSM-Namen werden über das Ketten-Verzeichnis normalisiert; fehlende Spalten dürfen das Speichern nie blockieren.
- **L3** Seitenweises Laden (30), lokale Ablage der letzten 3 Monate bzw. 50 Einkäufe im Konto, Realtime oder Nachladen
  nach Rückkehr; Verlauf-Provider wird beim Abschluss ergänzt statt neu geladen (behebt Bug 3); Home-Schnappschuss.
- **L4** Grundpreis, Grundeinheit, Packungsgröße und Angebots-Kette pro Artikel-Schnappschuss
  (`shopping_history_items`), sonst lässt sich Regel 5 im Verlauf nicht rechnen; bis dahin zählt eine Ersparnis nur, wenn
  der Schnappschuss den Händler-Vergleichspreis und dieselbe Kette hat, gerechnet über die Packung. Genau so rechnet
  `totalSavingsOf` inzwischen (`ShoppingHistoryItem.pricingQuantity`, Änderung des parallelen Workflows); V3, V4, V5 und
  V9 nutzen diese eine Funktion plus `roundedSavingsCents`, nie eine eigene Rechnung.
- **L5** `expense_splits`: `split_mode` (`equal`/`custom`), `paid_by_user_id` bzw. `paid_by_name` am Einkauf schon da,
  `position` (Reihenfolge, Restcent), Speichern als RPC `save_trip_split` (ersetzen statt Einfügen-dann-Löschen,
  Bezahlt-Status bei gleichem Anteil erhalten).
- **L6** Neuberechnung gleicher Anteile, wenn sich der Betrag ändert (V6), in derselben Transaktion.
- **L7** Mitglieder lokal zwischenspeichern; `ListRepository.getListMembers` gehört A, Ergebnis heute rohe Maps.
- **L8** Abfrage nur offener Anteile (Server), plus erledigte der letzten 30 Tage; RLS für `expense_splits` verschärfen
  (heute darf jedes Mitglied jede Zeile ändern) und RLS für `shopping_history` dokumentieren (Löschen fremder Einkäufe
  scheitert heute still, Bug 4).
- **L9** Teilen-Kandidat auch für fremde Einkäufe; Ausblenden pro Einkauf im Konto (Regel 15).
- **L10** `ArticleImage` braucht einen Weg für Verlaufsartikel (`ShoppingHistoryItem` hat Name und Kategorie, kein
  `ShoppingItemModel`), etwa `ArticleImage.forName(name:, categoryId:)`. Die Datei gehört gerade einem anderen
  Workflow; Absprache vor dem Bau.
- Mitteilungen mit Verzögerung: Auftrag in der Warteschlange (A-V22) oder serverseitig mit Verzögerung; beides
  verhindert falsche Nachrichten nach einem Widerrufen.
- Datenschutz: Koordinaten gehen beim Abschluss an Overpass (OpenStreetMap); das muss in die Datenschutzerklärung
  (OPEN-ISSUES).

Alte Dateien, die beim Bau gelöscht werden: `screens/history/shopping_history_screen.dart`,
`screens/history/widgets/split_cost_sheet.dart`, `pending_splits_banner.dart`, `split_trip_nudge_card.dart`,
`split_nudge_cache_service.dart` (nach Umzug ins Konto), die Abschluss-Teile in `checkout_store_sheet.dart` (gehört
gerade dem anderen Workflow) und die Bestandsschlüssel aus der Einleitung.

---

## 8. Prüfliste für Screenshots

Jeden Punkt am Screenshot abhaken; Breiten 320, 375, 390, 402, 440; Textgrößen L, xxxL, AX3, AX5; fett an und aus;
hell und dunkel; dazu je einmal erhöhter Kontrast, Reduce Motion, Transparenz reduzieren.

**Allgemein**
- [ ] Kein Bottom-Sheet, kein halbhohes Modal, kein Drawer, kein Schieberegler auf irgendeinem Screen dieses Bereichs.
- [ ] Jeder Screen öffnet per Push von rechts; V1, V6, V7 ohne Tab-Leiste, V4, V5, V8 mit.
- [ ] Höchstens drei Glasflächen gleichzeitig (Rückgängig-Hinweis nach Entscheidung A-V15), genau eine getönte.
- [ ] Alles Antippbare mindestens 44 × 44 pt, auch Chips (34 sichtbar), „Bezahlt“, „Ändern“, „Alle“, Balken.
- [ ] Kein Text abgeschnitten, keine Ellipse außer im Inline-Titel; nichts überlappt die Tab-Leiste oder die Kapsel.
- [ ] Beträge überall im Locale-Format („42,80 €“, „€42.80“), tabellarische Ziffern, kein „3.20 €“.
- [ ] Destruktiver Text in #D70015, nie #FF3B30; leere Ringe #8A8A8E.
- [ ] Keine Emojis, keine Ausrufezeichen, „Markt“ statt „Laden“, „Mitteilungen“, „Pro“.

**Ehrlichkeit und Recht**
- [ ] Jede Ersparnis mit „ca.“; als Satz mit „laut Händler“; keine Ersparnis unter 0,50 €; kein „Spare“, kein Prozent bei
      Angeboten, kein Minuszeichen vor einer Ersparnis.
- [ ] Kein Marktvergleich, keine Korbsumme, kein „günstigster Markt“ irgendwo.
- [ ] Kill-Switch an, Modul Angebote aus, ohne echte Region: kein „Angebot“, „gespart“, „laut Händler“, keine grüne
      Angebots-Pille; keine Lücke, wo die Ersparnis stand.
- [ ] Gesamtbetrag nur, wo ihn jemand eingegeben hat; ohne Betrag steht nichts statt „0,00 €“.
- [ ] Monatsvergleich nur in abgeschlossenen Monaten mit je ≥ 80 % erfassten Beträgen, in Euro; laufender Monat mit
      „bisher“.
- [ ] Marken als `StoreBadge` im gewählten Stil (Owner-Frage 1), nie ein Händlerlogo oder -bild.

**V1 Einkauf abschließen**
- [ ] Kein Alert vor dem Screen; Kapsel „Einkauf speichern“ an derselben Stelle wie „Einkauf abschließen“ im
      Einkaufsmodus.
- [ ] Vorauswahl mit Fußnote zur Herkunft; Standort-Chip hängt sich nur hinten an.
- [ ] Ohne Kosten-teilen-Modul bzw. ohne Mitglieder keine Lücke, wo der Schalter stand.
- [ ] Nichts abgehakt: „Noch nichts im Wagen.“ mit „Zurück zur Liste“, kein Eintrag im Verlauf.
- [ ] Standort abgelehnt: der Hinweis erscheint höchstens einmal im Leben.
- [ ] Bei offener Tastatur bleibt die Kapsel sichtbar über der Tastatur.

**V3 Erfolgsmoment**
- [ ] Avo feiernd (echte 3D-Figur), erst nach dem Schließen von V1; ab AX3 ohne Figur; Text passt bei 320 × 568 und AX5.
- [ ] Unterzeile ohne Ersparnis, wenn Modul aus oder unter 0,50 €; ohne Markt nur „9 Artikel“.
- [ ] Danach genau ein Hinweis „Einkauf gespeichert · Widerrufen“; Widerrufen stellt „Erledigt (9)“ wieder her.

**V4 Verlauf**
- [ ] Großer Titel „Verlauf“, Filter oben rechts; aktiver Filter als Metazeile mit „Alle“.
- [ ] Monatskarte: Zahl `numberXL` ≤ 51 pt, Abdeckung „aus 4 von 6 Einkäufen“ nur bei Lücken, Diagramm mit 6 Monaten,
      gewählter Monat grün, Leiste ohne doppelte Zahl.
- [ ] 320 pt: Balken ≥ 24 pt breit, Wertebeschriftung alle oder keine.
- [ ] AX1+: Monate als Zeilen unter dem Diagramm, `TripRow` ohne Kachel, Betrag unter dem Text.
- [ ] `TripRow`: Markt als Titel, Liste · Datum · Anzahl, Betrag rechts oder nichts, Schuldzeile nur mit Modul.
- [ ] Leer: Avo winkt (96 pt, ab AX1 ohne), „Noch keine Einkäufe.“ mit „Zu den Listen“.
- [ ] Fehler und Offline als `StatusRow` unter dem Titel; ohne Stand ruhige Tonflächen, nie ein Spinner.
- [ ] Fremde Einkäufe ohne „Löschen“ im Wischen und Kontextmenü.

**V5 Einkauf-Detail**
- [ ] Kopf mit Markt, Datum, Person und Betrag (oder „Betrag eintragen“ nur für den Einkäufer).
- [ ] „Alle wieder auf die Liste“ mit Ziel in der Fußnote; deaktiviert mit „Alles steht schon auf …“.
- [ ] Kosten teilen: „offen“/„bezahlt am …“, „Bezahlt“ bzw. „Zurückgezahlt“, Fußnote mit Zahler und Modus; keine
      Schulden in Rot.
- [ ] Artikel ohne Abhak-Kreis, mit Bild 44, Pille nur mit Modul, „laut Händler statt …“ nur mit Vergleichspreis.
- [ ] Menü „Mehr“ ohne graue Einträge: nicht Erlaubtes fehlt.

**V6 Betrag und V7 Kosten teilen**
- [ ] Vollbild mit `xmark` und getöntem Häkchen; Häkchen gedimmt, solange ungültig, Grund im Fuß sichtbar.
- [ ] V7: Segment „Gleich | Individuell“ (ab xxL Pull-down), Auswahl-Kreise statt Abhak-Kreise, Anteile auf den Cent,
      Restcent-Satz, „Noch 3,20 € zu verteilen“ mit Symbol plus Text.
- [ ] Hinweis „Der Anteil von Lena ändert sich …“ vor dem Speichern sichtbar.
- [ ] Mit Tastatur und 4 Teilnehmern bei AX3 scrollt alles, nichts liegt unter der Tastatur.
- [ ] Keine Figur, keine Erfolgs-Haptik.

**V8 Offene Beträge**
- [ ] Großer Titel, „Schuldet dir“ und „Du schuldest“ mit Summen, die aus den Zeilen aufgehen; eine Zeile pro Anteil.
- [ ] „Erledigt (n)“ eingeklappt; Zeile wandert nach „Bezahlt“ dorthin (Reduce Motion: Überblendung).
- [ ] Leer: Häkchen-Symbol ohne Figur, „Alles beglichen.“
- [ ] Fehlender Name: „Ein Mitglied“.

**V9 bis V12 Home**
- [ ] „Dein November“: Verlaufsfläche wie D2, Spalten Ausgaben · Einkäufe · Artikel, Ersparnis als Satz, keine Figur.
- [ ] „Ausgaben im Vergleich“: keine Prozentzahl, kein Vergleich des laufenden Monats, „bisher“ unter „Nov“.
- [ ] „Letzte Einkäufe“: höchstens 3 Zeilen, „ca. 3,20 € gespart“ statt „−3,20 €“, Fußnote nur mit Ersparnis.
- [ ] Höchstens ein Kosten-teilen-Hinweis, nie eine Liste von Schulden auf Home, keine Figur.
- [ ] Modul Kosten teilen aus: kein „schuldet“, „Anteil“, „Kosten teilen“, „bezahlt“ in Home oder Verlauf.

**Dialoge**
- [ ] „Einkauf vom 7. Nov. löschen?“ zentriert, Text je nach Fall, „Abbrechen“ fett, „Einkauf löschen“ rot.
- [ ] „Änderungen verwerfen?“ zentriert, nie als Aktionsblatt von unten.
- [ ] „Kosten teilen ist ausgeschaltet“ mit eigenem Nutzen-Satz, „Einschalten“ öffnet danach das Ziel.

**VoiceOver (am Gerät)**
- [ ] Jede Zeile ein Element mit vollem Satz, Aktionen per Rotor erreichbar (Löschen, Kosten teilen, Bezahlt, Erinnern).
- [ ] Monatsköpfe als Überschriften in normaler Schreibung; Diagramm als Zusammenfassung plus Balken.
- [ ] Rückgängig-Hinweis 10 s, angesagt, „Widerrufen“ erreichbar.
- [ ] Erfolgsmoment angesagt; Summen-Fuß in V7 als Live-Region.
