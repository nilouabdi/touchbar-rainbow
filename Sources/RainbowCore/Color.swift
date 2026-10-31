// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// An sRGB colour with gamma-encoded components in `0...1`.
public struct RGB: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let black = RGB(0, 0, 0)
    public static let white = RGB(1, 1, 1)

    /// Componentwise linear interpolation, the same maths `CAGradientLayer` uses between stops.
    public static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        RGB(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }

    /// Source-over compositing of `top` with the given alpha onto `self`.
    public func blended(with top: RGB, alpha: Double) -> RGB {
        RGB.lerp(self, top, alpha)
    }

    public func scaled(_ k: Double) -> RGB { RGB(r * k, g * k, b * k) }

    public var clamped: RGB {
        RGB(min(max(r, 0), 1), min(max(g, 0), 1), min(max(b, 0), 1))
    }

    /// 8-bit components, rounded.
    public var bytes: (UInt8, UInt8, UInt8) {
        let c = clamped
        return (UInt8((c.r * 255).rounded()), UInt8((c.g * 255).rounded()), UInt8((c.b * 255).rounded()))
    }
}

/// A colour in the OKLab perceptual colour space (Björn Ottosson, 2020).
public struct OKLab: Equatable, Sendable {
    public var L: Double
    public var a: Double
    public var b: Double

    public init(L: Double, a: Double, b: Double) {
        self.L = L
        self.a = a
        self.b = b
    }

    public var chroma: Double { (a * a + b * b).squareRoot() }

    /// Hue angle in degrees, `0..<360`.
    public var hue: Double {
        let h = atan2(b, a) * 180 / .pi
        return h < 0 ? h + 360 : h
    }

    /// Euclidean distance in OKLab. A difference of ~0.02 is roughly one just-noticeable difference.
    public func distance(to o: OKLab) -> Double {
        let dL = L - o.L, da = a - o.a, db = b - o.b
        return (dL * dL + da * da + db * db).squareRoot()
    }

    public init(_ c: RGB) {
        func linear(_ x: Double) -> Double {
            let x = min(max(x, 0), 1)
            return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        let r = linear(c.r), g = linear(c.g), b = linear(c.b)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        self.L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720320 * s
        self.a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        self.b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }
}
