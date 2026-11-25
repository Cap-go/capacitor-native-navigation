import type { CapacitorConfig } from '@capacitor/cli';

import pkg from './package.json' with { type: 'json' };

const screenshotBuild = Boolean(process.env.VITE_SCREENSHOT_MODE);

const config: CapacitorConfig = {
  appId: 'app.capgo.native.navigation.example',
  appName: '@capgo/capacitor-native-navigation',
  webDir: 'dist',
  plugins: {
    NativeNavigation: {
      webNativeUIEngine: process.env.VITE_WEB_NATIVE_UI_ENGINE === 'true',
    },
    CapacitorUpdater: {
      appId: 'app.capgo.native.navigation.example',
      autoUpdate: !screenshotBuild,
      autoSplashscreen: !screenshotBuild,
      directUpdate: screenshotBuild ? false : 'always',
      defaultChannel: 'production',
      version: pkg.version,
    },
  },
  android: {
    webContentsDebuggingEnabled: true,
  },
};

export default config;
