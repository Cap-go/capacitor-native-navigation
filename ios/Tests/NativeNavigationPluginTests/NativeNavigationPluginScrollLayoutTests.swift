import XCTest
import UIKit
@testable import NativeNavigationPlugin

final class NativeNavigationPluginScrollLayoutTests: XCTestCase {
    private let canvasWidth: CGFloat = 390
    private let safeAreaTop: CGFloat = 59

    func testNavbarScrollCollapseLayoutThroughPlugin() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: canvasWidth, height: 844))
        let host = UIViewController()
        window.rootViewController = host
        window.isHidden = false

        let rootView = UIView(frame: host.view.bounds)
        rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.addSubview(rootView)

        let plugin = NativeNavigationPlugin()
        plugin.testing_prepareNavbarScrollLayoutHarness(
            rootView: rootView,
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        )

        guard let container = plugin.testing_navContainer else {
            XCTFail("nav container missing after harness")
            return
        }

        let layoutFrame = plugin.testing_expectedNavContainerLayoutFrame(
            width: canvasWidth,
            safeAreaTop: safeAreaTop
        )
        let expectedCenter = CGPoint(x: layoutFrame.midX, y: layoutFrame.midY)
        let hideDistance = plugin.testing_navbarScrollHideDistance()

        plugin.testing_setNavbarScrollCollapsedForLayout(true)
        plugin.testing_layoutChrome()
        XCTAssertEqual(container.bounds.size, layoutFrame.size)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.01)
        XCTAssertEqual(container.transform.ty, -hideDistance, accuracy: 0.01)

        try writeLayoutScreenshotIfRequested(container: container, label: "collapsed", in: rootView)

        plugin.testing_setNavbarScrollCollapsedForLayout(false)
        plugin.testing_layoutChrome()
        XCTAssertEqual(container.transform, .identity)
        XCTAssertEqual(container.center.x, expectedCenter.x, accuracy: 0.01)
        XCTAssertEqual(container.center.y, expectedCenter.y, accuracy: 0.01)

        try writeLayoutScreenshotIfRequested(container: container, label: "revealed", in: rootView)
    }

    /// Reverting `layoutChrome` to assign `container.frame` during a collapse transform should fail the center assertions above.
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

    private func writeLayoutScreenshotIfRequested(
        container: UIView,
        label: String,
        in rootView: UIView
    ) throws {
        let env = ProcessInfo.processInfo.environment
        guard let outputDir = env["NAVBAR_SCROLL_SCREENSHOT_OUTPUT_DIR"]
            ?? env["TEST_RUNNER_NAVBAR_SCROLL_SCREENSHOT_OUTPUT_DIR"],
              !outputDir.isEmpty else {
            return
        }

        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        let bounds = rootView.bounds
        rootView.layoutIfNeeded()

        let title = UILabel()
        title.text = "Plugin scroll layout (\(label))"
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.frame = CGRect(x: 12, y: bounds.height - 48, width: bounds.width - 24, height: 40)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            rootView.layer.render(in: context.cgContext)
            title.layer.render(in: context.cgContext)
        }

        let fileName = "ios-navbar-scroll-jump-\(label).png"
        let url = URL(fileURLWithPath: outputDir).appendingPathComponent(fileName)
        guard let data = image.pngData() else {
            XCTFail("Failed to encode \(fileName)")
            return
        }
        try data.write(to: url)

        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}