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

    func testTabContentControllerKeepsSnapshotPlaceholderWhenWebViewMoves() {
        let webView = UIView()
        let firstController = NativeNavigationTabContentController()
        let secondController = NativeNavigationTabContentController()
        _ = firstController.view
        _ = secondController.view

        firstController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        secondController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        webView.backgroundColor = .systemBackground

        XCTAssertTrue(firstController.host(webView: webView))
        XCTAssertEqual(firstController.view.subviews.count, 1)

        firstController.clearHostedWebView(ifMatching: webView, preservingSnapshot: true)
        XCTAssertEqual(firstController.view.subviews.count, 2)

        XCTAssertTrue(secondController.host(webView: webView))
        XCTAssertEqual(webView.superview, secondController.view)
        XCTAssertEqual(firstController.view.subviews.count, 1)
        XCTAssertFalse(firstController.view.subviews.contains(webView))

        XCTAssertTrue(firstController.host(webView: webView))
        XCTAssertEqual(webView.superview, firstController.view)
        XCTAssertEqual(firstController.view.subviews.count, 1)
        XCTAssertTrue(firstController.view.subviews.first === webView)
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
