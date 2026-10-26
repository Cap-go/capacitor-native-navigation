import type { PluginListenerHandle } from '@capacitor/core';

/**
 * Platform rendering preference for the native bars.
 */
export type NativeNavigationPlatformStyle = 'auto' | 'ios' | 'android';

/**
 * How the plugin exposes native bar sizes to web content.
 */
export type NativeNavigationContentInsetMode = 'css' | 'none';

/**
 * Navigation animation direction.
 */
export type NativeNavigationTransitionDirection = 'forward' | 'back' | 'root' | 'tab' | 'zoom' | 'none';

/**
 * Native material/blur effect preference.
 */
export type NativeNavigationBlurEffect =
  | 'none'
  | 'systemDefault'
  | 'extraLight'
  | 'light'
  | 'dark'
  | 'regular'
  | 'prominent'
  | 'systemUltraThinMaterial'
  | 'systemThinMaterial'
  | 'systemMaterial'
  | 'systemThickMaterial'
  | 'systemChromeMaterial'
  | 'systemUltraThinMaterialLight'
  | 'systemThinMaterialLight'
  | 'systemMaterialLight'
  | 'systemThickMaterialLight'
  | 'systemChromeMaterialLight'
  | 'systemUltraThinMaterialDark'
  | 'systemThinMaterialDark'
  | 'systemMaterialDark'
  | 'systemThickMaterialDark'
  | 'systemChromeMaterialDark';

/**
 * When the native tabbar minimizes while web content scrolls.
 */
export type NativeNavigationTabbarMinimizeBehavior = 'never' | 'onScrollDown';

/**
 * Native glass background rendering preference.
 */
export type NativeNavigationGlassEffect = 'none' | 'liquidGlass';

/**
 * Native glass background configuration.
 */
export interface NativeNavigationGlassOptions {
  /**
   * `liquidGlass` gives native bars a translucent tint surface on Android (no
   * live blur: sampling the WebView from native code breaks its scrolling, so
   * put a CSS `backdrop-filter` under the bar when you want blur). iOS uses the
   * platform-owned Liquid Glass behavior.
   */
  effect?: NativeNavigationGlassEffect;

  /**
   * Blur radius in native dp for `liquidGlass`. Defaults to `18`. Currently
   * unused: Android draws no live blur.
   */
  blurRadius?: number;

  /**
   * Alpha multiplier for the tint surface over the glass backdrop. Defaults to
   * `0.62`. Ignored on Android 11 and older, where bars are always solid.
   */
  surfaceAlpha?: number;
}

/**
 * Native tab label visibility behavior.
 */
export type NativeNavigationTabLabelVisibilityMode = 'auto' | 'selected' | 'labeled' | 'unlabeled';

/**
 * A rectangle in WebView viewport coordinates, expressed in native points/dp.
 */
export interface NativeNavigationRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * Native tabbar background shape.
 */
export type NativeNavigationTabbarShape = 'floating' | 'curve';

/**
 * Horizontal alignment of a floating tab bar inside the safe area.
 * `start` and `end` follow `layoutDirection`.
 */
export type NativeNavigationTabbarAlignment = 'start' | 'center' | 'end';

/**
 * Where the native tab bar sits.
 *
 * `auto` lets iOS 18+ choose: a bottom bar on compact iPhone, a trailing
 * sidebar on iPad and iPhone Duo. `bottom` keeps a bottom bar. `sidebar`
 * asks for that trailing rail. Curve-shaped bars stay on the bottom.
 */
export type NativeNavigationTabbarPlacement = 'auto' | 'bottom' | 'sidebar';

/**
 * Where the navbar search field is drawn.
 *
 * `stacked` sits under the title, the iOS 27 Settings field. `button` is a
 * detached search button on the iPhone Duo rail on iOS 26+. A horizontal
 * navbar, Android, and web keep the stacked row.
 *
 * @since 8.14.0
 */
export type NativeNavigationNavbarSearchPlacement = 'stacked' | 'button';

/**
 * Native tab role for Liquid Glass tab bars.
 *
 * `search` (and `prominent` when the OS supports it) renders as a detached
 * trailing circular action beside the floating tab capsule — the Apple News /
 * Photos pattern. Only one detached trailing role is used; if multiple tabs
 * set `search` or `prominent`, the last one wins. Curve-shaped bars ignore
 * `role` and keep using the included center action instead.
 */
export type NativeNavigationTabRole = 'normal' | 'search' | 'prominent';

/**
 * A serializable icon descriptor. Framework nodes are intentionally not accepted
 * because icons are rendered by native UI.
 */
export interface NativeNavigationIcon {
  /**
   * Cross-platform asset path or URL fallback.
   */
  src?: string;

  /**
   * Cross-platform inline SVG markup. The native renderers support common icon
   * shapes such as path, line, polyline, polygon, circle, and rect. SVG icons
   * are rendered as template images by default so native tint colors still
   * apply.
   */
  svg?: string;

  /**
   * Preferred rendered icon width in native points/dp. Defaults to `24`.
   */
  width?: number;

  /**
   * Preferred rendered icon height in native points/dp. Defaults to `24`.
   */
  height?: number;

