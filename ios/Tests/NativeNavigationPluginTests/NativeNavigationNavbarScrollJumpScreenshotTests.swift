import XCTest
import UIKit
@testable import NativeNavigationPlugin

/// Writes layout comparison PNGs when `GENERATE_NAVBAR_SCROLL_SCREENSHOTS=1` (macOS/iOS simulator only).
final class NativeNavigationNavbarScrollJumpScreenshotTests: XCTestCase {
    private var outputDir: String {
        if let explicit = ProcessInfo.processInfo.environment["NAVBAR_SCROLL_SCREENSHOT_OUTPUT_DIR"],
           !explicit.isEmpty {
            return explicit
        }
        if let workspace = ProcessInfo.processInfo.environment["GITHUB_WORKSPACE"], !workspace.isEmpty {
            return workspace + "/docs/screenshots/ios-navbar-scroll-jump"
        }
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.path != "/" {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir.appendingPathComponent("docs/screenshots/ios-navbar-scroll-jump").path
            }
            dir.deleteLastPathComponent()
        }
        return "docs/screenshots/ios-navbar-scroll-jump"
    }

    override func tearDown() {
        #if GENERATE_NAVBAR_SCROLL_SCREENSHOTS
        let marker = URL(fileURLWithPath: outputDir).appendingPathComponent("navbar-scroll-jump.done")
        FileManager.default.createFile(atPath: marker.path, contents: Data())
        #endif
        super.tearDown()
    }

    func testNavbarScrollCollapseLayoutSnapshotsWhenRequested() throws {
        #if !GENERATE_NAVBAR_SCROLL_SCREENSHOTS
        throw XCTSkip("Pass OTHER_SWIFT_FLAGS=-D GENERATE_NAVBAR_SCROLL_SCREENSHOTS to write PNGs")
        #endif

        let frame = CGRect(x: 0, y: 59, width: 390, height: 103)
        let hideDistance: CGFloat = 88
        let canvas = CGRect(x: 0, y: 0, width: 390, height: 220)

        let before = renderLayoutComparison(
            canvas: canvas,
            frame: frame,
            hideDistance: hideDistance,
            useBoundsAndCenter: false,
            label: "Before (frame under transform)"
        )
        let after = renderLayoutComparison(
            canvas: canvas,
            frame: frame,
            hideDistance: hideDistance,
            useBoundsAndCenter: true,
            label: "After (bounds + center)"
        )

        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        try write(png: before, name: "ios-navbar-scroll-jump-before.png")
        try write(png: after, name: "ios-navbar-scroll-jump-after.png")

        let names = ["ios-navbar-scroll-jump-before.png", "ios-navbar-scroll-jump-after.png"]
        for name in names {
            let path = URL(fileURLWithPath: outputDir).appendingPathComponent(name).path
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "Missing \(name) at \(path)")
            let attachment = XCTAttachment(contentsOfFile: URL(fileURLWithPath: path))
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func renderLayoutComparison(
        canvas: CGRect,
        frame: CGRect,
        hideDistance: CGFloat,
        useBoundsAndCenter: Bool,
        label: String
    ) -> UIImage {
        let host = UIView(frame: canvas)
        host.backgroundColor = .systemBackground

        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        container.layer.borderColor = UIColor.systemBlue.cgColor
        container.layer.borderWidth = 2
        container.transform = CGAffineTransform(translationX: 0, y: -hideDistance)
        if useBoundsAndCenter {
            nativeNavigationSetViewFrame(container, frame: frame)
        } else {
            container.frame = frame
        }

        let guide = UIView(frame: frame)
        guide.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
        guide.layer.borderColor = UIColor.systemGreen.cgColor
        guide.layer.borderWidth = 1
        guide.isUserInteractionEnabled = false

        let title = UILabel()
        title.text = label
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.numberOfLines = 2
        title.frame = CGRect(x: 12, y: canvas.height - 52, width: canvas.width - 24, height: 44)

        host.addSubview(guide)
        host.addSubview(container)
        host.addSubview(title)

        let window = UIWindow(frame: canvas)
        let controller = UIViewController()
        controller.view.addSubview(host)
        host.frame = canvas
        host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(bounds: canvas, format: format).image { context in
            host.layer.render(in: context.cgContext)
        }
    }

    private func write(png: UIImage, name: String) throws {
        let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
        guard let data = png.pngData() else {
            XCTFail("Failed to encode \(name)")
            return
        }
        try data.write(to: url)
    }
}