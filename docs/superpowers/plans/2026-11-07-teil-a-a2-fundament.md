# A2 Fundament (S2) – Detailplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** D2-Designsystem als Flutter-Bausteine, D2-Tab-Bar mit 5 Tabs, Prüfgerüst – damit A und B ihre Screens darauf
umbauen können (Meilenstein S2).

**Architecture:** Tokens in `lib/core/design/` (eine Import-Datei `design.dart`), Komponenten in
`lib/presentation/widgets/design/` (eine Datei je Komponente, jede mit Widget-Test und `layoutMatrix`), Shell in
`main_scaffold.dart` + `routes/`. Glas nativ nur auf der schwebenden Ebene (Tab-Bar, Toolbar, Eingabe), im Inhalt
günstiges Pseudo-Glas ohne Platform View und ohne `BackdropFilter`.

**Tech Stack:** Flutter, Riverpod 2, GoRouter 13, `adaptive_platform_ui`, `LiquidGlassViewFactory.swift`.

**Spec:** `docs/redesign/prompt-teil-A.md` A2, `docs/redesign/design-quelle.md`, D2-Artboard `D2-Komponenten`,
Konzept 00 Kap. 10–15, 01, 20 (Prüfmatrix, Tempo).

## Global Constraints

- Keine Hex-Werte, Schriftgrößen oder Dauern in Screens; D2-Einzelmaße einer Komponente als private Konstante mit
  Kommentar „D2“.
- Text nie in fester Höhe; nur Mindesthöhen. Jede Komponente besteht `layoutMatrix` (320–440 pt, 1,0–3,1×, fett, dunkel,
  Kontrast).
- Touch-Ziele ≥ 44 pt; Semantics (Rolle, Zustand, Label); Dekor aus VoiceOver ausgeblendet.
- Federn aus `AvoMotion`, unterbrechbar; Reduce Motion → Überblendung oder keine Bewegung.
- Haptik nur über `AvoHaptics`. Keine Sheets, Drawer oder Schieberegler.
- Texte über `common_*`-Schlüssel oder Parameter; Agenten ändern keine Übersetzungsdateien.

## Review Focus

1. AX5 auf 320 pt: Zeilen mit Bild, Badge und Stepper brechen um, nichts überlappt.
2. Reduce Transparency/Increase Contrast: Glas wird deckend, Text bleibt ≥ 4,5:1.
3. Schnelles Antippen während einer Animation (Haken, Segment, Stepper): Bewegung startet vom aktuellen Wert.
4. VoiceOver: jeder Knopf hat ein Label, Zustände (ausgewählt, erledigt) werden angesagt.
5. Dunkelmodus: keine hellen Restflächen, Schatten nicht schwarz auf schwarz.

---

### Task 1: Tokens, Theme auf iOS, Paletten, Prüfgerüst, gemeinsame Texte – erledigt

- [x] `lib/core/design/` (`AvoColors`, `AvoTypography`, `AvoSpacing`/`AvoRadii`/`AvoSizes`/`ShellInsets`, `AvoMotion`,
      `AvoHaptics`, `AvoDesignScope`, `design.dart`), Tests in `test/core/design/` (Kontraste in 4 Varianten,
      Dynamic-Type-Tabellen, Federn)
- [x] `app.dart`/`app_theme.dart`: Cupertino- und Material-Theme aus Tokens, kein Remount-Schlüssel
- [x] `AppColors`/`PaperColors`/`PaperTextStyles` zeigen D2-Werte, keine Serife, kein Satoshi
- [x] `test/layout/layout_matrix.dart` + Selbsttest; `common_*`-Texte

### Task 2: Komponenten Phase 1 (parallel, Workflow)

