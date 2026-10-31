// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Visual tests: they check, numerically, the properties that make the rainbow pleasant to look at
// (smoothness, no seams, no banding, balanced brightness, calm motion). Set RAINBOW_SNAPSHOT_DIR
// to also write Touch Bar-sized PPM snapshots for review by eye.

import Foundation
import XCTest
@testable import RainbowCore

final class VisualQualityTests: XCTestCase {
    let style = RainbowStyle.default
    lazy var renderer = FrameRenderer(style: style)

    /// About one just-noticeable difference in OKLab.
    let jnd = 0.02

    private func samples(_ n: Int, _ f: (Double) -> RGB) -> [OKLab] {
        (0..<n).map { OKLab(f(Double($0) / Double(n))) }
    }

    // MARK: Seamless looping

    func testPaletteIsPeriodic() {
        for t in stride(from: 0.0, to: 1.0, by: 0.01) {
            XCTAssertLessThan(OKLab(Sinebow.color(at: t)).distance(to: OKLab(Sinebow.color(at: t + 1))), 1e-9)
            XCTAssertLessThan(OKLab(Sinebow.color(at: t)).distance(to: OKLab(Sinebow.color(at: t - 3))), 1e-9)
        }
    }

    func testAnimationLoopsWithoutSeam() {
        let first = renderer.render(time: 0)
        XCTAssertEqual(first, renderer.render(time: style.period), "frame at one period must equal frame at 0")
        XCTAssertEqual(first, renderer.render(time: 5 * style.period))
        // Just before the wrap the picture must be almost identical to the first frame, i.e. no jump.
        let almost = renderer.render(time: style.period - 1.0 / 120)
        let maxDiff = zip(first.pixels, almost.pixels).map { OKLab($0).distance(to: OKLab($1)) }.max() ?? 0
        XCTAssertLessThan(maxDiff, jnd, "the step into the wrap must be no bigger than a normal frame step")
    }

    func testTwoCycleLayerRepeatsExactly() {
        let stops = GradientStops(style: style)
        for i in 0...200 {
            let u = Double(i) / 400 // first cycle
            XCTAssertLessThan(OKLab(stops.color(at: u)).distance(to: OKLab(stops.color(at: u + 0.5))), 1e-9)
        }
    }

    func testVisibleAreaNeverRunsOffTheLayer() {
        // The layer is 2 cycles wide and moves by at most one cycle, so the view must fit in one cycle.
        XCTAssertLessThanOrEqual(renderer.width, style.cycleWidth)
        XCTAssertLessThanOrEqual(FrameRenderer.touchBarWidth, style.cycleWidth, "even without esc the bar is covered")
    }

    // MARK: Smoothness

    func testNoVisibleBandingBetweenNeighbouringPixels() {
        let frame = renderer.render(time: 1.234)
        let y = frame.height / 2
        var worst = 0.0
        for x in 1..<frame.width {
            worst = max(worst, OKLab(frame[x - 1, y]).distance(to: OKLab(frame[x, y])))
        }
        XCTAssertLessThan(worst, jnd / 2, "adjacent pixels must be indistinguishable (worst ΔE \(worst))")
    }

    func testGradientStopsTrackThePaletteClosely() {
        let stops = GradientStops(style: style)
        var worst = 0.0
        for i in 0..<4000 {
            let u = Double(i) / 4000 * 0.5 // one cycle
            let analytic = style.paletteColor(at: u * 2)
            worst = max(worst, OKLab(stops.color(at: u)).distance(to: OKLab(analytic)))
        }
        XCTAssertLessThan(worst, jnd, "24 linear stops per cycle must look like the smooth curve (worst ΔE \(worst))")
    }

    func testNoKinksInTheColourPath() {
        // A kink (e.g. from sRGB gamut clipping) shows up as a sudden change of direction of the colour path.
        let n = 720
        let pts = samples(n) { style.paletteColor(at: $0) }
        var worstAngle = 0.0
        for i in 0..<n {
            let a = pts[i], b = pts[(i + 1) % n], c = pts[(i + 2) % n]
            let d1 = (b.L - a.L, b.a - a.a, b.b - a.b)
            let d2 = (c.L - b.L, c.a - b.a, c.b - b.b)
            let dot = d1.0 * d2.0 + d1.1 * d2.1 + d1.2 * d2.2
            let n1 = (d1.0 * d1.0 + d1.1 * d1.1 + d1.2 * d1.2).squareRoot()
            let n2 = (d2.0 * d2.0 + d2.1 * d2.1 + d2.2 * d2.2).squareRoot()
            let angle = acos(min(max(dot / (n1 * n2), -1), 1)) * 180 / .pi
            worstAngle = max(worstAngle, angle)
        }
        XCTAssertLessThan(worstAngle, 12, "colour path turns by \(worstAngle)° between samples")
    }

    // MARK: Colour balance

