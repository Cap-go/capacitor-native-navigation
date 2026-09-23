import './style.css';
import { Capacitor } from '@capacitor/core';
import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { NativeNavigation } from '@capgo/capacitor-native-navigation';

const app = document.getElementById('app');
const isWebPreview = Capacitor.getPlatform() === 'web';
const topButtonStorageKey = 'native-navigation-top-button-visible';

const readTopButtonPreference = () => {
  try {
    return window.localStorage.getItem(topButtonStorageKey) !== 'false';
  } catch {
    return true;
  }
};

const writeTopButtonPreference = (visible) => {
  try {
    window.localStorage.setItem(topButtonStorageKey, visible ? 'true' : 'false');
  } catch {
    // Ignore storage failures in restricted webviews.
  }
};

void CapacitorUpdater.notifyAppReady().catch((error) => {
  console.warn('Capgo updater notifyAppReady failed', error);
});

const icons = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/></svg>',
  activity:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19V5"/><path d="M9 19V9"/><path d="M14 19v-7"/><path d="M19 19V7"/></svg>',
  camera:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 4h-5L8 6H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-3z"/><circle cx="12" cy="13" r="3.5"/></svg>',
  settings:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="m4.93 4.93 2.12 2.12"/><path d="m16.95 16.95 2.12 2.12"/><path d="M2 12h3"/><path d="M19 12h3"/><path d="m4.93 19.07 2.12-2.12"/><path d="m16.95 7.05 2.12-2.12"/></svg>',
  profile:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21a8 8 0 0 0-16 0"/><circle cx="12" cy="7" r="4"/></svg>',
  compose:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>',
  star: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1L12 16.8 6.6 19.8l1-6.1L3.2 9.4l6.1-.9Z"/></svg>',
};

const tabs = [
  {
    id: 'home',
    title: 'Home',
    icon: { svg: icons.home },
  },
  {
    id: 'activity',
    title: 'Activity',
    icon: { svg: icons.activity },
    badge: 3,
  },
  {
    id: 'capture',
    title: 'Capture',
    icon: { svg: icons.camera, width: 30, height: 30 },
  },
  {
    id: 'settings',
    title: 'Settings',
    icon: { svg: icons.settings },
  },
  {
    id: 'profile',
    title: 'Profile',
    icon: { svg: icons.profile },
  },
  {
    id: 'draft',
    title: 'Draft',
    icon: { svg: icons.compose },
    hidden: true,
  },
];

let activeTab = 'home';
let route = 'home';
let stack = ['home'];
let labelsEnabled = true;
let iconsEnabled = true;
let tabbarPreset = 'system';
let tabbarHidden = false;
let shapeOverride = null;
let removedTabIds = [];
let addedTabIds = [];
let activityBadge = 3;
let standardBarHeight = true;
const itemPatches = {};
const activityTitles = ['Activity', 'Inbox', 'Updates'];
const activityIcons = [icons.activity, icons.star];

const tabbarPresets = {
  system: {
    label: 'System',
    detail: 'Apple tab bar. No center button.',
    shape: 'floating',
  },
  trailing: {
    label: 'Trailing',
    detail: 'Floating bar plus a detached search button.',
    shape: 'floating',
  },
  center: {
    label: 'Center',
    detail: 'Full-width bar with an included center button.',
    shape: 'curve',
  },
};

const addableTabs = [
  {
    id: 'draft',
    title: 'Draft',
    icon: { svg: icons.compose },
  },
  {
    id: 'alerts',
    title: 'Alerts',
    icon: { svg: icons.activity },
  },
  {
    id: 'search',
    title: 'Search',
    icon: { svg: icons.profile },
  },
];

const tabbarShape = () => shapeOverride ?? tabbarPresets[tabbarPreset].shape;

const withItemPatch = (tab) => {
  const patch = itemPatches[tab.id];
  const patched = patch ? { ...tab, ...patch } : tab;
  if (patched.id !== 'activity') {
    return patched;
  }
  return { ...patched, badge: activityBadge > 0 ? activityBadge : '' };
};