| Paket | Dateien in `lib/presentation/widgets/design/` | Öffentliche API |
|---|---|---|
| Icons | `avo_icons.dart` | `AvoIconData`, `AvoIcons.{home, cart, sparkle, forkKnife, person, chevronBack, chevronRight, chevronDown, share, more, plus, minus, mic, check, tag, trash, clock, search, xmark, calendar, keyboard, people}`, `AvoIcon(icon, {size, color, filled, strokeWidth})` |
| Glas, Buttons, Toolbar | `glass_surface.dart`, `app_button.dart`, `glass_icon_button.dart`, `glass_toolbar.dart` | `GlassShape`, `GlassSurface`, `ContentGlass`, `AppButton.{primary, secondary, plain, destructive}`, `AppButtonSize`, `GlassIconButton`, `GlassButtonGroup`, `GlassGroupItem`, `GlassToolbar`, `ScrollEdgeFade` |
| Bedienelemente | `check_circle.dart`, `value_stepper.dart`, `rolling_number.dart`, `segmented_control.dart`, `filter_chip.dart`, `progress.dart`, `search_field.dart` | `CheckCircle`, `CheckCircleSize`, `CheckState`, `ValueStepper`, `RollingNumber`, `AppSegmentedControl<T>`, `SegmentItem<T>`, `AppFilterChip`, `ChipRow`, `ProgressLine`, `ProgressRing`, `AvoSearchField` |
| Zeilen und Zustände | `inset_section.dart`, `settings_rows.dart`, `hint_row.dart`, `status_row.dart`, `empty_state.dart`, `skeleton.dart`, `confirm_dialog.dart`, `undo_toast.dart`, `pro_badge.dart`, `avo_figure.dart`, `success_moment.dart`, `module_off_alert.dart` | `InsetSection`, `SectionCaps`, `NavRow`, `ToggleRow`, `ValueRow`, `DestructiveRow`, `HintRow`, `StatusRow`, `StatusKind`, `EmptyState`, `SkeletonSection`, `showAvoConfirm`, `AvoToast`, `AvoToastHost`, `ProBadge`, `AvoPose`, `AvoFigure`, `showSuccessMoment`, `showModuleOffAlert` |

### Task 3: Komponenten Phase 2 (parallel, nach Phase 1)

| Paket | Dateien | Öffentliche API |
|---|---|---|
| Liste, Rezept, Editor | `item_row.dart`, `list_card.dart`, `avatar.dart`, `quick_add_tile.dart`, `recipe_card.dart`, `full_screen_editor.dart` | `ItemRow`, `ItemRowState`, `ItemThumb`, `ListCard`, `ListRow`, `Avatar`, `AvatarStack`, `PresenceDot`, `QuickAddTile`, `RecipeCard`, `RecipeCardStyle`, `RecipeHeroCard`, `GlassInfoPanel`, `FullScreenEditor` |
| Eingabe und Menüs | `add_item_accessory.dart`, `avo_menu.dart` | `AddItemAccessory` (Regel L-04, A3-sicher), `AvoMenuItem`, `AvoMenuButton`, `showAvoMenu` |

### Task 4: Komponenten-Galerie (Debug-Route `/debug/components`)

- [ ] `lib/presentation/widgets/design/gallery/component_gallery.dart`: jede Komponente hell, dunkel, AX5;
      Route nur in Debug-Builds (`kDebugMode`)

### Task 5: Shell mit D2-Tab-Bar

**Files:** `lib/presentation/widgets/design/app_tab_bar.dart`, `lib/presentation/screens/main_scaffold.dart`,
`lib/app.dart`, `lib/routes/app_router.dart`, `lib/routes/areas/*_routes.dart` (A), Test `test/routes/`,
`test/presentation/widgets/design/app_tab_bar_test.dart`.

- [ ] Test: 5 Branches Home, Listen, Avo, Rezepte, Profil; `/lists` und `/lists/:listId` im Listen-Branch, `/avo` im
      Avo-Branch, `/calories` als Push im Home-Branch; alle alten Pfade lösen weiter auf; unbekannter Pfad →
      Fehlerseite; Avo-Modul aus → Tab weg, `/avo` zeigt Modul-Alert
- [ ] `AppTabBar` nach D2 (Glas-Kapsel 64, Items 56, aktiver Schein, Icons 26, Label 11/13), keine Haptik, erneutes
      Tippen → Wurzel; ab AX1 Large Content Viewer statt größerer Labels; Semantics „Tab, 1 von 5, ausgewählt“
- [ ] `MainScaffold` ohne Slide-Animation (IndexedStack/Offstage), `ShellInsets` statt Messung,
      `getNavbarClearance` als veraltete Weiterleitung für B, Tastatur blendet Leiste aus
- [ ] Listen-Übersicht als Wurzel des Listen-Tabs (bis A5 der vorhandene Listen-Teil von Home)

### Task 6: Abschluss S2

- [ ] Konzepttreue-Review (Apple-Treue, Barrierefreiheit, Tempo, Regressionen), Funde beheben
- [ ] Palette hell/dunkel/Kontrast dem Owner zeigen (Abhak-Ring-Frage)
- [ ] Designsystem-Abschnitt in `CLAUDE.md` (eigener Commit, sofort pushen)
- [ ] `status-A.md` S2, pushen, „Jannis kann pullen“
