// swift-tools-version: 5.9
import PackageDescription

// DO NOT MODIFY THIS FILE - managed by Capacitor CLI commands
let package = Package(
    name: "CapApp-SPM",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapApp-SPM",
            targets: ["CapApp-SPM"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", exact: "8.5.2"),
        .package(name: "CapgoCapacitorUpdater", path: "../../../node_modules/.bun/@capgo+capacitor-updater@8.51.23+8c735c3c6e2ff3c1/node_modules/@capgo/capacitor-updater"),
        .package(name: "CapgoCapacitorNativeNavigation", path: "../../../node_modules/.bun/@capgo+capacitor-native-navigation@file+..+c7d91c372e2d53be/node_modules/@capgo/capacitor-native-navigation")
    ],
    targets: [
        .target(
            name: "CapApp-SPM",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "CapgoCapacitorUpdater", package: "CapgoCapacitorUpdater"),
                .product(name: "CapgoCapacitorNativeNavigation", package: "CapgoCapacitorNativeNavigation")
            ]
        )
    ]
)
