#!/usr/bin/env bash
set -euo pipefail

chmod +x .github/scripts/capture-navbar-left-items-screenshot.sh
mkdir -p docs/screenshots/navbar-left-items
bash .github/scripts/capture-navbar-left-items-screenshot.sh screenshot-apks/navbar-before.apk docs/screenshots/navbar-left-items/android-before.png
NAVBAR_SCREENSHOT_SKIP_BOOT=1 bash .github/scripts/capture-navbar-left-items-screenshot.sh screenshot-apks/navbar-after.apk docs/screenshots/navbar-left-items/android-after.png
