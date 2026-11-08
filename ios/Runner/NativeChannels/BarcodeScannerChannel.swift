import AVFoundation
import UIKit
import Vision
import VisionKit

/// `shoply/scanner`: barcode camera for "Essen eintragen" (concept 15, S6).
///
/// VisionKit `DataScannerViewController` (iOS 16+, A12 or newer). On iOS 15
/// and older devices `isSupported` is false and `scan` answers `unavailable`,
/// so the app shows the digit field instead.
///
/// Never asks for the camera on its own: `requestCameraAccess` is called by
/// Dart after the "Kamera für Strichcodes" alert, and `scan` refuses with
/// `permission_denied` until the camera is allowed.
///
/// `scan` answers `{"status": "scanned", "code": "4056489123453",
/// "symbology": "ean13"}`, `{"status": "manual"}` (tapped "Nummer eingeben")
/// or `{"status": "cancelled"}`.
@MainActor
final class BarcodeScannerChannel: NativeMethodHandler {
  private var pendingResult: NativeResult?

  func handle(method: String, arguments: Any?, result: @escaping NativeResult) {
    switch method {
    case "isSupported":
      result(.value(Self.isScannerSupported))
    case "cameraPermission":
      result(.value(Self.cameraPermission))
    case "requestCameraAccess":
      AVCaptureDevice.requestAccess(for: .video) { granted in result(.value(granted)) }
    case "scan":
      scan(arguments, result)
    default:
      result(.notImplemented)
    }
  }

  private static var isScannerSupported: Bool {
    if #available(iOS 16.0, *) {
      return DataScannerViewController.isSupported
    }
    return false
  }

  private static var cameraPermission: String {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "denied"
    }
  }

  private func scan(_ arguments: Any?, _ result: @escaping NativeResult) {
    guard #available(iOS 16.0, *), DataScannerViewController.isSupported else {
      return result(.error(.unavailable, "The barcode scanner needs iOS 16 and an A12 chip"))
    }
    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
      return result(.error(.permissionDenied, "Camera access is not allowed"))
    }
    guard pendingResult == nil else {
      return result(.error(.busy, "A scanner is already open"))
    }
    guard let presenter = Self.topViewController() else {
      return result(.error(.failed, "No view controller to present the scanner"))
    }
    pendingResult = result
    let scanner = BarcodeScannerViewController(
      labels: BarcodeScannerLabels(NativeArguments(arguments))
    ) { [weak self] outcome in
      self?.finish(outcome)
    }
    presenter.present(scanner, animated: true)
  }

  private func finish(_ outcome: BarcodeScanOutcome) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    switch outcome {
    case .scanned(let code, let symbology):
      result(.value(["status": "scanned", "code": code, "symbology": symbology]))
    case .manual:
      result(.value(["status": "manual"]))
    case .cancelled:
      result(.value(["status": "cancelled"]))
    case .failed(let message):
      result(.error(.failed, message))
    }
  }

  static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let active = scenes.filter { $0.activationState == .foregroundActive }
    let windows = (active.isEmpty ? scenes : active).flatMap(\.windows)
    var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }
}

enum BarcodeScanOutcome {
  case scanned(code: String, symbology: String)
  case manual
  case cancelled
  case failed(String)
}

/// Texts from Dart (app language), with German defaults.
struct BarcodeScannerLabels {
  let hint: String
  let manualEntry: String
  let close: String
  let torch: String
  let torchOn: String
  let torchOff: String

  init(_ args: NativeArguments) {
    hint = args.string("hint") ?? "Strichcode in den Rahmen halten"
    manualEntry = args.string("manualEntry") ?? "Nummer eingeben"
    close = args.string("close") ?? "Zurück"
    torch = args.string("torch") ?? "Taschenlampe"
    torchOn = args.string("torchOn") ?? "An"
    torchOff = args.string("torchOff") ?? "Aus"
  }
}

/// Full-screen scanner (never a sheet): camera, dimmed surroundings with a
/// 280 × 160 frame (248 × 144 on 320-pt screens), back and flashlight at the
/// top, "Nummer eingeben" at the bottom. A recognised code moves the frame
/// onto the barcode, shows the digits for 0.4 s with a light haptic, then
/// the screen closes.
@available(iOS 16.0, *)
final class BarcodeScannerViewController: UIViewController, DataScannerViewControllerDelegate {
  private let labels: BarcodeScannerLabels
  private let onFinish: (BarcodeScanOutcome) -> Void
  private let scanner = DataScannerViewController(
    recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
    qualityLevel: .balanced,
    recognizesMultipleItems: false,
    isHighFrameRateTrackingEnabled: false,
    isPinchToZoomEnabled: true,
    isGuidanceEnabled: false,
    isHighlightingEnabled: false
  )

