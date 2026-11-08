import Foundation

// Flutter-free building blocks of Shoply's native channels. Only
// `ShoplyNativeChannels.swift` imports Flutter; every channel speaks in these
// types so it can be type-checked and reasoned about without the engine.

/// Error codes the Dart side maps in `native_channel_errors.dart`.
enum NativeErrorCode: String {
  case unavailable
  case permissionDenied = "permission_denied"
  case invalidArgs = "invalid_args"
  case busy
  case cancelled
  case failed
}

/// The answer to one method call.
enum NativeReply {
  case value(Any?)
  case error(NativeErrorCode, String?)
  case notImplemented
}

typealias NativeResult = (NativeReply) -> Void
typealias NativeEventSink = (Any?) -> Void

/// A channel's method handler. Called on the main thread; `result` may be
/// called from any thread exactly once.
protocol NativeMethodHandler: AnyObject {
  @MainActor func handle(method: String, arguments: Any?, result: @escaping NativeResult)
}

/// The native end of an event channel. Called on the main thread.
protocol NativeEventSource: AnyObject {
  @MainActor func onListen(arguments: Any?, sink: @escaping NativeEventSink)
  @MainActor func onCancel()
}

/// Event channel end that just remembers the current listener. `send` may be
/// called from any thread; it does nothing while nobody listens.
final class NativeEventStream: NativeEventSource {
  private var sink: NativeEventSink?
  private let onFirstListen: ((NativeEventSink) -> Void)?
  private let onLastCancel: (() -> Void)?

  init(
    onListen: ((NativeEventSink) -> Void)? = nil,
    onCancel: (() -> Void)? = nil
  ) {
    onFirstListen = onListen
    onLastCancel = onCancel
  }

  var hasListener: Bool { sink != nil }

  func onListen(arguments: Any?, sink: @escaping NativeEventSink) {
    self.sink = sink
    onFirstListen?(sink)
  }

  func onCancel() {
    sink = nil
    onLastCancel?()
  }

  func send(_ event: Any?) {
    if Thread.isMainThread {
      sink?(event)
    } else {
      DispatchQueue.main.async { [weak self] in self?.sink?(event) }
    }
  }
}

/// Typed access to the argument map of a method call.
struct NativeArguments {
  private let map: [String: Any]

  init(_ raw: Any?) {
    map = raw as? [String: Any] ?? [:]
  }

  func string(_ key: String) -> String? {
    guard let value = map[key] as? String, !value.isEmpty else { return nil }
    return value
  }

  func double(_ key: String) -> Double? {
    guard let number = map[key] as? NSNumber else { return nil }
    let value = number.doubleValue
    return value.isFinite ? value : nil
  }

  func int(_ key: String) -> Int? {
    (map[key] as? NSNumber)?.intValue
  }

  func bool(_ key: String) -> Bool? {
    (map[key] as? NSNumber)?.boolValue
  }

  /// Milliseconds since epoch, as Dart's `millisecondsSinceEpoch`.
  func date(_ key: String) -> Date? {
    guard let ms = double(key) else { return nil }
    return Date(timeIntervalSince1970: ms / 1000)
  }
}

extension Date {
  /// Milliseconds since epoch for Dart's `DateTime.fromMillisecondsSinceEpoch`.
  var millisecondsSinceEpoch: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }
}

/// Debug-only log with the project's emoji prefixes. Never pass transcripts,
/// health values or other personal data.
func nativeLog(_ message: @autoclosure () -> String) {
  #if DEBUG
    NSLog("%@", message())
  #endif
}
