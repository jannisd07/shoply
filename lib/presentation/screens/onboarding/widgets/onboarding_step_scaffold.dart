import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';

/// Step progress capsule (Konzept 17 §9.2): 96 × 3 pt.
const double _kProgressWidth = 96;
const double _kProgressHeight = 3;

/// The action bar stays pinned while it takes at most this share of the
/// screen height; above that the main action scrolls with the content
/// (Konzept 17 §2.3).
const double _kPinnedBarMaxShare = 0.25;

/// Space between the title and the sentence below it, and before the step's
/// content (Konzept 17 §2.1).
const double _kTitleGap = AvoSpacing.s;
const double _kContentGap = AvoSpacing.xxl;

/// Height of the soft fade above the pinned action bar (Konzept 17 §2.1).
const double _kBarFade = 40;

/// "Schritt 3 von 6" as a 96 × 3 pt capsule (Konzept 17 §9.2): track in
/// `fill`, value in `label` (progress is not green, K-09). The value glides
/// with a spring when [step] changes and jumps under Reduce Motion.
class StepProgress extends StatefulWidget {
  const StepProgress({
    super.key,
    required this.step,
    required this.total,
    required this.semanticLabel,
  });

  /// Current step, 1-based.
  final int step;

  /// Number of counted steps.
  final int total;

  /// VoiceOver text, e.g. "Schritt 3 von 6".
  final String semanticLabel;

  @override
  State<StepProgress> createState() => _StepProgressState();
}

class _StepProgressState extends State<StepProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _value = AnimationController.unbounded(
    vsync: this,
    value: _target,
  );

  double get _target =>
      widget.total <= 0 ? 0 : (widget.step / widget.total).clamp(0.0, 1.0);

  @override
  void didUpdateWidget(covariant StepProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step == widget.step && oldWidget.total == widget.total) {
      return;
    }
    if (context.reduceMotion) {
      _value.value = _target;
    } else {
      _value.animateWith(
        SpringSimulation(
          AvoMotion.standard,
          _value.value,
          _target,
          _value.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: widget.semanticLabel,
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        width: _kProgressWidth,
        height: _kProgressHeight,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.fill,
            shape: const StadiumBorder(),
          ),
          child: AnimatedBuilder(
            animation: _value,
            builder: (context, _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: _value.value.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.label,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One step of the onboarding and account flow (Konzept 17 §2,
/// `OnboardingStepScaffold`): a standing top bar (glass back, [progress],
/// glass "Überspringen"), scrolling content on the grouped background
/// (title `title1`, a sentence in `body`, then [children]) and the one main
/// action at the bottom.
///
/// - The action bar stays pinned while it needs at most 25 % of the screen
///   height and sits on the keyboard; with large text it moves to the end of
///   the content and scrolls with it.
/// - "Überspringen" moves below the main action as a plain button from AX1
///   or when it doesn't fit next to back and progress.
/// - VoiceOver order: back, progress, title (heading), sentence, content,
///   main action, skip.
class OnboardingStepPage extends StatelessWidget {
  const OnboardingStepPage({
    super.key,
    required this.title,
    this.message,
    this.children = const [],
    required this.primaryAction,
    this.progress,
    this.onBack,
    this.backLabel,
    this.onSkip,
    this.skipLabel,
  });

  /// The step's question or statement, `title1`.
  final String title;

  /// One sentence below the title, `body`.
  final String? message;

  /// The step's content: inset sections, toggle rows, chips, fields.
  final List<Widget> children;

  /// The one main action, usually `AppButton.primary(expand: true)`.
  final Widget primaryAction;

  /// Usually a [StepProgress]; nothing when null.
  final Widget? progress;

  /// Shows the glass back button; the place stays empty without it (after
  /// the account step, Konzept 17 §2.2).
  final VoidCallback? onBack;

  /// VoiceOver label of the back button; `back` by default.
  final String? backLabel;

  /// Shows "Überspringen".
  final VoidCallback? onSkip;

  /// Text of the skip button; `skip` by default.
  final String? skipLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final skipText = skipLabel ?? context.tr('skip');

    return ColoredBox(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // The skip capsule fits next to back (44) and progress (96) at
          // default sizes from 375 pt; below that and from AX1 it moves.
          final skipInBar =
              onSkip != null && !context.isAccessibilityText && width >= 360;
          final skipBelow = onSkip != null && !skipInBar;

          final topBar = Padding(
            padding: EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              media.padding.top + AvoSpacing.xs,
              AvoSpacing.screen,
              AvoSpacing.xs,
            ),
            // At least 44 pt; grows with the skip capsule's text.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AvoSizes.toolbarButton,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress != null) progress!,
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    heightFactor: 1,
                    child: onBack == null
                        ? const SizedBox.shrink()
                        : GlassIconButton(
                            icon: const AvoIcon(AvoIcons.chevronBack),
                            semanticLabel: backLabel ?? context.tr('back'),
                            onPressed: onBack,
                          ),
                  ),
                  if (skipInBar)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      heightFactor: 1,
                      child: AppButton.secondary(
                        label: skipText,
                        onPressed: onSkip,
                        floating: true,
                      ),
                    ),
                ],
              ),
            ),
          );

          final actions = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primaryAction,
              if (skipBelow)
                Center(
                  child: AppButton.plain(label: skipText, onPressed: onSkip),
                ),
            ],
          );

          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: context.text(AvoTextStyle.title1)),
              ),
              if (message != null) ...[
                const SizedBox(height: _kTitleGap),
                Text(message!, style: context.text(AvoTextStyle.body)),
              ],
              const SizedBox(height: _kContentGap),
            ],
          );

          // Pinned while the bar is small; the estimate uses the main
          // action's text height at the current size (44 pt minimum).
          final barEstimate =
              AvoSizes.hitTarget +
              context.typography.lineHeightOf(AvoTextStyle.body) *
                  (skipBelow ? 2 : 1) +
              AvoSpacing.l * 2;
          final pinned =
              barEstimate <= constraints.maxHeight * _kPinnedBarMaxShare;

          final content = ListView(
            padding: EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              AvoSpacing.l,
              AvoSpacing.screen,
              pinned ? AvoSpacing.l : media.padding.bottom + AvoSpacing.l,
            ),
            children: [
              header,
              ...children,
              if (!pinned) ...[const SizedBox(height: AvoSpacing.xxl), actions],
            ],
          );

          return Column(
            children: [
              topBar,
              Expanded(child: content),
              if (pinned)
                _PinnedActionBar(
                  bottomInset: media.viewInsets.bottom > 0
                      ? media.viewInsets.bottom
                      : media.padding.bottom,
                  child: actions,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The pinned bar: no glass, no line, a soft fade from the background above
/// it (Konzept 17 §2.1), 16 pt above the safe area or on the keyboard.
class _PinnedActionBar extends StatelessWidget {
  const _PinnedActionBar({required this.bottomInset, required this.child});

  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = context.colors.background;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -_kBarFade,
          height: _kBarFade,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [base, base.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        ColoredBox(
          color: base,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              AvoSpacing.s,
              AvoSpacing.screen,
              bottomInset + AvoSpacing.l,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
