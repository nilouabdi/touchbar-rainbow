# Design

## Visual design

### Palette: the "sinebow"

Three candidate rainbows were rendered at Touch Bar resolution and compared:

| Palette | OKLab lightness range | Lightness std-dev | Verdict |
| --- | --- | --- | --- |
| HSV hue sweep | 0.45 – 0.97 | 0.152 | Harsh: glaring yellow and cyan bands, dark muddy blue |
| OKLCH, constant chroma | 0.75 – 0.75 | ≈0 | Perceptually even but washed-out pastel |
| OKLCH, max in-gamut chroma | 0.60 – 0.82 | 0.06 | Vivid, but the sRGB gamut cusps cause visible kinks at green and blue |
| **Sinebow** | 0.51 – 0.87 | 0.122 | **Vivid, smooth everywhere, no hard bands. Chosen.** |

The sinebow (Charlie Loyd) shifts three squared sine waves by a third of a
period each:

```
r = sin²(π·(½ − t))
g = sin²(π·(½ − t + ⅓))
b = sin²(π·(½ − t + ⅔))
```

It is analytic, periodic with continuous derivatives (so it loops with no seam),
and always in gamut. A global `brightness` factor (default 0.92) takes the edge
off the OLED Touch Bar in a dark room.

### Geometry

* Touch Bar: 2170 × 60 px (1085 × 30 pt @2x).
* One full colour cycle spans the full Touch Bar width (1085 pt), so the
  whole spectrum is always visible exactly once.
* Rounded corners (6 pt) match the system Touch Bar keys.
* A very soft vertical sheen (white, 10 % at the top edge fading to 0 by the
  middle) gives the bar a bit of depth without hiding the colours.
* An `esc` key stays on the left (64 pt) because PyCharm users need it.

### Motion

* The gradient layer is 2 cycles wide and slides left by exactly 1 cycle per
  period, then repeats, so there is never a seam or jump.
* Default period: 6 s (≈180 pt/s, about 3 pt per 60 Hz frame). Calm enough to
  sit in peripheral vision without being distracting.
* Speed presets: Slow (10 s), Normal (6 s), Fast (3 s).

### Gradient stops

`CAGradientLayer` interpolates linearly between stops. The sinebow is sampled
at 24 stops per cycle; the tests check that the linear interpolation never
deviates from the analytic curve by more than ΔE(OKLab) 0.02 (around the
threshold of a just-noticeable difference).

## Software design

```
NSWorkspace notifications ──► FrontAppWatcher ──► DisplayPolicy.shouldShow ──► TouchBarPresenter
                                                         ▲                         │
                                   Settings (UserDefaults)┘                         ▼
                                                                         RainbowTouchBar (NSTouchBar)
                                                                           ├─ esc button
                                                                           └─ RainbowView (CAGradientLayer)
```

* **RainbowCore** (pure Swift, no AppKit)
  * `Sinebow` – the palette function.
  * `RainbowStyle` – brightness, cycle width, period, stops per cycle.
  * `GradientStops` – generates the stop colours and locations for 2 cycles.
  * `FrameRenderer` – rasterises a frame at time *t* exactly the way the layer
    does (linear stop interpolation + translation), used by tests and preview.
  * `OKLab` – colour-science helpers for the visual tests.
  * `AppMatcher` – decides whether a bundle id is PyCharm.
  * `DisplayPolicy` – mode × frontmost app → show / hide.
* **TouchBarPrivate** (Objective-C) – declares the private class methods and
  wraps them in C functions that check availability first; loads
  `DFRFoundation` with `dlopen` so there is no link-time dependency on a
  private framework.
* **TouchBarRainbow** (AppKit) – `AppDelegate`, status-bar menu,
  `TouchBarPresenter`, `RainbowView`.

### Failure modes

* Mac without a Touch Bar: everything still runs, presenting is a no-op.
* Private API missing in a future macOS: `TBRSystemModalTouchBarAvailable()`
  returns `false`, the menu shows "Touch Bar API unavailable".
* esc needs Accessibility permission to post a key event; the app asks for it
  the first time esc is tapped.
