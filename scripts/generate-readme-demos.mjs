import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const docsDir = join(root, 'docs');
const frameRoot = join(docsDir, '.demo-frames');
const width = 390;
const height = 844;
const fps = 6;

const icons = {
  home: [
    '<path d="M3 10.5 12 3l9 7.5"/>',
    '<path d="M5 10v10h14V10"/>',
    '<path d="M9 20v-6h6v6"/>',
  ],
  activity: ['<path d="M4 19V5"/>', '<path d="M9 19V9"/>', '<path d="M14 19v-7"/>', '<path d="M19 19V7"/>'],
  settings: [
    '<circle cx="12" cy="12" r="3"/>',
    '<path d="M12 2v3"/>',
    '<path d="M12 19v3"/>',
    '<path d="M2 12h3"/>',
    '<path d="M19 12h3"/>',
    '<path d="m4.93 4.93 2.12 2.12"/>',
    '<path d="m16.95 16.95 2.12 2.12"/>',
    '<path d="m4.93 19.07 2.12-2.12"/>',
    '<path d="m16.95 7.05 2.12-2.12"/>',
  ],
  compose: ['<path d="M12 20h9"/>', '<path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/>'],
  back: ['<path d="M15 18 9 12l6-6"/>'],
  chevron: ['<path d="m9 18 6-6-6-6"/>'],
};

function ensureEmptyDir(dir) {
  if (existsSync(dir)) rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
}

function ease(value) {
  const t = Math.max(0, Math.min(1, value));
  return t * t * (3 - 2 * t);
}

function lerp(from, to, progress) {
  return Math.round(from + (to - from) * progress);
}

function icon(name, x, y, size, color, strokeWidth = 2) {
  return `<g transform="translate(${x} ${y}) scale(${size / 24})" fill="none" stroke="${color}" stroke-width="${strokeWidth}" stroke-linecap="round" stroke-linejoin="round">${icons[name].join('')}</g>`;
}

function text(value, x, y, size, color = '#0f172a', weight = 500, anchor = 'start') {
  const escaped = String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
  return `<text x="${x}" y="${y}" font-family="Arial" font-size="${size}" font-weight="${weight}" fill="${color}" text-anchor="${anchor}">${escaped}</text>`;
}

function pill(x, y, w, h, fill, stroke = 'none') {
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${h / 2}" fill="${fill}" stroke="${stroke}"/>`;
}

function touch(x, y, visible, label = '') {
  if (!visible) return '';
  return `
    <circle cx="${x}" cy="${y}" r="33" fill="#0a84ff" opacity="0.14"/>
    <circle cx="${x}" cy="${y}" r="15" fill="#0a84ff" opacity="0.28"/>
    <circle cx="${x}" cy="${y}" r="6" fill="#0a84ff"/>
    ${label ? `${pill(x - 48, y - 62, 96, 24, '#0f172a')} ${text(label, x, y - 45, 11, '#ffffff', 700, 'middle')}` : ''}
  `;
}

