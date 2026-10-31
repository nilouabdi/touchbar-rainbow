// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// User settings, persisted in `UserDefaults` (domain `com.nilouabdi.TouchBarRainbow`).
///
/// Everything can also be set from the terminal, e.g.
/// `defaults write com.nilouabdi.TouchBarRainbow extraBundleIDs -array com.jetbrains.intellij`.
public struct Settings: Equatable, Sendable {
    public enum Key {
        public static let mode = "mode"
        public static let speed = "speed"
        public static let showEscKey = "showEscKey"
        public static let brightness = "brightness"
        public static let extraBundleIDs = "extraBundleIDs"
    }

    public var mode: DisplayMode = .pycharmOnly
    public var speed: Speed = .normal
    public var showEscKey: Bool = true
    public var brightness: Double = RainbowStyle.default.brightness
    public var extraBundleIDs: [String] = []

    public init() {}

    public init(defaults: UserDefaults) {
        if let raw = defaults.string(forKey: Key.mode), let m = DisplayMode(rawValue: raw) { mode = m }
        if let raw = defaults.string(forKey: Key.speed), let s = Speed(rawValue: raw) { speed = s }
        if defaults.object(forKey: Key.showEscKey) != nil { showEscKey = defaults.bool(forKey: Key.showEscKey) }
        if defaults.object(forKey: Key.brightness) != nil {
            brightness = min(max(defaults.double(forKey: Key.brightness), 0.2), 1)
        }
        if let ids = defaults.stringArray(forKey: Key.extraBundleIDs) { extraBundleIDs = ids }
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(speed.rawValue, forKey: Key.speed)
        defaults.set(showEscKey, forKey: Key.showEscKey)
        defaults.set(brightness, forKey: Key.brightness)
        defaults.set(extraBundleIDs, forKey: Key.extraBundleIDs)
    }

    public var matcher: AppMatcher { AppMatcher(extraBundleIDs: Set(extraBundleIDs)) }

    public var style: RainbowStyle {
        var s = RainbowStyle.default
        s.period = speed.period
        s.brightness = brightness
        return s
    }
}