const currentTabs = () => {
  const base = tabs
    .filter((tab) => tab.id !== 'draft' && !removedTabIds.includes(tab.id))
    .map(withItemPatch);
  const extras = addableTabs.filter((tab) => addedTabIds.includes(tab.id)).map(withItemPatch);
  return [...base, ...extras];
};
let topButtonVisible = readTopButtonPreference();
let chromeConfigured = false;
const pages = {
  home: {
    title: 'Layouts',
    subtitle: 'Switch the native tab bar',
    body: `
      <section class="layout-presets" aria-label="Tab bar layouts"></section>
      <section class="venue-strip" aria-label="Curved tabbar demo content">
        <article class="venue-card venue-card-bar">
          <span>BAR</span>
          <strong>Hidden bar</strong>
        </article>
        <article class="venue-card venue-card-food">
          <span>RESTAURANT</span>
          <strong>Pizza room</strong>
        </article>
      </section>
      <section class="demo-actions" aria-label="Navigation demo actions">
        <button class="tile" data-push="detail">
          <span>Open detail</span>
          <small>Push transition and native back button</small>
        </button>
        <button class="tile" data-action="toggle-tabbar">
          <span>Toggle tabbar</span>
          <small>Dynamic visibility from JavaScript</small>
        </button>
        <button class="tile" data-action="add-tab">
          <span>Add tab</span>
          <small>Insert another item in the bar</small>
        </button>
        <button class="tile" data-action="remove-tab">
          <span>Remove tab</span>
          <small>Drop the last item</small>
        </button>
        <button class="tile" data-action="toggle-labels">
          <span>Labels</span>
          <small id="labels-state">Shown</small>
        </button>
        <button class="tile" data-action="toggle-icons">
          <span>Icons</span>
          <small id="icons-state">Shown</small>
        </button>
        <button class="tile" data-action="toggle-floating">
          <span>Floating</span>
          <small id="floating-state">Follows the layout</small>
        </button>
        <button class="tile" data-action="toggle-badge">
          <span>Badge</span>
          <small id="badge-state">Activity count on</small>
        </button>
        <button class="tile" data-action="toggle-height">
          <span>Bar height</span>
          <small id="height-state">Standard 49pt, 83pt with the home indicator</small>
        </button>
        <button class="tile" data-action="update-label">
          <span>Update one label</span>
          <small id="label-item-state">Activity</small>
        </button>
        <button class="tile" data-action="update-icon">
          <span>Update one icon</span>
          <small id="icon-item-state">Activity bars</small>
        </button>
      </section>
    `,
  },
  activity: {
    title: 'Activity',
    subtitle: 'Badge and tabs',
    body: `
      <section class="list">
        <article><strong>Live update shipped</strong><span>Navbar action event received by JS.</span></article>
        <article><strong>Android native bar</strong><span>Bottom navigation is native on Android.</span></article>
        <article><strong>iOS Liquid Glass</strong><span>Native chrome uses system glass rendering.</span></article>
        <article><strong>Orders synced</strong><span>Seven pending approvals moved to done.</span></article>
        <article><strong>Review queued</strong><span>Three changes are waiting for owner review.</span></article>
        <article><strong>Build complete</strong><span>The release candidate finished without errors.</span></article>
        <article><strong>Archive ready</strong><span>May exports are prepared for download.</span></article>
        <article><strong>Invoices posted</strong><span>Thirty-two customers were notified.</span></article>
      </section>
    `,
  },
  capture: {
    title: 'Capture',
    subtitle: 'Included center tab',
    body: `
      <section class="capture-panel">
        <div class="capture-lens">Camera</div>
        <p>The center tab is included in the curved native tabbar.</p>
      </section>
    `,
  },
  settings: {
    title: 'Settings',
    subtitle: 'Runtime configuration',
    body: `
      <section class="settings">
        <label><input id="labels-toggle" type="checkbox" /> Tab labels</label>
        <label><input id="icons-toggle" type="checkbox" /> Tab icons</label>
        <div class="layout-presets" aria-label="Tab bar layouts"></div>
        <label><input id="top-button-toggle" type="checkbox" /> Top button</label>
        <button data-action="refresh-version">Read native version</button>
        <pre id="version-output">Ready.</pre>
      </section>
    `,
  },
  profile: {
    title: 'Profile',
    subtitle: 'Fifth tab',
    body: `
      <section class="list">
        <article><strong>Martin</strong><span>Five native tabs with a promoted center action.</span></article>
        <article><strong>Theme</strong><span>Colors and shape are updated from JavaScript.</span></article>
        <article><strong>Safe area</strong><span>CSS variables still reflect the native tabbar height.</span></article>
      </section>
    `,
  },
  draft: {
    title: 'Draft',
    subtitle: 'Hidden tab selected',
    body: `
      <section class="detail">
        <p class="eyebrow">Hidden native tab</p>
        <h1>Visible only while active.</h1>
        <p>The Draft tab is configured with hidden: true. The native tabbar shows it when selected, then removes it after another tab is chosen.</p>
      </section>
    `,
  },
  detail: {
    title: 'Detail',
    subtitle: 'Native push shell',
    body: `
      <section class="detail">
        <h1>Detail content is still web.</h1>
        <p>The native layer captured the previous WebView, waited for this route to render, then animated the frame.</p>
        <button data-action="go-back">Go back</button>
      </section>
    `,
  },
};