  /**
   * When `true`, native tint colors are applied to the rendered SVG/image.
   * Defaults to `true`.
   */
  template?: boolean;

  /**
   * iOS-specific SF Symbol, bundled image name, or inline SVG.
   */
  ios?: {
    /**
     * SF Symbol name, for example `house.fill`.
     */
    sfSymbol?: string;

    /**
     * Bundled image name from the app asset catalog.
     */
    image?: string;

    /**
     * iOS-specific inline SVG markup.
     */
    svg?: string;
  };

  /**
   * Android-specific drawable resource, asset name, or inline SVG.
   */
  android?: {
    /**
     * Drawable resource name without the `R.drawable.` prefix.
     */
    resource?: string;

    /**
     * Bundled image asset name.
     */
    image?: string;

    /**
     * Android-specific inline SVG markup.
     */
    svg?: string;
  };
}

/**
 * Native bar colors. Use CSS-style hex strings (`#RRGGBB` or `#AARRGGBB`).
 */
export interface NativeNavigationColors {
  /**
   * When `true`, Android 12+ derives unspecified bar colors from Material You
   * system palettes. Explicit color fields still win.
   */
  dynamic?: boolean;

  /**
   * Tint color for active buttons/items.
   */
  tint?: string;

  /**
   * Color for inactive tab items. Ignored on iOS 26+ unless
   * `experimentalBakedTintColors` is enabled.
   */
  inactiveTint?: string;

  /**
   * Optional background tint. Ignored on iOS 26+ so UIKit can preserve the
   * system Liquid Glass navigation appearance. On Android, alpha is honored.
   * When `glass.effect` is not `liquidGlass`, floating tabbars still apply
   * `glass.surfaceAlpha` (from `configure` / `setTabbar`) to the fill tint.
   */
  background?: string;

  /**
   * Title and label text color where the native platform supports it.
   */
  foreground?: string;

  /**
   * Badge background color for native tab badges.
   */
  badgeBackground?: string;

  /**
   * Badge text color for native tab badges.
   */
  badgeText?: string;

  /**
   * Active tab indicator color on Android.
   */
  indicator?: string;

  /**
   * Tab press ripple color on Android.
   */
  ripple?: string;
}

/**
 * Global plugin configuration.
 */
export interface NativeNavigationConfigureOptions {
  /**
   * Enables or disables the native chrome host.
   */
  enabled?: boolean;

  /**
   * Native style preference. `auto` uses the current platform.
   */
  platformStyle?: NativeNavigationPlatformStyle;

  /**
   * When `css`, the plugin writes CSS variables on `document.documentElement`.
   */
  contentInsetMode?: NativeNavigationContentInsetMode;

  /**
   * Default native transition duration in milliseconds.
   */
  animationDuration?: number;

  /**
   * Shared color hints for native bars.
   */
  colors?: NativeNavigationColors;

  /**
   * Shared glass background defaults for native bars.
   */
  glass?: NativeNavigationGlassOptions;

  /**
   * iPhone Duo vertical rail. `automatic` lets iOS move the status bar, the
   * system tab bar, and navbar icon buttons into the rail. The title stays
   * horizontal. `disabled` keeps the horizontal bars for a screen that should
   * stay put, such as video or a calculator. The preference starts as
   * `automatic`. Omitting this option on a later `configure` call keeps the
   * current preference, so a screen that selected `disabled` stays disabled
   * until another call passes `automatic`. iOS 27.1+.
   *
   * @since 8.14.0
   */
  verticalBarBehavior?: NativeNavigationVerticalBarBehavior;
}

/**
 * Whether iPhone Duo uses the vertical rail.
 *
 * @since 8.14.0
 */
export type NativeNavigationVerticalBarBehavior = 'automatic' | 'disabled';

/**
 * Semantic edge of the iPhone Duo vertical rail.
 *
 * The rail stays on the camera's physical edge. This value flips with
 * right-to-left layout. `null` when the system is not using a rail, including
 * iPhone Duo open in portrait.
 *
 * @since 8.14.0
 */
export type NativeNavigationVerticalBarEdge = 'leading' | 'trailing';

/**
 * A button shown in the native navbar.
 */
export interface NativeNavigationBarButton {
  /**
   * Stable id returned in `navbarItemTap`.
   */
  id: string;

  /**
   * Visible text label.
   */
  title?: string;

  /**
   * Native icon descriptor.
   */
  icon?: NativeNavigationIcon;

  /**
   * Whether the action is enabled. Defaults to `true`.
   */
  enabled?: boolean;

  /**
   * How the button sits in the bar. `shared` (the default) joins the system
   * group. `detached` draws it alone, outside that group, on iOS 26 and
   * later. `prominent` pins it past overflow and search, such as Done.
   * Android keeps every dock value in the normal toolbar menu.
   *
   * @since 8.14.0
   */
  dock?: NativeNavigationBarButtonDock;

  /**
   * Items that share a group id collapse into one control. The first item is
   * what you see; the system expands the rest. One item stays a normal
   * button. Detached and prominent buttons ignore `group`. iOS 16 and later.
   * Older systems show every item.
   *
   * @since 8.14.0
   */
  group?: string;

