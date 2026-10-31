// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// When the rainbow should be on the Touch Bar.
public enum DisplayMode: String, CaseIterable, Sendable {
    /// Only while PyCharm (or another configured app) is frontmost. The default.
    case pycharmOnly
    /// All the time.
    case always
    /// Never.
    case off

    public var title: String {
        switch self {
        case .pycharmOnly: return "Only in PyCharm"
        case .always: return "Always"
        case .off: return "Off"
        }
    }
}

/// Decides whether a bundle identifier belongs to an app that should get the rainbow.
public struct AppMatcher: Equatable, Sendable {
    /// Every PyCharm edition (Professional `com.jetbrains.pycharm`, Community `com.jetbrains.pycharm.ce`,
    /// EAP builds `com.jetbrains.pycharm-EAP`, …) shares this prefix.
    public static let pycharmPrefix = "com.jetbrains.pycharm"

    public var prefixes: [String]
    public var extraBundleIDs: Set<String>

    public init(prefixes: [String] = [AppMatcher.pycharmPrefix], extraBundleIDs: Set<String> = []) {
        self.prefixes = prefixes
        self.extraBundleIDs = extraBundleIDs
    }

    public func matches(_ bundleID: String?) -> Bool {
        guard let id = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return false
        }
        let lower = id.lowercased()
        if extraBundleIDs.contains(where: { $0.lowercased() == lower }) { return true }
        return prefixes.contains { prefix in
            let p = prefix.lowercased()
            guard lower.hasPrefix(p) else { return false }
            // Match the id itself or a dotted/dashed variant, but not e.g. "com.jetbrains.pycharmfoo".
            if lower.count == p.count { return true }
            let next = lower[lower.index(lower.startIndex, offsetBy: p.count)]
            return next == "." || next == "-"
        }
    }
}

public enum DisplayPolicy {
    public static func shouldShow(mode: DisplayMode, frontmostBundleID: String?, matcher: AppMatcher) -> Bool {
        switch mode {
        case .always: return true
        case .off: return false
        case .pycharmOnly: return matcher.matches(frontmostBundleID)
        }
    }
}
