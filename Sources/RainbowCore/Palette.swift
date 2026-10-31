// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The "sinebow" palette: three squared sine waves a third of a period apart.
///
/// It is vivid, always inside the sRGB gamut, and smooth (C-infinity) all the way round,
/// which is what makes the animation loop without a visible seam. See `docs/DESIGN.md`
/// for the comparison with HSV and OKLCH rainbows.
public enum Sinebow {
    /// Colour at position `t` along one cycle. Periodic with period 1, so any real `t` is valid.
    public static func color(at t: Double) -> RGB {
        let x = 0.5 - t
        func channel(_ phase: Double) -> Double {
            let s = sin(.pi * (x + phase))
            return s * s
        }
        return RGB(channel(0), channel(1.0 / 3.0), channel(2.0 / 3.0))
    }
}

/// Visual parameters of the rainbow. Everything that affects the look lives here so the app,
/// the preview tool and the tests all render exactly the same thing.
public struct RainbowStyle: Equatable, Sendable {
    /// Global brightness multiplier, `0...1`. Slightly below 1 so the OLED is not glaring.
    public var brightness: Double
    /// Width of one full colour cycle in points.
    public var cycleWidth: Double
    /// Seconds it takes the rainbow to move by one cycle.
    public var period: Double
    /// Number of gradient stops per cycle handed to `CAGradientLayer`.
    public var stopsPerCycle: Int
    /// Opacity of the white sheen at the top edge (fades to 0 at `sheenDepth`).
    public var sheenOpacity: Double
    /// Fraction of the height (from the top) over which the sheen fades out.
    public var sheenDepth: Double
    /// Corner radius in points.
    public var cornerRadius: Double

    public init(
        brightness: Double = 0.92,
        cycleWidth: Double = 1085,
        period: Double = Speed.normal.period,
        stopsPerCycle: Int = 24,
        sheenOpacity: Double = 0.10,
        sheenDepth: Double = 0.5,
        cornerRadius: Double = 6
    ) {
        self.brightness = brightness
        self.cycleWidth = cycleWidth
        self.period = period
        self.stopsPerCycle = stopsPerCycle
        self.sheenOpacity = sheenOpacity
        self.sheenDepth = sheenDepth
        self.cornerRadius = cornerRadius
    }

    public static let `default` = RainbowStyle()

    /// Horizontal speed in points per second.
    public var pointsPerSecond: Double { cycleWidth / period }

    /// The palette colour (with brightness applied) at position `t` in cycles.
    public func paletteColor(at t: Double) -> RGB {
        Sinebow.color(at: t).scaled(brightness)
    }
}

/// Animation speed presets offered in the menu.
public enum Speed: String, CaseIterable, Sendable {
    case slow
    case normal
    case fast

    public var period: Double {
        switch self {
        case .slow: return 10
        case .normal: return 6
        case .fast: return 3
        }
    }

    public var title: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }
}

/// Gradient stops for a layer that is exactly two cycles wide.
///
/// Sliding such a layer left by one cycle and then snapping back is invisible, because the
/// second cycle is identical to the first.
public struct GradientStops: Equatable, Sendable {
    public let colors: [RGB]
    /// Stop locations in `0...1` across the full (two-cycle) layer width.
    public let locations: [Double]

    public init(style: RainbowStyle, cycles: Int = 2) {
        precondition(style.stopsPerCycle >= 2 && cycles >= 1)
        let count = style.stopsPerCycle * cycles
        var colors: [RGB] = []
        var locations: [Double] = []
        colors.reserveCapacity(count + 1)
        locations.reserveCapacity(count + 1)
        for i in 0...count {
            let t = Double(i) / Double(style.stopsPerCycle)
            colors.append(style.paletteColor(at: t))
            locations.append(Double(i) / Double(count))
        }
        self.colors = colors
        self.locations = locations
    }

    /// Colour at `u` in `0...1` across the layer, interpolated linearly between stops
    /// the way `CAGradientLayer` does.
    public func color(at u: Double) -> RGB {
        if u <= locations[0] { return colors[0] }
        if u >= locations[locations.count - 1] { return colors[colors.count - 1] }
        // Stops are evenly spaced, so the segment can be found directly.
        let segments = Double(locations.count - 1)
        let i = min(Int(u * segments), locations.count - 2)
        let local = (u - locations[i]) / (locations[i + 1] - locations[i])
        return RGB.lerp(colors[i], colors[i + 1], local)
    }
}