  /**
   * Axis on the iPhone Duo rail. `automatic` (the default) lets iOS put icon
   * buttons on the rail and keep text buttons horizontal. `vertical` asks
   * for the rail, including a text button such as Done. `horizontal` keeps
   * the button off the rail. iOS 27.1+.
   *
   * @since 8.14.0
   */
  axis?: NativeNavigationBarButtonAxis;
}

/**
 * How a navbar button joins the system bar group.
 *
 * @since 8.14.0
 */
export type NativeNavigationBarButtonDock = 'shared' | 'detached' | 'prominent';

/**
 * Which bar axis a navbar button prefers on iPhone Duo.
 *
 * @since 8.14.0
 */
export type NativeNavigationBarButtonAxis = 'automatic' | 'horizontal' | 'vertical';

/**
 * Native back button configuration.
 */
export interface NativeNavigationBackButton {
  /**
   * Show the native back affordance.
   */
  visible?: boolean;

  /**
   * Optional back title. This is the accessibility label when the control is
   * an icon. When `display` is omitted, a non-empty title (including the
   * default `Back`) is drawn as text and stays off the iPhone Duo rail.
   */
  title?: string;

  /**
   * `back` (the default) is a chevron. `close` is an xmark. An icon sits at
   * the top of the iPhone Duo rail. Android uses the back arrow, or a close
   * icon when `role` is `close`.
   *
   * @since 8.14.0
   */
  role?: NativeNavigationBackButtonRole;

  /**
   * `icon` draws a symbol and can join the iPhone Duo rail. `title` draws
   * text and stays horizontal. When omitted, `close` is an icon, an empty
   * title is an icon, and any other title is text.
   *
   * @since 8.14.0
   */
  display?: NativeNavigationBackButtonDisplay;

  /**
   * When `true`, `leftItems` are kept beside the system back button.
   * Omitted means `false`. The plugin's back control is its own leading
   * item, so this does not hide `leftItems` on iOS. On Android, `leftItems`
   * are shown with a visible back button only when this is `true`. When no
   * back button is visible, the first `leftItems` entry with an icon uses
   * the toolbar navigation slot (leading edge); further left items stay in
   * the toolbar menu.
   *
   * @since 8.14.0
   */
  supplements?: boolean;
}

/**
 * Symbol used for the navbar back control.
 *
 * @since 8.14.0
 */
export type NativeNavigationBackButtonRole = 'back' | 'close';

/**
 * Whether the navbar back control draws a symbol or a text title.
 *
 * @since 8.14.0
 */
export type NativeNavigationBackButtonDisplay = 'icon' | 'title';

/**
 * Which side of the iPhone Duo rail gives up space first.
 *
 * `automatic` is the system default and prefers the tab bar. `preferItems`
 * compresses the tab bar first so navbar buttons stay. `preferTabs`
 * compresses navbar buttons first. iOS 27.1+.
 *
 * @since 8.14.0
 */
export type NativeNavigationVerticalBarCompression = 'automatic' | 'preferItems' | 'preferTabs';

/**
 * How the native navbar reacts to WebView scroll direction.
 *
 * Defaults to `none` (current static navbar behavior).
 */
export type NativeNavigationNavbarScrollBehavior = 'none' | 'hideOnScrollDown' | 'revealOnScrollUp' | 'both';

/**
 * One choice inside a navbar segment row.
 *
 * @since 8.13.0
 */
export interface NativeNavigationNavbarSegmentItem {
  /**
   * Stable id returned in `navbarSegmentSelect`.
   */
  id: string;

  /**
   * Visible label. Items without a title show only their icon.
   */
  title?: string;

  /**
   * Native icon descriptor.
   */
  icon?: NativeNavigationIcon;

  /**
   * Screen reader label. Defaults to `title`. Set it for icon-only items.
   */
  accessibilityLabel?: string;

  /**
   * Whether the item can be selected. Defaults to `true`.
   */
  enabled?: boolean;
}

/**
 * Native search field drawn with the navbar, like the iOS 27 Settings search.
 */
export interface NativeNavigationNavbarSearch {
  /**
   * Remove the field. Pass `hidden: true` to show no field.
   */
  hidden?: boolean;

  /**
   * Placeholder text. Defaults to `Search`.
   */
  placeholder?: string;

  /**
   * Query to show. While the field is focused, native edits are kept until
   * this value changes.
   */
  text?: string;

  /**
   * Whether the field accepts input. Defaults to `true`.
   */
  enabled?: boolean;

  /**
   * `stacked` (the default) is a row under the title and above `segments`.
   * `button` is a detached search button on the iPhone Duo rail on iOS 26+.
   * A horizontal navbar, Android, and web keep the stacked row. Below iOS 26
   * the button is also the stacked row. `hidesWhenCollapsed` does not hide
   * the rail button.
   */
  placement?: NativeNavigationNavbarSearchPlacement;

  /**
   * Hide the row once a large title collapses on scroll. Defaults to `true`
   * when `large` is `true`, and `false` otherwise. The reported top inset
   * shrinks with the row.
   */
  hidesWhenCollapsed?: boolean;
}

/**
 * How a navbar segment row draws its items.
 *
 * - `segmented`: equal-width control that fills the row (`UISegmentedControl` on iOS).
 * - `scroll`: horizontally scrolling pills, for rows with many or long items.
 * - `auto`: `segmented` for up to 4 items, `scroll` otherwise.
 *
 * @since 8.13.0
 */
