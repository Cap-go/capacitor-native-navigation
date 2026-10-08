#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image


def main() -> None:
    source = Path("android-floating-tabbar-after-full.png")
    target = Path("docs/android-floating-tabbar-after-300.png")
    target.parent.mkdir(parents=True, exist_ok=True)
    image = Image.open(source)
    width = 300
    height = max(1, int(image.height * width / image.width))
    resized = image.resize((width, height), Image.Resampling.LANCZOS)
    resized.save(target, format="PNG", optimize=True, compress_level=9)
    print(f"Wrote {target} ({width}x{height})")


if __name__ == "__main__":
    main()
