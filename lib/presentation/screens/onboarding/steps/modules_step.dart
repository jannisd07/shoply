import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_descriptors.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/steps/step_common.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// D2 X-Onboarding `.mod`: white card, radius 22, padding 14/16, gap 10;
// `.ic` 40 pt tile with radius 12; `.tick` 26 pt.
const double _kCardRadius = 22; // D2
const double _kCardGap = 10; // D2
const double _kTile = 40; // D2
const double _kTileRadius = 12; // D2
const double _kTileGlyph = 20; // D2
const double _kTickBorder = 1.6; // D2
const double _kTickGlyph = 14; // D2
const double _kFigure = 72; // D2

/// "Was soll Avo für dich tun?" (Konzept 17 §3.3, D2 X-Onboarding): one card
/// per visible module with a switch-like tick, the AI note with a link to
/// the privacy page, "Weiter" and "Später entscheiden" (the defaults).
class ModulesStep extends ConsumerWidget {
  const ModulesStep({
    super.key,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.progress,
  });

  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final avoOn = draft.isOn(AppModule.avo);
    return OnboardingStepPage(
      title: context.tr('onb_modules_title'),
      message: context.tr('onb_modules_sentence'),
      titleTrailing: context.isAccessibilityText
          ? null
          : const AvoFigure(pose: AvoPose.waving, size: _kFigure),
      progress: progress,
      onBack: onBack,
      onSkip: () => runIfCurrent(context, onSkip),
      skipLabel: context.tr('onb_modules_later'),
      skipBelowAction: true,
      status: const OnboardingSyncStatus(),
      primaryAction: AppButton.primary(
        label: context.tr('next'),
        onPressed: () => runIfCurrent(context, onNext),
        size: AppButtonSize.large,
        expand: true,
      ),
      children: [
        for (final d in visibleModuleDescriptors()) ...[
          ModuleChoiceCard(
            descriptor: d,
            value: draft.isOn(d.module),
            onChanged: (on) => controller.setModule(d.module, on),
          ),
          const SizedBox(height: _kCardGap),
        ],
        const SizedBox(height: AvoSpacing.s),
        Text(
          context.tr(avoOn ? 'onb_modules_ai_note_avo' : 'onb_modules_ai_note'),
          style: context.text(
            AvoTextStyle.footnote,
            color: context.colors.secondaryLabel,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.plain(
            label: context.tr('onb_modules_privacy'),
            onPressed: () => launchUrl(
              Uri.parse(LegalLinks.privacy),
              mode: LaunchMode.inAppBrowserView,
            ),
          ),
        ),
      ],
    );
  }
}

/// One module as a D2 card: coloured tile, title, benefit, tick. The whole
/// card toggles; VoiceOver reads a switch with its state. From AX3 on the
/// tile is left out so the words keep their width (Konzept 17 §2.3).
class ModuleChoiceCard extends StatelessWidget {
  const ModuleChoiceCard({
    super.key,
    required this.descriptor,
    required this.value,
    required this.onChanged,
  });

  final ModuleDescriptor descriptor;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = context.tr(descriptor.titleKey);
    final benefit = context.tr(descriptor.benefitKey);
    final showTile =
        context.typography.category.index < ContentSizeCategory.ax3.index;

    final tick = SizedBox.square(
      dimension: AvoSizes.checkCircle,
      child: DecoratedBox(
        decoration: value
            ? ShapeDecoration(
                color: colors.tintFill,
                shape: const CircleBorder(),
              )
            : ShapeDecoration(
                shape: CircleBorder(
                  side: BorderSide(
                    color: colors.uncheckedRing,
                    width: _kTickBorder,
                  ),
                ),
              ),
        child: value
            ? Center(
                child: AvoIcon(
                  AvoIcons.check,
                  size: _kTickGlyph,
                  color: colors.onTint,
                  strokeWidth: 3,
                ),
              )
            : null,
      ),
    );

    return Semantics(
      container: true,
      toggled: value,
      label: '$title, $benefit',
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(_kCardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: 14, // D2
              ),
              child: Row(
                children: [
                  if (showTile) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: descriptor.tileColor,
                        borderRadius: BorderRadius.circular(_kTileRadius),
                      ),
                      child: SizedBox.square(
                        dimension: _kTile,
                        child: Center(
                          child: AvoIcon(
                            descriptor.icon,
                            size: _kTileGlyph,
                            // White glyph on a data colour (D2).
                            color: const Color(0xFFFFFFFF), // D2
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14), // D2
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text(AvoTextStyle.headline)),
                        Text(
                          benefit,
                          style: context.text(
                            AvoTextStyle.footnote,
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                  tick,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
