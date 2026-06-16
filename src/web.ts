import { WebPlugin } from '@capacitor/core';

import type {
  NativeNavigationBeginTransitionOptions,
  NativeNavigationConfigureOptions,
  NativeNavigationFinishTransitionOptions,
  NativeNavigationInsets,
  NativeNavigationInsetsResult,
  NativeNavigationNavbarOptions,
  NativeNavigationPlugin,
  NativeNavigationTabbarOptions,
  NativeNavigationTransitionDirection,
  NativeNavigationTransitionResult,
  PluginVersionResult,
} from './definitions';

const DEFAULT_NAVBAR_HEIGHT = 44;
const DEFAULT_TABBAR_HEIGHT = 49;
const DEFAULT_TRANSITION_DURATION = 350;

export class NativeNavigationWeb extends WebPlugin implements NativeNavigationPlugin {
  private config: NativeNavigationConfigureOptions = {
    contentInsetMode: 'css',
    enabled: true,
    platformStyle: 'auto',
  };
  private navbar: NativeNavigationNavbarOptions = { hidden: true };
  private tabbar: NativeNavigationTabbarOptions = { hidden: true };
  private activeTransition: NativeNavigationTransitionResult | null = null;

  async configure(options: NativeNavigationConfigureOptions = {}): Promise<NativeNavigationInsetsResult> {
    this.config = {
      ...this.config,
      ...options,
      colors: {
        ...this.config.colors,
        ...options.colors,
      },
      glass: {
        ...this.config.glass,
        ...options.glass,
      },
    };
    return this.applyInsets();
  }

  async setNavbar(options: NativeNavigationNavbarOptions): Promise<NativeNavigationInsetsResult> {
    this.navbar = {
      ...this.navbar,
      ...options,
      colors: {
        ...this.navbar.colors,
        ...options.colors,
      },
      glass: {
        ...this.navbar.glass,
        ...options.glass,
      },
    };
    return this.applyInsets();
  }

  async setTabbar(options: NativeNavigationTabbarOptions): Promise<NativeNavigationInsetsResult> {
    this.tabbar = {
      ...this.tabbar,
      ...options,
      colors: {
        ...this.tabbar.colors,
        ...options.colors,
      },
      style: {
        ...this.tabbar.style,
        ...options.style,
      },
      glass: {
        ...this.tabbar.glass,
        ...options.glass,
      },
    };
    return this.applyInsets();
  }

  async beginTransition(
    options: NativeNavigationBeginTransitionOptions = {},
  ): Promise<NativeNavigationTransitionResult> {
    const transition = this.createTransition(options.id, options.direction, options.duration);
    this.activeTransition = transition;
    this.notifyListeners('transitionStart', transition);
    this.dispatchWindowEvent('transitionStart', transition);
    return transition;
  }

  async finishTransition(
    options: NativeNavigationFinishTransitionOptions = {},
  ): Promise<NativeNavigationTransitionResult> {
    const transition =
      this.activeTransition && (!options.id || options.id === this.activeTransition.id)
        ? {
            ...this.activeTransition,
            direction: options.direction ?? this.activeTransition.direction,
            duration: options.duration ?? this.activeTransition.duration,
          }
        : this.createTransition(options.id, options.direction, options.duration);

    this.activeTransition = null;
    this.notifyListeners('transitionEnd', transition);
    this.dispatchWindowEvent('transitionEnd', transition);
    return transition;
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return {
      version: 'web',
    };
  }

  private createTransition(
    id = `transition-${Date.now()}`,
    direction: NativeNavigationTransitionDirection = 'forward',
    duration = this.config.animationDuration ?? DEFAULT_TRANSITION_DURATION,
  ): NativeNavigationTransitionResult {
    return { id, direction, duration };
  }

  private currentTabbarHeight(): number {
    const style = this.tabbar.style;
    if (!style) {
      return DEFAULT_TABBAR_HEIGHT;
    }

    const defaultHeight = style.shape === 'curve' ? 76 : style.shape === 'floating' ? 64 : DEFAULT_TABBAR_HEIGHT;
    const height = style.height ?? defaultHeight;
    const bottomGap = style.bottomGap ?? (style.shape === 'curve' ? 0 : 10);
    const centerButtonLift =
      style.shape === 'curve' ? (style.centerButtonLift ?? (style.centerButtonDiameter ?? 56) / 2) : 0;
    return Math.ceil(height + bottomGap + centerButtonLift);
  }

  private applyInsets(): NativeNavigationInsetsResult {
    const enabled = this.config.enabled !== false;
    const navbarVisible = enabled && this.navbar.hidden !== true;
    const tabbarVisible = enabled && this.tabbar.hidden !== true;
    const tabbarHeight = tabbarVisible ? this.currentTabbarHeight() : 0;
    const insets: NativeNavigationInsets = {
      top: navbarVisible ? DEFAULT_NAVBAR_HEIGHT : 0,
      right: 0,
      bottom: tabbarHeight,
      left: 0,
      navbarHeight: navbarVisible ? DEFAULT_NAVBAR_HEIGHT : 0,
      tabbarHeight,
    };

    if (this.config.contentInsetMode !== 'none' && typeof document !== 'undefined') {
      const root = document.documentElement;
      root.style.setProperty('--cap-native-navigation-top', `${insets.top}px`);
      root.style.setProperty('--cap-native-navigation-right', `${insets.right}px`);
      root.style.setProperty('--cap-native-navigation-bottom', `${insets.bottom}px`);
      root.style.setProperty('--cap-native-navigation-left', `${insets.left}px`);
      root.style.setProperty('--cap-native-navbar-height', `${insets.navbarHeight}px`);
      root.style.setProperty('--cap-native-tabbar-height', `${insets.tabbarHeight}px`);
    }

    const event = { insets };
    this.notifyListeners('safeAreaChanged', event);
    this.dispatchWindowEvent('safeAreaChanged', event);
    return { insets };
  }

  private dispatchWindowEvent(name: string, detail: unknown): void {
    if (typeof window === 'undefined') {
      return;
    }
    window.dispatchEvent(new CustomEvent(`capNativeNavigation:${name}`, { detail }));
  }
}
