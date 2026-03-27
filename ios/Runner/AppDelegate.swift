import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  private let widgetChannel = "com.shoply.widget"
  private let appGroupId = "group.com.shoply.app"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins first
    GeneratedPluginRegistrant.register(with: self)
    
    // Register native Liquid Glass platform view
    let glassFactory = LiquidGlassViewFactory(
      messenger: (window?.rootViewController as! FlutterViewController).binaryMessenger
    )
    registrar(forPlugin: "LiquidGlassView")!
      .register(glassFactory, withId: "shoply/liquid_glass")
    
    // Setup widget method channel
    setupWidgetChannel()
    
    // Set notification delegate
    UNUserNotificationCenter.current().delegate = self
    
    // Set Firebase Messaging delegate (required when swizzling is disabled)
    Messaging.messaging().delegate = self
    
    // Request notification permission
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      print("📱 [APNS] Permission granted: \(granted)")
      if let error = error {
        print("❌ [APNS] Permission error: \(error.localizedDescription)")
      }
    }
    
    // CRITICAL: Explicitly register for remote notifications
    // This triggers APNs to provide a device token
    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
      print("📱 [APNS] Registered for remote notifications")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Widget Channel Setup
  private func setupWidgetChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("❌ [Widget] Could not get FlutterViewController")
      return
    }
    
    let channel = FlutterMethodChannel(name: widgetChannel, binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate is nil", details: nil))
        return
      }
      
      switch call.method {
      case "updateShoppingListWidget":
        self.updateShoppingListWidget(call.arguments as? [String: Any], result: result)
      case "updateSavedRecipesWidget":
        self.updateSavedRecipesWidget(call.arguments as? [String: Any], result: result)
      case "clearWidget":
        self.clearWidgetData(result: result)
      case "refreshAllWidgets":
        self.refreshAllWidgets(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    print("✅ [Widget] Method channel setup complete")
  }
  
  private func updateShoppingListWidget(_ data: [String: Any]?, result: FlutterResult) {
    guard let data = data else {
      result(FlutterError(code: "INVALID_DATA", message: "No data provided", details: nil))
      return
    }
    
    // Save to App Group UserDefaults
    if let defaults = UserDefaults(suiteName: appGroupId) {
      if let jsonData = try? JSONSerialization.data(withJSONObject: data),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        defaults.set(jsonString, forKey: "widget_shopping_list")
        defaults.synchronize()
        print("✅ [Widget] Shopping list data saved to App Group")
      }
    }
    
    // Reload widget timelines
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "ShoppingListWidget")
      print("✅ [Widget] Shopping list widget timeline reloaded")
    }
    
    result(true)
  }
  
  private func updateSavedRecipesWidget(_ data: [String: Any]?, result: FlutterResult) {
    guard let data = data else {
      result(FlutterError(code: "INVALID_DATA", message: "No data provided", details: nil))
      return
    }
    
    // Save to App Group UserDefaults
    if let defaults = UserDefaults(suiteName: appGroupId) {
      if let jsonData = try? JSONSerialization.data(withJSONObject: data),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        defaults.set(jsonString, forKey: "widget_saved_recipes")
        defaults.synchronize()
        print("✅ [Widget] Saved recipes data saved to App Group")
      }
    }
    
    // Reload widget timelines
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "SavedRecipesWidget")
      print("✅ [Widget] Saved recipes widget timeline reloaded")
    }
    
    result(true)
  }
  
  private func clearWidgetData(result: FlutterResult) {
    if let defaults = UserDefaults(suiteName: appGroupId) {
      defaults.removeObject(forKey: "widget_shopping_list")
      defaults.removeObject(forKey: "widget_saved_recipes")
      defaults.synchronize()
      print("✅ [Widget] Widget data cleared")
    }
    
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
    
    result(true)
  }
  
  private func refreshAllWidgets(result: FlutterResult) {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
      print("✅ [Widget] All widget timelines reloaded")
    }
    result(true)
  }
  
  // MARK: - MessagingDelegate (required when swizzling is disabled)
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔥 [FCM] Token received via delegate: \(fcmToken ?? "nil")")
    // The Flutter plugin will handle this automatically
  }
  
  // Handle notification when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([[.banner, .sound, .badge]])
  }
  
  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
  
  // Register for remote notifications - MUST call super for Flutter plugin
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("📱 [APNS] Device token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    Messaging.messaging().apnsToken = deviceToken
    // CRITICAL: Call super to let Flutter plugin handle this
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle registration failure - MUST call super for Flutter plugin
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ [APNS] Failed to register: \(error.localizedDescription)")
    // CRITICAL: Call super to let Flutter plugin handle this
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
