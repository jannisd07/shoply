import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

// D2 has no menu artboard. Apple pull-down menu metrics, built from the D2
// glass tokens and radii.
const double _menuWidth = 250; // Apple UIMenu width
const double _menuRadius = AvoRadii.card; // Konzept 00 §12.24 radiusCard
const double _menuInset = AvoSpacing.s; // rows sit inside the glass
const double _rowRadius = _menuRadius - _menuInset; // concentric highlight
const double _rowHorizontal = AvoSpacing.m;
const double _rowVertical = 11; // (44 - 22) / 2 at the default size
const double _iconSize = 20; // SF Symbol next to 17 pt text
const double _chevronSize = 14; // submenu disclosure, as D2-Artikel
const double _checkSize = 16; // checkmark column
const double _checkGap = AvoSpacing.s;
const double _leadingSlot = 28; // iOS: 20 pt glyph or store mark column
const double _dividerSpace = AvoSpacing.xs; // above and below the hairline
const double _anchorGap = AvoSpacing.s; // between trigger and menu
const double _edge = AvoSpacing.screen; // from the screen edges
const double _verticalEdge = AvoSpacing.s; // from the safe area
const double _disabledOpacity = 0.4; // Konzept 00 §12.20

/// Glyphs grow with Dynamic Type up to xxxL (body 23 pt), then stay (E-04).
const double _iconGrowthLimit = 23 / 17;

/// The menu grows out of its trigger from this scale (Konzept 00 §10.2).
const double _startScale = 0.6;

/// The screen behind dims only slightly; the menu is not a dialog.
const double _barrierAlpha = 0.08;

/// A context menu with a preview dims more, so the preview stands out.
const double _previewBarrierAlpha = 0.25;

/// Corner of a lifted preview (Konzept 00 §12.24 radiusCard).
const double _previewRadius = AvoRadii.card;

// D2 `.glass` shadow for the opaque surface: 0 0 0 .5px rgba(0,0,0,.05),
// 0 6px 20px rgba(0,0,0,.10).
const double _ringAlpha = 0.05; // D2
const Offset _dropOffset = Offset(0, 6); // D2
const double _dropBlur = 20; // D2
const double _dropAlpha = 0.10; // D2

/// One entry of a menu for [showAvoMenu]: an [AvoMenuItem], an
/// [AvoMenuTitle] or an [AvoMenuDivider].
@immutable
sealed class AvoMenuEntry {
  const AvoMenuEntry();
}

/// One row of an Avo pull-down menu: title (17/22) on the left, optional
/// subtitle, optional icon on the right, a checkmark on the left when
/// [checked] (Konzept 00 §12.24). Destructive rows are red; put them last.
class AvoMenuItem extends AvoMenuEntry {
  /// Creates a menu row.
  const AvoMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
    this.checked = false,
    this.leading,
    this.trailing,
    this.trailingLabel,
  });

  /// The title, also what VoiceOver reads first.
  final String label;

  /// Called after the menu has started to close.
  final VoidCallback onSelected;

  /// Glyph at the end of the row, drawn in the row's text colour.
  final AvoIconData? icon;

  /// A second line in 15/20 secondary text ("Für alle 4 Mitglieder").
  final String? subtitle;

  /// Red text and icon ("Liste löschen"). Confirm final actions separately.
  final bool destructive;

  /// False dims the row (40 %) and ignores taps.
  final bool enabled;

  /// Shows a checkmark at the start: the current choice of a group.
  final bool checked;

  /// A glyph or mark before the text, for example a store mark. It sits in
  /// its own column (after the checkmark column) that is reserved in every
  /// row of the menu as soon as one row has a [leading]; it grows with
  /// Dynamic Type up to xxxL and is decorative for VoiceOver (the label says
  /// what it shows). It must not take taps of its own.
  final Widget? leading;

  /// A small widget between the text and the [icon], for example a
  /// `ProBadge`. It must not take taps of its own; the whole row is the
  /// target.
  final Widget? trailing;

  /// What VoiceOver adds after the label for [trailing] ("Pro-Funktion").
  /// Without it the trailing widget is not read.
  final String? trailingLabel;
}

