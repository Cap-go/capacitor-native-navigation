# iOS navbar scroll collapse layout (issue #104)

Regression coverage lives in `NativeNavigationPluginScrollLayoutTests`:

- Boots `NativeNavigationPlugin` on a real root view, calls `setNavbarScrollCollapsed` and `layoutChrome()`, and asserts `navContainer.center` stays on the intended layout rect while the collapse `transform` is active.
- Reassigning `container.frame` under that transform (the pre-fix bug) fails those center assertions.

## Local commands

Build only (same as `verify:ios`):

```bash
xcodebuild -scheme CapgoCapacitorNativeNavigation -destination generic/platform=iOS
```

Run all plugin unit tests on the simulator:

```bash
xcodebuild test -scheme CapgoCapacitorNativeNavigation \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NativeNavigationPluginTests
```

To prove the guard, temporarily replace `nativeNavigationSetViewFrame` calls in `layoutChrome()` with `container.frame = ...` and re-run `NativeNavigationPluginScrollLayoutTests/testNavbarScrollCollapseLayoutThroughPlugin`.

## CI artifacts

On pull requests, CI sets `NAVBAR_SCROLL_SCREENSHOT_OUTPUT_DIR` to `$RUNNER_TEMP/ios-navbar-scroll-jump`, writes `ios-navbar-scroll-jump-collapsed.png` and `ios-navbar-scroll-jump-revealed.png`, and uploads that folder. PNGs are not committed to the repository.