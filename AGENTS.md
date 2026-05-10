# AGENTS.md

This file provides guidance to AI agents and contributors working on this Capacitor plugin template.

## Template First

Run this before implementing real plugin logic:

```bash
bun run init-plugin <plugin-slug> [ClassName] [app.capgo.packageid] [GitHubOrg] [android-lang]
```

Example:

```bash
bun run init-plugin downloader CapacitorDownloader app.capgo.downloader Cap-go kotlin
```

This command renames JS/iOS/Android identifiers, package metadata, and native file paths.
The optional `android-lang` argument defaults to `java`; pass `kotlin` to generate Kotlin Android sources and Gradle setup.
The 4th argument always remains `GitHubOrg`; pass `Cap-go` as the 4th argument and `kotlin` as the 5th argument when you want the Kotlin Android scaffold with the default org.

Immediately after running it in a generated plugin copy:

1. Change git remote away from the template before any push:
   - `git remote set-url origin git@github.com:Cap-go/capacitor-<plugin-slug>.git`
2. Remove bootstrap-only init script from the generated copy:
   - delete `scripts/init-plugin.sh`
   - delete `scripts/templates/`
   - remove `"init-plugin"` from `package.json` scripts

## Public Release Requirements (Mandatory)

When shipping a new plugin from this template, the agent must perform all of the following:

1. Publish the repository under `Cap-go` and make it public.
2. Set the GitHub repository description and ensure it starts with:
   - `Capacitor plugin for ...`
3. Set the GitHub repository homepage to:
   - `https://capgo.app/docs/plugins/<plugin-slug>/`
4. Open a pull request on `https://github.com/Cap-go/website` (or monorepo folder `landing/`) and update:
   - `src/config/plugins.ts` (plugin registry entry)
   - `src/content/docs/docs/plugins/index.mdx` (plugin card in docs index)
   - `src/content/docs/docs/plugins/<plugin-doc-slug>/index.mdx`
   - `src/content/docs/docs/plugins/<plugin-doc-slug>/getting-started.mdx`
   - `src/content/docs/docs/plugins/<plugin-doc-slug>/ios.mdx` and `android.mdx` when platform setup differs
   - `astro.config.mjs` (pagefind bucket + docs sidebar entry)
   - `src/content/plugins-tutorials/en/<plugin-repo-slug>.md` (SEO tutorial page)
   - `public/icons/plugins/<plugin-doc-slug>.svg` when the docs hero references a plugin icon
5. Keep the README Capgo CTA header block and replace:
   - `{{PLUGIN_REF_SLUG}}` with the tracking slug (example: `native_audio`)

Website slug rule:

- Docs routes use `<plugin-doc-slug>` under `/docs/plugins/<plugin-doc-slug>/`.
- Tutorial routing uses `<plugin-repo-slug>` extracted from the plugin GitHub URL in `src/config/plugins.ts`.
- Example: repo URL `https://github.com/Cap-go/capacitor-app-attest/` maps to tutorial file
  `src/content/plugins-tutorials/en/capacitor-app-attest.md`.

Reference commands:

```bash
# Create public repo directly
gh repo create Cap-go/capacitor-<plugin-slug> --public --source=. --remote=origin --push

# Or switch existing private repo to public
gh repo edit Cap-go/capacitor-<plugin-slug> --visibility public --accept-visibility-change-consequences

# Enforce description + homepage
gh repo edit Cap-go/capacitor-<plugin-slug> \
  --description "Capacitor plugin for <what-it-does>." \
  --homepage "https://capgo.app/docs/plugins/<plugin-slug>/"
```

## Quick Start

```bash
# Install dependencies
bun install

# Build the plugin (TypeScript + Rollup + docgen)
bun run build

# Full verification (iOS, Android, Web)
bun run verify

# Format code (ESLint + Prettier + SwiftLint)
bun run fmt

# Lint without fixing
bun run lint
```

## Development Workflow

1. **Install** - `bun install` (never use npm)
2. **Build** - `bun run build` compiles TypeScript, generates docs, and bundles with Rollup
3. **Verify** - `bun run verify` builds for iOS, Android, and Web. Always run this before submitting work
4. **Format** - `bun run fmt` auto-fixes ESLint, Prettier, and SwiftLint issues
5. **Lint** - `bun run lint` checks code quality without modifying files

## Capacitor Hook Scripts

Use Capacitor lifecycle hooks in `package.json` when plugin setup must run automatically during `cap sync` / `cap update`.

Recommended hooks:

- `capacitor:sync:before` for code generation that must exist before native project sync.
- `capacitor:update:before` for code generation that must exist before native project update.
- `capacitor:sync:after` for post-sync native patching/configuration.
- `capacitor:update:after` for post-update native patching/configuration.

Example:

```json
{
  "scripts": {
    "generate:version-share": "bun run scripts/generate-version-share-data.mjs",
    "configure:dependencies": "bun run scripts/configure-dependencies.mjs",
    "capacitor:sync:before": "bun run generate:version-share",
    "capacitor:update:before": "bun run generate:version-share",
    "capacitor:sync:after": "bun run configure:dependencies"
  }
}
```

Notes:

- Prefer `*:before` for deterministic inputs needed by native build/sync.
- Use `*:after` only when the task depends on generated native files.
- Keep hook scripts idempotent so repeated `cap sync` runs are safe.

### Individual Platform Verification

```bash
bun run verify:ios
bun run verify:android
bun run verify:web
```

### Example App

The `example-app/` directory links to the plugin via `file:..`:

```bash
cd example-app
bun install
bun run start
```

Use `bunx cap sync <platform>` to test iOS/Android shells.

## Project Structure

- `src/definitions.ts` - TypeScript interfaces and types (source of truth for API docs)
- `src/index.ts` - Plugin registration
- `src/web.ts` - Web implementation
- `ios/Sources/` - iOS native code (Swift)
- `android/src/main/` - Android native code (Java/Kotlin)
- `dist/` - Generated output (do not edit manually)
- `Package.swift` - SwiftPM definition
- `*.podspec` - CocoaPods spec

## iOS Package Management

We always support both **CocoaPods** and **Swift Package Manager (SPM)**. Every plugin must ship a valid `*.podspec` and `Package.swift`.

## API Documentation

API docs in the README are auto-generated from JSDoc in `src/definitions.ts`. **Never edit the `<docgen-index>` or `<docgen-api>` sections in `README.md` directly.** Instead, update `src/definitions.ts` and run `bun run docgen`. Document any important default or future-major default candidate in `src/definitions.ts` so the next Capacitor major upgrade can change it deliberately.

## Versioning

- New plugins must start at version `8.0.0` (Capacitor 8 baseline).
- The plugin major version must always follow the Capacitor major version.
- By default, ship and maintain Capacitor 8 support first.
- Do not introduce breaking changes in `src/definitions.ts` unless explicitly asked or the current definition is broken or unusable.
- Document any important default or future-major default candidate in `src/definitions.ts` so the next Capacitor major upgrade can change it deliberately.
- Backward compatibility for older Capacitor majors is supported on demand.
- Ship breaking changes only with a Capacitor major migration.

## Changelog

`CHANGELOG.md` is managed automatically by CI/CD. Do not edit it manually.

## Common Pitfalls

- Always rename Swift and Android classes plus package IDs when creating a new plugin from this template.
- We target JVM 21 for Android builds.
- `dist/` is regenerated on every build and should never be edited directly.
- Use Bun for everything. If a command needs a package binary, use `bunx`.
