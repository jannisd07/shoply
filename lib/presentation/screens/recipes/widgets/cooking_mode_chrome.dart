import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_logic.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_timers.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';

/// Labels in the floating glass grow up to xxxL (body 23 pt) and then stay
/// (Konzept 13 §2.7, E-19).
const double kCookingChromeMaxScale = 23 / 17;

/// Below this width the controls go compact: servings as a symbol with the
/// number, the timer capsule with the time only, "Weiter" as a tinted
/// circle (Konzept 13 §16.7).
const double kCookingCompactWidth = 360;

const double _itemGap = AvoSpacing.s; // D2 toolbar gap
const double _capsuleSide = 18; // D2 text capsule padding
const double _capsuleVertical = 11; // (44 - 22) / 2
const double _capsuleIcon = 20;
const double _finishedScale = 1.08; // Konzept 13 §16.3

/// Caps the text size of the floating glass at xxxL.
class _ChromeScale extends StatelessWidget {
  const _ChromeScale({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: kCookingChromeMaxScale,
    child: child,
  );
}

/// A glass text capsule (servings, timer): at least 44 × 44 pt, grows with
/// its label.
class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({
    required this.child,
    required this.semanticLabel,
    required this.onPressed,
    this.tinted = false,
    this.semanticHint,
  });

