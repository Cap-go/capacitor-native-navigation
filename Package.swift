// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorNativeNavigation",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapgoCapacitorNativeNavigation",
            targets: ["NativeNavigationPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0"),
        .package(url: "https://github.com/webview-native-ui/engine.git", exact: "1.0.11")
    ],
    targets: [
        .target(
            name: "NativeNavigationPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "WebViewNativeUIEngine", package: "engine")
            ],
            path: "ios/Sources/NativeNavigationPlugin"),
        .testTarget(
            name: "NativeNavigationPluginTests",
            dependencies: ["NativeNavigationPlugin"],
            path: "ios/Tests/NativeNavigationPluginTests")
    ]
)
