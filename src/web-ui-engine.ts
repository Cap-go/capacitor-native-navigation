export const NATIVE_NAVIGATION_NAVBAR_SLOT_ID = 'cap-native-navigation-navbar-slot';
export const NATIVE_NAVIGATION_TABBAR_SLOT_ID = 'cap-native-navigation-tabbar-slot';
export const NATIVE_NAVIGATION_NAVBAR_SLOT_SELECTOR = `#${NATIVE_NAVIGATION_NAVBAR_SLOT_ID}`;
export const NATIVE_NAVIGATION_TABBAR_SLOT_SELECTOR = `#${NATIVE_NAVIGATION_TABBAR_SLOT_ID}`;

const SLOT_STYLE = [
  'position:fixed',
  'left:0',
  'right:0',
  'pointer-events:none',
  'z-index:0',
  'overflow:hidden',
  'margin:0',
  'padding:0',
  'border:0',
].join(';');

let ionicOverlaysEnabled = false;
let activationGeneration = 0;

const ensureSlot = (doc: Document, id: string, placement: 'top' | 'bottom'): HTMLElement => {
  const existing = doc.getElementById(id);
  if (existing instanceof HTMLElement) {
    return existing;
  }
  const slot = doc.createElement('div');
  slot.id = id;
  slot.setAttribute('data-cap-native-navigation-projection-slot', placement);
  slot.setAttribute('aria-hidden', 'true');
  slot.style.cssText =
    placement === 'top'
      ? `${SLOT_STYLE};top:0;height:var(--cap-native-navbar-height, 0px)`
      : `${SLOT_STYLE};bottom:0;height:max(var(--cap-native-tabbar-height, 0px), var(--cap-native-system-tabbar-height, 0px))`;
  doc.documentElement.appendChild(slot);
  return slot;
};

export const ensureProjectionSlots = (doc: Document = globalThis.document!): void => {
  if (!doc) {
    return;
  }
  ensureSlot(doc, NATIVE_NAVIGATION_NAVBAR_SLOT_ID, 'top');
  ensureSlot(doc, NATIVE_NAVIGATION_TABBAR_SLOT_ID, 'bottom');
};

export const activateWebNativeUIEngine = async (): Promise<void> => {
  const generation = ++activationGeneration;
  ensureProjectionSlots();
  if (ionicOverlaysEnabled) {
    return;
  }
  ionicOverlaysEnabled = true;
  const { enableSupportIonicOverlays } = await import('@webview-native-ui/engine/ionic');
  if (generation !== activationGeneration) {
    ionicOverlaysEnabled = false;
    return;
  }
  enableSupportIonicOverlays();
};

export const deactivateWebNativeUIEngine = (): void => {
  activationGeneration += 1;
  ionicOverlaysEnabled = false;
};

export const isWebNativeUIEngineActive = (): boolean => ionicOverlaysEnabled;
