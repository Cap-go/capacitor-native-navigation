# PR #83 tab bar layout direction screenshots

Android emulator captures (API 34, Pixel 6 profile) with `debug.force_rtl` enabled:

- `android-before.png`: example app built from `main` (no `layoutDirection` option).
- `android-after.png`: example app from this branch with `setTabbar({ layoutDirection: 'rtl' })` via `VITE_SCREENSHOT_LAYOUT_DIRECTION=rtl` in screenshot mode.

Regenerate locally or in CI:

```bash
.github/scripts/capture-pr83-android-tabbar-screenshots.sh
```

Or run the `PR83 layout direction screenshots` GitHub Actions workflow (`workflow_dispatch`).
