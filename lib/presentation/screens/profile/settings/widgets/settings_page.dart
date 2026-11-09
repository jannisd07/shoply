import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

// D2 X-Profil: content starts at 106 on a 47 pt status bar (toolbar 54 to
// 98, then 8); the large title 34/41 bold has a 12 pt margin below.
const double _kTitleTop = AvoSpacing.s; // D2 106 - 98
const double _kTitleBottom = AvoSpacing.m; // D2 h1 margin 0 16 12

/// Icon tile of a settings row (D2 X-Profil `.ic`: 30 pt, radius 8, white
/// 16 pt glyph).
const double _kTileSize = 30; // D2
const double _kTileRadius = 8; // D2
const double _kTileGlyph = 16; // D2

/// Text edge of rows with a tile: 16 inset + 30 tile + 12 gap (D2 `.sep`
/// left 58). Pass it as `InsetSection.separatorIndent`.
const double kSettingsTileRowIndent = 58; // D2

/// Checkmark of a choice row (iOS: 17 pt next to body text).
const double _kCheckSize = 17;

/// Minimum row height (D2 `.row`), like the rows in `settings_rows.dart`.
const double _kRowMinHeight = 52; // D2
const double _kRowVerticalPadding = 9; // D2

/// Space between two sections without a heading (D2: groups 12 apart after
/// the header group, headings bring their own 20 pt).
const double kSettingsSectionGap = AvoSpacing.xl;

