import Capacitor
import UIKit
import WebKit
import WebViewNativeUIEngine

final class NativeNavigationWebUIEngine {
    private weak var plugin: NativeNavigationPlugin?
    private var navbarProjection: NativeUIProjection?
    private var tabbarProjection: NativeUIProjection?
    private(set) var isActive = false

    func setActive(_ active: Bool, plugin: NativeNavigationPlugin) {
        guard active != isActive else {
            if active {
                refreshProjections(plugin: plugin)
            }
            return
        }
        isActive = active
        self.plugin = plugin
        if active {
            install(plugin: plugin)
        } else {
            teardown()
        }
    }

    func forward(eventName: String, data: [String: Any]?) {
        guard isActive else {
            return
        }
        navbarProjection?.receive(eventName, data: data)
        tabbarProjection?.receive(eventName, data: data)
    }

    func notifyChrome(surface: String, hidden: Bool) {
        guard isActive else {
            return
        }
        let eventName = hidden ? "chromeHidden" : "chromeShown"
        let data: [String: Any] = ["surface": surface]
        if surface == "navbar" {
            navbarProjection?.receive(eventName, data: data)
        } else if surface == "tabbar" {
            tabbarProjection?.receive(eventName, data: data)
        }
    }

    func teardown() {
        navbarProjection?.destroy()
        tabbarProjection?.destroy()
        navbarProjection = nil
        tabbarProjection = nil
        plugin = nil
    }

    private func install(plugin: NativeNavigationPlugin) {
        guard let webView = plugin.bridge?.webView as? WKWebView else {
            return
        }
        injectProjectionSlots(into: webView)
        if navbarProjection == nil {
            navbarProjection = makeProjection(
                webView: webView,
                selector: NativeNavigationWebUIEngine.navbarSelector,
                plugin: plugin,
                view: { [weak plugin] in plugin?.navContainer }
            )
        }
        if tabbarProjection == nil {
            tabbarProjection = makeProjection(
                webView: webView,
                selector: NativeNavigationWebUIEngine.tabbarSelector,
                plugin: plugin,
                view: { [weak plugin] in plugin?.nativeNavigationTabbarProjectionView() }
            )
        }
        notifyChrome(surface: "navbar", hidden: !plugin.nativeNavigationNavbarProjectionVisible())
        notifyChrome(surface: "tabbar", hidden: !plugin.nativeNavigationTabbarProjectionVisible())
    }

    private func refreshProjections(plugin: NativeNavigationPlugin) {
        notifyChrome(surface: "navbar", hidden: !plugin.nativeNavigationNavbarProjectionVisible())
        notifyChrome(surface: "tabbar", hidden: !plugin.nativeNavigationTabbarProjectionVisible())
    }

    private func makeProjection(
        webView: WKWebView,
        selector: String,
        plugin: NativeNavigationPlugin,
        view: @escaping () -> UIView?
    ) -> NativeUIProjection? {
        do {
            return try NativeUIProjection(
                webView: webView,
                plugin: plugin.jsName,
                projectionSelector: selector,
                receiveListeners: .init(
                    update: ["safeAreaChanged"],
                    projection: .init(
                        native: ["chromeShown"],
                        web: ["transitionStart"],
                        none: ["chromeHidden"]
                    )
                ),
                view: view
            )
        } catch {
            CAPLog.print("NativeNavigation web UI engine projection failed: \(error)")
            return nil
        }
    }

    private func injectProjectionSlots(into webView: WKWebView) {
        let script = """
        (function () {
          if (globalThis.__capNativeNavigationProjectionSlots) { return; }
          const make = (id, placement) => {
            if (document.getElementById(id)) { return; }
            const slot = document.createElement('div');
            slot.id = id;
            slot.setAttribute('data-cap-native-navigation-projection-slot', placement);
            slot.setAttribute('aria-hidden', 'true');
            slot.style.cssText = placement === 'top'
              ? 'position:fixed;left:0;right:0;top:0;pointer-events:none;z-index:0;overflow:hidden;margin:0;padding:0;border:0;height:var(--cap-native-navbar-height, 0px)'
              : 'position:fixed;left:0;right:0;bottom:0;pointer-events:none;z-index:0;overflow:hidden;margin:0;padding:0;border:0;height:var(--cap-native-tabbar-height, 0px)';
            document.documentElement.appendChild(slot);
          };
          make('cap-native-navigation-navbar-slot', 'top');
          make('cap-native-navigation-tabbar-slot', 'bottom');
          globalThis.__capNativeNavigationProjectionSlots = true;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    static let navbarSelector = "#cap-native-navigation-navbar-slot"
    static let tabbarSelector = "#cap-native-navigation-tabbar-slot"
}