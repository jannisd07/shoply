import 'package:shoply/data/services/avo_assistant_service.dart';

/// One entry in the Avo chat transcript (kept in memory only).
class ChatMessage {
  final String text;
  final bool isUser;
  final AvoExpressionType? avoExpression;
  final List<AvoWidgetPayload> payloads;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.avoExpression,
    this.payloads = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