  private let dimLayer = CAShapeLayer()
  private let cornerLayer = CAShapeLayer()
  private let hintLabel = UILabel()
  private let closeButton = UIButton(type: .system)
  private let torchButton = UIButton(type: .system)
  private let manualButton = UIButton(type: .system)
  private var frameRect = CGRect.zero
  private var recognised = false
  private var finished = false
  private var torchOn = false
  private lazy var hintTop = hintLabel.topAnchor.constraint(equalTo: view.topAnchor)

  private static let cornerRadius: CGFloat = 20
  private static let recognisedColor = UIColor.systemGreen

  init(labels: BarcodeScannerLabels, onFinish: @escaping (BarcodeScanOutcome) -> Void) {
    self.labels = labels
    self.onFinish = onFinish
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

    addChild(scanner)
    scanner.view.frame = view.bounds
    scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    scanner.view.accessibilityElementsHidden = true
    view.addSubview(scanner.view)
    scanner.didMove(toParent: self)
    scanner.delegate = self

    dimLayer.fillRule = .evenOdd
    dimLayer.fillColor = UIColor.black.withAlphaComponent(0.4).cgColor
    view.layer.addSublayer(dimLayer)

    cornerLayer.strokeColor = UIColor.white.cgColor
    cornerLayer.fillColor = UIColor.clear.cgColor
    cornerLayer.lineWidth = 4
    cornerLayer.lineCap = .round
    view.layer.addSublayer(cornerLayer)

    hintLabel.text = labels.hint
    hintLabel.textColor = .white
    hintLabel.textAlignment = .center
    hintLabel.numberOfLines = 0
    hintLabel.font = .preferredFont(forTextStyle: .body)
    hintLabel.adjustsFontForContentSizeCategory = true
    hintLabel.accessibilityTraits = .updatesFrequently
    hintLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hintLabel)

