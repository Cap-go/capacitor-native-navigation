#!/usr/bin/env bun
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..');
const appDir = resolve(repoRoot, 'example-app');
const distDir = resolve(appDir, 'dist');
const packageJsonPath = resolve(repoRoot, 'package.json');
const capacitorConfigPath = resolve(appDir, 'capacitor.config.json');
const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));
const capacitorConfig = JSON.parse(readFileSync(capacitorConfigPath, 'utf8'));
const packageVersion = packageJson.version;
const configVersion = capacitorConfig.plugins?.CapacitorUpdater?.version;

const appId = process.env.CAPGO_APP_ID || 'app.capgo.capacitor.navigation';
const channel = process.env.CAPGO_CHANNEL || process.argv[2] || 'production';
const bundle = packageVersion;
const comment =
  process.env.CAPGO_COMMENT ||
  (process.env.GITHUB_SHA ? `Native navigation example ${process.env.GITHUB_SHA}` : 'Native navigation example upload');

if (!packageVersion) {
  console.error('Missing package.json version.');
  process.exit(1);
}

if (configVersion !== packageVersion) {
  console.error(
    `CapacitorUpdater.version (${configVersion ?? 'missing'}) must match package.json version (${packageVersion}).`,
  );
  process.exit(1);
}

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
  '../package.json,package.json',
  '--node-modules',
  '../node_modules,node_modules',
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
