#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def main() -> None:
    args = [arg for arg in sys.argv[1:] if arg != "--relaxed"]
    relaxed = "--relaxed" in sys.argv[1:]
    path = Path(args[0] if args else "android-floating-tabbar-after-full.png")
    image = Image.open(path).convert("RGB")
    width, height = image.size

    if width < 8 or height < 8:
        raise SystemExit("Screenshot is too small to verify.")

    sample_pixels = [image.getpixel((x, y)) for x in (0, width // 2, width - 1) for y in (0, height // 2, height - 1)]
    if all(all(channel < 8 for channel in pixel[:3]) for pixel in sample_pixels):
        raise SystemExit("Screenshot looks blank (display off or failed screencap).")

    orange_samples = 0
    y_step = 4 if relaxed else 3
    x_step = 8 if relaxed else 3
    for y in range(int(height * 0.12), int(height * 0.55), y_step):
        for x in range(0, width, x_step):
            red, green, blue = image.getpixel((x, y))
            bright_orange = red > 175 and green > 65 and blue < 140 and red > green + 20
            warm_venue = (
                red > 80
                and green > 20
                and blue < 100
                and red >= green - 5
                and red > green + 8
                and max(red, green, blue) - min(red, green, blue) > 15
            )
            if bright_orange or warm_venue:
                orange_samples += 1
        if relaxed and orange_samples >= 400:
            break

    tab_tint_samples = 0
    tabbar_chrome_samples = 0
    tab_y_step = 6 if relaxed else 1
    tab_x_step = 8 if relaxed else 4
    for y in range(height - 140, height - 20, tab_y_step):
        for x in range(0, width, tab_x_step):
            red, green, blue = image.getpixel((x, y))
            if blue > 170 and red < 120 and green < 170 and blue > red + 40:
                tab_tint_samples += 1
            active_tab_blue = blue > 200 and red < 90 and green > 90 and blue > red + 80
            frosted_bar = (
                min(red, green, blue) > 145
                and max(red, green, blue) < 252
                and max(red, green, blue) - min(red, green, blue) < 45
            )
            if active_tab_blue or frosted_bar:
                tabbar_chrome_samples += 1
        if relaxed and tabbar_chrome_samples >= 40 and tab_tint_samples >= 25:
            break

    if orange_samples < 250:
        raise SystemExit(
            f"Screenshot missing venue content (only {orange_samples} warm/orange samples). "
            "Likely still on splash or home without content."
        )

    if tab_tint_samples < 25 and tabbar_chrome_samples < 30:
        raise SystemExit(
            "Screenshot missing native tabbar chrome "
            f"(tab_tint_samples={tab_tint_samples}, tabbar_chrome_samples={tabbar_chrome_samples})."
        )

    if relaxed:
        print(
            f"Verified relaxed screenshot content: orange_samples={orange_samples}, tab_tint_samples={tab_tint_samples}"
        )
        return

    bottom_y = min(height - 1, int(height * 0.96))
    bottom_colors = {image.getpixel((x, bottom_y)) for x in range(0, width, max(1, width // 90))}
    if len(bottom_colors) < 8:
        raise SystemExit(
            f"Bottom chrome region looks flat ({len(bottom_colors)} distinct colors). "
            "Floating tabbar is probably not visible."
        )

    center = image.getpixel((width // 2, int(height * 0.55)))
    if all(channel > 200 for channel in center[:3]) and orange_samples < 1500:
        raise SystemExit("Center looks like splash gray, not colorful content.")

    print(f"Verified screenshot content: orange_samples={orange_samples}, bottom_variety={len(bottom_colors)}")


if __name__ == "__main__":
    main()
