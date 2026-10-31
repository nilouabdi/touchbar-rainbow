// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest
@testable import RainbowCore

final class DisplayPolicyTests: XCTestCase {
    let matcher = AppMatcher()

    func testMatchesAllPyCharmEditions() {
        XCTAssertTrue(matcher.matches("com.jetbrains.pycharm"))
        XCTAssertTrue(matcher.matches("com.jetbrains.pycharm.ce"))
        XCTAssertTrue(matcher.matches("com.jetbrains.pycharm-EAP"))
        XCTAssertTrue(matcher.matches("COM.JetBrains.PyCharm"))
    }

    func testDoesNotMatchOtherApps() {
        XCTAssertFalse(matcher.matches(nil))
        XCTAssertFalse(matcher.matches(""))
        XCTAssertFalse(matcher.matches("com.jetbrains.intellij"))
        XCTAssertFalse(matcher.matches("com.microsoft.VSCode"))
        XCTAssertFalse(matcher.matches("com.jetbrains.pycharmish"))
        XCTAssertFalse(matcher.matches("org.example.com.jetbrains.pycharm"))
    }

    func testExtraBundleIDs() {
        let m = AppMatcher(extraBundleIDs: ["com.jetbrains.intellij"])
        XCTAssertTrue(m.matches("com.jetbrains.intellij"))
        XCTAssertTrue(m.matches("com.jetbrains.pycharm"))
        XCTAssertFalse(m.matches("com.jetbrains.goland"))
    }

    func testPolicy() {
        XCTAssertTrue(DisplayPolicy.shouldShow(mode: .pycharmOnly, frontmostBundleID: "com.jetbrains.pycharm.ce", matcher: matcher))
        XCTAssertFalse(DisplayPolicy.shouldShow(mode: .pycharmOnly, frontmostBundleID: "com.apple.Safari", matcher: matcher))
        XCTAssertTrue(DisplayPolicy.shouldShow(mode: .always, frontmostBundleID: "com.apple.Safari", matcher: matcher))
        XCTAssertFalse(DisplayPolicy.shouldShow(mode: .off, frontmostBundleID: "com.jetbrains.pycharm", matcher: matcher))
    }

    func testSettingsRoundTrip() throws {
        let suite = "TouchBarRainbowTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(Settings(defaults: defaults), Settings(), "empty defaults give the default settings")

        var s = Settings()
        s.mode = .always
        s.speed = .fast
        s.showEscKey = false
        s.brightness = 0.7
        s.extraBundleIDs = ["com.jetbrains.goland"]
        s.save(to: defaults)
        XCTAssertEqual(Settings(defaults: defaults), s)
        XCTAssertEqual(s.style.period, Speed.fast.period)
        XCTAssertTrue(s.matcher.matches("com.jetbrains.goland"))
    }

    func testSettingsIgnoreGarbage() throws {
        let suite = "TouchBarRainbowTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("sideways", forKey: Settings.Key.mode)
        defaults.set("ludicrous", forKey: Settings.Key.speed)
        defaults.set(42.0, forKey: Settings.Key.brightness)
        let s = Settings(defaults: defaults)
        XCTAssertEqual(s.mode, .pycharmOnly)
        XCTAssertEqual(s.speed, .normal)
        XCTAssertEqual(s.brightness, 1, "brightness is clamped")
    }
}
