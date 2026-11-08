import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_confirm_card.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// A deletion Avo proposed (Kap. 6), with the texts for its target.
class AvoConfirmSection extends ConsumerWidget {
  const AvoConfirmSection({
    super.key,
    required this.payload,
    required this.scope,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = payload.pendingDelete!;
    final lists = ref.watch(avoListsProvider);
    final name = pending.name;
    final String title;
    String? body;
    String? hint;
    String done;
    switch (pending.target) {
      case AvoDeleteTarget.list:
        final list = lists.where((l) => l.id == pending.targetId).firstOrNull;
        title = context.tr('avo_confirm_list_title', params: {'name': name});
        body = avoTrCount(
          context,
          list?.isShared ?? false
              ? 'avo_confirm_list_shared_body'
              : 'avo_confirm_list_body',
          list?.itemCount ?? 0,
        );
        hint = context.tr('avo_confirm_hint_list');
        done = context.tr('avo_deleted_list', params: {'name': name});
      case AvoDeleteTarget.item:
        final list = lists.where((l) => l.id == pending.parentId).firstOrNull;
        title = list == null
            ? context.tr('avo_confirm_list_title', params: {'name': name})
            : context.tr(
                'avo_confirm_item_title',
                params: {'name': name, 'list': list.name},
              );
        done = avoTrCount(context, 'avo_deleted_items', 1);
      case AvoDeleteTarget.foodLog:
        title = context.tr('avo_confirm_food_title', params: {'food': name});
        done = context.tr('avo_deleted_named', params: {'name': name});
      case AvoDeleteTarget.planEntry:
      case AvoDeleteTarget.historyTrip:
      case AvoDeleteTarget.listMember:
        title = context.tr('avo_confirm_list_title', params: {'name': name});
        done = context.tr('avo_deleted_named', params: {'name': name});
    }
    return AvoConfirmCard(
      title: title,
      body: body,
      confirmLabel: context.tr('avo_delete'),
      confirmHint: hint,
      doneText: done,
      phase: scope.chat.confirmPhaseOf(payload),
      offline: scope.offline,
      expiresAt: pending.expiresAt,
      onExpired: scope.chat.refreshConfirm,
      firstShow: scope.chat.firstShowOf(payload),
      onConfirm: () => scope.chat.confirmDelete(payload),
      onCancel: () => scope.chat.cancelDelete(payload),
    );
  }
}

/// Asks to share data with Avo before a tool may use it (Kap. 16): calories,
/// weight and goals, or diet and allergies.
class AvoConsentSection extends StatelessWidget {
  const AvoConsentSection({
    super.key,
    required this.payload,
    required this.scope,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefix = payload.consentKind == AvoConsentKind.body
        ? 'avo_consent_body'
        : 'avo_consent_health';
    final answer = scope.chat.consentOf(payload);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.all(AvoSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.tr('${prefix}_title'),
                style: context.text(AvoTextStyle.headline),
              ),
            ),
            const SizedBox(height: AvoSpacing.xs),
            Semantics(
              liveRegion: answer != null,
              child: Text(
                context.tr(
                  answer == null
                      ? '${prefix}_body'
                      : answer
                      ? 'avo_consent_shared'
                      : 'avo_consent_not_now',
                ),
                style: context.text(
                  AvoTextStyle.subhead,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
            if (answer == null) ...[
              const SizedBox(height: AvoSpacing.m),
              Wrap(
                spacing: AvoSpacing.s,
                runSpacing: AvoSpacing.s,
                children: [
                  AppButton.primary(
                    label: context.tr('avo_consent_share'),
                    onPressed: () =>
                        scope.chat.answerConsent(payload, share: true),
                  ),
                  AppButton.plain(
                    label: context.tr('avo_consent_not_now_action'),
                    onPressed: () =>
                        scope.chat.answerConsent(payload, share: false),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