export type NativeNavigationNavbarSegmentStyle = 'auto' | 'segmented' | 'scroll';

/**
 * A row of native segments drawn under the navbar, such as section tabs.
 *
 * @since 8.13.0
 */
export interface NativeNavigationNavbarSegmentGroup {
  /**
   * Stable id returned in `navbarSegmentSelect`.
   */
  id: string;

  /**
   * Items of the row.
   */
  items: NativeNavigationNavbarSegmentItem[];

  /**
   * Id of the selected item. No item is selected when omitted.
   */
  selectedId?: string;

  /**
   * Row layout. Defaults to `auto`.
   */
  style?: NativeNavigationNavbarSegmentStyle;
}

/**
 * Native navbar state.
 */
export interface NativeNavigationNavbarOptions {
  /**
   * Hide the native navbar. A web modal, sheet, dialog, or popover renders
   * inside the WebView and stays under this bar, so hide the navbar while
   * that overlay is open. Send the same options again with `hidden: false`
   * when it closes. The hide is immediate on iOS and Android.
   */
  hidden?: boolean;

  /**
   * Main title.
   */
  title?: string;

  /**
   * Secondary title where supported by the platform.
   */
  subtitle?: string;

  /**
   * Show a large title under the bar, like iOS large titles. On Android the bar grows by 52dp and
   * the title moves into its own row. Send `large: false` with the same title to collapse it to the
   * inline title (animated on Android), e.g. once the page scrolls.
   */
  large?: boolean;

  /**
   * Prefer transparent/scroll-edge style.
   */
  transparent?: boolean;

  /**
   * iOS blur/material effect for the navbar background when glass is not
   * available. Defaults to `systemChromeMaterial` for transparent bars.
   */
  blurEffect?: NativeNavigationBlurEffect;

  /**
   * Optional glass background behavior. Overrides `configure({ glass })` for
   * this navbar update.
   */
  glass?: NativeNavigationGlassOptions;

  /**
   * Progressive blur that fades out below the navbar, drawn by the page with
   * CSS `backdrop-filter` so it follows web scrolling. Not drawn on Android
   * 11 and older.
   *
   * Defaults to `true` on iOS 26+, where the clear Liquid Glass navbar needs
   * it to match the system scroll edge effect, and `false` elsewhere.
   */
  edgeBlur?: boolean;

  /**
   * Back button state.
   */
  backButton?: NativeNavigationBackButton;

  /**
   * Which side of the iPhone Duo rail compresses first when space runs out.
   * Omitted means `automatic`. This is separate from
   * `configure({ verticalBarBehavior })`. iOS 27.1+.
   *
   * @since 8.14.0
   */
  verticalBarCompression?: NativeNavigationVerticalBarCompression;

  /**
   * Left-side action buttons.
   */
  leftItems?: NativeNavigationBarButton[];

  /**
   * Right-side action buttons.
   */
  rightItems?: NativeNavigationBarButton[];

  /**
   * Search field under the title. The row adds 52pt (iOS) or 52dp (Android)
   * to the navbar and to the reported top inset while it is visible. Pass
   * `hidden: true` to remove it. Typing fires `navbarSearch`.
   *
   * @since 8.14.0
   */
  search?: NativeNavigationNavbarSearch;

  /**
   * Rows of native segments drawn under the bar, top to bottom. Each row adds
   * 44pt (iOS) or 48dp (Android) to the navbar and to the reported insets.
   * Selecting an item fires `navbarSegmentSelect` and moves the selection
   * natively. Each `setNavbar` call applies `selectedId` again, so store the
   * selected id from the event and pass it on every later `setNavbar` call.
   * To reject a selection, send the previous `selectedId`.
   *
   * @since 8.13.0
   */
  segments?: NativeNavigationNavbarSegmentGroup[];

  /**
   * Navbar color hints.
   */
  colors?: NativeNavigationColors;

  /**
   * Animate navbar title and item changes while the bar is visible. Hiding
   * the bar with `hidden: true` does not use this flag.
   */
  animated?: boolean;

  /**
   * Hide or reveal the navbar while web content scrolls. When enabled, iOS and
   * Android inject scroll listeners on `window`, `#app`, and any existing
   * `[data-cap-native-navigation-scroll]` elements, and rescan marked elements
   * on each `setNavbar` call. The web fallback binds the same roots when
   * `setNavbar` runs (`window`, `#app`, and matching marked elements). Do not
   * call `reportNavbarScroll()` for a root that is already bound.
   *
   * Defaults to `none`.
   */
  scrollBehavior?: NativeNavigationNavbarScrollBehavior;

  /**
   * Minimum vertical scroll delta (CSS px) before `scrollBehavior` reacts.
   * Defaults to `8`.
   */
  scrollThreshold?: number;

  /**
   * When `true`, clears any scroll-collapsed navbar state before applying this
   * update. Use on route changes; omit for same-screen chrome tweaks.
   */
  resetScrollCollapsed?: boolean;
}

/**
 * Scroll sample reported from web content while `scrollBehavior` is active.
 */
