import AVFoundation
import PhotosUI
import UIKit

/// `shoply/camera`: the meal photo camera of "Foto aufnehmen" (concept 15,
/// S4) and the system photo picker of "Aus Fotos wählen" (S3).
///
/// Both open full screen with a cross-fade, never sliding up from the bottom
/// (owner rule). The photo comes back as a JPEG with a long edge of at most
/// 1024 px at 80 % quality and stays in memory: nothing is written to the
/// photo library or to disk.
///
/// Never asks for the camera on its own: Dart calls `requestCameraAccess` on
/// `shoply/scanner` after the "Kamera für Essensfotos" alert, and
/// `takePhoto` refuses with `permission_denied` until the camera is allowed.
/// The photo picker needs no permission.
///
/// `takePhoto` and `pickPhoto` answer `{"status": "captured", "bytes": …}`,
/// `{"status": "picked", "bytes": …}` or `{"status": "cancelled"}`.
@MainActor
final class MealCameraChannel: NativeMethodHandler {
  private var pendingResult: NativeResult?
  private var picker: MealPhotoPicker?

  func handle(method: String, arguments: Any?, result: @escaping NativeResult) {
    switch method {
    case "isAvailable":
      result(.value(MealCameraViewController.backCamera != nil))
    case "takePhoto":
      takePhoto(arguments, result)
    case "pickPhoto":
      pickPhoto(result)
    default:
      result(.notImplemented)
    }
  }

  private func takePhoto(_ arguments: Any?, _ result: @escaping NativeResult) {
    guard MealCameraViewController.backCamera != nil else {
      return result(.error(.unavailable, "This device has no camera"))
    }
    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
      return result(.error(.permissionDenied, "Camera access is not allowed"))
    }
    guard pendingResult == nil else {
      return result(.error(.busy, "A camera is already open"))
    }
    guard let presenter = BarcodeScannerChannel.topViewController() else {
      return result(.error(.failed, "No view controller to present the camera"))
    }
    pendingResult = result
    let camera = MealCameraViewController(
      labels: MealCameraLabels(NativeArguments(arguments))
    ) { [weak self] outcome in
      self?.finish(outcome)
    }
    presenter.present(camera, animated: true)
  }

  private func pickPhoto(_ result: @escaping NativeResult) {
    guard pendingResult == nil else {
      return result(.error(.busy, "A camera is already open"))
    }
    guard let presenter = BarcodeScannerChannel.topViewController() else {
      return result(.error(.failed, "No view controller to present the photo picker"))
    }
    pendingResult = result
    let picker = MealPhotoPicker { [weak self] data in
      self?.picker = nil
      self?.finish(data.map { .picked($0) } ?? .cancelled)
    }
    self.picker = picker
    presenter.present(picker.controller, animated: true)
  }

  private func finish(_ outcome: MealCameraOutcome) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    switch outcome {
    case .captured(let data):
      result(.value(["status": "captured", "bytes": data]))
    case .picked(let data):
      result(.value(["status": "picked", "bytes": data]))
    case .cancelled:
      result(.value(["status": "cancelled"]))
    case .failed(let message):
      result(.error(.failed, message))
    }
  }
}

enum MealCameraOutcome {
  case captured(Data)
  case picked(Data)
  case cancelled
  case failed(String)
}

/// Texts of the camera screen, in the app language.
struct MealCameraLabels {
  let hint: String
  let hintShort: String
  let back: String
  let flash: String
  let flashOn: String
  let flashOff: String
  let shutter: String
  let library: String

  init(_ args: NativeArguments) {
    hint = args.string("hint")
      ?? "Den Teller von oben und ganz ins Bild nehmen. Eine Gabel daneben hilft, die Größe zu schätzen."
    hintShort = args.string("hintShort") ?? "Teller von oben fotografieren."
    back = args.string("back") ?? "Zurück"
    flash = args.string("flash") ?? "Blitz"
    flashOn = args.string("flashOn") ?? "An"
    flashOff = args.string("flashOff") ?? "Aus"
    shutter = args.string("shutter") ?? "Foto aufnehmen"
    library = args.string("library") ?? "Aus Fotos"
  }
}

/// A photo as the estimate needs it: JPEG, long edge at most 1024 px, 80 %.
enum MealPhotoEncoding {
  static let maxEdge: CGFloat = 1024
  static let quality: CGFloat = 0.8

  static func jpeg(from image: UIImage) -> Data? {
    let size = image.size
    let longest = max(size.width, size.height)
    guard longest > 0 else { return nil }
    let scale = min(1, maxEdge / longest)
    let target = CGSize(
      width: max(1, (size.width * scale).rounded()),
      height: max(1, (size.height * scale).rounded()))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    // `draw(in:)` applies the photo's orientation.
    let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
    return rendered.jpegData(compressionQuality: quality)
  }
}

/// The system photo picker (no photo library permission needed), full
/// screen with a cross-fade.
@MainActor
final class MealPhotoPicker: NSObject, PHPickerViewControllerDelegate {
  let controller: PHPickerViewController
  private let onFinish: (Data?) -> Void
  private var finished = false

