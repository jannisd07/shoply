import 'package:shoply/presentation/screens/avo/avo_chat.dart';

/// What every card of one round needs: the conversation (which runs every
/// action with the tab root's ref), the round, and the tab's state.
class AvoCardScope {
  const AvoCardScope({
    required this.chat,
    required this.turn,
    this.offline = false,
    this.proHintAllowed = false,
  });

  final AvoChat chat;
  final AvoTurn turn;
  final bool offline;

  /// Free with a known Pro limit: the Pro row may follow a daily limit.
  final bool proHintAllowed;
}