export interface NativeNavigationNavbarScrollEvent {
  /**
   * Current vertical scroll offset in CSS pixels.
   */
  offsetY: number;

  /**
   * Change since the previous sample in CSS pixels.
   */
  deltaY: number;
}

/**
 * A native tab item.
 */
export interface NativeNavigationTab {
  /**
   * Stable tab id returned in `tabSelect`.
   */
  id: string;

  /**
   * Visible tab label.
   */
  title?: string;

  /**
   * Native icon descriptor.
   */
  icon?: NativeNavigationIcon;

  /**
   * Optional selected-state icon.
   */
  selectedIcon?: NativeNavigationIcon;

  /**
   * Optional badge. Numeric badges are supported on both platforms; text badge
   * support depends on platform capabilities.
   */
  badge?: string | number;

  /**
   * Whether the tab is enabled. Defaults to `true`.
   */
  enabled?: boolean;

  /**
   * Hide the tab item from the native tabbar. When the hidden tab is selected,
   * native platform constraints may keep it visible until another tab is
   * selected.
   */
  hidden?: boolean;

  /**
   * Optional tab role. On floating tabbars, `search` (or `prominent` when
   * available) becomes a detached trailing circular action beside the capsule
   * — including the iOS 26+ system Liquid Glass tab bar, Android floating
   * layout, and the custom floating capsule path. Only one detached trailing
   * role is used; if multiple tabs set `search` or `prominent`, the last one
   * wins. Curve-shaped bars ignore `role` and keep using the included center
   * action. Defaults to `normal`.
   */
  role?: NativeNavigationTabRole;
}

/**
 * Native tabbar layout and background shape options.
 */
export interface NativeNavigationTabbarStyle {
  /**
   * `floating` keeps the capsule tabbar. On iOS 26+ this uses the
   * system-owned Liquid Glass `UITabBarController` unless a custom capsule
   * path is required; earlier iOS and the custom capsule path use
   * `UIGlassEffect` on iOS 26+ (blur material fallback otherwise). `curve`
   * draws a full-width bar with an included center action.
   */
  shape?: NativeNavigationTabbarShape;

  /**
   * Bar height in native points/dp, not including the system bottom inset.
   * Curve defaults to `49` on iOS (83pt once the home indicator is added) and
   * `80` on Android (Material navigation bar). Floating defaults to `64`.
   * Pass `height` to override either platform.
   */
  height?: number;

  /**
   * Horizontal margin in native points/dp. Defaults to `24` for `floating` and
   * `0` for `curve`.
   */
  horizontalMargin?: number;

  /**
   * Maximum tabbar width in native points/dp. Defaults to `430` for `floating`;
   * `curve` uses the available width unless this is set.
   */
  maxWidth?: number;

  /**
   * Bottom gap above the platform safe area in native points/dp. Defaults to
   * `10` for `floating` and `0` for `curve`.
   */
  bottomGap?: number;

  /**
   * Background corner radius in native points/dp. Defaults to a capsule radius
   * for `floating` and `0` for `curve`.
   */
  cornerRadius?: number;

  /**
   * Tab id promoted into the included center button for `curve`. Defaults to
   * the middle tab.
   */
  centerItemId?: string;

  /**
   * Included center button diameter in native points/dp. Defaults to `56`.
   */
  centerButtonDiameter?: number;

  /**
   * Distance from the top of the center button to the top edge of the bar in
   * native points/dp. Defaults to half of `centerButtonDiameter`.
   */
  centerButtonLift?: number;

  /**
   * Included center button color. Defaults to the active tint color.
   */
  centerButtonColor?: string;

  /**
   * Included center button icon color. Defaults to white.
   */
  centerButtonIconColor?: string;

  /**
   * Horizontal alignment of a floating bar. Defaults to `center`. Ignored for
   * `curve` and for `sidebar` placement. `start` and `end` follow
   * `layoutDirection`.
   *
   * @since 8.14.0
   */
  alignment?: NativeNavigationTabbarAlignment;

  /**
   * `auto` lets iOS 18+ place the system tab bar (bottom on compact iPhone,
   * trailing sidebar on iPad and iPhone Duo). `bottom` keeps a bottom bar.
   * `sidebar` requests the trailing rail: the system tab bar on iOS 18+, and
   * a vertical rail of the same tabs on Android. Compact iPhone may stay on
   * the bottom when UIKit does not offer a sidebar. `curve` stays on the
   * bottom. `sidebar` ignores `minimizeBehavior` and drag-to-select.
   *
   * @since 8.14.0
   */
  placement?: NativeNavigationTabbarPlacement;
}

/**
 * Native tabbar state.
 */
export interface NativeNavigationTabbarOptions {
  /**
   * Hide the native tabbar. A web modal, sheet, dialog, or popover renders
   * inside the WebView and stays under this bar, so hide the tabbar while
   * that overlay is open. Pass `animated: true` together with the same
   * `tabs` and `selectedId` you last rendered. That soft-hides the bar and
   * leaves it mounted. `animated: false` hides it immediately.
   */
  hidden?: boolean;

  /**
   * Tab definitions.
   */
  tabs?: NativeNavigationTab[];

  /**
   * Currently selected tab id.
   */
  selectedId?: string;

  /**
   * Show text labels. Defaults to `true`.
   */
  labels?: boolean;

