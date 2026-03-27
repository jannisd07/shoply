import Flutter
import UIKit

/// Registers the `shoply/liquid_glass` platform view with the Flutter engine.
/// This renders a real UIGlassEffect (iOS 26+) or UIBlurEffect fallback.
class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return LiquidGlassView(frame: frame, viewId: viewId, args: args as? [String: Any])
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class LiquidGlassView: NSObject, FlutterPlatformView {
    private let containerView: UIView

    init(frame: CGRect, viewId: Int64, args: [String: Any]?) {
        let cornerRadius = args?["cornerRadius"] as? CGFloat ?? 0
        let isCircle = args?["isCircle"] as? Bool ?? false

        containerView = UIView(frame: frame)
        containerView.backgroundColor = .clear
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        super.init()

        let effectView: UIVisualEffectView

        if #available(iOS 26.0, *) {
            // Real Liquid Glass via UIGlassEffect
            let glassEffect = UIGlassEffect()
            effectView = UIVisualEffectView(effect: glassEffect)
        } else {
            // Fallback: system thin material blur (frosted glass look)
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }

        effectView.frame = frame
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if isCircle {
            effectView.clipsToBounds = true
            // Will be updated in layoutSubviews via observer
            containerView.addObserver(self, forKeyPath: "bounds", options: [.new], context: nil)
        } else if cornerRadius > 0 {
            effectView.layer.cornerRadius = cornerRadius
            effectView.layer.cornerCurve = .continuous
            effectView.clipsToBounds = true
        }

        containerView.addSubview(effectView)
        containerView.tag = isCircle ? 1 : 0
    }

    deinit {
        if containerView.tag == 1 {
            containerView.removeObserver(self, forKeyPath: "bounds")
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "bounds", let view = containerView.subviews.first {
            view.layer.cornerRadius = min(containerView.bounds.width, containerView.bounds.height) / 2
            view.layer.cornerCurve = .continuous  // Apple's smooth squircle
        }
    }

    func view() -> UIView {
        return containerView
    }
}
