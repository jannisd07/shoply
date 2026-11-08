import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_done_note.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_message_text.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_payload_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_line.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_suggestion_views.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_user_bubble.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/routes/route_paths.dart';

// D2 X-Avo spacing inside one round (Kap. 3.1).
const double _bubbleToBlock = 14; // D2
const double _cardToText = 10; // D2
const double _toChips = 14; // D2

/// One round of the Avo tab: the question, then (in this order, Kap. 3.1,
/// K2) the status line while Avo works, the result card, Avo's text, a
/// choice card under its question, the follow-up chips under the newest
/// answer.
class AvoTurnView extends ConsumerWidget {
  const AvoTurnView({
    super.key,
    required this.chat,
    required this.turn,
    required this.offline,
    required this.aiEnabled,
    required this.onSend,
    required this.onEdit,
    this.followUps = const [],
  });

  final AvoChat chat;
  final AvoTurn turn;
  final bool offline;
  final bool aiEnabled;

  /// Sends a follow-up chip.
  final ValueChanged<String> onSend;

  /// "Bearbeiten und neu senden": puts the question into the composer.
  final ValueChanged<String> onEdit;

  /// Chips under this answer (only the newest one has some).
  final List<AvoSuggestion> followUps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFree = !ref.watch(isSubscribedProvider);
    final limit = ref.watch(avoProQuestionLimitProvider);
    // The weekly Pro slot is only spent when the row can really show.
    final proHintAllowed = isFree && limit != null;
    final scope = AvoCardScope(
      chat: chat,
      turn: turn,
      offline: offline,
      proHintAllowed: proHintAllowed,
    );

    String? note;
    String? noteAction;
    VoidCallback? onNoteAction;
    switch (turn.phase) {
      case AvoTurnPhase.queued:
        note = context.tr('avo_queued');
      case AvoTurnPhase.notSent:
        note = context.tr('avo_not_sent');
        noteAction = context.tr('avo_resend');
        onNoteAction = aiEnabled
            ? () => chat.retry(
                turn,
                offline: offline,
                proHintAllowed: proHintAllowed,
              )
            : null;
      default:
        break;
    }

    final children = <Widget>[
      AvoUserBubble(
        text: turn.question,
        note: note,
        noteActionLabel: noteAction,
        onNoteAction: onNoteAction,
        onEdit: () => onEdit(turn.question),
      ),
    ];
    void add(Widget w, double gap) {
      children
        ..add(SizedBox(height: gap))
        ..add(w);
    }

    var gap = _bubbleToBlock;
    if (turn.showsStatus) {
      add(AvoStatusLine(step: turn.step, onStop: chat.stop), gap);
      gap = _cardToText;
    }

    final sections = avoSectionsFor(context, scope);
    if (turn.phase == AvoTurnPhase.failed && turn.errorCode != null) {
      sections.add(
        AvoErrorSection(
          code: turn.errorCode!,
          retryAt: turn.retryAt,
          partlyDone: turn.payloads.any((p) => p.isDoneChange),
          // Asked again as a new round: the retry is that round now.
          onRetry: turn.retried
              ? null
              : () => chat.retry(
                  turn,
                  offline: offline,
                  proHintAllowed: proHintAllowed,
                  // All done changes of this question, earlier rounds too.
                  doneNote: avoDoneNote(context, chat, turn.doneChanges),
                ),
          onSignIn: () => context.push(RoutePaths.login),
        ),
      );
      if (turn.errorCode == 'quota_exceeded' &&
          turn.proHint &&
          isFree &&
          limit != null) {
        sections.add(
          AvoProRow(
            title: context.tr('avo_pro_more_questions_title'),
            subtitle: context.tr(
              'avo_pro_more_questions_sub',
              params: {'pro': AppBrand.proName, 'limit': '$limit'},
            ),
            feature: avoQuestionsProFeature,
          ),
        );
      }
    }
    if (sections.isNotEmpty) {
      add(AvoResultCard(sections: sections), gap);
      gap = _cardToText;
    }

    if (turn.refused) {
      add(_PlainAvoText(text: context.tr('avo_err_refused')), gap);
      gap = _cardToText;
    } else {
      // Rebuilds only the text while it streams.
      final textGap = gap;
      children.add(
        ValueListenableBuilder<String>(
          valueListenable: turn.text,
          builder: (context, value, child) => value.trim().isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(top: textGap),
                  child: child,
                ),
          child: AvoMessageText(text: turn.text),
        ),
      );
    }

    final choices = avoChoiceCards(context, scope);
    for (final c in choices) {
      add(c, _cardToText);
    }

    // Once the first card or word replaced the status line, "Stopp" stays
    // reachable here until Teil A's composer has its "Antwort anhalten"
    // state (Kap. 2.11).
    if (turn.phase == AvoTurnPhase.working && !turn.showsStatus) {
      add(
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppButton.plain(
            label: context.tr('avo_stop'),
            onPressed: chat.stop,
          ),
        ),
        AvoSpacing.xs,
      );
    }

    if (turn.phase == AvoTurnPhase.stopped) {
      add(
        Text(
          context.tr('avo_stopped'),
          style: context.text(
            AvoTextStyle.footnote,
            color: context.colors.secondaryLabel,
          ),
        ),
        AvoSpacing.xs,
      );
    }

    if (followUps.isNotEmpty) {
      add(
        AvoFollowUpChips(
          suggestions: followUps,
          onSend: onSend,
          enabled: !offline && aiEnabled,
        ),
        _toChips,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// A fixed sentence in Avo's voice (refusal), with "Avo:" for VoiceOver.
class _PlainAvoText extends StatelessWidget {
  const _PlainAvoText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${context.tr('avo_a11y_prefix')} $text',
    excludeSemantics: true,
    child: Text(text, style: context.text(AvoTextStyle.body)),
  );
}