  /**
   * Native label visibility mode. Overrides `labels` when provided.
   */
  labelVisibilityMode?: NativeNavigationTabLabelVisibilityMode;

  /**
   * Show icons. Defaults to `true`.
   */
  icons?: boolean;

  /**
   * Tabbar color hints.
   */
  colors?: NativeNavigationColors;

  /**
   * iOS blur/material effect for the tabbar background when glass is not
   * available.
   */
  blurEffect?: NativeNavigationBlurEffect;

  /**
   * Optional glass background behavior. Overrides `configure({ glass })` for
   * this tabbar update. On Android 12+, floating tabbars default to
   * `liquidGlass` (translucent tint) when this field is omitted. Pass
   * `effect: 'none'` for a flat fill.
   */
  glass?: NativeNavigationGlassOptions;

  /**
   * Opt into the iOS 26 Liquid Glass tint workaround that renders active and
   * inactive tab items into baked images. This can affect badge positioning
   * and icon sizing, so it is disabled by default.
   */
  experimentalBakedTintColors?: boolean;

  /**
   * Keep the iOS scroll-edge tabbar appearance from becoming transparent.
   * Mirrors Expo Router native tabs' `disableTransparentOnScrollEdge` option.
   * Defaults to `false`.
   */
  disableTransparentOnScrollEdge?: boolean;

  /**
   * Tab bar layout direction. Use `rtl` when the app language is right to left
   * but the device locale is not. Omitted leaves Android layout direction
   * inherited from the host and resets any explicit iOS system tab bar
   * direction override from this plugin.
   *
   * @since 8.12.0
   */
  layoutDirection?: 'ltr' | 'rtl';

  /**
   * Disable the Android active tab indicator.
   */
  disableIndicator?: boolean;

  /**
   * Active tab indicator color on Android. `colors.indicator` is also
   * supported.
   */
  indicatorColor?: string;

  /**
   * Tab press ripple color on Android. `colors.ripple` is also supported.
   */
  rippleColor?: string;

  /**
   * Badge background color. `colors.badgeBackground` is also supported.
   */
  badgeBackgroundColor?: string;

  /**
   * Badge text color. `colors.badgeText` is also supported.
   */
  badgeTextColor?: string;

  /**
   * Optional native tabbar layout and shape customization.
   */
  style?: NativeNavigationTabbarStyle;

  /**
   * Minimize the tabbar while web content scrolls down and expand it again on
   * scroll up or near the top. Scroll samples come from the same roots as the
   * navbar `scrollBehavior` (`window`, `#app` and
   * `[data-cap-native-navigation-scroll]` elements) and use the navbar
   * `scrollThreshold`.
   *
   * Keeps every icon, hides the labels and shrinks the floating capsule.
   * Tapping a tab (or dragging the bar on Android) expands it again. Ignored
   * for `curve` shape and when `icons` is `false`.
   *
   * On iOS 26+ this replaces the system Liquid Glass tab bar with the
   * plugin's own glass capsule while enabled, because UIKit's
   * `tabBarMinimizeBehavior` cannot follow WebView scrolling. That capsule has
   * no drag-to-select.
   *
   * Insets keep reporting the expanded height so the page does not reflow.
   * Defaults to `never`.
   */
  minimizeBehavior?: NativeNavigationTabbarMinimizeBehavior;

  /**
   * Blur page content behind the tabbar, strongest at the bottom edge and
   * fading out just above the bar. The page draws it with CSS
   * `backdrop-filter`: the plugin adds a fixed, non-interactive
   * `#cap-native-navigation-edge-blur` element and keeps its height in sync
   * with the tabbar. It is removed when the tabbar hides.
   *
   * Android 11 and older skip the blur. On those versions the native bars are
   * always drawn with a solid background instead of a translucent tint,
   * because without blur the page reads through the bar.
   *
   * Defaults to `false`, except on iOS 26+ while `minimizeBehavior` replaces
   * the system tab bar: it then defaults to `true` to match the system bar's
   * scroll edge blur.
   */
  edgeBlur?: boolean;

  /**
   * Drag a finger along the floating tabbar to move the selection like the
   * iOS 26 tab bar: the indicator follows the finger, a haptic tick plays on
   * each tab boundary, and `tabSelect` fires on release. iOS 26+ system tab
   * bars always support this natively; this option controls the Android
   * floating tabbar. Ignored for `curve` shape. Defaults to `true`.
   */
  dragToSelect?: boolean;

  /**
   * Animate native tabbar changes. With `hidden: true` on iOS 26+ system
   * Liquid Glass (any shape except `curve`, and while `minimizeBehavior` is
   * not `onScrollDown`), the plugin calls
   * `UITabBarController.setTabBarHidden(_:animated:)` and leaves the tab
   * controller and hosted WebView in place. UIKit fades the bar.
   * `systemTabbarHeight` stays reported for that soft hide. Other iOS bars
   * fade over 200ms and stay mounted. Android slides and fades over 200ms,
   * then removes the bar from layout. Showing the bar with `animated: true`
   * reverses that. Omit `animated` to hide immediately; on the iOS system
   * bar that also tears the tab controller down.
   */
  animated?: boolean;
}

