# S6 Gegenprüfung von B – Ergebnis (09.11.2026)

A hat B's fertige Screens nur lesend geprüft: Angebote (S1–S16 inkl. Listen-Slots), Avo-Tab und Antwortkarten,
Kalorien-Kern (B6), B-Einstellungen (Angebote, Avo, Kalorien & Gesundheit, Siri, Widgets). Nicht geprüft, weil B sie
noch umbaut: Verlauf und Kosten teilen (B8, Zweig `feature/b8-history`), Kalorien-Woche, Gewicht, Challenges, „Was kann
ich essen“ (B6b), Wochenplan (B7). Keine B-Datei geändert. Screenshots: [`abnahme/s6/`](abnahme/s6/) (iPhone 17,
angemeldet, Englisch).

## Ergebnis

- **Anfragen von B an A:** keine offen. status-B 17 (2) (`ItemPrice.retailer`-Doku) stand schon so in
  `lib/data/repositories/item_batch.dart`.
- **Prüfmatrix:** jeder fertige B-Screen hat einen Matrix-Test (`test/layout/screens/b/`, 7 Dateien);
  `flutter test test/layout/screens/b/`: 2546 Fälle grün. Ohne Matrix nur die fünf Screens aus B6b/B8.
- **Harte Regel (keine Sheets/Slider):** in den fertigen Screens keine. Die zwei bekannten Sheets
  (`checkout_store_sheet`, `split_cost_sheet`) gehören zu B8.
- **`bash tool/design_check.sh B`:** 140 Funde, davon 132 in B6b/B8-Dateien (Verlauf, Kosten teilen, Markt beim
  Abschließen, Woche, Challenges, Gewicht, „Was kann ich essen“). In fertigen Screens 8, siehe unten (Nr. 8).
- **Code-Review** (ein Prüfer, nur lesend, Regeln aus CLAUDE.md und Konzept 20 §7): keine P1. Texte in fester Höhe,
  Touch-Ziele, VoiceOver-Labels, Glas nur auf der schwebenden Ebene, Übersetzungen, Navigation, Modul-aus-Zustand und
  `mounted`-Prüfungen sind in Ordnung.
- **Simulator** (hell und dunkel): Avo-Tab leer und mit Frage, Profil, Angebots-Einstellungen, Region, Avo-Einstellungen.

## Von Teil B (gewünscht)

1. **P1 Avo antwortet nicht:** jede Frage im Avo-Tab endet mit „That didn't work. Avo can't be reached right now.“
   (`fund_avo_titel_doppelt_fehler.png`). Ursache prüfen; naheliegend ist der fehlende Deploy von `ai`
   (OPEN-ISSUES 2., BA8). Liegt es nicht daran, ist es ein B-Fehler.
2. **P2 Avo-Tab: Titel doppelt.** Nach der ersten Frage stehen der große Titel „Avo“ mit Figur (halb ausgeblendet) und
   der kleine Titel „Avo“ in der Mitte gleichzeitig da, auch wenn die Animation längst vorbei ist (gleicher Screenshot).
   iOS zeigt nur einen der beiden.
3. **P3 Avo-Einstellungen:** im Fuß ist „Privacy“ größer als der Satz davor (`avo_einstellungen_dunkel.png`); der
   Hinweis unter „Diet and allergies“ sagt „These switches“, es gibt aber nur einen Schalter.
4. **P3 Angebots-Einstellungen:** der Postleitzahl-Hinweis nutzt eine erhobene Hand (liest sich wie „Stopp“); ein
   Standort-Symbol passt besser (`angebote_einstellungen_hell.png`).
5. **P3 `list_offers_screen.dart:348–370`:** `_addRegular` ruft `ref.invalidate(…)` nach zwei `await` in einem
   `ConsumerWidget`; verlässt man den Screen vorher, greift der Debug-Assert von Riverpod. Container vorher merken.
6. **P3 Dauern und Kurven nicht aus `AvoMotion`:** `avo_result_card.dart:230, 404`, `avo_confirm_card.dart:87, 113`
   (dazu `Curves.easeOutCubic`), `avo_status_line.dart:12`, `avo_message_text.dart:12`,
   `calorie_estimate_parts.dart:25`. Fehlt in `AvoMotion` ein passender Wert, als Wunsch an A melden.
7. **P3 `avo_confirm_card.dart:199–201`** liest `AvoColors.light`/`lightHighContrast` direkt; der Token
   `context.colors.destructiveFill` gibt es seit AB1.
8. **P3 design_check in fertigen Screens:** `calorie_colors.dart:74, 86, 98` (als Token-Datei mit `// D2` markieren
   oder in `design_check.sh` ausnehmen wie `list_info_colors`), `article_image.dart:31` (Weiß hinter Produktfotos:
   `// D2` markieren), `store_mark.dart:152, 156`, `item_offer_card.dart:184`, `calories_today_summary.dart:349`
   (Schriftgröße/Laufweite: als `// D2`-Einzelfall markieren oder Textstil nehmen).
9. **P3 37 `CupertinoIcons` in Avo- und Kalorien-Dateien** (Liste: `bash tool/design_check.sh B`). Fehlt eine Glyphe
   in `AvoIcons`, als Wunsch an A melden; A ergänzt sie.
10. Weiter offen aus A11/A11b: Schatten unter `_PostcodeHintRow` (`offer_suggestions_bar.dart`), Kommentar über dem
    Auth-Listener in `main.dart`.

## Offen bei A (→ S5)

- **A-V9 (status-B 19, angekündigt):** Sobald B8 auf `main` kommt, lassen `shopping_mode_screen.dart` und
  `list_detail_screen.dart` ihren eigenen Erfolgsmoment nach `openCheckoutFlow == true` weg (sonst doppelt). B meldet
  sich vor dem Merge, beides im selben Push.
- Gegenprüfung der B6b-, B7- und B8-Screens, sobald sie auf `main` sind (in S5 oder der nächsten A-Sitzung danach).
- Aus A11b: Filter-Chips mit `recipeShownDiet`, Galerie-Einträge, `SwipeActions`-Reste, `ItemRow`-Vorschlagsvariante.

## Braucht den Owner

- Deploy von `ai` (OPEN-ISSUES 2.), falls Fund 1 daran liegt.
- Platte: 12–14 GB frei. Unter 15 GB keine Worktrees, unter 10 GB keine Builds.

## Bewusst abgewichen

- Simulator nur als Stichprobe auf vier Screens; Kalorien nicht im Simulator (Modul im Testkonto aus, nicht
  eingeschaltet, um die Einstellungen des Owners nicht zu ändern). Die Matrix deckt sie ab.
- Prüfmatrix und Build im Hauptordner statt im Worktree (Platte unter 15 GB).