    func testCoversTheWholeHueCircle() {
        let hues = samples(360) { style.paletteColor(at: $0) }.map(\.hue)
        for sector in 0..<12 {
            let lo = Double(sector) * 30, hi = lo + 30
            XCTAssertTrue(hues.contains { $0 >= lo && $0 < hi }, "no colour with hue in \(lo)..<\(hi)°")
        }
    }

    func testStaysVividEverywhere() {
        // Reference points (OKLab chroma): a washed-out constant-chroma OKLCH rainbow averages 0.125,
        // an HSV rainbow averages 0.25 and dips to 0.145 at cyan, grey is ~0.
        let chroma = samples(360) { style.paletteColor(at: $0) }.map(\.chroma)
        let mean = chroma.reduce(0, +) / Double(chroma.count)
        XCTAssertGreaterThan(mean, 0.18, "vivid overall, not pastel (mean chroma \(mean))")
        XCTAssertGreaterThan(chroma.min() ?? 0, 0.10, "no greyish stretches (min chroma \(chroma.min() ?? 0))")
    }

    func testBrightnessIsMoreEvenThanAnHSVRainbow() {
        func hsv(_ t: Double) -> RGB {
            let h = t * 6, i = Int(h) % 6, f = h - floor(h)
            switch i {
            case 0: return RGB(1, f, 0)
            case 1: return RGB(1 - f, 1, 0)
            case 2: return RGB(0, 1, f)
            case 3: return RGB(0, 1 - f, 1)
            case 4: return RGB(f, 0, 1)
            default: return RGB(1, 0, 1 - f)
            }
        }
        func stddev(_ xs: [Double]) -> Double {
            let m = xs.reduce(0, +) / Double(xs.count)
            return (xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(xs.count)).squareRoot()
        }
        let ours = stddev(samples(360) { style.paletteColor(at: $0) }.map(\.L))
        let naive = stddev(samples(360, hsv).map(\.L))
        XCTAssertLessThan(ours, naive * 0.85, "lightness std-dev \(ours) vs HSV \(naive)")
        let ls = samples(360) { style.paletteColor(at: $0) }.map(\.L)
        XCTAssertLessThan(ls.max() ?? 1, 0.88, "no glaring highlights")
        XCTAssertGreaterThan(ls.min() ?? 0, 0.45, "no muddy dark patches")
    }

    func testSheenIsSubtleAndOnlyOnTop() {
        let frame = renderer.render(time: 0)
        let x = frame.width / 2
        let top = OKLab(frame[x, 1]), middle = OKLab(frame[x, frame.height / 2]), bottom = OKLab(frame[x, frame.height - 2])
        let base = OKLab(renderer.gradientColor(atPoint: (Double(x) + 0.5) / 2, time: 0))
        XCTAssertGreaterThan(top.L, base.L, "the sheen brightens the top edge")
        XCTAssertLessThan(top.distance(to: base), 0.08, "…but only slightly")
        XCTAssertLessThan(middle.distance(to: base), 0.005)
        XCTAssertLessThan(bottom.distance(to: base), 0.005)
    }

    func testCornersAreRounded() {
        let frame = renderer.render(time: 0)
        XCTAssertEqual(frame.width, 2026)
        XCTAssertEqual(frame.height, 60)
        for (x, y) in [(0, 0), (frame.width - 1, 0), (0, frame.height - 1), (frame.width - 1, frame.height - 1)] {
            XCTAssertEqual(frame[x, y], .black, "corner (\(x), \(y)) is outside the rounded rect")
        }
        XCTAssertNotEqual(frame[frame.width / 2, 0], .black, "the top edge itself is filled")
    }

    // MARK: Motion

    func testMotionIsCalmAtEverySpeed() {
        for speed in Speed.allCases {
            var s = style
            s.period = speed.period
            let perFrame = s.pointsPerSecond / 60
            XCTAssertGreaterThan(perFrame, 1, "\(speed) should visibly flow")
            XCTAssertLessThan(perFrame, 8, "\(speed) should not strobe (\(perFrame) pt per frame)")
            // Each pixel's colour should change gradually from one 60 Hz frame to the next.
            let r = FrameRenderer(style: s)
            let a = r.render(time: 0.5), b = r.render(time: 0.5 + 1.0 / 60)
            let worst = zip(a.pixels, b.pixels).map { OKLab($0).distance(to: OKLab($1)) }.max() ?? 0
            XCTAssertLessThan(worst, 0.06, "\(speed): per-frame colour change \(worst)")
        }
    }

    // MARK: Snapshots

    func testWriteSnapshotsForReview() throws {
        guard let dir = ProcessInfo.processInfo.environment["RAINBOW_SNAPSHOT_DIR"] else {
            throw XCTSkip("set RAINBOW_SNAPSHOT_DIR to write snapshot images")
        }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (i, t) in [0.0, 1.5, 3.0, 4.5].enumerated() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("snapshot-\(i).ppm")
            try renderer.render(time: t).ppmData().write(to: url)
        }
    }
}