  init(onFinish: @escaping (Data?) -> Void) {
    var configuration = PHPickerConfiguration()
    configuration.filter = .images
    configuration.selectionLimit = 1
    controller = PHPickerViewController(configuration: configuration)
    controller.modalPresentationStyle = .fullScreen
    controller.modalTransitionStyle = .crossDissolve
    self.onFinish = onFinish
    super.init()
    controller.delegate = self
  }

  nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    MainActor.assumeIsolated {
      let provider = results.first?.itemProvider
      picker.presentingViewController?.dismiss(animated: true)
      guard let provider, provider.canLoadObject(ofClass: UIImage.self) else {
        return finish(nil)
      }
      provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
        let data = (object as? UIImage).flatMap(MealPhotoEncoding.jpeg(from:))
        DispatchQueue.main.async { self?.finish(data) }
      }
    }
  }

  private func finish(_ data: Data?) {
    guard !finished else { return }
    finished = true
    onFinish(data)
  }
}

/// The camera of S4: black, the camera image edge to edge, back and flash
/// at the top, the hint on a dark capsule below them, the shutter (ring 72,
/// circle 60, no glass) at the bottom centre and "Aus Fotos" to its left.
final class MealCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
  private let labels: MealCameraLabels
  private let onFinish: (MealCameraOutcome) -> Void

  private let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private let sessionQueue = DispatchQueue(label: "com.shoply.meal-camera")
  private let previewLayer: AVCaptureVideoPreviewLayer

  private let closeButton = UIButton(type: .system)
  private let flashButton = UIButton(type: .system)
  private let libraryButton = UIButton(type: .system)
  private let shutterButton = MealShutterButton()
  private let hintBackground = UIView()
  private let hintLabel = UILabel()

  private var picker: MealPhotoPicker?
  private var flashOn = false
  private var capturing = false
  private var finished = false

  static var backCamera: AVCaptureDevice? {
    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
  }

  init(labels: MealCameraLabels, onFinish: @escaping (MealCameraOutcome) -> Void) {
    self.labels = labels
    self.onFinish = onFinish
    previewLayer = AVCaptureVideoPreviewLayer(session: session)
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
    modalTransitionStyle = .crossDissolve
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  // MARK: Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)

    hintBackground.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    hintBackground.layer.cornerRadius = 16
    hintBackground.layer.cornerCurve = .continuous
    hintBackground.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hintBackground)

    let large = traitCollection.preferredContentSizeCategory >= .accessibilityExtraLarge
    hintLabel.text = large ? labels.hintShort : labels.hint
    hintLabel.textColor = .white
    hintLabel.textAlignment = .center
    hintLabel.numberOfLines = 0
    hintLabel.font = .preferredFont(forTextStyle: .subheadline)
    hintLabel.adjustsFontForContentSizeCategory = true
    hintLabel.translatesAutoresizingMaskIntoConstraints = false
    hintBackground.addSubview(hintLabel)

    configure(closeButton, symbol: "chevron.left", label: labels.back)
    closeButton.addAction(UIAction { [weak self] _ in self?.close(.cancelled) }, for: .touchUpInside)
    configure(flashButton, symbol: "bolt.slash", label: labels.flash)
    flashButton.accessibilityValue = labels.flashOff
    flashButton.addAction(UIAction { [weak self] _ in self?.toggleFlash() }, for: .touchUpInside)
    flashButton.isHidden = !(Self.backCamera?.hasFlash ?? false)
    configure(libraryButton, symbol: "photo.on.rectangle", label: labels.library)
    libraryButton.addAction(UIAction { [weak self] _ in self?.openLibrary() }, for: .touchUpInside)

    shutterButton.accessibilityLabel = labels.shutter
    shutterButton.showsLargeContentViewer = true
    shutterButton.largeContentTitle = labels.shutter
    shutterButton.addInteraction(UILargeContentViewerInteraction())
    shutterButton.translatesAutoresizingMaskIntoConstraints = false
    shutterButton.addAction(UIAction { [weak self] _ in self?.capture() }, for: .touchUpInside)
    view.addSubview(shutterButton)

    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
      closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      closeButton.widthAnchor.constraint(equalToConstant: 44),
      closeButton.heightAnchor.constraint(equalToConstant: 44),
      flashButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
      flashButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      flashButton.widthAnchor.constraint(equalToConstant: 44),
      flashButton.heightAnchor.constraint(equalToConstant: 44),
      hintBackground.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 16),
      hintBackground.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
      hintBackground.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
      hintLabel.topAnchor.constraint(equalTo: hintBackground.topAnchor, constant: 8),
      hintLabel.bottomAnchor.constraint(equalTo: hintBackground.bottomAnchor, constant: -8),
      hintLabel.leadingAnchor.constraint(equalTo: hintBackground.leadingAnchor, constant: 12),
      hintLabel.trailingAnchor.constraint(equalTo: hintBackground.trailingAnchor, constant: -12),
      shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      shutterButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
      shutterButton.widthAnchor.constraint(equalToConstant: MealShutterButton.size),
      shutterButton.heightAnchor.constraint(equalToConstant: MealShutterButton.size),
      libraryButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
      libraryButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
      libraryButton.widthAnchor.constraint(equalToConstant: 44),
      libraryButton.heightAnchor.constraint(equalToConstant: 44),
    ])
    view.accessibilityElements = [closeButton, flashButton, hintLabel, libraryButton, shutterButton]

    configureSession()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer.frame = view.bounds
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    UIAccessibility.post(notification: .screenChanged, argument: closeButton)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    let session = self.session
    sessionQueue.async { if session.isRunning { session.stopRunning() } }
  }

  override func accessibilityPerformEscape() -> Bool {
    close(.cancelled)
    return true
  }

  // MARK: Session

  private func configureSession() {
    guard let device = Self.backCamera, let input = try? AVCaptureDeviceInput(device: device) else {
      close(.failed("The camera could not start"))
      return
    }
    let session = self.session
    let output = self.output
    sessionQueue.async {
      session.beginConfiguration()
      session.sessionPreset = .photo
      if session.canAddInput(input) { session.addInput(input) }
      if session.canAddOutput(output) { session.addOutput(output) }
      session.commitConfiguration()
      session.startRunning()
    }
  }

  private func capture() {
    guard !capturing, !finished else { return }
    capturing = true
    shutterButton.isEnabled = false
    let settings = AVCapturePhotoSettings()
    if output.supportedFlashModes.contains(.on), flashOn {
      settings.flashMode = .on
    }
    // No haptic: the system plays the shutter sound.
    output.capturePhoto(with: settings, delegate: self)
  }

  nonisolated func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    let image = error == nil ? photo.fileDataRepresentation().flatMap(UIImage.init(data:)) : nil
    let data = image.flatMap(MealPhotoEncoding.jpeg(from:))
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.capturing = false
      self.shutterButton.isEnabled = true
      if let data {
        self.close(.captured(data))
      } else {
        self.close(.failed("The photo could not be taken"))
      }
    }
  }

  // MARK: Flash and library

  private func toggleFlash() {
    flashOn.toggle()
    var config = flashButton.configuration
    config?.image = UIImage(
      systemName: flashOn ? "bolt" : "bolt.slash",
      withConfiguration: UIImage.SymbolConfiguration(textStyle: .body))
    flashButton.configuration = config
    flashButton.accessibilityValue = flashOn ? labels.flashOn : labels.flashOff
  }

  private func openLibrary() {
    guard !finished else { return }
    let picker = MealPhotoPicker { [weak self] data in
      guard let self else { return }
      self.picker = nil
      if let data { self.close(.picked(data)) }
    }
    self.picker = picker
    present(picker.controller, animated: true)
  }

  private func close(_ outcome: MealCameraOutcome) {
    guard !finished else { return }
    finished = true
    let session = self.session
    sessionQueue.async { if session.isRunning { session.stopRunning() } }
    let onFinish = self.onFinish
    if let presenter = presentingViewController {
      presenter.dismiss(animated: true) { onFinish(outcome) }
    } else {
      onFinish(outcome)
    }
  }

  // MARK: Drawing

  private func configure(_ button: UIButton, symbol: String, label: String) {
    var config: UIButton.Configuration
    if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
      config = .glass()
    } else {
      config = .filled()
      config.baseBackgroundColor = UIColor(
        white: 0.12, alpha: UIAccessibility.isReduceTransparencyEnabled ? 1 : 0.72)
    }
    config.baseForegroundColor = .white
    config.cornerStyle = .capsule
    config.image = UIImage(
      systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(textStyle: .body))
    button.configuration = config
    button.accessibilityLabel = label
    button.showsLargeContentViewer = true
    button.largeContentTitle = label
    button.addInteraction(UILargeContentViewerInteraction())
    button.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)
  }
}

/// The shutter: a white ring (72 pt, 4 pt line) around a white circle
/// (60 pt). Dims while pressed.
final class MealShutterButton: UIControl {
  static let size: CGFloat = 72
  private let ring = CAShapeLayer()
  private let dot = CAShapeLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isAccessibilityElement = true
    accessibilityTraits = .button
    ring.strokeColor = UIColor.white.cgColor
    ring.fillColor = UIColor.clear.cgColor
    ring.lineWidth = 4
    dot.fillColor = UIColor.white.cgColor
    layer.addSublayer(ring)
    layer.addSublayer(dot)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

  override func layoutSubviews() {
    super.layoutSubviews()
    ring.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).cgPath
    let inset = (bounds.width - 60) / 2
    dot.path = UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)).cgPath
  }

  override var isHighlighted: Bool {
    didSet { alpha = isHighlighted || !isEnabled ? 0.6 : 1 }
  }

  override var isEnabled: Bool {
    didSet { alpha = isEnabled ? 1 : 0.6 }
  }
}
