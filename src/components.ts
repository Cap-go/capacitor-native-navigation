import type {
  NativeNavigationConfigureOptions,
  NativeNavigationNavbarOptions,
  NativeNavigationTabbarOptions,
} from './definitions';

const parseBoolean = (value: string | null, defaultValue = false): boolean => {
  if (value === null) {
    return defaultValue;
  }
  return value === '' || value === 'true' || value === '1';
};

const normalizeAttribute = (value: string | null): string | undefined => (value ? value : undefined);

const typedAttribute = <T extends string>(element: Element, name: string): T | undefined =>
  normalizeAttribute(element.getAttribute(name)) as T | undefined;

const parseJsonAttribute = <T>(element: Element, name: string, fallback: T): T => {
  const value = element.getAttribute(name);
  if (!value) {
    return fallback;
  }

  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
};

const getNativeNavigation = async () => (await import('./index')).NativeNavigation;

export function defineNativeNavigationElements(): void {
  if (typeof customElements === 'undefined' || typeof HTMLElement === 'undefined') {
    return;
  }

  class CapNativeNavigationProvider extends HTMLElement {
    static get observedAttributes(): string[] {
      return ['enabled', 'platform-style', 'content-inset-mode', 'animation-duration', 'colors'];
    }

    connectedCallback(): void {
      void this.sync();
    }

    attributeChangedCallback(): void {
      if (this.isConnected) {
        void this.sync();
      }
    }

    private async sync(): Promise<void> {
      const duration = this.getAttribute('animation-duration');
      const options: NativeNavigationConfigureOptions = {
        enabled: parseBoolean(this.getAttribute('enabled'), true),
        platformStyle:
          typedAttribute<NonNullable<NativeNavigationConfigureOptions['platformStyle']>>(this, 'platform-style') ??
          'auto',
        contentInsetMode:
          typedAttribute<NonNullable<NativeNavigationConfigureOptions['contentInsetMode']>>(
            this,
            'content-inset-mode',
          ) ?? 'css',
        colors: parseJsonAttribute(this, 'colors', undefined as NativeNavigationConfigureOptions['colors']),
      };

      if (duration) {
        options.animationDuration = Number(duration);
      }

      const NativeNavigation = await getNativeNavigation();
      await NativeNavigation.configure(options);
    }
  }

  class CapNativeNavbar extends HTMLElement {
    static get observedAttributes(): string[] {
      return [
        'hidden',
        'title',
        'subtitle',
        'large',
        'transparent',
        'blur-effect',
        'back-button',
        'back-title',
        'left-items',
        'right-items',
        'colors',
        'animated',
      ];
    }

    connectedCallback(): void {
      void this.sync();
    }

    attributeChangedCallback(): void {
      if (this.isConnected) {
        void this.sync();
      }
    }

    private async sync(): Promise<void> {
      const options: NativeNavigationNavbarOptions = {
        hidden: parseBoolean(this.getAttribute('hidden')),
        title: this.getAttribute('title') ?? undefined,
        subtitle: this.getAttribute('subtitle') ?? undefined,
        large: parseBoolean(this.getAttribute('large')),
        transparent: parseBoolean(this.getAttribute('transparent')),
        blurEffect: typedAttribute<NonNullable<NativeNavigationNavbarOptions['blurEffect']>>(this, 'blur-effect'),
        backButton: {
          visible: parseBoolean(this.getAttribute('back-button')),
          title: normalizeAttribute(this.getAttribute('back-title')),
        },
        leftItems: parseJsonAttribute(this, 'left-items', []),
        rightItems: parseJsonAttribute(this, 'right-items', []),
        colors: parseJsonAttribute(this, 'colors', undefined as NativeNavigationNavbarOptions['colors']),
        animated: parseBoolean(this.getAttribute('animated')),
      };

      const NativeNavigation = await getNativeNavigation();
      await NativeNavigation.setNavbar(options);
    }
  }

  class CapNativeTabbar extends HTMLElement {
    static get observedAttributes(): string[] {
      return [
        'hidden',
        'tabs',
        'selected-id',
        'labels',
        'label-visibility-mode',
        'icons',
        'colors',
        'blur-effect',
        'disable-indicator',
        'indicator-color',
        'ripple-color',
        'badge-background-color',
        'badge-text-color',
        'animated',
      ];
    }

    connectedCallback(): void {
      void this.sync();
    }

    attributeChangedCallback(): void {
      if (this.isConnected) {
        void this.sync();
      }
    }

    private async sync(): Promise<void> {
      const options: NativeNavigationTabbarOptions = {
        hidden: parseBoolean(this.getAttribute('hidden')),
        tabs: parseJsonAttribute(this, 'tabs', []),
        selectedId: normalizeAttribute(this.getAttribute('selected-id')),
        labels: parseBoolean(this.getAttribute('labels'), true),
        labelVisibilityMode: typedAttribute<NonNullable<NativeNavigationTabbarOptions['labelVisibilityMode']>>(
          this,
          'label-visibility-mode',
        ),
        icons: parseBoolean(this.getAttribute('icons'), true),
        colors: parseJsonAttribute(this, 'colors', undefined as NativeNavigationTabbarOptions['colors']),
        blurEffect: typedAttribute<NonNullable<NativeNavigationTabbarOptions['blurEffect']>>(this, 'blur-effect'),
        disableIndicator: parseBoolean(this.getAttribute('disable-indicator')),
        indicatorColor: normalizeAttribute(this.getAttribute('indicator-color')),
        rippleColor: normalizeAttribute(this.getAttribute('ripple-color')),
        badgeBackgroundColor: normalizeAttribute(this.getAttribute('badge-background-color')),
        badgeTextColor: normalizeAttribute(this.getAttribute('badge-text-color')),
        animated: parseBoolean(this.getAttribute('animated')),
      };

      const NativeNavigation = await getNativeNavigation();
      await NativeNavigation.setTabbar(options);
    }
  }

  if (!customElements.get('cap-native-navigation-provider')) {
    customElements.define('cap-native-navigation-provider', CapNativeNavigationProvider);
  }
  if (!customElements.get('cap-native-navbar')) {
    customElements.define('cap-native-navbar', CapNativeNavbar);
  }
  if (!customElements.get('cap-native-tabbar')) {
    customElements.define('cap-native-tabbar', CapNativeTabbar);
  }
}