/// A heading line inside a menu ("Markt", "Auf welche Liste?"): small
/// semibold secondary text, no action, not focusable, read as a heading.
/// Put it first, or at the start of a group after an [AvoMenuDivider].
class AvoMenuTitle extends AvoMenuEntry {
  /// Creates a title line.
  const AvoMenuTitle(this.text);

  /// The heading; it wraps instead of being cut off.
  final String text;
}

/// Separates groups of [AvoMenuItem]s with a hairline band.
class AvoMenuDivider extends AvoMenuEntry {
  /// Creates a group separator.
  const AvoMenuDivider();
}

/// A row that opens a nested menu in the same place (iOS submenu, A-K10):
/// the panel swaps to [items] with the submenu's title on top; tapping the
/// title goes back. The row shows its [icon] and a chevron. [items] may hold
/// rows, titles, dividers and further submenus; checkmarks, subtitles,
/// destructive rows and a `ProBadge` in [AvoMenuItem.trailing] work as in
/// the main menu.
class AvoSubmenu extends AvoMenuEntry {
  /// Creates a submenu row.
  const AvoSubmenu({
    required this.label,
    required this.items,
    this.icon,
    this.subtitle,
    this.enabled = true,
    this.trailing,
    this.trailingLabel,
  });

  /// The title of the row and of the opened submenu.
  final String label;

  /// What the submenu shows.
  final List<AvoMenuEntry> items;

  /// Glyph at the end of the row, before the chevron.
  final AvoIconData? icon;

  /// A second line in 15/20 secondary text ("Mittwoch").
  final String? subtitle;

  /// False dims the row (40 %) and ignores taps.
  final bool enabled;

  /// As [AvoMenuItem.trailing].
  final Widget? trailing;

  /// As [AvoMenuItem.trailingLabel].
  final String? trailingLabel;

  /// Whether the submenu has anything to choose.
  bool get _hasRows => items.any((e) => e is AvoMenuItem || e is AvoSubmenu);
}

/// Opens an iOS pull-down menu that grows out of its trigger (Konzept 00
/// §12.24; no bottom sheet, no action sheet). Entries are rows
/// ([AvoMenuItem]), headings ([AvoMenuTitle]) and group separators
/// ([AvoMenuDivider]); several groups in one menu are written as items
/// separated by dividers.
///
/// The trigger is [anchorRect] (global coordinates), else the widget of
/// [anchorKey], else the widget of [context]. The menu is about 250 pt wide
/// (the screen width minus 16 pt margins from AX1), opens below the trigger
/// when it sits in the upper half of the screen and above it otherwise, and
/// aligns to the trigger's edge on that side of the screen. It scrolls when
/// its rows do not fit. It grows on the [AvoMotion.menu] spring from 0.6 at
/// the trigger (Reduce Motion: a short fade).
///
/// Tapping outside, Escape and the VoiceOver escape gesture close it.
/// VoiceOver focus moves to the first row. Choosing a row closes the menu
/// and then calls [AvoMenuItem.onSelected]. Opens on the root navigator, above
/// the tab bar. The future completes when the menu is closed.
///
/// [AvoSubmenu] rows open their items in the same place. With [preview]
/// (a context menu, A-K10) that widget is drawn lifted over the trigger's
/// place, in the trigger's size, with the screen dimmed behind it, and the
/// menu sits next to it; the preview is decorative for VoiceOver.
Future<void> showAvoMenu(
  BuildContext context, {
  required List<AvoMenuEntry> items,
  Rect? anchorRect,
  GlobalKey? anchorKey,
  String? semanticLabel,
  Widget? preview,
}) async {
  final entries = _normalize(items);
  if (!entries.any(_isRow)) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  final anchor =
      anchorRect ??
      _rectOf(anchorKey?.currentContext ?? context, navigator.overlay);
  await navigator.push(
    _AvoMenuRoute(
      anchor: anchor,
      entries: entries,
      semanticLabel: semanticLabel,
      reduceMotion: context.reduceMotion,
      preview: preview,
      barrierColor: context.colors.shadow.withValues(
        alpha: preview == null ? _barrierAlpha : _previewBarrierAlpha,
      ),
      barrierLabel: context.tr('common_close'),
    ),
  );
}