const tabbarColors = () => ({
  tint: tabbarShape() === 'curve' ? '#ff5b45' : '#0a84ff',
  inactiveTint: '#8b8f96',
  background: '#ffffff',
});

const tabsForNative = () =>
  currentTabs().map((tab) => {
    if (tabbarShape() === 'floating' && tabbarPreset === 'trailing' && tab.id === 'profile' && !shapeOverride) {
      return { ...tab, role: 'search' };
    }
    return tab;
  });

const tabbarStyle = () => {
  const curve = tabbarShape() === 'curve';
  const height = standardBarHeight ? (curve ? 49 : 64) : 80;
  return curve
    ? {
        shape: 'curve',
        centerItemId: 'capture',
        height,
        horizontalMargin: 0,
        maxWidth: 0,
        bottomGap: 0,
        cornerRadius: 0,
        centerButtonDiameter: 56,
        centerButtonLift: 28,
        centerButtonColor: '#ff5b45',
        centerButtonIconColor: '#ffffff',
      }
    : {
        shape: 'floating',
        height,
        horizontalMargin: 24,
        maxWidth: 430,
        bottomGap: 10,
      };
};
const topButtonItems = [
  {
    id: 'compose',
    title: 'Compose',
    icon: { svg: icons.compose },
  },
];

const shouldShowTopButton = () => route === 'settings' && topButtonVisible;

const setTopButtonVisible = (visible) => {
  topButtonVisible = visible;
  writeTopButtonPreference(visible);
};

const configureChrome = async () => {
  await NativeNavigation.configure({
    contentInsetMode: 'css',
    animationDuration: 360,
    colors: {
      tint: '#0a84ff',
      inactiveTint: '#6b7280',
    },
    glass: {
      effect: 'liquidGlass',
      blurRadius: 18,
      surfaceAlpha: 0.62,
    },
  });
  chromeConfigured = true;
  await updateNavbar();
  await updateTabbar();
};

const pageFor = (id) =>
  pages[id] ?? {
    title: id.charAt(0).toUpperCase() + id.slice(1),
    subtitle: 'Added from the demo controls',
    body: `
      <section class="detail">
        <h1>${id}</h1>
        <p>This tab was inserted into the native bar from the home controls.</p>
      </section>
    `,
  };

const updateNavbar = async () => {
  const page = pageFor(route);
  await NativeNavigation.setNavbar({
    hidden: route === 'home' && tabbarShape() === 'curve',
    title: page.title,
    subtitle: route === 'home' ? tabbarPresets[tabbarPreset].detail : page.subtitle,
    large: route === 'home' && tabbarShape() !== 'curve',
    transparent: true,
    backButton: {
      visible: stack.length > 1,
      title: 'Back',
    },
    rightItems: shouldShowTopButton() ? topButtonItems : [],
  });
};

const updateTabbar = async () => {
  await NativeNavigation.setTabbar({
    hidden: route === 'detail' || tabbarHidden,
    selectedId: activeTab,
    tabs: tabsForNative(),
    labels: labelsEnabled,
    icons: iconsEnabled,
    colors: tabbarColors(),
    style: tabbarStyle(),
  });
};

const restoreChrome = async () => {
  if (!chromeConfigured) {
    return;
  }
  await updateNavbar();
  await updateTabbar();
};

const clearNavbarActions = () => {
  void NativeNavigation.setNavbar({
    hidden: true,
    title: '',
    transparent: true,
    backButton: { visible: false },
    leftItems: [],
    rightItems: [],
  }).catch((error) => {
    console.warn('Native navbar cleanup failed', error);
  });
};

