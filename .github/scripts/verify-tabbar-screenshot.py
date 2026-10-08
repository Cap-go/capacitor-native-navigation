#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "android-floating-tabbar-after-full.png")
    image = Image.open(path).convert("RGB")
    width, height = image.size

    orange_samples = 0
    for y in range(int(height * 0.1), int(height * 0.72)):
        for x in range(0, width, 3):
            red, green, blue = image.getpixel((x, y))
            if red > 175 and green > 65 and blue < 140 and red > green + 20:
                orange_samples += 1

    if orange_samples < 250:
        raise SystemExit(
            f"Screenshot missing orange venue content (only {orange_samples} orange-ish samples). "
            "Likely still on splash or home without content."
        )

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
