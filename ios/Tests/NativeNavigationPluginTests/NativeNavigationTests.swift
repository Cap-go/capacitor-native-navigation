import XCTest
import UIKit
@testable import NativeNavigationPlugin

class NativeNavigationTests: XCTestCase {
    func testGetPluginVersion() {
        let implementation = NativeNavigation()
        let result = implementation.getPluginVersion()

        XCTAssertEqual("native", result)
    }

    func testTabContentControllerHostsWebView() {
        let webView = UIView()
        let originalContainer = UIView()
        let controller = NativeNavigationTabContentController()
        _ = controller.view

        originalContainer.addSubview(webView)

        XCTAssertTrue(controller.host(webView: webView))
        XCTAssertEqual(webView.superview, controller.view)
        XCTAssertEqual(webView.frame, controller.view.bounds)
    }

    func testTabContentControllerRejectsLayerCycle() {
        let webView = UIView()
        let controller = NativeNavigationTabContentController()
        _ = controller.view

        webView.addSubview(controller.view)

        XCTAssertFalse(controller.host(webView: webView))
        XCTAssertNil(webView.superview)
        XCTAssertEqual(controller.view.superview, webView)
    }
}