const syncControls = () => {
  const labelsToggle = document.getElementById('labels-toggle');
  const iconsToggle = document.getElementById('icons-toggle');
  const topButtonToggle = document.getElementById('top-button-toggle');
  if (labelsToggle) {
    labelsToggle.checked = labelsEnabled;
  }
  if (iconsToggle) {
    iconsToggle.checked = iconsEnabled;
  }
  if (topButtonToggle) {
    topButtonToggle.checked = topButtonVisible;
  }
  const labelsState = document.getElementById('labels-state');
  const iconsState = document.getElementById('icons-state');
  const floatingState = document.getElementById('floating-state');
  const badgeState = document.getElementById('badge-state');
  if (labelsState) {
    labelsState.textContent = labelsEnabled ? 'Shown under the icons' : 'Hidden';
  }
  if (iconsState) {
    iconsState.textContent = iconsEnabled ? 'Shown' : 'Hidden';
  }
  if (floatingState) {
    floatingState.textContent = shapeOverride
      ? shapeOverride === 'floating'
        ? 'Capsule, forced on'
        : 'Full-width bar, forced on'
      : tabbarShape() === 'floating'
        ? 'Capsule, from the layout'
        : 'Full-width bar, from the layout';
  }
  if (badgeState) {
    badgeState.textContent = activityBadge ? `Activity count ${activityBadge}` : 'Activity count off';
  }
  const heightState = document.getElementById('height-state');
  if (heightState) {
    heightState.textContent = standardBarHeight
      ? 'Standard 49pt, 83pt with the home indicator'
      : 'Tall 80pt body, plus the home indicator';
  }
  const labelItemState = document.getElementById('label-item-state');
  const iconItemState = document.getElementById('icon-item-state');
  const activityTab = currentTabs().find((tab) => tab.id === 'activity');
  if (labelItemState) {
    labelItemState.textContent = activityTab ? `Activity item: ${activityTab.title}` : 'Activity item is hidden';
  }
  if (iconItemState) {
    iconItemState.textContent = itemPatches.activity?.icon?.svg === icons.star ? 'Activity item: star' : 'Activity item: bars';
  }
  document.querySelectorAll('.layout-presets').forEach((container) => {
    container.innerHTML = Object.entries(tabbarPresets)
      .map(
        ([id, preset]) => `
          <button class="tile${tabbarPreset === id ? ' is-selected' : ''}" data-preset="${id}">
            <span>${preset.label}</span>
            <small>${preset.detail}</small>
          </button>
        `,
      )
      .join('');
  });
};

const visiblePreviewTabs = () => tabsForNative().filter((tab) => !tab.hidden);

const renderWebTabbarPreview = () => {
  if (!isWebPreview || route === 'detail' || tabbarHidden) {
    return '';
  }

  const visibleTabs = visiblePreviewTabs();
  const trailingCandidates = visibleTabs.filter((tab) => tab.role === 'search' || tab.role === 'prominent');
  const trailingTab = tabbarShape() === 'floating' ? (trailingCandidates[trailingCandidates.length - 1] ?? null) : null;
  const capsuleTabs = trailingTab
    ? visibleTabs.filter((tab) => !(tab.role === 'search' || tab.role === 'prominent'))
    : visibleTabs;
  const renderTab = (tab, { center = false, detached = false } = {}) => {
    const selected = tab.id === activeTab;
    const iconMarkup = iconsEnabled ? `<span class="web-tabbar-icon">${tab.icon.svg}</span>` : '';
    const showDetachedLabel = detached && !iconsEnabled && labelsEnabled;
    const labelMarkup =
      (!detached && labelsEnabled) || showDetachedLabel ? `<span class="web-tabbar-label">${tab.title}</span>` : '';
    return `
      <button class="web-tabbar-item${selected ? ' is-selected' : ''}${center ? ' is-center' : ''}${detached ? ' is-detached' : ''}" data-web-tab="${tab.id}" aria-label="${tab.title}">
        ${iconMarkup}
        ${labelMarkup}
      </button>
    `;
  };
  const capsuleItems = capsuleTabs
    .map((tab) => renderTab(tab, { center: tabbarShape() === 'curve' && tab.id === 'capture' }))
    .join('');
  const trailingMarkup = trailingTab ? renderTab(trailingTab, { detached: true }) : '';

  return `<nav class="web-tabbar-preview ${tabbarShape()}${trailingTab ? ' has-trailing' : ''}" style="--web-tab-count: ${capsuleTabs.length}" aria-label="Tabbar preview"><div class="web-tabbar-capsule">${capsuleItems}</div>${trailingMarkup}</nav>`;
};
const render = () => {
  const page = pageFor(route);
  app.innerHTML = `<div class="page" data-route="${route}">${page.body}</div>${renderWebTabbarPreview()}`;
  syncControls();
};

