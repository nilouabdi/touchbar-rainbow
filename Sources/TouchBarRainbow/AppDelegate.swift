// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import RainbowCore
import ServiceManagement

/// Watches which app is frontmost, shows the rainbow while PyCharm is, and owns the menu-bar menu.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults.standard
    private lazy var settings = Settings(defaults: defaults)
    private let presenter = TouchBarPresenter()
    private var statusItem: NSStatusItem?
    private var frontmostBundleID: String?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        presenter.configure(style: settings.style, showEscKey: settings.showEscKey)
        setUpStatusItem()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appDidActivate(_:)),
                           name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(systemDidWake(_:)),
                           name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(systemDidWake(_:)),
                           name: NSWorkspace.screensDidWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionDidBecomeActive(_:)),
                           name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        presenter.dismiss()
    }

    // MARK: Notifications

    @objc private func appDidActivate(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        // Opening our own menu must not hide the rainbow.
        guard app?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        frontmostBundleID = app?.bundleIdentifier
        refresh()
    }

    @objc private func systemDidWake(_ note: Notification) {
        // The Touch Bar server can restart while asleep and forget system-modal bars.
        refresh(force: true)
    }

    @objc private func sessionDidBecomeActive(_ note: Notification) {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        refresh(force: true)
    }

    private func refresh(force: Bool = false) {
        let show = DisplayPolicy.shouldShow(mode: settings.mode, frontmostBundleID: frontmostBundleID,
                                            matcher: settings.matcher)
        if show {
            presenter.present(force: force)
        } else {
            presenter.dismiss()
        }
        rebuildMenu()
    }

    // MARK: Settings

    private func update(_ change: (inout Settings) -> Void) {
        change(&settings)
        settings.save(to: defaults)
        presenter.configure(style: settings.style, showEscKey: settings.showEscKey)
        refresh()
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = DisplayMode(rawValue: raw) else { return }
        update { $0.mode = mode }
    }

    @objc private func selectSpeed(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let speed = Speed(rawValue: raw) else { return }
        update { $0.speed = speed }
    }

    @objc private func toggleEscKey(_ sender: NSMenuItem) {
        update { $0.showEscKey.toggle() }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("TouchBarRainbow: could not change launch-at-login: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    // MARK: Menu

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if #available(macOS 12.0, *),
               let image = NSImage(systemSymbolName: "rainbow", accessibilityDescription: "Touch Bar Rainbow") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "🌈"
            }
            button.toolTip = "Touch Bar Rainbow"
        }
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let title = NSMenuItem(title: "Touch Bar Rainbow", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = settings.mode == mode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let speedMenu = NSMenu()
        for speed in Speed.allCases {
            let item = NSMenuItem(title: speed.title, action: #selector(selectSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = speed.rawValue
            item.state = settings.speed == speed ? .on : .off
            speedMenu.addItem(item)
        }
        let speedItem = NSMenuItem(title: "Speed", action: nil, keyEquivalent: "")
        speedItem.submenu = speedMenu
        menu.addItem(speedItem)

        let esc = NSMenuItem(title: "Show esc Key", action: #selector(toggleEscKey(_:)), keyEquivalent: "")
        esc.target = self
        esc.state = settings.showEscKey ? .on : .off
        menu.addItem(esc)

        if #available(macOS 13.0, *) {
            let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Touch Bar Rainbow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private var statusText: String {
        if !presenter.isAvailable { return "Touch Bar API unavailable on this Mac" }
        if presenter.isPresented { return "Showing the rainbow" }
        switch settings.mode {
        case .off: return "Turned off"
        case .always, .pycharmOnly: return "Waiting for PyCharm"
        }
    }
}
