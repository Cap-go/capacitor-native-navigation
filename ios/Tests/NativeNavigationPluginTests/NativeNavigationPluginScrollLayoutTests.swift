import XCTest
import UIKit
import WebKit
@testable import NativeNavigationPlugin

final class NativeNavigationPluginScrollLayoutTests: XCTestCase {
    private let canvasWidth: CGFloat = 390
    private let canvasHeight: CGFloat = 844
    private let safeAreaTop: CGFloat = 59
    private var webViewLoadObserverRetention = [WebViewLoadObserver]()

    private var expectedNavBarBandMaxY: CGFloat {
        safeAreaTop + 44
    }

    func testNavbarScrollCollapseLayoutThroughPlugin() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let container = fixture.container

        let layoutFrame = plugin.testing_expectedNavContainerLayoutFrame(
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        )
        let expectedCenter = CGPoint(x: layoutFrame.midX, y: layoutFrame.midY)
        let hideDistance = plugin.testing_navbarScrollHideDistance()

        plugin.testing_setNavbarScrollCollapsedForLayout(true)
        plugin.testing_layoutChrome()
        plugin.testing_updateInsetsAndNotify()
        drainMainQueue(for: 0.4)
        XCTAssertEqual(container.bounds.size, layoutFrame.size)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.01)
        XCTAssertEqual(container.transform.ty, -hideDistance, accuracy: 0.01)
        let collapsedBlurHeight = try awaitEdgeBlurOverlayHeight(plugin)

        try captureAndAssertScreenshot(
            fixture: fixture,
            label: "collapsed",
            expectNavbarVisible: false,
            captureOverrideAlpha: nil,
            navbarSearchRect: CGRect(x: 0, y: 0, width: canvasWidth, height: expectedNavBarBandMaxY)
        )

        plugin.testing_setNavbarScrollCollapsedForLayout(false)
        plugin.testing_layoutChrome()
        plugin.testing_updateInsetsAndNotify()
        drainMainQueue(for: 0.4)
        XCTAssertEqual(container.transform, .identity)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.01)
        let revealedBlurHeight = try awaitEdgeBlurOverlayHeight(plugin)
        XCTAssertGreaterThan(revealedBlurHeight, collapsedBlurHeight + 20)
        XCTAssertGreaterThan(revealedBlurHeight, 80)

        try captureAndAssertScreenshot(
            fixture: fixture,
            label: "revealed",
            expectNavbarVisible: true,
            captureOverrideAlpha: nil,
            navbarSearchRect: CGRect(x: 0, y: 0, width: canvasWidth, height: expectedNavBarBandMaxY)
        )

        try capturePRComparisonScreenshots(fixture: fixture)
    }

    func testAnimatedRevealNotifiesInsetsBeforeAnimationEnds() throws {
        let fixture = try makeWindowFixture()
        let plugin = fixture.plugin
        let expectedNavHeight = plugin.testing_expectedNavContainerLayoutFrame(
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        ).height

        plugin.testing_setNavbarScrollCollapsedForLayout(true)
        let collapsedNotifyHeight = plugin.testing_lastNotifiedNavbarHeight

        plugin.testing_setNavbarScrollCollapsedForLayout(false, animated: true)
        XCTAssertGreaterThan(
            plugin.testing_lastNotifiedNavbarHeight,
            collapsedNotifyHeight + 20,
            "Reveal must notify full navbar insets immediately, not after 0.22s"
        )
        XCTAssertGreaterThan(plugin.testing_lastNotifiedNavbarHeight, expectedNavHeight * 0.85)
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
        plugin.testing_setEdgeBlurWebView(webView)
        plugin.testing_prepareNavbarScrollLayoutHarness(
            rootView: rootView,
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        )
        plugin.testing_updateInsetsAndNotify()
        drainMainQueue(for: 0.2)

        guard let container = plugin.testing_navContainer else {
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

    private func awaitEdgeBlurOverlayHeight(_ plugin: NativeNavigationPlugin) throws -> CGFloat {
        let expectation = expectation(description: "edge blur overlay height")
        var measured: CGFloat = -1
        plugin.testing_navbarEdgeBlurOverlayHeight { height in
            measured = height
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
        guard measured >= 0 else {
            throw NSError(domain: "NativeNavigationPluginScrollLayoutTests", code: 2)
        }
        return measured
    }

    private func navbarBandRect(in fixture: WindowFixture) -> CGRect {
        let rect = fixture.container.convert(fixture.container.bounds, to: fixture.window)
        return rect.insetBy(dx: 8, dy: 4)
    }

    private func prDocsOutputDirectory() -> String? {
        let env = ProcessInfo.processInfo.environment
        let path = env["NAVBAR_SCROLL_PR_DOCS_DIR"] ?? env["TEST_RUNNER_NAVBAR_SCROLL_PR_DOCS_DIR"]
        guard let path, !path.isEmpty else {
            return nil
        }
        return path
    }

    private func ciScreenshotOutputDirectory() -> String? {
        let env = ProcessInfo.processInfo.environment
        let path = env["NAVBAR_SCROLL_SCREENSHOT_OUTPUT_DIR"]
            ?? env["TEST_RUNNER_NAVBAR_SCROLL_SCREENSHOT_OUTPUT_DIR"]
        guard let path, !path.isEmpty else {
            return nil
        }
        return path
    }

    private func capturePRComparisonScreenshots(fixture: WindowFixture) throws {
        guard let docsDir = prDocsOutputDirectory() else {
            return
        }
        let plugin = fixture.plugin
        let band = CGRect(x: 0, y: 0, width: canvasWidth, height: expectedNavBarBandMaxY)

        plugin.testing_useLegacyNavContainerFrameLayout = true
        plugin.testing_setNavbarScrollCollapsedForLayout(true)
        plugin.testing_layoutChrome()
        plugin.testing_updateInsetsAndNotify()
        drainMainQueue(for: 0.2)
        let mainCollapsed = try captureWindowScreenshot(
            fixture: fixture,
            expectNavbarVisible: false,
            captureOverrideAlpha: nil,
            band: band,
            label: "main-collapsed"
        )
        try writeScreenshot(mainCollapsed, directory: docsDir, fileName: "ios-main-collapsed.png")

        plugin.testing_setNavbarScrollCollapsedForLayout(true)
        plugin.testing_layoutChrome()
        let mainRevealedJump = try captureWindowScreenshot(
            fixture: fixture,
            expectNavbarVisible: true,
            captureOverrideAlpha: 1,
            band: band,
            label: "main-revealed-jump",
            assertBand: false
        )
        try writeScreenshot(mainRevealedJump, directory: docsDir, fileName: "ios-main-revealed-jump.png")

        plugin.testing_useLegacyNavContainerFrameLayout = false
        plugin.testing_setNavbarScrollCollapsedForLayout(true)
        plugin.testing_layoutChrome()
        plugin.testing_updateInsetsAndNotify()
        drainMainQueue(for: 0.2)
        let prCollapsed = try captureWindowScreenshot(
            fixture: fixture,
            expectNavbarVisible: false,
            captureOverrideAlpha: nil,
            band: band,
            label: "pr-collapsed"
        )
        try writeScreenshot(prCollapsed, directory: docsDir, fileName: "ios-pr-collapsed.png")

        plugin.testing_setNavbarScrollCollapsedForLayout(false)
        plugin.testing_layoutChrome()
        plugin.testing_updateInsetsAndNotify()
        drainMainQueue(for: 0.2)
        let prRevealed = try captureWindowScreenshot(
            fixture: fixture,
            expectNavbarVisible: true,
            captureOverrideAlpha: nil,
            band: band,
            label: "pr-revealed"
        )
        try writeScreenshot(prRevealed, directory: docsDir, fileName: "ios-pr-revealed.png")
    }

    private func captureAndAssertScreenshot(
        fixture: WindowFixture,
        label: String,
        expectNavbarVisible: Bool,
        captureOverrideAlpha: CGFloat?,
        navbarSearchRect: CGRect
    ) throws {
        let image = try captureWindowScreenshot(
            fixture: fixture,
            expectNavbarVisible: expectNavbarVisible,
            captureOverrideAlpha: captureOverrideAlpha,
            band: navbarSearchRect,
            label: label
        )

        guard let outputDir = ciScreenshotOutputDirectory() else {
            return
        }

        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        let fileName = "ios-navbar-scroll-jump-\(label).png"
        let url = URL(fileURLWithPath: outputDir).appendingPathComponent(fileName)
        try writeScreenshot(image, directory: outputDir, fileName: fileName)

        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func captureWindowScreenshot(
        fixture: WindowFixture,
        expectNavbarVisible: Bool,
        captureOverrideAlpha: CGFloat?,
        band: CGRect,
        label: String,
        assertBand: Bool = true
    ) throws -> UIImage {
        let previousAlpha = fixture.container.alpha
        if let captureOverrideAlpha {
            fixture.container.alpha = captureOverrideAlpha
        }
        fixture.plugin.testing_updateInsetsAndNotify()
        drainMainQueue(for: 0.15)
        fixture.window.layoutIfNeeded()

        let image = renderWindow(fixture.window)
        if assertBand {
            if expectNavbarVisible {
                try assertNavbarVisible(in: image, band: band, label: label)
            } else {
                try assertNavbarHidden(in: image, band: band, label: label)
            }
        }

        if captureOverrideAlpha != nil {
            fixture.container.alpha = previousAlpha
        }
        return image
    }

    private func writeScreenshot(_ image: UIImage, directory: String, fileName: String) throws {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: directory).appendingPathComponent(fileName)
        guard let data = image.pngData() else {
            XCTFail("Failed to encode \(fileName)")
            return
        }
        try data.write(to: url)
    }

    private func renderWindow(_ window: UIWindow) -> UIImage {
        let bounds = window.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            if !window.drawHierarchy(in: bounds, afterScreenUpdates: true) {
                window.layer.render(in: context.cgContext)
            }
        }
    }

    private func assertNavbarVisible(in image: UIImage, band: CGRect, label: String) throws {
        guard let cgImage = image.cgImage else {
            XCTFail("Missing CGImage for \(label)")
            return
        }
        let scale = image.scale
        let bandRect = CGRect(
            x: band.origin.x * scale,
            y: band.origin.y * scale,
            width: band.width * scale,
            height: band.height * scale
        ).integral
        let width = cgImage.width
        let background = averageColor(
            in: cgImage,
            rect: CGRect(x: bandRect.minX, y: bandRect.maxY + 24, width: bandRect.width, height: 80)
        )
        var navbarSamples = 0
        var navbarContrastHits = 0
        let minX = max(0, Int(bandRect.minX) + 8)
        let maxX = min(width - 1, Int(bandRect.maxX) - 8)
        let minY = max(0, Int(bandRect.minY) + 4)
        let maxY = min(cgImage.height - 1, Int(bandRect.maxY) - 4)
        let xPositions = [minX, (minX + maxX) / 2, maxX]
        for x in xPositions {
            for y in stride(from: minY, through: maxY, by: 8) {
                guard let pixel = colorAt(x: x, y: y, in: cgImage) else {
                    continue
                }
                navbarSamples += 1
                if pixel.a > 0.08 && colorDistance(pixel, background) > 0.06 {
                    navbarContrastHits += 1
                }
            }
        }
        XCTAssertGreaterThan(navbarSamples, 12, "Navbar sample grid empty for \(label)")
        XCTAssertGreaterThan(
            navbarContrastHits,
            navbarSamples / 4,
            "Navbar region looks empty or matches page background for \(label)"
        )
    }

    private func assertNavbarHidden(in image: UIImage, band: CGRect, label: String) throws {
        guard let cgImage = image.cgImage else {
            XCTFail("Missing CGImage for \(label)")
            return
        }
        let scale = image.scale
        let bandRect = CGRect(
            x: band.origin.x * scale,
            y: band.origin.y * scale,
            width: band.width * scale,
            height: band.height * scale
        ).integral
        let width = cgImage.width
        let background = averageColor(
            in: cgImage,
            rect: CGRect(x: bandRect.minX, y: bandRect.maxY + 24, width: bandRect.width, height: 80)
        )
        var navbarSamples = 0
        var navbarContrastHits = 0
        let minX = max(0, Int(bandRect.minX) + 8)
        let maxX = min(width - 1, Int(bandRect.maxX) - 8)
        let minY = max(0, Int(bandRect.minY) + 4)
        let maxY = min(cgImage.height - 1, Int(bandRect.maxY) - 4)
        let xPositions = [minX, (minX + maxX) / 2, maxX]
        for x in xPositions {
            for y in stride(from: minY, through: maxY, by: 8) {
                guard let pixel = colorAt(x: x, y: y, in: cgImage) else {
                    continue
                }
                navbarSamples += 1
                if pixel.a > 0.08 && colorDistance(pixel, background) > 0.06 {
                    navbarContrastHits += 1
                }
            }
        }
        XCTAssertGreaterThan(navbarSamples, 12, "Navbar sample grid empty for \(label)")
        XCTAssertLessThanOrEqual(
            navbarContrastHits,
            navbarSamples / 6,
            "Navbar region still shows chrome for \(label)"
        )
    }

    private struct RGBA {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat
    }

    private func colorAt(x: Int, y: Int, in image: CGImage) -> RGBA? {
        guard x >= 0, x < image.width, y >= 0, y < image.height else {
            return nil
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        let flippedY = image.height - 1 - y
        context.draw(image, in: CGRect(x: -x, y: -flippedY, width: image.width, height: image.height))
        return RGBA(
            r: CGFloat(pixel[0]) / 255,
            g: CGFloat(pixel[1]) / 255,
            b: CGFloat(pixel[2]) / 255,
            a: CGFloat(pixel[3]) / 255
        )
    }

    private func averageColor(in image: CGImage, rect: CGRect) -> RGBA {
        let clamped = rect.integral
        var total = RGBA(r: 0, g: 0, b: 0, a: 0)
        var count = 0
        let minX = max(0, Int(clamped.minX))
        let maxX = min(image.width - 1, Int(clamped.maxX))
        let minY = max(0, Int(clamped.minY))
        let maxY = min(image.height - 1, Int(clamped.maxY))
        for x in stride(from: minX, through: maxX, by: 12) {
            for y in stride(from: minY, through: maxY, by: 12) {
                if let sample = colorAt(x: x, y: y, in: image) {
                    total = RGBA(
                        r: total.r + sample.r,
                        g: total.g + sample.g,
                        b: total.b + sample.b,
                        a: total.a + sample.a
                    )
                    count += 1
                }
            }
        }
        guard count > 0 else {
            return RGBA(r: 1, g: 1, b: 1, a: 1)
        }
        let divisor = CGFloat(count)
        return RGBA(r: total.r / divisor, g: total.g / divisor, b: total.b / divisor, a: total.a / divisor)
    }

    private func colorDistance(_ left: RGBA, _ right: RGBA) -> CGFloat {
        let dr = left.r - right.r
        let dg = left.g - right.g
        let db = left.b - right.b
        return sqrt(dr * dr + dg * dg + db * db)
    }
}

private final class WebViewLoadObserver: NSObject, WKNavigationDelegate {
    var onDidFinish: (() -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onDidFinish?()
    }
}