const navigate = async (nextRoute, direction = 'forward') => {
  const transition = await NativeNavigation.beginTransition({ direction });
  route = nextRoute;
  if (direction === 'forward') {
    stack.push(nextRoute);
  } else if (direction === 'back' && stack.length > 1) {
    stack.pop();
  } else if (direction === 'tab' || direction === 'root') {
    stack = [nextRoute];
  }
  render();
  await updateNavbar();
  await updateTabbar();
  await NativeNavigation.finishTransition({ id: transition.id, direction });
};

app.addEventListener('click', async (event) => {
  const target = event.target.closest('button');
  if (!target) {
    return;
  }
  const previewTab = target.dataset.webTab;
  if (previewTab) {
    activeTab = previewTab;
    await navigate(previewTab, 'tab');
    return;
  }
  const pushRoute = target.dataset.push;
  if (pushRoute) {
    await navigate(pushRoute, 'forward');
    return;
  }
  if (target.dataset.action === 'go-back') {
    await navigate(stack[stack.length - 2] ?? activeTab, 'back');
    return;
  }
  if (target.dataset.action === 'toggle-tabbar') {
    tabbarHidden = !tabbarHidden;
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.preset && tabbarPresets[target.dataset.preset]) {
    tabbarPreset = target.dataset.preset;
    shapeOverride = null;
    render();
    await updateNavbar();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'add-tab') {
    if (removedTabIds.length > 0) {
      removedTabIds.pop();
    } else {
      const next = addableTabs.find((tab) => !addedTabIds.includes(tab.id));
      if (next) {
        addedTabIds.push(next.id);
      }
    }
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'remove-tab') {
    const visible = currentTabs();
    if (visible.length <= 1) {
      return;
    }
    const last = visible[visible.length - 1];
    if (addedTabIds.includes(last.id)) {
      addedTabIds = addedTabIds.filter((id) => id !== last.id);
    } else {
      removedTabIds.push(last.id);
    }
    if (activeTab === last.id) {
      activeTab = visible[0].id;
      await navigate(activeTab, 'tab');
      return;
    }
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'toggle-labels') {
    labelsEnabled = !labelsEnabled;
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'toggle-icons') {
    iconsEnabled = !iconsEnabled;
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'toggle-floating') {
    shapeOverride = tabbarShape() === 'floating' ? 'curve' : 'floating';
    render();
    await updateNavbar();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'toggle-badge') {
    activityBadge = activityBadge ? 0 : 3;
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'toggle-height') {
    standardBarHeight = !standardBarHeight;
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'update-label') {
    const currentTitle = itemPatches.activity?.title ?? 'Activity';
    const nextTitle = activityTitles[(activityTitles.indexOf(currentTitle) + 1) % activityTitles.length];
    itemPatches.activity = { ...itemPatches.activity, title: nextTitle };
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'update-icon') {
    const currentIcon = itemPatches.activity?.icon?.svg ?? icons.activity;
    const nextIcon = activityIcons[(activityIcons.indexOf(currentIcon) + 1) % activityIcons.length];
    itemPatches.activity = { ...itemPatches.activity, icon: { svg: nextIcon } };
    render();
    await updateTabbar();
    return;
  }
  if (target.dataset.action === 'refresh-version') {
    const output = document.getElementById('version-output');
    const version = await NativeNavigation.getPluginVersion();
    output.textContent = JSON.stringify(version, null, 2);
  }
});

app.addEventListener('change', async (event) => {
  if (event.target.id === 'labels-toggle') {
    labelsEnabled = event.target.checked;
    render();
    await updateTabbar();
  }
  if (event.target.id === 'icons-toggle') {
    iconsEnabled = event.target.checked;
    render();
    await updateTabbar();
  }
  if (event.target.id === 'top-button-toggle') {
    setTopButtonVisible(event.target.checked);
    await updateNavbar();
  }
});

NativeNavigation.addListener('navbarBack', async () => {
  await navigate(stack[stack.length - 2] ?? activeTab, 'back');
});

NativeNavigation.addListener('navbarItemTap', async (event) => {
  const output = document.getElementById('version-output');
  if (output) {
    output.textContent = `Navbar item tapped: ${event.id}`;
  }
});

NativeNavigation.addListener('tabSelect', async (event) => {
  if (event.id === activeTab && route !== 'detail') {
    return;
  }
  activeTab = event.id;
  await navigate(event.id, 'tab');
});

NativeNavigation.addListener('safeAreaChanged', (event) => {
  app.dataset.insets = JSON.stringify(event.insets);
});

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') {
    clearNavbarActions();
    return;
  }
  void restoreChrome();
});

window.addEventListener('pagehide', clearNavbarActions);
window.addEventListener('pageshow', () => {
  void restoreChrome();
});

render();
void configureChrome();
