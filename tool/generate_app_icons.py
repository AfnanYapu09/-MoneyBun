#!/usr/bin/env python3
"""Generate MoneyBun launcher-icon and native-splash assets from the pixel "Bun".

The Bun mascot is the 14-col x 15-row grid mirrored from lib/core/widgets/bun_avatar.dart
(design_files/bun.jsx BUN_MAP). 'X'=body, 'K'=eye, 'N'=nose/cheek shadow, '.'=empty.

We render directly to PNG (this environment has no Flutter toolchain, so
flutter_launcher_icons / flutter_native_splash can't run). Re-run after changing the grid
or colors:  python3 tool/generate_app_icons.py
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BUN_MAP = [
    "...XX....XX...",
    "...XX....XX...",
    "...XX.XX.XX...",
    "..XXXXXXXXXX..",
    ".XXXXXXXXXXXX.",
    "XXXXXXXXXXXXXX",
    "XXXKKXXXXKKXXX",
    "XXXKKXXXXKKXXX",
    "XXXXXXXXXXXXXX",
    "XXXXXXNNXXXXXX",
    "XXXXXXXXXXXXXX",
    ".XXXXXXXXXXXX.",
    ".XXXXXXXXXXXX.",
    ".XX.XX..XX.XX.",
    ".XX.XX..XX.XX.",
]
COLS = 14
ROWS = len(BUN_MAP)  # 15

TERRA = (0xC4, 0x69, 0x4A, 255)
TERRA_DEEP = (0xA9, 0x54, 0x3A, 255)
INK = (0x21, 0x1C, 0x18, 255)
CREAM = (0xF1, 0xEE, 0xE4, 255)
REVERSE = (0xFB, 0xF4, 0xEE, 255)


def draw_bun(img, box, body, eye, nose):
    """Draw the Bun pixel grid into box=(x,y,w,h) on RGBA image `img`."""
    d = ImageDraw.Draw(img)
    x0, y0, w, h = box
    cw = w / COLS
    ch = h / ROWS
    for r, row in enumerate(BUN_MAP):
        for c, ch_ in enumerate(row):
            if ch_ == ".":
                continue
            color = eye if ch_ == "K" else (nose if ch_ == "N" else body)
            px0 = x0 + round(c * cw)
            py0 = y0 + round(r * ch)
            px1 = max(px0 + 1, x0 + round((c + 1) * cw))
            py1 = max(py0 + 1, y0 + round((r + 1) * ch))
            d.rectangle([px0, py0, px1 - 1, py1 - 1], fill=color)


def bun_box(size, frac):
    """Centered box for a Bun that is `frac` of `size` wide (grid is 14x15)."""
    bw = size * frac
    bh = bw * ROWS / COLS
    return (round((size - bw) / 2), round((size - bh) / 2), round(bw), round(bh))


def make_tile_icon(size, bun_frac=0.56, radius_frac=0.22, opaque=False):
    """Cream rounded tile + orange Bun. opaque=True fills a cream square (iOS, no alpha)."""
    if opaque:
        img = Image.new("RGBA", (size, size), CREAM)
    else:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        r = round(size * radius_frac)
        d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=CREAM)
    draw_bun(img, bun_box(size, bun_frac), TERRA, INK, TERRA_DEEP)
    return img


def make_adaptive_foreground(size, bun_frac=0.42):
    """Bun on transparent, sized for the adaptive-icon safe zone (~66/108)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_bun(img, bun_box(size, bun_frac), TERRA, INK, TERRA_DEEP)
    return img


def make_splash_logo(size, bun_frac=0.62, radius_frac=0.25):
    """Cream rounded tile + orange Bun on transparent (centered on terra at runtime)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = round(size * radius_frac)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=CREAM)
    draw_bun(img, bun_box(size, bun_frac), TERRA, INK, TERRA_DEEP)
    return img


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT), img.size)


def main():
    # 1024 source (cream tile, transparent corners) + reference asset.
    save(make_tile_icon(1024), "assets", "icon", "app_icon.png")
    save(make_adaptive_foreground(1024, 0.42), "assets", "icon", "app_icon_foreground.png")

    # Android legacy mipmaps (rounded cream tile on transparent).
    android_mipmaps = {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
    }
    for d, px in android_mipmaps.items():
        save(make_tile_icon(px), "android", "app", "src", "main", "res",
             f"mipmap-{d}", "ic_launcher.png")

    # Android adaptive foreground (108dp @ each density; safe-zone Bun on transparent).
    fg_sizes = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for d, px in fg_sizes.items():
        save(make_adaptive_foreground(px), "android", "app", "src", "main", "res",
             f"mipmap-{d}", "ic_launcher_foreground.png")

    # Android native splash logo (drawable-density).
    splash_sizes = {"mdpi": 192, "hdpi": 288, "xhdpi": 384, "xxhdpi": 576, "xxxhdpi": 768}
    for d, px in splash_sizes.items():
        save(make_splash_logo(px), "android", "app", "src", "main", "res",
             f"drawable-{d}", "splash_logo.png")
    save(make_splash_logo(384), "android", "app", "src", "main", "res",
         "drawable", "splash_logo.png")

    # iOS app icons (opaque cream square; OS masks corners). Filenames match Contents.json.
    ios = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, px in ios.items():
        img = make_tile_icon(px, opaque=True)
        if name.endswith("1024x1024@1x.png"):
            img = img.convert("RGB")  # marketing icon must have no alpha
        save(img, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", name)

    # iOS launch image (splash logo on transparent; storyboard sets terra bg).
    for name, px in {"LaunchImage.png": 220, "LaunchImage@2x.png": 440,
                     "LaunchImage@3x.png": 660}.items():
        save(make_splash_logo(px), "ios", "Runner", "Assets.xcassets",
             "LaunchImage.imageset", name)


if __name__ == "__main__":
    main()
