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
        self.plugin = plugin
        if !active {
            if isActive {
                isActive = false
                teardown()
            }
            return
        }
        if isActive {
            refreshProjections(plugin: plugin)
            return
        }
        guard install(plugin: plugin) else {
            isActive = false
            teardown()
            return
        }
        isActive = true
        refreshProjections(plugin: plugin)
    }

    func forward(eventName: String, data: [String: Any]?) {
        guard isActive else {
            return
        }
        if eventName == "transitionStart" || eventName == "transitionEnd" {
            return
        }
        if eventName == "safeAreaChanged" {
            var navbarData = data ?? [:]
            navbarData["surface"] = "navbar"
            navbarProjection?.receive(eventName, data: navbarData)
            var tabbarData = data ?? [:]
            tabbarData["surface"] = "tabbar"
            tabbarProjection?.receive(eventName, data: tabbarData)
            return
        }
        navbarProjection?.receive(eventName, data: data)
        tabbarProjection?.receive(eventName, data: data)
    }

    func notifyChrome(surface: String, hidden: Bool) {
        guard isActive, let plugin else {
            return
        }
        let eventName = hidden ? "chromeHidden" : "chromeShown"
        plugin.notifyListeners(eventName, data: ["surface": surface], retainUntilConsumed: false)
    }

    func teardown() {
        navbarProjection?.destroy()
        tabbarProjection?.destroy()
        navbarProjection = nil
        tabbarProjection = nil
        plugin = nil
    }

    @discardableResult
    private func install(plugin: NativeNavigationPlugin) -> Bool {
        guard let webView = plugin.bridge?.webView as? WKWebView else {
            return false
        }
        injectProjectionSlots(into: webView)
        if navbarProjection == nil {
            navbarProjection = makeProjection(
                webView: webView,
                selector: NativeNavigationWebUIEngine.navbarSelector,
                plugin: plugin,
                surface: "navbar",
                view: { [weak plugin] in plugin?.nativeNavigationNavbarProjectionView() }
            )
        }
        if tabbarProjection == nil {
            tabbarProjection = makeProjection(
                webView: webView,
                selector: NativeNavigationWebUIEngine.tabbarSelector,
                plugin: plugin,
                surface: "tabbar",
                view: { [weak plugin] in plugin?.nativeNavigationTabbarProjectionView() }
            )
        }
        guard navbarProjection != nil, tabbarProjection != nil else {
            return false
        }
        return true
    }

    private func refreshProjections(plugin: NativeNavigationPlugin) {
        notifyChrome(surface: "navbar", hidden: !plugin.nativeNavigationNavbarProjectionVisible())
        notifyChrome(surface: "tabbar", hidden: !plugin.nativeNavigationTabbarProjectionVisible())
    }

    private func makeProjection(
        webView: WKWebView,
        selector: String,
        plugin: NativeNavigationPlugin,
        surface: String,
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
                        web: [],
                        none: ["chromeHidden"]
                    ),
                    match: ["surface": surface]
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
              : 'position:fixed;left:0;right:0;bottom:0;pointer-events:none;z-index:0;overflow:hidden;margin:0;padding:0;border:0;height:max(var(--cap-native-tabbar-height, 0px), var(--cap-native-system-tabbar-height, 0px))';
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