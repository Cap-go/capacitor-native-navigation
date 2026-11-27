import { registerPlugin } from '@capacitor/core';

import type {
  NativeNavigationBeginTransitionOptions,
  NativeNavigationConfigureOptions,
  NativeNavigationFinishTransitionOptions,
  NativeNavigationPlugin,
  NativeNavigationRect,
  NativeNavigationTransitionResult,
} from './definitions';
import { createNativeNavigationWeb } from './plugin';
import { activateWebNativeUIEngine, deactivateWebNativeUIEngine } from './web-ui-engine';

const nativeNavigationPlugin = registerPlugin<NativeNavigationPlugin>('NativeNavigation', {
  web: createNativeNavigationWeb,
});

async function syncWebNativeUIEngine(options?: NativeNavigationConfigureOptions): Promise<void> {
  if (options?.webNativeUIEngine === true) {
    await activateWebNativeUIEngine();
    return;
  }
  if (options?.webNativeUIEngine === false) {
    deactivateWebNativeUIEngine();
  }
}

const configureNativeNavigation = async (
  options?: NativeNavigationConfigureOptions,
): Promise<Awaited<ReturnType<NativeNavigationPlugin['configure']>>> => {
  const result = await nativeNavigationPlugin.configure(options);
  await syncWebNativeUIEngine(options);
  return result;
};

export const NativeNavigation: NativeNavigationPlugin = new Proxy(nativeNavigationPlugin, {
  get(target, prop, receiver) {
    if (prop === 'configure') {
      return configureNativeNavigation;
    }
    const value = Reflect.get(target, prop, receiver);
    if (typeof value === 'function') {
      return (value as (...args: unknown[]) => unknown).bind(target);
    }
    return value;
  },
});

export * from './definitions';
export { defineNativeNavigationElements } from './components';

type NativeNavigationRectTarget = Element | DOMRect | NativeNavigationRect;

const isElement = (target: NativeNavigationRectTarget): target is Element =>
  typeof Element !== 'undefined' && target instanceof Element;

const isDomRect = (target: NativeNavigationRectTarget): target is DOMRect =>
  typeof DOMRect !== 'undefined' && target instanceof DOMRect;

/**
 * Convert an element or DOMRect into viewport coordinates accepted by native
 * zoom transitions.
 */
export const getNativeNavigationRect = (target: NativeNavigationRectTarget): NativeNavigationRect => {
  const rect = isElement(target) ? target.getBoundingClientRect() : target;
  if (isDomRect(rect)) {
    return {
      x: rect.x,
      y: rect.y,
      width: rect.width,
      height: rect.height,
    };
  }
  return {
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
  };
};

/**
 * Begin an Apple-Zoom-style native transition from a DOM element or rect.
 */
export const beginZoomTransition = (
  target: NativeNavigationRectTarget,
  options: Omit<NativeNavigationBeginTransitionOptions, 'direction' | 'sourceRect'> = {},
): Promise<NativeNavigationTransitionResult> =>
  NativeNavigation.beginTransition({
    ...options,
    direction: 'zoom',
    sourceRect: getNativeNavigationRect(target),
  });

/**
 * Finish an Apple-Zoom-style native transition into an optional DOM element or
 * rect on the destination route.
 */
export const finishZoomTransition = (
  target?: NativeNavigationRectTarget,
  options: Omit<NativeNavigationFinishTransitionOptions, 'direction' | 'targetRect'> = {},
): Promise<NativeNavigationTransitionResult> =>
  NativeNavigation.finishTransition({
    ...options,
    direction: 'zoom',
    targetRect: target ? getNativeNavigationRect(target) : undefined,
  });
