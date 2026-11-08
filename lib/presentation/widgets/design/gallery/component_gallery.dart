import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/theme/app_theme.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/app_tab_bar.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/bar_chart.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/module_off_alert.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';
import 'package:shoply/presentation/widgets/design/quick_add_tile.dart';
import 'package:shoply/presentation/widgets/design/recipe_card.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/success_moment.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

/// Linear text scale of AX5, the largest case of the layout matrix.
const double _kAx5Scale = 3.1;

/// Settings icon tile in front of a row title (D2: 30 pt, radius 8, glyph 18).
const double _kIconTile = 30; // D2
const double _kIconTileRadius = 8; // D2
const double _kIconTileGlyph = 18; // D2

/// Height of the photo band of the edge-to-edge card example.
const double _kPhotoBand = 96;

/// Space above the glass info panel, so the photo shows behind it.
const double _kPanelPhotoTop = 72;

/// Size of the figures and rings in the gallery.
const double _kFigureSize = 96;
const double _kRingLarge = 96;
const double _kIconPreview = 26;

void _noop() {}

/// How the gallery renders its content.
enum ComponentGalleryMode {
  /// Light at the default text size (Large), as in the D2 artboards.
  light('Hell'),

  /// Dark at the default text size.
  dark('Dunkel'),

  /// Light at AX5 (linear text scale 3.1).
  ax5('AX5'),

  /// Light with Increase Contrast and Reduce Transparency: glass is opaque.
  contrast('Kontrast');

  const ComponentGalleryMode(this.label);

  /// Label in the mode switch.
  final String label;

  /// The brightness this mode renders in.
  Brightness get brightness =>
      this == ComponentGalleryMode.dark ? Brightness.dark : Brightness.light;
}

/// Debug gallery of every component in `lib/presentation/widgets/design/`,
/// to compare them with the D2 artboard "D2-Komponenten" (route
/// `/debug/components`, debug builds only).
///
/// A segmented control at the top switches the content between light, dark,
/// AX5 and Increase Contrast. The gallery sets these itself (its own
/// [MediaQuery], [Theme] and [AvoDesignScope], see [ComponentGalleryScope]),
/// so it works inside the running app whatever the device is set to. Dialogs,
/// menus and the success moment open on the root navigator and therefore show
/// in the app's own appearance; toasts and the full-screen editor follow the
/// gallery's mode.
class ComponentGallery extends StatefulWidget {
  /// Creates the gallery.
  const ComponentGallery({
    super.key,
    this.initialMode = ComponentGalleryMode.light,
  });

  /// The mode the gallery starts in.
  final ComponentGalleryMode initialMode;

