import type { NativeNavigationPlugin } from './definitions';

export const createNativeNavigationWeb = (): Promise<NativeNavigationPlugin> =>
  import('./web').then((m) => new m.NativeNavigationWeb());