function phoneShell(inner) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
    <defs>
      <linearGradient id="pageBg" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="#f8fafc"/>
        <stop offset="55%" stop-color="#eef6ff"/>
        <stop offset="100%" stop-color="#f7f3ff"/>
      </linearGradient>
      <linearGradient id="glass" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#ffffff" stop-opacity="0.88"/>
        <stop offset="100%" stop-color="#ffffff" stop-opacity="0.66"/>
      </linearGradient>
      <filter id="softShadow" x="-20%" y="-40%" width="140%" height="190%">
        <feDropShadow dx="0" dy="14" stdDeviation="14" flood-color="#0f172a" flood-opacity="0.16"/>
      </filter>
    </defs>
    <rect width="${width}" height="${height}" fill="url(#pageBg)"/>
    <rect x="10" y="10" width="${width - 20}" height="${height - 20}" rx="42" fill="#ffffff" opacity="0.72"/>
    <clipPath id="clip"><rect x="10" y="10" width="${width - 20}" height="${height - 20}" rx="42"/></clipPath>
    <g clip-path="url(#clip)">
      <rect x="10" y="10" width="${width - 20}" height="${height - 20}" fill="url(#pageBg)"/>
      ${inner}
    </g>
  </svg>`;
}

function navbar(title, subtitle, options = {}) {
  const { detail = false, tint = '#0a84ff', compose = true } = options;
  return `
    <rect x="10" y="10" width="${width - 20}" height="104" fill="url(#glass)"/>
    <line x1="10" y1="113.5" x2="${width - 10}" y2="113.5" stroke="#dbe3ef"/>
    ${text('9:41', 42, 42, 13, '#0f172a', 700)}
    <rect x="178" y="28" width="34" height="10" rx="5" fill="#111827" opacity="0.9"/>
    ${detail ? `${icon('back', 28, 65, 24, tint, 2.2)} ${text('Back', 52, 83, 16, tint, 600)}` : ''}
    ${text(title, detail ? 112 : 30, 78, detail ? 21 : 28, '#111827', 800)}
    ${subtitle ? text(subtitle, detail ? 112 : 31, 99, 12, '#64748b', 600) : ''}
    ${compose ? `${pill(322, 58, 42, 42, '#ffffff', '#dbe3ef')} ${icon('compose', 331, 67, 24, tint, 2)}` : ''}
  `;
}

function tabbar(active, shown = true, tint = '#0a84ff') {
  if (!shown) return '';
  const items = [
    ['home', 'Home', 106],
    ['activity', 'Activity', 195],
    ['settings', 'Settings', 284],
  ];
  return `
    <rect x="58" y="742" width="274" height="66" rx="33" fill="url(#glass)" stroke="#dbe3ef" filter="url(#softShadow)"/>
    ${items
      .map(([id, label, x]) => {
        const selected = active === id;
        const color = selected ? tint : '#64748b';
        return `
          ${selected ? pill(x - 44, 748, 88, 54, '#e8f2ff') : ''}
          ${icon(id, x - 12, 756, 24, color, 2)}
          ${id === 'activity' ? `${pill(x + 10, 750, 22, 18, '#ff3b30')} ${text('3', x + 21, 763, 11, '#ffffff', 800, 'middle')}` : ''}
          ${text(label, x, 793, 11, color, selected ? 800 : 600, 'middle')}
        `;
      })
      .join('')}
    <rect x="148" y="824" width="94" height="5" rx="2.5" fill="#111827" opacity="0.84"/>
  `;
}

function card(x, y, w, h, title, body, accent = '#0a84ff') {
  return `
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="18" fill="#ffffff" stroke="#dbe3ef"/>
    <circle cx="${x + 27}" cy="${y + 31}" r="13" fill="${accent}" opacity="0.14"/>
    ${text(title, x + 50, y + 34, 16, '#0f172a', 800)}
    ${text(body, x + 22, y + 66, 13, '#64748b', 600)}
  `;
}

function optionCard(x, y, w, h, title, value, accent = '#0a84ff') {
  return `
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="18" fill="#ffffff" stroke="#dbe3ef"/>
    <rect x="${x + 14}" y="${y + 14}" width="32" height="32" rx="10" fill="${accent}" opacity="0.16"/>
    <circle cx="${x + 30}" cy="${y + 30}" r="6" fill="${accent}"/>
    ${text(title, x + 58, y + 30, 14, '#0f172a', 800)}
    ${text(value, x + 58, y + 54, 12, '#64748b', 650)}
  `;
}

function codePanel(x, y, lines) {
  return `
    <rect x="${x}" y="${y}" width="330" height="${38 + lines.length * 21}" rx="22" fill="#111827"/>
    ${lines.map((line, index) => text(line, x + 22, y + 36 + index * 21, 13, '#dbeafe', 700)).join('')}
  `;
}

function content(route, active, progress = 1) {
  const offset = Math.round((1 - progress) * 32);
  const opacity = 0.15 + progress * 0.85;
  if (route === 'activity') {
    return `<g transform="translate(0 ${offset})" opacity="${opacity}">
      ${card(30, 138, 330, 74, 'Live update shipped', 'Navbar action event received by JS.', '#34c759')}
      ${card(30, 224, 330, 74, 'Android native bar', 'Bottom navigation is native on Android.', '#0a84ff')}
      ${card(30, 310, 330, 74, 'iOS Liquid Glass', 'Native chrome uses system glass rendering.', '#af52de')}
      ${card(30, 396, 330, 74, 'Orders synced', 'Seven pending approvals moved to done.', '#34c759')}
      ${card(30, 482, 330, 74, 'Review queued', 'Three changes wait for owner review.', '#0a84ff')}
      ${card(30, 568, 330, 74, 'Build complete', 'Release candidate finished without errors.', '#af52de')}
      ${card(30, 654, 330, 74, 'Archive ready', 'May exports are prepared for download.', '#34c759')}
      ${card(30, 740, 330, 74, 'Invoices posted', 'Thirty-two customers were notified.', '#0a84ff')}
    </g>`;
  }
  if (route === 'settings') {
    return `<g transform="translate(0 ${offset})" opacity="${opacity}">
      ${text('Settings', 30, 156, 34, '#111827', 850)}
      ${text('Runtime bar options are changed from JavaScript.', 31, 181, 14, '#64748b', 600)}
      ${card(30, 214, 330, 78, 'Tab labels', 'enabled', '#0a84ff')}
      ${card(30, 312, 330, 78, 'Tab icons', 'enabled with SVG descriptors', '#34c759')}
      <rect x="30" y="426" width="330" height="122" rx="22" fill="#111827"/>
      ${text('icon: { svg: "<svg ...>" }', 52, 476, 17, '#ffffff', 750)}
      ${text('native tint + selected state', 52, 510, 13, '#cbd5e1', 600)}
    </g>`;
  }
  if (route === 'detail') {
    return `<g transform="translate(0 ${offset})" opacity="${opacity}">
      ${text('Detail', 30, 172, 38, '#111827', 850)}
      ${text('The WebView changed route; native animated the shell.', 31, 201, 14, '#64748b', 600)}
      <rect x="30" y="238" width="330" height="230" rx="28" fill="#ffffff" stroke="#dbe3ef"/>
      ${icon('chevron', 170, 286, 50, '#0a84ff', 1.8)}
      ${text('Push transition', 195, 382, 22, '#0f172a', 850, 'middle')}
      ${text('single Capacitor WebView', 195, 414, 14, '#64748b', 600, 'middle')}
    </g>`;
  }
  return `<g transform="translate(0 ${offset})" opacity="${opacity}">
    ${text('Native Home', 30, 156, 35, '#111827', 850)}
    ${text('Web content, native navigation frame.', 31, 182, 14, '#64748b', 600)}
    <rect x="30" y="220" width="330" height="152" rx="28" fill="#ffffff" stroke="#dbe3ef"/>
    ${text('Native frame, web content.', 54, 274, 26, '#0f172a', 850)}
    ${text('Navbar and tabbar render outside this page.', 54, 308, 14, '#64748b', 600)}
    ${card(30, 410, 330, 86, 'Open detail', 'Push route with native snapshot animation.', '#0a84ff')}
    ${card(30, 516, 330, 86, 'Toggle tabbar', 'Dynamic visibility comes from JS.', '#af52de')}
  </g>`;
}

function navState(frame) {
  const second = frame / fps;
  if (second < 1.0) return { route: 'home', active: 'home', progress: 1, touch: null };
  if (second < 1.45) return { route: 'home', active: 'home', progress: 1, touch: [195, 766, 'tap Activity'] };
  if (second < 2.35) return { route: 'activity', active: 'activity', progress: ease((second - 1.45) / 0.45), touch: null };
  if (second < 2.85) return { route: 'activity', active: 'activity', progress: 1, touch: [316, 766, 'tap Settings'] };
  if (second < 3.65) return { route: 'settings', active: 'settings', progress: ease((second - 2.85) / 0.45), touch: null };
  if (second < 4.15) return { route: 'settings', active: 'settings', progress: 1, touch: [190, 462, 'push'] };
  if (second < 5.1) return { route: 'detail', active: 'settings', progress: ease((second - 4.15) / 0.5), touch: null };
  if (second < 5.6) return { route: 'detail', active: 'settings', progress: 1, touch: [45, 76, 'back'] };
  return { route: 'settings', active: 'settings', progress: ease((second - 5.6) / 0.45), touch: null };
}

function navigationFrame(frame) {
  const state = navState(frame);
  const titles = {
    home: ['Native Home', 'Web content, native chrome'],
    activity: ['Activity', 'Badge and tabs'],
    settings: ['Settings', 'Runtime configuration'],
    detail: ['Detail', 'Native push shell'],
  };
  const [title, subtitle] = titles[state.route];
  const inner = `
    ${content(state.route, state.active, state.progress)}
    ${navbar(title, subtitle, { detail: state.route === 'detail', compose: state.route !== 'detail' })}
    ${tabbar(state.active, state.route !== 'detail')}
    ${state.touch ? touch(state.touch[0], state.touch[1], true, state.touch[2]) : ''}
  `;
  return phoneShell(inner);
}

function iconDemoState(frame) {
  const second = frame / fps;
  if (second < 1.2) return { tint: '#0a84ff', selected: 'home', labels: true, touch: null, callout: 'Inline SVG descriptors' };
  if (second < 1.75) return { tint: '#0a84ff', selected: 'home', labels: true, touch: [330, 78, 'tap SVG'] , callout: 'Navbar icon is SVG' };
  if (second < 2.5) return { tint: '#34c759', selected: 'activity', labels: true, touch: [195, 766, 'tap tab'], callout: 'Native tint changes selected SVG' };
  if (second < 3.4) return { tint: '#34c759', selected: 'activity', labels: false, touch: [268, 420, 'labels off'], callout: 'Labels and icons are dynamic' };
  if (second < 4.5) return { tint: '#af52de', selected: 'settings', labels: false, touch: [316, 766, 'tap tab'], callout: 'Same SVG, new native state' };
  return { tint: '#0a84ff', selected: 'home', labels: true, touch: null, callout: 'SVG works without packaged assets' };
}

function iconChip(name, label, x, y, selected, tint) {
  const color = selected ? tint : '#64748b';
  return `
    <rect x="${x}" y="${y}" width="146" height="126" rx="24" fill="#ffffff" stroke="${selected ? tint : '#dbe3ef'}"/>
    <circle cx="${x + 73}" cy="${y + 46}" r="28" fill="${selected ? tint : '#e2e8f0'}" opacity="${selected ? 0.18 : 0.8}"/>
    ${icon(name, x + 55, y + 28, 36, color, 1.9)}
    ${text(label, x + 73, y + 96, 14, '#0f172a', 800, 'middle')}
  `;
}

function iconDemoFrame(frame) {
  const state = iconDemoState(frame);
  const labelsOpacity = state.labels ? 1 : 0.22;
  const inner = `
    <rect x="30" y="142" width="330" height="94" rx="28" fill="#111827"/>
    ${text('icon: { svg: "<svg ...>" }', 54, 184, 18, '#ffffff', 800)}
    ${text('JS sends serializable paths; native draws the bars.', 54, 212, 12, '#cbd5e1', 600)}
    ${iconChip('home', 'Home SVG', 30, 270, state.selected === 'home', state.tint)}
    ${iconChip('activity', 'Badge SVG', 214, 270, state.selected === 'activity', state.tint)}
    ${iconChip('settings', 'Settings SVG', 30, 424, state.selected === 'settings', state.tint)}
    ${iconChip('compose', 'Navbar SVG', 214, 424, false, state.tint)}
    <rect x="30" y="604" width="330" height="66" rx="22" fill="#ffffff" stroke="#dbe3ef"/>
    ${text(state.callout, 54, 644, 17, '#0f172a', 850)}
    ${navbar('SVG Icons', 'No native asset packaging required', { tint: state.tint })}
    <rect x="58" y="742" width="274" height="66" rx="33" fill="url(#glass)" stroke="#dbe3ef" filter="url(#softShadow)"/>
    ${[
      ['home', 'Home', 106],
      ['activity', 'Activity', 195],
      ['settings', 'Settings', 284],
    ]
      .map(([id, label, x]) => {
        const selected = state.selected === id;
        const color = selected ? state.tint : '#64748b';
        return `
          ${selected ? pill(x - 44, 748, 88, 54, '#eef2ff') : ''}
          ${icon(id, x - 12, 756, 24, color, 2)}
          <g opacity="${labelsOpacity}">${text(label, x, 793, 11, color, selected ? 800 : 600, 'middle')}</g>
        `;
      })
      .join('')}
    <rect x="148" y="824" width="94" height="5" rx="2.5" fill="#111827" opacity="0.84"/>
    ${state.touch ? touch(state.touch[0], state.touch[1], true, state.touch[2]) : ''}
  `;
  return phoneShell(inner);
}

function optionsDemoState(frame) {
  const second = frame / fps;
  if (second < 0.9) {
    return {
      route: 'options',
      selected: 'home',
      tint: '#0a84ff',
      labelMode: 'labeled',
      callout: 'colors.dynamic follows the platform',
      touch: null,
      zoom: 0,
    };
  }
  if (second < 1.65) {
    return {
      route: 'options',
      selected: 'home',
      tint: '#0a84ff',
      labelMode: 'selected',
      callout: 'labelVisibilityMode: selected',
      touch: [190, 604, 'labels'],
      zoom: 0,
    };
  }
  if (second < 2.55) {
    return {
      route: 'options',
      selected: 'activity',
      tint: '#34c759',
      labelMode: 'selected',
      callout: 'indicator, ripple, and badge colors',
      touch: [195, 766, 'tap tab'],
      zoom: 0,
    };
  }
  if (second < 3.45) {
    return {
      route: 'options',
      selected: 'settings',
      tint: '#af52de',
      labelMode: 'selected',
      callout: 'iOS system Liquid Glass',
      touch: [284, 766, 'tap tab'],
      zoom: 0,
    };
  }
  if (second < 4.2) {
    return {
      route: 'options',
      selected: 'settings',
      tint: '#af52de',
      labelMode: 'selected',
      callout: 'beginZoomTransition(card)',
      touch: [104, 462, 'zoom'],
      zoom: 0,
    };
  }
  if (second < 5.35) {
    return {
      route: 'zooming',
      selected: 'settings',
      tint: '#af52de',
      labelMode: 'selected',
      callout: 'zoom sourceRect -> targetRect',
      touch: null,
      zoom: ease((second - 4.2) / 0.78),
    };
  }
  return {
    route: 'zoom',
    selected: 'settings',
    tint: '#af52de',
    labelMode: 'selected',
    callout: 'native snapshot zoom complete',
    touch: null,
    zoom: 1,
  };
}

function optionsTabbar(state) {
  const items = [
    ['home', 'Home', 106],
    ['activity', 'Activity', 195],
    ['settings', 'Settings', 284],
  ];
  return `
    <rect x="58" y="742" width="274" height="66" rx="33" fill="url(#glass)" stroke="#dbe3ef" filter="url(#softShadow)"/>
    ${items
      .map(([id, label, x]) => {
        const selected = state.selected === id;
        const color = selected ? state.tint : '#64748b';
        const labelOpacity = state.labelMode === 'labeled' || selected ? 1 : 0;
        return `
          ${selected ? pill(x - 38, 748, 76, 54, `${state.tint}22`) : ''}
          ${selected ? `<rect x="${x - 20}" y="751" width="40" height="4" rx="2" fill="${state.tint}"/>` : ''}
          ${icon(id, x - 12, 756, 24, color, 2)}
          ${id === 'activity' ? `${pill(x + 10, 750, 22, 18, '#ff3b30')} ${text('3', x + 21, 763, 11, '#ffffff', 800, 'middle')}` : ''}
          <g opacity="${labelOpacity}">${text(label, x, 793, 11, color, selected ? 800 : 600, 'middle')}</g>
        `;
      })
      .join('')}
    <rect x="148" y="824" width="94" height="5" rx="2.5" fill="#111827" opacity="0.84"/>
  `;
}

function optionsHomeContent(state) {
  return `
    ${text('Native Options', 30, 156, 34, '#111827', 850)}
    ${text('Expo-style chrome controls from JavaScript.', 31, 182, 14, '#64748b', 600)}
    ${optionCard(30, 222, 158, 82, 'dynamic colors', 'dynamic: true', '#0a84ff')}
    ${optionCard(202, 222, 158, 82, 'native glass', 'UIKit iOS 26', '#af52de')}
    ${optionCard(30, 320, 158, 82, 'tab labels', 'selected only', '#34c759')}
    ${optionCard(202, 320, 158, 82, 'badge style', 'red badge', '#ff3b30')}
    <rect x="30" y="434" width="330" height="120" rx="26" fill="#111827"/>
    ${text('beginZoomTransition(card)', 54, 482, 18, '#ffffff', 850)}
    ${text('sourceRect + targetRect + cornerRadius', 54, 514, 13, '#cbd5e1', 650)}
    <rect x="54" y="582" width="282" height="52" rx="17" fill="#ffffff" stroke="#dbe3ef"/>
    ${text(state.callout, 195, 616, 15, '#0f172a', 850, 'middle')}
  `;
}

function zoomContent() {
  return `
    ${text('Zoom Route', 30, 166, 37, '#111827', 850)}
    ${text('The WebView route changed; native animated the snapshot.', 31, 196, 14, '#64748b', 600)}
    ${codePanel(30, 236, [
      'await beginZoomTransition(card)',
      'router.push("/details")',
      'await finishZoomTransition(hero)',
    ])}
    ${optionCard(30, 404, 330, 82, 'cornerRadius', 'shared element style route animation', '#af52de')}
    ${optionCard(30, 506, 330, 82, 'transition shell', 'single WebView, native-feeling motion', '#0a84ff')}
  `;
}

function zoomOverlay(progress) {
  if (progress <= 0 || progress >= 1) return '';
  const x = lerp(30, 10, progress);
  const y = lerp(434, 114, progress);
  const w = lerp(330, width - 20, progress);
  const h = lerp(120, 628, progress);
  const radius = lerp(26, 42, progress);
  const opacity = 0.36 + progress * 0.34;
  return `
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="#111827" opacity="${opacity}"/>
    <rect x="${x + 18}" y="${y + 18}" width="${Math.max(90, w - 36)}" height="${Math.max(44, h - 36)}" rx="${Math.max(12, radius - 10)}" fill="#ffffff" opacity="${0.18 + progress * 0.3}"/>
    ${text('zoom', x + w / 2, y + h / 2 + 5, 26, '#ffffff', 850, 'middle')}
  `;
}

function optionsDemoFrame(frame) {
  const state = optionsDemoState(frame);
  const contentLayer = state.route === 'zoom' ? zoomContent() : optionsHomeContent(state);
  const inner = `
    ${contentLayer}
    ${navbar(state.route === 'zoom' ? 'Zoom Detail' : 'Native Options', state.callout, {
      tint: state.tint,
      compose: state.route !== 'zoom',
      detail: state.route === 'zoom',
    })}
    ${state.route === 'zoom' ? '' : optionsTabbar(state)}
    ${zoomOverlay(state.zoom)}
    ${state.touch ? touch(state.touch[0], state.touch[1], true, state.touch[2]) : ''}
  `;
  return phoneShell(inner);
}

function renderFrames(name, count, factory) {
  const dir = join(frameRoot, name);
  const frameDuration = Math.round(1000 / fps);
  const webpArgs = ['-loop', '0', '-lossy', '-q', '72', '-m', '4'];
  ensureEmptyDir(dir);
  for (let frame = 0; frame < count; frame += 1) {
    const svgPath = join(dir, `frame-${String(frame).padStart(3, '0')}.svg`);
    const pngPath = join(dir, `frame-${String(frame).padStart(3, '0')}.png`);
    writeFileSync(svgPath, factory(frame));
    execFileSync('rsvg-convert', ['-o', pngPath, svgPath], { stdio: 'ignore' });
    webpArgs.push('-d', String(frameDuration), pngPath);
  }
  webpArgs.push('-o', join(docsDir, `${name}.webp`));
  execFileSync('img2webp', webpArgs, { stdio: 'ignore' });
}

ensureEmptyDir(frameRoot);
renderFrames('demo-navigation', 40, navigationFrame);
renderFrames('demo-svg-icons', 32, iconDemoFrame);
renderFrames('demo-options', 36, optionsDemoFrame);
rmSync(frameRoot, { recursive: true, force: true });
