# Example App for `@capgo/capacitor-native-navigation`

This Vite project links directly to the local plugin source so you can validate iOS, Android, and Web wiring while developing.

## Getting started

From the repository root:

```bash
bun install
bun run example:build
cd example-app
bun run start
```

To test on native shells:

```bash
bun run cap:sync
bun run cap:ios
bun run cap:android
```

The iOS and Android commands add the native platform folder the first time they run.

## Capgo Cloud testing

This app is configured for Capgo Cloud with app id `app.capgo.capacitor.navigation` and the `production` channel.

First-time setup in Capgo:

```bash
bunx @capgo/cli@latest app add app.capgo.capacitor.navigation --name "Native Navigation Example"
bunx @capgo/cli@latest channel add production app.capgo.capacitor.navigation --default --self-assign
```

Deploy a new OTA bundle:

```bash
bun run capgo:deploy
```

The Capgo bundle version is read from the root plugin `package.json` and must match `plugins.CapacitorUpdater.version` in `capacitor.config.json`. Use `CAPGO_CHANNEL` or `CAPGO_APP_ID` when you need to override the deployment target.
