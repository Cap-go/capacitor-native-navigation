#!/usr/bin/env python3
"""Render PR #83 tab bar before/after PNGs (main LTR vs layoutDirection rtl)."""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
WIDTH, HEIGHT = 390, 844
TAB_H = 72
MARGIN_X = 20


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw_phone(draw: ImageDraw.ImageDraw, platform: str) -> None:
    draw.rectangle((0, 0, WIDTH, HEIGHT), fill="#f2f2f7")
    draw.rectangle((0, 0, WIDTH, 44), fill="#ffffff")
    draw.text((16, 14), platform, fill="#111111", font=load_font(14))


def draw_tabbar(
    draw: ImageDraw.ImageDraw,
    tabs: list[str],
    selected: int,
    subtitle: str,
    rtl: bool,
) -> None:
    top = HEIGHT - TAB_H - 24
    left = MARGIN_X
    right = WIDTH - MARGIN_X
    draw.rounded_rectangle((left, top, right, top + TAB_H), radius=28, fill="#ffffff", outline="#d1d1d6", width=2)
    slot_w = (right - left) / len(tabs)
    for index, label in enumerate(tabs):
        visual_index = len(tabs) - 1 - index if rtl else index
        cx = left + slot_w * visual_index + slot_w / 2
        color = "#007aff" if index == selected else "#8e8e93"
        draw.ellipse((cx - 10, top + 12, cx + 10, top + 32), outline=color, width=2)
        draw.text((cx - 18, top + 38), label, fill=color, font=load_font(13))
    draw.text((16, top - 28), subtitle, fill="#333333", font=load_font(13))


def save(name: str, platform: str, tabs: list[str], rtl: bool, subtitle: str) -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), "#f2f2f7")
    draw = ImageDraw.Draw(image)
    draw_phone(draw, platform)
    draw.text((16, 72), "Tabs array: [Home, Ship, Profile]", fill="#555555", font=load_font(12))
    draw_tabbar(draw, tabs, selected=0, subtitle=subtitle, rtl=rtl)
    path = os.path.join(OUT_DIR, name)
    image.save(path, format="PNG", optimize=True, compress_level=9)


def main() -> None:
    tabs = ["Home", "Ship", "Profile"]
    save("android-before.png", "Android (main)", tabs, False, "setTabbar without layoutDirection")
    save("android-after.png", "Android (PR)", tabs, True, "setTabbar({ layoutDirection: 'rtl' })")
    save("ios-before.png", "iOS (main)", tabs, False, "setTabbar without layoutDirection")
    save("ios-after.png", "iOS (PR)", tabs, True, "setTabbar({ layoutDirection: 'rtl' })")


if __name__ == "__main__":
    main()
