# AB1 Anfragen von B: Komponenten und Daten – Ergebnis (09.11.2026)

Auftrag: [`ab1-auftrag.md`](ab1-auftrag.md). Vorarbeit `f259477` (Konto-Symbole in `AvoIcons`, `stopFill`,
Textdateien `components_{rows,input,menus}.dart`), Komponenten im Commit danach (`git log --grep AB1`). Alles in
`lib/presentation/widgets/design/`, je Datei mit Test und `layoutMatrix`. Nur in Tests geprüft, nicht im Simulator.

## Neue API (für B)

**Zeilen**
- `ItemRow`: `trailingSemanticsLabel` (geht ins Zeilen-Label und blendet die Slot-Semantik aus; dann die Slot-Aktionen
  über `trailingActions` geben), `trailingActions` (`Map<String, VoidCallback>`, Custom Actions), `contextMenuItems`
  (`List<AvoMenuEntry>`, Langdruck öffnet `showAvoMenu` am Finger, auch im Einkaufsmodus), `swipeActions`,
  `leadingSwipeActions` (`List<SwipeAction>`). Tipp auf den Slot erreicht den Slot. Ab AX1 sitzt der Slot unter dem
  Namen neben der Menge. `ItemRowSize.compact` (≥ 56 hoch, Kreis 22 in 44, Bild 36/Radius 9, Linie ab 88 =
  `ItemRow.separatorIndentCompact`).
- `CheckCircleSize.small` (22 in 44).
- `SelectCircle({selected, onChanged, semanticLabel})` (E-08): Schalter-Semantik, keine Haptik.
- `SwipeActions({child, trailingActions, leadingActions, fullSwipe, enabled, exposeSemantics, borderRadius})` mit
  `SwipeAction({label, onPressed, icon, destructive})`; alle Aktionen auch als VoiceOver-Aktionen.
- `ReorderableInsetSection({children (mit Keys), labels, onReorder(old, new), header, headerTrailing, footer, …})`:
  Griff 44 rechts, Langdruck hebt, VoiceOver „Nach oben“/„Nach unten“ mit Ansage. `newIndex` ist der Index nach dem
  Verschieben (`insert(newIndex, removeAt(oldIndex))`). Kein Auto-Scrollen (für kurze Listen wie S13).
- `HintRow(title:, swipeActions:, contextMenuItems:)`.
- `shoppingModeSessionProvider` (`StateProvider<ShoppingModeSession?>`, `ShoppingModeSession {listId, startedAt}`) in
  `lists_provider.dart`; der Einkaufsmodus setzt und leert ihn. `ListOfferSummary` kann ihn statt des
  `ShoppingModeHeader`-Vorfahren lesen.

