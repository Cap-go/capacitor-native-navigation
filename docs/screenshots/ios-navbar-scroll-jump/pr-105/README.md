# PR #105 iOS navbar scroll hide/reveal screenshots

iPhone 17 simulator, 390x844 canvas, safe area top 59pt. Harness title: Scroll layout.

| File | Meaning |
| --- | --- |
| `ios-main-collapsed.png` | `main` layout (`container.frame` under collapse transform), collapsed with production alpha 0 (bar hidden) |
| `ios-main-revealed-jump.png` | `main` layout mid animated reveal (0.05s after reveal starts): `layoutChrome` assigns `frame` under the outgoing collapse transform, so the bar jumps in the slot before the slide finishes |
| `ios-pr-collapsed.png` | This branch (`nativeNavigationSetViewFrame`), collapsed, alpha 0 (bar hidden) |
| `ios-pr-revealed.png` | This branch, revealed, navbar in the layout slot |

PNG files are written by `NativeNavigationPluginScrollLayoutTests` on pull request CI.