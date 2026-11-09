import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/name_save.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_field.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';

/// Name (Konzept 17 §3.8): writes `users.display_name` (targeted update)
/// and calls [onDone] at once; saving runs in the background
/// ([nameSaveProvider], [NameSaveStatus] in the next step). [onSkip] keeps
/// the name empty. No back button (§1.1).
///
/// The field starts with the first name from Apple or Google, never with
/// the part of the email before the @. The constructor is the contract with
/// the flow; [initialName] is an optional addition.
class NameStep extends ConsumerStatefulWidget {
  const NameStep({
    super.key,
    required this.onDone,
    this.onSkip,
    this.progress,
    this.initialName,
  });

  final VoidCallback onDone;
  final VoidCallback? onSkip;
  final Widget? progress;

  /// Overrides the first name from the provider metadata.
  final String? initialName;

  @override
  ConsumerState<NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<NameStep> {
  late final TextEditingController _controller = TextEditingController(
    text:
        widget.initialName ??
        ref.read(authGatewayProvider).suggestedFirstName ??
        '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _controller.text.trim();
    // Empty means the default ("Mitglied" for others); nothing is written.
    if (name.isNotEmpty) {
      unawaited(ref.read(nameSaveProvider.notifier).save(name));
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepPage(
      title: context.tr('auth_name_title'),
      message: context.tr('auth_name_message'),
      progress: widget.progress,
      onSkip: widget.onSkip,
      primaryAction: AppButton.primary(
        label: context.tr('continue_text'),
        onPressed: _continue,
        size: AppButtonSize.large,
        expand: true,
      ),
      children: [
        Center(
          child: ExcludeSemantics(
            child: Avatar(name: _controller.text, size: AvatarSize.xl),
          ),
        ),
        const SizedBox(height: AvoSpacing.l),
        AuthTextField(
          controller: _controller,
          label: context.tr('auth_name_placeholder'),
          placeholder: context.tr('auth_name_placeholder'),
          autofillHints: const [AutofillHints.givenName],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _continue(),
        ),
      ],
    );
  }
}

/// "L" for one word, "LB" for two or more (first and last word); the
/// person symbol while empty.
String nameInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final first = words.first.characters.first.toUpperCase();
  if (words.length == 1) return first;
  return first + words.last.characters.first.toUpperCase();
}