/// The frame of every A8 settings page (Konzept 18 §5): grouped background,
/// a glass back button over the scroll edge fade, the page name as large
/// title (34/41 bold, a VoiceOver header), the offline status under it, an
/// optional sentence, then the sections. Everything scrolls; the bottom
/// leaves room for the tab bar.
///
/// [highlightRowId] (`?row=`) is handed to [RowHighlightScope], so the
/// searched row lights up once.
class SettingsPage extends ConsumerWidget {
  /// Creates a settings page.
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.intro,
    this.highlightRowId,
    this.backLabel,
    this.showOffline = true,
  });

  /// Page name ("Module").
  final String title;

  /// Sections, top to bottom. Space sections without a heading with
  /// [kSettingsSectionGap].
  final List<Widget> children;

  /// One sentence under the title (`body`, `label`, no section).
  final String? intro;

  /// Row to light up once.
  final String? highlightRowId;

  /// VoiceOver label of the back button; defaults to "Zurück".
  final String? backLabel;

  /// Shows "Offline. …" under the title while offline (settings work
  /// locally, Konzept 18 §5).
  final bool showOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final offline = showOffline && ref.watch(isOfflineProvider);
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final top =
        GlassToolbar.topOffset(context) + AvoSizes.toolbarButton + _kTitleTop;
    final bottom = MediaQuery.paddingOf(context).bottom + AvoSpacing.section;
    final text = intro;

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              0,
              AvoSpacing.screen,
              _kTitleBottom,
            ),
            child: Semantics(
              header: true,
              namesRoute: true,
              child: Text(title, style: context.text(AvoTextStyle.largeTitle)),
            ),
          ),
          if (offline) ...[
            StatusRow(
              kind: StatusKind.offline,
              text: context.tr('common_offline'),
            ),
            const SizedBox(height: AvoSpacing.s),
          ],
          if (text != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AvoSpacing.screen,
                0,
                AvoSpacing.screen,
                AvoSpacing.m,
              ),
              child: Text(text, style: context.text(AvoTextStyle.body)),
            ),
          ...children,
        ],
      ),
    );
    final id = highlightRowId;
    if (id != null) content = RowHighlightScope(rowId: id, child: content);

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(1),
              child: content,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              sortKey: const OrdinalSortKey(0),
              child: Stack(
                children: [
                  const Positioned.fill(child: ScrollEdgeFade()),
                  Padding(
                    padding: EdgeInsets.only(
                      top: GlassToolbar.topOffset(context),
                      bottom: _kTitleTop,
                    ),
                    child: GlassToolbar(
                      leading: canPop
                          ? GlassIconButton(
                              icon: const AvoIcon(AvoIcons.chevronBack),
                              semanticLabel: backLabel ?? context.tr('back'),
                              onPressed: () => Navigator.of(context).maybePop(),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a settings page: through the router when there is one (the page
/// has a route, `?row=` included), otherwise as a plain push of [fallback]
/// (isolated screens, tests).
void openSettingsLocation(
  BuildContext context,
  String location, [
  WidgetBuilder? fallback,
]) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(location);
    return;
  }
  if (fallback == null) return;
  Navigator.of(context).push(CupertinoPageRoute<void>(builder: fallback));
}

/// Symbols of the settings pages that the base set (`AvoIcons`) does not
/// have, on the 24 pt grid like SF Symbols.
abstract final class SettingsIcons {
  /// `switch.2`: Module.
  static const switches = AvoIconData([
    AvoIconRect(3, 4.5, 18, 6.5, radius: 3.25),
    AvoIconCircle(16.5, 7.75, 1.8, style: AvoIconStyle.fill),
    AvoIconRect(3, 13, 18, 6.5, radius: 3.25),
    AvoIconCircle(7.5, 16.25, 1.8, style: AvoIconStyle.fill),
  ]);

  /// `leaf`: Ernährung & Allergien.
  static const leaf = AvoIconData([
    AvoIconPath('M5 19.5c0-8.4 5.2-13.6 14.5-14.5 0 9.3-5.2 14.5-13.5 14.5z'),
    AvoIconPath('M5 19.5l7.5-7.5'),
  ]);

  /// `person.text.rectangle`: Persönliche Daten.
  static const personText = AvoIconData([
    AvoIconRect(3, 5, 18, 14, radius: 2.5),
    AvoIconCircle(8.5, 10.2, 2),
    AvoIconPath('M5.6 16c.5-1.5 1.5-2.4 2.9-2.4s2.4.9 2.9 2.4'),
    AvoIconPath('M14 10h4M14 13.5h4'),
  ]);

  /// `checklist`: Listen.
  static const checklist = AvoIconData([
    AvoIconPath('M4 6.5 5.5 8 8 5M4 12.5 5.5 14 8 11M4 18.5 5.5 20 8 17'),
    AvoIconPath('M11 6.5h9M11 12.5h9M11 18.5h9'),
  ]);

  /// `bell`: Mitteilungen (D2 X-Profil).
  static const bell = AvoIconData([
    AvoIconPath('M6 16v-5a6 6 0 0 1 12 0v5l2 2H4z'),
    AvoIconPath('M10 20.5h4'),
  ]);

  /// `circle.lefthalf.filled`: Darstellung (D2 X-Profil).
  static const appearance = AvoIconData([
    AvoIconCircle(12, 12, 8),
    AvoIconPath('M12 4a8 8 0 0 1 0 16z', style: AvoIconStyle.fill),
  ]);

  /// `globe`: Sprache.
  static const globe = AvoIconData([
    AvoIconCircle(12, 12, 8.5),
    AvoIconPath('M3.5 12h17'),
    AvoIconPath(
      'M12 3.5c2.3 2.4 3.4 5.2 3.4 8.5s-1.1 6.1-3.4 8.5c-2.3-2.4-3.4-5.2-3.4'
      '-8.5s1.1-6.1 3.4-8.5z',
    ),
  ]);

  /// `doc.text`: Rechtliches.
  static const doc = AvoIconData([
    AvoIconRect(5.5, 3.5, 13, 17, radius: 2),
    AvoIconPath('M9 8.5h6M9 12h6M9 15.5h4'),
  ]);

  /// `ant`: "Fehler melden" (Konzept 18 E18-01).
  static const ant = AvoIconData([
    AvoIconCircle(12, 7.5, 2.6, style: AvoIconStyle.fill),
    AvoIconPath(
      'M12 10.6c-2.9 0-4.4 2.3-4.4 5.1s1.5 5 4.4 5 4.4-2.2 4.4-5-1.5-5.1-4.4-5.1z',
      style: AvoIconStyle.fill,
    ),
    AvoIconPath('M7.6 13.4H4.2M7.8 17.6H4.6M16.4 13.4h3.4M16.2 17.6h3.2'),
    AvoIconPath('M10 5.2 8.6 3.4M14 5.2l1.4-1.8'),
  ]);

  /// `star`: "Avo bewerten".
  static const star = AvoIconData([
    AvoIconPath(
      'M12 3.4l2.6 5.3 5.8.85-4.2 4.1 1 5.8L12 16.7l-5.2 2.75 1-5.8-4.2-4.1 '
      '5.8-.85z',
      style: AvoIconStyle.fill,
    ),
  ]);

  /// `book`: "Anleitung".
  static const book = AvoIconData([
    AvoIconPath(
      'M4 5.5c2.6-.9 5.3-.7 8 1 2.7-1.7 5.4-1.9 8-1v13c-2.6-.9-5.3-.7-8 1'
      '-2.7-1.7-5.4-1.9-8-1z',
    ),
    AvoIconPath('M12 6.5v13'),
  ]);

  /// `arrow.counterclockwise`: "Tipps zurücksetzen".
  static const reset = AvoIconData([
    AvoIconPath('M5.5 12a6.5 6.5 0 1 0 2-4.7'),
    AvoIconPath('M5 4.5v4h4'),
  ]);
}

/// The coloured icon tile in front of a settings row (D2 X-Profil).
/// Decorative for VoiceOver.
class SettingsIconTile extends StatelessWidget {
  /// Creates a tile with [icon] on [color] (a D2 data colour).
  const SettingsIconTile({super.key, required this.icon, required this.color});

  /// The glyph, drawn white.
  final AvoIconData icon;

  /// Tile colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(_kTileRadius),
        ),
        child: SizedBox.square(
          dimension: _kTileSize,
          child: Center(
            child: AvoIcon(
              icon,
              size: _kTileGlyph,
              // White glyph on a data colour (D2), in light and dark mode.
              color: const Color(0xFFFFFFFF), // D2
            ),
          ),
        ),
      ),
    );
  }
}

