import Capacitor
import UIKit
import WebKit
@testable import NativeNavigationPlugin

extension NativeNavigationPlugin {
    var scrollLayoutNavContainer: UIView? { navContainer }

    func scrollLayout_navbarHideDistance(from container: UIView) -> CGFloat {
        abs(container.transform.ty)
    }

    func scrollLayout_lastNotifiedNavbarHeight() -> CGFloat {
        currentInsets()["navbarHeight"] as? CGFloat ?? 0
    }

    func scrollLayout_prepareHarness(
        rootView: UIView,
        windowHost: UIViewController,
        webView: WKWebView,
        width: CGFloat,
        safeAreaTop: CGFloat,
        drain: (TimeInterval) -> Void
    ) {
        rootView.frame = CGRect(x: 0, y: 0, width: width, height: 800)
        let layoutHost = ScrollLayoutHostViewController(rootView: rootView)
        windowHost.addChild(layoutHost)
        layoutHost.didMove(toParent: windowHost)
        layoutHost.additionalSafeAreaInsets = UIEdgeInsets(
            top: max(0, safeAreaTop - rootView.safeAreaInsets.top),
            left: 0,
            bottom: 0,
            right: 0
        )

        let testBridge = ScrollLayoutTestBridge(viewController: layoutHost, webView: webView)
        bridge = testBridge

        scrollLayout_runOnMain(plugin: self, drain: drain, method: configure, options: ["enabled": true])
        scrollLayout_runOnMain(
            plugin: self,
            drain: drain,
            method: setNavbar,
            options: [
                "hidden": false,
                "title": "Scroll layout",
                "edgeBlur": true,
                "scrollBehavior": "both"
            ]
        )
    }

    func scrollLayout_setCollapsed(_ collapsed: Bool, animated: Bool = false) {
        setNavbarScrollCollapsed(collapsed, animated: animated)
    }

    func scrollLayout_layoutChrome() {
        layoutChrome()
    }

    func scrollLayout_updateInsetsAndNotify() {
        updateInsetsAndNotify()
    }

    func scrollLayout_webNavbarHeight(in webView: WKWebView, completion: @escaping (CGFloat) -> Void) {
        let script = """
        (function(){
          var style = getComputedStyle(document.documentElement);
          var raw = style.getPropertyValue('--cap-native-navbar-height').trim();
          if (!raw) { return 0; }
          return parseFloat(raw) || 0;
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            if let number = result as? NSNumber {
                completion(CGFloat(truncating: number))
            } else {
                completion(0)
            }
        }
    }

    func scrollLayout_navbarEdgeBlurOverlayHeight(in webView: WKWebView, completion: @escaping (CGFloat) -> Void) {
        let script = """
        (function(){
          var root = document.getElementById('cap-native-navigation-edge-blur-top');
          if (!root) { return 0; }
          return parseFloat(root.style.height) || 0;
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            if let number = result as? NSNumber {
                completion(CGFloat(truncating: number))
            } else {
                completion(0)
            }
        }
    }

    /// Simulates pre-fix `layoutChrome()` assigning `navContainer.frame` under an active collapse transform.
    func scrollLayout_applyLegacyMainFrameAssignment(revealedContainerSize: CGSize) {
        guard let container = navContainer else {
            return
        }
        container.frame = CGRect(x: 0, y: 0, width: revealedContainerSize.width, height: revealedContainerSize.height)
    }

    private func scrollLayout_runOnMain(
        plugin: NativeNavigationPlugin,
        drain: (TimeInterval) -> Void,
        method: @escaping (CAPPluginCall) -> Void,
        options: [String: Any]
    ) {
        guard let call = CAPPluginCall(
            callbackId: "scroll-layout-test",
            methodName: "scrollLayout",
            options: options,
            success: { _, _ in },
            error: { _ in }
        ) else {
            return
        }
        if Thread.isMainThread {
            method(call)
        } else {
            DispatchQueue.main.sync {
                method(call)
            }
        }
        drain(0.35)
    }
}