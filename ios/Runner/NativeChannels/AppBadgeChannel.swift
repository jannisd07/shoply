import UIKit
import UserNotifications

/// `shoply/app`: app-level calls that never show a permission dialog.
///
/// `clearBadge` sets the app icon badge to 0. It never calls
/// `requestAuthorization` (the old `flutter_app_badger` asked for alert,
/// badge and sound on every call): without permission there is no badge to
/// clear, and asking is `NotificationPermissionService`'s job alone.
final class AppBadgeChannel: NativeMethodHandler {
  func handle(method: String, arguments: Any?, result: @escaping NativeResult) {
    switch method {
    case "clearBadge":
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
          if let error {
            nativeLog("⚠️ [AppBadge] Clearing the badge failed: \(error.localizedDescription)")
          }
        }
      } else {
        UIApplication.shared.applicationIconBadgeNumber = 0
      }
      result(.value(nil))
    default:
      result(.notImplemented)
    }
  }
}
