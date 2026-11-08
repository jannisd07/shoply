import Flutter
import Foundation

/// Registers Shoply's own native channels. The only file in this folder that
/// imports Flutter: it turns `NativeReply` into Flutter results and events.
///
/// `AppDelegate.application(_:didFinishLaunchingWithOptions:)` calls
/// `ShoplyNativeChannels.register(registry: self)` right after
/// `GeneratedPluginRegistrant.register(with: self)`. Registration only wires
/// channels: no permission dialog, no audio session, no HealthKit store.
///
/// Channels: `shoply/health`, `shoply/scanner`, `shoply/camera`, `shoply/voice` with
/// `shoply/voice/events` and `shoply/voice/levels`, `shoply/accessibility`
/// with `shoply/accessibility/events`, `shoply/app`.
enum ShoplyNativeChannels {
  /// Channels, handlers and stream bridges live as long as the app.
  private static var retained: [AnyObject] = []

  @MainActor
  static func register(registry: FlutterPluginRegistry) {
    guard retained.isEmpty else { return }
    guard let registrar = registry.registrar(forPlugin: "ShoplyNativeChannels") else {
      nativeLog("❌ [NativeChannels] Could not obtain plugin registrar")
      return
    }
    let messenger = registrar.messenger()
    let health = HealthKitChannel()
    let scanner = BarcodeScannerChannel()
    let camera = MealCameraChannel()
    let voice = VoiceChannel()
    let accessibility = AccessibilityChannel()
    let app = AppBadgeChannel()
    retained = [health, scanner, camera, voice, accessibility, app]

    bind("shoply/health", health, messenger)
    bind("shoply/scanner", scanner, messenger)
    bind("shoply/camera", camera, messenger)
    bind("shoply/voice", voice, messenger)
    stream("shoply/voice/events", voice.events, messenger)
    stream("shoply/voice/levels", voice.levels, messenger)
    bind("shoply/accessibility", accessibility, messenger)
    stream("shoply/accessibility/events", accessibility.events, messenger)
    bind("shoply/app", app, messenger)
    nativeLog("✅ [NativeChannels] health, scanner, camera, voice, accessibility and app registered")
  }

  @MainActor
  private static func bind(
    _ name: String, _ handler: NativeMethodHandler, _ messenger: FlutterBinaryMessenger
  ) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let reply = deliver(result)
      // Flutter calls method handlers on the platform (main) thread.
      MainActor.assumeIsolated {
        handler.handle(method: call.method, arguments: call.arguments, result: reply)
      }
    }
    retained.append(channel)
  }

  @MainActor
  private static func stream(
    _ name: String, _ source: NativeEventSource, _ messenger: FlutterBinaryMessenger
  ) {
    let channel = FlutterEventChannel(name: name, binaryMessenger: messenger)
    let bridge = StreamBridge(source)
    channel.setStreamHandler(bridge)
    retained.append(channel)
    retained.append(bridge)
  }

  /// Answers exactly once, on the main thread.
  private static func deliver(_ result: @escaping FlutterResult) -> NativeResult {
    let lock = NSLock()
    var answered = false
    return { reply in
      lock.lock()
      let first = !answered
      answered = true
      lock.unlock()
      guard first else { return }
      let send = {
        switch reply {
        case .value(let value):
          result(value)
        case .error(let code, let message):
          result(FlutterError(code: code.rawValue, message: message, details: nil))
        case .notImplemented:
          result(FlutterMethodNotImplemented)
        }
      }
      Thread.isMainThread ? send() : DispatchQueue.main.async(execute: send)
    }
  }

  private final class StreamBridge: NSObject, FlutterStreamHandler {
    private let source: NativeEventSource

    init(_ source: NativeEventSource) {
      self.source = source
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
      -> FlutterError?
    {
      MainActor.assumeIsolated {
        source.onListen(arguments: arguments) { event in events(event) }
      }
      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      MainActor.assumeIsolated { source.onCancel() }
      return nil
    }
  }
}