**Eingabe**
- `AppButton.filledNeutral` und `AppButton.destructiveFilled` (gleiche Parameter wie die anderen); Token
  `colors.destructiveFill` (#D70015, Kontrast-Paletten dunkler, weiß ≥ 4,5:1).
- `AvoComposerField(onStop:, responding:, stopLabel:, enabled:, maxLength:, semanticLabel:, photoMenuItems:)`:
  Anhalten-Zustand bei `responding && onStop != null`, Zähler ab 5 % Rest, Foto-Knopf als Pull-down.
- `AvoSearchField(onDictate:, dictateLabel:)`: Mikrofon, solange leer. Form bleibt (D2: 36/Radius 10).
- `TextFieldRow({label, controller, placeholder, keyboardType, autofillHints, inputFormatters, errorText, hintText, …})`
  (A-C5): ab AX1 gestapelt, Fehler als VoiceOver-Hinweis.
- `AppFilterChip(leading:, secondaryLabel:)` (`secondaryLabel` ohne Punkt übergeben, „400 m“), `ChipRow(wrap: true)`,
  `SingleChoiceChipRow<T>({choices: [ChipChoice(value, label, secondaryLabel, leading)], value, onChanged,
  allowDeselect, wrap})` als Radiogruppe.
- `NavRow(valueLeading:)`; `AvatarSize.size28`, `size40`, `xl` (64) und `Avatar(image:, syncing:)`.
  `ProfilePhotoAvatar` ist weg (Profil, Profil bearbeiten und Name-Schritt nutzen `Avatar(size: AvatarSize.xl)`).

**Menüs, Rückmeldung, Daten**
- `AvoMenuTitle(text)` (Titelzeile ohne Aktion), `AvoMenuItem(leading:, trailing:, trailingLabel:)` (`leading` z. B.
  `StoreMark` in eigener Spalte nach dem Häkchen, `trailing` z. B. `ProBadge`). Häkchen vorn, Unterzeile, Scrollen
  und Öffnen nach oben gab es schon.
- `showModuleOffAlert(…, body:)`.
- `AvoToast.show(…, targetLabel:, onTarget:)` (E-16: Tipp auf den Text öffnet das Ziel, „Widerrufen“ bleibt);
  die Zeit steht, solange der VoiceOver-Fokus auf dem Hinweis liegt (A-V10).
- `AvoIcons`: `plusBubble`, `leaf`, `switch2`, `eurosignCircle`, `filter`, `filterCircle`, `filterCircleFill`,
  `checkmarkCircle`, `cartBadgePlus`, `bag`, `chartBar`, `listBullet`, `arrowDown`, `chevronUpChevronDown`,
  `stopFill`, `photo`, `camera`, `checklist`, `history`, `personCircle`, `flame`, `sync`.
- A-D1: `ItemPrice({price, currency, retailer, unit, oldValue, updatedAt})`, `ItemRepository.setItemPrice(itemId,
  price)` / `clearItemPrice(itemId)` → `PriceChangeResult(token, item)`, `undoPriceChange(token)` → `bool` (schreibt
  nur, wenn noch der gesetzte Preis gilt); `NewItem(price: ItemPrice?)`, `addItems` schreibt ihn (beim Zusammenführen
  ersetzt er den alten Preis, `undoAddItems` stellt ihn wieder her). Optimistisch aus der UI:
  `ItemsNotifier.setPrice` / `clearPrice` / `undoPrice` (`items_provider.dart`, bei Fehler zurück).

## Braucht den Owner

Nichts.

## Von Teil B (gewünscht)

- Eigenbauten umstellen: `StoreFilterChip` → `AppFilterChip(leading:, secondaryLabel:)`, `PostcodeFieldRow` →
  `TextFieldRow`, sortierbare Zeilen in S13 → `ReorderableInsetSection`, Avo-Composer → die neuen
  `AvoComposerField`-Parameter (eigenen Zeichenzähler weglassen), Angebotspille in `ItemRow` →
  `trailingSemanticsLabel` + `trailingActions`.
- `AvoMenuItem.trailing` ohne eigene Tippfläche; `targetLabel` und `onTarget` immer zusammen.

## Offen bei A

- Untermenüs an derselben Stelle (A-K10): nicht gebaut; Behelf: neues `showAvoMenu` mit dem `anchorRect` des alten.
- Review-Reste (Klein): `SwipeActions` ohne „nur eine Zeile offen“ und ohne Schließen beim Scrollen;
  `ReorderableInsetSection`: Trennlinie wandert beim Ziehen mit, Schatten am Rand evtl. abgeschnitten (im Simulator
  prüfen); Preis-Rückgängig prüft per Select-dann-Update (nicht atomar).
- Kompakte `ItemRow`: Aufrufer übergeben `ItemThumb(radius: 9)`.
- Galerie (`/debug/components`): Einträge für alle neuen Komponenten und Varianten fehlen.
- Nicht in AB1: A-C4, A-L1–A-L4, A-R1–A-R3 (→ AB2); Kalender-Menü, Zahlenfeld/`AmountField`, `NutritionRow`, Charts
  mit Ziellinie, `InlineCalendar`, einklappbare `InsetSection` (kalorien/wochenplan/verlauf-kosten §6) sind weiter offen.

## Bewusst abgewichen

- Kompakte Zeile: Bild bei 49 statt 48, damit das 44er Ziel um den Kreis nicht abgeschnitten wird; Linie bei 88.
- `NewItem.price` ist ein `ItemPrice?` statt sechs Felder; gefülltes Filter heißt `filterCircleFill`.
- Das Warndreieck „In iOS aus“ sitzt in der Profil-Wurzel (dort steht der Wert), nicht auf der Mitteilungs-Seite.
- Avatar `xl` ist immer grau mit zwei Initialen (wie der alte Profilkreis).
