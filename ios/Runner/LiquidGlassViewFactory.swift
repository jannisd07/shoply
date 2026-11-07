import Flutter
import UIKit

/// Registers the `shoply/liquid_glass` platform view with the Flutter engine.
///
/// Renders genuine iOS 26 Liquid Glass (`UIGlassEffect`), falling back to a
/// system material blur on iOS 25 and earlier.
///
/// Two things matter here and are easy to get wrong:
///
///  1. **Never clip a glass view.** `layer.cornerRadius` + `clipsToBounds` is
///     ignored by `UIGlassEffect` (and on older betas actively broke it). The
///     shape has to come from `cornerConfiguration`, because the effect draws
///     its specular rim and edge lensing *from* that shape. Clipping a
///     rectangular glass into a rounded frame throws exactly those cues away,
///     which is what makes a hand-rolled blur look flat next to Apple's.
///
///  2. **Merging needs one container.** Separate glass views never blend. To
///     get the Messages behaviour — where the "+" button and the composer
///     capsule bulge toward each other and fuse as they approach — the shapes
///     must be siblings inside a single `UIVisualEffectView` whose effect is a
///     `UIGlassContainerEffect`. That is why `shoply/liquid_glass_group`
///     exists: Flutter cannot merge two independent platform views, so one
///     view owns both shapes and Flutter draws its content on top.
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
        return LiquidGlassView(frame: frame, args: args as? [String: Any])
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Factory for the grouped variant: a container effect holding N glass shapes
/// that merge when they come within `spacing` of one another.
class LiquidGlassGroupViewFactory: NSObject, FlutterPlatformViewFactory {
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
        return LiquidGlassGroupView(frame: frame, args: args as? [String: Any])
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Shared helpers

private enum GlassBuilder {
    /// A single glass surface. `cornerRadius <= 0` means "capsule".
    static func makeEffectView(
        cornerRadius: CGFloat,
        isCapsule: Bool,
        interactive: Bool,
        tint: UIColor?,
        clearStyle: Bool
    ) -> UIVisualEffectView {
        let effectView: UIVisualEffectView

        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: clearStyle ? .clear : .regular)
            // Expands and highlights under the finger, the way system
            // controls do. Without this the glass is inert and reads as a
            // static blur.
            glass.isInteractive = interactive
            glass.tintColor = tint
            effectView = UIVisualEffectView(effect: glass)
        } else {
            effectView = UIVisualEffectView(
                effect: UIBlurEffect(style: .systemThinMaterial)
            )
        }

        applyCorners(
            to: effectView,
            cornerRadius: cornerRadius,
            isCapsule: isCapsule
        )
        return effectView
    }

    static func applyCorners(
        to view: UIVisualEffectView,
        cornerRadius: CGFloat,
        isCapsule: Bool
    ) {
        if #available(iOS 26.0, *) {
            // The shape the effect renders against — not a clip.
            view.cornerConfiguration =
                isCapsule || cornerRadius <= 0
                ? .capsule()
                : .corners(radius: .fixed(cornerRadius))
        } else {
            // Pre-26 there is no cornerConfiguration; a plain blur tolerates
            // being clipped, so the old approach is correct on that path.
            view.layer.cornerCurve = .continuous
            view.layer.cornerRadius = isCapsule
                ? min(view.bounds.width, view.bounds.height) / 2
                : cornerRadius
            view.clipsToBounds = true
        }
    }

    static func color(fromARGB value: Any?) -> UIColor? {
        guard let argb = value as? NSNumber else { return nil }
        let v = argb.uint32Value
        return UIColor(
            red: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: CGFloat((v >> 24) & 0xFF) / 255.0
        )
    }
}

// MARK: - Single glass surface

class LiquidGlassView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private let effectView: UIVisualEffectView
    private let isCapsule: Bool
    private let cornerRadius: CGFloat

    init(frame: CGRect, args: [String: Any]?) {
        cornerRadius = (args?["cornerRadius"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
        isCapsule = (args?["isCircle"] as? Bool) ?? (args?["isCapsule"] as? Bool) ?? false

        let interactive = (args?["interactive"] as? Bool) ?? true
        let clearStyle = (args?["style"] as? String) == "clear"
        let tint = GlassBuilder.color(fromARGB: args?["tint"])

        containerView = UIView(frame: frame)
        containerView.backgroundColor = .clear
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // The glass must never be clipped by its host either.
        containerView.clipsToBounds = false

        effectView = GlassBuilder.makeEffectView(
            cornerRadius: cornerRadius,
            isCapsule: isCapsule,
            interactive: interactive,
            tint: tint,
            clearStyle: clearStyle
        )
        effectView.frame = containerView.bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        super.init()
        containerView.addSubview(effectView)
    }

    func view() -> UIView {
        return containerView
    }
}

// MARK: - Merging glass group

/// Hosts several glass shapes inside one `UIGlassContainerEffect`, so they
/// fuse when they get close — the composer's "+" button and text capsule.
///
/// Shapes arrive as logical-pixel rects in the platform view's own coordinate
/// space, so Flutter stays the single source of truth for layout.
class LiquidGlassGroupView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private var hostView: UIVisualEffectView?
    private var shapeViews: [UIVisualEffectView] = []
    private var shapes: [[String: Any]] = []

    init(frame: CGRect, args: [String: Any]?) {
        containerView = UIView(frame: frame)
        containerView.backgroundColor = .clear
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.clipsToBounds = false

        shapes = (args?["shapes"] as? [[String: Any]]) ?? []
        let spacing = (args?["spacing"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 20
        let interactive = (args?["interactive"] as? Bool) ?? true
        let clearStyle = (args?["style"] as? String) == "clear"
        let tint = GlassBuilder.color(fromARGB: args?["tint"])

        super.init()

        let host: UIVisualEffectView
        if #available(iOS 26.0, *) {
            let container = UIGlassContainerEffect()
            // Distance at which neighbouring shapes start to blend.
            container.spacing = spacing
            host = UIVisualEffectView(effect: container)
        } else {
            host = UIVisualEffectView(effect: nil)
        }
        host.frame = containerView.bounds
        host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.clipsToBounds = false
        containerView.addSubview(host)
        hostView = host

        for shape in shapes {
            let radius = (shape["cornerRadius"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let capsule = (shape["isCapsule"] as? Bool) ?? false
            let shapeView = GlassBuilder.makeEffectView(
                cornerRadius: radius,
                isCapsule: capsule,
                interactive: interactive,
                tint: tint,
                clearStyle: clearStyle
            )
            // Children of a container effect go into its contentView.
            host.contentView.addSubview(shapeView)
            shapeViews.append(shapeView)
        }

        layoutShapes()
    }

    private func layoutShapes() {
        for (index, shape) in shapes.enumerated() {
            guard index < shapeViews.count else { break }
            let x = (shape["x"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let y = (shape["y"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let w = (shape["width"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let h = (shape["height"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            shapeViews[index].frame = CGRect(x: x, y: y, width: w, height: h)
        }
    }

    func view() -> UIView {
        return containerView
    }
}
