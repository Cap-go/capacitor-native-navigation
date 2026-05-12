import XCTest
@testable import NativeNavigationPlugin

class NativeNavigationTests: XCTestCase {
    func testEcho() {
        let implementation = NativeNavigation()
        let value = "Hello, World!"
        let result = implementation.echo(value)

        XCTAssertEqual(value, result)
    }

    func testGetPluginVersion() {
        let implementation = NativeNavigation()
        let result = implementation.getPluginVersion()

        XCTAssertEqual("native", result)
    }

    func testTabContentControllerHostAvoidsLayerCycle() {
        let webView = UIView()
        let controller = NativeNavigationTabContentController()
        _ = controller.view

        webView.addSubview(controller.view)
        XCTAssertTrue(controller.view.isDescendant(of: webView))

        controller.host(webView: webView)

        XCTAssertNil(webView.superview)
        XCTAssertEqual(controller.view.superview, webView)
    }
}
