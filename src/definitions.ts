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
 * Native glass background rendering preference.
 */
export type NativeNavigationGlassEffect = 'none' | 'liquidGlass';

/**
 * Native glass background configuration.
 */
export interface NativeNavigationGlassOptions {
  /**
   * `liquidGlass` enables the Android 12+ live blurred WebView backdrop for
   * native bars. Android 11 and older keep a translucent surface fallback. iOS
   * uses the platform-owned Liquid Glass behavior.
   */
  effect?: NativeNavigationGlassEffect;

  /**
   * Android blur radius in native dp for `liquidGlass`. Defaults to `18`.
   */
  blurRadius?: number;

  /**
   * Alpha multiplier for the tint surface over the glass backdrop. Defaults to
   * `0.62`.
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
   * system Liquid Glass navigation appearance.
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
}

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
}

/**
 * Native back button configuration.
 */
export interface NativeNavigationBackButton {
  /**
   * Show the native back affordance.
   */
  visible?: boolean;

  /**
   * Optional back title.
   */
  title?: string;
}

/**
 * Native navbar state.
 */
export interface NativeNavigationNavbarOptions {
  /**
   * Hide the native navbar.
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
   * Prefer a large iOS title style.
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
   * Back button state.
   */
  backButton?: NativeNavigationBackButton;

  /**
   * Left-side action buttons.
   */
  leftItems?: NativeNavigationBarButton[];

  /**
   * Right-side action buttons.
   */
  rightItems?: NativeNavigationBarButton[];

  /**
   * Navbar color hints.
   */
  colors?: NativeNavigationColors;

  /**
   * Animate native navbar changes.
   */
  animated?: boolean;
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
}

/**
 * Native tabbar layout and background shape options.
 */
export interface NativeNavigationTabbarStyle {
  /**
   * `floating` keeps the existing capsule tabbar. `curve` draws a full-width
   * bar with a center notch and raised center tab.
   */
  shape?: NativeNavigationTabbarShape;

  /**
   * Bar height in native points/dp. Defaults to `64` for `floating` and `76`
   * for `curve`.
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
   * for `floating` and `24` for `curve`.
   */
  cornerRadius?: number;

  /**
   * Tab id promoted into the raised center button for `curve`. Defaults to the
   * middle tab.
   */
  centerItemId?: string;

  /**
   * Raised center button diameter in native points/dp. Defaults to `76`.
   */
  centerButtonDiameter?: number;

  /**
   * Distance from the top of the center button to the top edge of the bar in
   * native points/dp. Defaults to half of `centerButtonDiameter`.
   */
  centerButtonLift?: number;

  /**
   * Raised center button color. Defaults to the active tint color.
   */
  centerButtonColor?: string;

  /**
   * Raised center button icon color. Defaults to white.
   */
  centerButtonIconColor?: string;
}

/**
 * Native tabbar state.
 */
export interface NativeNavigationTabbarOptions {
  /**
   * Hide the native tabbar.
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
   * this tabbar update.
   */
  glass?: NativeNavigationGlassOptions;

  /**
   * Opt into the iOS 26 Liquid Glass tint workaround that renders active and
   * inactive tab labels into icon images. This can affect badge positioning
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
   * Animate native tabbar changes.
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
  tabbarHeight: number;
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

export interface NativeNavigationTabSelectEvent {
  id: string;
  index: number;
  title?: string;
}

export interface NativeNavigationSafeAreaChangedEvent {
  insets: NativeNavigationInsets;
}

export interface NativeNavigationTransitionEvent {
  id: string;
  direction: NativeNavigationTransitionDirection;
  duration: number;
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

  addListener(
    eventName: 'tabSelect',
    listenerFunc: (event: NativeNavigationTabSelectEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'safeAreaChanged',
    listenerFunc: (event: NativeNavigationSafeAreaChangedEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'transitionStart',
    listenerFunc: (event: NativeNavigationTransitionEvent) => void,
  ): Promise<PluginListenerHandle>;

  addListener(
    eventName: 'transitionEnd',
    listenerFunc: (event: NativeNavigationTransitionEvent) => void,
  ): Promise<PluginListenerHandle>;
}
