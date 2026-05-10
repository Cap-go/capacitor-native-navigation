import { registerPlugin } from '@capacitor/core';

import type { NativeNavigationPlugin } from './definitions';

export const NativeNavigation = registerPlugin<NativeNavigationPlugin>('NativeNavigation', {
  web: () => import('./web').then((m) => new m.NativeNavigationWeb()),
});
