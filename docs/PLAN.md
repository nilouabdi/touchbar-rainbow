# Plan

## Goal

Show a calm, continuously flowing rainbow on the MacBook Pro Touch Bar while
PyCharm is the frontmost application, and give the Touch Bar back to normal
behaviour as soon as you switch to any other app.

## Constraints

* A third-party app cannot draw into another app's Touch Bar. PyCharm's own
  Touch Bar support (IntelliJ platform) has no plugin hook for custom views.
* macOS has a (private, but long-stable) API that lets a background app present
  a *system-modal* Touch Bar that sits on top of whatever the frontmost app
  shows. This is what MTMR, Pock and similar tools use:
  `+[NSTouchBar presentSystemModalTouchBar:placement:systemTrayItemIdentifier:]`
  and `+[NSTouchBar dismissSystemModalTouchBar:]` (`…FunctionBar…` on 10.13).
* Being private, the API is called defensively: the app checks
  `respondsToSelector:` first and degrades to a no-op instead of crashing.

## Approach

1. **Menu-bar agent app** (`LSUIElement`, no Dock icon) written in Swift.
2. **Front-app watcher**: listens to
   `NSWorkspace.didActivateApplicationNotification` and checks the bundle id
   (`com.jetbrains.pycharm`, `com.jetbrains.pycharm.ce`, EAP builds, plus any
   user-added ids).
3. **Presenter**: when the policy says "show", present a system-modal Touch Bar
   containing an `esc` key and the rainbow view; otherwise dismiss it.
   Re-present after wake from sleep because the Touch Bar server restarts.
4. **Rainbow view**: a `CAGradientLayer` twice as wide as one colour cycle,
   animated with a single repeating `transform.translation.x` animation. The
   GPU does all the work, so CPU usage stays at ~0 %.
5. **Menu**: mode (Only in PyCharm / Always / Off), speed, esc-key toggle,
   launch at login, quit. Settings persist in `UserDefaults`.

## Code layout

| Path | Platform | Purpose |
| --- | --- | --- |
| `Sources/RainbowCore` | any | Palette, gradient maths, frame renderer, app matching, display policy |
| `Sources/rainbow-preview` | any | CLI that renders frames to PPM for visual review / README GIF |
| `Sources/TouchBarPrivate` | macOS | Objective-C shim around the private Touch Bar APIs |
| `Sources/TouchBarRainbow` | macOS | The AppKit menu-bar app |
| `Tests/RainbowCoreTests` | any | Unit tests plus visual quality tests |

Keeping all the maths in a platform-neutral module means the colour, motion and
looping behaviour can be tested (and rendered to images) without a Mac.

## Testing

* **Unit**: bundle-id matching, display policy, settings parsing, palette maths.
* **Visual (quantitative)**: seamless loop (frame at *t* = period equals frame
  at *t* = 0 pixel-for-pixel), no visible banding (max ΔE between adjacent
  pixel columns), gradient-stop interpolation stays within a just-noticeable
  difference of the analytic palette, even perceived brightness, full hue
  coverage, comfortable motion speed.
* **Visual (snapshot)**: `rainbow-preview` renders Touch Bar-sized frames
  (2170 × 60 px) and an animated GIF that are reviewed by eye.
* **CI**: GitHub Actions builds the macOS app and runs the tests on macOS.

## Delivery

* `main`: licence (GPL-3.0) and a README stub.
* `feature/pycharm-rainbow`: the implementation, merged through a pull request.
