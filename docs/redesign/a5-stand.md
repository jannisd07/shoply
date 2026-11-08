# A5 Stand je Teil (Unterbrechung 08.11.2026, Mac-Neustart)

Berichte der vier A5-Agenten beim Anhalten. Nichts davon ist committet; die Dateien liegen im Arbeitsordner.
Auftrag: [`a5-auftrag.md`](a5-auftrag.md). Dateizuordnung: `status-A.md`, Abschnitt „Unterbrechung“.

## item (Artikel-Vollbild, Import)

| Datei | Stand |
|---|---|
| `translations/lists_item.dart` | fertig (Präfixe `list_item_`, `list_item_unit_`, `list_item_import_`, keine Doppelungen) |
| `widgets/item_editor_parts.dart` (neu) | halb: Fehler `:584` `kTouchSlop` unbekannt (`import 'package:flutter/gestures.dart';` fehlt), Info `:148` `library_private_types_in_public_api` (`covariant RenderObject` + Cast); kein Test |
| `item_editor_screen.dart` | halb: Code vollständig (`ItemEditorScreen` für Bearbeiten/Hinzufügen/Entwurf, `openItemDraftEditor`/`ItemDraft`, Löschen mit Rückgängig, offline/Fehler); kein Test. `openItemEditor` öffnet schon das D2-Vollbild |
| `widgets/item_form_dialog.dart` | nicht begonnen: zur Weiterleitung kürzen (`showItemFormDialog` → `openItemEditor`), `PaperPrimaryButton` vorerst behalten (Importe in `share_list_dialog.dart`, `list_detail_screen.dart`) |
| `widgets/attachment_sheet.dart`, `import_review_sheet.dart` | nicht begonnen (alte Bottom-Sheets) |
| Tests `test/screens/lists/item_editor_*`, `import_*` | nicht begonnen; `test/attachment_sheet_test.dart` erwartet alte Texte „Kamera / Fotos / Dateien“ |

Abweichung: „Artikel löschen“ ohne Rückfrage, mit Rückgängig (Konzept 11 §4). Für B: `ArticleImageCredit` und
`articleImagesShown` sind nicht über `b_slots.dart` exportiert (auch detail und shopping brauchen `articleImagesShown`,
sonst bleibt bei ausgeschalteten Bildern eine Lücke).

Nächste Schritte: (1) Analyse-Meldungen beheben, `item_form_dialog.dart` zur Weiterleitung. (2)
`item_editor_screen_test.dart` (layoutMatrix + Verhalten mit ersetzten Providern). (3) Import: `showAttachmentSheet` →
`AvoMenu` am Plus mit „Foto aufnehmen / Foto wählen / Datei wählen / Text einfügen“ + Status-Kapsel;
`showImportReviewSheet` → Vollbild „14 Artikel erkannt“ mit Häkchen, Hinzufügen über `addItems` mit Rückgängig; neu
`openListImport(context, listId:, anchorKey:)` für „detail“; Tests.

## detail (Liste)

**Baut nicht**: die alte `list_detail_screen.dart` nutzt Klassen, die in den Widget-Dateien schon ersetzt sind. Nicht
committen, bevor der Screen neu geschrieben ist.

