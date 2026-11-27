import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

test('webNativeUIEngine defaults to off when omitted from configure merge', () => {
  const previous = { webNativeUIEngine: false };
  const incoming = { enabled: true };
  const merged = { ...previous, ...incoming };
  assert.equal(merged.webNativeUIEngine, false);
});

test('projection slot ids stay stable', async () => {
  const { NATIVE_NAVIGATION_NAVBAR_SLOT_ID, NATIVE_NAVIGATION_TABBAR_SLOT_ID } =
    await import('../dist/esm/web-ui-engine.js');
  assert.equal(NATIVE_NAVIGATION_NAVBAR_SLOT_ID, 'cap-native-navigation-navbar-slot');
  assert.equal(NATIVE_NAVIGATION_TABBAR_SLOT_ID, 'cap-native-navigation-tabbar-slot');
});

test('exported NativeNavigation uses a Proxy configure wrapper', async () => {
  const src = await readFile(new URL('../dist/esm/index.js', import.meta.url), 'utf8');
  assert.match(src, /new Proxy\(nativeNavigationPlugin/);
  assert.match(src, /prop === 'configure'/);
  assert.match(src, /syncWebNativeUIEngine/);
});