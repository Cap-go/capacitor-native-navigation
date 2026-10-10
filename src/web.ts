import { WebPlugin } from '@capacitor/core';

import type {
  NativeNavigationBeginTransitionOptions,
  NativeNavigationConfigureOptions,
  NativeNavigationFinishTransitionOptions,
  NativeNavigationInsets,
  NativeNavigationInsetsResult,
  NativeNavigationNavbarOptions,
  NativeNavigationNavbarScrollEvent,
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
  private navbarScrollCollapsed = false;
  private navbarScrollSamples = new Map<string, number>();
  private navbarScrollListeners: { target: EventTarget; listener: () => void }[] = [];

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
    this.configureNavbarScrollListener();
    return this.applyInsets();
  }

  async reportNavbarScroll(options: NativeNavigationNavbarScrollEvent): Promise<void> {
    this.applyNavbarScrollSample(options.offsetY, options.deltaY);
    await this.applyInsets();
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

  private configureNavbarScrollListener(): void {
    if (typeof window === 'undefined') {
      return;
    }

    for (const binding of this.navbarScrollListeners) {
      binding.target.removeEventListener('scroll', binding.listener);
    }
    this.navbarScrollListeners = [];
    this.navbarScrollSamples.clear();

    const behavior = this.navbar.scrollBehavior ?? 'none';
    if (behavior === 'none' || this.navbar.hidden === true) {
      this.navbarScrollCollapsed = false;
      return;
    }

    const bind = (key: string, target: EventTarget, readOffset: () => number) => {
      const listener = () => {
        const offsetY = readOffset();
        const previous = this.navbarScrollSamples.get(key) ?? offsetY;
        const deltaY = offsetY - previous;
        this.navbarScrollSamples.set(key, offsetY);
        this.applyNavbarScrollSample(offsetY, deltaY);
        void this.applyInsets();
      };
      target.addEventListener('scroll', listener, { passive: true });
      this.navbarScrollListeners.push({ target, listener });
    };

    bind('window', window, () => window.scrollY);
    const app = document.getElementById('app');
    if (app) {
      bind('app', app, () => app.scrollTop);
    }
  }

  private applyNavbarScrollSample(offsetY: number, deltaY: number): void {
    const behavior = this.navbar.scrollBehavior ?? 'none';
    if (behavior === 'none') {
      return;
    }

    const threshold = this.navbar.scrollThreshold ?? 8;
    const atTop = offsetY <= threshold;
    let nextCollapsed = this.navbarScrollCollapsed;

    if (atTop && nextCollapsed) {
      nextCollapsed = false;
    } else if (deltaY > threshold) {
      if (behavior === 'hideOnScrollDown' || behavior === 'both') {
        nextCollapsed = true;
      }
    } else if (deltaY < -threshold) {
      if (behavior === 'revealOnScrollUp' || behavior === 'both') {
        nextCollapsed = false;
      }
    }

    this.navbarScrollCollapsed = nextCollapsed;
  }

  private applyInsets(): NativeNavigationInsetsResult {
    const enabled = this.config.enabled !== false;
    const navbarVisible = enabled && this.navbar.hidden !== true;
    const tabbarVisible = enabled && this.tabbar.hidden !== true;
    const tabbarHeight = tabbarVisible ? this.currentTabbarHeight() : 0;
    const navbarChromeHeight =
      navbarVisible && !this.navbarScrollCollapsed ? DEFAULT_NAVBAR_HEIGHT : navbarVisible ? 0 : 0;
    const insets: NativeNavigationInsets = {
      top: navbarVisible ? (this.navbarScrollCollapsed ? 0 : DEFAULT_NAVBAR_HEIGHT) : 0,
      right: 0,
      bottom: tabbarHeight,
      left: 0,
      navbarHeight: navbarChromeHeight,
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
      if (this.navbar.scrollBehavior && this.navbar.scrollBehavior !== 'none') {
        root.classList.toggle('cap-native-navbar-scroll-collapsed', this.navbarScrollCollapsed);
      } else {
        root.classList.remove('cap-native-navbar-scroll-collapsed');
      }
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