/// A 44 pt glass "Mehr" button (three dots) that opens [items] as an
/// [showAvoMenu] pull-down menu from itself.
class AvoMenuButton extends StatelessWidget {
  /// Creates a "more" button with a menu.
  const AvoMenuButton({
    super.key,
    required this.items,
    this.semanticLabel,
    this.floating = true,
    this.enabled = true,
  });

  /// The menu rows. An empty list (or only dividers) disables the button.
  final List<AvoMenuEntry> items;

  /// VoiceOver label; defaults to "Mehr".
  final String? semanticLabel;

  /// True on the floating layer (native glass); false inside content.
  final bool floating;

  /// False dims the button (40 %) and ignores taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasItems = items.any((e) => e is AvoMenuItem);
    return Builder(
      builder: (buttonContext) => GlassIconButton(
        icon: const AvoIcon(AvoIcons.more),
        semanticLabel: semanticLabel ?? buttonContext.tr('common_more'),
        floating: floating,
        onPressed: enabled && hasItems
            ? () => showAvoMenu(buttonContext, items: items)
            : null,
      ),
    );
  }
}

/// Drops leading, trailing and repeated dividers.
bool _isRow(AvoMenuEntry e) =>
    e is AvoMenuItem || (e is AvoSubmenu && e._hasRows);

List<AvoMenuEntry> _normalize(List<AvoMenuEntry> items) {
  final out = <AvoMenuEntry>[];
  for (final e in items) {
    if (e is AvoSubmenu && !e._hasRows) continue;
    if (e is AvoMenuDivider && (out.isEmpty || out.last is AvoMenuDivider)) {
      continue;
    }
    out.add(e);
  }
  while (out.isNotEmpty && out.last is AvoMenuDivider) {
    out.removeLast();
  }
  // A title needs a row before the next divider or the end.
  final kept = <AvoMenuEntry>[];
  for (var i = 0; i < out.length; i++) {
    if (out[i] is AvoMenuTitle) {
      var hasRow = false;
      for (var j = i + 1; j < out.length && out[j] is! AvoMenuDivider; j++) {
        if (_isRow(out[j])) {
          hasRow = true;
          break;
        }
      }
      if (!hasRow) continue;
    }
    kept.add(out[i]);
  }
  out
    ..clear()
    ..addAll(kept);
  while (out.isNotEmpty && out.last is AvoMenuDivider) {
    out.removeLast();
  }
  for (var i = out.length - 1; i > 0; i--) {
    if (out[i] is AvoMenuDivider && out[i - 1] is AvoMenuDivider) {
      out.removeAt(i);
    }
  }
  while (out.isNotEmpty && out.first is AvoMenuDivider) {
    out.removeAt(0);
  }
  return out;
}

Rect _rectOf(BuildContext context, OverlayState? overlay) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  final ancestor = overlay?.context.findRenderObject();
  final origin = box.localToGlobal(
    Offset.zero,
    ancestor: ancestor is RenderBox ? ancestor : null,
  );
  return origin & box.size;
}

double _iconScale(BuildContext context) {
  final base = AvoTypography.forFactor(1).sizeOf(AvoTextStyle.body);
  final size = context.typography.sizeOf(AvoTextStyle.body);
  return (size / base).clamp(1.0, _iconGrowthLimit);
}

