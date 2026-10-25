import type { NativeNavigationPlugin } from './definitions';

let webPlugin: Promise<NativeNavigationPlugin> | null = null;

/**
 * One web implementation for every concurrent `registerPlugin` call.
 * Capacitor can invoke this factory twice before the first import settles,
 * and a second instance would drop `addListener` events from `setNavbar`.
 */
export const createNativeNavigationWeb = (): Promise<NativeNavigationPlugin> => {
  webPlugin ??= import('./web')
    .then((m) => new m.NativeNavigationWeb())
    .catch((error: unknown) => {
      webPlugin = null;
      throw error;
    });
  return webPlugin;
};
