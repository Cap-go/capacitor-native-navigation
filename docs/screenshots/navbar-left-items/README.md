# PR navbar left items screenshots

CI workflow `android-navbar-left-items-screenshot.yml` builds two debug APKs from the example app with `VITE_SCREENSHOT_MODE=navbar-left-items`:

- `android-before.png`: plugin Android sources from `origin/main`.
- `android-after.png`: plugin Android sources from the PR head.

The capture job installs each APK on an API 34 emulator, waits for `NATIVE_NAV_SCREENSHOT_READY` or the `screenshot-ready` UI flag, then saves PNGs under this folder as workflow artifacts.
