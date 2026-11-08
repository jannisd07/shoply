import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';

/// Labels in the floating glass grow up to xxxL (body 23 pt) and then stay
/// (Konzept 13 §2.7, E-19).
const double _chromeMaxScale = 23 / 17;
const double _closeGlyph = 18; // D2 X-Essen
const double _titleChevron = 20;

/// A swipe from the left edge faster than this goes one step back.
const double _edgeSwipeVelocity = 300;

/// The frame of the recipe editor in the style of [FullScreenEditor]: glass
/// close (X) on the left, "Mehr" and the tinted capsule "Weiter" /
/// "Veröffentlichen" on the right, the progress line under it, then the
/// step. The keyboard shrinks the step, so the focused field stays visible.
class RecipeEditorFrame extends StatelessWidget {
  const RecipeEditorFrame({
    super.key,
    required this.step,
    required this.stepCount,
    required this.onClose,
    required this.nextLabel,
    required this.onNext,
    required this.menuItems,
    required this.body,
    this.working = false,
    this.status,
    this.onSwipeBack,
  });

  /// 0-based.
  final int step;
  final int stepCount;
  final VoidCallback onClose;
  final String nextLabel;

  /// Null dims "Weiter" (while loading).
  final VoidCallback? onNext;

  /// The "Mehr" menu ("Entwurf verwerfen").
  final List<AvoMenuEntry> menuItems;

  /// The pages of the steps.
  final Widget body;

  /// Publishing: an activity indicator in the capsule, taps blocked.
  final bool working;

  /// One [StatusRow] under the progress line (offline, not saved).
  final Widget? status;

  /// A swipe from the left edge (one step back); null turns it off.
  final VoidCallback? onSwipeBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final status = this.status;
    final swipeBack = onSwipeBack;
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: GlassToolbar.topOffset(context)),
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: _chromeMaxScale,
                child: GlassToolbar(
                  leading: GlassIconButton(
                    icon: const AvoIcon(AvoIcons.xmark, size: _closeGlyph),
                    semanticLabel: context.tr('common_close'),
                    onPressed: onClose,
                  ),
                  trailing: [
                    if (menuItems.isNotEmpty) AvoMenuButton(items: menuItems),
                    AppButton.primary(
                      label: nextLabel,
                      floating: true,
                      working: working,
                      workingLabel: context.tr('recipe_editor_publishing'),
                      onPressed: onNext,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AvoSpacing.m),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AvoSpacing.screen,
                ),
                child: ProgressLine(
                  value: (step + 1) / stepCount,
                  semanticLabel: context.tr('common_progress'),
                  semanticValue: context.tr(
                    'recipe_editor_step_of',
                    params: {'n': '${step + 1}', 'total': '$stepCount'},
                  ),
                ),
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: AvoSpacing.s),
                  child: status,
                ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: body),
                    if (swipeBack != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: AvoSpacing.xl,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          excludeFromSemantics: true,
                          onHorizontalDragEnd: (d) {
                            final v = d.primaryVelocity ?? 0;
                            if (v > _edgeSwipeVelocity) swipeBack();
                          },
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

/// One step of the editor: the step name as a large title that opens the
/// step menu (Wayfinding: "Zutaten ⌄", under it "Neues Rezept · 3 von 4"),
/// then the step's sections. Scrolls; dragging hides the keyboard.
class RecipeEditorStepPage extends StatelessWidget {
  const RecipeEditorStepPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTitleTap,
    required this.child,
  });

  final String title;

  /// "Neues Rezept · 3 von 4".
  final String subtitle;

  /// Opens the step menu, anchored at the title.
  final ValueChanged<BuildContext> onTitleTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // The tab bar may still float over this route (it lives in the tab
    // branch); keep the last field above it.
    final bottom = keyboardOpen
        ? AvoSpacing.section
        : ShellInsets.bottom(context);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(top: AvoSpacing.l, bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: Builder(
              builder: (anchor) => Semantics(
                button: true,
                header: true,
                label: '$title, $subtitle',
                hint: context.tr('recipe_editor_switch_step'),
                excludeSemantics: true,
                onTap: () => onTitleTap(anchor),
                child: PressableScale(
                  onPressed: () => onTitleTap(anchor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: context.text(AvoTextStyle.largeTitle),
                            ),
                          ),
                          const SizedBox(width: AvoSpacing.s),
                          AvoIcon(
                            AvoIcons.chevronDown,
                            size: _titleChevron,
                            color: colors.secondaryLabel,
                          ),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: context.text(
                          AvoTextStyle.footnote,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AvoSpacing.l),
          child,
        ],
      ),
    );
  }
}
