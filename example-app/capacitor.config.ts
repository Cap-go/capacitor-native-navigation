import type { CapacitorConfig } from '@capacitor/cli';

import pkg from './package.json' with { type: 'json' };

const screenshotBuild = process.env.VITE_SCREENSHOT_MODE === 'floating-tabbar';

const config: CapacitorConfig = {
  appId: 'app.capgo.native.navigation.example',
  appName: '@capgo/capacitor-native-navigation',
  webDir: 'dist',
  plugins: {
    CapacitorUpdater: {
      appId: 'app.capgo.native.navigation.example',
      autoUpdate: !screenshotBuild,
      autoSplashscreen: !screenshotBuild,
      directUpdate: screenshotBuild ? 'never' : 'always',
      defaultChannel: 'production',
      version: pkg.version,
    },
  },
  android: {
    webContentsDebuggingEnabled: true,
  },
};

export default config;
