import AVFoundation
import Accelerate
import Speech
import UIKit

/// `shoply/voice` (+ `shoply/voice/events`, `shoply/voice/levels`): Avo's
/// voice mode without a package (concept 16, ch. 10).
///
/// - Recognition: Apple Speech, on the device whenever the language model is
///   installed (`requireOnDevice` refuses server recognition). Partial
///   transcripts stream as events; after `silenceMs` (about 1 s) without a
///   new word the sentence ends automatically, unless `autoEndOnSilence` is
///   false (VoiceOver: the person ends it with a double tap).
/// - Speech: `AVSpeechSynthesizer` in the app's audio session, other audio is
///   ducked. While VoiceOver reads an element, Avo's voice pauses and
///   continues shortly after.
/// - Levels: about 30 values per second. Microphone levels are measured
///   (RMS, -50…0 dB mapped to 0…1); the speech level is an envelope driven by
///   the synthesizer's word callbacks (the synthesizer exposes no audio).
///
/// Permissions are asked only in `requestPermissions`. Nothing starts at
/// registration: synthesizer, audio engine and observers are created on first
/// use. Transcripts are never logged.
///
/// Events: `partial {text}`, `final {text, reason: silence|stopped|noSpeech}`,
/// `speechStart`, `word {location, length}`, `speechEnd {status}`,
/// `ttsPaused {reason}`, `ttsResumed`, `interrupted {reason:
/// background|audioInterruption}`, `error {code, message}`.
final class VoiceChannel: NSObject, NativeMethodHandler, AVSpeechSynthesizerDelegate {
  let events = NativeEventStream()
  let levels = NativeEventStream()

  // Recognition
  private var engine: AVAudioEngine?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  /// Grows with every start, so late callbacks of an ended task are ignored.
  private var recognitionGeneration = 0
  private var transcript = ""
  private var endReason: String?
  private var silence: TimeInterval = 1
  private var autoEndOnSilence = true
  private var silenceTimer: Timer?
  private var noSpeechTimer: Timer?
  private var finalFallbackTimer: Timer?
  /// Touched only on the audio thread.
  private var lastMicLevelTime: CFTimeInterval = 0

  // Speech
  private var createdSynthesizer: AVSpeechSynthesizer?
  private var speakResults: [ObjectIdentifier: NativeResult] = [:]
  private var envelope = 0.0
  private var envelopeTimer: Timer?
  private var pausedForVoiceOver = false
  private var voiceOverResume: DispatchWorkItem?

  // Session
  private var observers: [NSObjectProtocol] = []
  private var previousSession: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?

  private static let levelInterval: CFTimeInterval = 1.0 / 30

  private var synthesizer: AVSpeechSynthesizer {
    if let createdSynthesizer { return createdSynthesizer }
    let synthesizer = AVSpeechSynthesizer()
    synthesizer.delegate = self
    createdSynthesizer = synthesizer
    return synthesizer
  }

  private var isListening: Bool { recognitionTask != nil }
  private var isSpeaking: Bool { createdSynthesizer?.isSpeaking ?? false }

  // MARK: Dispatch

  func handle(method: String, arguments: Any?, result: @escaping NativeResult) {
    let args = NativeArguments(arguments)
    switch method {
    case "permissions": result(.value(Self.permissions))
    case "requestPermissions": requestPermissions(result)
    case "recognitionSupport": result(.value(Self.recognitionSupport(args.string("locale"))))
    case "startListening": startListening(args, result)
    case "stopListening":
      endListening(reason: "stopped")
      result(.value(nil))
    case "cancelListening":
      teardownRecognition()
      result(.value(nil))
    case "speak": speak(args, result)
    case "stopSpeaking":
      createdSynthesizer?.stopSpeaking(at: .immediate)
      result(.value(nil))
    case "pauseSpeaking":
      if createdSynthesizer?.pauseSpeaking(at: .word) == true {
        events.send(["type": "ttsPaused", "reason": "app"])
      }
      result(.value(nil))
    case "resumeSpeaking":
      pausedForVoiceOver = false
      if createdSynthesizer?.continueSpeaking() == true { events.send(["type": "ttsResumed"]) }
      result(.value(nil))
    case "voices": result(.value(Self.voices(language: args.string("language"))))
    case "setKeepScreenOn":
      UIApplication.shared.isIdleTimerDisabled = args.bool("on") ?? false
      result(.value(nil))
    case "endSession":
      endSession()
      result(.value(nil))
    default:
      result(.notImplemented)
    }
  }

