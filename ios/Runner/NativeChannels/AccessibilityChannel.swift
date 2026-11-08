import UIKit

/// `shoply/accessibility` + `shoply/accessibility/events`: settings Flutter
/// does not expose. Today "Reduce Transparency", which Flutter-drawn glass
/// fallbacks need (native `UIGlassEffect` views adapt on their own).
///
/// Events: `{"reduceTransparency": Bool}`, sent once on listen and on every
/// change.
final class AccessibilityChannel: NativeMethodHandler {
  private var observer: NSObjectProtocol?

  private(set) lazy var events = NativeEventStream(
    onListen: { [weak self] sink in self?.startObserving(sink) },
    onCancel: { [weak self] in self?.stopObserving() }
  )

  deinit { stopObserving() }

  func handle(method: String, arguments: Any?, result: @escaping NativeResult) {
    switch method {
    case "isReduceTransparencyEnabled":
      result(.value(UIAccessibility.isReduceTransparencyEnabled))
    default:
      result(.notImplemented)
    }
  }

  private static var state: [String: Any] {
    ["reduceTransparency": UIAccessibility.isReduceTransparencyEnabled]
  }

  private func startObserving(_ sink: NativeEventSink) {
    stopObserving()
    sink(Self.state)
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.events.send(Self.state)
    }
  }

  private func stopObserving() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
  }
}
