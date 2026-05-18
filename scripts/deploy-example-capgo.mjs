#!/usr/bin/env bun
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..');
const appDir = resolve(repoRoot, 'example-app');
const distDir = resolve(appDir, 'dist');

const appId = process.env.CAPGO_APP_ID || 'app.capgo.capacitor.navigation';
const channel = process.env.CAPGO_CHANNEL || process.argv[2] || 'production';
const safeChannel = channel.replace(/[^0-9A-Za-z-]/g, '-');
const bundle = process.env.CAPGO_BUNDLE_VERSION || `0.0.1-${safeChannel}.${Date.now()}`;
const comment =
  process.env.CAPGO_COMMENT ||
  (process.env.GITHUB_SHA ? `Native navigation example ${process.env.GITHUB_SHA}` : 'Native navigation example upload');

if (!existsSync(distDir)) {
  console.error('Missing example-app/dist. Run bun run --cwd example-app build first.');
  process.exit(1);
}

const args = [
  '@capgo/cli@latest',
  'bundle',
  'upload',
  appId,
  '--path',
  'dist',
  '--channel',
  channel,
  '--bundle',
  bundle,
  '--package-json',
  'package.json',
  '--node-modules',
  'node_modules',
  '--delta',
  '--no-key',
  '--ignore-checksum-check',
  '--version-exists-ok',
  '--comment',
  comment,
];

console.log(`Deploying ${appId}@${bundle} to Capgo channel "${channel}"`);

const result = spawnSync('bunx', args, {
  cwd: appDir,
  stdio: 'inherit',
  env: process.env,
});

process.exit(result.status ?? 1);
