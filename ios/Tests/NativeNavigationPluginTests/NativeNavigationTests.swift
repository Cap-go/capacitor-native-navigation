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
}