/**
 * Insets exposed to web content.
 */
export interface NativeNavigationInsets {
  top: number;
  right: number;
  bottom: number;
  left: number;
  navbarHeight: number;
  /**
   * Bottom overlap inset for web layout when the WebView does not already
   * reserve space for the native tab bar. On iOS 26+ with a system-hosted tab
   * bar this stays `0` so content is not lifted twice.
   */
  tabbarHeight: number;
  /**
   * Nominal native tab bar height (bar plus home-indicator padding on iOS)
   * even when `tabbarHeight` is `0`. Stays available while the tab bar is
   * soft-hidden with `setTabbar({ hidden: true, animated: true })`.
   */
  systemTabbarHeight: number;

  /**
   * Semantic edge of the vertical rail, or `null` when the bars are horizontal.
   * On a rail, `left` or `right` carries the rail thickness and `tabbarHeight`
   * stays `0` when the WebView is already beside it. `systemTabbarHeight` is
   * that thickness rather than a bottom bar.
   *
   * @since 8.14.0
   */
  verticalBarEdge?: NativeNavigationVerticalBarEdge | null;

  /**
   * Fold and occlusion rectangles reported by iOS, in the root view's points.
   * Empty when the device has no reserved regions.
   *
   * @since 8.14.0
   */
  reservedRegions?: NativeNavigationReservedRegion[];

  /**
   * Latest hinge sample. `null` when the device has no hinge. Angle updates
   * are delivered on `hingeChanged` and are not pushed through this snapshot
   * on every tick.
   *
   * @since 8.14.0
   */
  hinge?: NativeNavigationHinge | null;
}

/**
 * A region iOS reserves inside the window, such as the fold or an occlusion.
 *
 * @since 8.14.0
 */
export interface NativeNavigationReservedRegion {
  kind: 'division' | 'occlusion';
  x: number;
  y: number;
  width: number;
  height: number;
  active: boolean;
}

/**
 * iPhone Duo hinge sample. `angle` is radians.
 *
 * @since 8.14.0
 */
export interface NativeNavigationHinge {
  angle: number;
  status: 'unknown' | 'closed' | 'partiallyOpen' | 'fullyOpen';
}

/**
 * Returned by methods that may change safe content bounds.
 */
export interface NativeNavigationInsetsResult {
  insets: NativeNavigationInsets;
}

/**
 * Begin a native transition transaction before JS changes route content.
 */
export interface NativeNavigationBeginTransitionOptions {
  id?: string;
  direction?: NativeNavigationTransitionDirection;
  duration?: number;
  /**
   * Source rectangle for `zoom` transitions. Use viewport coordinates such as
   * those returned by `Element.getBoundingClientRect()`.
   */
  sourceRect?: NativeNavigationRect;
  /**
   * Destination rectangle for shared-element-style `zoom` transitions.
   */
  targetRect?: NativeNavigationRect;
  /**
   * Corner radius used while animating a `zoom` transition.
   */
  cornerRadius?: number;
}

/**
 * Finish a native transition transaction after JS has changed route content.
 */
export interface NativeNavigationFinishTransitionOptions {
  id?: string;
  direction?: NativeNavigationTransitionDirection;
  duration?: number;
  /**
   * Source rectangle for `zoom` transitions when no active source was recorded.
   */
  sourceRect?: NativeNavigationRect;
  /**
   * Destination rectangle for shared-element-style `zoom` transitions.
   */
  targetRect?: NativeNavigationRect;
  /**
   * Corner radius used while animating a `zoom` transition.
   */
  cornerRadius?: number;
}

/**
 * Native transition result.
 */
export interface NativeNavigationTransitionResult {
  id: string;
  direction: NativeNavigationTransitionDirection;
  duration: number;
}

/**
 * Plugin version payload.
 */
export interface PluginVersionResult {
  /**
   * Version identifier returned by the platform implementation.
   */
  version: string;
}

export interface NativeNavigationBackEvent {
  source: 'navbar';
}

export interface NativeNavigationBarItemTapEvent {
  id: string;
  title?: string;
  placement: 'left' | 'right';
}

export interface NativeNavigationNavbarSearchEvent {
  /**
   * Current field text.
   */
  text: string;

  /**
   * `input` while typing, `submit` from the search key, `cancel` when the
   * field is cleared from the platform cancel action.
   */
  reason: 'input' | 'submit' | 'cancel';
}

export interface NativeNavigationNavbarSegmentSelectEvent {
  /**
   * Id of the segment row.
   */
  groupId: string;

  /**
   * Id of the selected item.
   */
  id: string;

  /**
   * Index of the selected item in its row.
   */
  index: number;
}

export interface NativeNavigationTabSelectEvent {
  id: string;
  index: number;
  title?: string;
}

export interface NativeNavigationSafeAreaChangedEvent {
  insets: NativeNavigationInsets;
}

/**
 * iPhone Duo vertical rail edge change.
 *
 * @since 8.14.0
 */
export interface NativeNavigationVerticalBarChangedEvent {
  edge: NativeNavigationVerticalBarEdge | null;
  /**
   * True when the system tab bar is currently a vertical rail.
   */
  active: boolean;
}

/**
 * iPhone Duo hinge update. `hinge` is `null` when updates stop.
 *
 * @since 8.14.0
 */
