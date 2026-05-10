import type {
  NativeNavigationConfigureOptions,
  NativeNavigationNavbarOptions,
  NativeNavigationTabbarOptions,
} from './definitions';
import { NativeNavigation } from './plugin';

const parseBoolean = (value: string | null, defaultValue = false): boolean => {
  if (value === null) {
    return defaultValue;
  }
  return value === '' || value === 'true' || value === '1';
};

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
          (this.getAttribute('platform-style') as NativeNavigationConfigureOptions['platformStyle']) ?? 'auto',
        contentInsetMode:
          (this.getAttribute('content-inset-mode') as NativeNavigationConfigureOptions['contentInsetMode']) ?? 'css',
        colors: parseJsonAttribute(this, 'colors', undefined as NativeNavigationConfigureOptions['colors']),
      };

      if (duration) {
        options.animationDuration = Number(duration);
      }

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
        backButton: {
          visible: parseBoolean(this.getAttribute('back-button')),
          title: this.getAttribute('back-title') ?? undefined,
        },
        leftItems: parseJsonAttribute(this, 'left-items', []),
        rightItems: parseJsonAttribute(this, 'right-items', []),
        colors: parseJsonAttribute(this, 'colors', undefined as NativeNavigationNavbarOptions['colors']),
        animated: parseBoolean(this.getAttribute('animated')),
      };

      await NativeNavigation.setNavbar(options);
    }
  }

  class CapNativeTabbar extends HTMLElement {
    static get observedAttributes(): string[] {
      return ['hidden', 'tabs', 'selected-id', 'labels', 'icons', 'colors', 'animated'];
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
        selectedId: this.getAttribute('selected-id') ?? undefined,
        labels: parseBoolean(this.getAttribute('labels'), true),
        icons: parseBoolean(this.getAttribute('icons'), true),
        colors: parseJsonAttribute(this, 'colors', undefined as NativeNavigationTabbarOptions['colors']),
        animated: parseBoolean(this.getAttribute('animated')),
      };

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