  final Widget child;
  final String semanticLabel;
  final String? semanticHint;
  final VoidCallback? onPressed;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      hint: semanticHint,
      onTap: onPressed,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onPressed,
        child: GlassSurface(
          shape: GlassShape.capsule,
          tinted: tinted,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AvoSizes.toolbarButton,
              minWidth: AvoSizes.hitTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _capsuleSide,
                vertical: _capsuleVertical,
              ),
              child: Center(widthFactor: 1, heightFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// The toolbar of the cooking mode: close (chevron down), the recipe name
/// and where one is ("Schritt 3 von 5"), the servings capsule and the
/// overview.
class CookingTopBar extends StatelessWidget {
  const CookingTopBar({
    super.key,
    required this.recipeName,
    required this.pageLabel,
    required this.shortPageLabel,
    required this.servings,
    required this.onClose,
    required this.onServings,
    required this.onOverview,
  });

  final String recipeName;

  /// "Schritt 3 von 5", "Zutaten", "Fertig".
  final String pageLabel;

  /// "3 von 5" for large text and narrow screens.
  final String shortPageLabel;
  final int servings;
  final VoidCallback onClose;
  final VoidCallback onServings;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Decided on the real text size, before the chrome caps it.
    final ax = context.isAccessibilityText;
    final servingsLabel = context.tr(
      servings == 1 ? 'recipe_cook_servings_one' : 'recipe_cook_servings',
      params: {'n': '$servings'},
    );
    return _ChromeScale(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < kCookingCompactWidth || ax;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: Row(
              children: [
                GlassIconButton(
                  icon: const AvoIcon(AvoIcons.chevronDown),
                  semanticLabel: context.tr('recipe_cook_close'),
                  onPressed: onClose,
                ),
                const SizedBox(width: _itemGap),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: '$recipeName, $pageLabel',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!ax)
                          Text(
                            recipeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: context.text(
                              AvoTextStyle.subhead,
                              weight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          compact ? shortPageLabel : pageLabel,
                          textAlign: TextAlign.center,
                          style: context.text(
                            AvoTextStyle.footnote,
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _itemGap),
                _GlassCapsule(
                  semanticLabel: servingsLabel,
                  semanticHint: context.tr('recipe_cook_servings_hint'),
                  onPressed: onServings,
                  child: compact
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AvoIcon(AvoIcons.people, size: _capsuleIcon),
                            const SizedBox(width: AvoSpacing.xs),
                            Text(
                              '$servings',
                              style: context.text(
                                AvoTextStyle.subhead,
                                weight: FontWeight.w600,
                                tabular: true,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          servingsLabel,
                          style: context.text(
                            AvoTextStyle.subhead,
                            weight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(width: _itemGap),
                GlassIconButton(
                  icon: const Icon(CupertinoIcons.list_bullet),
                  semanticLabel: context.tr('recipe_cook_overview'),
                  onPressed: onOverview,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The controls at the bottom: back, the timer capsule while a timer
/// exists, and the one tinted action ("Weiter", "Fertig", "Schließen").
class CookingBottomBar extends StatelessWidget {
  const CookingBottomBar({
    super.key,
    required this.onBack,
    required this.nextLabel,
    required this.onNext,
    this.nextIsPro = false,
    this.timer,
  });

  /// Null disables back (first page).
  final VoidCallback? onBack;
  final String nextLabel;
  final VoidCallback onNext;

  /// Shows a Pro badge on the next capsule (cooking mode locked behind Pro,
  /// Konzept 13 §16.6).
  final bool nextIsPro;

  /// The timer capsule, built by the screen.
  final Widget? timer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    return _ChromeScale(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < kCookingCompactWidth || ax;
          final Widget next = compact && !nextIsPro
              ? GlassIconButton(
                  icon: const AvoIcon(AvoIcons.chevronRight),
                  semanticLabel: nextLabel,
                  tinted: true,
                  onPressed: onNext,
                )
              : _GlassCapsule(
                  semanticLabel: nextIsPro
                      ? '$nextLabel, ${context.tr('common_pro_feature')}'
                      : nextLabel,
                  tinted: true,
                  onPressed: onNext,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          nextLabel,
                          textAlign: TextAlign.center,
                          style: context.text(
                            AvoTextStyle.body,
                            weight: FontWeight.w600,
                            color: colors.onTint,
                          ),
                        ),
                      ),
                      if (nextIsPro) ...[
                        const SizedBox(width: AvoSpacing.s),
                        const ProBadge(onTint: true),
                      ],
                    ],
                  ),
                );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: Row(
              children: [
                GlassIconButton(
                  icon: const AvoIcon(AvoIcons.chevronBack),
                  semanticLabel: context.tr('recipe_cook_previous'),
                  onPressed: onBack,
                ),
                const SizedBox(width: _itemGap),
                Expanded(
                  child: Center(child: timer ?? const SizedBox.shrink()),
                ),
                const SizedBox(width: _itemGap),
                // At most half the row, but always flush right (a Flexible
                // would leave its unused share as a gap after it).
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: next,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The timer capsule: the timer that ends first ("Schritt 3 · 12:47", "+1"
/// when more run), or "Schritt 3 fertig" once it ran out; then it grows
/// once (1.08, Reduce Motion: no movement). Never tinted: the one tint of
/// the bar belongs to "Weiter".
class CookingTimerCapsule extends StatefulWidget {
  const CookingTimerCapsule({
    super.key,
    required this.timers,
    required this.onTap,
  });

  final CookingTimers timers;

  /// Tapped; gets the capsule's context to anchor a menu.
  final ValueChanged<BuildContext> onTap;

  @override
  State<CookingTimerCapsule> createState() => _CookingTimerCapsuleState();
}

class _CookingTimerCapsuleState extends State<CookingTimerCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  final Set<int> _grown = {};

  @override
  void initState() {
    super.initState();
    widget.timers.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant CookingTimerCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timers != widget.timers) {
      oldWidget.timers.removeListener(_changed);
      widget.timers.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.timers.removeListener(_changed);
    _grow.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final timers = widget.timers;
    final finishedNow = {
      for (final t in timers.timers)
        if (t.finishedAt(timers.now)) t.step,
    };
    _grown.removeWhere((s) => !finishedNow.contains(s));
    final fresh = finishedNow.difference(_grown);
    if (fresh.isNotEmpty) {
      _grown.addAll(fresh);
      if (!context.reduceMotion) {
        // Up and back on the quick spring, from the current value.
        _grow
            .animateWith(
              SpringSimulation(AvoMotion.quick, _grow.value, 1, _grow.velocity),
            )
            .then((_) {
              if (!mounted) return;
              _grow.animateWith(
                SpringSimulation(AvoMotion.quick, _grow.value, 0, 0),
              );
            });
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final timers = widget.timers;
    final list = timers.timers;
    if (list.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final now = timers.now;
    final first = list.first;
    final finished = first.finishedAt(now);
    final stepLabel = context.tr(
      'recipe_cook_step_label',
      params: {'n': '${first.step + 1}'},
    );
    final clock = formatTimerClock(first.left(now));
    final more = list.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.sizeOf(context).width < kCookingCompactWidth ||
            constraints.maxWidth < AvoSizes.hitTarget * 3;
        final String text;
        final String semantic;
        if (finished) {
          text = compact
              ? context.tr('recipe_cook_timer_done_short')
              : context.tr(
                  'recipe_cook_timer_done_step',
                  params: {'step': stepLabel},
                );
          semantic = context.tr(
            'recipe_cook_timer_done_announce',
            params: {'step': stepLabel},
          );
        } else {
          final base = compact ? clock : '$stepLabel · $clock';
          text = more > 0 ? '$base +$more' : base;
          semantic = context.tr(
            first.running
                ? 'recipe_cook_timer_semantic'
                : 'recipe_cook_timer_semantic_paused',
            params: {'step': stepLabel, 'time': clock},
          );
        }
        final textColor = !finished && !first.running
            ? colors.secondaryLabel
            : colors.label;
        final capsule = _GlassCapsule(
          semanticLabel: semantic,
          semanticHint: context.tr(
            finished
                ? 'recipe_cook_timer_ack_hint'
                : 'recipe_cook_timer_menu_hint',
          ),
          onPressed: () => widget.onTap(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              finished
                  ? Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: _capsuleIcon,
                      color: colors.label,
                    )
                  : AvoIcon(
                      AvoIcons.clock,
                      size: _capsuleIcon,
                      color: textColor,
                    ),
              const SizedBox(width: AvoSpacing.s - AvoSpacing.xxs),
              Flexible(
                child: Text(
                  text,
                  style: context.text(
                    AvoTextStyle.body,
                    weight: FontWeight.w600,
                    color: textColor,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ),
        );
        return AnimatedBuilder(
          animation: _grow,
          child: capsule,
          builder: (context, child) => Transform.scale(
            scale: 1 + (_finishedScale - 1) * _grow.value,
            child: child,
          ),
        );
      },
    );
  }
}

/// Says a finished timer out loud for VoiceOver ("Timer Schritt 3
/// abgelaufen").
void announceTimerFinished(BuildContext context, int step) {
  final label = context.tr(
    'recipe_cook_step_label',
    params: {'n': '${step + 1}'},
  );
  SemanticsService.sendAnnouncement(
    View.of(context),
    context.tr('recipe_cook_timer_done_announce', params: {'step': label}),
    Directionality.of(context),
  );
}
