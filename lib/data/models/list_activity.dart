/// Model for tracking activities/changes on a shopping list.
/// 
/// Activities include:
/// - Item added/removed/checked/unchecked
/// - Category added/removed/reordered
/// - List shared/member joined
/// - List renamed
/// - Shopping completed

enum ListActivityType {
  itemAdded,
  itemRemoved,
  itemChecked,
  itemUnchecked,
  categoryAdded,
  categoryRemoved,
  categoryReordered,
  listShared,
  memberJoined,
  memberLeft,
  listRenamed,
  shoppingCompleted,
  backgroundChanged,
}

class ListActivity {
  final String id;
  final String listId;
  final ListActivityType type;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ListActivity({
    required this.id,
    required this.listId,
    required this.type,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.metadata,
  });

  /// Get a human-readable description of the activity
  String getDescription({required String languageCode}) {
    final isGerman = languageCode == 'de';
    
    switch (type) {
      case ListActivityType.itemAdded:
        final itemName = metadata?['itemName'] ?? '';
        return isGerman 
            ? '$userName hat "$itemName" hinzugefügt'
            : '$userName added "$itemName"';
      
      case ListActivityType.itemRemoved:
        final itemName = metadata?['itemName'] ?? '';
        return isGerman 
            ? '$userName hat "$itemName" entfernt'
            : '$userName removed "$itemName"';
      
      case ListActivityType.itemChecked:
        final itemName = metadata?['itemName'] ?? '';
        return isGerman 
            ? '$userName hat "$itemName" abgehakt'
            : '$userName checked off "$itemName"';
      
      case ListActivityType.itemUnchecked:
        final itemName = metadata?['itemName'] ?? '';
        return isGerman 
            ? '$userName hat "$itemName" wieder aktiviert'
            : '$userName unchecked "$itemName"';
      
      case ListActivityType.categoryAdded:
        final categoryName = metadata?['categoryName'] ?? '';
        return isGerman 
            ? '$userName hat Kategorie "$categoryName" erstellt'
            : '$userName created category "$categoryName"';
      
      case ListActivityType.categoryRemoved:
        final categoryName = metadata?['categoryName'] ?? '';
        return isGerman 
            ? '$userName hat Kategorie "$categoryName" gelöscht'
            : '$userName deleted category "$categoryName"';
      
      case ListActivityType.categoryReordered:
        return isGerman 
            ? '$userName hat die Kategorien neu sortiert'
            : '$userName reordered categories';
      
      case ListActivityType.listShared:
        return isGerman 
            ? '$userName hat die Liste geteilt'
            : '$userName shared the list';
      
      case ListActivityType.memberJoined:
        final memberName = metadata?['memberName'] ?? userName;
        return isGerman 
            ? '$memberName ist der Liste beigetreten'
            : '$memberName joined the list';
      
      case ListActivityType.memberLeft:
        final memberName = metadata?['memberName'] ?? userName;
        return isGerman 
            ? '$memberName hat die Liste verlassen'
            : '$memberName left the list';
      
      case ListActivityType.listRenamed:
        final oldName = metadata?['oldName'] ?? '';
        final newName = metadata?['newName'] ?? '';
        return isGerman 
            ? '$userName hat die Liste von "$oldName" zu "$newName" umbenannt'
            : '$userName renamed the list from "$oldName" to "$newName"';
      
      case ListActivityType.shoppingCompleted:
        final itemCount = metadata?['itemCount'] ?? 0;
        return isGerman 
            ? '$userName hat den Einkauf abgeschlossen ($itemCount Artikel)'
            : '$userName completed shopping ($itemCount items)';
      
      case ListActivityType.backgroundChanged:
        return isGerman 
            ? '$userName hat den Hintergrund geändert'
            : '$userName changed the background';
    }
  }

  /// Get an icon for this activity type
  String getIcon() {
    switch (type) {
      case ListActivityType.itemAdded:
        return '➕';
      case ListActivityType.itemRemoved:
        return '🗑️';
      case ListActivityType.itemChecked:
        return '✅';
      case ListActivityType.itemUnchecked:
        return '⬜';
      case ListActivityType.categoryAdded:
        return '📁';
      case ListActivityType.categoryRemoved:
        return '🗂️';
      case ListActivityType.categoryReordered:
        return '🔀';
      case ListActivityType.listShared:
        return '🔗';
      case ListActivityType.memberJoined:
        return '👋';
      case ListActivityType.memberLeft:
        return '👤';
      case ListActivityType.listRenamed:
        return '✏️';
      case ListActivityType.shoppingCompleted:
        return '🛒';
      case ListActivityType.backgroundChanged:
        return '🎨';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'list_id': listId,
    'type': type.name,
    'user_id': userId,
    'user_name': userName,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory ListActivity.fromJson(Map<String, dynamic> json) => ListActivity(
    id: json['id'] as String,
    listId: json['list_id'] as String,
    type: ListActivityType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ListActivityType.itemAdded,
    ),
    userId: json['user_id'] as String,
    userName: json['user_name'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}
