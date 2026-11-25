import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.env.CAPACITOR_PLATFORM_NAME && process.env.CAPACITOR_PLATFORM_NAME !== 'ios') {
  process.exit(0);
}

const pluginRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const appRoot = process.cwd();
const podfilePath = join(appRoot, 'ios', 'App', 'Podfile');

const resolveEngineRoot = () => {
  for (const base of [appRoot, pluginRoot]) {
    try {
      const requireFrom = createRequire(join(base, 'package.json'));
      const enginePackageJson = requireFrom.resolve('@webview-native-ui/engine/package.json');
      return dirname(enginePackageJson);
    } catch {
      // try next base
    }
  }
  return null;
};

if (!existsSync(podfilePath)) {
  process.exit(0);
}

const engineRoot = resolveEngineRoot();
if (!engineRoot) {
  process.exit(0);
}

const marker = "pod 'WebViewNativeUIEngine'";
let podfile = readFileSync(podfilePath, 'utf8');
if (podfile.includes(marker)) {
  process.exit(0);
}

const relPath = relative(dirname(podfilePath), engineRoot).replaceAll('\\', '/');
const injection = `  pod 'WebViewNativeUIEngine', :path => '${relPath}'\n`;

if (/^\s*capacitor_pods\s*$/m.test(podfile)) {
  podfile = podfile.replace(/(^\s*capacitor_pods\s*$)/m, `$1\n${injection}`);
} else {
  podfile = podfile.replace(/(def capacitor_pods[\s\S]+?^end\n)/m, `$1${injection}`);
}

writeFileSync(podfilePath, podfile);