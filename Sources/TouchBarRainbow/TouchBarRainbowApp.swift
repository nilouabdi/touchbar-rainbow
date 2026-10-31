// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

@main
enum TouchBarRainbowApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar only: no Dock icon, never steals focus from PyCharm.
        app.setActivationPolicy(.accessory)
        // NSApplication.delegate is weak, so keep the delegate alive for the app's lifetime.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
