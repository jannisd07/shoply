import 'package:flutter/material.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

/// One tab of [AppTabBar].
@immutable
class AppTabItem {
  const AppTabItem({required this.icon, required this.label});

  final AvoIconData icon;
  final String label;
}

/// The floating D2 tab bar: a glass capsule (64 pt, radius 32, padding 4,
/// gap 2) with items 56 pt high. The active item shows the filled icon in
/// green on a soft green glow.
///
/// - No haptics on tab switches (Konzept 00 §11).
/// - Labels follow Dynamic Type only up to xxxL (the tab-label table stops
///   at 14 pt); at accessibility sizes a long press shows the large content
///   viewer, like UIKit tab bars.
/// - VoiceOver: "Listen, Tab 2 von 5, ausgewählt".
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<AppTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  // D2 metrics.
  static const double _padding = 4;
  static const double _gap = 2;
  static const double _iconSize = 26;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.tr('common_main_navigation'),
      child: GlassSurface(
        shape: GlassShape.capsule,
        interactive: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.tabBarHeight),
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: _TabButton(
                      item: items[i],
                      selected: i == selectedIndex,
                      position: i + 1,
                      count: items.length,
                      onTap: () => onSelect(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.position,
    required this.count,
    required this.onTap,
  });

  final AppTabItem item;
  final bool selected;
  final int position;
  final int count;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  OverlayEntry? _largeContent;

  void _showLargeContent() {
    if (!context.isAccessibilityText) return;
    final colors = context.colors;
    _largeContent = OverlayEntry(
      builder: (context) => Center(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(AvoRadii.card),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.2),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AvoSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvoIcon(widget.item.icon, size: 64, color: colors.label),
                  const SizedBox(height: AvoSpacing.m),
                  Text(
                    widget.item.label,
                    style: context.text(AvoTextStyle.title2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_largeContent!);
  }

  void _hideLargeContent() {
    _largeContent?.remove();
    _largeContent = null;
  }

  @override
  void dispose() {
    _hideLargeContent();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = widget.selected;
    final labelStyle = context.text(
      AvoTextStyle.tabLabel,
      color: selected ? colors.tint : colors.tertiaryLabel,
      weight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AvoIcon(
          widget.item.icon,
          size: AppTabBar._iconSize,
          filled: selected,
          color: selected ? colors.tintIcon : colors.tertiaryLabel,
        ),
        const SizedBox(height: 3), // D2
        Text(
          widget.item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          // Tab labels stop growing at xxxL; beyond that the large content
          // viewer (long press) takes over.
          textScaler: TextScaler.noScaling,
          style: labelStyle.copyWith(
            fontSize: context.typography.sizeOf(AvoTextStyle.tabLabel),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      label: widget.item.label,
      hint: context.tr(
        'common_tab_position',
        params: {'index': '${widget.position}', 'count': '${widget.count}'},
      ),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPressStart: (_) => _showLargeContent(),
        onLongPressEnd: (_) {
          _hideLargeContent();
          if (context.isAccessibilityText) widget.onTap();
        },
        onLongPressCancel: _hideLargeContent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.tabItemHeight),
          // D2: white .35 under a radial green glow (gradient ignores
          // `color`, so the white sits in its own layer).
          child: DecoratedBox(
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AvoSizes.tabItemHeight / 2,
                    ),
                    color: colors.surface.withValues(alpha: 0.35),
                  )
                : const BoxDecoration(),
            child: DecoratedBox(
              decoration: selected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AvoSizes.tabItemHeight / 2,
                      ),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1), // 50 % 45 %
                        radius: 0.75,
                        colors: [
                          colors.tintIcon.withValues(alpha: 0.20),
                          colors.tintIcon.withValues(alpha: 0.09),
                          colors.tintIcon.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    )
                  : const BoxDecoration(),
              // heightFactor 1: the item is as tall as its content (min 56), not as
              // tall as the space the shell offers.
              child: Center(heightFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
