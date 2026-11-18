# iOS navbar scroll collapse layout (issue #104)

Before/after PNGs compare navbar container placement while a scroll-collapse `transform` is active:

- **Before:** `container.frame = ...` (UIKit shifts `center`, ~44pt jump)
- **After:** `nativeNavigationSetViewFrame` (`bounds` + `center`)

Generate on macOS:

```bash
xcodebuild test -scheme CapgoCapacitorNativeNavigation \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  'OTHER_SWIFT_FLAGS=-D GENERATE_NAVBAR_SCROLL_SCREENSHOTS' \
  -only-testing:NativeNavigationPluginTests/NativeNavigationNavbarScrollJumpScreenshotTests
```

CI forwards `GITHUB_WORKSPACE` and `NAVBAR_SCROLL_SCREENSHOT_OUTPUT_DIR` so PNGs land in this directory on the runner. Tests also attach PNGs to the XCTest result bundle.

Output: `ios-navbar-scroll-jump-before.png`, `ios-navbar-scroll-jump-after.png`.