  /// Key of the scroll view that holds the components (tests scroll it).
  static const Key scrollKey = ValueKey<String>('component-gallery-scroll');

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  late ComponentGalleryMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canPop = Navigator.of(context).canPop();
    return ColoredBox(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AvoSpacing.screen,
                AvoSpacing.s,
                AvoSpacing.screen,
                AvoSpacing.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (canPop) ...[
                        GlassIconButton(
                          icon: AvoIcon(
                            AvoIcons.chevronBack,
                            color: colors.label,
                          ),
                          semanticLabel: 'Zurück',
                          floating: false,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: AvoSpacing.m),
                      ],
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Komponenten',
                            style: context.text(AvoTextStyle.title2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AvoSpacing.m),
                  AppSegmentedControl<ComponentGalleryMode>(
                    segments: [
                      for (final mode in ComponentGalleryMode.values)
                        SegmentItem(value: mode, label: mode.label),
                    ],
                    selected: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                    semanticLabel: 'Darstellung',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ComponentGalleryScope(
                mode: _mode,
                child: AvoToastHost(child: _GalleryBody(mode: _mode)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [child] in [mode]: brightness, text size and contrast in its own
/// [MediaQuery], the matching Material and Cupertino themes, and
/// [AvoDesignScope] with Reduce Transparency forced on for
/// [ComponentGalleryMode.contrast] and off otherwise.
class ComponentGalleryScope extends StatelessWidget {
  /// Creates the scope.
  const ComponentGalleryScope({
    super.key,
    required this.mode,
    required this.child,
  });

  /// The appearance to render in.
  final ComponentGalleryMode mode;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = mode.brightness;
    final contrast = mode == ComponentGalleryMode.contrast;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        platformBrightness: brightness,
        textScaler: TextScaler.linear(
          mode == ComponentGalleryMode.ax5 ? _kAx5Scale : 1,
        ),
        highContrast: contrast,
      ),
      child: AvoDesignScope(
        reduceTransparencyOverride: contrast,
        child: Theme(
          data: AppTheme.of(brightness),
          child: CupertinoTheme(
            data: brightness == Brightness.dark
                ? AppTheme.cupertinoDark
                : AppTheme.cupertinoLight,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GalleryBody extends StatefulWidget {
  const _GalleryBody({required this.mode});

  final ComponentGalleryMode mode;

  @override
  State<_GalleryBody> createState() => _GalleryBodyState();
}

class _GalleryBodyState extends State<_GalleryBody> {
  static const _chipLabels = [
    'Vegetarisch',
    'Unter 30 Minuten',
    'Ohne Nüsse und Erdnüsse',
    'Saisonal',
    'Glutenfrei',
  ];

  bool _milk = false;
  bool _lena = false;
  int _quantity = 2;
  int _portions = 4;
  String _sort = 'kategorie';
  String _view = 'rezepte';
  String _range = 'alle';
  final Set<String> _chips = {'Vegetarisch'};
  bool _notify = true;
  final List<bool> _items = [false, true];
  int _tab = 1;
  final TextEditingController _longEntry = TextEditingController(
    text:
        '2 Packungen laktosefreie Bio-Vollmilch 1,5 % Fett von der '
        'Molkerei Berchtesgadener Land',
  );

  @override
  void dispose() {
    _longEntry.dispose();
    super.dispose();
  }

  void _toast(BuildContext context, String message) =>
      AvoToast.show(context, message: message);

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showAvoConfirm(
      context,
      title: 'Liste „Wocheneinkauf“ löschen?',
      message:
          'Die Liste verschwindet auch bei Lena und Maximilian. Das lässt '
          'sich nicht rückgängig machen.',
      confirmLabel: 'Löschen',
    );
    if (!context.mounted || !confirmed) return;
    _toast(context, 'Liste gelöscht');
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showAvoConfirm(
      context,
      title: 'Abmelden?',
      message:
          '2 Änderungen sind noch nicht gesendet. Wenn du dich jetzt '
          'abmeldest, gehen sie verloren.',
      confirmLabel: 'Abmelden',
    );
    if (!context.mounted || !confirmed) return;
    _toast(context, 'Abgemeldet (nur Galerie)');
  }

  void _openEditor(BuildContext context) {
    final mode = widget.mode;
    pushFullScreenEditor<void>(
      context,
      (_) => ComponentGalleryScope(mode: mode, child: const _EditorDemo()),
    );
  }

  List<AvoMenuEntry> _menuItems(BuildContext context) => [
    AvoMenuItem(
      label: 'Liste teilen',
      icon: AvoIcons.share,
      onSelected: () => _toast(context, 'Liste geteilt'),
    ),
    const AvoMenuItem(label: 'Umbenennen', onSelected: _noop),
    const AvoMenuDivider(),
    AvoMenuItem(
      label: 'Nach Kategorie sortieren',
      checked: _sort == 'kategorie',
      onSelected: () => setState(() => _sort = 'kategorie'),
    ),
    AvoMenuItem(
      label: 'Nach Laden sortieren',
      checked: _sort == 'laden',
      onSelected: () => setState(() => _sort = 'laden'),
    ),
    const AvoMenuItem(
      label: 'Als Vorlage speichern',
      subtitle: 'Gerade nicht verfügbar',
      enabled: false,
      onSelected: _noop,
    ),
    const AvoMenuDivider(),
    AvoMenuItem(
      label: 'Liste löschen',
      subtitle: 'Für alle 4 Mitglieder',
      icon: AvoIcons.trash,
      destructive: true,
      onSelected: () => _confirmDelete(context),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.background,
      child: ListView(
        key: ComponentGallery.scrollKey,
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + AvoSpacing.xxxl,
        ),
        children: [
          ..._glass(context),
          ..._controls(context),
          ..._rows(context),
          ..._home(context),
          ..._list(context),
          ..._recipe(context),
          ..._charts(context),
          ..._input(context),
          ..._menu(context),
          ..._feedback(context),
        ],
      ),
    );
  }

  // --- Glas, Buttons, Toolbar -------------------------------------------------

  List<Widget> _glass(BuildContext context) {
    final colors = context.colors;
    Widget back() => GlassIconButton(
      icon: AvoIcon(AvoIcons.chevronBack, color: colors.label),
      semanticLabel: 'Zurück',
      onPressed: _noop,
    );
    GlassButtonGroup group() => GlassButtonGroup(
      items: [
        GlassGroupItem(
          icon: AvoIcon(AvoIcons.share, color: colors.label),
          semanticLabel: 'Teilen',
          onPressed: _noop,
        ),
        GlassGroupItem(
          icon: AvoIcon(AvoIcons.more, color: colors.label),
          semanticLabel: 'Mehr',
          onPressed: _noop,
        ),
      ],
    );
    return [
      const _GroupHeader('Glas, Buttons, Toolbar'),
      _Demo(
        'AppButton',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _States([
              AppButton.primary(
                label: 'Zutaten auf die Liste',
                icon: AvoIcon(AvoIcons.plus, color: colors.onTint),
                onPressed: _noop,
              ),
              AppButton.secondary(
                label: 'Teilen',
                icon: AvoIcon(AvoIcons.share, color: colors.label),
                onPressed: _noop,
              ),
              const AppButton.plain(label: 'Alle anzeigen', onPressed: _noop),
              const AppButton.destructive(
                label: 'Liste löschen',
                onPressed: _noop,
              ),
            ]),
            const SizedBox(height: AvoSpacing.m),
            const _States([
              _Labeled(
                'arbeitet',
                child: AppButton.primary(
                  label: 'Speichern',
                  working: true,
                  workingLabel: 'Wird gespeichert',
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                'deaktiviert',
                child: AppButton.primary(label: 'Speichern'),
              ),
              _Labeled(
                'deaktiviert',
                child: AppButton.secondary(label: 'Teilen'),
              ),
            ]),
            const SizedBox(height: AvoSpacing.m),
            const AppButton.primary(
              label: 'Einkauf abschließen',
              size: AppButtonSize.large,
              expand: true,
              onPressed: _noop,
            ),
            const SizedBox(height: AvoSpacing.m),
            const AppButton.secondary(
              label:
                  'Alle fehlenden Zutaten für die Shakshuka mit Feta auf die '
                  'Wocheneinkaufsliste setzen',
              expand: true,
              onPressed: _noop,
            ),
          ],
        ),
      ),
      _Demo(
        'GlassSurface und ContentGlass',
        child: _Backdrop(
          child: _States([
            _Labeled(
              'Inhalt',
              child: ContentGlass(
                padding: _chipPadding,
                child: _ChipText('4 von 6 Zutaten da', color: colors.label),
              ),
            ),
            _Labeled(
              'Inhalt getönt',
              child: ContentGlass(
                tinted: true,
                padding: _chipPadding,
                child: _ChipText('Zutaten auf die Liste', color: colors.onTint),
              ),
            ),
            _Labeled(
              'schwebend',
              child: GlassSurface(
                padding: _chipPadding,
                child: _ChipText('Mit Lena geteilt', color: colors.label),
              ),
            ),
            _Labeled(
              'schwebend getönt',
              child: GlassSurface(
                tinted: true,
                padding: _chipPadding,
                child: _ChipText('Fertig', color: colors.onTint),
              ),
            ),
            _Labeled(
              'Kreis',
              child: GlassSurface(
                shape: GlassShape.circle,
                child: SizedBox.square(
                  dimension: AvoSizes.toolbarButton,
                  child: Center(
                    child: AvoIcon(AvoIcons.plus, color: colors.label),
                  ),
                ),
              ),
            ),
            _Labeled(
              'abgerundet',
              child: GlassSurface(
                shape: GlassShape.rounded,
                padding: const EdgeInsets.all(AvoSpacing.m),
                child: _ChipText('Infotafel', color: colors.label),
              ),
            ),
          ]),
        ),
      ),
      _Demo(
        'GlassIconButton und GlassButtonGroup',
        child: _Backdrop(
          child: _States([
            _Labeled('schwebend', child: back()),
            _Labeled(
              'getönt',
              child: GlassIconButton(
                icon: AvoIcon(AvoIcons.plus, color: colors.onTint),
                semanticLabel: 'Neue Liste',
                tinted: true,
                onPressed: _noop,
              ),
            ),
            _Labeled(
              'im Inhalt',
              child: GlassIconButton(
                icon: AvoIcon(AvoIcons.share, color: colors.label),
                semanticLabel: 'Teilen',
                floating: false,
                onPressed: _noop,
              ),
            ),
            _Labeled(
              'deaktiviert',
              child: GlassIconButton(
                icon: AvoIcon(AvoIcons.trash, color: colors.label),
                semanticLabel: 'Löschen',
              ),
            ),
            _Labeled('Gruppe', child: group()),
          ]),
        ),
      ),
      _Demo(
        'GlassToolbar',
        inset: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassToolbar(
              leading: back(),
              title: 'Laktosefreie Bio-Vollmilch',
              trailing: const [
                AppButton.primary(
                  label: 'Fertig',
                  floating: true,
                  onPressed: _noop,
                ),
              ],
            ),
            const SizedBox(height: AvoSpacing.m),
            GlassToolbar(
              leading: back(),
              trailing: [
                group(),
                GlassIconButton(
                  icon: AvoIcon(AvoIcons.plus, color: colors.onTint),
                  semanticLabel: 'Neue Liste',
                  tinted: true,
                  onPressed: _noop,
                ),
              ],
            ),
          ],
        ),
      ),
      _Demo(
        'ScrollEdgeFade',
        inset: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AvoSpacing.screen,
                AvoSpacing.xxxl,
                AvoSpacing.screen,
                AvoSpacing.l,
              ),
              child: Text(
                'Wocheneinkauf · 12 Artikel · 23,80 €',
                style: context.text(AvoTextStyle.largeTitle),
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ScrollEdgeFade(),
            ),
          ],
        ),
      ),
      _Demo(
        'AppTabBar',
        child: AppTabBar(
          items: const [
            AppTabItem(icon: AvoIcons.home, label: 'Home'),
            AppTabItem(icon: AvoIcons.cart, label: 'Listen'),
            AppTabItem(icon: AvoIcons.sparkle, label: 'Avo'),
            AppTabItem(icon: AvoIcons.forkKnife, label: 'Rezepte'),
            AppTabItem(icon: AvoIcons.person, label: 'Profil'),
          ],
          selectedIndex: _tab,
          onSelect: (index) => setState(() => _tab = index),
        ),
      ),
    ];
  }

