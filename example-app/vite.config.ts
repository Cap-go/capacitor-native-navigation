import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

const currentDir = dirname(fileURLToPath(import.meta.url));
const localPluginEntry = resolve(currentDir, '../dist/esm/index.js');

export default defineConfig({
  resolve: {
    alias: existsSync(localPluginEntry)
      ? {
          '@capgo/capacitor-native-navigation': localPluginEntry,
        }
      : {},
  },
  server: {
    open: true,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
