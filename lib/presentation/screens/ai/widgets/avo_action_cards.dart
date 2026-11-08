import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';

/// "Milch löschen?" for a deletion Avo proposed (Kap. 16, 15.3). Only a tap
/// on "Löschen" deletes, with the card's one-time token; the name is the
/// app's own stored name, never Avo's wording.
class AvoConfirmDeleteCard extends ConsumerStatefulWidget {
  const AvoConfirmDeleteCard({super.key, required this.pending});

  final AvoPendingDelete pending;

  @override
  ConsumerState<AvoConfirmDeleteCard> createState() =>
      _AvoConfirmDeleteCardState();
}

enum _DeleteState { asking, working, deleted, failed, cancelled }

class _AvoConfirmDeleteCardState extends ConsumerState<AvoConfirmDeleteCard> {
  var _state = _DeleteState.asking;

  String get _bodyKey => switch (widget.pending.target) {
        AvoDeleteTarget.list => 'avo_confirm_delete_list_body',
        AvoDeleteTarget.foodLog => 'avo_confirm_delete_food_body',
        _ => 'avo_confirm_delete_item_body',
      };

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();
    setState(() => _state = _DeleteState.working);
    final ok = await AvoAssistantService.instance
        .confirmPendingDelete(widget.pending.token, ref);
    if (!mounted) return;
    setState(() => _state = ok ? _DeleteState.deleted : _DeleteState.failed);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.pending.name;
    final done = switch (_state) {
      _DeleteState.deleted => context.tr('avo_confirm_delete_done', params: {'name': name}),
      _DeleteState.failed => context.tr('avo_confirm_delete_failed'),
      _DeleteState.cancelled => context.tr('avo_confirm_delete_cancelled'),
      _ => null,
    };
    return Semantics(
      container: true,
      child: AvoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.tr('avo_confirm_delete_title', params: {'name': name}),
                style: context.text(AvoTextStyle.headline),
              ),
            ),
            const SizedBox(height: AvoSpacing.xs),
            Text(
              done ?? context.tr(_bodyKey),
              style: context.text(AvoTextStyle.subhead).copyWith(
                    color: context.colors.secondaryLabel,
                  ),
            ),
            if (done == null) ...[
              const SizedBox(height: AvoSpacing.m),
              Wrap(
                spacing: AvoSpacing.s,
                runSpacing: AvoSpacing.s,
                children: [
                  AppButton.destructive(
                    label: context.tr('avo_confirm_delete_action'),
                    working: _state == _DeleteState.working,
                    onPressed: _state == _DeleteState.asking ? _delete : null,
                  ),
                  AppButton.plain(
                    label: context.tr('cancel'),
                    onPressed: _state == _DeleteState.asking
                        ? () => setState(() => _state = _DeleteState.cancelled)
                        : null,
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

/// Asks to share data with Avo before it can answer (Kap. 16): calories,
/// weight and goals, or diet and allergies. The choice can be changed in the
/// Avo settings.
class AvoConsentCard extends StatefulWidget {
  const AvoConsentCard({super.key, required this.kind});

  final AvoConsentKind kind;

  @override
  State<AvoConsentCard> createState() => _AvoConsentCardState();
}

class _AvoConsentCardState extends State<AvoConsentCard> {
  bool? _shared;

  String get _prefix => widget.kind == AvoConsentKind.body
      ? 'avo_consent_body'
      : 'avo_consent_health';

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    if (widget.kind == AvoConsentKind.body) {
      await AvoConsents.set(body: true);
    } else {
      await AvoConsents.set(health: true);
    }
    if (mounted) setState(() => _shared = true);
  }

  @override
  Widget build(BuildContext context) {
    final shared = _shared;
    return AvoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.tr('${_prefix}_title'),
              style: context.text(AvoTextStyle.headline),
            ),
          ),
          const SizedBox(height: AvoSpacing.xs),
          Text(
            context.tr(shared == null
                ? '${_prefix}_body'
                : shared
                    ? 'avo_consent_shared'
                    : 'avo_consent_not_now'),
            style: context.text(AvoTextStyle.subhead).copyWith(
                  color: context.colors.secondaryLabel,
                ),
          ),
          if (shared == null) ...[
            const SizedBox(height: AvoSpacing.m),
            Wrap(
              spacing: AvoSpacing.s,
              runSpacing: AvoSpacing.s,
              children: [
                AppButton.primary(
                  label: context.tr('avo_consent_share'),
                  onPressed: _share,
                ),
                AppButton.plain(
                  label: context.tr('avo_consent_not_now_action'),
                  onPressed: () => setState(() => _shared = false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