  // MARK: Permissions

  private static var microphoneStatus: String {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted: return "granted"
      case .denied: return "denied"
      default: return "notDetermined"
      }
    } else {
      switch AVAudioSession.sharedInstance().recordPermission {
      case .granted: return "granted"
      case .denied: return "denied"
      default: return "notDetermined"
      }
    }
  }

  private static var speechStatus: String {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    default: return "notDetermined"
    }
  }

  private static var permissions: [String: String] {
    ["microphone": microphoneStatus, "speech": speechStatus]
  }

  /// Microphone first; speech recognition only once the microphone is
  /// allowed (one permission alone is useless and counts as refused).
  private func requestPermissions(_ result: @escaping NativeResult) {
    let askSpeech = {
      guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else {
        return result(.value(Self.permissions))
      }
      SFSpeechRecognizer.requestAuthorization { _ in result(.value(Self.permissions)) }
    }
    let onMicrophone: (Bool) -> Void = { granted in
      granted ? askSpeech() : result(.value(Self.permissions))
    }
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission(completionHandler: onMicrophone)
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission(onMicrophone)
    }
  }

  private static func recognitionSupport(_ locale: String?) -> [String: Bool] {
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale ?? Locale.current.identifier))
    else { return ["available": false, "onDevice": false] }
    return ["available": recognizer.isAvailable, "onDevice": recognizer.supportsOnDeviceRecognition]
  }

  // MARK: Listening

  private func startListening(_ args: NativeArguments, _ result: @escaping NativeResult) {
    guard Self.microphoneStatus == "granted", SFSpeechRecognizer.authorizationStatus() == .authorized
    else { return result(.error(.permissionDenied, "Microphone or speech recognition is not allowed")) }
    guard !isListening else { return result(.error(.busy, "Already listening")) }
    let locale = Locale(identifier: args.string("locale") ?? Locale.current.identifier)
    guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
      return result(.error(.unavailable, "Speech recognition is not available for this language"))
    }
    if (args.bool("requireOnDevice") ?? true) && !recognizer.supportsOnDeviceRecognition {
      return result(.error(.unavailable, "On-device speech recognition is not available"))
    }
    silence = Double(max(args.int("silenceMs") ?? 1000, 300)) / 1000
    autoEndOnSilence = args.bool("autoEndOnSilence") ?? true
    let noSpeechTimeout = Double(max(args.int("noSpeechTimeoutMs") ?? 8000, 1000)) / 1000

    // Avo never listens to itself.
    createdSynthesizer?.stopSpeaking(at: .immediate)
    installObservers()

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    if #available(iOS 16.0, *) { request.addsPunctuation = true }

    let engine = self.engine ?? AVAudioEngine()
    self.engine = engine
    do {
      try activateSession()
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else {
        return result(.error(.unavailable, "No microphone input"))
      }
      input.removeTap(onBus: 0)
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
        request.append(buffer)
        self?.meter(buffer)
      }
      engine.prepare()
      try engine.start()
    } catch {
      stopAudioInput()
      return result(.error(.failed, "The microphone could not start"))
    }

    transcript = ""
    endReason = nil
    recognitionRequest = request
    recognitionGeneration += 1
    let generation = recognitionGeneration
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] update, error in
      DispatchQueue.main.async {
        guard let self, generation == self.recognitionGeneration else { return }
        self.recognitionUpdate(update, error)
      }
    }
    noSpeechTimer = Self.timer(after: noSpeechTimeout) { [weak self] in
      guard let self, self.transcript.isEmpty else { return }
      self.endListening(reason: "noSpeech")
    }
    result(.value(true))
  }

  private func recognitionUpdate(_ update: SFSpeechRecognitionResult?, _ error: Error?) {
    guard isListening else { return }
    if let update {
      let text = update.bestTranscription.formattedString
      if text != transcript {
        transcript = text
        noSpeechTimer?.invalidate()
        events.send(["type": "partial", "text": text])
        if autoEndOnSilence && endReason == nil {
          silenceTimer?.invalidate()
          silenceTimer = Self.timer(after: silence) { [weak self] in
            self?.endListening(reason: "silence")
          }
        }
      }
      if update.isFinal { return finishRecognition() }
    }
    guard error != nil else { return }
    if endReason != nil || !transcript.isEmpty {
      finishRecognition()
    } else if (error as NSError?)?.code == 1110 {
      // "No speech detected"
      endReason = "noSpeech"
      finishRecognition()
    } else {
      teardownRecognition()
      events.send(["type": "error", "code": NativeErrorCode.failed.rawValue, "message": "Speech recognition failed"])
    }
  }

  /// Stops the microphone and asks the recogniser for its final result.
  private func endListening(reason: String) {
    guard isListening, endReason == nil else { return }
    endReason = reason
    silenceTimer?.invalidate()
    noSpeechTimer?.invalidate()
    stopAudioInput()
    recognitionRequest?.endAudio()
    finalFallbackTimer = Self.timer(after: 1.5) { [weak self] in self?.finishRecognition() }
  }

  private func finishRecognition() {
    guard isListening else { return }
    let text = transcript
    let reason = endReason ?? "stopped"
    teardownRecognition()
    events.send(["type": "final", "text": text, "reason": text.isEmpty && reason != "stopped" ? "noSpeech" : reason])
  }

  private func teardownRecognition() {
    for timer in [silenceTimer, noSpeechTimer, finalFallbackTimer] { timer?.invalidate() }
    silenceTimer = nil
    noSpeechTimer = nil
    finalFallbackTimer = nil
    stopAudioInput()
    let task = recognitionTask
    recognitionTask = nil
    recognitionRequest = nil
    task?.cancel()
    endReason = nil
    transcript = ""
    levels.send(["source": "mic", "level": 0.0])
  }

  private func stopAudioInput() {
    guard let engine else { return }
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
  }

  /// Audio thread: about 30 microphone levels per second.
  private func meter(_ buffer: AVAudioPCMBuffer) {
    let now = CACurrentMediaTime()
    guard now - lastMicLevelTime >= Self.levelInterval else { return }
    lastMicLevelTime = now
    levels.send(["source": "mic", "level": Self.level(of: buffer)])
  }

  static func level(of buffer: AVAudioPCMBuffer) -> Double {
    guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
    var rms: Float = 0
    vDSP_rmsqv(channel, 1, &rms, vDSP_Length(buffer.frameLength))
    let decibels = 20 * log10(max(rms, 0.000_000_1))
    return Double(min(max((decibels + 50) / 50, 0), 1))
  }

  // MARK: Speaking

  private func speak(_ args: NativeArguments, _ result: @escaping NativeResult) {
    guard let text = args.string("text") else {
      return result(.error(.invalidArgs, "speak needs text"))
    }
    if isListening { teardownRecognition() }
    do {
      try activateSession()
    } catch {
      return result(.error(.failed, "The audio session could not start"))
    }
    installObservers()
    let utterance = AVSpeechUtterance(string: text)
    if let id = args.string("voiceId"), let voice = AVSpeechSynthesisVoice(identifier: id) {
      utterance.voice = voice
    } else if let locale = args.string("locale") {
      utterance.voice = AVSpeechSynthesisVoice(language: locale)
    }
    if let rate = args.double("rate") {
      utterance.rate = min(
        max(AVSpeechUtteranceDefaultSpeechRate * Float(rate), AVSpeechUtteranceMinimumSpeechRate),
        AVSpeechUtteranceMaximumSpeechRate)
    }
    // A new answer replaces the one still playing (its call ends "cancelled").
    if isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    pausedForVoiceOver = false
    speakResults[ObjectIdentifier(utterance)] = result
    synthesizer.speak(utterance)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    events.send(["type": "speechStart"])
    startEnvelope()
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    envelope = 1
    events.send(["type": "word", "location": characterRange.location, "length": characterRange.length])
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    complete(utterance, status: "finished")
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    complete(utterance, status: "cancelled")
  }

  private func complete(_ utterance: AVSpeechUtterance, status: String) {
    speakResults.removeValue(forKey: ObjectIdentifier(utterance))?(.value(status))
    events.send(["type": "speechEnd", "status": status])
    if !isSpeaking { stopEnvelope() }
  }

  private func startEnvelope() {
    guard envelopeTimer == nil else { return }
    let timer = Timer(timeInterval: Self.levelInterval, repeats: true) { [weak self] _ in
      self?.envelopeTick()
    }
    RunLoop.main.add(timer, forMode: .common)
    envelopeTimer = timer
  }

  private func envelopeTick() {
    let paused = pausedForVoiceOver || (createdSynthesizer?.isPaused ?? false)
    envelope *= 0.82
    let level = isSpeaking && !paused ? max(envelope, 0.12) : 0
    levels.send(["source": "tts", "level": level])
  }

  private func stopEnvelope() {
    envelopeTimer?.invalidate()
    envelopeTimer = nil
    envelope = 0
    levels.send(["source": "tts", "level": 0.0])
  }

  // MARK: VoiceOver, background, interruptions

  private func installObservers() {
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: UIAccessibility.elementFocusedNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.voiceOverSpeaks() },
      center.addObserver(
        forName: UIAccessibility.announcementDidFinishNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.scheduleVoiceOverResume(after: 0.3) },
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.interrupt(reason: "background") },
      center.addObserver(
        forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
      ) { [weak self] note in
        let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        if raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began {
          self?.interrupt(reason: "audioInterruption")
        }
      },
    ]
  }

  private func removeObservers() {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
  }

  /// VoiceOver moved focus and is reading: pause Avo until it is quiet.
  private func voiceOverSpeaks() {
    guard UIAccessibility.isVoiceOverRunning, let synthesizer = createdSynthesizer,
      synthesizer.isSpeaking || pausedForVoiceOver
    else { return }
    if !pausedForVoiceOver, !synthesizer.isPaused, synthesizer.pauseSpeaking(at: .immediate) {
      pausedForVoiceOver = true
      events.send(["type": "ttsPaused", "reason": "voiceOver"])
    }
    scheduleVoiceOverResume(after: 1.5)
  }

  private func scheduleVoiceOverResume(after delay: TimeInterval) {
    guard pausedForVoiceOver else { return }
    voiceOverResume?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.pausedForVoiceOver else { return }
      self.pausedForVoiceOver = false
      if self.createdSynthesizer?.continueSpeaking() == true {
        self.events.send(["type": "ttsResumed"])
      }
    }
    voiceOverResume = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  private func interrupt(reason: String) {
    guard isListening || isSpeaking else { return }
    teardownRecognition()
    createdSynthesizer?.stopSpeaking(at: .immediate)
    events.send(["type": "interrupted", "reason": reason])
  }

  // MARK: Audio session

  /// Play and record in one session, ducking other audio.
  private func activateSession() throws {
    let session = AVAudioSession.sharedInstance()
    if previousSession == nil {
      previousSession = (session.category, session.mode, session.categoryOptions)
    }
    try session.setCategory(
      .playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
    try session.setActive(true)
  }

  /// Leaving voice mode: stop, restore other audio and let the screen sleep.
  private func endSession() {
    teardownRecognition()
    createdSynthesizer?.stopSpeaking(at: .immediate)
    stopEnvelope()
    voiceOverResume?.cancel()
    pausedForVoiceOver = false
    removeObservers()
    UIApplication.shared.isIdleTimerDisabled = false
    guard let previous = previousSession else { return }
    previousSession = nil
    let session = AVAudioSession.sharedInstance()
    try? session.setActive(false, options: .notifyOthersOnDeactivation)
    try? session.setCategory(previous.0, mode: previous.1, options: previous.2)
  }

  // MARK: Helpers

  private static func voices(language: String?) -> [[String: String]] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { voice in
        if let language, !voice.language.hasPrefix(language) { return false }
        if #available(iOS 17.0, *) {
          return voice.voiceTraits.isDisjoint(with: [.isNoveltyVoice, .isPersonalVoice])
        }
        return true
      }
      .map { voice in
        var quality = voice.quality == .enhanced ? "enhanced" : "standard"
        if #available(iOS 16.0, *), voice.quality == .premium { quality = "premium" }
        return ["id": voice.identifier, "name": voice.name, "language": voice.language, "quality": quality]
      }
  }

  private static func timer(after interval: TimeInterval, _ block: @escaping () -> Void) -> Timer {
    let timer = Timer(timeInterval: interval, repeats: false) { _ in block() }
    RunLoop.main.add(timer, forMode: .common)
    return timer
  }
}