  // --- Bedienelemente ---------------------------------------------------------

  List<Widget> _controls(BuildContext context) {
    final colors = context.colors;
    final ringText = context.text(AvoTextStyle.footnote, tabular: true);
    return [
      const _GroupHeader('Bedienelemente'),
      _Demo(
        'CheckCircle',
        child: _States([
          _Labeled(
            'offen',
            child: CheckCircle(
              checked: _milk,
              itemName: 'Milch',
              onChanged: (value) => setState(() => _milk = value),
            ),
          ),
          _Labeled(
            'erledigt',
            child: CheckCircle(
              checked: true,
              itemName: 'Eier',
              onChanged: (_) {},
            ),
          ),
          _Labeled(
            'von Lena (tippen)',
            child: CheckCircle(
              checked: _lena,
              itemName: 'Vollkornbrot',
              state: _lena ? CheckState.doneByOther : CheckState.open,
              byName: 'Lena',
              statusLabel: _lena ? 'von Lena' : null,
              onChanged: (value) => setState(() => _lena = value),
            ),
          ),
          _Labeled(
            'wartet',
            child: CheckCircle(
              checked: true,
              itemName: 'Butter',
              state: CheckState.pending,
              statusLabel: 'Wartet auf Verbindung',
              onChanged: (_) {},
            ),
          ),
          _Labeled(
            'Fehler',
            child: CheckCircle(
              checked: false,
              itemName: 'Bergkäse',
              state: CheckState.failed,
              onChanged: (_) {},
            ),
          ),
          const _Labeled(
            'deaktiviert',
            child: CheckCircle(checked: false, itemName: 'Salz'),
          ),
          _Labeled(
            'groß',
            child: CheckCircle(
              checked: _milk,
              itemName: 'Milch',
              size: CheckCircleSize.large,
              onChanged: (value) => setState(() => _milk = value),
            ),
          ),
          _Labeled(
            'groß erledigt',
            child: CheckCircle(
              checked: true,
              itemName: 'Eier',
              size: CheckCircleSize.large,
              onChanged: (_) {},
            ),
          ),
        ]),
      ),
      _Demo(
        'ValueStepper und RollingNumber',
        child: _States([
          _Labeled(
            'normal',
            child: ValueStepper(
              value: _quantity,
              min: 1,
              max: 20,
              unit: 'St.',
              semanticLabel: 'Menge',
              onChanged: (value) => setState(() => _quantity = value),
            ),
          ),
          _Labeled(
            'kompakt',
            child: ValueStepper(
              value: _portions,
              min: 1,
              max: 12,
              compact: true,
              unit: 'Pers.',
              semanticLabel: 'Portionen',
              onChanged: (value) => setState(() => _portions = value),
            ),
          ),
          _Labeled(
            'am Minimum',
            child: ValueStepper(
              value: 0,
              semanticLabel: 'Menge',
              onChanged: (_) {},
            ),
          ),
          _Labeled(
            'RollingNumber (Menge × 1,29 €)',
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                RollingNumber(
                  value: _quantity * 1.29,
                  fractionDigits: 2,
                  locale: 'de',
                  style: context.text(AvoTextStyle.title1),
                ),
                Text(' €', style: context.text(AvoTextStyle.title1)),
              ],
            ),
          ),
        ]),
      ),
      _Demo(
        'AppSegmentedControl',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSegmentedControl<String>(
              segments: const [
                SegmentItem(value: 'liste', label: 'Liste'),
                SegmentItem(value: 'kategorie', label: 'Kategorie'),
                SegmentItem(value: 'laden', label: 'Laden'),
              ],
              selected: _sort,
              semanticLabel: 'Sortieren nach',
              onChanged: (value) => setState(() => _sort = value),
            ),
            const SizedBox(height: AvoSpacing.m),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppSegmentedControl<String>(
                segments: const [
                  SegmentItem(value: 'rezepte', label: 'Rezepte'),
                  SegmentItem(value: 'plan', label: 'Wochenplan'),
                ],
                selected: _view,
                compact: true,
                semanticLabel: 'Ansicht',
                onChanged: (value) => setState(() => _view = value),
              ),
            ),
            const SizedBox(height: AvoSpacing.m),
            AppSegmentedControl<String>(
              segments: const [
                SegmentItem(value: 'alle', label: 'Alle Lebensmittel'),
                SegmentItem(
                  value: 'angebote',
                  label: 'Nur Angebote dieser Woche',
                ),
              ],
              selected: _range,
              semanticLabel: 'Anzeigen',
              onChanged: (value) => setState(() => _range = value),
            ),
          ],
        ),
      ),
      _Demo(
        'AppFilterChip und ChipRow',
        inset: false,
        child: ChipRow(
          chips: [
            for (final label in _chipLabels)
              AppFilterChip(
                label: label,
                selected: _chips.contains(label),
                onSelected: (on) => setState(
                  () => on ? _chips.add(label) : _chips.remove(label),
                ),
              ),
            const AppFilterChip(label: 'Deaktiviert', selected: false),
            AppFilterChip(
              label: 'Zurücksetzen',
              selected: false,
              onSelected: _chips.isEmpty ? null : (_) => setState(_chips.clear),
            ),
          ],
        ),
      ),
      _Demo(
        'ProgressLine und ProgressRing',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProgressLine(
              value: 8 / 12,
              semanticLabel: 'Fortschritt',
              semanticValue: '8 von 12',
            ),
            const SizedBox(height: AvoSpacing.l),
            _States([
              const _Labeled(
                '44 pt',
                child: ProgressRing(value: 0.62, semanticLabel: 'Fortschritt'),
              ),
              _Labeled(
                'mit Inhalt',
                child: ProgressRing(
                  value: 0.68,
                  size: _kRingLarge,
                  semanticLabel: 'Kalorien',
                  semanticValue: '640 kcal übrig',
                  center: Text(
                    '640\nkcal übrig',
                    textAlign: TextAlign.center,
                    style: ringText,
                  ),
                ),
              ),
              _Labeled(
                'überschritten',
                child: ProgressRing(
                  value: 1.06,
                  size: _kRingLarge,
                  over: true,
                  semanticLabel: 'Kalorien',
                  semanticValue: '120 kcal drüber',
                  center: Text(
                    '120\nkcal drüber',
                    textAlign: TextAlign.center,
                    style: ringText.copyWith(color: colors.destructive),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
      const _Demo(
        'AvoSearchField',
        child: AvoSearchField(hint: 'Rezepte, Zutaten oder Listen suchen'),
      ),
    ];
  }

  // --- Zeilen und Zustände ----------------------------------------------------

  List<Widget> _rows(BuildContext context) {
    final colors = context.colors;
    final caps = context.text(AvoTextStyle.sectionCaps);
    return [
      const _GroupHeader('Zeilen und Zustände'),
      _Demo(
        'InsetSection, NavRow, ToggleRow, ValueRow',
        inset: false,
        child: InsetSection(
          header: 'Allgemein',
          footer:
              'Mitteilungen kommen nur zu Listen, die du mit anderen teilst.',
          children: [
            NavRow(
              title: 'Sprache',
              value: 'Automatisch',
              leading: const _IconTile(AvoIcons.people),
              onTap: _noop,
            ),
            NavRow(
              title: 'Wochenplan',
              subtitle: 'Jeden Sonntag eine Einkaufsliste aus deinen Rezepten',
              pro: true,
              leading: const _IconTile(AvoIcons.calendar),
              onTap: _noop,
            ),
            const NavRow(
              title: 'Lieblingsladen (deaktiviert)',
              value: 'Lidl, Ulmer Straße 12',
            ),
            ToggleRow(
              title: 'Mitteilungen bei Änderungen an geteilten Listen',
              subtitle: 'Zum Beispiel wenn Lena etwas abhakt',
              value: _notify,
              leading: const _IconTile(AvoIcons.clock),
              onChanged: (value) => setState(() => _notify = value),
            ),
            ToggleRow(
              title: 'Standort für Angebote',
              value: false,
              enabled: false,
              onChanged: (_) {},
            ),
            const ValueRow(title: 'Version', value: '4.2.0 (1187)'),
          ],
        ),
      ),
      _Demo(
        'InsetSection flach mit Zähler',
        inset: false,
        child: InsetSection(
          header: 'Kühlregal',
          headerTrailing: const Text('3'),
          plain: true,
          children: [
            const NavRow(title: 'Griechischer Joghurt 10 %', onTap: _noop),
            const NavRow(title: 'Süßrahmbutter', onTap: _noop),
            NavRow(title: 'Konto löschen', destructive: true, onTap: _noop),
          ],
        ),
      ),
      _Demo(
        'DestructiveRow',
        inset: false,
        child: InsetSection(
          children: [
            DestructiveRow(
              title: 'Abmelden',
              onTap: () => _confirmSignOut(context),
            ),
          ],
        ),
      ),
      _Demo(
        'SectionCaps',
        inset: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionCaps('Obst & Gemüse', trailing: Text('12')),
            SectionCaps(
              'Zuletzt gekauft bei Lidl in der Ulmer Straße',
              trailing: Text('Alle', style: caps.copyWith(color: colors.tint)),
            ),
          ],
        ),
      ),
      _Demo(
        'HintRow',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HintRow(
              text:
                  'Lidl lohnt sich diese Woche: drei Artikel deiner Liste sind '
                  'dort im Angebot, zusammen 4,20 € günstiger.',
              leading: AvoFigure(pose: AvoPose.thinking, size: 44),
              actionLabel: 'Angebote ansehen',
              onTap: _noop,
              onDismiss: _noop,
              dismissLabel: 'Hinweis schließen',
            ),
            const SizedBox(height: AvoSpacing.m),
            HintRow(
              text:
                  'Halte einen Artikel gedrückt, um Menge, Laden oder '
                  'Kategorie zu ändern.',
              leading: const _IconTile(AvoIcons.sparkle),
              onDismiss: _noop,
            ),
          ],
        ),
      ),
      _Demo(
        'StatusRow',
        inset: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StatusRow(
              kind: StatusKind.offline,
              text:
                  'Offline. Deine Änderungen werden gespeichert, sobald du '
                  'wieder online bist.',
            ),
            const StatusRow(
              kind: StatusKind.pending,
              text: 'Offline. 3 Änderungen warten.',
            ),
            const StatusRow(
              kind: StatusKind.sending,
              text: '3 Änderungen werden gesendet.',
            ),
            StatusRow(
              kind: StatusKind.failed,
              text: '1 Änderung konnte nicht gespeichert werden.',
              actionLabel: 'Erneut versuchen',
              onAction: () => _toast(context, 'Wird erneut gesendet'),
            ),
            const StatusRow(
              kind: StatusKind.sectionError,
              text: 'Das lässt sich gerade nicht laden.',
              actionLabel: 'Erneut versuchen',
              onAction: _noop,
            ),
            const StatusRow(
              kind: StatusKind.permission,
              text: 'Standort ist aus. Angebote in deiner Nähe brauchen ihn.',
              actionLabel: 'In Einstellungen erlauben',
              onAction: _noop,
            ),
          ],
        ),
      ),
      _Demo(
        'EmptyState',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EmptyState(
              title: 'Noch nichts auf der Liste.',
              message:
                  'Tippe unten auf „Artikel hinzufügen“ oder sag Avo, was '
                  'fehlt.',
              actionLabel: 'Rezept als Liste übernehmen',
              onAction: _noop,
              pose: AvoPose.waving,
            ),
            EmptyState(
              title: 'Keine Treffer für „Hafermilch ungesüßt“.',
              message:
                  'Prüf die Schreibweise oder such nach einem allgemeineren '
                  'Begriff.',
              icon: AvoIcon(
                AvoIcons.search,
                size: 48,
                color: colors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
      const _Demo(
        'SkeletonSection',
        inset: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonSection(),
            SizedBox(height: AvoSpacing.l),
            SkeletonSection(
              rows: 2,
              withImage: false,
              loadingLabel: 'Angebote werden geladen',
            ),
          ],
        ),
      ),
      _Demo(
        'ProBadge',
        child: _States([
          MergeSemantics(
            child: Wrap(
              spacing: AvoSpacing.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Wochenplan', style: context.text(AvoTextStyle.body)),
                const ProBadge(),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.tintFill,
              borderRadius: BorderRadius.circular(AvoRadii.card),
            ),
            child: Padding(
              padding: _chipPadding,
              child: MergeSemantics(
                child: Wrap(
                  spacing: AvoSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Avo Pro testen',
                      style: context.text(
                        AvoTextStyle.subhead,
                        color: colors.onTint,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const ProBadge(onTint: true),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
      _Demo(
        'AvoFigure',
        child: _States([
          for (final pose in AvoPose.values)
            _Labeled(
              pose.name,
              child: AvoFigure(pose: pose, size: _kFigureSize),
            ),
        ]),
      ),
      _Demo(
        'AvoIcons',
        child: _States([
          for (final entry in AvoIcons.all.entries)
            _Labeled(
              entry.key,
              child: Wrap(
                spacing: AvoSpacing.xs,
                children: [
                  AvoIcon(entry.value, size: _kIconPreview),
                  if (entry.value.hasFilledVariant)
                    AvoIcon(
                      entry.value,
                      size: _kIconPreview,
                      filled: true,
                      color: colors.tint,
                    ),
                ],
              ),
            ),
        ]),
      ),
    ];
  }

  // --- Home -------------------------------------------------------------------

  List<Widget> _home(BuildContext context) {
    final colors = context.colors;
    return [
      const _GroupHeader('Home'),
      const _Demo(
        'AvoSectionHeader',
        inset: false,
        child: AvoSectionHeader(
          'Letzte Einkäufe in deiner Nähe',
          actionLabel: 'Alle anzeigen',
          onAction: _noop,
        ),
      ),
      _Demo(
        'AvoCard',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AvoCard(
              tone: AvoCardTone.tint,
              child: Text(
                'Hey Jannis! Lidl lohnt sich diese Woche, drei Artikel deiner '
                'Liste sind dort im Angebot.',
                style: context.text(AvoTextStyle.body),
              ),
            ),
            const SizedBox(height: AvoSpacing.m),
            AvoCard(
              onTap: _noop,
              semanticLabel:
                  'Dein November, 183 Euro ausgegeben, 12 Prozent weniger als '
                  'im Oktober',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dein November',
                    style: context.text(AvoTextStyle.headline),
                  ),
                  Text(
                    '183 € ausgegeben · 12 % weniger als im Oktober',
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: colors.secondaryLabel,
                      tabular: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AvoSpacing.m),
            AvoCard(
              clip: true,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(
                    height: _kPhotoBand,
                    child: _Photo(tone: _PhotoTone.fresh),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AvoSpacing.l),
                    child: Text(
                      'Karte mit Foto bis an den Rand',
                      style: context.text(AvoTextStyle.body),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _Demo(
        'AvoTile und AvoTileGrid',
        child: AvoTileGrid(
          children: [
            AvoTile(
              title: 'Weiter einkaufen',
              icon: AvoIcon(
                AvoIcons.cart,
                size: _kIconTileGlyph,
                color: colors.tint,
              ),
              onTap: _noop,
              child: const _TileValue('Wocheneinkauf für das lange Wochenende'),
            ),
            AvoTile(
              title: 'Nochmal kaufen',
              icon: AvoIcon(
                AvoIcons.clock,
                size: _kIconTileGlyph,
                color: colors.tint,
              ),
              trailing: GlassIconButton(
                icon: AvoIcon(AvoIcons.plus, color: colors.onTint),
                semanticLabel: 'Alle hinzufügen',
                tinted: true,
                floating: false,
                onPressed: _noop,
              ),
              child: const _TileValue('Hafermilch, Eier, Bananen'),
            ),
            AvoTile(
              title: 'Angebote in deiner Region',
              icon: AvoIcon(
                AvoIcons.tag,
                size: _kIconTileGlyph,
                color: colors.tint,
              ),
              onTap: _noop,
              child: const _TileValue('5'),
            ),
          ],
        ),
      ),
    ];
  }

  // --- Liste ------------------------------------------------------------------

  List<Widget> _list(BuildContext context) {
    final colors = context.colors;
    Widget thumb(AvoIconData icon, {double size = AvoSizes.thumbSmall}) =>
        ItemThumb(
          size: size,
          placeholder: AvoIcon(icon, size: 20, color: colors.secondaryLabel),
        );
    return [
      const _GroupHeader('Liste'),
      _Demo(
        'ItemRow',
        inset: false,
        child: InsetSection(
          header: 'Obst & Gemüse',
          headerTrailing: const Text('6'),
          separatorIndent: ItemRow.separatorIndentOf(context),
          children: [
            ItemRow(
              title: 'Bio-Avocados aus Spanien, essreif',
              subtitle: '2 St. · für Guacamole',
              thumb: thumb(AvoIcons.tag),
              trailing: const _Price('2,49 €'),
              checked: _items[0],
              openLabel: 'Bearbeiten',
              onTap: _noop,
              onToggle: (value) => setState(() => _items[0] = value),
            ),
            ItemRow(
              title: 'Laktosefreie Bio-Vollmilch 1,5 % Fett',
              subtitle: '2 L',
              thumb: const ItemThumb(
                image: AssetImage('assets/avo/avo_excited.png'),
              ),
              checked: _items[1],
              onToggle: (value) => setState(() => _items[1] = value),
            ),
            ItemRow(
              title: 'Vollkornbrot',
              subtitle: 'gerade von Lena',
              thumb: thumb(AvoIcons.forkKnife),
              checked: true,
              checkState: CheckState.doneByOther,
              checkedBy: 'Lena',
              statusLabel: 'von Lena',
              onToggle: (_) {},
            ),
            ItemRow(
              title: 'Hafermilch ungesüßt',
              subtitle: '1 L',
              thumb: thumb(AvoIcons.cart),
              checked: true,
              checkState: CheckState.pending,
              statusLabel: 'Wartet auf Verbindung',
              onToggle: (_) {},
            ),
            ItemRow(
              title: 'Paprika rot',
              subtitle: '3 St.',
              thumb: thumb(AvoIcons.tag),
              checkState: CheckState.failed,
              onToggle: (_) {},
            ),
            const ItemRow(title: 'Küchenrolle (ohne Bild, deaktiviert)'),
          ],
        ),
      ),
      _Demo(
        'ItemRow groß (Einkaufsmodus)',
        inset: false,
        child: InsetSection(
          separatorIndent: ItemRow.separatorIndentOf(
            context,
            size: ItemRowSize.large,
          ),
          children: [
            ItemRow(
              size: ItemRowSize.large,
              title: 'Bio-Avocados aus Spanien, essreif',
              subtitle: '2 St.',
              thumb: thumb(AvoIcons.tag, size: AvoSizes.thumbMedium),
              trailing: const _Price('2,49 €'),
              checked: _items[0],
              onToggle: (value) => setState(() => _items[0] = value),
            ),
            ItemRow(
              size: ItemRowSize.large,
              title: 'Laktosefreie Bio-Vollmilch 1,5 % Fett',
              subtitle: '2 L',
              thumb: thumb(AvoIcons.cart, size: AvoSizes.thumbMedium),
              checked: _items[1],
              onToggle: (value) => setState(() => _items[1] = value),
            ),
          ],
        ),
      ),
      _Demo(
        'ListCard',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListCard(
              title: 'Wocheneinkauf für das lange Wochenende bei Lidl und dm',
              done: 8,
              total: 12,
              meta: '12 Artikel · 4 offen · vor 2 Std.',
              color: colors.tintIcon,
              sharedLabel: 'mit Lena und Maximilian',
              sharedName: 'Lena',
              onTap: _noop,
            ),
            const SizedBox(height: AvoSpacing.m),
            const ListCard(
              title: 'Grillabend Samstag',
              done: 14,
              total: 14,
              meta: 'Alles erledigt',
              cover: _Photo(tone: _PhotoTone.red),
              onTap: _noop,
            ),
            const SizedBox(height: AvoSpacing.m),
            const ListCard(title: 'Drogerie', done: 0, total: 0),
          ],
        ),
      ),
      _Demo(
        'ListRow',
        inset: false,
        child: InsetSection(
          header: 'Meine Listen',
          separatorIndent: ListRow.separatorIndent,
          children: [
            ListRow(
              title: 'Wocheneinkauf für das lange Wochenende',
              meta: '4 offen · Lena kauft gerade ein',
              color: colors.tintIcon,
              glyph: AvoIcon(AvoIcons.cart, color: colors.onTint, filled: true),
              accessory: const AvatarStack(
                names: ['Jannis', 'Lena', 'Mia', 'Tom', 'Maximilian'],
                neutralFirst: true,
              ),
              done: 8,
              total: 12,
              onTap: _noop,
            ),
            ListRow(
              title: 'Pasta-Abend mit Freunden',
              meta: '6 Zutaten',
              cover: thumb(AvoIcons.forkKnife),
              done: 2,
              total: 6,
              progress: ListRowProgress.ring,
              onTap: _noop,
            ),
            ListRow(
              title: 'Grillabend Samstag',
              meta: 'Alles erledigt',
              color: colors.red,
              glyph: AvoIcon(AvoIcons.heart, color: colors.onTint),
              done: 14,
              total: 14,
              complete: true,
              onTap: _noop,
            ),
            const ListRow(title: 'Drogerie (ohne Bild und Fortschritt)'),
          ],
        ),
      ),
      const _Demo(
        'Avatar, AvatarStack, PresenceDot',
        child: _States([
          _Labeled(
            '20 pt',
            child: Avatar(name: 'Lena', size: AvatarSize.small),
          ),
          _Labeled('24 pt', child: Avatar(name: 'Lena')),
          _Labeled(
            '32 pt',
            child: Avatar(name: 'Lena', size: AvatarSize.large),
          ),
          _Labeled('neutral', child: Avatar(name: 'Jannis', neutral: true)),
          _Labeled(
            'kauft ein',
            child: Avatar(
              name: 'Maximilian',
              size: AvatarSize.large,
              presence: true,
            ),
          ),
          _Labeled(
            'Stapel',
            child: AvatarStack(
              names: ['Jannis', 'Lena', 'Mia', 'Tom', 'Maximilian'],
              neutralFirst: true,
            ),
          ),
          _Labeled('PresenceDot', child: PresenceDot(name: 'Lena')),
        ]),
      ),
      _Demo(
        'QuickAddTile',
        child: _Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: QuickAddTile(
                  name: 'Vollkornbrot',
                  label: 'Brot',
                  onTap: _noop,
                ),
              ),
              const SizedBox(width: AvoSpacing.m),
              Expanded(
                child: QuickAddTile(
                  name: 'Laktosefreie Bio-Vollmilch',
                  thumb: thumb(AvoIcons.cart),
                  onTap: _noop,
                ),
              ),
              const SizedBox(width: AvoSpacing.m),
              const Expanded(
                child: QuickAddTile(name: 'Eier', onTap: _noop),
              ),
              const SizedBox(width: AvoSpacing.m),
              const Expanded(child: QuickAddTile(name: 'Olivenöl')),
            ],
          ),
        ),
      ),
    ];
  }

  // --- Rezept -----------------------------------------------------------------

  List<Widget> _recipe(BuildContext context) {
    final colors = context.colors;
    final grid = [
      RecipeCard(
        image: const _Photo(tone: _PhotoTone.green),
        title: 'Ofengemüse mit Halloumi und Zitronen-Joghurt-Dip',
        meta: '35 Min · ★ 4,6',
        pro: true,
        badge: Text(
          'Enthält Sesam',
          style: context.text(AvoTextStyle.footnote, color: colors.destructive),
        ),
        onTap: _noop,
      ),
      const RecipeCard(
        image: _Photo(tone: _PhotoTone.red),
        title: 'Avocado-Pasta',
        meta: '15 Min · ★ 4,5',
        semanticLabel: 'Avocado-Pasta, 15 Minuten, Bewertung 4,5',
        onTap: _noop,
      ),
    ];
    return [
      const _GroupHeader('Rezept'),
      _Demo(
        'RecipeCard Raster',
        child: context.isAccessibilityText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  grid[0],
                  const SizedBox(height: AvoSpacing.l),
                  grid[1],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: grid[0]),
                  const SizedBox(width: AvoSpacing.m),
                  Expanded(child: grid[1]),
                ],
              ),
      ),
      const _Demo(
        'RecipeCard Leiste',
        inset: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: AvoSpacing.screen,
            vertical: AvoSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipeCard(
                image: _Photo(tone: _PhotoTone.fresh),
                title: 'Shakshuka mit Feta',
                meta: '25 Min · ★ 4,8',
                style: RecipeCardStyle.rail,
                onTap: _noop,
              ),
              SizedBox(width: AvoSpacing.m),
              RecipeCard(
                image: _Photo(tone: _PhotoTone.grey),
                title: 'Linsen-Dal mit Kokosmilch und frischem Koriander',
                meta: '40 Min · vegan',
                style: RecipeCardStyle.rail,
                pro: true,
                onTap: _noop,
              ),
              SizedBox(width: AvoSpacing.m),
              RecipeCard(
                image: _Photo(tone: _PhotoTone.green),
                title: 'Overnight Oats',
                meta: '5 Min',
                style: RecipeCardStyle.rail,
              ),
            ],
          ),
        ),
      ),
      _Demo(
        'RecipeHeroCard regular',
        child: RecipeHeroCard(
          image: const _Photo(tone: _PhotoTone.red),
          title: 'Shakshuka mit Feta',
          eyebrow: 'Passt zu deiner Liste',
          meta: '25 Min · ★ 4,8 (126) · vegetarisch',
          chipLabel: '4 von 6 Zutaten da',
          actionLabel: 'Zutaten auf die Liste',
          onAction: () => _toast(context, '2 Zutaten hinzugefügt'),
          onTap: _noop,
        ),
      ),
      const _Demo(
        'RecipeHeroCard large',
        child: RecipeHeroCard(
          image: _Photo(tone: _PhotoTone.green),
          title: 'Ofengemüse mit Halloumi und Zitronen-Joghurt-Dip',
          meta: '35 Min · ★ 4,6 · vegetarisch',
          chipLabel: '6 von 6 Zutaten da',
          actionLabel: 'Heute kochen',
          style: RecipeHeroStyle.large,
          onAction: _noop,
          onTap: _noop,
        ),
      ),
      _Demo(
        'GlassInfoPanel',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AvoRadii.card),
          child: Stack(
            children: [
              const Positioned.fill(child: _Photo(tone: _PhotoTone.fresh)),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AvoSpacing.l,
                  _kPanelPhotoTop,
                  AvoSpacing.l,
                  AvoSpacing.l,
                ),
                child: GlassInfoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Linsen-Dal mit Kokosmilch',
                        style: context.text(AvoTextStyle.headline),
                      ),
                      Text(
                        '40 Min · ★ 4,7 · vegan',
                        style: context.text(
                          AvoTextStyle.footnote,
                          color: colors.tertiaryLabel,
                          tabular: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // --- Charts -----------------------------------------------------------------

  List<Widget> _charts(BuildContext context) {
    final colors = context.colors;
    return [
      const _GroupHeader('Charts'),
      _Demo(
        'AvoBarChart Monate',
        child: AvoCard(
          child: AvoBarChart(
            entries: const [
              AvoBarEntry(label: 'Jun', value: 212, semanticLabel: 'Juni'),
              AvoBarEntry(label: 'Jul', value: 186, semanticLabel: 'Juli'),
              AvoBarEntry(label: 'Aug', value: 240, semanticLabel: 'August'),
              AvoBarEntry(label: 'Sep', value: 198, semanticLabel: 'September'),
              AvoBarEntry(label: 'Okt', value: 208, semanticLabel: 'Oktober'),
              AvoBarEntry(label: 'Nov', value: 183, semanticLabel: 'November'),
            ],
            formatValue: (value) => '${value.round()} €',
            semanticSummary:
                'Ausgaben pro Monat, November bisher 183 €, 12 % weniger als '
                'im Oktober',
            highlightIndex: 5,
          ),
        ),
      ),
      _Demo(
        'AvoBarChart Woche mit Ziel',
        child: AvoCard(
          child: AvoBarChart(
            entries: const [
              AvoBarEntry(label: 'Mo', value: 1910, semanticLabel: 'Montag'),
              AvoBarEntry(label: 'Di', value: 2080, semanticLabel: 'Dienstag'),
              AvoBarEntry(
                label: 'Mi',
                semanticLabel: 'Mittwoch',
                semanticValue: 'nicht erfasst',
              ),
              AvoBarEntry(
                label: 'Do',
                value: 1760,
                semanticLabel: 'Donnerstag',
              ),
              AvoBarEntry(label: 'Fr', value: 2010, semanticLabel: 'Freitag'),
              AvoBarEntry(label: 'Sa', value: 1640, semanticLabel: 'Samstag'),
              AvoBarEntry(
                label: 'So',
                semanticLabel: 'Sonntag',
                semanticValue: 'nicht erfasst',
              ),
            ],
            formatValue: (value) => '${value.round()} kcal',
            semanticSummary:
                'Diese Woche im Schnitt 1.880 Kilokalorien an 5 Tagen, Ziel '
                '2.000',
            highlightIndex: 5,
            tintAllBars: true,
            goal: 2000,
            showValues: false,
            maxBarHeight: 120,
          ),
        ),
      ),
      _Demo(
        'AvoBarChart leer',
        child: AvoCard(
          child: AvoBarChart(
            entries: const [
              AvoBarEntry(label: 'Mo'),
              AvoBarEntry(label: 'Di'),
              AvoBarEntry(label: 'Mi'),
              AvoBarEntry(label: 'Do'),
              AvoBarEntry(label: 'Fr'),
              AvoBarEntry(label: 'Sa'),
              AvoBarEntry(label: 'So'),
            ],
            formatValue: (value) => '${value.round()} kcal',
            semanticSummary: 'Noch keine Woche erfasst',
            emptyText: 'Noch keine Woche erfasst.',
          ),
        ),
      ),
      _Demo(
        'AvoHorizontalBar',
        child: AvoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AvoHorizontalBar(
                label: 'Protein',
                value: '62 / 110 g',
                fraction: 62 / 110,
                semanticValue: '62 von 110 Gramm',
              ),
              const SizedBox(height: AvoSpacing.m),
              AvoHorizontalBar(
                label: 'Kohlenhydrate',
                value: '180 / 250 g',
                fraction: 180 / 250,
                color: colors.tintIcon,
              ),
              const SizedBox(height: AvoSpacing.m),
              AvoHorizontalBar(
                label: 'Ballaststoffe aus Vollkorn und Hülsenfrüchten',
                value: '34 / 30 g',
                fraction: 34 / 30,
                color: colors.red,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // --- Eingabe ----------------------------------------------------------------

  List<Widget> _input(BuildContext context) {
    return [
      const _GroupHeader('Eingabe'),
      _Demo(
        'AddItemAccessory',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AddItemAccessory(
              placeholder: 'Artikel hinzufügen',
              semanticHint: 'Zum Beispiel 2 Milch',
              trailingText: '≈ 23,80 €',
              onDictate: _noop,
              onSubmitted: (text) => _toast(context, '„$text“ hinzugefügt'),
            ),
            const SizedBox(height: AvoSpacing.m),
            AddItemAccessory(
              placeholder: 'Artikel hinzufügen',
              controller: _longEntry,
              trailingText: '≈ 23,80 €',
              onDictate: _noop,
              onSubmitted: (text) => _toast(context, 'Hinzugefügt'),
            ),
            const SizedBox(height: AvoSpacing.m),
            AddItemAccessory(
              placeholder: 'Notiz wird gelesen …',
              leading: Semantics(
                label: 'Wird gelesen',
                child: const CupertinoActivityIndicator(),
              ),
            ),
          ],
        ),
      ),
      _Demo(
        'AvoComposerField',
        child: AvoComposerField(
          placeholder: 'Frag Avo oder suche',
          shortPlaceholder: 'Frag Avo',
          sendLabel: 'Senden',
          voiceLabel: 'Sprachmodus starten',
          cameraLabel: 'Foto aufnehmen',
          onCamera: _noop,
          onVoice: _noop,
          onSubmitted: (text) => _toast(context, 'Gesendet: $text'),
        ),
      ),
    ];
  }

  // --- Menü -------------------------------------------------------------------

  List<Widget> _menu(BuildContext context) {
    return [
      const _GroupHeader('Menü'),
      _Demo(
        'AvoMenuButton',
        child: _States([
          _Labeled(
            'im Inhalt',
            child: AvoMenuButton(
              floating: false,
              semanticLabel: 'Mehr zur Liste',
              items: _menuItems(context),
            ),
          ),
          _Labeled(
            'schwebend',
            child: AvoMenuButton(items: _menuItems(context)),
          ),
          _Labeled(
            'deaktiviert',
            child: AvoMenuButton(
              floating: false,
              enabled: false,
              items: _menuItems(context),
            ),
          ),
        ]),
      ),
    ];
  }

  // --- Dialoge und Rückmeldungen ----------------------------------------------

  List<Widget> _feedback(BuildContext context) {
    return [
      const _GroupHeader('Dialoge und Rückmeldungen'),
      _Demo(
        'showAvoConfirm',
        child: _Trigger(
          label: 'Liste löschen fragen',
          onPressed: () => _confirmDelete(context),
        ),
      ),
      _Demo(
        'AvoToast',
        child: _States([
          _Trigger(
            label: 'Mit Rückgängig',
            onPressed: () => AvoToast.show(
              context,
              message: '„Laktosefreie Bio-Vollmilch“ gelöscht',
              actionLabel: 'Rückgängig',
              onAction: () => _toast(context, 'Wiederhergestellt'),
            ),
          ),
          _Trigger(
            label: 'Nur Status',
            onPressed: () => _toast(context, 'Liste geteilt'),
          ),
        ]),
      ),
      _Demo(
        'showSuccessMoment',
        child: _Trigger(
          label: 'Erfolg zeigen',
          onPressed: () => showSuccessMoment(
            context,
            title: 'Einkauf gespeichert.',
            subtitle: '23,80 € bei Lidl, davon 3,10 € gespart',
          ),
        ),
      ),
      _Demo(
        'showModuleOffAlert',
        child: _Trigger(
          label: 'Modul Kalorien ist aus',
          onPressed: () => showModuleOffAlert(
            context,
            moduleName: 'Kalorien',
            onEnable: () async => _toast(context, 'Kalorien ist an'),
          ),
        ),
      ),
      _Demo(
        'pushFullScreenEditor',
        child: _Trigger(
          label: 'Artikel bearbeiten',
          onPressed: () => _openEditor(context),
        ),
      ),
    ];
  }
}

/// The full-screen editor example, opened from the gallery.
class _EditorDemo extends StatefulWidget {
  const _EditorDemo();

  @override
  State<_EditorDemo> createState() => _EditorDemoState();
}

class _EditorDemoState extends State<_EditorDemo> {
  int _quantity = 2;
  bool _remember = false;
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop();
    return FullScreenEditor(
      title: 'Artikel',
      dirty: _dirty,
      onDone: close,
      bottom: AppButton.primary(
        label: 'Auf die Liste setzen',
        size: AppButtonSize.large,
        expand: true,
        onPressed: close,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsetSection(
            header: 'Laktosefreie Bio-Vollmilch 1,5 % Fett',
            children: [
              const NavRow(
                title: 'Kategorie',
                value: 'Kühlregal',
                onTap: _noop,
              ),
              const ValueRow(title: 'Preis bei Lidl', value: '1,29 €'),
              ToggleRow(
                title: 'Für den nächsten Einkauf merken',
                value: _remember,
                onChanged: (value) => setState(() {
                  _remember = value;
                  _dirty = true;
                }),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AvoSpacing.screen),
            child: Wrap(
              spacing: AvoSpacing.m,
              runSpacing: AvoSpacing.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Menge', style: context.text(AvoTextStyle.body)),
                ValueStepper(
                  value: _quantity,
                  min: 1,
                  unit: 'St.',
                  semanticLabel: 'Menge',
                  onChanged: (value) => setState(() {
                    _quantity = value;
                    _dirty = true;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Gallery building blocks --------------------------------------------------

const EdgeInsetsGeometry _chipPadding = EdgeInsets.symmetric(
  horizontal: AvoSpacing.m,
  vertical: AvoSpacing.s,
);

/// A group of components, headed like a Home section.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AvoSpacing.xxxl),
    child: AvoSectionHeader(title),
  );
}

/// One component: its name as section caps, then the examples.
class _Demo extends StatelessWidget {
  const _Demo(this.name, {required this.child, this.inset = true});

  final String name;
  final Widget child;

  /// Adds the 16 pt screen margin; off for components that bring their own.
  final bool inset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      SectionCaps(name, padding: SectionCaps.plainPadding),
      if (inset)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: child,
        )
      else
        child,
    ],
  );
}

/// Several states side by side, wrapping onto new lines.
class _States extends StatelessWidget {
  const _States(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AvoSpacing.l,
    runSpacing: AvoSpacing.m,
    crossAxisAlignment: WrapCrossAlignment.end,
    children: children,
  );
}

/// A state with a small caption below it.
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, {required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      child,
      const SizedBox(height: AvoSpacing.xs),
      ExcludeSemantics(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: context.text(
            AvoTextStyle.caption1,
            color: context.colors.secondaryLabel,
          ),
        ),
      ),
    ],
  );
}

/// A button that opens a dialog, toast or screen.
class _Trigger extends StatelessWidget {
  const _Trigger({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  /// The Wrap keeps the button at its own width in a stretched column.
  @override
  Widget build(BuildContext context) => Wrap(
    children: [AppButton.secondary(label: label, onPressed: onPressed)],
  );
}

/// Text inside a glass chip.
class _ChipText extends StatelessWidget {
  const _ChipText(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text(
      AvoTextStyle.footnote,
      color: color,
      weight: FontWeight.w600,
    ),
  );
}

/// A soft gradient standing in for a photo behind glass.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AvoRadii.card),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [colors.tintSoft, colors.fillStrong],
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(AvoSpacing.l), child: child),
    );
  }
}

/// A surface panel like the D2 "Schnell wieder hinzufügen" section.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AvoRadii.group),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AvoSpacing.group),
      child: child,
    ),
  );
}

enum _PhotoTone { green, fresh, red, grey }

/// A coloured area standing in for a photo (no network images).
class _Photo extends StatelessWidget {
  const _Photo({required this.tone});

  final _PhotoTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: switch (tone) {
        _PhotoTone.green => colors.tintIcon,
        _PhotoTone.fresh => colors.presence,
        _PhotoTone.red => colors.red,
        _PhotoTone.grey => colors.secondaryLabel,
      },
    );
  }
}

/// The settings icon tile (D2: 30 pt, radius 8, white glyph on green).
class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final AvoIconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tintFill,
        borderRadius: BorderRadius.circular(_kIconTileRadius),
      ),
      child: SizedBox.square(
        dimension: _kIconTile,
        child: Center(
          child: AvoIcon(icon, size: _kIconTileGlyph, color: colors.onTint),
        ),
      ),
    );
  }
}

/// The value block of an [AvoTile].
class _TileValue extends StatelessWidget {
  const _TileValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.text(AvoTextStyle.headline));
}

/// A price at the end of an item row.
class _Price extends StatelessWidget {
  const _Price(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text(
      AvoTextStyle.subhead,
      color: context.colors.secondaryLabel,
      tabular: true,
    ),
  );
}
