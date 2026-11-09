import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/services/fcm_service.dart';
import 'package:shoply/data/services/notification_preferences_service.dart';

void main() {
  test('push types land on their settings toggle', () {
    expect(
      notificationCategoryForPushType('shopping_started'),
      NotificationCategory.shoppingStarted,
    );
    expect(
      notificationCategoryForPushType('expense_split'),
      NotificationCategory.costSplitOpen,
    );
    expect(
      notificationCategoryForPushType('split_reminder'),
      NotificationCategory.costSplitOpen,
    );
    expect(
      notificationCategoryForPushType('list_update'),
      NotificationCategory.listActivity,
    );
    expect(notificationCategoryForPushType('something_new'), isNull);
    expect(notificationCategoryForPushType(null), isNull);
  });
}