/// The press highlight and frame of the rows in this file (same as
/// `settings_rows.dart`).
class _RowFrame extends StatefulWidget {
  const _RowFrame({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_RowFrame> createState() => _RowFrameState();
}

class _RowFrameState extends State<_RowFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlight;

  @override
  void initState() {
    super.initState();
    _highlight = AnimationController.unbounded(vsync: this);
  }

  void _release() {
    _highlight.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _highlight.value,
        0,
        _highlight.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _kRowVerticalPadding,
        ),
        child: widget.child,
      ),
    );
    final onTap = widget.onTap;
    if (onTap == null) return row;
    final fill = context.colors.fillStrong;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: (_) => _highlight
        ..stop()
        ..value = 1,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _highlight,
        builder: (context, child) {
          final t = _highlight.value.clamp(0.0, 1.0);
          return ColoredBox(
            color: fill.withValues(alpha: fill.a * t),
            child: child,
          );
        },
        child: row,
      ),
    );
  }
}

/// One option of a single choice ("System", "Hell", "Dunkel"): title,
/// optional subtitle, a checkmark in the accent colour at the end when
/// chosen (iOS pattern, Konzept 18 §5.6). VoiceOver reads a button with a
/// selected state in a mutually exclusive group.
class ChoiceRow extends StatelessWidget {
  /// Creates a choice row.
  const ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sub = subtitle;
    final ax = context.isAccessibilityText;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: sub == null ? title : '$title, $sub',
      onTap: onTap,
      child: ExcludeSemantics(
        child: _RowFrame(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: context.text(AvoTextStyle.body)),
                    if (sub != null)
                      Text(
                        sub,
                        style: context.text(
                          AvoTextStyle.subhead,
                          color: colors.secondaryLabel,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AvoSpacing.m),
              SizedBox(
                width: _kCheckSize,
                height: context.typography.lineHeightOf(AvoTextStyle.body),
                child: selected
                    ? AvoIcon(
                        AvoIcons.check,
                        size: _kCheckSize,
                        color: colors.tint,
                        strokeWidth: 2.6,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row that runs an action, its title in the accent colour without a
/// chevron ("Mitteilungen erlauben", "Tipps zurücksetzen"); optional leading
/// tile and subtitle.
class SettingsActionRow extends StatelessWidget {
  /// Creates an action row.
  const SettingsActionRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Runs the action; null shows the row disabled.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sub = subtitle;
    final lead = leading;
    final enabled = onTap != null;
    final ax = context.isAccessibilityText;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: sub == null ? title : '$title, $sub',
      onTap: onTap,
      child: ExcludeSemantics(
        child: _RowFrame(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (lead != null) ...[lead, const SizedBox(width: AvoSpacing.m)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.text(
                        AvoTextStyle.body,
                        color: enabled ? colors.tint : colors.secondaryLabel,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        style: context.text(
                          AvoTextStyle.subhead,
                          color: colors.secondaryLabel,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A question that unfolds its answer in place (Konzept 18 §5.8): title in
/// `body`, `chevron.down` at the end that turns up when open, the answer in
/// `body` `label` (never pale grey), optional [actions] (plain links such
/// as "Profil › Konto") under it. VoiceOver reads a button with the expanded
/// state.
class ExpandableRow extends StatelessWidget {
  /// Creates an expandable row.
  const ExpandableRow({
    super.key,
    required this.title,
    required this.answer,
    required this.expanded,
    required this.onTap,
    this.actions = const [],
  });

  final String title;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  /// Shown under the answer while open.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduce = context.reduceMotion;
    final head = Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: _RowFrame(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title, style: context.text(AvoTextStyle.body)),
              ),
              const SizedBox(width: AvoSpacing.m),
              SizedBox(
                height: context.typography.lineHeightOf(AvoTextStyle.body),
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: reduce ? Duration.zero : AvoMotion.fadeReduced,
                  child: AvoIcon(
                    AvoIcons.chevronDown,
                    size: _kCheckSize,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return AnimatedSize(
      duration: reduce ? Duration.zero : AvoMotion.fadeReduced,
      curve: Curves.easeInOut,
      alignment: AlignmentDirectional.topStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AvoSpacing.l,
                0,
                AvoSpacing.l,
                AvoSpacing.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(answer, style: context.text(AvoTextStyle.body)),
                  ...actions,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A centred footnote at the end of a page ("Avo · Version 1.1.4 (31)").
class SettingsFooter extends StatelessWidget {
  /// Creates a footer.
  const SettingsFooter(this.text, {super.key, this.onLongPress});

  final String text;

  /// Debug builds: the developer menu (Konzept 18 §5.8).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final label = Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        AvoSpacing.xxl,
        AvoSpacing.screen,
        0,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text(
          AvoTextStyle.footnote,
          color: context.colors.secondaryLabel,
        ),
      ),
    );
    final press = onLongPress;
    if (press == null) return label;
    return GestureDetector(onLongPress: press, child: label);
  }
}
