import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

/// Avo's size on Willkommen (Konzept 17 §3.2): 160 pt, 96 pt from AX1, gone
/// from AX3.
const double _kFigure = 160;
const double _kFigureAx = 96;

/// The sentence stays in two calm lines at 393 pt (Konzept 17 §3.2).
const double _kSentenceMaxWidth = 300;

/// Free space above Avo: at least 48 pt, about an eighth of the height, so
/// the block stands a little above the middle (Konzept 17 §3.2).
const double _kMinTopGap = 48;
const double _kTopShare = 0.12;

/// Willkommen (Konzept 17 §3.2), the one place that greets. No step frame:
/// Avo, the app name, one sentence, then "Los geht's" and "Ich habe schon
/// ein Konto". The variant for `/welcome` ([returning]) offers "Anmelden"
/// first and "Neues Konto anlegen" below.
///
/// Everything sits in one scroll area; the buttons stay at the bottom while
/// the content fits and follow it otherwise.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.onStart,
    required this.onLogin,
    this.returning = false,
    this.invited = false,
  });

  /// "Los geht's" (or "Neues Konto anlegen" in the variant).
  final VoidCallback onStart;

  /// "Ich habe schon ein Konto" (or "Anmelden" in the variant).
  final VoidCallback onLogin;

  /// The device knows the onboarding already (after signing out).
  final bool returning;

  /// A list invitation is waiting (Konzept 17 §5.1).
  final bool invited;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final category = context.typography.category;
    final showFigure = category.index < ContentSizeCategory.ax3.index;
    final figureSize = context.isAccessibilityText ? _kFigureAx : _kFigure;
    final media = MediaQuery.of(context);

    final primary = AppButton.primary(
      label: context.tr(returning ? 'onb_welcome_login' : 'onb_welcome_start'),
      onPressed: returning ? onLogin : onStart,
      size: AppButtonSize.large,
      expand: true,
    );
    final secondary = AppButton.plain(
      label: context.tr(
        returning ? 'onb_welcome_new_account' : 'onb_welcome_have_account',
      ),
      onPressed: returning ? onStart : onLogin,
    );

    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFigure) ...[
          Center(
            child: AvoFigure(pose: AvoPose.waving, size: figureSize),
          ),
          const SizedBox(height: AvoSpacing.xxl),
        ],
        Semantics(
          header: true,
          child: Text(
            context.tr('onb_welcome_title'),
            textAlign: TextAlign.center,
            style: context.text(AvoTextStyle.largeTitle),
          ),
        ),
        const SizedBox(height: AvoSpacing.s),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kSentenceMaxWidth),
            child: Text(
              context.tr('onb_welcome_sentence'),
              textAlign: TextAlign.center,
              style: context.text(AvoTextStyle.body),
            ),
          ),
        ),
        if (invited) ...[
          const SizedBox(height: AvoSpacing.xxl),
          InsetSection(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AvoSpacing.l,
                  vertical: AvoSpacing.m,
                ),
                child: Row(
                  children: [
                    AvoIcon(
                      AvoIcons.people,
                      size: 22,
                      color: colors.secondaryLabel,
                    ),
                    const SizedBox(width: AvoSpacing.m),
                    Expanded(
                      child: Text(
                        context.tr('onb_welcome_invited'),
                        style: context.text(AvoTextStyle.callout),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final bottom = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AvoSpacing.xxl),
        primary,
        const SizedBox(height: AvoSpacing.s),
        Center(child: secondary),
      ],
    );

    // One scroll area: while everything fits, the block stands a little
    // above the middle and the buttons at the bottom; otherwise the buttons
    // follow the content. No intrinsic sizes, so AX5 cannot overflow.
    return ColoredBox(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = media.padding.top + media.padding.bottom;
          final minHeight = (constraints.maxHeight - vertical - AvoSpacing.l)
              .clamp(0.0, double.infinity);
          final topGap = (minHeight * _kTopShare).clamp(
            _kMinTopGap,
            double.infinity,
          );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              media.padding.top,
              AvoSpacing.screen,
              media.padding.bottom + AvoSpacing.l,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topGap),
                    child: top,
                  ),
                  bottom,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
