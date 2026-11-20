import Capacitor
import Foundation
import UIKit
import WebKit

/// Host view controller whose `view` is the scroll-layout root (not the UIWindow shell).
final class ScrollLayoutHostViewController: UIViewController {
    init(rootView: UIView) {
        super.init(nibName: nil, bundle: nil)
        view = rootView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Minimal `CAPBridgeProtocol` for scroll-layout XCTest harnesses (viewController + webView only).
final class ScrollLayoutTestBridge: NSObject, CAPBridgeProtocol {
    weak var viewController: UIViewController?
    var webView: WKWebView?
    let config: InstanceConfiguration
    let notificationRouter = NotificationRouter()
    var isSimEnvironment = true
    var isDevEnvironment = true
    var userInterfaceStyle: UIUserInterfaceStyle = .unspecified
    var autoRegisterPlugins = false
    var statusBarVisible = true
    var statusBarStyle: UIStatusBarStyle = .default
    var statusBarAnimation: UIStatusBarAnimation = .none

    init(viewController: UIViewController, webView: WKWebView) {
        self.viewController = viewController
        self.webView = webView
        let descriptor = InstanceDescriptor()
        self.config = InstanceConfiguration(with: descriptor, isDebug: false)
        super.init()
    }

    func getWebView() -> WKWebView? { webView }
    func isSimulator() -> Bool { isSimEnvironment }
    func isDevMode() -> Bool { isDevEnvironment }
    func getStatusBarVisible() -> Bool { statusBarVisible }
    func getStatusBarStyle() -> UIStatusBarStyle { statusBarStyle }
    func getUserInterfaceStyle() -> UIUserInterfaceStyle { userInterfaceStyle }
    func getLocalUrl() -> String { config.localURL.absoluteString }
    func getSavedCall(_ callbackId: String) -> CAPPluginCall? { savedCall(withID: callbackId) }
    func releaseCall(callbackId: String) { releaseCall(withID: callbackId) }

    func plugin(withName: String) -> CAPPlugin? { nil }
    func saveCall(_ call: CAPPluginCall) {}
    func savedCall(withID: String) -> CAPPluginCall? { nil }
    func releaseCall(_ call: CAPPluginCall) {}
    func releaseCall(withID: String) {}
    func evalWithPlugin(_ plugin: CAPPlugin, js: String) {
        _ = webView?.evaluateJavaScript(js)
    }
    func eval(js: String) {
        _ = webView?.evaluateJavaScript(js)
    }
    func triggerJSEvent(eventName: String, target: String) {}
    func triggerJSEvent(eventName: String, target: String, data: String) {}
    func triggerWindowJSEvent(eventName: String) {}
    func triggerWindowJSEvent(eventName: String, data: String) {}
    func triggerDocumentJSEvent(eventName: String) {}
    func triggerDocumentJSEvent(eventName: String, data: String) {}
    func localURL(fromWebURL: URL?) -> URL? { nil }
    func portablePath(fromLocalURL: URL?) -> URL? { nil }
    func setServerBasePath(_: String) {}
    func registerPluginType(_: CAPPlugin.Type) {}
    func registerPluginInstance(_: CAPPlugin) {}
    func showAlertWith(title: String, message: String, buttonTitle: String) {}
    func presentVC(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        viewController?.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    func dismissVC(animated flag: Bool, completion: (() -> Void)?) {
        viewController?.dismiss(animated: flag, completion: completion)
    }
}