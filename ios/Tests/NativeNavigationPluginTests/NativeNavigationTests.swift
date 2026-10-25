import XCTest
import UIKit
@testable import NativeNavigationPlugin

class NativeNavigationTests: XCTestCase {
    func testGetPluginVersion() {
        let implementation = NativeNavigation()
        let result = implementation.getPluginVersion()

        XCTAssertEqual("native", result)
    }

    func testPullToRefreshIsOptIn() {
        let webView = UIView()
        let pullToRefresh = NativeNavigationPullToRefresh {}

        XCTAssertFalse(pullToRefresh.isEnabled)
        XCTAssertTrue(webView.gestureRecognizers?.isEmpty ?? true)

        pullToRefresh.enable(on: webView, scrollView: nil, tintColor: .red)
        XCTAssertTrue(pullToRefresh.isEnabled)
        XCTAssertEqual(webView.gestureRecognizers?.count, 1)
        XCTAssertEqual((webView.subviews.last as? UIActivityIndicatorView)?.color, .red)

        pullToRefresh.disable()
        XCTAssertFalse(pullToRefresh.isEnabled)
        XCTAssertTrue(webView.gestureRecognizers?.isEmpty ?? true)
        XCTAssertTrue(webView.subviews.isEmpty)
    }

    func testPullStateArmsAtThreshold() {
        XCTAssertEqual(nativeNavigationPullState(distance: -20), NativeNavigationPullState(offset: 0, progress: 0, armed: false))
        XCTAssertEqual(nativeNavigationPullState(distance: 45, threshold: 90), NativeNavigationPullState(offset: 22.5, progress: 0.5, armed: false))
        XCTAssertEqual(nativeNavigationPullState(distance: 90, threshold: 90), NativeNavigationPullState(offset: 45, progress: 1, armed: true))
        XCTAssertEqual(nativeNavigationPullState(distance: 190, threshold: 90).offset, 60, accuracy: 0.001)
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

    func testLiftWebViewOverlaySubviewsMovesSplashOverlayAboveContainerContent() {
        let webView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let container = UIView(frame: webView.frame)
        let tabControllerView = UIView(frame: webView.frame)
        let scrollView = UIScrollView(frame: webView.bounds)
        let splashOverlay = UIView(frame: webView.bounds)
        var liftedOverlays: [NativeNavigationWeakView] = []

        container.addSubview(webView)
        container.addSubview(tabControllerView)
        webView.addSubview(scrollView)
        webView.addSubview(splashOverlay)

        nativeNavigationLiftWebViewOverlaySubviews(
            from: webView,
            to: container,
            tracking: &liftedOverlays,
            excluding: [tabControllerView]
        )

        XCTAssertEqual(scrollView.superview, webView)
        XCTAssertEqual(splashOverlay.superview, container)
        XCTAssertTrue(container.subviews.last === splashOverlay)
        XCTAssertEqual(liftedOverlays.count, 1)
        XCTAssertTrue(liftedOverlays.first?.value === splashOverlay)
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

    func testStationaryTransitionsCrossfadeSnapshotsAway() {
        XCTAssertTrue(nativeNavigationUsesStationaryTransitionCrossfade(direction: "tab"))
        XCTAssertTrue(nativeNavigationUsesStationaryTransitionCrossfade(direction: "root"))
        XCTAssertTrue(nativeNavigationUsesStationaryTransitionCrossfade(direction: "none"))
        XCTAssertFalse(nativeNavigationUsesStationaryTransitionCrossfade(direction: "forward"))
        XCTAssertFalse(nativeNavigationUsesStationaryTransitionCrossfade(direction: "back"))
    }

    func testNavbarScrollBehaviorBothHidesAndReveals() {
        XCTAssertEqual(
            nativeNavigationNavbarScrollAction(
                behavior: .both,
                offsetY: 120,
                deltaY: 20,
                threshold: 8,
                isCollapsed: false
            ),
            .hide
        )
        XCTAssertEqual(
            nativeNavigationNavbarScrollAction(
                behavior: .both,
                offsetY: 120,
                deltaY: -20,
                threshold: 8,
                isCollapsed: true
            ),
            .reveal
        )
    }

    func testNavbarScrollHideOnScrollDownRevealsAtTop() {
        XCTAssertEqual(
            nativeNavigationNavbarScrollAction(
                behavior: .hideOnScrollDown,
                offsetY: 0,
                deltaY: 0,
                threshold: 8,
                isCollapsed: true
            ),
            .reveal
        )
    }

    func testTabbarInsetHeightsHostedSystemBarReportsSystemHeightOnly() {
        let insets = nativeNavigationTabbarInsetHeights(
            isEnabled: true,
            tabbarVisible: true,
            tabbarSoftHidden: false,
            isWebViewHostedInSystemTabController: true,
            usesSystemTabbar: true,
            nativeTabHeight: 83,
            customTabHeight: 74
        )
        XCTAssertEqual(insets.tabbarHeight, 0)
        XCTAssertEqual(insets.systemTabbarHeight, 83)
    }

    func testTabbarInsetHeightsSoftHiddenKeepsSystemHeight() {
        let insets = nativeNavigationTabbarInsetHeights(
            isEnabled: true,
            tabbarVisible: false,
            tabbarSoftHidden: true,
            isWebViewHostedInSystemTabController: true,
            usesSystemTabbar: true,
            nativeTabHeight: 83,
            customTabHeight: 74
        )
        XCTAssertEqual(insets.tabbarHeight, 0)
        XCTAssertEqual(insets.systemTabbarHeight, 83)
    }

    func testTabbarInsetHeightsNonHostedMatchesOverlap() {
        let insets = nativeNavigationTabbarInsetHeights(
            isEnabled: true,
            tabbarVisible: true,
            tabbarSoftHidden: false,
            isWebViewHostedInSystemTabController: false,
            usesSystemTabbar: true,
            nativeTabHeight: 83,
            customTabHeight: 74
        )
        XCTAssertEqual(insets.tabbarHeight, 83)
        XCTAssertEqual(insets.systemTabbarHeight, 83)
    }

    func testTabBarSemanticContentAttributeMapping() {
        XCTAssertEqual(nativeNavigationTabBarSemanticContentAttribute(layoutDirection: nil), .unspecified)
        XCTAssertEqual(nativeNavigationTabBarSemanticContentAttribute(layoutDirection: "ltr"), .forceLeftToRight)
        XCTAssertEqual(nativeNavigationTabBarSemanticContentAttribute(layoutDirection: "rtl"), .forceRightToLeft)
        XCTAssertEqual(nativeNavigationTabBarSemanticContentAttribute(layoutDirection: "auto"), .unspecified)
    }

    func testSystemTabBarLayoutDirectionUpdateDoesNotClobberAppController() {
        let omitted = nativeNavigationSystemTabBarLayoutDirectionUpdate(layoutDirection: nil, didOverrideController: false)
        XCTAssertEqual(omitted.tabBarAttribute, .unspecified)
        XCTAssertNil(omitted.controllerAttribute)
        XCTAssertFalse(omitted.didOverrideController)

        let rtl = nativeNavigationSystemTabBarLayoutDirectionUpdate(layoutDirection: "rtl", didOverrideController: false)
        XCTAssertEqual(rtl.controllerAttribute, .forceRightToLeft)
        XCTAssertTrue(rtl.didOverrideController)

        let cleared = nativeNavigationSystemTabBarLayoutDirectionUpdate(layoutDirection: nil, didOverrideController: true)
        XCTAssertEqual(cleared.controllerAttribute, .unspecified)
        XCTAssertFalse(cleared.didOverrideController)
    }

    func testFloatingTabOriginXLtrAndRtl() {
        XCTAssertEqual(
            nativeNavigationFloatingTabOriginX(
                rectMinX: 0,
                rectWidth: 300,
                position: 0,
                itemWidth: 100,
                pitch: 100,
                inset: 0,
                systemLook: false,
                layoutDirection: "ltr"
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            nativeNavigationFloatingTabOriginX(
                rectMinX: 0,
                rectWidth: 300,
                position: 0,
                itemWidth: 100,
                pitch: 100,
                inset: 0,
                systemLook: false,
                layoutDirection: "rtl"
            ),
            200,
            accuracy: 0.001
        )
        let rtlSystemOrigin = nativeNavigationFloatingTabOriginX(
            rectMinX: 10,
            rectWidth: 280,
            position: 1,
            itemWidth: 92,
            pitch: 80,
            inset: 4,
            systemLook: true,
            layoutDirection: "rtl"
        )
        let rtlSystemExpected: CGFloat = 10 + 280 - 4 - 2 * 80 - (92 - 80)
        XCTAssertEqual(rtlSystemOrigin, rtlSystemExpected, accuracy: 0.001)
    }

    func testAnimatedSystemTabbarVisibilityUsesSoftHide() {
        XCTAssertTrue(
            nativeNavigationPrefersAnimatedSystemTabbarVisibility(
                animated: true,
                usesSystemLiquidGlass: true,
                shape: "floating"
            )
        )
        XCTAssertFalse(
            nativeNavigationPrefersAnimatedSystemTabbarVisibility(
                animated: false,
                usesSystemLiquidGlass: true,
                shape: "floating"
            )
        )
        XCTAssertFalse(
            nativeNavigationPrefersAnimatedSystemTabbarVisibility(
                animated: true,
                usesSystemLiquidGlass: true,
                shape: "curve"
            )
        )
    }

    func testSVGArcDrawsCurveNotLine() {
        // Top half of a circle of radius 8 centred on (12, 21), as in a "person" icon.
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 20, y: 21))
        nativeNavigationAddSVGArc(
            to: path,
            from: CGPoint(x: 20, y: 21),
            to: CGPoint(x: 4, y: 21),
            radii: CGSize(width: 8, height: 8),
            rotation: 0,
            largeArc: false,
            sweep: false
        )

        XCTAssertEqual(path.currentPoint.x, 4, accuracy: 0.001)
        XCTAssertEqual(path.currentPoint.y, 21, accuracy: 0.001)
        XCTAssertEqual(path.bounds.minY, 13, accuracy: 0.05)
        XCTAssertEqual(path.bounds.width, 16, accuracy: 0.05)
    }

    func testFocusedSearchKeepsKeystrokesUntilTheSuppliedTextChanges() {
        XCTAssertFalse(
            nativeNavigationShouldApplyNavbarSearchText(
                focused: true,
                fieldText: "he",
                suppliedText: "h",
                previousSuppliedText: "h"
            )
        )
        XCTAssertTrue(
            nativeNavigationShouldApplyNavbarSearchText(
                focused: true,
                fieldText: "hello",
                suppliedText: "",
                previousSuppliedText: "hello"
            )
        )
        XCTAssertFalse(
            nativeNavigationShouldApplyNavbarSearchText(
                focused: true,
                fieldText: "h",
                suppliedText: "h",
                previousSuppliedText: nil
            )
        )
        XCTAssertTrue(
            nativeNavigationShouldApplyNavbarSearchText(
                focused: false,
                fieldText: "he",
                suppliedText: "h",
                previousSuppliedText: "h"
            )
        )
    }

    func testNavbarSearchRowHeightCollapsesWithTheLargeTitle() {
        XCTAssertEqual(
            nativeNavigationNavbarSearchRowHeight(visible: false, hidesWhenCollapsed: true, largeCollapsed: false),
            0
        )
        XCTAssertEqual(
            nativeNavigationNavbarSearchRowHeight(visible: true, hidesWhenCollapsed: true, largeCollapsed: false),
            52
        )
        XCTAssertEqual(
            nativeNavigationNavbarSearchRowHeight(visible: true, hidesWhenCollapsed: true, largeCollapsed: true),
            0
        )
        XCTAssertEqual(
            nativeNavigationNavbarSearchRowHeight(visible: true, hidesWhenCollapsed: false, largeCollapsed: true),
            52
        )
    }

    func testResolvedTabbarPlacementKeepsCurveOnTheBottom() {
        XCTAssertEqual(nativeNavigationResolvedTabbarPlacement(raw: "sidebar", shapeIsCurve: true), "bottom")
        XCTAssertEqual(nativeNavigationResolvedTabbarPlacement(raw: "SIDEBAR", shapeIsCurve: false), "sidebar")
        XCTAssertEqual(nativeNavigationResolvedTabbarPlacement(raw: "bottom", shapeIsCurve: false), "bottom")
        XCTAssertEqual(nativeNavigationResolvedTabbarPlacement(raw: "nope", shapeIsCurve: false), "auto")
        XCTAssertEqual(nativeNavigationResolvedTabbarPlacement(raw: nil, shapeIsCurve: false), "auto")
    }

    func testResolvedTabbarAlignment() {
        XCTAssertEqual(nativeNavigationResolvedTabbarAlignment(raw: "START"), "start")
        XCTAssertEqual(nativeNavigationResolvedTabbarAlignment(raw: "end"), "end")
        XCTAssertEqual(nativeNavigationResolvedTabbarAlignment(raw: "middle"), "center")
        XCTAssertEqual(nativeNavigationResolvedTabbarAlignment(raw: nil), "center")
    }

    func testFloatingBarOriginXFollowsAlignmentAndDirection() {
        XCTAssertEqual(
            nativeNavigationFloatingBarOriginX(containerWidth: 400, barWidth: 200, margin: 24, alignment: "center", layoutRtl: false),
            100,
            accuracy: 0.001
        )
        XCTAssertEqual(
            nativeNavigationFloatingBarOriginX(containerWidth: 400, barWidth: 200, margin: 24, alignment: "start", layoutRtl: false),
            24,
            accuracy: 0.001
        )
        XCTAssertEqual(
            nativeNavigationFloatingBarOriginX(containerWidth: 400, barWidth: 200, margin: 24, alignment: "end", layoutRtl: false),
            176,
            accuracy: 0.001
        )
        XCTAssertEqual(
            nativeNavigationFloatingBarOriginX(containerWidth: 400, barWidth: 200, margin: 24, alignment: "start", layoutRtl: true),
            176,
            accuracy: 0.001
        )
        XCTAssertEqual(
            nativeNavigationFloatingBarOriginX(containerWidth: 400, barWidth: 200, margin: 24, alignment: "end", layoutRtl: true),
            24,
            accuracy: 0.001
        )
    }

    func testSidebarOriginXSitsOnTheTrailingEdge() {
        XCTAssertEqual(
            nativeNavigationSidebarOriginX(containerWidth: 400, railWidth: 84, margin: 12, layoutRtl: false),
            304,
            accuracy: 0.001
        )
        XCTAssertEqual(
            nativeNavigationSidebarOriginX(containerWidth: 400, railWidth: 84, margin: 12, layoutRtl: true),
            12,
            accuracy: 0.001
        )
    }
}
