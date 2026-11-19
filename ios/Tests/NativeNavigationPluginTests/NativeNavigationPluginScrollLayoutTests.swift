import XCTest
import UIKit
import WebKit
@testable import NativeNavigationPlugin

final class NativeNavigationPluginScrollLayoutTests: XCTestCase {
    private let canvasWidth: CGFloat = 390
    private let canvasHeight: CGFloat = 844
    private let safeAreaTop: CGFloat = 59
    private var webViewLoadObserverRetention = [WebViewLoadObserver]()

    func testNavbarScrollCollapseLayoutThroughPlugin() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let container = fixture.container

        let layoutFrame = plugin.scrollLayout_expectedNavContainerLayoutFrame(
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        )
        let expectedCenter = CGPoint(x: layoutFrame.midX, y: layoutFrame.midY)
        let hideDistance = plugin.scrollLayout_navbarHideDistance()

        plugin.scrollLayout_setCollapsed(true)
        plugin.scrollLayout_layoutChrome()
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.4)
        XCTAssertEqual(container.bounds.size, layoutFrame.size)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.01)
        XCTAssertEqual(container.transform.ty, -hideDistance, accuracy: 0.01)
        let collapsedBlurHeight = try awaitEdgeBlurOverlayHeight(plugin: plugin, webView: fixture.webView)

        plugin.scrollLayout_setCollapsed(false)
        plugin.scrollLayout_layoutChrome()
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.4)
        XCTAssertEqual(container.transform, .identity)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.01)
        let revealedBlurHeight = try awaitEdgeBlurOverlayHeight(plugin: plugin, webView: fixture.webView)
        XCTAssertGreaterThan(revealedBlurHeight, collapsedBlurHeight + 20)
        XCTAssertGreaterThan(revealedBlurHeight, 80)
    }

    func testAnimatedRevealNotifiesInsetsBeforeAnimationEnds() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let expectedNavHeight = plugin.scrollLayout_expectedNavContainerLayoutFrame(
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        ).height

        plugin.scrollLayout_setCollapsed(true)
        plugin.scrollLayout_updateInsetsAndNotify()
        let collapsedNotifyHeight = plugin.scrollLayout_lastNotifiedNavbarHeight()

        plugin.scrollLayout_setCollapsed(false, animated: true)
        XCTAssertGreaterThan(
            plugin.scrollLayout_lastNotifiedNavbarHeight(),
            collapsedNotifyHeight + 20,
            "Reveal must notify full navbar insets immediately, not after 0.22s"
        )
        XCTAssertGreaterThan(plugin.scrollLayout_lastNotifiedNavbarHeight(), expectedNavHeight * 0.85)
    }

    func testLegacyFrameAssignmentShiftsLayoutCenterWhileCollapsed() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let container = fixture.container
        let layoutFrame = plugin.scrollLayout_expectedNavContainerLayoutFrame(
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        )
        let expectedCenter = CGPoint(x: layoutFrame.midX, y: layoutFrame.midY)

        plugin.scrollLayout_setCollapsed(true)
        plugin.scrollLayout_applyLegacyMainFrameAssignment(width: canvasWidth, safeAreaTop: safeAreaTop)
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.1)

        XCTAssertNotEqual(container.center.y, expectedCenter.y, accuracy: 0.5)
    }

    override func tearDown() {
        webViewLoadObserverRetention.removeAll()
        super.tearDown()
    }

    func testSetViewFrameRegressionGuard() {
        let layoutFrame = CGRect(x: 0, y: 0, width: canvasWidth, height: safeAreaTop + 44)
        let expectedCenter = CGPoint(x: layoutFrame.midX, y: layoutFrame.midY)

        let fixed = UIView()
        fixed.transform = CGAffineTransform(translationX: 0, y: -44)
        nativeNavigationSetViewFrame(fixed, frame: layoutFrame)
        XCTAssertEqual(fixed.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(fixed.center.y, expectedCenter.y, accuracy: 0.01)

        let buggy = UIView()
        buggy.transform = CGAffineTransform(translationX: 0, y: -44)
        buggy.frame = layoutFrame
        XCTAssertNotEqual(buggy.center.y, expectedCenter.y, accuracy: 0.5)
    }

    private struct WindowFixture {
        let window: UIWindow
        let rootView: UIView
        let webView: WKWebView
        let plugin: NativeNavigationPlugin
        let container: UIView
    }

    private func makeWindowFixture() throws -> WindowFixture {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        window.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)

        let host = UIViewController()
        host.view.backgroundColor = window.backgroundColor
        window.rootViewController = host
        window.makeKeyAndVisible()

        let rootView = UIView(frame: host.view.bounds)
        rootView.backgroundColor = UIColor(red: 0.92, green: 0.94, blue: 0.98, alpha: 1)
        rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.addSubview(rootView)

        let webView = WKWebView(frame: rootView.bounds)
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 0.86, green: 0.9, blue: 0.97, alpha: 1)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        rootView.addSubview(webView)
        drainMainQueue(for: 0.25)
        waitForWebViewHTMLLoad(
            webView,
            html: "<html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head>"
                + "<body style=\"margin:0;background:#dbe6f5;min-height:200vh\"></body></html>",
            baseURL: URL(string: "https://capacitor.test")
        )

        let plugin = NativeNavigationPlugin()
        plugin.scrollLayout_prepareHarness(
            rootView: rootView,
            windowHost: host,
            webView: webView,
            width: canvasWidth,
            safeAreaTop: safeAreaTop,
            drain: drainMainQueue(for:)
        )
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.2)

        guard let container = plugin.scrollLayoutNavContainer else {
            XCTFail("nav container missing after harness")
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 1)
        }

        window.layoutIfNeeded()
        return WindowFixture(window: window, rootView: rootView, webView: webView, plugin: plugin, container: container)
    }

    private func drainMainQueue(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func waitForWebViewHTMLLoad(_ webView: WKWebView, html: String, baseURL: URL?, timeout: TimeInterval = 30) {
        let deadline = Date().addingTimeInterval(timeout)
        var navigationDidFinish = false

        let observer = WebViewLoadObserver()
        observer.onDidFinish = { navigationDidFinish = true }
        webViewLoadObserverRetention.append(observer)
        webView.navigationDelegate = observer

        webView.loadHTMLString(html, baseURL: baseURL)

        var isReady = false
        while Date() < deadline && !isReady {
            drainMainQueue(for: 0.05)
            if navigationDidFinish || !webView.isLoading {
                isReady = isWebViewDocumentReady(webView)
            }
        }

        XCTAssertTrue(isReady, "WKWebView HTML load timed out")
        webView.navigationDelegate = nil
        webViewLoadObserverRetention.removeAll { $0 === observer }
    }

    private func isWebViewDocumentReady(_ webView: WKWebView) -> Bool {
        final class Probe {
            var ready = false
            var completed = false
        }
        let probe = Probe()
        webView.evaluateJavaScript("document.readyState") { result, _ in
            probe.ready = (result as? String) == "complete"
            probe.completed = true
        }
        let scriptDeadline = Date().addingTimeInterval(2)
        while !probe.completed && Date() < scriptDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return probe.ready && !webView.isLoading
    }

    private func awaitEdgeBlurOverlayHeight(plugin: NativeNavigationPlugin, webView: WKWebView) throws -> CGFloat {
        let expectation = expectation(description: "edge blur overlay height")
        var measured: CGFloat = -1
        plugin.scrollLayout_navbarEdgeBlurOverlayHeight(in: webView) { height in
            measured = height
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
        guard measured >= 0 else {
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 2)
        }
        return measured
    }
}

private final class WebViewLoadObserver: NSObject, WKNavigationDelegate {
    var onDidFinish: (() -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onDidFinish?()
    }
}