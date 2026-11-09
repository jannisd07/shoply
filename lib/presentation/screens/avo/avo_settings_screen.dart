import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/providers/avo_consents_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/routes/route_paths.dart';

/// Row ids of the page (`/settings/avo?row=…`, the settings search).
abstract final class AvoSettingsRows {
  static const consentDiet = 'avo.consent_diet';
  static const consentHealth = 'avo.consent_health';
  static const kept = 'avo.kept';
  static const deleteConversation = 'avo.delete_conversation';
}

/// "Avo" (`/settings/avo`, Kap. 16 §10, only with the module): what Avo may
/// use and the conversation.
///
/// "Was Avo einbeziehen darf" holds the two consents ("Kalorien, Gewicht
/// und Ziele" only with the Kalorien module); taking one back ends the
/// conversation at the next question. "Gespräch" says where it is kept and
/// deletes it after a centred question (§11.2). The disclosure links to the
/// privacy text. The voice section (Stimme, Vorlesen, weiter zuhören) joins
/// with the voice mode. Every switch acts at once; no figure, never Pro.
class AvoSettingsScreen extends ConsumerWidget {
  const AvoSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`).
  final String? highlightRowId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('avo_delete_conv_title'),
      message: context.tr('avo_delete_conv_body'),
      confirmLabel: context.tr('avo_delete_conv_confirm'),
      cancelLabel: context.tr('avo_delete_conv_cancel'),
    );
    if (!confirmed || !context.mounted) return;
    ref.read(avoChatProvider).deleteConversation();
    final view = View.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        context.tr('avo_conversation_deleted_a11y'),
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consents = ref.watch(avoConsentsProvider);
    final notifier = ref.read(avoConsentsProvider.notifier);
    final calories = ref.watch(moduleEnabledProvider(AppModule.calories));
    final chat = ref.watch(avoChatProvider);
    final kept = chat.hasConversation;

    return SettingsPage(
      title: context.tr('avo_set_title'),
      highlightRowId: highlightRowId,
      children: [
        InsetSection(
          header: context.tr('avo_set_section_consent'),
          footer: context.tr('avo_set_consent_note'),
          children: [
            HighlightableRow(
              id: AvoSettingsRows.consentDiet,
              child: ToggleRow(
                title: context.tr('avo_set_consent_diet'),
                value: consents.health,
                enabled: consents.loaded,
                onChanged: (on) => unawaited(notifier.set(health: on)),
              ),
            ),
            if (calories)
              HighlightableRow(
                id: AvoSettingsRows.consentHealth,
                child: ToggleRow(
                  title: context.tr('avo_set_consent_health'),
                  value: consents.body,
                  enabled: consents.loaded,
                  onChanged: (on) => unawaited(notifier.set(body: on)),
                ),
              ),
          ],
        ),
        InsetSection(
          header: context.tr('avo_set_section_conversation'),
          children: [
            HighlightableRow(
              id: AvoSettingsRows.kept,
              child: ValueRow(
                title: context.tr('avo_set_kept'),
                value: context.tr('avo_set_kept_value'),
              ),
            ),
            HighlightableRow(
              id: AvoSettingsRows.deleteConversation,
              child: kept
                  ? DestructiveRow(
                      title: context.tr('avo_set_delete_conversation'),
                      onTap: () => unawaited(_delete(context, ref)),
                    )
                  // Disabled "Gespräch löschen" (§10.1): VoiceOver says it is
                  // dimmed. TODO(B): A's disabled DestructiveRow once it
                  // exists (status-B, request 16), for the dimmed title.
                  : Semantics(
                      container: true,
                      button: true,
                      enabled: false,
                      label: context.tr('avo_set_delete_conversation'),
                      value: context.tr('avo_set_no_conversation'),
                      child: ExcludeSemantics(
                        child: ValueRow(
                          title: context.tr('avo_set_delete_conversation'),
                          value: context.tr('avo_set_no_conversation'),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: AvoSpacing.xl),
        _Disclosure(
          onPrivacy: () => unawaited(
            context.push(RoutePaths.settingsLegalDocument('privacy')),
          ),
        ),
      ],
    );
  }
}

/// "Avo nutzt Claude von Anthropic. · Datenschutz" under the groups
/// (footnote and a text button, §10.1 "Fuß").
class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.onPrivacy});

  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AvoSpacing.xs,
        children: [
          Text(
            context.tr('avo_disclosure_short', params: {'app': AppBrand.name}),
            style: context.text(
              AvoTextStyle.footnote,
              color: context.colors.secondaryLabel,
            ),
          ),
          AppButton.plain(
            label: context.tr('avo_set_privacy'),
            onPressed: onPrivacy,
          ),
        ],
      ),
    );
  }
}
