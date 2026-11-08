# A5 Listen: Ergebnis und offene Punkte (08.11.2026)

A5 ist auf `main`: Einkaufsmodus `0e1f753`, Listen-Übersicht/Teilen/Listen-Info `c53e84f`, Artikel-Vollbild und
Zettel-Import `5efc97f`, Liste `5e943ba`. Auftrag: [`a5-auftrag.md`](a5-auftrag.md). Tests: 3.701 grün (Listen, Design,
Home, Routen, Übersetzungen), `dart analyze` ohne Errors/Warnings. Auf dem Gerät noch nicht geprüft.

## Fehlende Daten (A, eigene Aufgaben)

- **Präsenz** („Lena kauft gerade ein“): kein `list_presence_service.dart`; `shoppingCompanionsProvider` (Einkaufsmodus)
  meldet niemanden, die Liste zeigt nur Mitglieder-Avatare (`listDetailMembersProvider`).
- **Wer hat abgehakt:** keine Spalte `shopping_items.checked_by`, kein `ShoppingItemModel.checkedBy`; es steht „gerade
  abgehakt“ ohne Namen (`list_shop_just_by` liegt bereit).
- **Reihenfolge je Markt und Gang-Nummern:** keine Daten; genutzt wird die Kategorie-Reihenfolge der Liste
  (`CategoryOrderService`, nur auf dem Gerät gespeichert).
- **„Zuletzt geändert“ in der Listen-Info** bleibt leer: `ListActivityService` hat keine Aufrufer, Tabelle `list_events`
  fehlt.
- **Offline:** `ItemsNotifier` hat keine Warteschlange; Abhaken offline wird zurückgerollt.
- **Rückgängig beim Artikel-Löschen** legt den Artikel neu an (neue ID); kein Restore im Repository.

## Router und Repository (A)

- Routen fehlen: `/join/:code` (geteilter Link `https://shoplyai.app/join/<CODE>` führt ins Leere), `/lists/join`
  (kollidiert mit `/lists/:listId`), `/lists/:id/info`, `/lists/:id/share`.
- `ListRepository.removeMember(listId, userId)` fehlt (heute direkt in `list_members`); `createList` nicht atomar.
- Teilen-Codes sind 6 Zeichen `A-Z0-9`, nicht 6 Ziffern wie entschieden (nicht geändert).
- `NewItem` (`item_batch.dart`) hat kein `isDietWarning`; `addItem` meldet kein Zusammenführen („Menge jetzt 4“).

## Komponenten (A)

- `AvoToast` verdeckt auf der Liste kurz das Eingabefeld (braucht `aboveAccessory`), `ShellInsets` kennt die Höhe des
  Eingabefelds je Textgröße nicht.
- `ValueStepper` nur ganze Zahlen, kein Tippen auf den Wert (Artikel-Vollbild nutzt bei Kommazahlen ein Zahlenfeld);
  `ValueRow` richtet den Wert nicht rechtsbündig aus.
- `AvoIcons` fehlen Kamera, Foto, Ordner, Zwischenablage, Glocke (liegen privat in `attachment_sheet.dart` bzw. als
  `CupertinoIcons.bell`).
- `ListDetailActions` und `ListActions` überschneiden sich (Umbenennen, Löschen, Verlassen); zusammenführen.
- Die Texte liegen in vier Dateien `lists_{detail,item,shopping,overview}.dart`; nach A5 in `lists.dart` zusammenführen.
- Listenfarben stehen als Tabelle in `list_info_colors.dart`, passender wäre `AvoColors`.

## Von D2 bzw. Konzept bewusst abgewichen

- Artikel löschen ohne Rückfrage, mit Rückgängig (Konzept 11 §4).
- Einheit: St./g/kg wie D2 plus Segment „Mehr“ für die übrigen Einheiten.
- Im Einkaufsmodus „+“ unten links (Konzept 5.2, nicht in D2); Kapsel ab AX3 nur Häkchen.
- Kein Wischen mit halb aufgezogenen Knöpfen, kein Untermenü im Langdruck-Menü (`AvoMenu` kennt keine Untermenüs).
- „Oben anheften“ statt „Beim Start zeigen“ (keine Start-Logik); kein Listen-Symbol (keine Spalte, keine Icons);
  kein Foto-Upload für neue Listen.
- „Vielleicht auch“ fehlt (Empfehlungs-API von B), ebenso Mitteilungen pro Liste und „Kosten teilen einschalten“.

## Für Teil B

- `restockSuggestionsProvider` über `b_slots.dart` exportieren (Übersicht importiert ihn direkt).
- `OfferSuggestionsBar`: `onSelect` und nullbare `listId` können weg; `ListPriceSummaryBar` nutzt A nicht mehr.
- Abschluss: Bis B8 erscheint nach `openCheckoutFlow` zweimal „gespeichert“ (B's Zwischen-Screen und A's Erfolgsmoment).
