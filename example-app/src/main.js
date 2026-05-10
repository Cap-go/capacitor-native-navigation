import './style.css';
import { NativeNavigation } from '@capgo/native-navigation';

const app = document.getElementById('app');

const icons = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/></svg>',
  activity:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19V5"/><path d="M9 19V9"/><path d="M14 19v-7"/><path d="M19 19V7"/></svg>',
  settings:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="m4.93 4.93 2.12 2.12"/><path d="m16.95 16.95 2.12 2.12"/><path d="M2 12h3"/><path d="M19 12h3"/><path d="m4.93 19.07 2.12-2.12"/><path d="m16.95 7.05 2.12-2.12"/></svg>',
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
    id: 'settings',
    title: 'Settings',
    icon: { svg: icons.settings },
  },
];

let activeTab = 'home';
let route = 'home';
let stack = ['home'];

const pages = {
  home: {
    title: 'Native Home',
    subtitle: 'Web content, native chrome',
    body: `
      <section class="hero">
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
      </section>
    `,
  },
  activity: {
    title: 'Activity',
    subtitle: 'Badge and tabs',
    body: `
      <section class="list">
        <article><strong>Live update shipped</strong><span>Navbar action event received by JS.</span></article>
        <article><strong>Android Material bar</strong><span>Bottom navigation is native on Android.</span></article>
        <article><strong>iOS Liquid Glass</strong><span>UINavigationBar and UITabBar use system rendering.</span></article>
        <article><strong>Orders synced</strong><span>Seven pending approvals moved to done.</span></article>
        <article><strong>Review queued</strong><span>Three changes are waiting for owner review.</span></article>
        <article><strong>Build complete</strong><span>The release candidate finished without errors.</span></article>
        <article><strong>Archive ready</strong><span>May exports are prepared for download.</span></article>
        <article><strong>Invoices posted</strong><span>Thirty-two customers were notified.</span></article>
      </section>
    `,
  },
  settings: {
    title: 'Settings',
    subtitle: 'Runtime configuration',
    body: `
      <section class="settings">
        <label><input id="labels-toggle" type="checkbox" checked /> Tab labels</label>
        <label><input id="icons-toggle" type="checkbox" checked /> Tab icons</label>
        <button data-action="refresh-version">Read native version</button>
        <pre id="version-output">Ready.</pre>
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
    hidden: route === 'detail',
    selectedId: activeTab,
    tabs,
    labels: document.getElementById('labels-toggle')?.checked ?? true,
    icons: document.getElementById('icons-toggle')?.checked ?? true,
    colors: {
      tint: '#0a84ff',
      inactiveTint: '#6b7280',
    },
  });
};

const render = () => {
  const page = pages[route];
  app.innerHTML = `<div class="page" data-route="${route}">${page.body}</div>`;
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
    const isDetailHidden = route === 'detail';
    await NativeNavigation.setTabbar({ hidden: !isDetailHidden && app.dataset.tabbarHidden !== 'true', tabs, selectedId: activeTab });
    app.dataset.tabbarHidden = app.dataset.tabbarHidden === 'true' ? 'false' : 'true';
    return;
  }
  if (target.dataset.action === 'refresh-version') {
    const output = document.getElementById('version-output');
    const version = await NativeNavigation.getPluginVersion();
    output.textContent = JSON.stringify(version, null, 2);
  }
});

app.addEventListener('change', async (event) => {
  if (event.target.id === 'labels-toggle' || event.target.id === 'icons-toggle') {
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
