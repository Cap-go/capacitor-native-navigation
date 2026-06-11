import './style.css';
import { Capacitor } from '@capacitor/core';
import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { NativeNavigation } from '@capgo/capacitor-native-navigation';

const app = document.getElementById('app');
const isWebPreview = Capacitor.getPlatform() === 'web';

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
];

let activeTab = 'home';
let route = 'home';
let stack = ['home'];
let labelsEnabled = true;
let iconsEnabled = true;
let tabbarShape = 'curve';
let tabbarHidden = false;

const pages = {
  home: {
    title: 'Native Home',
    subtitle: 'Web content, native chrome',
    body: `
      <section class="hero">
        <img class="app-logo" src="/icon.svg" alt="Native Navigation Example" />
        <p class="eyebrow">Capgo native navigation</p>
        <h1>Native frame, web content.</h1>
        <p>Top and bottom navigation render outside the WebView while this page remains ordinary HTML.</p>
      </section>
      <section class="grid">
        <button class="tile" data-push="detail">
          <span>Open detail</span>
          <small>Push transition and native back button</small>
        </button>
        <button class="tile" data-action="toggle-tabbar">
          <span>Toggle tabbar</span>
          <small>Dynamic visibility from JavaScript</small>
        </button>
        <button class="tile" data-action="toggle-tabbar-shape">
          <span>Switch tabbar shape</span>
          <small>Floating capsule or curved center action</small>
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
    subtitle: 'Raised center tab',
    body: `
      <section class="capture-panel">
        <div class="capture-lens">Camera</div>
        <p>The center tab is a native raised action button inside a curved native tabbar.</p>
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
        <label><input id="curve-toggle" type="checkbox" /> Curved center tabbar</label>
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
  tint: tabbarShape === 'curve' ? '#ff5b45' : '#0a84ff',
  inactiveTint: '#8b8f96',
  background: tabbarShape === 'curve' ? '#f8f8fb' : '#ffffff',
});

const tabbarStyle = () =>
  tabbarShape === 'curve'
    ? {
        shape: 'curve',
        centerItemId: 'capture',
        height: 76,
        horizontalMargin: 0,
        maxWidth: 0,
        bottomGap: 0,
        cornerRadius: 24,
        centerButtonDiameter: 76,
        centerButtonLift: 38,
        centerButtonColor: '#ff5b45',
        centerButtonIconColor: '#ffffff',
      }
    : {
        shape: 'floating',
        height: 64,
        horizontalMargin: 24,
        maxWidth: 430,
        bottomGap: 10,
      };

const configureChrome = async () => {
  await NativeNavigation.configure({
    contentInsetMode: 'css',
    animationDuration: 360,
    colors: {
      tint: '#0a84ff',
      inactiveTint: '#6b7280',
    },
  });
  await updateNavbar();
  await updateTabbar();
};

const updateNavbar = async () => {
  const page = pages[route];
  await NativeNavigation.setNavbar({
    hidden: false,
    title: page.title,
    subtitle: page.subtitle,
    large: route === 'home',
    transparent: true,
    backButton: {
      visible: stack.length > 1,
      title: 'Back',
    },
    rightItems: [
      {
        id: 'compose',
        title: 'Compose',
        icon: { svg: icons.compose },
      },
    ],
  });
};

const updateTabbar = async () => {
  await NativeNavigation.setTabbar({
    hidden: route === 'detail' || tabbarHidden,
    selectedId: activeTab,
    tabs,
    labels: labelsEnabled,
    icons: iconsEnabled,
    colors: tabbarColors(),
    style: tabbarStyle(),
  });
};

const syncControls = () => {
  const labelsToggle = document.getElementById('labels-toggle');
  const iconsToggle = document.getElementById('icons-toggle');
  const curveToggle = document.getElementById('curve-toggle');
  if (labelsToggle) {
    labelsToggle.checked = labelsEnabled;
  }
  if (iconsToggle) {
    iconsToggle.checked = iconsEnabled;
  }
  if (curveToggle) {
    curveToggle.checked = tabbarShape === 'curve';
  }
};


const renderWebTabbarPreview = () => {
  if (!isWebPreview || route === 'detail' || tabbarHidden) {
    return '';
  }

  const items = tabs
    .map((tab) => {
      const selected = tab.id === activeTab;
      const center = tabbarShape === 'curve' && tab.id === 'capture';
      const iconMarkup = iconsEnabled ? `<span class="web-tabbar-icon">${tab.icon.svg}</span>` : '';
      const labelMarkup = labelsEnabled ? `<span class="web-tabbar-label">${tab.title}</span>` : '';
      return `
        <button class="web-tabbar-item${selected ? ' is-selected' : ''}${center ? ' is-center' : ''}" data-web-tab="${tab.id}" aria-label="${tab.title}">
          ${iconMarkup}
          ${labelMarkup}
        </button>
      `;
    })
    .join('');

  return `<nav class="web-tabbar-preview ${tabbarShape}" aria-label="Tabbar preview">${items}</nav>`;
};
const render = () => {
  const page = pages[route] ?? pages.home;
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
  if (target.dataset.action === 'toggle-tabbar-shape') {
    tabbarShape = tabbarShape === 'curve' ? 'floating' : 'curve';
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
  if (event.target.id === 'curve-toggle') {
    tabbarShape = event.target.checked ? 'curve' : 'floating';
    render();
    await updateTabbar();
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

render();
void configureChrome();
