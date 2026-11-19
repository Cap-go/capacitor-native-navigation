# iOS navbar scroll collapse layout (issue #104)

Regression coverage lives in `NativeNavigationPluginScrollLayoutTests`:

- Boots `NativeNavigationPlugin` on a real root view, calls `setNavbarScrollCollapsed` and `layoutChrome()`, and asserts `navContainer.center` stays on the intended layout rect while the collapse `transform` is active.
- Reassigning `container.frame` under that transform (the pre-fix bug) fails those center assertions (`testLegacyFrameAssignmentShiftsLayoutCenterWhileCollapsed`).

## Local commands

`bun run verify:ios` is **build-only** (same as CI `build_ios` for this package):

```bash
xcodebuild -scheme CapgoCapacitorNativeNavigation -destination generic/platform=iOS
```

Run plugin unit tests on the iOS Simulator (not run in CI today):

```bash
xcodebuild test -scheme CapgoCapacitorNativeNavigation \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NativeNavigationPluginTests
```

To prove the guard, temporarily replace `nativeNavigationSetViewFrame` calls in `layoutChrome()` with `container.frame = ...` and re-run `NativeNavigationPluginScrollLayoutTests/testNavbarScrollCollapseLayoutThroughPlugin`.