    configure(closeButton, symbol: "chevron.left", title: nil, label: labels.close)
    closeButton.addAction(UIAction { [weak self] _ in self?.close(.cancelled) }, for: .touchUpInside)
    configure(torchButton, symbol: "flashlight.off.fill", title: nil, label: labels.torch)
    torchButton.accessibilityValue = labels.torchOff
    torchButton.addAction(UIAction { [weak self] _ in self?.toggleTorch() }, for: .touchUpInside)
    torchButton.isHidden = !Self.hasTorch
    configure(manualButton, symbol: "keyboard", title: labels.manualEntry, label: labels.manualEntry)
    manualButton.addAction(UIAction { [weak self] _ in self?.close(.manual) }, for: .touchUpInside)

    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
      closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      closeButton.widthAnchor.constraint(equalToConstant: 44),
      closeButton.heightAnchor.constraint(equalToConstant: 44),
      torchButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
      torchButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      torchButton.widthAnchor.constraint(equalToConstant: 44),
      torchButton.heightAnchor.constraint(equalToConstant: 44),
      manualButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      manualButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
      manualButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
      manualButton.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 16),
      manualButton.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16),
      hintLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
      hintLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
      hintTop,
    ])
    view.accessibilityElements = [closeButton, hintLabel, torchButton, manualButton]
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let compact = view.bounds.width <= 320
    let size = compact ? CGSize(width: 248, height: 144) : CGSize(width: 280, height: 160)
    frameRect = CGRect(
      x: (view.bounds.width - size.width) / 2,
      y: view.bounds.height * 0.42 - size.height / 2,
      width: size.width, height: size.height
    ).integral
    let dim = UIBezierPath(rect: view.bounds)
    dim.append(UIBezierPath(roundedRect: frameRect, cornerRadius: Self.cornerRadius))
    dimLayer.path = dim.cgPath
    if !recognised {
      cornerLayer.path = Self.cornerPath(in: frameRect)
      scanner.regionOfInterest = frameRect
    }
    // Same value again must not dirty the layout (no layout loop).
    if hintTop.constant != frameRect.maxY + 24 { hintTop.constant = frameRect.maxY + 24 }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    do {
      try scanner.startScanning()
      UIAccessibility.post(notification: .screenChanged, argument: hintLabel)
    } catch {
      close(.failed("The camera could not start"))
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    scanner.stopScanning()
    setTorch(false)
  }

  override func accessibilityPerformEscape() -> Bool {
    close(.cancelled)
    return true
  }

  // MARK: DataScannerViewControllerDelegate

  func dataScanner(
    _ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
    allItems: [RecognizedItem]
  ) {
    consider(addedItems)
  }

  func dataScanner(
    _ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem],
    allItems: [RecognizedItem]
  ) {
    consider(updatedItems)
  }

  func dataScanner(
    _ dataScanner: DataScannerViewController,
    becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
  ) {
    close(.failed("The scanner became unavailable"))
  }

  // MARK: Recognition

  private func consider(_ items: [RecognizedItem]) {
    guard !recognised else { return }
    for item in items {
      guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue else {
        continue
      }
      let symbology = Self.name(of: barcode.observation.symbology)
      guard let code = GTIN.normalize(payload, symbology: symbology) else { continue }
      recognise(code: code, symbology: symbology, bounds: item.bounds)
      return
    }
  }

  private func recognise(code: String, symbology: String, bounds: RecognizedItem.Bounds) {
    recognised = true
    scanner.stopScanning()
    UIImpactFeedbackGenerator(style: .light).impactOccurred()

    let points = [bounds.topLeft, bounds.topRight, bounds.bottomRight, bounds.bottomLeft]
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    let target = CGRect(
      x: xs.min() ?? frameRect.minX, y: ys.min() ?? frameRect.minY,
      width: (xs.max() ?? frameRect.maxX) - (xs.min() ?? frameRect.minX),
      height: (ys.max() ?? frameRect.maxY) - (ys.min() ?? frameRect.minY)
    ).insetBy(dx: -12, dy: -12)
    let newPath = Self.cornerPath(in: target.width > 40 && target.height > 24 ? target : frameRect)

    if !UIAccessibility.isReduceMotionEnabled {
      let spring = CASpringAnimation(keyPath: "path")
      spring.fromValue = cornerLayer.path
      spring.toValue = newPath
      spring.mass = 1
      spring.stiffness = 420
      spring.damping = 32
      spring.duration = spring.settlingDuration
      cornerLayer.add(spring, forKey: "snap")
    }
    cornerLayer.path = newPath
    cornerLayer.strokeColor = Self.recognisedColor.cgColor

    let formatted = GTIN.formatted(code)
    hintLabel.font = .monospacedDigitSystemFont(
      ofSize: UIFont.preferredFont(forTextStyle: .title3).pointSize, weight: .semibold)
    hintLabel.text = formatted
    UIAccessibility.post(notification: .announcement, argument: formatted)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
      self?.close(.scanned(code: code, symbology: symbology))
    }
  }

  private static func name(of symbology: VNBarcodeSymbology) -> String {
    switch symbology {
    case .ean8: return "ean8"
    case .upce: return "upce"
    default: return "ean13"
    }
  }

  private func close(_ outcome: BarcodeScanOutcome) {
    guard !finished else { return }
    finished = true
    scanner.stopScanning()
    setTorch(false)
    let onFinish = self.onFinish
    if let presenter = presentingViewController {
      presenter.dismiss(animated: true) { onFinish(outcome) }
    } else {
      onFinish(outcome)
    }
  }

  // MARK: Torch

  private static var hasTorch: Bool {
    AVCaptureDevice.default(for: .video)?.hasTorch ?? false
  }

  private func toggleTorch() {
    setTorch(!torchOn)
  }

  private func setTorch(_ on: Bool) {
    guard on != torchOn, let device = AVCaptureDevice.default(for: .video), device.hasTorch
    else { return }
    do {
      try device.lockForConfiguration()
      device.torchMode = on && device.isTorchAvailable ? .on : .off
      device.unlockForConfiguration()
      torchOn = device.torchMode == .on
    } catch {
      torchOn = false
    }
    var config = torchButton.configuration
    config?.image = UIImage(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
    torchButton.configuration = config
    torchButton.accessibilityValue = torchOn ? labels.torchOn : labels.torchOff
  }

  // MARK: Drawing

  private func configure(_ button: UIButton, symbol: String, title: String?, label: String) {
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
    if let title {
      config.title = title
      config.imagePadding = 8
      config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
        var attributes = $0
        attributes.font = UIFont.preferredFont(forTextStyle: .headline)
        return attributes
      }
    }
    button.configuration = config
    button.accessibilityLabel = label
    button.showsLargeContentViewer = true
    button.largeContentTitle = label
    button.addInteraction(UILargeContentViewerInteraction())
    button.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)
  }

  /// Four rounded corner brackets, 4 pt white, radius 20.
  private static func cornerPath(in rect: CGRect) -> CGPath {
    let r = min(cornerRadius, rect.width / 4, rect.height / 4)
    let arm = min(28, rect.width / 3, rect.height / 3)
    let path = UIBezierPath()
    // Top left
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
    path.addQuadCurve(
      to: CGPoint(x: rect.minX + r, y: rect.minY), controlPoint: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
    // Top right
    path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: rect.minY + r), controlPoint: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
    // Bottom right
    path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX - r, y: rect.maxY), controlPoint: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
    // Bottom left
    path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
    path.addQuadCurve(
      to: CGPoint(x: rect.minX, y: rect.maxY - r), controlPoint: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
    return path.cgPath
  }
}
