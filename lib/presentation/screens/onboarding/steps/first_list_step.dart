import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/steps/step_common.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Corner radius of the name field (a capsule on one line).
const double _kFieldRadius = 26;

/// "Deine erste Liste" (Konzept 17 §3.11): a name field with focus, the
/// preview row in the first free list colour and up to four suggestions.
/// An empty field creates "Wocheneinkauf", so the quickest tap still ends on
/// a list. The market follows from the name (Teil B's store guess reads it).
class FirstListStep extends ConsumerStatefulWidget {
  const FirstListStep({
    super.key,
    required this.onCreate,
    required this.onSkip,
    this.onBack,
    this.progress,
  });

  /// Creates the list; false when it failed (the step shows a status row).
  final Future<bool> Function(String name) onCreate;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  ConsumerState<FirstListStep> createState() => _FirstListStepState();
}

class _FirstListStepState extends ConsumerState<FirstListStep> {
  late final _name = TextEditingController(
    text: ref.read(onboardingControllerProvider).listName,
  );
  final _focus = FocusNode();
  bool _working = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(String name) {
    _name.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    ref.read(onboardingControllerProvider.notifier).setListName(name);
    setState(() {});
  }

  Future<void> _create() async {
    if (_working) return;
    final typed = _name.text.trim();
    final name = typed.isEmpty ? context.tr('onb_list_default_name') : typed;
    setState(() {
      _working = true;
      _failed = false;
    });
    final ok = await widget.onCreate(name);
    if (!mounted) return;
    if (!ok) AvoHaptics.error();
    setState(() {
      _working = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final offers = ref.watch(
      onboardingControllerProvider.select(
        (s) => s.isOn(AppModule.offers, planned: true),
      ),
    );
    final placeholder = context.tr('onb_list_placeholder');
    final shownName = _name.text.trim().isEmpty
        ? context.tr('onb_list_default_name')
        : _name.text.trim();
    final suggestions = [
      context.tr('onb_list_default_name'),
      'Lidl',
      context.tr('onb_list_drugstore'),
    ];

    return OnboardingStepPage(
      title: context.tr('onb_list_title'),
      message: context.tr(
        offers ? 'onb_list_sentence_offers' : 'onb_list_sentence',
      ),
      progress: widget.progress,
      onBack: widget.onBack,
      onSkip: () => runIfCurrent(context, widget.onSkip),
      status: _failed
          ? StatusRow(
              kind: StatusKind.failed,
              text: context.tr('onb_list_failed'),
              actionLabel: context.tr('retry'),
              onAction: _create,
            )
          : const OnboardingSyncStatus(),
      primaryAction: AppButton.primary(
        label: context.tr('onb_list_create'),
        onPressed: () => runIfCurrent(context, _create),
        working: _working,
        size: AppButtonSize.large,
        expand: true,
      ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(_kFieldRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.m,
            ),
            child: CupertinoTextField(
              controller: _name,
              focusNode: _focus,
              autofocus: true,
              placeholder: placeholder,
              placeholderStyle: context.text(
                AvoTextStyle.body,
                color: colors.placeholder,
              ),
              style: context.text(AvoTextStyle.body),
              cursorColor: colors.tint,
              decoration: null,
              padding: EdgeInsets.zero,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (v) {
                ref.read(onboardingControllerProvider.notifier).setListName(v);
                setState(() {});
              },
              onSubmitted: (_) => _create(),
            ),
          ),
        ),
        const SizedBox(height: AvoSpacing.xl),
        InsetSection(
          separatorIndent: ListRow.separatorIndent,
          children: [
            ListRow(
              title: shownName,
              color: kListPalette.first.resolve(context),
              glyph: AvoIcon(AvoIcons.cart, color: colors.onTint),
              showChevron: false,
            ),
          ],
        ),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          header: context.tr('onb_list_suggestions'),
          children: [
            for (final s in suggestions)
              ChoiceRow(
                title: s,
                selected: _name.text.trim() == s,
                onTap: () => _set(s),
              ),
          ],
        ),
      ],
    );
  }
}
