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
    if image.width > 480:
        image = image.resize((image.width // 2, image.height // 2))
    width, height = image.size

    if width < 8 or height < 8:
        raise SystemExit("Screenshot is too small to verify.")

    sample_pixels = [image.getpixel((x, y)) for x in (0, width // 2, width - 1) for y in (0, height // 2, height - 1)]
    if all(all(channel < 8 for channel in pixel[:3]) for pixel in sample_pixels):
        raise SystemExit("Screenshot looks blank (display off or failed screencap).")

    orange_samples = 0
    for y in range(int(height * 0.12), int(height * 0.55)):
        for x in range(0, width, 3):
            red, green, blue = image.getpixel((x, y))
            if red > 175 and green > 65 and blue < 140 and red > green + 20:
                orange_samples += 1

    tab_tint_samples = 0
    for y in range(height - 140, height - 20):
        for x in range(0, width, 4):
            red, green, blue = image.getpixel((x, y))
            if blue > 170 and red < 120 and green < 170 and blue > red + 40:
                tab_tint_samples += 1

    if orange_samples < 250:
        raise SystemExit(
            f"Screenshot missing orange venue content (only {orange_samples} orange-ish samples). "
            "Likely still on splash or home without content."
        )

    if tab_tint_samples < 25:
        raise SystemExit(
            f"Screenshot missing native tabbar tint (only {tab_tint_samples} blue-ish samples near bottom)."
        )

    if relaxed:
        print(
            f"Verified relaxed screenshot content: orange_samples={orange_samples}, tab_tint_samples={tab_tint_samples}"
        )
        return

    bottom_colors = {image.getpixel((x, height - 72)) for x in range(0, width, 12)}
    if len(bottom_colors) < 8:
        raise SystemExit(
            f"Bottom chrome region looks flat ({len(bottom_colors)} distinct colors). "
            "Floating tabbar is probably not visible."
        )

    center = image.getpixel((width // 2, int(height * 0.55)))
    if all(channel > 200 for channel in center[:3]):
        raise SystemExit("Center looks like splash gray, not colorful content.")

    print(f"Verified screenshot content: orange_samples={orange_samples}, bottom_variety={len(bottom_colors)}")


if __name__ == "__main__":
    main()
