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
  NativeNavigationPullToRefreshOptions,
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
  private searchApplying = false;

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
    if (options.resetScrollCollapsed) {
      this.navbarScrollCollapsed = false;
    }

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

  async setPullToRefresh(_options: NativeNavigationPullToRefreshOptions): Promise<void> {
    // Browsers own pull-to-refresh on the web.
  }

  async endPullToRefresh(): Promise<void> {
    // Nothing to stop on the web.
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

  private navbarContentHeight(): number {
    return DEFAULT_NAVBAR_HEIGHT + this.searchRowHeight();
  }

  private searchRowHeight(): number {
    const search = this.navbar.search;
    if (!search || search.hidden) {
      return 0;
    }
    return 52;
  }

  private tabbarEdges(): { left: number; right: number; bottom: number; cross: number } {
    const placement = this.tabbar.style?.placement;
    const shape = this.tabbar.style?.shape;
    if (placement === 'sidebar' && shape !== 'curve') {
      const rail = 96;
      const rtl = this.tabbar.layoutDirection === 'rtl';
      return { left: rtl ? rail : 0, right: rtl ? 0 : rail, bottom: 0, cross: rail };
    }
    return { left: 0, right: 0, bottom: this.currentTabbarHeight(), cross: 0 };
  }

  private ensureSearchStyles(): void {
    if (document.getElementById('cap-native-navigation-search-style')) {
      return;
    }
    const style = document.createElement('style');
    style.id = 'cap-native-navigation-search-style';
    style.textContent = `
      #cap-native-navigation-search {
        position: fixed;
        z-index: 30;
        display: flex;
        align-items: center;
        box-sizing: border-box;
        margin: 0;
        padding: 0;
        pointer-events: auto;
      }
      #cap-native-navigation-search input {
        width: 100%;
        height: 36px;
        border: 0;
        border-radius: 10px;
        padding: 0 12px;
        font: inherit;
        font-size: 17px;
        color: light-dark(#111827, #f8fafc);
        background: light-dark(rgba(120, 120, 128, 0.16), rgba(120, 120, 128, 0.32));
      }
      #cap-native-navigation-search input:focus-visible {
        outline: 2px solid #0a84ff;
        outline-offset: 1px;
      }
    `;
    document.head.append(style);
  }

  private syncSearchChrome(navbarHeight: number): void {
    if (typeof document === 'undefined') {
      return;
    }
    const existing = document.getElementById('cap-native-navigation-search');
    const visible = navbarHeight > 0 && this.searchRowHeight() > 0;
    if (!visible) {
      existing?.remove();
      return;
    }

    this.ensureSearchStyles();
    let form = existing;
    if (!form) {
      form = document.createElement('form');
      form.id = 'cap-native-navigation-search';
      form.setAttribute('role', 'search');
      const input = document.createElement('input');
      input.type = 'search';
      input.enterKeyHint = 'search';
      input.autocomplete = 'off';
      input.setAttribute('aria-label', 'Search');
      input.addEventListener('input', () => {
        if (this.searchApplying) {
          return;
        }
        this.emitSearch(input.value, 'input');
      });
      input.addEventListener('search', () => {
        if (input.value === '') {
          this.emitSearch('', 'cancel');
        }
      });
      form.addEventListener('submit', (event) => {
        event.preventDefault();
        const field = form?.querySelector('input');
        this.emitSearch(field?.value ?? '', 'submit');
      });
      form.append(input);
      document.body.append(form);
    }

    const input = form.querySelector('input');
    if (!input) {
      return;
    }
    const search = this.navbar.search;
    input.placeholder = search?.placeholder || 'Search';
    input.disabled = search?.enabled === false;
    const text = search?.text ?? '';
    if (document.activeElement !== input && input.value !== text) {
      this.searchApplying = true;
      input.value = text;
      this.searchApplying = false;
    }
    const row = this.searchRowHeight();
    const tabbarVisible = this.config.enabled !== false && this.tabbar.hidden !== true;
    const edges = tabbarVisible ? this.tabbarEdges() : { left: 0, right: 0, bottom: 0, cross: 0 };
    form.style.top = `calc(env(safe-area-inset-top, 0px) + ${Math.max(0, navbarHeight - row)}px)`;
    form.style.height = `${row}px`;
    form.style.left = `${16 + edges.left}px`;
    form.style.right = `${16 + edges.right}px`;
  }

  private emitSearch(text: string, reason: 'input' | 'submit' | 'cancel'): void {
    const event = { text, reason };
    this.notifyListeners('navbarSearch', event);
    this.dispatchWindowEvent('navbarSearch', event);
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

    const readOffset = (target: Window | HTMLElement) => {
      if (target === window) {
        const raw = window.scrollY;
        const max = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
        return Math.min(Math.max(0, raw), max);
      }
      const element = target as HTMLElement;
      const raw = element.scrollTop;
      const max = Math.max(0, element.scrollHeight - element.clientHeight);
      return Math.min(Math.max(0, raw), max);
    };

    bind('window', window, () => readOffset(window));
    const app = document.getElementById('app');
    if (app) {
      bind('app', app, () => readOffset(app));
    }
    document.querySelectorAll('[data-cap-native-navigation-scroll]').forEach((node, index) => {
      if (node instanceof HTMLElement) {
        bind(`scroll-root-${index}`, node, () => readOffset(node));
      }
    });
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
    const navbarChromeHeight = navbarVisible && !this.navbarScrollCollapsed ? this.navbarContentHeight() : 0;
    const tabbarEdges = tabbarVisible ? this.tabbarEdges() : { left: 0, right: 0, bottom: 0, cross: 0 };
    const insets: NativeNavigationInsets = {
      top: navbarChromeHeight,
      right: tabbarEdges.right,
      bottom: tabbarEdges.bottom,
      left: tabbarEdges.left,
      navbarHeight: navbarChromeHeight,
      tabbarHeight: tabbarEdges.cross || tabbarEdges.bottom,
      systemTabbarHeight: tabbarEdges.cross || tabbarEdges.bottom,
    };

    if (this.config.contentInsetMode !== 'none' && typeof document !== 'undefined') {
      const root = document.documentElement;
      root.style.setProperty('--cap-native-navigation-top', `${insets.top}px`);
      root.style.setProperty('--cap-native-navigation-right', `${insets.right}px`);
      root.style.setProperty('--cap-native-navigation-bottom', `${insets.bottom}px`);
      root.style.setProperty('--cap-native-navigation-left', `${insets.left}px`);
      root.style.setProperty('--cap-native-navbar-height', `${insets.navbarHeight}px`);
      root.style.setProperty('--cap-native-tabbar-height', `${insets.tabbarHeight}px`);
      root.style.setProperty('--cap-native-system-tabbar-height', `${insets.systemTabbarHeight}px`);
      if (this.navbar.scrollBehavior && this.navbar.scrollBehavior !== 'none') {
        root.classList.toggle('cap-native-navbar-scroll-collapsed', this.navbarScrollCollapsed);
      } else {
        root.classList.remove('cap-native-navbar-scroll-collapsed');
      }
    }

    this.syncSearchChrome(navbarChromeHeight);
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
