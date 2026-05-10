# Contributing

This guide provides instructions for contributing to this Capacitor plugin template.

## Developing

### Local Setup

1. Fork and clone the repo.
2. Install dependencies.

```shell
bun install
```

3. Install SwiftLint if you're on macOS.

```shell
brew install swiftlint
```

### Scripts

#### `bun run build`

Builds plugin web assets and generates API documentation with [`@capacitor/docgen`](https://github.com/ionic-team/capacitor-docgen).

#### `bun run verify`

Builds and validates iOS, Android, and Web.

#### `bun run lint` / `bun run fmt`

Checks or auto-fixes formatting and linting.

## Publishing

The `prepublishOnly` hook prepares the plugin before publishing.

```shell
bun publish
```

> The `files` array in `package.json` controls what is published. Update it if you move files.

## PR Beta Packages

Each PR gets a bot comment that explains how to publish a temporary npm build for testing.

Maintainers can comment `/publish-beta` on a PR once checks are green. CI will publish the PR head to:

- the shared `beta` dist-tag
- a pinned `pr-<number>` dist-tag for that exact PR build
