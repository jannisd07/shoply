import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';

/// Placeholder for UI component type (incomplete feature from previous session)
class AvoUIComponent {
  final String type;
  final Map<String, dynamic>? data;
  const AvoUIComponent({required this.type, this.data});
}

/// Chat message model with rich content support
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final AvoExpressionType? avoExpression;
  final List<AvoAction>? actions;
  final List<AvoUIComponent>? uiComponents;
  final List<Recipe>? recipes;
  final List<ShoppingItemModel>? items;
  final List<ShoppingListModel>? lists;
  final List<String>? suggestedItems;
  final List<ButtonData>? buttons;
  final DateTime timestamp;
  final bool isLoading;
  final ChatMessageType type;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    this.avoExpression,
    this.actions,
    this.uiComponents,
    this.recipes,
    this.items,
    this.lists,
    this.suggestedItems,
    this.buttons,
    DateTime? timestamp,
    this.isLoading = false,
    this.type = ChatMessageType.text,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    AvoExpressionType? avoExpression,
    List<AvoAction>? actions,
    List<AvoUIComponent>? uiComponents,
    List<Recipe>? recipes,
    List<ShoppingItemModel>? items,
    List<ShoppingListModel>? lists,
    List<String>? suggestedItems,
    List<ButtonData>? buttons,
    bool? isLoading,
    ChatMessageType? type,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      avoExpression: avoExpression ?? this.avoExpression,
      actions: actions ?? this.actions,
      uiComponents: uiComponents ?? this.uiComponents,
      recipes: recipes ?? this.recipes,
      items: items ?? this.items,
      lists: lists ?? this.lists,
      suggestedItems: suggestedItems ?? this.suggestedItems,
      buttons: buttons ?? this.buttons,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
      type: type ?? this.type,
    );
  }
}

/// Button data for interactive buttons
class ButtonData {
  final String label;
  final String action;
  final List<String> params;

  ButtonData({
    required this.label,
    required this.action,
    this.params = const [],
  });
}

enum ChatMessageType {
  text,
  recipeGrid,
  recipeList,
  itemList,
  shoppingList,
  listSelector,
  historyItems,
  actionButtons,
  addItemButtons,
  actionConfirmation,
}

/// Singleton service to manage chat state across the app session
/// Messages persist until app is closed
class AvoChatStateService extends ChangeNotifier {
  static final AvoChatStateService _instance = AvoChatStateService._internal();
  static AvoChatStateService get instance => _instance;
  factory AvoChatStateService() => _instance;
  AvoChatStateService._internal();

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isInitialized = false;
  
  // Pagination
  static const int _messagesPerPage = 20;
  int _displayedMessageCount = _messagesPerPage;

  List<ChatMessage> get messages => _messages;
  List<ChatMessage> get displayedMessages {
    final startIndex = (_messages.length - _displayedMessageCount).clamp(0, _messages.length);
    return _messages.sublist(startIndex);
  }
  
  bool get isTyping => _isTyping;
  bool get isInitialized => _isInitialized;
  bool get hasMoreMessages => _displayedMessageCount < _messages.length;
  int get totalMessageCount => _messages.length;

  /// Initialize with welcome message if not already done
  void initialize({String? welcomeMessage}) {
    if (_isInitialized && _messages.isNotEmpty) return;
    
    _messages.clear();
    _messages.add(ChatMessage(
      text: welcomeMessage ?? "Hey there! 🥑 I'm Avo, your shopping buddy! I can help you with:\n\n"
            "• Adding items to your lists\n"
            "• Finding delicious recipes\n"
            "• Checking your shopping history\n"
            "• Answering cooking questions\n\n"
            "Just chat with me - what would you like to do?",
      isUser: false,
      avoExpression: AvoExpressionType.waving,
    ));
    _isInitialized = true;
    _displayedMessageCount = _messagesPerPage;
    notifyListeners();
  }

  /// Add a user message
  void addUserMessage(String text) {
    _messages.add(ChatMessage(
      text: text,
      isUser: true,
    ));
    _isTyping = true;
    // Ensure we show the latest messages
    _displayedMessageCount = _messagesPerPage.clamp(0, _messages.length + 1);
    notifyListeners();
  }

  /// Add Avo's response
  void addAvoMessage({
    required String text,
    AvoExpressionType? expression,
    List<AvoAction>? actions,
    List<AvoUIComponent>? uiComponents,
    List<Recipe>? recipes,
    List<ShoppingItemModel>? items,
    List<ShoppingListModel>? lists,
    List<String>? suggestedItems,
    List<ButtonData>? buttons,
    ChatMessageType type = ChatMessageType.text,
  }) {
    _messages.add(ChatMessage(
      text: text,
      isUser: false,
      avoExpression: expression ?? AvoExpressionType.happy,
      actions: actions,
      uiComponents: uiComponents,
      recipes: recipes,
      items: items,
      lists: lists,
      suggestedItems: suggestedItems,
      buttons: buttons,
      type: type,
    ));
    _isTyping = false;
    _displayedMessageCount = _messagesPerPage.clamp(0, _messages.length);
    notifyListeners();
  }

  /// Set typing state
  void setTyping(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }

  /// Load more messages (for scroll pagination)
  void loadMoreMessages() {
    if (_displayedMessageCount < _messages.length) {
      _displayedMessageCount = (_displayedMessageCount + _messagesPerPage)
          .clamp(0, _messages.length);
      notifyListeners();
    }
  }

  /// Reset chat (clear all messages and start fresh)
  void resetChat() {
    _messages.clear();
    _isTyping = false;
    _displayedMessageCount = _messagesPerPage;
    _messages.add(ChatMessage(
      text: "Fresh start! 🥑 What would you like help with?",
      isUser: false,
      avoExpression: AvoExpressionType.waving,
    ));
    notifyListeners();
  }

  /// Clear all state (called when app closes)
  void dispose() {
    _messages.clear();
    _isTyping = false;
    _isInitialized = false;
    _displayedMessageCount = _messagesPerPage;
  }
}
