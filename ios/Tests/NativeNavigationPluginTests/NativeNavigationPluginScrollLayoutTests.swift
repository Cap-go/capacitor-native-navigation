import XCTest
import UIKit
import WebKit
@testable import NativeNavigationPlugin

final class NativeNavigationPluginScrollLayoutTests: XCTestCase {
    private let canvasWidth: CGFloat = 390
    private let canvasHeight: CGFloat = 844
    /// Drives `additionalSafeAreaInsets` in the harness only; assertions use measured layout.
    private let harnessSafeAreaTop: CGFloat = 59
    private var webViewLoadObserverRetention = [WebViewLoadObserver]()

    func testNavbarScrollCollapseLayoutThroughPlugin() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let container = fixture.container

        let revealedSize = fixture.revealedContainerSize
        let expectedCenter = fixture.revealedContainerCenter

        plugin.scrollLayout_setCollapsed(true)
        plugin.scrollLayout_layoutChrome()
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.4)
        XCTAssertEqual(container.bounds.size.width, revealedSize.width, accuracy: 0.01)
        XCTAssertEqual(container.bounds.size.height, revealedSize.height, accuracy: 0.01)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.5)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.5)
        let hideDistance = plugin.scrollLayout_navbarHideDistance(from: container)
        XCTAssertGreaterThan(hideDistance, 40)
        XCTAssertEqual(container.transform.ty, -hideDistance, accuracy: 0.01)
        let collapsedBlurHeight = plugin.scrollLayout_lastPushedNavbarBlurHeight()
        XCTAssertEqual(collapsedBlurHeight, 0, accuracy: 0.01)

        plugin.scrollLayout_setCollapsed(false)
        plugin.scrollLayout_layoutChrome()
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.4)
        XCTAssertEqual(container.transform, .identity)
        XCTAssertEqual(container.bounds.size.width, revealedSize.width, accuracy: 0.01)
        XCTAssertEqual(container.bounds.size.height, revealedSize.height, accuracy: 0.01)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.5)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.5)
        let revealedBlurHeight = try awaitEdgeBlurOverlayHeight(plugin: plugin, webView: fixture.webView)
        XCTAssertGreaterThan(revealedBlurHeight, collapsedBlurHeight)
        XCTAssertGreaterThan(revealedBlurHeight, collapsedBlurHeight + 40)
    }

    func testAnimatedRevealNotifiesInsetsBeforeAnimationEnds() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let revealedNavbarHeight = fixture.revealedNavbarInsetHeight

        plugin.scrollLayout_setCollapsed(true)
        plugin.scrollLayout_updateInsetsAndNotify()
        let collapsedPushedHeight = plugin.scrollLayout_lastNotifiedNavbarHeight()

        plugin.scrollLayout_setCollapsed(false, animated: true)
        let immediatePushedHeight = plugin.scrollLayout_lastNotifiedNavbarHeight()
        XCTAssertGreaterThan(
            immediatePushedHeight,
            collapsedPushedHeight + 5,
            "Reveal must push full navbar insets immediately, not after 0.22s"
        )
        XCTAssertGreaterThanOrEqual(
            immediatePushedHeight,
            revealedNavbarHeight * 0.92,
            "Inset notification should match the revealed layout height"
        )
        XCTAssertEqual(immediatePushedHeight, revealedNavbarHeight, accuracy: 2)
    }

    func testLegacyFrameAssignmentShiftsLayoutCenterWhileCollapsed() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let container = fixture.container
        let expectedCenter = fixture.revealedContainerCenter

        plugin.scrollLayout_setCollapsed(true)
        plugin.scrollLayout_applyLegacyMainFrameAssignment(revealedContainerSize: fixture.revealedContainerSize)
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.1)

        XCTAssertNotEqual(container.center.y, expectedCenter.y, accuracy: 0.5)
    }

    override func tearDown() {
        webViewLoadObserverRetention.removeAll()
        super.tearDown()
    }

    func testSetViewFrameRegressionGuard() {
        let fixed = UIView()
        let layoutFrame = CGRect(x: 0, y: 0, width: canvasWidth, height: 103)
        let hideDistance: CGFloat = 44
        let expectedCenter = CGPoint(x: layoutFrame.midX, y: layoutFrame.midY)
        fixed.transform = CGAffineTransform(translationX: 0, y: -hideDistance)
        nativeNavigationSetViewFrame(fixed, frame: layoutFrame)
        XCTAssertEqual(fixed.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(fixed.center.y, expectedCenter.y, accuracy: 0.01)

        let buggy = UIView()
        buggy.transform = CGAffineTransform(translationX: 0, y: -hideDistance)
        buggy.frame = layoutFrame
        XCTAssertNotEqual(buggy.center.y, expectedCenter.y, accuracy: 0.5)
    }

    private struct WindowFixture {
        let window: UIWindow
        let rootView: UIView
        let webView: WKWebView
        let plugin: NativeNavigationPlugin
        let container: UIView
        let revealedContainerSize: CGSize
        let revealedContainerCenter: CGPoint
        let revealedNavbarInsetHeight: CGFloat
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
        try waitForWebViewHTMLLoad(
            webView,
            html: "<html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head>"
                + "<body style=\"margin:0;background:#dbe6f5;min-height:200vh\"></body></html>"
        )

        let plugin = NativeNavigationPlugin()
        plugin.scrollLayout_prepareHarness(
            rootView: rootView,
            windowHost: host,
            webView: webView,
            width: canvasWidth,
            safeAreaTop: harnessSafeAreaTop,
            drain: drainMainQueue(for:)
        )
        plugin.scrollLayout_updateInsetsAndNotify()
        drainMainQueue(for: 0.2)

        guard let container = plugin.scrollLayoutNavContainer else {
            XCTFail("nav container missing after harness")
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 1)
        }

        window.layoutIfNeeded()
        rootView.layoutIfNeeded()
        let revealedSize = container.bounds.size
        let revealedCenter = CGPoint(x: container.midX, y: container.midY)
        let revealedNavbarHeight = plugin.scrollLayout_lastNotifiedNavbarHeight()
        return WindowFixture(
            window: window,
            rootView: rootView,
            webView: webView,
            plugin: plugin,
            container: container,
            revealedContainerSize: revealedSize,
            revealedContainerCenter: revealedCenter,
            revealedNavbarInsetHeight: revealedNavbarHeight
        )
    }

    private func drainMainQueue(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// Upper bound for one local HTML load. On a cold CI simulator the first WKWebView of the run has to
    /// launch the WebKit WebContent, Networking and GPU helper processes, which has been observed to take
    /// more than 60 seconds. Later loads in the same run finish in well under a second.
    private static let webViewLoadTimeout: TimeInterval = 90

    /// Loads local HTML (nil base URL, so no network origin) and waits for the navigation delegate to report
    /// `didFinish` for that navigation. Fails fast with the WebKit error on `didFail`,
    /// `didFailProvisionalNavigation` or a WebContent process termination instead of polling until the deadline.
    private func waitForWebViewHTMLLoad(
        _ webView: WKWebView,
        html: String,
        timeout: TimeInterval = NativeNavigationPluginScrollLayoutTests.webViewLoadTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let observer = WebViewLoadObserver()
        webViewLoadObserverRetention.append(observer)
        webView.navigationDelegate = observer
        defer {
            webView.navigationDelegate = nil
            webViewLoadObserverRetention.removeAll { $0 === observer }
        }

        observer.navigation = webView.loadHTMLString(html, baseURL: nil)

        let startedAt = Date()
        let deadline = startedAt.addingTimeInterval(timeout)
        while observer.outcome == nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        let elapsed = Date().timeIntervalSince(startedAt)

        switch observer.outcome {
        case .finished:
            break
        case .failed(let reason):
            XCTFail(
                String(format: "WKWebView local HTML load failed after %.1fs: %@", elapsed, reason),
                file: file,
                line: line
            )
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 3)
        case nil:
            XCTFail(
                String(
                    format: "WKWebView local HTML load got no didFinish or didFail within %.0fs (isLoading=%@)",
                    timeout,
                    webView.isLoading ? "true" : "false"
                ),
                file: file,
                line: line
            )
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 4)
        }

        let readyState = try evaluateDocumentReadyState(webView)
        XCTAssertEqual(readyState, "complete", "document.readyState after didFinish", file: file, line: line)
    }

    private func evaluateDocumentReadyState(_ webView: WKWebView) throws -> String? {
        final class Probe {
            var value: String?
            var error: Error?
            var completed = false
        }
        let probe = Probe()
        webView.evaluateJavaScript("document.readyState") { result, error in
            probe.value = result as? String
            probe.error = error
            probe.completed = true
        }
        let scriptDeadline = Date().addingTimeInterval(10)
        while !probe.completed && Date() < scriptDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        guard probe.completed else {
            XCTFail("document.readyState evaluation did not complete within 10s after didFinish")
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 5)
        }
        if let error = probe.error {
            XCTFail("document.readyState evaluation failed: \(error)")
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 6)
        }
        return probe.value
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

private extension UIView {
    var midX: CGFloat { frame.midX }
    var midY: CGFloat { frame.midY }
}

private final class WebViewLoadObserver: NSObject, WKNavigationDelegate {
    enum Outcome {
        case finished
        case failed(String)
    }

    /// Navigation returned by `loadHTMLString`; callbacks for any other navigation are ignored.
    var navigation: WKNavigation?
    private(set) var outcome: Outcome?

    private func isTracked(_ candidate: WKNavigation?) -> Bool {
        guard let navigation else {
            return true
        }
        return candidate === navigation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard outcome == nil, isTracked(navigation) else {
            return
        }
        outcome = .finished
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard outcome == nil, isTracked(navigation) else {
            return
        }
        outcome = .failed("didFail: \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard outcome == nil, isTracked(navigation) else {
            return
        }
        outcome = .failed("didFailProvisionalNavigation: \(error)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard outcome == nil else {
            return
        }
        outcome = .failed("WebContent process terminated")
    }
}
