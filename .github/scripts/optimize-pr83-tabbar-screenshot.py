#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def optimize(source: Path, target: Path, width: int = 420) -> None:
    image = Image.open(source)
    crop_top = max(0, int(image.height * 0.58))
    cropped = image.crop((0, crop_top, image.width, image.height))
    height = max(1, int(cropped.height * width / cropped.width))
    resized = cropped.resize((width, height), Image.Resampling.LANCZOS)
    target.parent.mkdir(parents=True, exist_ok=True)
    resized.save(target, format="PNG", optimize=True, compress_level=9)
    size_kb = target.stat().st_size / 1024
    print(f"Wrote {target} ({width}x{height}, {size_kb:.1f} KiB)")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: optimize-pr83-tabbar-screenshot.py <source.png> <target.png>")
    optimize(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
