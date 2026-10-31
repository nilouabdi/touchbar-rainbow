// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import QuartzCore
import RainbowCore

/// The flowing rainbow. A layer-hosting view with:
///
/// * a horizontal `CAGradientLayer` two colour cycles wide, slid left by one cycle per period by a
///   single repeating Core Animation animation (rendered by the GPU / render server, ~0 % CPU);
/// * a soft white sheen on the top edge;
/// * rounded corners like the system Touch Bar keys.
///
/// `RainbowCore.FrameRenderer` reproduces this layer tree pixel for pixel, which is what the
/// visual tests check.
final class RainbowView: NSView {
    private static let animationKey = "flow"

    private let root = CALayer()
    private let gradient = CAGradientLayer()
    private let sheen = CAGradientLayer()

    var style: RainbowStyle {
        didSet {
            guard style != oldValue else { return }
            applyStyle()
            restartAnimation()
        }
    }

    private var widthConstraint: NSLayoutConstraint?

    init(style: RainbowStyle, initialWidth: CGFloat) {
        self.style = style
        super.init(frame: NSRect(x: 0, y: 0, width: initialWidth, height: 30))

        translatesAutoresizingMaskIntoConstraints = false
        let width = widthAnchor.constraint(equalToConstant: initialWidth)
        width.isActive = true
        widthConstraint = width

        // Layer-hosting: assign the layer before turning on wantsLayer.
        root.masksToBounds = true
        root.backgroundColor = CGColor(gray: 0, alpha: 1)
        layer = root
        wantsLayer = true

        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        root.addSublayer(gradient)

        // Layer unit coordinates are y-up on macOS, so y = 1 is the top edge.
        sheen.startPoint = CGPoint(x: 0.5, y: 1)
        sheen.endPoint = CGPoint(x: 0.5, y: 0)
        root.addSublayer(sheen)

        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Flowing rainbow")

        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: CGFloat(FrameRenderer.touchBarHeight))
    }

    private func applyStyle() {
        let stops = GradientStops(style: style)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.cornerRadius = CGFloat(style.cornerRadius)
        gradient.colors = stops.colors.map { CGColor(srgbRed: $0.r, green: $0.g, blue: $0.b, alpha: 1) }
        gradient.locations = stops.locations.map { NSNumber(value: $0) }
        sheen.colors = [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: style.sheenOpacity),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
        ]
        sheen.locations = [0, NSNumber(value: style.sheenDepth)]
        CATransaction.commit()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let h = bounds.height
        // Assign bounds/position rather than frame so the running translation animation is untouched.
        gradient.bounds = CGRect(x: 0, y: 0, width: 2 * style.cycleWidth, height: h)
        gradient.position = CGPoint(x: style.cycleWidth, y: h / 2)
        sheen.frame = bounds
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            NSLog("TouchBarRainbow: rainbow on screen, touch bar window width \(window.frame.width), item width \(bounds.width)")
            restartAnimation()
            // Let the Touch Bar finish its layout, then grow into the free space.
            DispatchQueue.main.async { [weak self] in self?.fillAvailableWidth() }
        } else {
            gradient.removeAnimation(forKey: Self.animationKey)
        }
    }

    /// Widens the rainbow to the space between its left edge and the end of the Touch Bar,
    /// never wider than one colour cycle (the gradient layer is two cycles wide and slides by one).
    private func fillAvailableWidth() {
        guard let window, let widthConstraint else { return }
        let left = convert(bounds, to: nil).minX
        let available = floor(window.frame.width - left - 4)
        let target = min(available, CGFloat(style.cycleWidth))
        guard target >= 200, abs(target - widthConstraint.constant) > 1 else { return }
        NSLog("TouchBarRainbow: widening rainbow from \(widthConstraint.constant) to \(target)")
        widthConstraint.constant = target
    }

    private func restartAnimation() {
        gradient.removeAnimation(forKey: Self.animationKey)
        guard window != nil else { return }
        let flow = CABasicAnimation(keyPath: "transform.translation.x")
        flow.fromValue = 0
        flow.toValue = -style.cycleWidth
        flow.duration = style.period
        flow.repeatCount = .infinity
        flow.timingFunction = CAMediaTimingFunction(name: .linear)
        flow.isRemovedOnCompletion = false
        gradient.add(flow, forKey: Self.animationKey)
    }
}