export interface NativeNavigationHingeChangedEvent {
  hinge: NativeNavigationHinge | null;
}

export interface NativeNavigationTransitionEvent {
  id: string;
  direction: NativeNavigationTransitionDirection;
  duration: number;
}

/**
 * Options for the optional native pull-to-refresh gesture.
 */
export interface NativeNavigationPullToRefreshOptions {
  /**
   * Turn native pull-to-refresh on or off. Off by default: nothing is attached
   * to the WebView until this is `true`, and `false` restores the original
   * view setup.
   *
   * iOS shows the system activity indicator below the navbar and arms the
   * refresh with a haptic, like `UIRefreshControl`. Android wraps the WebView
   * in a `SwipeRefreshLayout`. Both work whether the page scrolls `window` or
   * an inner root (`#app`, `[data-cap-native-navigation-scroll]`): the gesture
   * only starts when that root is at the top. Call `reportNavbarScroll()` for
   * other scroll containers.
   *
   * @default false
   */
  enabled: boolean;

  /**
   * Spinner color as a hex string. Defaults to the platform spinner color.
   */
  tintColor?: string;

  /**
   * Spinner disc background color as a hex string. Android only.
   */
  backgroundColor?: string;
}

/**
 * Framework-agnostic native navigation chrome API.
 */
export interface NativeNavigationPlugin {
  /**
   * Configure the native chrome host and content inset behavior.
   */
  configure(options?: NativeNavigationConfigureOptions): Promise<NativeNavigationInsetsResult>;

  /**
   * Render or update the native navbar.
   */
  setNavbar(options: NativeNavigationNavbarOptions): Promise<NativeNavigationInsetsResult>;

  /**
   * Report scroll samples for `scrollBehavior`. Use only for scroll roots that
   * are not already wired by `setNavbar` (`window`, `#app`, or
   * `[data-cap-native-navigation-scroll]`). iOS, Android, and the web fallback
   * install those listeners automatically when scrolling is enabled.
   */
  reportNavbarScroll(options: NativeNavigationNavbarScrollEvent): Promise<void>;

  /**
   * Enable or disable the native pull-to-refresh gesture. Listen for
   * `pullToRefresh`, reload your data, then call `endPullToRefresh()` to hide
   * the spinner. No-op on web.
   *
   * @since 8.11.0
   */
  setPullToRefresh(options: NativeNavigationPullToRefreshOptions): Promise<void>;

  /**
   * Stop the native pull-to-refresh spinner once the refresh is done.
   *
   * @since 8.11.0
   */
  endPullToRefresh(): Promise<void>;

  /**
   * Render or update the native tabbar.
   */
  setTabbar(options: NativeNavigationTabbarOptions): Promise<NativeNavigationInsetsResult>;

  /**
   * Capture the current WebView and prepare a native transition.
   */
  beginTransition(options?: NativeNavigationBeginTransitionOptions): Promise<NativeNavigationTransitionResult>;

  /**
   * Animate from the captured WebView snapshot to the current live WebView.
   */
  finishTransition(options?: NativeNavigationFinishTransitionOptions): Promise<NativeNavigationTransitionResult>;

  /**
   * Returns the platform implementation version marker.
   */
  getPluginVersion(): Promise<PluginVersionResult>;

  addListener(
    eventName: 'navbarBack',
    listenerFunc: (event: NativeNavigationBackEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'navbarItemTap',
    listenerFunc: (event: NativeNavigationBarItemTapEvent) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Fired when the navbar search field changes.
   *
   * @since 8.14.0
   */
  addListener(
    eventName: 'navbarSearch',
    listenerFunc: (event: NativeNavigationNavbarSearchEvent) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Fired when the user selects an item in a navbar segment row.
   *
   * @since 8.13.0
   */
  addListener(
    eventName: 'navbarSegmentSelect',
    listenerFunc: (event: NativeNavigationNavbarSegmentSelectEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'tabSelect',
    listenerFunc: (event: NativeNavigationTabSelectEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'safeAreaChanged',
    listenerFunc: (event: NativeNavigationSafeAreaChangedEvent) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Fired when the iPhone Duo vertical rail appears, disappears, or changes
   * edge. `safeAreaChanged` carries the same edge on every inset update.
   *
   * @since 8.14.0
   */
  addListener(
    eventName: 'verticalBarChanged',
    listenerFunc: (event: NativeNavigationVerticalBarChangedEvent) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Fired when the iPhone Duo hinge changes, or when hinge updates stop.
   * Prefer `hinge.status` over `hinge.angle` when a coarse pose is enough.
   *
   * @since 8.14.0
   */
  addListener(
    eventName: 'hingeChanged',
    listenerFunc: (event: NativeNavigationHingeChangedEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'transitionStart',
    listenerFunc: (event: NativeNavigationTransitionEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'transitionEnd',
    listenerFunc: (event: NativeNavigationTransitionEvent) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Fired when the user pulls to refresh. The spinner keeps spinning until
   * `endPullToRefresh()` is called.
   *
   * @since 8.11.0
   */
  addListener(eventName: 'pullToRefresh', listenerFunc: () => void): Promise<PluginListenerHandle>;
}
