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

This app is configured for Capgo Cloud with app id `app.capgo.native.navigation.example` and the `production` channel.

The `Deploy example app to Capgo` GitHub Actions workflow builds the example app and uploads the bundle to Capgo when a GitHub release is published. You can also run that workflow manually from GitHub Actions.
