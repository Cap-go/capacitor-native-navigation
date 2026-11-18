# iOS navbar scroll collapse layout (issue #104)

Before/after PNGs compare navbar container placement while a scroll-collapse `transform` is active:

- **Before:** `container.frame = ...` (UIKit shifts `center`, ~44pt jump)
- **After:** `nativeNavigationSetViewFrame` (`bounds` + `center`)

Generate on macOS:

```bash
export GENERATE_NAVBAR_SCROLL_SCREENSHOTS=1
xcodebuild test -scheme CapgoCapacitorNativeNavigation \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -only-testing:NativeNavigationPluginTests/NativeNavigationNavbarScrollJumpScreenshotTests
```

Output: `ios-navbar-scroll-jump-before.png`, `ios-navbar-scroll-jump-after.png`.