class _AvoMenuRoute extends PopupRoute<void> {
  _AvoMenuRoute({
    required this.anchor,
    required this.entries,
    required this.semanticLabel,
    required this.reduceMotion,
    required this.barrierColor,
    required this.barrierLabel,
    this.preview,
  });

  final Rect anchor;
  final List<AvoMenuEntry> entries;
  final String? semanticLabel;
  final bool reduceMotion;
  final Widget? preview;

  @override
  final Color barrierColor;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  // The barrier stays out of VoiceOver: focus goes to the first row; the
  // escape gesture closes the menu (onDismiss on the menu).
  @override
  bool get semanticsDismissible => false;

  @override
  Duration get transitionDuration => AvoMotion.fadeReduced;

  @override
  Simulation? createSimulation({required bool forward}) {
    if (reduceMotion) return null;
    final c = controller!;
    return SpringSimulation(
      AvoMotion.menu,
      c.value,
      forward ? 1 : 0,
      c.velocity,
      snapToEnd: true,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _MenuLayer(route: this, animation: animation);
}

class _MenuLayer extends StatelessWidget {
  const _MenuLayer({required this.route, required this.animation});

  final _AvoMenuRoute route;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final anchor = route.anchor;

    final width = context.isAccessibilityText
        ? size.width - 2 * _edge
        : math.min(_menuWidth, size.width - 2 * _edge);

    // Leading edge for triggers on the left, trailing on the right, centred
    // under triggers in the middle third.
    final cx = anchor.center.dx;
    final double desiredLeft;
    if (cx >= size.width * 2 / 3) {
      desiredLeft = anchor.right - width;
    } else if (cx <= size.width / 3) {
      desiredLeft = anchor.left;
    } else {
      desiredLeft = cx - width / 2;
    }
    final left = desiredLeft
        .clamp(_edge, math.max(_edge, size.width - _edge - width))
        .toDouble();

    final below = anchor.center.dy <= size.height / 2;
    final topLimit = padding.top + _verticalEdge;
    final bottomLimit =
        size.height - math.max(padding.bottom, keyboard) - _verticalEdge;
    final double maxHeight;
    if (below) {
      maxHeight = bottomLimit - (anchor.bottom + _anchorGap);
    } else {
      maxHeight = (anchor.top - _anchorGap) - topLimit;
    }

    final originX = width <= 0
        ? 0.0
        : ((cx - left) / width * 2 - 1).clamp(-1.0, 1.0);
    final origin = Alignment(originX, below ? -1 : 1);

    final reduceMotion = route.reduceMotion;
    final curved = reduceMotion
        ? CurvedAnimation(parent: animation, curve: Curves.easeInOut)
        : animation;

    final panel = AnimatedBuilder(
      animation: curved,
      child: _MenuPanel(
        entries: route.entries,
        semanticLabel: route.semanticLabel,
      ),
      builder: (context, child) {
        final t = curved.value.clamp(0.0, 1.0);
        final faded = Opacity(opacity: t, child: child);
        if (reduceMotion) return faded;
        return Transform.scale(
          scale: _startScale + (1 - _startScale) * t,
          alignment: origin,
          child: faded,
        );
      },
    );

    final preview = route.preview;
    return Stack(
      children: [
        if (preview != null)
          Positioned.fromRect(
            rect: anchor,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: curved,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_previewRadius),
                    child: preview,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: left,
          width: width,
          top: below ? anchor.bottom + _anchorGap : null,
          bottom: below ? null : size.height - (anchor.top - _anchorGap),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(AvoSizes.hitTarget, maxHeight),
            ),
            child: panel,
          ),
        ),
      ],
    );
  }
}

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({required this.entries, required this.semanticLabel});

  final List<AvoMenuEntry> entries;
  final String? semanticLabel;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  /// The open submenus, innermost last.
  final List<AvoSubmenu> _path = [];

  void _close(BuildContext context) {
    if (_path.isNotEmpty) {
      _back();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _open(AvoSubmenu submenu) {
    AvoHaptics.selection();
    setState(() => _path.add(submenu));
  }

  void _back() => setState(_path.removeLast);

  @override
  Widget build(BuildContext context) {
    final open = _path.isEmpty ? null : _path.last;
    final entries = open == null ? widget.entries : _normalize(open.items);
    final reserveCheck = entries.any((e) => e is AvoMenuItem && e.checked);
    final reserveLeading = entries.any(
      (e) => e is AvoMenuItem && e.leading != null,
    );
    final firstEnabled = open != null
        ? -1
        : entries.indexWhere(
            (e) =>
                (e is AvoMenuItem && e.enabled) ||
                (e is AvoSubmenu && e.enabled),
          );
    final label = open?.label ?? widget.semanticLabel;

    final rows = <Widget>[
      if (open != null) ...[
        _MenuRow(
          item: AvoMenuItem(
            label: open.label,
            onSelected: _back,
            icon: AvoIcons.chevronDown,
          ),
          reserveCheck: false,
          reserveLeading: false,
          autofocus: true,
          header: true,
          semanticsLabel: context.tr(
            'common_back_to',
            params: {
              'title': _path.length > 1
                  ? _path[_path.length - 2].label
                  : (widget.semanticLabel ?? context.tr('common_more')),
            },
          ),
          onActivate: _back,
        ),
        const _MenuDivider(),
      ],
      for (var i = 0; i < entries.length; i++)
        switch (entries[i]) {
          final AvoMenuItem item => _MenuRow(
            item: item,
            reserveCheck: reserveCheck,
            reserveLeading: reserveLeading,
            autofocus: i == firstEnabled,
          ),
          final AvoSubmenu sub => _MenuRow(
            item: AvoMenuItem(
              label: sub.label,
              onSelected: () {},
              icon: sub.icon,
              subtitle: sub.subtitle,
              enabled: sub.enabled,
              trailing: sub.trailing,
              trailingLabel: sub.trailingLabel,
            ),
            reserveCheck: reserveCheck,
            reserveLeading: reserveLeading,
            autofocus: i == firstEnabled,
            onActivate: () => _open(sub),
          ),
          final AvoMenuTitle title => _MenuTitle(text: title.text),
          AvoMenuDivider() => const _MenuDivider(),
        },
    ];

    final column = Column(
      key: ValueKey(_path.length),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: label != null,
      explicitChildNodes: true,
      label: label,
      role: SemanticsRole.menu,
      onDismiss: () => _close(context),
      child: _MenuSurface(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_menuRadius),
          child: FocusTraversalGroup(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(_menuInset),
              child: AnimatedSize(
                duration: context.reduceMotion
                    ? Duration.zero
                    : AvoMotion.fadeReduced,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: AvoMotion.fadeReduced,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      for (final p in previous)
                        Positioned(top: 0, left: 0, right: 0, child: p),
                      ?current,
                    ],
                  ),
                  child: column,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Native glass on iOS; elsewhere and with Reduce Transparency an opaque
/// raised surface, since menu text must stay readable over any content.
class _MenuSurface extends StatelessWidget {
  const _MenuSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.reduceTransparency &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      return GlassSurface(
        shape: GlassShape.rounded,
        radius: _menuRadius,
        child: child,
      );
    }
    final colors = context.colors;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_menuRadius),
          side: BorderSide(
            color: highContrast ? colors.glassBorder : colors.separator,
            width: AvoSizes.hairline,
          ),
        ),
        shadows: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: _ringAlpha),
            spreadRadius: AvoSizes.hairline,
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: _dropAlpha),
            offset: _dropOffset,
            blurRadius: _dropBlur,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MenuTitle extends StatelessWidget {
  const _MenuTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    container: true,
    label: text,
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowHorizontal,
        vertical: AvoSpacing.s,
      ),
      child: Text(
        text,
        style: context.text(
          AvoTextStyle.footnote,
          color: context.colors.secondaryLabel,
          weight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: _dividerSpace,
        horizontal: _rowHorizontal,
      ),
      child: SizedBox(
        height: AvoSizes.hairline,
        child: ColoredBox(color: context.colors.separator),
      ),
    ),
  );
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.item,
    required this.reserveCheck,
    required this.reserveLeading,
    required this.autofocus,
    this.onActivate,
    this.header = false,
    this.semanticsLabel,
  });

  final AvoMenuItem item;
  final bool reserveCheck;
  final bool reserveLeading;
  final bool autofocus;

  /// Set for a submenu row (opens it, shows a chevron) and the submenu's
  /// title row (goes back); the menu stays open.
  final VoidCallback? onActivate;

  /// The title row of an open submenu: semibold.
  final bool header;

  /// Replaces what VoiceOver reads.
  final String? semanticsLabel;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;
  bool _focused = false;

  void _select() {
    final item = widget.item;
    // Ignore a second choice while the menu is already closing.
    final closing = !(ModalRoute.of(context)?.isCurrent ?? true);
    if (!item.enabled || closing) return;
    final activate = widget.onActivate;
    if (activate != null) {
      activate();
      return;
    }
    Navigator.of(context).pop();
    item.onSelected();
  }

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;
    final enabled = item.enabled;
    final foreground = item.destructive ? colors.destructive : colors.label;
    final scale = _iconScale(context);
    final subtitle = item.subtitle;
    final icon = item.icon;
    final trailing = item.trailing;
    final leading = item.leading;

    Widget row = Row(
      children: [
        if (widget.reserveCheck) ...[
          SizedBox(
            width: _checkSize * scale,
            child: item.checked
                ? AvoIcon(
                    AvoIcons.check,
                    size: _checkSize * scale,
                    color: foreground,
                  )
                : null,
          ),
          const SizedBox(width: _checkGap),
        ],
        if (widget.reserveLeading) ...[
          SizedBox(
            width: _leadingSlot * scale,
            child: leading == null
                ? null
                : ExcludeSemantics(child: Center(child: leading)),
          ),
          const SizedBox(width: AvoSpacing.m),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: context.text(
                  AvoTextStyle.body,
                  color: foreground,
                  weight: widget.header ? FontWeight.w600 : null,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AvoSpacing.s),
          trailing,
        ],
        if (icon != null) ...[
          const SizedBox(width: AvoSpacing.m),
          AvoIcon(icon, size: _iconSize * scale, color: foreground),
        ],
        if (widget.onActivate != null && !widget.header) ...[
          const SizedBox(width: AvoSpacing.s),
          AvoIcon(
            AvoIcons.chevronRight,
            size: _chevronSize * scale,
            color: colors.tertiaryLabel,
          ),
        ],
      ],
    );

    row = DecoratedBox(
      decoration: ShapeDecoration(
        color: enabled && (_pressed || _focused)
            ? colors.fill
            : colors.fill.withValues(alpha: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rowRadius),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _rowHorizontal,
            vertical: _rowVertical,
          ),
          child: Center(heightFactor: 1, child: row),
        ),
      ),
    );
    if (!enabled) row = Opacity(opacity: _disabledOpacity, child: row);

    final label =
        widget.semanticsLabel ??
        [
          item.label,
          ?subtitle,
          if (trailing != null) ?item.trailingLabel,
        ].join(', ');
    return Semantics(
      container: true,
      button: true,
      role: SemanticsRole.menuItem,
      enabled: enabled,
      selected: widget.reserveCheck ? item.checked : null,
      label: label,
      onTap: enabled ? _select : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (value) {
          if (mounted && _focused != value) setState(() => _focused = value);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _select();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: enabled ? _select : null,
          child: row,
        ),
      ),
    );
  }
}
