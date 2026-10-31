// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A simple RGB raster.
public struct Image: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [RGB]

    public init(width: Int, height: Int, fill: RGB = .black) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: fill, count: width * height)
    }

    public subscript(x: Int, y: Int) -> RGB {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    /// Binary PPM (P6), viewable almost everywhere and trivially convertible to PNG/GIF.
    public func ppmData() -> Data {
        var data = Data("P6\n\(width) \(height)\n255\n".utf8)
        data.reserveCapacity(data.count + width * height * 3)
        for p in pixels {
            let (r, g, b) = p.bytes
            data.append(contentsOf: [r, g, b])
        }
        return data
    }
}

/// Rasterises the rainbow exactly as the app's layer tree draws it:
/// a two-cycle `CAGradientLayer` translated left by `cycleWidth * (time / period mod 1)`,
/// a white sheen overlay, and rounded corners on a black Touch Bar background.
public struct FrameRenderer: Sendable {
    public let style: RainbowStyle
    public let stops: GradientStops
    /// View size in points.
    public let width: Double
    public let height: Double
    /// Pixels per point (the Touch Bar is @2x).
    public let scale: Int

    /// Touch Bar is 1085 x 30 pt. The esc key plus spacing take 72 pt on the left.
    public static let touchBarWidth: Double = 1085
    public static let touchBarHeight: Double = 30
    public static let escKeyReservedWidth: Double = 72

    public init(
        style: RainbowStyle = .default,
        width: Double = FrameRenderer.touchBarWidth - FrameRenderer.escKeyReservedWidth,
        height: Double = FrameRenderer.touchBarHeight,
        scale: Int = 2
    ) {
        self.style = style
        self.stops = GradientStops(style: style)
        self.width = width
        self.height = height
        self.scale = scale
    }

    /// How far (in points) the gradient layer has slid left at `time`.
    public func offset(at time: Double) -> Double {
        let phase = (time / style.period).truncatingRemainder(dividingBy: 1)
        return style.cycleWidth * (phase < 0 ? phase + 1 : phase)
    }

    /// Gradient colour (without sheen) at view x-coordinate `x` in points.
    public func gradientColor(atPoint x: Double, time: Double) -> RGB {
        let layerX = x + offset(at: time)
        return stops.color(at: layerX / (2 * style.cycleWidth))
    }

    /// White sheen alpha at view y-coordinate `y` in points, measured from the top edge.
    public func sheenAlpha(atPoint y: Double) -> Double {
        let depth = style.sheenDepth * height
        guard depth > 0 else { return 0 }
        return style.sheenOpacity * max(0, 1 - y / depth)
    }

    /// Coverage of the rounded-rect mask for the pixel centred at (x, y) points: 1 inside, 0 outside,
    /// with one pixel of anti-aliasing at the corners.
    public func maskCoverage(atPoint x: Double, _ y: Double) -> Double {
        let r = style.cornerRadius
        guard r > 0 else { return 1 }
        let cx = min(max(x, r), width - r)
        let cy = min(max(y, r), height - r)
        let dx = x - cx, dy = y - cy
        let d = (dx * dx + dy * dy).squareRoot()
        let aa = 1 / Double(scale)
        return min(max((r - d) / aa + 0.5, 0), 1)
    }

    public func render(time: Double) -> Image {
        let w = Int(width * Double(scale)), h = Int(height * Double(scale))
        var img = Image(width: w, height: h)
        let s = Double(scale)
        // The gradient is horizontal, so compute one row of colours and reuse it.
        let row: [RGB] = (0..<w).map { px in gradientColor(atPoint: (Double(px) + 0.5) / s, time: time) }
        for py in 0..<h {
            let y = (Double(py) + 0.5) / s
            let sheen = sheenAlpha(atPoint: y)
            for px in 0..<w {
                let x = (Double(px) + 0.5) / s
                let c = row[px].blended(with: .white, alpha: sheen)
                img[px, py] = RGB.black.blended(with: c, alpha: maskCoverage(atPoint: x, y))
            }
        }
        return img
    }
}
