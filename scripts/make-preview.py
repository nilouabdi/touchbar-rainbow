#!/usr/bin/env python3
# Touch Bar Rainbow
# Copyright (C) 2026 nilouabdi
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Turns the PPM frames written by `rainbow-preview` into a mock Touch Bar (black bar, esc key,
# rainbow) and saves a still contact sheet (PNG) and an animated GIF for visual review.
#
#   swift run -c release rainbow-preview build/frames --frames 60 --fps 10
#   python3 scripts/make-preview.py build/frames docs/preview
#
# Requires Pillow (pip install pillow).

import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

BAR_W, BAR_H = 2170, 60          # Touch Bar in pixels (1085 x 30 pt @2x)
ESC_W, GAP = 128, 16             # esc key 64 pt, 8 pt gap
MARGIN = 24                      # dark bezel around the mock bar in the preview


def font(size):
    for path in ("/System/Library/Fonts/SFNS.ttf",
                 "/System/Library/Fonts/Helvetica.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def touch_bar(frame):
    bar = Image.new("RGB", (BAR_W + 2 * MARGIN, BAR_H + 2 * MARGIN), (18, 18, 20))
    d = ImageDraw.Draw(bar)
    d.rounded_rectangle([MARGIN - 6, MARGIN - 6, MARGIN + BAR_W + 5, MARGIN + BAR_H + 5], 14, fill=(0, 0, 0))
    d.rounded_rectangle([MARGIN, MARGIN, MARGIN + ESC_W - 1, MARGIN + BAR_H - 1], 12, fill=(58, 58, 60))
    f = font(26)
    w = d.textlength("esc", font=f)
    d.text((MARGIN + (ESC_W - w) / 2, MARGIN + 14), "esc", font=f, fill=(235, 235, 235))
    bar.paste(frame, (MARGIN + ESC_W + GAP, MARGIN))
    return bar


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: make-preview.py <frames-dir> <output-prefix>")
    frames_dir, out = sys.argv[1], sys.argv[2]
    paths = sorted(glob.glob(os.path.join(frames_dir, "frame-*.ppm")))
    if not paths:
        sys.exit(f"no frame-*.ppm files in {frames_dir}")
    bars = [touch_bar(Image.open(p).convert("RGB")) for p in paths]

    picks = [bars[i * len(bars) // 4] for i in range(4)]
    sheet = Image.new("RGB", (picks[0].width, picks[0].height * 4), (18, 18, 20))
    for i, b in enumerate(picks):
        sheet.paste(b, (0, i * b.height))
    sheet.save(out + ".png")

    # Half-size GIF keeps the file small enough for a README.
    small = [b.resize((b.width // 2, b.height // 2), Image.LANCZOS) for b in bars]
    small[0].save(out + ".gif", save_all=True, append_images=small[1:], duration=100, loop=0, optimize=True)
    print(f"wrote {out}.png and {out}.gif from {len(paths)} frames")


if __name__ == "__main__":
    main()