| Datei | Stand |
|---|---|
| `widgets/list_detail_data.dart` (neu) | fertig: Provider für Liste, Mitglieder (`getListMembers`), Besitzer, Summe „≈ … €“, `ListDetailActions` (Aufrufe der anderen Teile) |
| `widgets/list_item_tile.dart` | fertig: `ListItemTile` (ItemRow, `ArticleImage`, `ItemOfferBadge`, Wischen löschen, Langdruck ziehen/Menü), `formatItemQuantity`, `itemSubtitle` |
| `widgets/list_drag_controller.dart` | fertig: Konstruktor braucht jetzt `vsync` |
| `widgets/list_category_section.dart` | fertig: `ListAisleSection` (SectionCaps + InsetSection + Ablegen); `ListCategorySection` entfernt; Import `list_item_tile.dart` evtl. unbenutzt |
| `widgets/list_detail_menu.dart` | fertig: neue `ListDetailMenuAction`-Werte, `listDetailMenuEntries(...)`; `ListDetailMenuButton` entfernt |
| `widgets/list_detail_parts.dart` | fertig: `ListDetailToolbar`, `ListDetailHeader`, `ListDoneSection`, `RenameListDialog` |
| `widgets/list_detail_composer.dart` (neu) | fertig: `AddItemAccessory` mit Summe und `OfferSuggestionsBar(listId:, query:, onAdded:)`, ohne Mikrofon |
| `list_detail_screen.dart` | nicht begonnen (alte Fassung; Fehler `:66` vsync, `:351–361`, `:376`, `:450`, `:462`) |
| `widgets/add_item_composer.dart` | nach dem Screen löschen (kein anderer Importeur) |
| `translations/lists_detail.dart` | leer; gebraucht: `list_detail_share`, `_shop`, `_progress`, `_done`, `_done_summary`, `_delete_item`, `_rows_count`, `_diet_warning`, `_add_placeholder`, `_add_hint`, `_menu_shop`, `_menu_checkout`, `_menu_info`, `_menu_rename`, `_menu_order`, `_menu_hide_offers`, `_menu_show_offers`, `_menu_import`, `_menu_delete`, `_menu_leave`, `list_detail_unit_*` (pcs, kg, g, l, ml, dozen, pack, bottle, can, box, bunch) |
| Tests | nicht begonnen; `add_item_composer_test.dart` wird A3-Nachweis für `ListDetailComposer` |

Nächste Schritte: (1) Screen aus den Teilen neu schreiben (Toolbar mit Teilen+Mehr als `GlassButtonGroup`, Gänge,
Erledigt eingeklappt, Abhaken mit Rückgängig, Löschen nach Ablauf des Rückgängig-Fensters, `parseItemInput`+`addItems`,
`avoScreenContextProvider`, `?focus=add`, Zustände), dann `add_item_composer.dart` löschen. (2) Schlüssel eintragen,
analyze 0/0/0. (3) Tests. Offen: Präsenz-Datenquelle fehlt; `AvoToast` verdeckt kurz das Eingabefeld; `lists_routes.dart`
könnte `focusAdd` durchreichen.

## shopping (Einkaufsmodus)

| Datei | Stand |
|---|---|
| `translations/lists_shopping.dart` | fertig (Präfix `list_shop_`) |
| `widgets/shopping_mode_{aisles,header,bars,view}.dart` | fertig (Gänge in Kategorie-Reihenfolge, Kopf mit `StoreChip`/rollender Zahl/`ListOfferSummary`, Leisten, Abhaken mit Haptik, alle Zustände) |
| `shopping_mode_screen.dart` | fertig (Bildschirm bleibt an, Avo-Kontext, `openCheckoutFlow` → Erfolgsmoment) |
| `routes/areas/lists_routes.dart` | fertig (`list-shopping` im Root-Navigator); letzte Info-Korrektur nicht neu geprüft |
| `test/routes/app_routes_test.dart` | Zeile `list-shopping` nur im Arbeitsordner |
| `shopping_trip_completion.dart` | bewusst unverändert (B's `checkout_flow.dart` braucht `completeShoppingTrip`) |
| `test/screens/lists/shopping_mode_aisles_test.dart` | fertig, 5 grün |
| `test/screens/lists/shopping_mode_view_test.dart` | geschrieben (13), nie gelaufen |
| Layout- und Screen-Test | nicht begonnen |

Nächste Schritte: (1) analyze + Tests (`shopping_mode_*`, `test/routes/`). (2) Layout- und Screen-Test. (3) committen.
Offen: keine Präsenz-Datenquelle (`shoppingCompanionsProvider` meldet niemanden, `list_presence_service.dart` fehlt), kein
`checked_by` („gerade abgehakt“ ohne Namen), keine Gang-Nummern je Markt, Abhaken offline wird zurückgerollt statt
vorgemerkt.

## overview (Listen-Übersicht, Teilen, Listen-Info)

offen (Bericht ausstehend)
