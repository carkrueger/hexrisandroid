#!/usr/bin/env python3
"""Renders the Hexris launcher-icon source images and Android resources.

The iOS icon (ios/Runner/Assets.xcassets/AppIcon.appiconset/
Icon-App-1024x1024@1x.png) is an opaque RGB image with a baked-in rounded
corner, so it can't be used directly as an Android adaptive-icon foreground.
This script redraws the same 19-cell hex cluster as vector shapes (cell colours
are sampled from the iOS icon) and writes:

  assets/icon/icon.png         1024px legacy icon (rounded square, transparent corners)
  assets/icon/foreground.png   1024px adaptive foreground, cluster inside the 66/108 safe zone
  assets/icon/monochrome.png   1024px Android 13 themed-icon mask

and the Android resources that flutter_launcher_icons would generate from them
(mipmap-*/ic_launcher.png, drawable-*/ic_launcher_foreground.png,
drawable-*/ic_launcher_monochrome.png). Run from the repo root:

  python3 tool/generate_icon_sources.py

Requires Pillow. The flutter_launcher_icons config in pubspec.yaml points at the
same source images, so `dart run flutter_launcher_icons` gives equivalent output.
"""

import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_ICON = os.path.join(
    ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
)
ICON_DIR = os.path.join(ROOT, "assets/icon")
RES_DIR = os.path.join(ROOT, "android/app/src/main/res")

BACKGROUND = (0x2D, 0x2D, 0x2D)  # GameColors.background
EMPTY_CELL = (0x4A, 0x4A, 0x4A)  # GameColors.emptyCell

# Geometry of the iOS icon, measured from the 1024px source: pointy-top hexes on
# an axial grid of radius 2, centre-to-centre spacing unit 88px, cluster centre
# at (512, 532), drawn hex radius 84.5px (leaves the dark gap lines).
IOS_CENTER = (512.0, 532.0)
IOS_SPACING = 88.0
CELL_FILL = 84.5 / 88.0  # drawn radius / spacing

SS = 4  # supersampling factor for anti-aliasing

LEGACY_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE_SIZES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def cells():
    for q in range(-2, 3):
        for r in range(-2, 3):
            if abs(q + r) <= 2:
                yield q, r


def axial_to_px(q, r, spacing, center):
    x = spacing * math.sqrt(3) * (q + r / 2)
    y = spacing * 1.5 * r
    return center[0] + x, center[1] + y


def hex_points(cx, cy, radius):
    # Pointy-top: vertices at 30°, 90°, ... measured from the x axis.
    return [
        (cx + radius * math.cos(math.radians(60 * i - 30)),
         cy + radius * math.sin(math.radians(60 * i - 30)))
        for i in range(6)
    ]


def sample_colours():
    src = Image.open(IOS_ICON).convert("RGB")
    colours = {}
    for q, r in cells():
        x, y = axial_to_px(q, r, IOS_SPACING, IOS_CENTER)
        colours[(q, r)] = src.getpixel((int(round(x)), int(round(y))))
    return colours


def cluster_extent():
    """Max distance from the cluster centre to any hex vertex, in spacing units."""
    best = 0.0
    for q, r in cells():
        x, y = axial_to_px(q, r, 1.0, (0.0, 0.0))
        for px, py in hex_points(x, y, CELL_FILL):
            best = max(best, math.hypot(px, py))
    return best


def is_empty(colour):
    return all(abs(a - b) <= 12 for a, b in zip(colour, EMPTY_CELL))


def draw_cluster(draw, size, spacing, colours, mode):
    centre = (size / 2, size / 2)
    for q, r in cells():
        x, y = axial_to_px(q, r, spacing, centre)
        colour = colours[(q, r)]
        if mode == "colour":
            fill = colour + (255,)
        else:  # monochrome: alpha carries the shape, empty cells are dimmer
            fill = (255, 255, 255, 110 if is_empty(colour) else 255)
        draw.polygon(hex_points(x, y, spacing * CELL_FILL), fill=fill)


def render(size, spacing_fraction, colours, mode, rounded_bg=False):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if rounded_bg:
        draw.rounded_rectangle(
            (0, 0, big - 1, big - 1), radius=int(big * 0.225), fill=BACKGROUND + (255,)
        )
    draw_cluster(draw, big, big * spacing_fraction, colours, mode)
    return img.resize((size, size), Image.LANCZOS)


def main():
    colours = sample_colours()
    extent = cluster_extent()

    # Legacy icon: same proportions as the iOS icon (cluster spacing 88/1024),
    # recentred so it sits in the middle of the rounded square.
    legacy_spacing = IOS_SPACING / 1024.0
    # Adaptive foreground: the whole cluster must fit inside the 66dp safe-zone
    # circle of the 108dp canvas (radius 33/108), with a 2% margin.
    adaptive_spacing = (33.0 / 108.0) * 0.98 / extent

    os.makedirs(ICON_DIR, exist_ok=True)
    render(1024, legacy_spacing, colours, "colour", rounded_bg=True).save(
        os.path.join(ICON_DIR, "icon.png"), optimize=True)
    render(1024, adaptive_spacing, colours, "colour").save(
        os.path.join(ICON_DIR, "foreground.png"), optimize=True)
    render(1024, adaptive_spacing, colours, "mono").save(
        os.path.join(ICON_DIR, "monochrome.png"), optimize=True)

    for dpi, px in LEGACY_SIZES.items():
        out = os.path.join(RES_DIR, f"mipmap-{dpi}")
        os.makedirs(out, exist_ok=True)
        render(px, legacy_spacing, colours, "colour", rounded_bg=True).save(
            os.path.join(out, "ic_launcher.png"), optimize=True)

    for dpi, px in ADAPTIVE_SIZES.items():
        out = os.path.join(RES_DIR, f"drawable-{dpi}")
        os.makedirs(out, exist_ok=True)
        render(px, adaptive_spacing, colours, "colour").save(
            os.path.join(out, "ic_launcher_foreground.png"), optimize=True)
        render(px, adaptive_spacing, colours, "mono").save(
            os.path.join(out, "ic_launcher_monochrome.png"), optimize=True)

    print(f"cluster extent {extent:.3f} spacing units; colours: {colours}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
