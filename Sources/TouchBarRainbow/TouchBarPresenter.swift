// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import RainbowCore
import TouchBarPrivate

/// Builds the rainbow Touch Bar and puts it on / takes it off the physical Touch Bar.
@MainActor
final class TouchBarPresenter: NSObject, NSTouchBarDelegate {
    private enum ID {
        static let rainbow = NSTouchBarItem.Identifier("com.nilouabdi.TouchBarRainbow.rainbow")
        static let esc = NSTouchBarItem.Identifier("com.nilouabdi.TouchBarRainbow.esc")
        static let tray = NSTouchBarItem.Identifier("com.nilouabdi.TouchBarRainbow.tray")
    }

    private(set) var isPresented = false
    private var touchBar: NSTouchBar?
    private weak var rainbowView: RainbowView?

    private var style: RainbowStyle = .default
    private var showEscKey = true

    var isAvailable: Bool { TBRSystemModalTouchBarAvailable() }

    /// Applies new settings. Style changes are applied live; adding/removing the esc key rebuilds the bar.
    func configure(style: RainbowStyle, showEscKey: Bool) {
        let rebuild = showEscKey != self.showEscKey
        self.style = style
        self.showEscKey = showEscKey
        rainbowView?.style = style
        if rebuild && isPresented {
            present(force: true)
        }
    }

    /// Shows the rainbow. Calling it again while shown does nothing unless `force` is set
    /// (needed after sleep, when the Touch Bar server may have restarted).
    func present(force: Bool = false) {
        guard isAvailable else { return }
        if isPresented && !force { return }
        if let old = touchBar {
            TBRDismissSystemModalTouchBar(old)
        }
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = showEscKey ? [ID.esc, ID.rainbow] : [ID.rainbow]
        TBRSetShowsCloseBox(false)
        TBRPresentSystemModalTouchBar(bar, true, ID.tray)
        touchBar = bar
        isPresented = true
    }

    func dismiss() {
        guard let bar = touchBar else { return }
        TBRDismissSystemModalTouchBar(bar)
        touchBar = nil
        isPresented = false
    }

    // MARK: NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case ID.esc:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "esc", target: self, action: #selector(escPressed))
            button.widthAnchor.constraint(equalToConstant: 64).isActive = true
            item.view = button
            item.visibilityPriority = .high
            return item
        case ID.rainbow:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let view = RainbowView(style: style)
            view.translatesAutoresizingMaskIntoConstraints = false
            // Take all the space the Touch Bar offers, but never more than one colour cycle
            // (the gradient layer is two cycles wide and slides by one).
            let maxWidth = view.widthAnchor.constraint(lessThanOrEqualToConstant: CGFloat(style.cycleWidth))
            let minWidth = view.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
            let fill = view.widthAnchor.constraint(equalToConstant: CGFloat(style.cycleWidth))
            fill.priority = .defaultLow
            NSLayoutConstraint.activate([maxWidth, minWidth, fill])
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            item.view = view
            item.visibilityPriority = .high
            rainbowView = view
            return item
        default:
            return nil
        }
    }

    // MARK: esc

    /// Sends a real Escape key press to the frontmost app (PyCharm). Posting key events needs the
    /// Accessibility permission; macOS shows its permission prompt the first time.
    @objc private func escPressed() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }
        let escKeyCode: CGKeyCode = 0x35
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: escKeyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: escKeyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
