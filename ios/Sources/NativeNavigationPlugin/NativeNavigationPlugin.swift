// swiftlint:disable file_length

import Foundation
import Capacitor
import ObjectiveC
import UIKit

private struct NativeNavigationTransitionContext {
    let webView: UIView
    let snapshot: UIView?
    let id: String
    let direction: String
    let duration: TimeInterval
    let durationMs: Int
    let resolve: ([String: Any]) -> Void
}

private struct NativeNavigationZoomTransitionContext {
    let transition: NativeNavigationTransitionContext
    let sourceFrame: CGRect?
    let targetFrame: CGRect?
    let cornerRadius: CGFloat
}

// swiftlint:disable type_body_length
@objc(NativeNavigationPlugin)
public class NativeNavigationPlugin: CAPPlugin, CAPBridgedPlugin, UITabBarControllerDelegate, UITabBarDelegate {
    public let identifier = "NativeNavigationPlugin"
    public let jsName = "NativeNavigation"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setNavbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reportNavbarScroll", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setPullToRefresh", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endPullToRefresh", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setTabbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "beginTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "finishTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = NativeNavigation()
    private var navContainer: UIView?
    private var navBlurView: UIVisualEffectView?
    private var navBar: UINavigationBar?
    private var navSegmentsView: NativeNavigationSegmentRowsView?
    private var tabContainer: UIView?
    private var tabEffectView: UIVisualEffectView?
    private var trailingTabEffectView: UIVisualEffectView?
    private var tabBar: UITabBar?
    /// `nil` when the app did not set `edgeBlur`.
    private var tabbarEdgeBlur: Bool?
    /// `nil` when the app did not set navbar `edgeBlur`.
    private var navbarEdgeBlur: Bool?
    private var tabbarMinimizeOnScroll = false
    private var tabbarMinimized = false
    private var floatingTabBar: NativeNavigationFloatingTabBar?
    private var tabbarStyle = NativeNavigationTabbarStyleConfig()
    private var tabBarController: NativeNavigationTabController?
    private var tabViewControllers: [UIViewController] = []
    private weak var systemTabRootContainer: UIView?
    private weak var originalWebViewSuperview: UIView?
    private var originalWebViewIndex: Int?
    private var originalWebViewAutoresizingMask: UIView.AutoresizingMask?
    private var liftedWebViewOverlays: [NativeNavigationWeakView] = []
    private var isWebViewHostedInSystemTabController = false
    private var navbarHeight: CGFloat = 44
    /// Large title requested by the page, and whether scrolling folded it into the inline title.
    private var navbarLarge = false
    private var navbarLargeCollapsed = false
    private var tabbarHeight: CGFloat = NativeNavigationTabbarStyleConfig().totalHeight
    private var navbarVisible = false
    private var tabbarVisible = false
    private var tabbarSoftHidden = false
    private var tabbarSkipImmediateSystemReveal = false
    private var floatingTabBarWantsHidden = false
    private var contentInsetMode = "css"
    private var isEnabled = true
    /// Navbar buttons currently installed on either the custom bar or the rail's navigation item.
    private var navbarRailLeftItems: [UIBarButtonItem] = []
    private var navbarRailRightItems: [UIBarButtonItem] = []
    private var navbarRailTitle = ""
    private var navbarRailSubtitle: String?
    private var navbarRailLarge = false
    private var navbarItemsNeedPlacement = false
    private var navbarUsesSystemRail = false
    private var didWrapSystemNavigation = false
    private var cachedRail = NativeNavigationVerticalRail(isVertical: false, onLeft: false, width: 0)
    private var lastReportedVerticalBarEdge: String?
    private var lastReportedVerticalBarActive = false
    private var didInstallDuoObservers = false
    private var verticalBarTraitToken: Any?
    private var hingeInteractionToken: Any?
    private var hingePayload: [String: Any]?
    private var lastHingeStatus: String?
    private var defaultTransitionDuration: TimeInterval = 0.35
    private var navbarItemPlacement: [String: String] = [:]
    private var navbarItemTitle: [String: String] = [:]
    private var navbarScrollBehavior: NativeNavigationNavbarScrollBehavior = .none
    private var navbarScrollThreshold: CGFloat = 8
    private var navbarScrollCollapsed = false
    private var tabIds: [String] = []
    private var tabTitles: [String] = []
    private var tabDisplayTitles: [String?] = []
    private var tabBaseImages: [UIImage?] = []
    private var tabSelectedImages: [UIImage?] = []
    private var suppressTabSelectEvent = false
    private var tabSelectEmittedForReTap = false
    private var didOverrideSystemTabBarControllerSemanticContentAttribute = false
    private var lastSetTabbarOptions: [String: Any] = [:]
    private var transitionSnapshot: UIView?
    private var activeTransitionId: String?
    private var activeTransitionDirection = "forward"
    private var activeZoomSourceFrame: CGRect?
    private var activeZoomCornerRadius: CGFloat = 0
    private weak var activeTransitionContainer: UIView?
    private var activeTransitionContainerBackgroundColor: UIColor?
    private var activeTransitionContainerWasOpaque = false
    private var activeTransitionContainerBackgroundCaptured = false
    private lazy var pullToRefresh = NativeNavigationPullToRefresh { [weak self] in
        self?.notifyListeners("pullToRefresh", data: [:])
    }

    private var usesSystemLiquidGlass: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    /// The iOS 26 system tab bar, unless the bar is a curve or minimizes on scroll. UIKit's own
    /// minimize cannot follow WebView scrolling, so minimize uses the plugin's glass capsule.
    private var usesSystemTabBar: Bool {
        usesSystemLiquidGlass && tabbarStyle.shape != .curve && !tabbarMinimizeOnScroll
    }

    /// The capsule stands in for the iOS 26 system tab bar (minimize on scroll), so it copies the
    /// system bar's geometry and colors instead of the custom floating style.
    private var usesSystemLookCapsule: Bool {
        usesSystemLiquidGlass && tabbarStyle.shape == .floating && tabbarMinimizeOnScroll
    }

    /// Height of the iOS 26 system tab bar and its distance from the screen edges.
    private static let systemLookBarHeight: CGFloat = 62
    private static let systemLookSideMargin: CGFloat = 21

    private func systemLookBottomOffset(_ safeInsets: UIEdgeInsets) -> CGFloat {
        safeInsets.bottom > 0 ? max(safeInsets.bottom - 13, 8) : 8
    }

    /// Minimize only shrinks the floating capsule, and needs icons to stay recognizable.
    private var tabbarMinimizeActive: Bool {
        tabbarMinimized && tabbarMinimizeOnScroll && tabbarStyle.shape == .floating
    }

    override public func load() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleLayoutChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleKeyboardDidHide),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleReduceTransparencyChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        installDuoObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func configure(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.isEnabled = call.getBool("enabled", true)
            self.contentInsetMode = call.getString("contentInsetMode") ?? self.contentInsetMode
            if let duration = call.getDouble("animationDuration") {
                self.defaultTransitionDuration = duration / 1_000
            }
            if let behavior = call.getString("verticalBarBehavior") {
                NativeNavigationVerticalBarPreference.disabled = behavior == "disabled"
                self.installDuoObservers()
                self.requestVerticalBarUpdate()
            }

            if !self.isEnabled {
                self.navContainer?.isHidden = true
                self.tabContainer?.isHidden = true
                self.restoreWebViewFromSystemTabController()
                self.tabBarController?.view.isHidden = true
                self.tabBar?.isHidden = true
            }

            self.updateInsetsAndNotify()
            call.resolve(self.insetsResult())
        }
    }

    @objc func setNavbar(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard self.isEnabled else {
                self.navbarVisible = false
                self.stopNavbarScrollObservation(resetCollapsed: true)
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            let hidden = call.getBool("hidden", false)
            self.navbarVisible = !hidden
            self.navbarEdgeBlur = call.getBool("edgeBlur")
            let animated = call.getBool("animated", false)
            let large = call.getBool("large", false)
            // iOS 26 draws the subtitle under the large title, which needs another line.
            let hasSubtitle = !(call.getString("subtitle") ?? "").isEmpty
            if #available(iOS 26.0, *), large, hasSubtitle {
                self.navbarHeight = 116
            } else {
                self.navbarHeight = large ? 96 : 44
            }
            if !large || call.getBool("resetScrollCollapsed", false) {
                self.navbarLargeCollapsed = false
            }
            self.navbarLarge = large

            guard !hidden else {
                self.navContainer?.isHidden = true
                self.navbarItemsNeedPlacement = false
                self.hideSystemRailNavbar()
                self.stopNavbarScrollObservation(resetCollapsed: true)
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            let navBar = self.ensureNavBar()
            let navItem = UINavigationItem(title: call.getString("title") ?? "")
            // `prompt` draws above the title and outside the bar height, so it overlapped the status bar.
            let subtitle = call.getString("subtitle").flatMap { $0.isEmpty ? nil : $0 }
            if #available(iOS 26.0, *) {
                navItem.subtitle = subtitle
            } else if let subtitle {
                navItem.titleView = self.makeNavbarTitleView(title: navItem.title ?? "", subtitle: subtitle, options: call)
            }
            if #available(iOS 11.0, *) {
                navBar.prefersLargeTitles = large && !self.navbarLargeCollapsed
                navItem.largeTitleDisplayMode = large && !self.navbarLargeCollapsed ? .always : .never
            }

            self.navbarItemPlacement.removeAll()
            self.navbarItemTitle.removeAll()

            if let backButton = call.getObject("backButton"), backButton["visible"] as? Bool == true {
                let title = backButton["title"] as? String ?? "Back"
                let item = title.isEmpty
                    ? UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(self.handleNavbarBack))
                    : UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(self.handleNavbarBack))
                self.configureGlassBarButtonItem(item, id: "back")
                let leftItems = self.makeBarButtonItems(call.getArray("leftItems") as? [[String: Any]] ?? [], placement: "left")
                navItem.leftBarButtonItems = [item] + leftItems
            } else {
                navItem.leftBarButtonItems = self.makeBarButtonItems(call.getArray("leftItems") as? [[String: Any]] ?? [], placement: "left")
            }

            navItem.rightBarButtonItems = self.makeBarButtonItems(call.getArray("rightItems") as? [[String: Any]] ?? [], placement: "right")
            self.navbarRailTitle = navItem.title ?? ""
            self.navbarRailSubtitle = subtitle
            self.navbarRailLarge = large
            self.navbarRailLeftItems = navItem.leftBarButtonItems ?? []
            self.navbarRailRightItems = navItem.rightBarButtonItems ?? []
            self.navbarItemsNeedPlacement = true
            navBar.setItems([navItem], animated: animated)
            self.applyNavBarAppearance(navBar: navBar, options: call)
            self.applyNavbarSegments(options: call)
            self.navContainer?.isHidden = false
            self.configureNavbarScrollBehavior(from: call)
            self.layoutChrome()
            self.updateInsetsAndNotify()
            call.resolve(self.insetsResult())
        }
    }

    @objc func reportNavbarScroll(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let offsetY = CGFloat(call.getDouble("offsetY") ?? 0)
            let deltaY = CGFloat(call.getDouble("deltaY") ?? 0)
            self.pullToRefresh.reportWebScroll(offsetY: offsetY)
            if self.navbarScrollBehavior != .none, self.navbarVisible {
                self.handleNavbarScroll(offsetY: offsetY, deltaY: deltaY)
            }
            if self.navbarLarge, self.navbarVisible {
                self.setNavbarLargeCollapsed(offsetY > 30)
            }
            if self.tabbarMinimizeOnScroll, self.tabbarVisible {
                self.handleTabbarMinimizeScroll(offsetY: offsetY, deltaY: deltaY)
            }
            call.resolve()
        }
    }

    @objc func setPullToRefresh(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard call.getBool("enabled", false) else {
                self.pullToRefresh.disable()
                call.resolve()
                return
            }
            guard let webView = self.bridge?.webView else {
                call.reject("WebView unavailable")
                return
            }
            self.pullToRefresh.enable(
                on: webView,
                scrollView: webView.scrollView,
                tintColor: self.colorValue(call.getString("tintColor"))
            )
            self.pullToRefresh.updateTopInset(self.pullToRefreshTopInset())
            // Inner scroll roots (`#app`, marked elements) report offsets through the scroll bridge.
            self.installNavbarScrollBridge()
            call.resolve()
        }
    }

    private func pullToRefreshTopInset() -> CGFloat {
        let safeTop = bridge?.viewController?.view.safeAreaInsets.top ?? 0
        return max(currentInsets()["navbarHeight"] as? CGFloat ?? 0, safeTop)
    }

    @objc func endPullToRefresh(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.pullToRefresh.endRefreshing()
            call.resolve()
        }
    }

    @objc func setTabbar(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard self.isEnabled else {
                self.tabbarVisible = false
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            let hidden = call.getBool("hidden", false)
            let animated = call.getBool("animated", false)
            self.tabbarVisible = !hidden
            self.tabbarEdgeBlur = call.getBool("edgeBlur")
            let minimizeOnScroll = call.getString("minimizeBehavior") == "onScrollDown" && call.getBool("icons", true)
            if !minimizeOnScroll {
                self.tabbarMinimized = false
            }
            self.tabbarMinimizeOnScroll = minimizeOnScroll

            guard !hidden else {
                self.hideTabBarChrome(animated: animated)
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            if self.tabbarSoftHidden {
                self.tabbarSoftHidden = false
                if animated {
                    if nativeNavigationPrefersAnimatedSystemTabbarVisibility(
                        animated: true,
                        usesSystemLiquidGlass: self.usesSystemTabBar,
                        shape: self.tabbarStyle.shape == .curve ? "curve" : "floating"
                    ) {
                        self.tabbarSkipImmediateSystemReveal = true
                        self.setSystemTabBarHidden(false, animated: true, syncSubviewState: false)
                    } else {
                        self.setFloatingTabBarVisibility(hidden: false, animated: true)
                    }
                } else if self.usesSystemTabBar {
                    self.setSystemTabBarHidden(false, animated: false, syncSubviewState: true)
                } else {
                    self.setFloatingTabBarVisibility(hidden: false, animated: false)
                }
            }

            self.tabbarStyle = self.makeTabbarStyle(from: call)
            self.tabbarHeight = self.tabbarStyle.totalHeight

            let tabs = call.getArray("tabs") as? [[String: Any]] ?? []
            let selectedId = call.getString("selectedId")
            let labels = call.getBool("labels", true)
            let labelVisibilityMode = call.getString("labelVisibilityMode") ?? (labels ? "labeled" : "unlabeled")
            let icons = call.getBool("icons", true)

            if self.usesSystemTabBar {
                self.floatingTabBar?.isHidden = true
                self.tabContainer?.isHidden = true
                // Unhide before rehosting. setTabBarHidden does not recover on iOS 26
                // after the controller view itself was hidden.
                self.tabBarController?.view.isHidden = false
                let tabBar = self.ensureTabBar()
                let (items, selectedIndex) = self.makeTabBarItems(
                    tabs,
                    selectedId: selectedId,
                    labelVisibilityMode: labelVisibilityMode,
                    icons: icons
                )
                self.applySystemTabBarItems(items, selectedIndex: selectedIndex, animated: call.getBool("animated", false))
                if let options = call.options as? [String: Any] {
                    self.lastSetTabbarOptions = options
                }
                self.applyTabBarAppearance(tabBar: tabBar, options: call)
                self.applyTabBarLayoutDirection(call.getString("layoutDirection"), tabBar: tabBar)
                if items.isEmpty {
                    self.tabbarVisible = false
                    self.tabbarSkipImmediateSystemReveal = false
                    self.hideSystemTabBarChromeCompletely()
                } else {
                    self.showTabBarChrome(tabBar)
                }
            } else {
                self.restoreWebViewFromSystemTabController()
                self.tabBarController?.view.isHidden = true
                let tabBar = self.ensureFloatingTabBar()
                let (items, selectedIndex) = self.makeFloatingTabBarItems(
                    tabs,
                    selectedId: selectedId,
                    icons: icons
                )
                if items.isEmpty {
                    self.tabbarVisible = false
                    tabBar.configure(
                        items: [],
                        selectedIndex: 0,
                        labelVisibilityMode: labelVisibilityMode,
                        icons: icons,
                        style: self.tabbarStyle
                    )
                    self.tabContainer?.isHidden = true
                    tabBar.isHidden = true
                } else {
                    self.applyFloatingTabBarAppearance(tabBar: tabBar, options: call)
                    let resolvedSelectedIndex = selectedIndex ?? (items.indices.contains(tabBar.selectedIndex) ? tabBar.selectedIndex : 0)
                    tabBar.configure(
                        items: items,
                        selectedIndex: resolvedSelectedIndex,
                        labelVisibilityMode: labelVisibilityMode,
                        icons: icons,
                        style: self.tabbarStyle
                    )
                    tabBar.minimized = self.tabbarMinimizeActive
                    tabBar.systemLook = self.usesSystemLookCapsule
                    if self.tabbarMinimizeOnScroll {
                        self.installNavbarScrollBridge()
                    }
                    tabBar.onSelect = { [weak self] _, item in
                        self?.setTabbarMinimized(false, animated: true)
                        self?.notifyListeners("tabSelect", data: [
                            "id": item.id,
                            "index": item.sourceIndex,
                            "title": item.title
                        ])
                    }
                    self.showFloatingTabBarChrome(tabBar)
                }
            }
            self.layoutChrome()
            self.updateInsetsAndNotify()
            call.resolve(self.insetsResult())
        }
    }

    @objc func beginTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let webView = self.webView,
                  let transitionContainer = webView.superview else {
                call.reject("WebView unavailable")
                return
            }

            let transitionId = call.getString("id") ?? "transition-\(Int(Date().timeIntervalSince1970 * 1_000))"
            let direction = call.getString("direction") ?? "forward"
            let durationMs = Int((call.getDouble("duration") ?? self.defaultTransitionDuration * 1_000).rounded())
            let zoomSourceRect = direction == "zoom" ? self.transitionRect(call.getObject("sourceRect")) : nil
            let zoomSourceFrame = zoomSourceRect.map { self.transitionFrame(for: $0, webView: webView) }
            let cornerRadius = CGFloat(call.getDouble("cornerRadius") ?? 0)

            self.transitionSnapshot?.removeFromSuperview()
            self.restoreTransitionContainerBackground()
            let transitionSurface = nativeNavigationFallbackBackground(for: webView).withAlphaComponent(1.0)
            self.prepareTransitionContainerBackground(transitionContainer, surface: transitionSurface)
            let snapshot = self.transitionSnapshotView(from: webView, sourceRect: zoomSourceRect)
            snapshot.frame = zoomSourceFrame ?? webView.frame
            snapshot.autoresizingMask = zoomSourceFrame == nil ? [.flexibleWidth, .flexibleHeight] : []
            snapshot.backgroundColor = transitionSurface
            snapshot.isOpaque = true
            snapshot.layer.cornerRadius = cornerRadius
            snapshot.clipsToBounds = cornerRadius > 0
            transitionContainer.insertSubview(snapshot, aboveSubview: webView)
            self.bringChromeToFront()
            self.transitionSnapshot = snapshot
            self.activeTransitionId = transitionId
            self.activeTransitionDirection = direction
            self.activeZoomSourceFrame = zoomSourceFrame
            self.activeZoomCornerRadius = cornerRadius
            webView.alpha = 0.01

            let event: [String: Any] = ["id": transitionId, "direction": direction, "duration": durationMs]
            self.notifyListeners("transitionStart", data: event)
            call.resolve(event)
        }
    }

    @objc func finishTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let webView = self.webView else {
                call.reject("WebView unavailable")
                return
            }
            // A new route starts at the top; a stale offset would block the gesture.
            self.pullToRefresh.resetWebScroll()

            let transitionId = call.getString("id") ?? self.activeTransitionId ?? "transition-\(Int(Date().timeIntervalSince1970 * 1_000))"
            let direction = call.getString("direction") ?? self.activeTransitionDirection
            let duration = (call.getDouble("duration") ?? self.defaultTransitionDuration * 1_000) / 1_000
            let durationMs = Int((duration * 1_000).rounded())
            let transition = NativeNavigationTransitionContext(
                webView: webView,
                snapshot: self.transitionSnapshot,
                id: transitionId,
                direction: direction,
                duration: duration,
                durationMs: durationMs,
                resolve: { call.resolve($0) }
            )

            if direction == "zoom" {
                let sourceRect = self.transitionRect(call.getObject("sourceRect"))
                let targetRect = self.transitionRect(call.getObject("targetRect"))
                self.finishZoomTransition(NativeNavigationZoomTransitionContext(
                    transition: transition,
                    sourceFrame: sourceRect.map { self.transitionFrame(for: $0, webView: webView) },
                    targetFrame: targetRect.map { self.transitionFrame(for: $0, webView: webView) },
                    cornerRadius: CGFloat(call.getDouble("cornerRadius") ?? Double(self.activeZoomCornerRadius))
                ))
                return
            }

            self.finishStandardTransition(transition)
        }
    }

    private func finishStandardTransition(_ transition: NativeNavigationTransitionContext) {
        let width = transition.webView.bounds.width
        let transforms = standardTransitionTransforms(direction: transition.direction, width: width)
        let usesStationaryCrossfade = nativeNavigationUsesStationaryTransitionCrossfade(direction: transition.direction)
        transition.webView.transform = transforms.start
        transition.webView.alpha = usesStationaryCrossfade ? 1 : 0.01

        UIView.animate(
            withDuration: max(transition.duration, 0),
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                transition.webView.transform = .identity
                transition.webView.alpha = 1
                transition.snapshot?.transform = transforms.snapshotEnd
                transition.snapshot?.alpha = usesStationaryCrossfade ? 0 : 0.75
            },
            completion: { _ in
                self.finishTransitionCleanup(transition)
            }
        )
    }

    private func standardTransitionTransforms(direction: String, width: CGFloat) -> (start: CGAffineTransform, snapshotEnd: CGAffineTransform) {
        switch direction {
        case "back":
            return (CGAffineTransform(translationX: -width * 0.3, y: 0), CGAffineTransform(translationX: width, y: 0))
        case "tab", "root", "none":
            return (.identity, .identity)
        default:
            return (CGAffineTransform(translationX: width, y: 0), CGAffineTransform(translationX: -width * 0.3, y: 0))
        }
    }

    private func finishZoomTransition(_ zoom: NativeNavigationZoomTransitionContext) {
        let transition = zoom.transition
        let startFrame = zoom.sourceFrame ?? activeZoomSourceFrame ?? transition.webView.frame

        let finish = {
            self.finishTransitionCleanup(transition)
        }

        guard transition.duration > 0 else {
            finish()
            return
        }

        if let targetFrame = zoom.targetFrame {
            animateZoomToTarget(zoom, startFrame: startFrame, targetFrame: targetFrame, completion: finish)
            return
        }

        animateZoomToFullScreen(zoom, startFrame: startFrame, completion: finish)
    }

    private func animateZoomToTarget(
        _ zoom: NativeNavigationZoomTransitionContext,
        startFrame: CGRect,
        targetFrame: CGRect,
        completion: @escaping () -> Void
    ) {
        let transition = zoom.transition
        transition.webView.transform = .identity
        transition.webView.alpha = 0.01
        transition.snapshot?.frame = startFrame
        transition.snapshot?.layer.cornerRadius = zoom.cornerRadius
        transition.snapshot?.clipsToBounds = zoom.cornerRadius > 0

        UIView.animate(
            withDuration: transition.duration,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                transition.webView.alpha = 1
                transition.snapshot?.frame = targetFrame
                transition.snapshot?.alpha = 0
            },
            completion: { _ in completion() }
        )
    }

    private func animateZoomToFullScreen(
        _ zoom: NativeNavigationZoomTransitionContext,
        startFrame: CGRect,
        completion: @escaping () -> Void
    ) {
        let transition = zoom.transition
        let fullFrame = transition.webView.frame
        let scaleX = max(startFrame.width / max(fullFrame.width, 1), 0.01)
        let scaleY = max(startFrame.height / max(fullFrame.height, 1), 0.01)
        let translationX = startFrame.midX - fullFrame.midX
        let translationY = startFrame.midY - fullFrame.midY
        transition.webView.transform = CGAffineTransform(translationX: translationX, y: translationY).scaledBy(x: scaleX, y: scaleY)
        transition.webView.alpha = 1
        transition.webView.layer.cornerRadius = zoom.cornerRadius
        transition.webView.clipsToBounds = zoom.cornerRadius > 0
        transition.snapshot?.frame = startFrame

        UIView.animate(
            withDuration: transition.duration,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                transition.webView.transform = .identity
                transition.webView.layer.cornerRadius = 0
                transition.snapshot?.frame = fullFrame
                transition.snapshot?.alpha = 0
            },
            completion: { _ in completion() }
        )
    }

    private func finishTransitionCleanup(_ transition: NativeNavigationTransitionContext) {
        transition.snapshot?.removeFromSuperview()
        transition.webView.transform = .identity
        transition.webView.alpha = 1
        transition.webView.layer.cornerRadius = 0
        transition.webView.clipsToBounds = false
        transitionSnapshot = nil
        restoreTransitionContainerBackground()
        activeTransitionId = nil
        activeZoomSourceFrame = nil
        let event: [String: Any] = ["id": transition.id, "direction": transition.direction, "duration": transition.durationMs]
        notifyListeners("transitionEnd", data: event)
        transition.resolve(event)
    }

    private func prepareTransitionContainerBackground(_ container: UIView, surface: UIColor) {
        activeTransitionContainer = container
        activeTransitionContainerBackgroundColor = container.backgroundColor
        activeTransitionContainerWasOpaque = container.isOpaque
        activeTransitionContainerBackgroundCaptured = true
        if nativeNavigationNeedsTransitionSurface(container.backgroundColor) {
            container.backgroundColor = surface
            container.isOpaque = true
        }
    }

    private func restoreTransitionContainerBackground() {
        guard activeTransitionContainerBackgroundCaptured else {
            return
        }
        activeTransitionContainer?.backgroundColor = activeTransitionContainerBackgroundColor
        activeTransitionContainer?.isOpaque = activeTransitionContainerWasOpaque
        activeTransitionContainer = nil
        activeTransitionContainerBackgroundColor = nil
        activeTransitionContainerWasOpaque = false
        activeTransitionContainerBackgroundCaptured = false
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve([
            "version": implementation.getPluginVersion()
        ])
    }

    @objc private func handleNavbarBack() {
        notifyListeners("navbarBack", data: ["source": "navbar"])
    }

    @objc private func handleNavbarButton(_ sender: UIBarButtonItem) {
        guard let id = sender.accessibilityIdentifier else {
            return
        }
        notifyListeners("navbarItemTap", data: [
            "id": id,
            "title": navbarItemTitle[id] ?? "",
            "placement": navbarItemPlacement[id] ?? "right"
        ])
    }

    private func applyNavbarSegments(options call: CAPPluginCall) {
        let rawGroups = call.getArray("segments") as? [[String: Any]] ?? []
        let groups = rawGroups.compactMap { rawGroup -> NativeNavigationSegmentGroup? in
            guard let id = rawGroup["id"] as? String else {
                return nil
            }
            let items = (rawGroup["items"] as? [[String: Any]] ?? []).compactMap { rawItem -> NativeNavigationSegmentItem? in
                guard let itemId = rawItem["id"] as? String else {
                    return nil
                }
                let icon = rawItem["icon"] as? [String: Any]
                return NativeNavigationSegmentItem(
                    id: itemId,
                    title: rawItem["title"] as? String,
                    accessibilityLabel: rawItem["accessibilityLabel"] as? String,
                    enabled: rawItem["enabled"] as? Bool ?? true,
                    iconKey: icon
                        .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: .sortedKeys) }
                        .flatMap { String(data: $0, encoding: .utf8) } ?? "",
                    image: image(from: icon)
                )
            }
            guard !items.isEmpty else {
                return nil
            }
            return NativeNavigationSegmentGroup(
                id: id,
                items: items,
                selectedId: rawGroup["selectedId"] as? String,
                style: NativeNavigationSegmentGroup.style(from: rawGroup["style"] as? String, itemCount: items.count)
            )
        }

        guard !groups.isEmpty else {
            navSegmentsView?.apply(groups: [], tint: nil, foreground: nil)
            navSegmentsView?.isHidden = true
            return
        }
        let segmentsView: NativeNavigationSegmentRowsView
        if let existing = navSegmentsView {
            segmentsView = existing
        } else {
            segmentsView = NativeNavigationSegmentRowsView()
            segmentsView.onSelect = { [weak self] groupId, id, index in
                self?.notifyListeners("navbarSegmentSelect", data: ["groupId": groupId, "id": id, "index": index])
            }
            navContainer?.addSubview(segmentsView)
            navSegmentsView = segmentsView
        }
        let colors = call.getObject("colors")
        segmentsView.apply(groups: groups, tint: colorValue(colors?["tint"]), foreground: colorValue(colors?["foreground"]))
        // Glass and transparent bars show the container blur behind the rows; an opaque bar
        // continues its own background under them.
        if usesSystemLiquidGlass || call.getBool("transparent", false) {
            segmentsView.backgroundColor = .clear
        } else {
            segmentsView.backgroundColor = colorValue(colors?["background"]) ?? .systemBackground
        }
        segmentsView.isHidden = false
    }

    /// Height of the segment rows under the bar; part of the navbar inset.
    private var navbarSegmentsHeight: CGFloat {
        guard let view = navSegmentsView, !view.isHidden else {
            return 0
        }
        return view.contentHeight
    }

    public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        notifyTabSelect(index: item.tag)
    }

    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if usesSystemLiquidGlass {
            hostWebView(in: viewController)
        }
        tabSelectEmittedForReTap = false
        if !suppressTabSelectEvent,
           tabBarController.selectedViewController === viewController {
            notifyTabSelect(index: viewController.tabBarItem.tag)
            tabSelectEmittedForReTap = true
        }
        return true
    }

    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard !suppressTabSelectEvent else {
            tabSelectEmittedForReTap = false
            hostWebViewInSelectedSystemTab()
            refreshRailNavbarItems()
            return
        }
        let index = viewController.tabBarItem.tag
        hostWebViewInSelectedSystemTab()
        refreshRailNavbarItems()
        if !tabSelectEmittedForReTap {
            notifyTabSelect(index: index)
        }
        tabSelectEmittedForReTap = false
    }

    private func notifyTabSelect(index: Int) {
        guard index >= 0,
              index < tabIds.count,
              !tabIds[index].isEmpty else {
            return
        }
        notifyListeners("tabSelect", data: [
            "id": tabIds[index],
            "index": index,
            "title": tabTitles[index]
        ])
    }

    @objc private func handleLayoutChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.layoutChrome()
            self.updateInsetsAndNotify()
        }
    }

    @objc private func handleKeyboardFrameChange() {
        DispatchQueue.main.async {
            self.layoutChrome()
        }
    }

    @objc private func handleKeyboardDidHide() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.refreshChromeAfterKeyboardDismiss()
        }
    }

    @objc private func handleReduceTransparencyChange() {
        DispatchQueue.main.async {
            self.refreshTabBarBackgroundIfNeeded()
            self.layoutChrome()
            self.updateInsetsAndNotify()
        }
    }

    private func refreshChromeAfterKeyboardDismiss() {
        layoutChrome()
        refreshTabBarBackgroundIfNeeded()
        updateInsetsAndNotify()
    }

    private func refreshTabBarBackgroundIfNeeded() {
        guard tabbarVisible else {
            return
        }

        tabBarController?.view.setNeedsLayout()
        tabBarController?.view.layoutIfNeeded()

        if let tabBar = tabBar {
            if usesSystemLiquidGlass,
               !lastSetTabbarOptions.isEmpty,
               let refreshCall = CAPPluginCall(
                callbackId: "tabbar-refresh",
                methodName: "setTabbar",
                options: lastSetTabbarOptions,
                success: { _, _ in },
                error: { _ in }
               ) {
                applyTabBarAppearance(tabBar: tabBar, options: refreshCall)
            } else {
                tabBar.isTranslucent = !prefersOpaqueTabBarBackground()
                let standardAppearance = tabBar.standardAppearance
                tabBar.standardAppearance = standardAppearance
                if #available(iOS 15.0, *) {
                    let scrollEdgeAppearance = tabBar.scrollEdgeAppearance ?? standardAppearance
                    tabBar.scrollEdgeAppearance = scrollEdgeAppearance
                }
                tabBar.items?.forEach { item in
                    item.standardAppearance = standardAppearance
                    if #available(iOS 15.0, *) {
                        item.scrollEdgeAppearance = tabBar.scrollEdgeAppearance
                    }
                }
            }
            tabBar.setNeedsLayout()
            tabBar.layoutIfNeeded()
        }

        tabContainer?.setNeedsLayout()
        tabContainer?.layoutIfNeeded()
        floatingTabBar?.setNeedsLayout()
        floatingTabBar?.layoutIfNeeded()
    }

    private func prefersOpaqueTabBarBackground() -> Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }

    private func ensureNavBar() -> UINavigationBar {
        if let navBar = navBar {
            return navBar
        }

        let container = NativeNavigationChromeContainer()
        container.hitSlop = UIEdgeInsets(top: 0, left: 0, bottom: 32, right: 0)
        container.isUserInteractionEnabled = true
        container.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]

        if !usesSystemLiquidGlass {
            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.isUserInteractionEnabled = false
            container.addSubview(blurView)
            self.navBlurView = blurView
        }

        let bar = NativeNavigationBar()
        bar.hitSlop = UIEdgeInsets(top: 0, left: 0, bottom: 32, right: 0)
        bar.isTranslucent = true
        if !usesSystemLiquidGlass {
            bar.backgroundColor = .clear
        }
        bar.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        container.addSubview(bar)

        bridge?.viewController?.view.addSubview(container)
        self.navContainer = container
        self.navBar = bar
        return bar
    }

    private func ensureTabBar() -> UITabBar {
        if usesSystemLiquidGlass {
            return ensureSystemTabBar()
        }

        if let tabBar = tabBar {
            return tabBar
        }

        let container = NativeNavigationChromeContainer()
        container.hitSlop = UIEdgeInsets(top: 32, left: 0, bottom: 24, right: 0)
        container.isUserInteractionEnabled = true
        container.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        container.backgroundColor = .clear

        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.14
        container.layer.shadowRadius = 18
        container.layer.shadowOffset = CGSize(width: 0, height: 10)

        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        container.addSubview(effectView)
        self.tabEffectView = effectView

        let bar = UITabBar()
        bar.isTranslucent = true
        bar.backgroundColor = .clear
        bar.backgroundImage = UIImage()
        bar.shadowImage = UIImage()
        bar.clipsToBounds = true
        bar.delegate = self
        bar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        container.addSubview(bar)
        bridge?.viewController?.view.addSubview(container)
        self.tabContainer = container
        self.tabBar = bar
        return bar
    }

    private func ensureFloatingTabBar() -> NativeNavigationFloatingTabBar {
        if let floatingTabBar = floatingTabBar {
            return floatingTabBar
        }

        let container = NativeNavigationChromeContainer()
        container.hitSlop = UIEdgeInsets(top: 32, left: 0, bottom: 24, right: 0)
        container.isUserInteractionEnabled = true
        container.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        container.backgroundColor = .clear
        container.clipsToBounds = false

        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.14
        container.layer.shadowRadius = 18
        container.layer.shadowOffset = CGSize(width: 0, height: 10)

        let effectView = UIVisualEffectView(effect: liquidGlassEffect() ?? UIBlurEffect(style: .systemChromeMaterial))
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        container.addSubview(effectView)
        self.tabEffectView = effectView

        let trailingEffectView = UIVisualEffectView(effect: liquidGlassEffect() ?? UIBlurEffect(style: .systemChromeMaterial))
        trailingEffectView.autoresizingMask = []
        trailingEffectView.isUserInteractionEnabled = false
        trailingEffectView.clipsToBounds = true
        trailingEffectView.isHidden = true
        container.addSubview(trailingEffectView)
        self.trailingTabEffectView = trailingEffectView

        let bar = NativeNavigationFloatingTabBar()
        bar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        bar.clipsToBounds = false
        container.addSubview(bar)
        bridge?.viewController?.view.addSubview(container)
        self.tabContainer = container
        self.floatingTabBar = bar
        return bar
    }

    private func ensureSystemTabBar() -> UITabBar {
        installDuoObservers()
        if let tabBarController = tabBarController {
            hostWebViewInSelectedSystemTab()
            return tabBarController.tabBar
        }

        let controller = NativeNavigationTabController()
        controller.delegate = self
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.isHidden = !tabbarVisible

        if let parent = bridge?.viewController {
            let containerView = systemTabHostingContainerView(in: parent)
            parent.addChild(controller)
            insertSystemTabControllerView(controller.view, in: containerView)
            controller.didMove(toParent: parent)
        }

        self.tabBarController = controller
        self.tabBar = controller.tabBar
        liftWebViewOverlaysAboveSystemTabs()
        hostWebViewInSelectedSystemTab()
        return controller.tabBar
    }

    private func systemTabHostingContainerView(in parent: UIViewController) -> UIView {
        if let systemTabRootContainer = systemTabRootContainer {
            return systemTabRootContainer
        }

        guard let webView = webView,
              parent.view === webView else {
            return parent.view
        }

        let previousSuperview = webView.superview
        let previousIndex = previousSuperview?.subviews.firstIndex(of: webView)
        let previousFrame = webView.frame
        let previousAutoresizingMask = webView.autoresizingMask
        let container = UIView(frame: previousFrame)
        container.backgroundColor = nativeNavigationFallbackBackground(for: webView)
        container.isOpaque = true
        container.autoresizingMask = previousAutoresizingMask.isEmpty ? [.flexibleWidth, .flexibleHeight] : previousAutoresizingMask

        if let previousSuperview = previousSuperview {
            previousSuperview.insertSubview(container, at: min(previousIndex ?? previousSuperview.subviews.count, previousSuperview.subviews.count))
        }

        parent.view = container
        container.addSubview(webView)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.frame = container.bounds
        moveNativeChrome(from: webView, to: container)

        systemTabRootContainer = container
        originalWebViewSuperview = container
        originalWebViewIndex = 0
        originalWebViewAutoresizingMask = webView.autoresizingMask
        liftWebViewOverlaysAboveSystemTabs()
        return container
    }

    private func moveNativeChrome(from webView: UIView, to container: UIView) {
        if let navContainer = navContainer,
           navContainer.superview === webView {
            container.addSubview(navContainer)
        }
    }

    private func applySystemTabBarItems(_ items: [UITabBarItem], selectedIndex: Int?, animated: Bool) {
        guard let tabBarController = tabBarController else {
            return
        }

        let previousSelectedIndex = tabBarController.selectedIndex
        let controllers = systemTabContentControllers(for: items)
        let currentControllers = tabBarController.viewControllers ?? []
        let shouldUpdateControllers = currentControllers.count != controllers.count
            || zip(currentControllers, controllers).contains { currentController, nextController in
                currentController !== nextController
            }
        let shouldAnimate = animated && tabBarController.viewControllers?.count == controllers.count

        suppressTabSelectEvent = true
        defer { suppressTabSelectEvent = false }

        guard !controllers.isEmpty else {
            restoreWebViewFromSystemTabController()
            if shouldUpdateControllers {
                tabBarController.setViewControllers([], animated: false)
            }
            tabViewControllers = []
            return
        }

        if shouldUpdateControllers {
            tabBarController.setViewControllers(controllers, animated: shouldAnimate)
        }

        let fallbackIndex = selectedIndex ?? previousSelectedIndex
        let index = min(max(fallbackIndex, 0), controllers.count - 1)
        hostWebView(in: controllers[index])
        tabBarController.selectedIndex = index
        tabViewControllers = controllers
    }

    private func systemTabContentControllers(for items: [UITabBarItem]) -> [UIViewController] {
        let existingContent = tabViewControllers.compactMap { nativeNavigationTabContentController(from: $0) }
        if existingContent.count == items.count, existingContent.count == tabViewControllers.count {
            for (controller, item) in zip(tabViewControllers, items) {
                controller.tabBarItem = item
                nativeNavigationTabContentController(from: controller)?.tabBarItem = item
            }
            return tabViewControllers
        }

        return items.map { item -> UIViewController in
            let controller = NativeNavigationTabContentController()
            controller.tabBarItem = item
            guard didWrapSystemNavigation, #available(iOS 27.1, *) else {
                return controller
            }
            let navigation = UINavigationController(rootViewController: controller)
            navigation.tabBarItem = item
            navigation.setNavigationBarHidden(true, animated: false)
            return navigation
        }
    }

    private func setSystemTabBarHidden(_ hidden: Bool, animated: Bool = false, syncSubviewState: Bool = true) {
        guard let tabBarController = tabBarController else {
            return
        }

        let tabBar = tabBarController.tabBar
        if #available(iOS 18.0, *) {
            tabBarController.setTabBarHidden(hidden, animated: animated)
        } else {
            tabBar.isHidden = hidden
        }

        guard syncSubviewState else {
            return
        }

        if hidden {
            setTabBarBackgroundSubviewsHidden(true, on: tabBar)
        } else {
            setTabBarBackgroundSubviewsHidden(false, on: tabBar)
            tabBar.setNeedsLayout()
            tabBar.layoutIfNeeded()
        }
    }

    private func setTabBarBackgroundSubviewsHidden(_ hidden: Bool, on tabBar: UITabBar) {
        tabBar.isHidden = hidden
        tabBar.alpha = hidden ? 0 : 1
        tabBar.isUserInteractionEnabled = !hidden
        tabBar.subviews.forEach { subview in
            subview.isHidden = hidden
            subview.alpha = hidden ? 0 : 1
        }
    }

    private func hideSystemTabBarChromeCompletely() {
        applySystemTabBarItems([], selectedIndex: nil, animated: false)
        setSystemTabBarHidden(true)
        tabBarController?.view.isHidden = true
        tabContainer?.isHidden = true
        floatingTabBar?.isHidden = true
    }

    private func hideTabBarChrome(animated: Bool = false) {
        if nativeNavigationPrefersAnimatedSystemTabbarVisibility(
            animated: animated,
            usesSystemLiquidGlass: usesSystemTabBar,
            shape: tabbarStyle.shape == .curve ? "curve" : "floating"
        ) {
            tabbarSoftHidden = true
            setSystemTabBarHidden(true, animated: true, syncSubviewState: false)
            return
        }

        if animated {
            tabbarSoftHidden = true
            setFloatingTabBarVisibility(hidden: true, animated: true)
            return
        }

        tabbarSoftHidden = false
        if usesSystemTabBar {
            hideSystemTabBarChromeCompletely()
        } else {
            restoreWebViewFromSystemTabController()
            hideSystemTabBarChromeCompletely()
            tabBar?.isHidden = true
        }
    }

    private func setFloatingTabBarVisibility(hidden: Bool, animated: Bool) {
        floatingTabBarWantsHidden = hidden
        let targets = [tabContainer, floatingTabBar].compactMap { $0 }
        guard !targets.isEmpty else {
            return
        }

        if !animated {
            targets.forEach { view in
                view.isHidden = hidden
                view.alpha = hidden ? 0 : 1
            }
            return
        }

        if hidden {
            UIView.animate(withDuration: 0.2, animations: {
                targets.forEach { $0.alpha = 0 }
            }, completion: { finished in
                guard finished, self.floatingTabBarWantsHidden else {
                    return
                }
                targets.forEach { $0.isHidden = true }
            })
            return
        }

        targets.forEach { view in
            view.isHidden = false
            view.alpha = 0
        }
        UIView.animate(withDuration: 0.2) {
            targets.forEach { $0.alpha = 1 }
        }
    }

    private func showTabBarChrome(_ tabBar: UITabBar) {
        tabContainer?.isHidden = true
        floatingTabBar?.isHidden = true
        tabBarController?.view.isHidden = false
        if usesSystemTabBar {
            if !tabbarSkipImmediateSystemReveal {
                setSystemTabBarHidden(false)
            }
            tabbarSkipImmediateSystemReveal = false
            liftWebViewOverlaysAboveSystemTabs()
            hostWebViewInSelectedSystemTab()
        } else {
            tabBar.isHidden = false
        }
    }

    private func showFloatingTabBarChrome(_ tabBar: NativeNavigationFloatingTabBar) {
        restoreWebViewFromSystemTabController()
        tabBarController?.view.isHidden = true
        tabContainer?.isHidden = false
        tabBar.isHidden = false
    }

    private func captureOriginalWebViewPlacementIfNeeded(_ webView: UIView) {
        guard originalWebViewSuperview == nil, let superview = webView.superview else {
            return
        }

        originalWebViewSuperview = superview
        originalWebViewIndex = superview.subviews.firstIndex(of: webView)
        originalWebViewAutoresizingMask = webView.autoresizingMask
    }

    private func insertSystemTabControllerView(_ controllerView: UIView, in parentView: UIView) {
        guard let webView = webView else {
            parentView.addSubview(controllerView)
            return
        }

        captureOriginalWebViewPlacementIfNeeded(webView)
        let insertionIndex = systemTabControllerInsertionIndex(in: parentView, for: webView)
        parentView.insertSubview(controllerView, at: insertionIndex)
    }

    private func systemTabControllerInsertionIndex(in parentView: UIView, for webView: UIView) -> Int {
        if let directChild = directChild(of: parentView, containing: webView),
           let index = parentView.subviews.firstIndex(of: directChild) {
            return min(index, parentView.subviews.count)
        }

        if let originalWebViewSuperview = originalWebViewSuperview,
           originalWebViewSuperview === parentView {
            return min(originalWebViewIndex ?? parentView.subviews.count, parentView.subviews.count)
        }

        return parentView.subviews.count
    }

    private func directChild(of ancestor: UIView, containing descendant: UIView) -> UIView? {
        var current: UIView? = descendant
        while let view = current, let superview = view.superview {
            if superview === ancestor {
                return view
            }
            current = superview
        }

        return nil
    }

    private func hostWebViewInSelectedSystemTab() {
        hostWebView(in: tabBarController?.selectedViewController)
    }

    private func hostWebView(in viewController: UIViewController?) {
        guard usesSystemLiquidGlass,
              let webView = webView,
              let selectedController = nativeNavigationTabContentController(from: viewController) else {
            return
        }

        liftWebViewOverlaysAboveSystemTabs()
        captureOriginalWebViewPlacementIfNeeded(webView)
        clearHostedWebViews(matching: webView, except: selectedController, preservingSnapshots: true)
        guard selectedController.host(webView: webView) else {
            isWebViewHostedInSystemTabController = false
            return
        }
        clearHostedWebViews(matching: webView, except: selectedController)
        isWebViewHostedInSystemTabController = true
        bringLiftedWebViewOverlaysToFront()
    }

    private func liftWebViewOverlaysAboveSystemTabs() {
        guard usesSystemLiquidGlass,
              let webView = webView,
              let container = systemTabRootContainer else {
            return
        }

        nativeNavigationLiftWebViewOverlaySubviews(
            from: webView,
            to: container,
            tracking: &liftedWebViewOverlays,
            excluding: [navContainer, tabContainer, tabBarController?.view]
        )
    }

    private func bringLiftedWebViewOverlaysToFront() {
        guard let container = systemTabRootContainer else {
            return
        }

        liftedWebViewOverlays = liftedWebViewOverlays.filter { $0.value != nil }
        liftedWebViewOverlays
            .compactMap(\.value)
            .filter { $0.superview === container }
            .forEach { container.bringSubviewToFront($0) }
    }

    private func restoreWebViewFromSystemTabController() {
        guard isWebViewHostedInSystemTabController,
              let webView = webView,
              let targetSuperview = originalWebViewSuperview ?? bridge?.viewController?.view else {
            return
        }

        let insertionIndex = min(originalWebViewIndex ?? targetSuperview.subviews.count, targetSuperview.subviews.count)
        clearHostedWebViews(matching: webView)
        webView.removeFromSuperview()
        targetSuperview.insertSubview(webView, at: insertionIndex)
        webView.autoresizingMask = originalWebViewAutoresizingMask ?? [.flexibleWidth, .flexibleHeight]
        webView.frame = targetSuperview.bounds
        isWebViewHostedInSystemTabController = false
    }

    private func clearHostedWebViews(
        matching webView: UIView,
        except owner: NativeNavigationTabContentController? = nil,
        preservingSnapshots: Bool = false
    ) {
        tabViewControllers
            .compactMap { nativeNavigationTabContentController(from: $0) }
            .filter { $0 !== owner }
            .forEach { $0.clearHostedWebView(ifMatching: webView, preservingSnapshot: preservingSnapshots) }
    }

    private func makeBarButtonItems(_ rawItems: [[String: Any]], placement: String) -> [UIBarButtonItem] {
        return rawItems.map { rawItem in
            let id = rawItem["id"] as? String ?? UUID().uuidString
            let title = rawItem["title"] as? String
            let image = image(from: rawItem["icon"] as? [String: Any])
            let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(handleNavbarButton(_:)))
            if image == nil {
                item.title = title
            }
            item.isEnabled = rawItem["enabled"] as? Bool ?? true
            item.accessibilityIdentifier = id
            item.accessibilityLabel = title
            configureGlassBarButtonItem(item, id: id)
            navbarItemPlacement[id] = placement
            navbarItemTitle[id] = title ?? ""
            return item
        }
    }

    private func makeTabBarItems(
        _ tabs: [[String: Any]],
        selectedId: String?,
        labelVisibilityMode: String,
        icons: Bool
    ) -> ([UITabBarItem], Int?) {
        tabIds = []
        tabTitles = []
        tabDisplayTitles = []
        tabBaseImages = []
        tabSelectedImages = []
        var selectedIndex: Int?
        var items: [UITabBarItem] = []
        var trailingEntry: (item: UITabBarItem, title: String?, image: UIImage?, selectedImage: UIImage?)?

        for (sourceIndex, tab) in tabs.enumerated() {
            let id = tab["id"] as? String ?? "tab-\(sourceIndex)"
            let isHidden = tab["hidden"] as? Bool ?? false
            if isHidden && id != selectedId {
                continue
            }

            let rawTitle = tab["title"] as? String ?? ""
            let title = tabTitle(
                rawTitle,
                id: id,
                index: items.count,
                selectedId: selectedId,
                labelVisibilityMode: labelVisibilityMode
            )
            let image = icons ? self.image(from: tab["icon"] as? [String: Any]) : nil
            let selectedImage = icons ? self.image(from: tab["selectedIcon"] as? [String: Any]) : nil
            let role = (tab["role"] as? String)?.lowercased()
            let item: UITabBarItem
            if role == "search" || role == "prominent" {
                // iOS 26+ Liquid Glass renders `.search` as a detached trailing
                // circular action beside the floating tab capsule. Keep the
                // system-item title empty so UIKit treats it as icon-only.
                item = UITabBarItem(tabBarSystemItem: .search, tag: sourceIndex)
                item.title = nil
                if let image = image {
                    item.image = image
                }
                if let selectedImage = selectedImage {
                    item.selectedImage = selectedImage
                }
                item.accessibilityLabel = rawTitle.isEmpty ? id : rawTitle
            } else {
                item = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
                item.tag = sourceIndex
            }
            item.isEnabled = tab["enabled"] as? Bool ?? true
            if let badge = tab["badge"] {
                item.badgeValue = String(describing: badge)
            }
            while tabIds.count <= sourceIndex {
                tabIds.append("")
                tabTitles.append("")
            }
            tabIds[sourceIndex] = id
            tabTitles[sourceIndex] = rawTitle
            if role == "search" || role == "prominent" {
                trailingEntry = (item, title, image, selectedImage ?? image)
            } else {
                items.append(item)
                tabDisplayTitles.append(title)
                tabBaseImages.append(image)
                tabSelectedImages.append(selectedImage ?? image)
            }
        }

        if let trailingEntry = trailingEntry {
            items.append(trailingEntry.item)
            tabDisplayTitles.append(trailingEntry.title)
            tabBaseImages.append(trailingEntry.image)
            tabSelectedImages.append(trailingEntry.selectedImage)
        }
        if let selectedId = selectedId {
            selectedIndex = items.firstIndex(where: { item in
                tabIds.indices.contains(item.tag) && tabIds[item.tag] == selectedId
            })
        }

        return (items, selectedIndex)
    }

    private func makeFloatingTabBarItems(
        _ tabs: [[String: Any]],
        selectedId: String?,
        icons: Bool
    ) -> ([NativeNavigationFloatingTabItem], Int?) {
        var selectedIndex: Int?
        var items: [NativeNavigationFloatingTabItem] = []

        for (sourceIndex, tab) in tabs.enumerated() {
            let id = tab["id"] as? String ?? "tab-\(sourceIndex)"
            let isHidden = tab["hidden"] as? Bool ?? false
            if isHidden && id != selectedId {
                continue
            }

            let visibleIndex = items.count
            let title = tab["title"] as? String ?? ""
            let image = icons ? self.image(from: tab["icon"] as? [String: Any]) : nil
            let selectedImage = icons ? self.image(from: tab["selectedIcon"] as? [String: Any]) : nil
            let role = (tab["role"] as? String)?.lowercased()
            let isDetachedTrailing = role == "search" || role == "prominent"
            if id == selectedId {
                selectedIndex = visibleIndex
            }
            items.append(NativeNavigationFloatingTabItem(
                id: id,
                title: title,
                accessibilityTitle: title.isEmpty ? id : title,
                image: image,
                selectedImage: selectedImage,
                badge: tab["badge"].map { String(describing: $0) },
                enabled: tab["enabled"] as? Bool ?? true,
                isDetachedTrailing: isDetachedTrailing,
                sourceIndex: sourceIndex
            ))
        }

        // Keep at most one detached trailing action and place it last so the
        // capsule + circular button layout matches the system Liquid Glass pattern.
        // Skip reordering for curve bars so center-item selection stays stable.
        if tabbarStyle.shape == .floating,
           let trailingIndex = items.lastIndex(where: { $0.isDetachedTrailing }) {
            let trailing = items.remove(at: trailingIndex)
            items.removeAll(where: { $0.isDetachedTrailing })
            items.append(trailing)
            if let selectedId = selectedId {
                selectedIndex = items.firstIndex(where: { $0.id == selectedId })
            }
        }

        return (items, selectedIndex)
    }
    private func tabTitle(
        _ title: String?,
        id: String,
        index: Int,
        selectedId: String?,
        labelVisibilityMode: String
    ) -> String? {
        let isSelected = id == selectedId || (selectedId == nil && index == 0)
        switch labelVisibilityMode {
        case "unlabeled":
            return nil
        case "selected":
            return isSelected ? title : nil
        case "auto":
            let compact = bridge?.viewController?.traitCollection.horizontalSizeClass == .compact
            return compact && !isSelected ? nil : title
        default:
            return title
        }
    }

    private func image(from descriptor: [String: Any]?) -> UIImage? {
        guard let descriptor = descriptor else {
            return nil
        }
        let template = descriptor["template"] as? Bool ?? true
        if let svg = svgMarkup(from: descriptor),
           let image = SVGIconRenderer.render(svg: svg, size: iconSize(from: descriptor)) {
            return template ? image.withRenderingMode(.alwaysTemplate) : image
        }
        if let ios = descriptor["ios"] as? [String: Any] {
            if let symbol = ios["sfSymbol"] as? String, let image = UIImage(systemName: symbol) {
                return template ? image.withRenderingMode(.alwaysTemplate) : image
            }
            if let imageName = ios["image"] as? String, let image = UIImage(named: imageName) {
                return template ? image.withRenderingMode(.alwaysTemplate) : image
            }
        }
        if let svg = descriptor["svg"] as? String,
           let image = SVGIconRenderer.render(svg: svg, size: iconSize(from: descriptor)) {
            return template ? image.withRenderingMode(.alwaysTemplate) : image
        }
        if let src = descriptor["src"] as? String {
            if let svg = inlineSVG(from: src),
               let image = SVGIconRenderer.render(svg: svg, size: iconSize(from: descriptor)) {
                return template ? image.withRenderingMode(.alwaysTemplate) : image
            }
            if let image = UIImage(named: src) {
                return template ? image.withRenderingMode(.alwaysTemplate) : image
            }
        }
        return nil
    }

    private func svgMarkup(from descriptor: [String: Any]) -> String? {
        if let ios = descriptor["ios"] as? [String: Any],
           let svg = ios["svg"] as? String {
            return svg
        }
        if let svg = descriptor["svg"] as? String {
            return svg
        }
        if let src = descriptor["src"] as? String {
            return inlineSVG(from: src)
        }
        return nil
    }

    private func inlineSVG(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<svg") {
            return trimmed
        }
        let prefix = "data:image/svg+xml"
        guard trimmed.lowercased().hasPrefix(prefix),
              let commaIndex = trimmed.firstIndex(of: ",") else {
            return nil
        }
        let payload = String(trimmed[trimmed.index(after: commaIndex)...])
        if trimmed[..<commaIndex].contains(";base64") {
            guard let data = Data(base64Encoded: payload) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        return payload.removingPercentEncoding
    }

    private func iconSize(from descriptor: [String: Any]) -> CGSize {
        let width = number(from: descriptor["width"]) ?? 24
        let height = number(from: descriptor["height"]) ?? width
        return CGSize(width: max(width, 1), height: max(height, 1))
    }

    private func number(from value: Any?) -> CGFloat? {
        if let value = value as? NSNumber {
            return CGFloat(truncating: value)
        }
        if let value = value as? String,
           let number = Double(value) {
            return CGFloat(number)
        }
        return nil
    }

    private func transitionRect(_ rawRect: [String: Any]?) -> CGRect? {
        guard let rawRect = rawRect,
              let width = number(from: rawRect["width"]),
              let height = number(from: rawRect["height"]),
              width > 0,
              height > 0 else {
            return nil
        }

        return CGRect(
            x: number(from: rawRect["x"]) ?? 0,
            y: number(from: rawRect["y"]) ?? 0,
            width: width,
            height: height
        )
    }

    private func transitionFrame(for viewportRect: CGRect, webView: UIView) -> CGRect {
        guard let transitionContainer = webView.superview else {
            return CGRect(
                x: webView.frame.minX + viewportRect.minX,
                y: webView.frame.minY + viewportRect.minY,
                width: viewportRect.width,
                height: viewportRect.height
            )
        }
        return webView.convert(viewportRect, to: transitionContainer)
    }

    private func transitionSnapshotView(from webView: UIView, sourceRect: CGRect?) -> UIView {
        guard let sourceRect = sourceRect else {
            return webView.snapshotView(afterScreenUpdates: false) ?? nativeNavigationSnapshotPlaceholder(for: webView)
        }

        let cropRect = sourceRect.intersection(webView.bounds)
        guard cropRect.width > 0, cropRect.height > 0 else {
            return webView.snapshotView(afterScreenUpdates: false) ?? nativeNavigationSnapshotPlaceholder(for: webView)
        }

        let renderer = UIGraphicsImageRenderer(bounds: webView.bounds)
        let image = renderer.image { _ in
            webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: false)
        }
        let scale = image.scale
        let scaledCropRect = CGRect(
            x: cropRect.minX * scale,
            y: cropRect.minY * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        ).integral

        guard let croppedImage = image.cgImage?.cropping(to: scaledCropRect) else {
            return webView.snapshotView(afterScreenUpdates: false) ?? nativeNavigationSnapshotPlaceholder(for: webView)
        }

        let imageView = UIImageView(image: UIImage(cgImage: croppedImage, scale: scale, orientation: image.imageOrientation))
        imageView.contentMode = .scaleAspectFill
        return imageView
    }

    private func makeTabbarStyle(from call: CAPPluginCall) -> NativeNavigationTabbarStyleConfig {
        let rawStyle = call.getObject("style") ?? [:]
        let requestedShape = (rawStyle["shape"] as? String)?.lowercased()
        let shape: NativeNavigationTabbarShape = requestedShape == "curve" ? .curve : .floating
        let isCurve = shape == .curve
        let centerDiameter = max(number(from: rawStyle["centerButtonDiameter"]) ?? 56, 44)
        let height = max(number(from: rawStyle["height"]) ?? (isCurve ? 49 : 64), 44)
        let centerLift = max(number(from: rawStyle["centerButtonLift"]) ?? (centerDiameter / 2), 0)
        let bottomGap = max(number(from: rawStyle["bottomGap"]) ?? (isCurve ? 0 : 10), 0)
        let horizontalMargin = max(number(from: rawStyle["horizontalMargin"]) ?? (isCurve ? 0 : 24), 0)
        let maxWidth = max(number(from: rawStyle["maxWidth"]) ?? (isCurve ? 0 : 430), 0)
        let cornerRadius = max(number(from: rawStyle["cornerRadius"]) ?? (isCurve ? 0 : height / 2), 0)
        let centerButtonColor = (rawStyle["centerButtonColor"] as? String).flatMap { UIColor(hexString: $0) }
        let centerButtonIconColor = (rawStyle["centerButtonIconColor"] as? String).flatMap { UIColor(hexString: $0) } ?? .white

        return NativeNavigationTabbarStyleConfig(
            shape: shape,
            height: height,
            horizontalMargin: horizontalMargin,
            maxWidth: maxWidth,
            bottomGap: bottomGap,
            cornerRadius: cornerRadius,
            centerItemId: rawStyle["centerItemId"] as? String,
            centerButtonDiameter: centerDiameter,
            centerButtonLift: centerLift,
            centerButtonColor: centerButtonColor,
            centerButtonIconColor: centerButtonIconColor
        )
    }
    /// Title with a subtitle line under it, for iOS versions without `UINavigationItem.subtitle`.
    private func makeNavbarTitleView(title: String, subtitle: String, options call: CAPPluginCall) -> UIView {
        let foreground = colorValue(call.getObject("colors")?["foreground"]) ?? .label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = foreground
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        return stack
    }

    private func applyNavBarAppearance(navBar: UINavigationBar, options call: CAPPluginCall) {
        let appearance = UINavigationBarAppearance()
        let transparent = call.getBool("transparent", false)
        if usesSystemLiquidGlass {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.backgroundEffect = nil
            appearance.shadowColor = .clear
            navBlurView?.isHidden = true
        } else if transparent {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            if let effect = blurEffect(from: call.getString("blurEffect"), fallback: .systemChromeMaterial) {
                navBlurView?.effect = effect
                navBlurView?.isHidden = false
            } else {
                navBlurView?.isHidden = true
            }
        } else {
            appearance.configureWithDefaultBackground()
            navBlurView?.isHidden = true
        }

        if let colors = call.getObject("colors") {
            if let color = colorValue(colors["tint"]) {
                navBar.tintColor = color
            }
            if let color = colorValue(colors["foreground"]) {
                appearance.titleTextAttributes = [.foregroundColor: color]
                appearance.largeTitleTextAttributes = [.foregroundColor: color]
            }
            if let background = colors["background"] as? String,
               let color = colorValue(background),
               !usesSystemLiquidGlass,
               !transparent {
                appearance.backgroundColor = color
            }
        }

        // Segment rows extend the bar, so the separator belongs under them, not between.
        if !(call.getArray("segments") ?? []).isEmpty {
            appearance.shadowColor = .clear
        }

        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
    }

    private func applyTabBarAppearance(tabBar: UITabBar, options call: CAPPluginCall) {
        if usesSystemLiquidGlass {
            let standardAppearance = UITabBarAppearance()
            // Match scroll-edge background so UIKit does not swap Liquid Glass for
            // legacy material when content scrolls under the bar (iOS 26+).
            configureSystemTabBarScrollEdgeBackground(standardAppearance, options: call)
            applyTabBarColorOptions(standardAppearance, tabBar: tabBar, options: call)
            applyTabBarBadgeOptions(standardAppearance, options: call)

            let scrollEdgeAppearance = UITabBarAppearance()
            configureSystemTabBarScrollEdgeBackground(scrollEdgeAppearance, options: call)
            applyTabBarColorOptions(scrollEdgeAppearance, tabBar: tabBar, options: call)
            applyTabBarBadgeOptions(scrollEdgeAppearance, options: call)

            tabBar.isTranslucent = !prefersOpaqueTabBarBackground()
            tabBar.standardAppearance = standardAppearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = scrollEdgeAppearance
            }
            tabBar.items?.forEach { item in
                item.standardAppearance = standardAppearance
                if #available(iOS 15.0, *) {
                    item.scrollEdgeAppearance = scrollEdgeAppearance
                }
            }
            applyExperimentalBakedTintColors(tabBar: tabBar, options: call)
            return
        }

        let appearance = UITabBarAppearance()
        configureTabBarBackground(appearance, options: call)
        applyTabBarColorOptions(appearance, tabBar: tabBar, options: call)
        applyTabBarBadgeOptions(appearance, options: call)

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    private func configureTabBarBackground(_ appearance: UITabBarAppearance, options call: CAPPluginCall) {
        appearance.configureWithDefaultBackground()
        if prefersOpaqueTabBarBackground() {
            tabEffectView?.isHidden = true
            return
        }
        if let effect = blurEffect(from: call.getString("blurEffect"), fallback: nil) {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            tabEffectView?.effect = effect
            tabEffectView?.isHidden = false
        } else {
            tabEffectView?.isHidden = true
        }
    }

    private func configureSystemTabBarStandardBackground(_ appearance: UITabBarAppearance) {
        appearance.configureWithDefaultBackground()
    }

    private func configureSystemTabBarScrollEdgeBackground(_ appearance: UITabBarAppearance, options call: CAPPluginCall) {
        if call.getBool("disableTransparentOnScrollEdge", false) || prefersOpaqueTabBarBackground() {
            configureSystemTabBarStandardBackground(appearance)
        } else {
            appearance.configureWithTransparentBackground()
            appearance.shadowColor = .clear
        }
    }

    private func applyTabBarColorOptions(
        _ appearance: UITabBarAppearance,
        tabBar: UITabBar,
        options call: CAPPluginCall
    ) {
        if let colors = call.getObject("colors") {
            if let color = colorValue(colors["tint"]) {
                tabBar.tintColor = color
                applyTabItemAppearances(appearance) { itemAppearance in
                    itemAppearance.selected.iconColor = color
                    itemAppearance.selected.titleTextAttributes = [.foregroundColor: color]
                }
            }
            if let color = colorValue(colors["inactiveTint"]), !usesSystemLiquidGlass {
                tabBar.unselectedItemTintColor = color
                applyTabItemAppearances(appearance) { itemAppearance in
                    itemAppearance.normal.iconColor = color
                    itemAppearance.normal.titleTextAttributes = [.foregroundColor: color]
                }
            }
            if let color = colorValue(colors["badgeBackground"]) {
                applyTabItemAppearances(appearance) { itemAppearance in
                    itemAppearance.normal.badgeBackgroundColor = color
                    itemAppearance.selected.badgeBackgroundColor = color
                }
            }
            if let color = colorValue(colors["badgeText"]) {
                applyTabItemAppearances(appearance) { itemAppearance in
                    itemAppearance.normal.badgeTextAttributes = [.foregroundColor: color]
                    itemAppearance.selected.badgeTextAttributes = [.foregroundColor: color]
                }
            }
            if let background = colors["background"] as? String,
               let color = colorValue(background),
               !usesSystemLiquidGlass {
                appearance.backgroundColor = color
            }
        }
    }

    private func applyFloatingTabBarAppearance(tabBar: NativeNavigationFloatingTabBar, options call: CAPPluginCall) {
        let colors = call.getObject("colors")
        let backgroundTint = colorValue(colors?["background"])
        let backgroundColor = (backgroundTint ?? .systemBackground).withAlphaComponent(tabbarStyle.shape == .curve ? 0.96 : 0.46)
        let usesLiquidGlass = liquidGlassEffect() != nil

        if tabbarStyle.shape == .curve || prefersOpaqueTabBarBackground() {
            tabEffectView?.isHidden = true
            trailingTabEffectView?.isHidden = true
        } else if let glass = liquidGlassEffect() {
            tabEffectView?.effect = glass
            tabEffectView?.isHidden = false
            tabEffectView?.contentView.backgroundColor = backgroundTint?.withAlphaComponent(0.08) ?? .clear
            trailingTabEffectView?.effect = liquidGlassEffect() ?? glass
            trailingTabEffectView?.contentView.backgroundColor = backgroundTint?.withAlphaComponent(0.08) ?? .clear
        } else if let effect = blurEffect(from: call.getString("blurEffect"), fallback: .systemChromeMaterial) {
            tabEffectView?.effect = effect
            tabEffectView?.isHidden = false
            tabEffectView?.contentView.backgroundColor = backgroundTint?.withAlphaComponent(0.12) ?? backgroundColor
            trailingTabEffectView?.effect = effect
            trailingTabEffectView?.contentView.backgroundColor = backgroundTint?.withAlphaComponent(0.12) ?? backgroundColor
        } else {
            tabEffectView?.isHidden = true
            trailingTabEffectView?.isHidden = true
        }

        let opaqueBackground = backgroundTint ?? .systemBackground
        if tabbarStyle.shape == .curve {
            // Curve hides the glass effect view, so the drawn fill has to stay visible.
            tabBar.backgroundFillColor = backgroundColor
        } else if prefersOpaqueTabBarBackground() {
            tabBar.backgroundFillColor = opaqueBackground
        } else if usesLiquidGlass {
            // Keep the hand-drawn fill clear so UIGlassEffect can show through.
            tabBar.backgroundFillColor = .clear
        } else {
            tabBar.backgroundFillColor = backgroundColor
        }
        if let color = colorValue(colors?["tint"]) {
            tabBar.selectedTintColor = color
        }
        if let color = colorValue(colors?["inactiveTint"]) {
            tabBar.inactiveTintColor = color
        }
        if let color = colorValue(call.getString("badgeBackgroundColor")) ?? colorValue(colors?["badgeBackground"]) {
            tabBar.badgeBackgroundColor = color
        }
        if let color = colorValue(call.getString("badgeTextColor")) ?? colorValue(colors?["badgeText"]) {
            tabBar.badgeTextColor = color
        }
        tabBar.layoutDirection = call.getString("layoutDirection")
        tabBar.setNeedsLayout()
    }

    private func applyTabBarLayoutDirection(_ layoutDirection: String?, tabBar: UITabBar) {
        let update = nativeNavigationSystemTabBarLayoutDirectionUpdate(
            layoutDirection: layoutDirection,
            didOverrideController: didOverrideSystemTabBarControllerSemanticContentAttribute
        )
        tabBar.semanticContentAttribute = update.tabBarAttribute
        if let controllerAttribute = update.controllerAttribute {
            tabBarController?.view.semanticContentAttribute = controllerAttribute
        }
        didOverrideSystemTabBarControllerSemanticContentAttribute = update.didOverrideController
        tabBar.setNeedsLayout()
        tabBarController?.view.setNeedsLayout()
    }

    private func applyTabBarBadgeOptions(_ appearance: UITabBarAppearance, options call: CAPPluginCall) {
        if let color = colorValue(call.getString("badgeBackgroundColor")) {
            applyTabItemAppearances(appearance) { itemAppearance in
                itemAppearance.normal.badgeBackgroundColor = color
                itemAppearance.selected.badgeBackgroundColor = color
            }
        }
        if let color = colorValue(call.getString("badgeTextColor")) {
            applyTabItemAppearances(appearance) { itemAppearance in
                itemAppearance.normal.badgeTextAttributes = [.foregroundColor: color]
                itemAppearance.selected.badgeTextAttributes = [.foregroundColor: color]
            }
        }
    }

    private func applyExperimentalBakedTintColors(tabBar: UITabBar, options call: CAPPluginCall) {
        guard shouldUseExperimentalBakedTintColors(options: call),
              let items = tabBar.items,
              let colors = call.getObject("colors") else {
            return
        }

        let activeTint = colorValue(colors["tint"]) ?? tabBar.tintColor ?? .tintColor
        let inactiveTint = colorValue(colors["inactiveTint"]) ?? tabBar.unselectedItemTintColor ?? .secondaryLabel
        guard colorValue(colors["tint"]) != nil || colorValue(colors["inactiveTint"]) != nil else {
            return
        }

        let labelVisibilityMode = tabLabelVisibilityMode(options: call)
        for (index, item) in items.enumerated() {
            let visibleTitle = tabDisplayTitles.indices.contains(index) ? (tabDisplayTitles[index] ?? "") : (item.title ?? "")
            let rawTitle = tabTitles.indices.contains(item.tag) ? tabTitles[item.tag] : visibleTitle
            let titles = bakedTintTitles(rawTitle: rawTitle, visibleTitle: visibleTitle, labelVisibilityMode: labelVisibilityMode)
            let icon = tabBaseImages.indices.contains(index) ? (tabBaseImages[index] ?? item.image) : item.image
            let selectedIcon = tabSelectedImages.indices.contains(index)
                ? (tabSelectedImages[index] ?? icon)
                : icon
            guard !titles.normal.isEmpty || !titles.selected.isEmpty || icon != nil || selectedIcon != nil else {
                continue
            }

            let accessibilityTitle = rawTitle.isEmpty ? visibleTitle : rawTitle
            if !accessibilityTitle.isEmpty {
                item.accessibilityLabel = accessibilityTitle
            }
            item.title = ""
            item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 100)
            item.image = makeTabBarItemImage(icon: icon, title: titles.normal, color: inactiveTint)
            item.selectedImage = makeTabBarItemImage(icon: selectedIcon, title: titles.selected, color: activeTint)
        }
    }

    private func shouldUseExperimentalBakedTintColors(options call: CAPPluginCall) -> Bool {
        guard usesSystemLiquidGlass,
              call.getBool("experimentalBakedTintColors", false) else {
            return false
        }

        return ["auto", "selected", "labeled", "unlabeled"].contains(tabLabelVisibilityMode(options: call))
    }

    private func tabLabelVisibilityMode(options call: CAPPluginCall) -> String {
        let labels = call.getBool("labels", true)
        return call.getString("labelVisibilityMode") ?? (labels ? "labeled" : "unlabeled")
    }

    private func bakedTintTitles(rawTitle: String, visibleTitle: String, labelVisibilityMode: String) -> (normal: String, selected: String) {
        switch labelVisibilityMode {
        case "unlabeled":
            return (normal: "", selected: "")
        case "selected":
            return (normal: "", selected: rawTitle)
        case "auto":
            let compact = bridge?.viewController?.traitCollection.horizontalSizeClass == .compact
            return compact ? (normal: "", selected: rawTitle) : (normal: rawTitle, selected: rawTitle)
        case "labeled":
            return (normal: rawTitle, selected: rawTitle)
        default:
            return (normal: visibleTitle, selected: visibleTitle)
        }
    }

    private func makeTabBarItemImage(icon: UIImage?, title: String, color: UIColor) -> UIImage {
        let iconSize = CGSize(width: 27, height: 27)
        let font = UIFont.systemFont(ofSize: 10, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let hasTitle = !title.isEmpty
        let titleSize = hasTitle ? (title as NSString).size(withAttributes: attributes) : .zero
        let imageSize = hasTitle
            ? CGSize(width: max(iconSize.width, ceil(titleSize.width)) + 8, height: iconSize.height + 3 + ceil(titleSize.height))
            : iconSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale

        let image = UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            if let icon {
                let tintedIcon = icon.withTintColor(color, renderingMode: .alwaysOriginal)
                let iconFrame = aspectFitRect(
                    size: tintedIcon.size,
                    in: CGRect(
                        x: (imageSize.width - iconSize.width) / 2,
                        y: 0,
                        width: iconSize.width,
                        height: iconSize.height
                    )
                )
                tintedIcon.draw(in: iconFrame)
            }
            if hasTitle {
                (title as NSString).draw(
                    in: CGRect(
                        x: 0,
                        y: iconSize.height + 3,
                        width: imageSize.width,
                        height: ceil(titleSize.height)
                    ),
                    withAttributes: attributes
                )
            }
        }

        return image.withRenderingMode(.alwaysOriginal)
    }

    private func aspectFitRect(size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return rect
        }

        let scale = min(rect.width / size.width, rect.height / size.height)
        let fittedSize = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: rect.minX + (rect.width - fittedSize.width) / 2,
            y: rect.minY + (rect.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private func applyTabItemAppearances(
        _ appearance: UITabBarAppearance,
        update: (UITabBarItemAppearance) -> Void
    ) {
        update(appearance.stackedLayoutAppearance)
        update(appearance.inlineLayoutAppearance)
        update(appearance.compactInlineLayoutAppearance)
    }

    // iPhone Duo's closed display moves the status bar to a side rail, so the top inset is zero
    // and the bar buttons would touch the rounded top edge. Keep a small gap there.
    private func navbarTopInset(_ safeInsets: UIEdgeInsets) -> CGFloat {
        safeInsets.top > 0 ? safeInsets.top : 8
    }

    private func configureNavbarScrollBehavior(from call: CAPPluginCall) {
        if call.getBool("resetScrollCollapsed", false) {
            setNavbarScrollCollapsed(false, animated: false)
        }

        navbarScrollBehavior = nativeNavigationNavbarScrollBehavior(from: call.getString("scrollBehavior"))
        if let threshold = call.getDouble("scrollThreshold") {
            navbarScrollThreshold = CGFloat(threshold)
        }

        if navbarLarge, navbarVisible {
            // The large title folds on scroll, so it needs scroll samples even without scrollBehavior.
            installNavbarScrollBridge()
        }
        guard navbarScrollBehavior != .none, navbarVisible else {
            stopNavbarScrollObservation(resetCollapsed: true)
            return
        }

        startNavbarScrollObservation()
    }

    private func startNavbarScrollObservation() {
        installNavbarScrollBridge()
    }

    private func stopNavbarScrollObservation(resetCollapsed: Bool) {
        if resetCollapsed {
            setNavbarScrollCollapsed(false, animated: false)
        }
    }

    private func installNavbarScrollBridge() {
        let threshold = navbarScrollThreshold
        let script = """
        (function(){
          const plugin = window.Capacitor?.Plugins?.NativeNavigation;
          if (!plugin?.reportNavbarScroll) { return; }
          const core = window.__capNativeNavigationScrollCore ||= { samples: new WeakMap(), bound: new WeakSet() };
          const readOffset = (target) => {
            const raw = target === window ? window.scrollY : target.scrollTop;
            const max = target === window
              ? Math.max(0, document.documentElement.scrollHeight - window.innerHeight)
              : Math.max(0, target.scrollHeight - target.clientHeight);
            return Math.min(Math.max(0, raw), max);
          };
          const bind = (target) => {
            if (!target || core.bound.has(target)) { return; }
            core.bound.add(target);
            target.addEventListener('scroll', () => {
              const offsetY = readOffset(target);
              const previous = core.samples.get(target) ?? offsetY;
              const deltaY = offsetY - previous;
              core.samples.set(target, offsetY);
              plugin.reportNavbarScroll({ offsetY, deltaY });
            }, { passive: true });
          };
          bind(window);
          bind(document.getElementById('app'));
          document.querySelectorAll('[data-cap-native-navigation-scroll]').forEach((node) => bind(node));
        })();
        """
        bridge?.webView?.evaluateJavaScript(script)
    }

    /// Fold the large title into the inline title once the page scrolls, like a UINavigationController
    /// does for its content scroll view. Insets keep the large height so web content does not jump.
    private func setNavbarLargeCollapsed(_ collapsed: Bool) {
        guard navbarLargeCollapsed != collapsed, let navBar else {
            return
        }
        navbarLargeCollapsed = collapsed
        UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            navBar.prefersLargeTitles = !collapsed
            navBar.topItem?.largeTitleDisplayMode = collapsed ? .never : .always
            self.layoutChrome()
            navBar.layoutIfNeeded()
        }
        applyNavbarEdgeBlur(navbarHeight: currentInsets()["navbarHeight"] as? CGFloat ?? 0)
    }

    private func handleTabbarMinimizeScroll(offsetY: CGFloat, deltaY: CGFloat) {
        let action = nativeNavigationNavbarScrollAction(
            behavior: .both,
            offsetY: offsetY,
            deltaY: deltaY,
            threshold: navbarScrollThreshold,
            isCollapsed: tabbarMinimized
        )
        switch action {
        case .hide:
            setTabbarMinimized(true, animated: true)
        case .reveal:
            setTabbarMinimized(false, animated: true)
        case .none:
            break
        }
    }

    /// Revolut-style minimize: every icon stays, labels fold away and the capsule shrinks in both dimensions.
    private func setTabbarMinimized(_ minimized: Bool, animated: Bool) {
        guard tabbarMinimized != minimized, !minimized || tabbarMinimizeOnScroll else {
            return
        }
        tabbarMinimized = minimized
        let apply = {
            self.floatingTabBar?.minimized = self.tabbarMinimizeActive
            self.layoutChrome()
            self.floatingTabBar?.layoutIfNeeded()
        }
        guard animated else {
            apply()
            return
        }
        UIView.animate(
            withDuration: 0.36,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: apply
        )
    }

    private func handleNavbarScroll(offsetY: CGFloat, deltaY: CGFloat) {
        let action = nativeNavigationNavbarScrollAction(
            behavior: navbarScrollBehavior,
            offsetY: offsetY,
            deltaY: deltaY,
            threshold: navbarScrollThreshold,
            isCollapsed: navbarScrollCollapsed
        )

        switch action {
        case .hide:
            setNavbarScrollCollapsed(true, animated: true)
        case .reveal:
            setNavbarScrollCollapsed(false, animated: true)
        case .none:
            break
        }
    }

    private func setNavbarScrollCollapsed(_ collapsed: Bool, animated: Bool) {
        guard navbarScrollCollapsed != collapsed else {
            return
        }
        navbarScrollCollapsed = collapsed
        applyNavbarScrollCollapsedAppearance(animated: animated)
        if animated && !collapsed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                self.updateInsetsAndNotify()
            }
        } else {
            updateInsetsAndNotify()
        }
    }

    private func applyNavbarScrollCollapsedAppearance(animated: Bool) {
        guard let container = navContainer else {
            return
        }

        let hideDistance = navbarHeight + navbarSegmentsHeight
        let updates = {
            if self.navbarScrollCollapsed {
                container.transform = CGAffineTransform(translationX: 0, y: -hideDistance)
                container.alpha = 0
            } else {
                container.transform = .identity
                container.alpha = 1
            }
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }

    private func layoutChrome() {
        guard let rootView = bridge?.viewController?.view else {
            return
        }
        rootView.layoutIfNeeded()
        let safeInsets = rootView.safeAreaInsets
        let width = rootView.bounds.width
        let height = rootView.bounds.height

        if let container = systemTabRootContainer {
            container.frame = rootView.bounds
            // Capacitor's root view is the WKWebView. After the webview is
            // hosted in a tab content controller, stretching it to this
            // container's full bounds overflows the tab VC (clipsToBounds is
            // off) and paints over the system tab bar.
            if !isWebViewHostedInSystemTabController {
                webView?.frame = container.bounds
            }
        }

        if let tabBarController = tabBarController {
            tabBarController.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
        }

        let tabBarFrame = usesSystemTabBar ? (tabBarController?.tabBar.frame ?? .zero) : .zero
        cachedRail = nativeNavigationVerticalRail(tabBarFrame: tabBarFrame, containerWidth: width)
        syncDuoRailChrome(rail: cachedRail)

        if let container = navContainer {
            let segmentsHeight = navbarSegmentsHeight
            if navbarUsesSystemRail {
                // The title and buttons live in the rail. Segment rows are a custom
                // view, so they stay horizontal and clear the rail.
                navBar?.isHidden = true
                navBlurView?.isHidden = true
                if navbarVisible && segmentsHeight > 0 {
                    let barWidth = max(0, width - safeInsets.left - safeInsets.right)
                    container.isHidden = false
                    container.frame = CGRect(x: safeInsets.left, y: safeInsets.top, width: barWidth, height: segmentsHeight)
                    navSegmentsView?.frame = container.bounds
                } else {
                    container.isHidden = true
                }
            } else {
                let topInset = navbarTopInset(safeInsets)
                let visibleNavbarHeight = navbarLarge && navbarLargeCollapsed ? 44 : navbarHeight
                container.frame = CGRect(x: 0, y: 0, width: width, height: topInset + visibleNavbarHeight + segmentsHeight)
                navBlurView?.frame = container.bounds
                navBar?.isHidden = false
                navBar?.frame = CGRect(x: 0, y: topInset, width: width, height: visibleNavbarHeight)
                navSegmentsView?.frame = CGRect(x: 0, y: topInset + visibleNavbarHeight, width: width, height: segmentsHeight)
                // The bar isn't hosted by a UINavigationController, so it starts with 8pt margins and the
                // large title sits off the system content margin. Match the hosting controller's margins.
                if let margins = bridge?.viewController?.systemMinimumLayoutMargins {
                    navBar?.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: margins.leading, bottom: 0, trailing: margins.trailing)
                }
            }
        }

        if let container = tabContainer {
            let systemLook = usesSystemLookCapsule
            let horizontalMargin = systemLook ? Self.systemLookSideMargin : tabbarStyle.horizontalMargin
            // Safe left/right are 0 in portrait on a phone. On Duo, and in landscape,
            // they keep the capsule off the rail and the notch.
            let safeSpan = max(0, width - safeInsets.left - safeInsets.right)
            let availableWidth = max(0, safeSpan - (horizontalMargin * 2))
            let maxWidth = tabbarStyle.maxWidth > 0 ? tabbarStyle.maxWidth : availableWidth
            let hasDetachedTrailing = floatingTabBar?.hasDetachedTrailing == true && tabbarStyle.shape == .floating
            let trailingDiameter = systemLook ? Self.systemLookBarHeight : tabbarStyle.height
            let trailingGap: CGFloat = 10
            let trailingExtra = hasDetachedTrailing ? trailingDiameter + trailingGap : 0
            let minimizeProgress: CGFloat = tabbarMinimizeActive ? 1 : 0
            let minimizedSideInset = 24 * minimizeProgress
            let tabbarWidth = max(0, min(availableWidth, maxWidth + trailingExtra) - minimizedSideInset * 2)
            let curveExtendsToBottom = tabbarStyle.shape == .curve && tabbarStyle.horizontalMargin == 0 && tabbarStyle.bottomGap == 0
            let bottomExtension = curveExtendsToBottom ? safeInsets.bottom : 0
            let contentHeight = (systemLook ? Self.systemLookBarHeight : tabbarStyle.height) - 16 * minimizeProgress
            let barTop = tabbarStyle.shape == .curve ? tabbarStyle.centerButtonLift : 0
            let totalHeight = contentHeight + barTop
            let originX = safeInsets.left + (safeSpan - tabbarWidth) / 2
            // Keep the home-indicator fill inside the screen. The previous origin
            // pushed that extension below the bezel and left labels on the edge.
            let originY = systemLook
                ? height - systemLookBottomOffset(safeInsets) - totalHeight
                : height - tabbarStyle.bottomGap - totalHeight - bottomExtension - (curveExtendsToBottom ? 0 : safeInsets.bottom)
            container.frame = CGRect(x: originX, y: originY, width: tabbarWidth, height: totalHeight + bottomExtension)
            floatingTabBar?.curveContentHeightOverride = tabbarStyle.shape == .curve ? contentHeight : nil
            floatingTabBar?.frame = container.bounds
            floatingTabBar?.layer.cornerRadius = 0
            floatingTabBar?.layoutIfNeeded()

            let capsuleBounds = floatingTabBar?.capsuleBounds(in: container.bounds) ?? container.bounds
            let floatingCornerRadius = systemLook ? capsuleBounds.height / 2 : min(tabbarStyle.cornerRadius, capsuleBounds.height / 2)
            container.layer.cornerRadius = tabbarStyle.shape == .floating ? floatingCornerRadius : 0
            // Liquid Glass brings its own depth; the custom capsule's drop shadow reads as a second edge.
            container.layer.shadowOpacity = systemLook ? 0 : 0.14
            container.layer.shadowPath = NativeNavigationTabbarBackgroundPath.path(in: capsuleBounds, style: tabbarStyle).cgPath
            tabEffectView?.frame = capsuleBounds
            tabEffectView?.layer.cornerRadius = tabbarStyle.shape == .floating ? floatingCornerRadius : 0
            tabEffectView?.isHidden = tabbarStyle.shape == .curve || prefersOpaqueTabBarBackground() || tabEffectView?.effect == nil

            if let trailingBounds = floatingTabBar?.trailingActionBounds(in: container.bounds),
               hasDetachedTrailing,
               !prefersOpaqueTabBarBackground() {
                trailingTabEffectView?.frame = trailingBounds
                trailingTabEffectView?.layer.cornerRadius = trailingBounds.height / 2
                trailingTabEffectView?.isHidden = trailingTabEffectView?.effect == nil
            } else {
                trailingTabEffectView?.isHidden = true
            }
        }

        bringChromeToFront()
    }

    private func bringChromeToFront() {
        if usesSystemTabBar {
            if let tabBarController = tabBarController {
                (systemTabRootContainer ?? bridge?.viewController?.view)?.bringSubviewToFront(tabBarController.view)
            }
            if let navContainer = navContainer {
                (systemTabRootContainer ?? bridge?.viewController?.view)?.bringSubviewToFront(navContainer)
            }
            bringLiftedWebViewOverlaysToFront()
            return
        }

        if let navContainer = navContainer {
            bridge?.viewController?.view.bringSubviewToFront(navContainer)
        }
        if let tabContainer = tabContainer {
            bridge?.viewController?.view.bringSubviewToFront(tabContainer)
        }
        if let tabBarController = tabBarController {
            bridge?.viewController?.view.bringSubviewToFront(tabBarController.view)
        }
    }

    private func colorValue(_ value: Any?) -> UIColor? {
        guard let value = value as? String else {
            return nil
        }

        switch value {
        case "ios:label", "system:label":
            return .label
        case "ios:secondaryLabel", "system:secondaryLabel":
            return .secondaryLabel
        case "ios:systemBackground", "system:background":
            return .systemBackground
        case "ios:secondarySystemBackground", "system:secondaryBackground":
            return .secondarySystemBackground
        default:
            return UIColor(hexString: value)
        }
    }

    private func blurEffect(from value: String?, fallback: UIBlurEffect.Style?) -> UIBlurEffect? {
        guard value != "none" else {
            return nil
        }
        guard let style = blurStyle(from: value) ?? fallback else {
            return nil
        }
        return UIBlurEffect(style: style)
    }

    private func blurStyle(from value: String?) -> UIBlurEffect.Style? {
        guard let value = value else {
            return nil
        }
        return [
            "extraLight": .extraLight,
            "light": .light,
            "dark": .dark,
            "regular": .regular,
            "prominent": .prominent,
            "systemUltraThinMaterial": .systemUltraThinMaterial,
            "systemThinMaterial": .systemThinMaterial,
            "systemMaterial": .systemMaterial,
            "systemThickMaterial": .systemThickMaterial,
            "systemUltraThinMaterialLight": .systemUltraThinMaterialLight,
            "systemThinMaterialLight": .systemThinMaterialLight,
            "systemMaterialLight": .systemMaterialLight,
            "systemThickMaterialLight": .systemThickMaterialLight,
            "systemUltraThinMaterialDark": .systemUltraThinMaterialDark,
            "systemThinMaterialDark": .systemThinMaterialDark,
            "systemMaterialDark": .systemMaterialDark,
            "systemThickMaterialDark": .systemThickMaterialDark,
            "systemDefault": .systemChromeMaterial,
            "systemChromeMaterial": .systemChromeMaterial,
            "systemChromeMaterialLight": .systemChromeMaterialLight,
            "systemChromeMaterialDark": .systemChromeMaterialDark
        ][value]
    }

    private func liquidGlassEffect() -> UIVisualEffect? {
        guard usesSystemLiquidGlass else {
            return nil
        }
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return UIGlassEffect(style: .regular)
        }
        #endif
        return nil
    }

    private func configureGlassBarButtonItem(_ item: UIBarButtonItem, id: String) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            item.identifier = id
            item.sharesBackground = true
            item.hidesSharedBackground = false
        }
        #endif
    }

    private func installDuoObservers() {
        guard !didInstallDuoObservers, bridge?.viewController != nil else {
            return
        }
        didInstallDuoObservers = true
        #if compiler(>=6.4)
        installVerticalBarForwarding()
        installVerticalBarTraitObserver()
        installHingeObserver()
        #endif
    }

    private func requestVerticalBarUpdate() {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            bridge?.viewController?.setNeedsUpdateOfVerticalBarConfiguration()
            tabBarController?.setNeedsUpdateOfVerticalBarConfiguration()
            tabViewControllers.forEach { $0.setNeedsUpdateOfVerticalBarConfiguration() }
        }
        #endif
    }

    private func traitVerticalBarEdge() -> String? {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            switch bridge?.viewController?.traitCollection.verticalBarEdge {
            case .leading:
                return "leading"
            case .trailing:
                return "trailing"
            default:
                return nil
            }
        }
        #endif
        return nil
    }

    private func reservedRegionPayload() -> [[String: Any]] {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *), let view = bridge?.viewController?.view {
            return duoReservedRegions(in: view)
        }
        #endif
        return []
    }

    private func notifyVerticalBarChange(_ insets: [String: Any]) {
        let edge = insets["verticalBarEdge"] as? String
        let active = cachedRail.isVertical && !NativeNavigationVerticalBarPreference.disabled
        guard edge != lastReportedVerticalBarEdge || active != lastReportedVerticalBarActive else {
            return
        }
        lastReportedVerticalBarEdge = edge
        lastReportedVerticalBarActive = active
        notifyListeners("verticalBarChanged", data: [
            "edge": edge ?? NSNull(),
            "active": active
        ])
    }

    private func syncDuoRailChrome(rail: NativeNavigationVerticalRail) {
        let railEngaged = rail.isVertical && usesSystemTabBar && !NativeNavigationVerticalBarPreference.disabled
        if railEngaged {
            wrapSystemNavigationForRail()
        }
        let useRail = railEngaged && didWrapSystemNavigation && navbarVisible
        let modeChanged = useRail != navbarUsesSystemRail
        navbarUsesSystemRail = useRail
        let placedOnRail = useRail && (modeChanged || navbarItemsNeedPlacement)
        if placedOnRail {
            placeNavbarItemsOnSelectedContent()
            navbarItemsNeedPlacement = false
        } else if !useRail && modeChanged {
            restoreNavbarItemsToCustomBar()
            navbarItemsNeedPlacement = false
        } else if navbarItemsNeedPlacement {
            navbarItemsNeedPlacement = false
        }
        applyDuoNavbarVisibility()
        // Items assigned after the rail is already visible stay on the horizontal
        // bar until UIKit is asked to place them.
        if placedOnRail {
            requestVerticalBarUpdate()
        }
    }

    /// UIKit only moves navbar items that belong to a navigation controller.
    /// Wrap once, after the tab bar itself is a rail, so a normal iPhone never
    /// gains an extra navigation controller.
    private func wrapSystemNavigationForRail() {
        guard !didWrapSystemNavigation, #available(iOS 27.1, *) else {
            return
        }
        guard let tabBarController, !tabViewControllers.isEmpty else {
            return
        }
        let selectedIndex = tabBarController.selectedIndex
        let wrapped: [UIViewController] = tabViewControllers.map { controller in
            if controller is UINavigationController {
                return controller
            }
            let content = nativeNavigationTabContentController(from: controller) ?? controller
            let navigation = UINavigationController(rootViewController: content)
            navigation.tabBarItem = content.tabBarItem
            navigation.setNavigationBarHidden(true, animated: false)
            return navigation
        }
        didWrapSystemNavigation = true
        tabViewControllers = wrapped
        tabBarController.setViewControllers(wrapped, animated: false)
        let index = min(max(selectedIndex, 0), wrapped.count - 1)
        tabBarController.selectedIndex = index
        hostWebView(in: wrapped[index])
    }

    private func hideSystemRailNavbar() {
        tabViewControllers
            .compactMap { $0 as? UINavigationController }
            .forEach { $0.setNavigationBarHidden(true, animated: false) }
    }

    private func refreshRailNavbarItems() {
        guard navbarUsesSystemRail else {
            return
        }
        placeNavbarItemsOnSelectedContent()
    }

    private func releaseStoredNavbarButtons() {
        navBar?.topItem?.leftBarButtonItems = nil
        navBar?.topItem?.rightBarButtonItems = nil
        for controller in tabViewControllers {
            guard let content = nativeNavigationTabContentController(from: controller) else {
                continue
            }
            content.navigationItem.leftBarButtonItems = nil
            content.navigationItem.rightBarButtonItems = nil
        }
    }

    private func applyStoredNavbarContent(to item: UINavigationItem) {
        item.title = navbarRailTitle
        if #available(iOS 26.0, *) {
            item.subtitle = navbarRailSubtitle
        }
        if #available(iOS 11.0, *) {
            item.largeTitleDisplayMode = navbarRailLarge && !navbarLargeCollapsed ? .always : .never
        }
        item.leftBarButtonItems = navbarRailLeftItems
        item.rightBarButtonItems = navbarRailRightItems
    }

    private func placeNavbarItemsOnSelectedContent() {
        let content = nativeNavigationTabContentController(from: tabBarController?.selectedViewController)
            ?? tabViewControllers.compactMap { nativeNavigationTabContentController(from: $0) }.first
        guard let content else {
            return
        }
        releaseStoredNavbarButtons()
        applyStoredNavbarContent(to: content.navigationItem)
        if #available(iOS 11.0, *) {
            content.navigationController?.navigationBar.prefersLargeTitles = navbarRailLarge && !navbarLargeCollapsed
        }
    }

    private func restoreNavbarItemsToCustomBar() {
        guard navbarVisible else {
            return
        }
        let bar = ensureNavBar()
        releaseStoredNavbarButtons()
        let item = UINavigationItem(title: navbarRailTitle)
        applyStoredNavbarContent(to: item)
        if #available(iOS 11.0, *) {
            bar.prefersLargeTitles = navbarRailLarge && !navbarLargeCollapsed
        }
        bar.setItems([item], animated: false)
        bar.isHidden = false
    }

    private func applyDuoNavbarVisibility() {
        let navigations = tabViewControllers.compactMap { $0 as? UINavigationController }
        if navbarUsesSystemRail && navbarVisible {
            navigations.forEach { $0.setNavigationBarHidden(false, animated: false) }
            navBar?.isHidden = true
            navBlurView?.isHidden = true
            navContainer?.isHidden = navbarSegmentsHeight == 0
            if let source = navBar {
                for navigation in navigations {
                    let bar = navigation.navigationBar
                    bar.standardAppearance = source.standardAppearance
                    bar.scrollEdgeAppearance = source.scrollEdgeAppearance
                    bar.compactAppearance = source.compactAppearance
                    bar.tintColor = source.tintColor
                }
            }
            return
        }

        navigations.forEach { $0.setNavigationBarHidden(true, animated: false) }
        navBar?.isHidden = false
        if navbarVisible {
            navContainer?.isHidden = false
        }
    }

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private func duoReservedRegions(in view: UIView) -> [[String: Any]] {
        let regions = view.reservedRegions(kind: .division) + view.reservedRegions(kind: .occlusion)
        return regions.map { region in
            [
                "kind": region.kind == .division ? "division" : "occlusion",
                "x": region.frame.origin.x,
                "y": region.frame.origin.y,
                "width": region.frame.size.width,
                "height": region.frame.size.height,
                "active": region.isActive
            ]
        }
    }

    private func installVerticalBarForwarding() {
        guard #available(iOS 27.1, *), let bridgeViewController = bridge?.viewController else {
            return
        }
        let currentClass: AnyClass = object_getClass(bridgeViewController) ?? type(of: bridgeViewController)
        let currentName = NSStringFromClass(currentClass)
        if currentName.hasSuffix("_CapNativeVerticalBar") {
            return
        }
        let subclassName = currentName + "_CapNativeVerticalBar"
        let subclass: AnyClass
        if let existing = NSClassFromString(subclassName) {
            subclass = existing
        } else {
            guard let created = objc_allocateClassPair(currentClass, subclassName, 0) else {
                return
            }
            let block: @convention(block) (AnyObject) -> UIViewController? = { object in
                (object as? UIViewController)?.children.first { $0 is NativeNavigationTabController }
            }
            let implementation = imp_implementationWithBlock(block)
            class_addMethod(
                created,
                NSSelectorFromString("childViewControllerForPreferredVerticalBarBehavior"),
                implementation,
                "@@:"
            )
            objc_registerClassPair(created)
            subclass = created
        }
        object_setClass(bridgeViewController, subclass)
    }

    private func installVerticalBarTraitObserver() {
        guard verticalBarTraitToken == nil, let viewController = bridge?.viewController else {
            return
        }
        if #available(iOS 27.1, *) {
            verticalBarTraitToken = viewController.registerForTraitChanges(
                UITraitCollection.systemTraitsAffectingVerticalBarEdge
            ) { [weak self] (_: UIViewController, _: UITraitCollection) in
                self?.updateInsetsAndNotify()
            }
        }
    }

    private func installHingeObserver() {
        guard hingeInteractionToken == nil, let view = bridge?.viewController?.view else {
            return
        }
        if #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { [weak self] _, update in
                self?.handleHingeUpdate(update)
            }
            view.addInteraction(interaction)
            hingeInteractionToken = interaction
        }
    }

    @available(iOS 27.1, *)
    private func handleHingeUpdate(_ update: UIHingeInteraction.Update) {
        guard let hinge = update.hinge else {
            hingePayload = nil
            lastHingeStatus = nil
            notifyListeners("hingeChanged", data: ["hinge": NSNull()])
            return
        }
        let status: String
        switch hinge.status {
        case .closed:
            status = "closed"
        case .partiallyOpen:
            status = "partiallyOpen"
        case .fullyOpen:
            status = "fullyOpen"
        default:
            status = "unknown"
        }
        let payload: [String: Any] = ["angle": hinge.angle, "status": status]
        hingePayload = payload
        notifyListeners("hingeChanged", data: ["hinge": payload])
        guard status != lastHingeStatus else {
            return
        }
        lastHingeStatus = status
        updateInsetsAndNotify()
    }
    #endif

    private func currentInsets() -> [String: Any] {
        let rootView = bridge?.viewController?.view
        let safeInsets = rootView?.safeAreaInsets ?? .zero
        let rootWidth = rootView?.bounds.width ?? 0
        // In the rail the title is not a top bar. Only custom segment rows still
        // occupy the top of the WebView.
        let topInset = navbarUsesSystemRail ? 0 : navbarTopInset(safeInsets)
        let barHeight: CGFloat = navbarUsesSystemRail
            ? navbarSegmentsHeight
            : (navbarScrollCollapsed ? 0 : navbarHeight + navbarSegmentsHeight)
        let navHeight = isEnabled && navbarVisible ? barHeight + topInset : 0
        let usesSystemTabbar = usesSystemTabBar
        let nativeTabHeight = max(tabBar?.frame.height ?? 0, 49 + safeInsets.bottom)
        let customTabHeight = usesSystemLookCapsule
            ? Self.systemLookBarHeight + systemLookBottomOffset(safeInsets)
            : tabbarHeight + safeInsets.bottom + tabbarStyle.bottomGap
        // Hosted in the tab content VC: the WebView already ends above the
        // bar. Reporting the bar height as CSS overlap lifts the FAB by a
        // second bar.
        let tabInsets = nativeNavigationTabbarInsetHeights(
            isEnabled: isEnabled,
            tabbarVisible: tabbarVisible,
            tabbarSoftHidden: tabbarSoftHidden,
            isWebViewHostedInSystemTabController: isWebViewHostedInSystemTabController,
            usesSystemTabbar: usesSystemTabbar,
            nativeTabHeight: nativeTabHeight,
            customTabHeight: customTabHeight
        )
        let contentView = isWebViewHostedInSystemTabController
            ? nativeNavigationTabContentController(from: tabBarController?.selectedViewController)?.view
            : nil
        let duo = nativeNavigationDuoEdgeInsets(
            rootSafe: safeInsets,
            contentSafe: contentView?.safeAreaInsets ?? safeInsets,
            rootWidth: rootWidth,
            contentWidth: contentView?.bounds.width ?? rootWidth,
            rail: cachedRail,
            hosted: isWebViewHostedInSystemTabController,
            horizontalTabbarHeight: tabInsets.tabbarHeight,
            horizontalSystemTabbarHeight: tabInsets.systemTabbarHeight
        )
        let edge = nativeNavigationResolvedVerticalBarEdge(
            traitEdge: traitVerticalBarEdge(),
            rail: cachedRail,
            layoutRtl: rootView?.effectiveUserInterfaceLayoutDirection == .rightToLeft
        )
        return [
            "top": navHeight,
            "right": duo.right,
            "bottom": duo.bottom,
            "left": duo.left,
            "navbarHeight": navHeight,
            "tabbarHeight": duo.tabbarHeight,
            "systemTabbarHeight": duo.systemTabbarHeight,
            "verticalBarEdge": edge ?? NSNull(),
            "reservedRegions": reservedRegionPayload(),
            "hinge": hingePayload ?? NSNull()
        ]
    }

    private func insetsResult() -> [String: Any] {
        return ["insets": currentInsets()]
    }

    private func updateInsetsAndNotify() {
        layoutChrome()
        let insets = currentInsets()
        notifyListeners("safeAreaChanged", data: ["insets": insets])
        notifyVerticalBarChange(insets)
        applyTabbarEdgeBlur(tabbarHeight: insets["tabbarHeight"] as? CGFloat ?? 0)
        applyNavbarEdgeBlur(navbarHeight: insets["navbarHeight"] as? CGFloat ?? 0)
        pullToRefresh.updateTopInset(pullToRefreshTopInset())
        guard contentInsetMode != "none" else {
            return
        }
        let top = insets["top"] as? CGFloat ?? 0
        let right = insets["right"] as? CGFloat ?? 0
        let bottom = insets["bottom"] as? CGFloat ?? 0
        let left = insets["left"] as? CGFloat ?? 0
        let navbar = insets["navbarHeight"] as? CGFloat ?? 0
        let tabbar = insets["tabbarHeight"] as? CGFloat ?? 0
        let systemTabbar = insets["systemTabbarHeight"] as? CGFloat ?? 0
        let edge = insets["verticalBarEdge"] as? String ?? ""
        let division = (insets["reservedRegions"] as? [[String: Any]])?.first { region in
            region["kind"] as? String == "division"
        }
        let divisionX = (division?["x"] as? NSNumber)?.doubleValue ?? (division?["x"] as? CGFloat).map(Double.init) ?? 0
        let divisionWidth = (division?["width"] as? NSNumber)?.doubleValue ?? (division?["width"] as? CGFloat).map(Double.init) ?? 0
        let detailJson = jsonString(["insets": insets])
        let script = """
        (() => {
          const root = document.documentElement;
          root.style.setProperty('--cap-native-navigation-top', '\(top)px');
          root.style.setProperty('--cap-native-navigation-right', '\(right)px');
          root.style.setProperty('--cap-native-navigation-bottom', '\(bottom)px');
          root.style.setProperty('--cap-native-navigation-left', '\(left)px');
          root.style.setProperty('--cap-native-navbar-height', '\(navbar)px');
          root.style.setProperty('--cap-native-tabbar-height', '\(tabbar)px');
          root.style.setProperty('--cap-native-system-tabbar-height', '\(systemTabbar)px');
          root.style.setProperty('--cap-native-navigation-vertical-bar-edge', '\(edge)');
          root.style.setProperty('--cap-native-navigation-division-x', '\(divisionX)px');
          root.style.setProperty('--cap-native-navigation-division-width', '\(divisionWidth)px');
          window.dispatchEvent(new CustomEvent('capNativeNavigation:safeAreaChanged', { detail: \(detailJson) }));
        })();
        """
        bridge?.webView?.evaluateJavaScript(script)
    }

    /// Progressive blur under the tabbar, drawn by the page with CSS backdrop-filter so it follows web
    /// scrolling for free. Stacked layers with growing masks fade the blur out above the bar.
    private func applyTabbarEdgeBlur(tabbarHeight: CGFloat) {
        // The system tab bar blurs content scrolling under it. The capsule that replaces it for
        // minimize does the same unless the app turned edgeBlur off.
        let wantsBlur = tabbarEdgeBlur ?? usesSystemLookCapsule
        let active = isEnabled && wantsBlur && tabbarVisible && tabbarHeight > 0
        let height = active ? Int(tabbarHeight.rounded()) + 48 : 0
        bridge?.webView?.evaluateJavaScript(edgeBlurScript(top: false, height: height))
    }

    /// iOS 26 navbars are clear glass and rely on the scroll edge effect of the content scroll
    /// view, which the WebView does not get. Draw the same progressive blur under the navbar.
    private func applyNavbarEdgeBlur(navbarHeight: CGFloat) {
        let wantsBlur = navbarEdgeBlur ?? usesSystemLiquidGlass
        let active = isEnabled && wantsBlur && navbarVisible && navbarHeight > 0
        // Follow the visible bar: a folded large title is shorter than the inset it keeps.
        let folded = navbarLarge && navbarLargeCollapsed ? self.navbarHeight - 44 : 0
        let height = active ? Int((navbarHeight - folded).rounded()) + 48 : 0
        bridge?.webView?.evaluateJavaScript(edgeBlurScript(top: true, height: height))
    }

    private func edgeBlurScript(top: Bool, height: Int) -> String {
        let id = top ? "cap-native-navigation-edge-blur-top" : "cap-native-navigation-edge-blur"
        let edge = top ? "top" : "bottom"
        let direction = top ? "to bottom" : "to top"
        return """
        (function(height){
          var id = '\(id)';
          var root = document.getElementById(id);
          if (!(height > 0)) { if (root) { root.remove(); } return; }
          if (!root) {
            root = document.createElement('div');
            root.id = id;
            root.setAttribute('aria-hidden', 'true');
            root.style.cssText = 'position:fixed;left:0;right:0;\(edge):0;pointer-events:none;z-index:2147483646;';
            [100, 84, 68, 52, 36, 20].forEach(function(h){
              var layer = document.createElement('div');
              var mask = 'linear-gradient(\(direction),#000 0%,#000 ' + Math.round(h * 0.6) + '%,transparent ' + h + '%)';
              layer.style.cssText = 'position:absolute;left:0;right:0;top:0;bottom:0;-webkit-backdrop-filter:blur(2px);'
                + 'backdrop-filter:blur(2px);-webkit-mask-image:' + mask + ';mask-image:' + mask + ';';
              root.appendChild(layer);
            });
          }
          if (root.parentNode !== document.body && document.body) { document.body.appendChild(root); }
          root.style.height = height + 'px';
        })(\(height));
        """
    }

    private func jsonString(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
// swiftlint:enable type_body_length

// swiftlint:disable cyclomatic_complexity function_body_length identifier_name
private struct NativeNavigationSVGArc {
    let radii: CGSize
    let rotation: CGFloat
    let largeArc: Bool
    let sweep: Bool
    let end: CGPoint
}

/// Draws an SVG elliptical arc as cubic Béziers (SVG 1.1 appendix F.6.5 endpoint-to-center conversion).
func nativeNavigationAddSVGArc(
    to path: UIBezierPath,
    from start: CGPoint,
    to end: CGPoint,
    radii: CGSize,
    rotation: CGFloat,
    largeArc: Bool,
    sweep: Bool
) {
    var rx = abs(radii.width)
    var ry = abs(radii.height)
    guard rx > 0, ry > 0, start != end else {
        path.addLine(to: end)
        return
    }
    let phi = rotation * .pi / 180
    let cosPhi = cos(phi)
    let sinPhi = sin(phi)
    let dx = (start.x - end.x) / 2
    let dy = (start.y - end.y) / 2
    let x1 = cosPhi * dx + sinPhi * dy
    let y1 = -sinPhi * dx + cosPhi * dy
    let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
    if lambda > 1 {
        rx *= sqrt(lambda)
        ry *= sqrt(lambda)
    }
    let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
    var factor = denominator == 0 ? 0 : sqrt(max(0, numerator / denominator))
    if largeArc == sweep {
        factor = -factor
    }
    let cxPrime = factor * rx * y1 / ry
    let cyPrime = -factor * ry * x1 / rx
    let cx = cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2
    let cy = sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2

    func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
        let value = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return value
    }
    let theta1 = angle(1, 0, (x1 - cxPrime) / rx, (y1 - cyPrime) / ry)
    var delta = angle((x1 - cxPrime) / rx, (y1 - cyPrime) / ry, (-x1 - cxPrime) / rx, (-y1 - cyPrime) / ry)
    if !sweep && delta > 0 {
        delta -= 2 * .pi
    } else if sweep && delta < 0 {
        delta += 2 * .pi
    }

    let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
    let step = delta / CGFloat(segments)
    let handle = 4 / 3 * tan(step / 4)
    func pointOnEllipse(_ theta: CGFloat) -> CGPoint {
        CGPoint(
            x: cx + rx * cos(theta) * cosPhi - ry * sin(theta) * sinPhi,
            y: cy + rx * cos(theta) * sinPhi + ry * sin(theta) * cosPhi
        )
    }
    func derivative(_ theta: CGFloat) -> CGPoint {
        CGPoint(
            x: -rx * sin(theta) * cosPhi - ry * cos(theta) * sinPhi,
            y: -rx * sin(theta) * sinPhi + ry * cos(theta) * cosPhi
        )
    }
    var theta = theta1
    for index in 0..<segments {
        let nextTheta = theta + step
        let from = pointOnEllipse(theta)
        let to = index == segments - 1 ? end : pointOnEllipse(nextTheta)
        let d1 = derivative(theta)
        let d2 = derivative(nextTheta)
        path.addCurve(
            to: to,
            controlPoint1: CGPoint(x: from.x + handle * d1.x, y: from.y + handle * d1.y),
            controlPoint2: CGPoint(x: to.x - handle * d2.x, y: to.y - handle * d2.y)
        )
        theta = nextTheta
    }
}

private struct SVGRenderStyle {
    var fill = true
    var stroke = false
    var strokeWidth: CGFloat = 2
    var lineCap: CGLineCap = .butt
    var lineJoin: CGLineJoin = .miter
    var opacity: CGFloat = 1

    mutating func apply(_ attributes: [String: String]) {
        if let fillValue = attributes["fill"] {
            fill = fillValue.lowercased() != "none"
        }
        if let strokeValue = attributes["stroke"] {
            stroke = strokeValue.lowercased() != "none"
        }
        if let width = SVGIconRenderer.length(attributes["stroke-width"]) {
            strokeWidth = width
        }
        if let opacityValue = SVGIconRenderer.length(attributes["opacity"]) {
            opacity = max(0, min(opacityValue, 1))
        }
        if let cap = attributes["stroke-linecap"]?.lowercased() {
            switch cap {
            case "round":
                lineCap = .round
            case "square":
                lineCap = .square
            default:
                lineCap = .butt
            }
        }
        if let join = attributes["stroke-linejoin"]?.lowercased() {
            switch join {
            case "round":
                lineJoin = .round
            case "bevel":
                lineJoin = .bevel
            default:
                lineJoin = .miter
            }
        }
    }
}
private struct NativeNavigationFloatingTabItem {
    let id: String
    let title: String
    let accessibilityTitle: String
    let image: UIImage?
    let selectedImage: UIImage?
    let badge: String?
    let enabled: Bool
    let isDetachedTrailing: Bool
    let sourceIndex: Int
}

private enum NativeNavigationTabbarShape {
    case floating
    case curve
}

private struct NativeNavigationTabbarStyleConfig {
    var shape: NativeNavigationTabbarShape = .floating
    var height: CGFloat = 64
    var horizontalMargin: CGFloat = 24
    var maxWidth: CGFloat = 430
    var bottomGap: CGFloat = 10
    var cornerRadius: CGFloat = 32
    var centerItemId: String?
    var centerButtonDiameter: CGFloat = 56
    var centerButtonLift: CGFloat = 28
    var centerButtonColor: UIColor?
    var centerButtonIconColor: UIColor = .white

    var barTop: CGFloat {
        shape == .curve ? centerButtonLift : 0
    }

    var totalHeight: CGFloat {
        height + barTop
    }
}

private enum NativeNavigationTabbarBackgroundPath {
    static func path(in bounds: CGRect, style: NativeNavigationTabbarStyleConfig) -> UIBezierPath {
        guard style.shape == .curve else {
            return UIBezierPath(roundedRect: bounds, cornerRadius: style.cornerRadius)
        }

        let barRect = CGRect(x: 0, y: style.barTop, width: bounds.width, height: max(bounds.maxY - style.barTop, 1))
        let cornerRadius = min(style.cornerRadius, barRect.height / 2)
        let centerX = bounds.midX
        let centerRadius = style.centerButtonDiameter / 2
        let centerTop = max(0, barRect.minY - style.centerButtonLift)
        let centerY = centerTop + centerRadius
        let dyToBarTop = barRect.minY - centerY
        let shoulderWidth = sqrt(max(0, centerRadius * centerRadius - dyToBarTop * dyToBarTop))
        let leftShoulder = max(barRect.minX + cornerRadius, centerX - shoulderWidth)
        let startAngle = atan2(dyToBarTop, -shoulderWidth)
        var endAngle = atan2(dyToBarTop, shoulderWidth)
        if endAngle <= startAngle {
            endAngle += .pi * 2
        }
        let path = UIBezierPath()

        path.move(to: CGPoint(x: barRect.minX + cornerRadius, y: barRect.minY))
        path.addLine(to: CGPoint(x: leftShoulder, y: barRect.minY))
        if shoulderWidth > 0 {
            path.addArc(withCenter: CGPoint(x: centerX, y: centerY), radius: centerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        }
        path.addLine(to: CGPoint(x: barRect.maxX - cornerRadius, y: barRect.minY))
        path.addQuadCurve(to: CGPoint(x: barRect.maxX, y: barRect.minY + cornerRadius), controlPoint: CGPoint(x: barRect.maxX, y: barRect.minY))
        path.addLine(to: CGPoint(x: barRect.maxX, y: barRect.maxY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: barRect.maxX - cornerRadius, y: barRect.maxY), controlPoint: CGPoint(x: barRect.maxX, y: barRect.maxY))
        path.addLine(to: CGPoint(x: barRect.minX + cornerRadius, y: barRect.maxY))
        path.addQuadCurve(to: CGPoint(x: barRect.minX, y: barRect.maxY - cornerRadius), controlPoint: CGPoint(x: barRect.minX, y: barRect.maxY))
        path.addLine(to: CGPoint(x: barRect.minX, y: barRect.minY + cornerRadius))
        path.addQuadCurve(to: CGPoint(x: barRect.minX + cornerRadius, y: barRect.minY), controlPoint: CGPoint(x: barRect.minX, y: barRect.minY))
        path.close()
        return path
    }
}

private struct NativeNavigationFloatingTabStyle {
    let selected: Bool
    let labels: Bool
    let icons: Bool
    let isCenter: Bool
    let isDetachedTrailing: Bool
    let selectedTint: UIColor
    let inactiveTint: UIColor
    let centerButtonColor: UIColor
    let centerButtonIconColor: UIColor
    let badgeBackgroundColor: UIColor
    let badgeTextColor: UIColor
    let showsSelectionBackground: Bool
    let systemLook: Bool
}

private final class NativeNavigationFloatingTabBar: UIView {
    private var items: [NativeNavigationFloatingTabItem] = []
    private var buttons: [NativeNavigationFloatingTabButton] = []
    private var labelVisibilityMode = "labeled"
    private var iconsVisible = true
    private let backgroundShapeView = NativeNavigationTabbarBackgroundView()
    private var tabbarStyle = NativeNavigationTabbarStyleConfig()
    var curveContentHeightOverride: CGFloat?
    var minimized = false {
        didSet {
            guard minimized != oldValue else {
                return
            }
            buttons.forEach { $0.labelsCollapsed = minimized }
            setNeedsLayout()
        }
    }
    /// Copy the iOS 26 system tab bar: label-colored items and a neutral selection pill.
    var systemLook = false {
        didSet {
            guard systemLook != oldValue else {
                return
            }
            updateButtons()
        }
    }

    var selectedIndex = 0
    var selectedTintColor = UIColor.systemBlue {
        didSet { updateButtons() }
    }
    var inactiveTintColor = UIColor.secondaryLabel {
        didSet { updateButtons() }
    }
    var badgeBackgroundColor = UIColor.systemRed {
        didSet { updateButtons() }
    }
    var badgeTextColor = UIColor.white {
        didSet { updateButtons() }
    }
    var backgroundFillColor = UIColor.systemBackground.withAlphaComponent(0.46) {
        didSet {
            backgroundShapeView.fillColor = backgroundFillColor
        }
    }
    var onSelect: ((Int, NativeNavigationFloatingTabItem) -> Void)?
    var layoutDirection: String?

    private var usesRtlLayout: Bool {
        layoutDirection == "rtl"
    }

    var hasDetachedTrailing: Bool {
        tabbarStyle.shape == .floating && items.contains(where: \.isDetachedTrailing)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundShapeView.isUserInteractionEnabled = false
        backgroundShapeView.fillColor = backgroundFillColor
        addSubview(backgroundShapeView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        items: [NativeNavigationFloatingTabItem],
        selectedIndex: Int,
        labelVisibilityMode: String,
        icons: Bool,
        style: NativeNavigationTabbarStyleConfig
    ) {
        self.items = items
        self.labelVisibilityMode = labelVisibilityMode
        self.iconsVisible = icons
        self.tabbarStyle = style
        self.selectedIndex = items.indices.contains(selectedIndex) ? selectedIndex : 0
        backgroundShapeView.style = style
        rebuildButtons()
        setNeedsLayout()
    }

    func capsuleBounds(in bounds: CGRect) -> CGRect {
        guard hasDetachedTrailing else {
            return bounds
        }
        let trailingGap: CGFloat = 10
        let trailingDiameter = systemLook ? bounds.height : min(tabbarStyle.height, bounds.height)
        let capsuleWidth = max(0, bounds.width - trailingDiameter - trailingGap)
        let capsuleX = usesRtlLayout ? bounds.minX + trailingDiameter + trailingGap : bounds.minX
        return CGRect(x: capsuleX, y: bounds.minY, width: capsuleWidth, height: bounds.height)
    }

    func trailingActionBounds(in bounds: CGRect) -> CGRect? {
        guard hasDetachedTrailing else {
            return nil
        }
        let trailingDiameter = systemLook ? bounds.height : min(tabbarStyle.height, bounds.height)
        let trailingX = usesRtlLayout ? bounds.minX : bounds.maxX - trailingDiameter
        return CGRect(
            x: trailingX,
            y: bounds.minY + (bounds.height - trailingDiameter) / 2,
            width: trailingDiameter,
            height: trailingDiameter
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let capsule = capsuleBounds(in: bounds)
        backgroundShapeView.frame = capsule
        // Unfolding resizes the bar without a new style pass. Rebuild the shadow
        // from the current bounds so the cradle stays a circle around the button.
        superview?.layer.shadowPath = NativeNavigationTabbarBackgroundPath.path(in: capsule, style: tabbarStyle).cgPath
        guard !buttons.isEmpty else {
            return
        }

        if let centerIndex = centerButtonIndex(), buttons.indices.contains(centerIndex) {
            let buttonDiameter = tabbarStyle.centerButtonDiameter
            let centerGap = min(buttonDiameter + 4, bounds.width * 0.34)
            let barFrame = CGRect(x: 0, y: tabbarStyle.barTop, width: bounds.width, height: curveContentHeightOverride ?? tabbarStyle.height)
            let leftWidth = max(0, bounds.midX - centerGap / 2)
            let rightX = min(bounds.width, bounds.midX + centerGap / 2)
            let centerFrame = CGRect(
                x: bounds.midX - buttonDiameter / 2,
                y: max(0, tabbarStyle.barTop - tabbarStyle.centerButtonLift),
                width: buttonDiameter,
                height: buttonDiameter
            )

            buttons[centerIndex].frame = centerFrame
            let rightSegment = CGRect(x: rightX, y: barFrame.minY, width: bounds.width - rightX, height: barFrame.height)
            let leftSegment = CGRect(x: 0, y: barFrame.minY, width: leftWidth, height: barFrame.height)
            if usesRtlLayout {
                layoutButtons(Array(0..<centerIndex), in: rightSegment)
                layoutButtons(Array((centerIndex + 1)..<buttons.count), in: leftSegment)
            } else {
                layoutButtons(Array(0..<centerIndex), in: leftSegment)
                layoutButtons(Array((centerIndex + 1)..<buttons.count), in: rightSegment)
            }
            return
        }

        if let trailingIndex = detachedTrailingIndex(),
           buttons.indices.contains(trailingIndex),
           let trailingBounds = trailingActionBounds(in: bounds) {
            buttons[trailingIndex].frame = trailingBounds
            let mainIndices = buttons.indices.filter { $0 != trailingIndex }
            layoutButtons(mainIndices, in: capsule)
            return
        }

        layoutButtons(Array(buttons.indices), in: bounds)
    }

    /// iOS 26 tab bar metrics: items sit 4pt inside the capsule and each selection pill is about
    /// 8pt wider than the item pitch, so neighbouring items overlap slightly.
    private func layoutSystemLookButtons(_ indices: [Int], in rect: CGRect) {
        let inset: CGFloat = 4
        let pillOverlap: CGFloat = 8.25
        let count = CGFloat(indices.count)
        let pitch = max(0, (rect.width - inset * 2 - pillOverlap) / count)
        let itemWidth = pitch + pillOverlap
        for (position, index) in indices.enumerated() where buttons.indices.contains(index) {
            let originX = nativeNavigationFloatingTabOriginX(
                rectMinX: rect.minX,
                rectWidth: rect.width,
                position: position,
                itemWidth: itemWidth,
                pitch: pitch,
                inset: inset,
                systemLook: true,
                layoutDirection: layoutDirection
            )
            buttons[index].frame = CGRect(
                x: originX,
                y: rect.minY,
                width: itemWidth,
                height: rect.height
            )
        }
    }

    private func layoutButtons(_ indices: [Int], in rect: CGRect) {
        guard !indices.isEmpty else {
            return
        }
        if systemLook && tabbarStyle.shape == .floating {
            layoutSystemLookButtons(indices, in: rect)
            return
        }
        let itemWidth = rect.width / CGFloat(indices.count)
        for (position, index) in indices.enumerated() where buttons.indices.contains(index) {
            let originX = nativeNavigationFloatingTabOriginX(
                rectMinX: rect.minX,
                rectWidth: rect.width,
                position: position,
                itemWidth: itemWidth,
                pitch: itemWidth,
                inset: 0,
                systemLook: false,
                layoutDirection: layoutDirection
            )
            buttons[index].frame = CGRect(
                x: originX,
                y: rect.minY,
                width: itemWidth,
                height: rect.height
            )
        }
    }

    private func centerButtonIndex() -> Int? {
        guard tabbarStyle.shape == .curve, !items.isEmpty else {
            return nil
        }
        if let centerItemId = tabbarStyle.centerItemId,
           let index = items.firstIndex(where: { $0.id == centerItemId }) {
            return index
        }
        return items.count / 2
    }

    private func detachedTrailingIndex() -> Int? {
        guard tabbarStyle.shape == .floating else {
            return nil
        }
        return items.lastIndex(where: \.isDetachedTrailing)
    }

    private func rebuildButtons() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = items.enumerated().map { index, item in
            let button = NativeNavigationFloatingTabButton()
            button.tag = index
            button.configure(
                item: item,
                style: style(for: index)
            )
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            button.labelsCollapsed = minimized
            addSubview(button)
            return button
        }
    }

    private func updateButtons() {
        for (index, button) in buttons.enumerated() {
            guard items.indices.contains(index) else {
                continue
            }
            button.configure(
                item: items[index],
                style: style(for: index)
            )
        }
    }

    private func style(for index: Int) -> NativeNavigationFloatingTabStyle {
        let isCenter = centerButtonIndex() == index
        let isDetachedTrailing = detachedTrailingIndex() == index
        // Detached actions stay icon-only when icons are available; fall back to
        // a label when icons are disabled so the control remains discoverable.
        let detachedShowsLabel = isDetachedTrailing && !iconsVisible && showsLabel(for: index)
        return NativeNavigationFloatingTabStyle(
            selected: index == selectedIndex,
            labels: isDetachedTrailing ? detachedShowsLabel : showsLabel(for: index),
            icons: iconsVisible,
            isCenter: isCenter,
            isDetachedTrailing: isDetachedTrailing,
            selectedTint: selectedTintColor,
            inactiveTint: inactiveTintColor,
            centerButtonColor: tabbarStyle.centerButtonColor ?? selectedTintColor,
            centerButtonIconColor: tabbarStyle.centerButtonIconColor,
            badgeBackgroundColor: badgeBackgroundColor,
            badgeTextColor: badgeTextColor,
            showsSelectionBackground: isCenter || tabbarStyle.shape != .curve,
            systemLook: systemLook
        )
    }

    private func showsLabel(for index: Int) -> Bool {
        switch labelVisibilityMode {
        case "unlabeled":
            return false
        case "selected":
            return index == selectedIndex
        case "auto":
            let compact = traitCollection.horizontalSizeClass == .compact
            return !compact || index == selectedIndex
        default:
            return true
        }
    }

    @objc private func handleTap(_ sender: NativeNavigationFloatingTabButton) {
        let index = sender.tag
        guard items.indices.contains(index), items[index].enabled else {
            return
        }
        selectedIndex = index
        updateButtons()
        onSelect?(index, items[index])
    }
}

private final class NativeNavigationTabbarBackgroundView: UIView {
    var style = NativeNavigationTabbarStyleConfig() {
        didSet { setNeedsDisplay() }
    }
    var fillColor = UIColor.systemBackground.withAlphaComponent(0.46) {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        // Default scaleToFill stretches the last bitmap when the bar widens.
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        fillColor.setFill()
        NativeNavigationTabbarBackgroundPath.path(in: bounds, style: style).fill()
    }
}

private final class NativeNavigationFloatingTabButton: UIControl {
    private let selectedView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let badgeLabel = UILabel()
    private var hasIcon = true
    private var hasLabel = true
    private var isCenterButton = false
    private var badgeText: String?
    private var systemLook = false
    var labelsCollapsed = false {
        didSet {
            guard labelsCollapsed != oldValue else {
                return
            }
            titleLabel.alpha = labelsCollapsed ? 0 : 1
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true

        selectedView.isUserInteractionEnabled = false
        selectedView.alpha = 0
        addSubview(selectedView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        badgeLabel.textAlignment = .center
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = .systemRed
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isUserInteractionEnabled = false
        addSubview(badgeLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        item: NativeNavigationFloatingTabItem,
        style: NativeNavigationFloatingTabStyle
    ) {
        isEnabled = item.enabled
        alpha = item.enabled ? 1 : 0.38
        isCenterButton = style.isCenter
        let isDetachedTrailing = style.isDetachedTrailing
        hasIcon = style.icons && (item.image != nil || item.selectedImage != nil)
        hasLabel = isDetachedTrailing
            ? (!hasIcon && style.labels && !item.title.isEmpty)
            : (style.isCenter ? (!hasIcon && !item.title.isEmpty) : (style.labels && !item.title.isEmpty))
        badgeText = item.badge
        systemLook = style.systemLook

        let inactiveColor = style.systemLook ? UIColor.label : style.inactiveTint
        let color = style.isCenter
            ? style.centerButtonIconColor
            : (style.selected ? style.selectedTint : inactiveColor)
        let selectionColor = style.systemLook ? UIColor.label.withAlphaComponent(0.1) : style.selectedTint.withAlphaComponent(0.16)
        selectedView.backgroundColor = style.isCenter
            ? style.centerButtonColor
            : (style.selected && !isDetachedTrailing ? selectionColor : .clear)
        selectedView.alpha = style.isCenter || (style.selected && style.showsSelectionBackground && !isDetachedTrailing) ? 1 : 0

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = style.isCenter ? 0.2 : 0
        layer.shadowRadius = style.isCenter ? 14 : 0
        layer.shadowOffset = CGSize(width: 0, height: 8)

        let image = style.selected ? (item.selectedImage ?? item.image) : item.image
        imageView.image = image
        imageView.tintColor = color
        imageView.isHidden = !hasIcon

        titleLabel.text = item.title
        titleLabel.textColor = color
        titleLabel.font = style.systemLook
            ? .systemFont(ofSize: 10, weight: .medium)
            : .systemFont(ofSize: style.isCenter ? 12 : 11, weight: style.selected ? .bold : .semibold)
        titleLabel.isHidden = !hasLabel

        badgeLabel.text = item.badge
        badgeLabel.textColor = style.badgeTextColor
        badgeLabel.backgroundColor = style.badgeBackgroundColor
        badgeLabel.isHidden = item.badge == nil || item.badge == "0"
        accessibilityLabel = item.accessibilityTitle
        accessibilityTraits = style.selected ? [.button, .selected] : .button
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isCenterButton {
            selectedView.frame = bounds
        } else if systemLook {
            // The system bar's selection pill fills the item with a small inset.
            selectedView.frame = bounds.insetBy(dx: 0, dy: 4)
        } else {
            let selectedSize = min(58, bounds.height - 6)
            selectedView.frame = CGRect(x: (bounds.width - selectedSize) / 2, y: (bounds.height - selectedSize) / 2, width: selectedSize, height: selectedSize)
        }
        selectedView.layer.cornerRadius = selectedView.bounds.height / 2

        let iconSize: CGFloat = isCenterButton ? 32 : (systemLook ? 26 : 23)
        if isCenterButton || (!hasLabel && hasIcon && bounds.width <= bounds.height + 1) {
            if hasIcon {
                imageView.frame = CGRect(x: (bounds.width - iconSize) / 2, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
                titleLabel.frame = .zero
            } else {
                imageView.frame = .zero
                titleLabel.frame = CGRect(x: 8, y: (bounds.height - 18) / 2, width: bounds.width - 16, height: 18)
            }
        } else if hasIcon && hasLabel && !labelsCollapsed {
            let labelHeight: CGFloat = 14
            let gap: CGFloat = 2
            let stackHeight = iconSize + gap + labelHeight
            // Tall curve cells sit above the home indicator. Keep the label
            // under the icon, not on the bezel.
            let stackY = bounds.height >= 72
                ? max(6, bounds.height - 10 - stackHeight)
                : max(4, (bounds.height - stackHeight) / 2)
            imageView.frame = CGRect(x: (bounds.width - iconSize) / 2, y: stackY, width: iconSize, height: iconSize)
            titleLabel.frame = CGRect(x: 4, y: stackY + iconSize + gap, width: bounds.width - 8, height: labelHeight)
        } else if hasIcon {
            imageView.frame = CGRect(x: (bounds.width - iconSize) / 2, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
            // Keep the folded label under the icon so it fades in place when the bar expands.
            titleLabel.frame = hasLabel ? CGRect(x: 4, y: imageView.frame.maxY + 2, width: bounds.width - 8, height: 14) : .zero
        } else {
            imageView.frame = .zero
            titleLabel.frame = CGRect(x: 5, y: (bounds.height - 18) / 2, width: bounds.width - 10, height: 18)
        }

        let badgeHeight: CGFloat = 18
        let badgeWidth = max(badgeHeight, CGFloat((badgeText ?? "").count * 7 + 11))
        let anchor = hasIcon ? imageView.frame : CGRect(x: bounds.midX - 10, y: bounds.midY - 10, width: 20, height: 20)
        badgeLabel.frame = CGRect(
            x: min(bounds.width - badgeWidth - 8, anchor.midX + 7),
            y: max(6, anchor.minY - 6),
            width: badgeWidth,
            height: badgeHeight
        )
        badgeLabel.layer.cornerRadius = badgeHeight / 2
    }
}

private final class NativeNavigationChromeContainer: UIView {
    var hitSlop = UIEdgeInsets.zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let expandedBounds = bounds.inset(by: UIEdgeInsets(
            top: -hitSlop.top,
            left: -hitSlop.left,
            bottom: -hitSlop.bottom,
            right: -hitSlop.right
        ))
        return expandedBounds.contains(point)
    }
}

private final class NativeNavigationBar: UINavigationBar {
    var hitSlop = UIEdgeInsets.zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let expandedBounds = bounds.inset(by: UIEdgeInsets(
            top: -hitSlop.top,
            left: -hitSlop.left,
            bottom: -hitSlop.bottom,
            right: -hitSlop.right
        ))
        return expandedBounds.contains(point)
    }
}

final class NativeNavigationWeakView {
    weak var value: UIView?

    init(_ value: UIView) {
        self.value = value
    }
}

func nativeNavigationLiftWebViewOverlaySubviews(
    from webView: UIView,
    to container: UIView,
    tracking liftedOverlays: inout [NativeNavigationWeakView],
    excluding excludedViews: [UIView?] = []
) {
    webView.subviews
        .filter { nativeNavigationShouldLiftWebViewOverlay($0, excluding: excludedViews) }
        .forEach { overlay in
            let frame = overlay.convert(overlay.bounds, to: container)
            let hadParentConstraints = nativeNavigationDeactivateParentConstraints(in: webView, involving: overlay)
            overlay.removeFromSuperview()
            overlay.frame = frame
            if hadParentConstraints {
                overlay.translatesAutoresizingMaskIntoConstraints = true
            }
            overlay.autoresizingMask = overlay.autoresizingMask.isEmpty
                ? [.flexibleWidth, .flexibleHeight]
                : overlay.autoresizingMask
            container.addSubview(overlay)
            liftedOverlays.append(NativeNavigationWeakView(overlay))
        }

    liftedOverlays = liftedOverlays.filter { $0.value != nil }
    liftedOverlays
        .compactMap(\.value)
        .filter { $0.superview === container }
        .forEach { container.bringSubviewToFront($0) }
}

func nativeNavigationShouldLiftWebViewOverlay(_ view: UIView, excluding excludedViews: [UIView?] = []) -> Bool {
    if excludedViews.contains(where: { $0 === view }) {
        return false
    }

    if view is UIScrollView {
        return false
    }

    let className = NSStringFromClass(type(of: view))
    return !className.contains("WK")
}

private func nativeNavigationDeactivateParentConstraints(in parent: UIView, involving view: UIView) -> Bool {
    let constraints = parent.constraints.filter { constraint in
        constraint.firstItem === view || constraint.secondItem === view
    }
    NSLayoutConstraint.deactivate(constraints)
    return !constraints.isEmpty
}

final class NativeNavigationTabController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.isOpaque = true
        tabBar.isTranslucent = !UIAccessibility.isReduceTransparencyEnabled
    }
}

final class NativeNavigationTabContentController: UIViewController {
    private weak var hostedWebView: UIView?
    private var snapshotPlaceholder: UIView?

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
        NativeNavigationVerticalBarPreference.disabled ? .disabled : .automatic
    }
    #endif

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.isOpaque = true
        view.clipsToBounds = true
        self.view = view
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard hostedWebView?.superview === view else {
            hostedWebView = nil
            return
        }
        hostedWebView?.frame = view.bounds
    }

    func clearHostedWebView(ifMatching webView: UIView? = nil, preservingSnapshot: Bool = false) {
        guard webView == nil || hostedWebView === webView else {
            return
        }

        if preservingSnapshot, let hostedWebView = hostedWebView, hostedWebView.superview === view {
            let placeholder = hostedWebView.snapshotView(afterScreenUpdates: false) ?? nativeNavigationSnapshotPlaceholder(for: hostedWebView)
            placeholder.frame = hostedWebView.frame
            placeholder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            snapshotPlaceholder?.removeFromSuperview()
            view.insertSubview(placeholder, belowSubview: hostedWebView)
            snapshotPlaceholder = placeholder
        }

        hostedWebView = nil
    }

    @discardableResult
    func host(webView: UIView) -> Bool {
        guard view !== webView, !view.isDescendant(of: webView) else {
            hostedWebView = nil
            return false
        }

        snapshotPlaceholder?.removeFromSuperview()
        snapshotPlaceholder = nil
        hostedWebView = webView
        if webView.superview !== view {
            // addSubview reparents in one step. removeFromSuperview() first
            // leaves a frame of this VC's backing colour (system white).
            view.addSubview(webView)
        }
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.frame = view.bounds
        return true
    }
}

private func nativeNavigationFallbackBackground(for view: UIView) -> UIColor {
    if let color = view.backgroundColor,
       color.cgColor.alpha > 0 {
        return color.withAlphaComponent(1)
    }
    return UIColor.systemBackground.withAlphaComponent(1.0)
}

func nativeNavigationUsesStationaryTransitionCrossfade(direction: String) -> Bool {
    direction == "tab" || direction == "root" || direction == "none"
}

func nativeNavigationPrefersAnimatedSystemTabbarVisibility(
    animated: Bool,
    usesSystemLiquidGlass: Bool,
    shape: String
) -> Bool {
    animated && usesSystemLiquidGlass && shape != "curve"
}

func nativeNavigationTabBarSemanticContentAttribute(layoutDirection: String?) -> UISemanticContentAttribute {
    guard let layoutDirection else {
        return .unspecified
    }
    if layoutDirection == "rtl" {
        return .forceRightToLeft
    }
    if layoutDirection == "ltr" {
        return .forceLeftToRight
    }
    return .unspecified
}

struct NativeNavigationSystemTabBarLayoutDirectionUpdate {
    let tabBarAttribute: UISemanticContentAttribute
    let controllerAttribute: UISemanticContentAttribute?
    let didOverrideController: Bool
}

func nativeNavigationSystemTabBarLayoutDirectionUpdate(
    layoutDirection: String?,
    didOverrideController: Bool
) -> NativeNavigationSystemTabBarLayoutDirectionUpdate {
    let tabBarAttribute = nativeNavigationTabBarSemanticContentAttribute(layoutDirection: layoutDirection)
    if layoutDirection == "rtl" || layoutDirection == "ltr" {
        return NativeNavigationSystemTabBarLayoutDirectionUpdate(
            tabBarAttribute: tabBarAttribute,
            controllerAttribute: tabBarAttribute,
            didOverrideController: true
        )
    }
    if didOverrideController {
        return NativeNavigationSystemTabBarLayoutDirectionUpdate(
            tabBarAttribute: tabBarAttribute,
            controllerAttribute: .unspecified,
            didOverrideController: false
        )
    }
    return NativeNavigationSystemTabBarLayoutDirectionUpdate(
        tabBarAttribute: tabBarAttribute,
        controllerAttribute: nil,
        didOverrideController: false
    )
}

func nativeNavigationFloatingTabOriginX(
    rectMinX: CGFloat,
    rectWidth: CGFloat,
    position: Int,
    itemWidth: CGFloat,
    pitch: CGFloat,
    inset: CGFloat,
    systemLook: Bool,
    layoutDirection: String?
) -> CGFloat {
    let rtl = layoutDirection == "rtl"
    if !rtl {
        if systemLook {
            return rectMinX + inset + CGFloat(position) * pitch
        }
        return rectMinX + CGFloat(position) * itemWidth
    }
    if systemLook {
        return rectMinX + rectWidth - inset - CGFloat(position + 1) * pitch - (itemWidth - pitch)
    }
    return rectMinX + rectWidth - CGFloat(position + 1) * itemWidth
}

struct NativeNavigationTabbarInsetHeights {
    let tabbarHeight: CGFloat
    let systemTabbarHeight: CGFloat
}

func nativeNavigationTabbarInsetHeights(
    isEnabled: Bool,
    tabbarVisible: Bool,
    tabbarSoftHidden: Bool,
    isWebViewHostedInSystemTabController: Bool,
    usesSystemTabbar: Bool,
    nativeTabHeight: CGFloat,
    customTabHeight: CGFloat
) -> NativeNavigationTabbarInsetHeights {
    let tabBarActive = isEnabled && (tabbarVisible || tabbarSoftHidden)
    let overlapHeight = usesSystemTabbar ? nativeTabHeight : customTabHeight
    let tabbarHeight = tabBarActive && !isWebViewHostedInSystemTabController ? overlapHeight : 0
    let systemTabbarHeight = tabBarActive ? overlapHeight : 0
    return NativeNavigationTabbarInsetHeights(tabbarHeight: tabbarHeight, systemTabbarHeight: systemTabbarHeight)
}

private func nativeNavigationNeedsTransitionSurface(_ color: UIColor?) -> Bool {
    guard let color else {
        return true
    }
    return color.cgColor.alpha < 1
}

private func nativeNavigationSnapshotPlaceholder(for view: UIView) -> UIView {
    let placeholder = UIView(frame: view.frame)
    placeholder.backgroundColor = nativeNavigationFallbackBackground(for: view)
    placeholder.isOpaque = true
    return placeholder
}

private final class SVGIconRenderer: NSObject, XMLParserDelegate {
    private let context: CGContext
    private var styleStack = [SVGRenderStyle()]

    init(context: CGContext) {
        self.context = context
    }

    static func render(svg: String, size: CGSize) -> UIImage? {
        guard let data = svg.data(using: .utf8) else {
            return nil
        }

        let viewBox = viewBox(in: svg) ?? CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.saveGState()
            context.scaleBy(x: size.width / max(viewBox.width, 1), y: size.height / max(viewBox.height, 1))
            context.translateBy(x: -viewBox.minX, y: -viewBox.minY)

            let parser = XMLParser(data: data)
            let delegate = SVGIconRenderer(context: context)
            parser.delegate = delegate
            parser.parse()
            context.restoreGState()
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        var style = styleStack.last ?? SVGRenderStyle()
        style.apply(attributeDict)
        styleStack.append(style)

        switch elementName.lowercased() {
        case "path":
            guard let pathData = attributeDict["d"] else {
                return
            }
            draw(SVGPathParser(pathData).parse(), style: style)
        case "line":
            let path = UIBezierPath()
            path.move(to: CGPoint(x: Self.length(attributeDict["x1"]) ?? 0, y: Self.length(attributeDict["y1"]) ?? 0))
            path.addLine(to: CGPoint(x: Self.length(attributeDict["x2"]) ?? 0, y: Self.length(attributeDict["y2"]) ?? 0))
            draw(path, style: style)
        case "polyline", "polygon":
            let points = Self.points(attributeDict["points"])
            guard let first = points.first else {
                return
            }
            let path = UIBezierPath()
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            if elementName.lowercased() == "polygon" {
                path.close()
            }
            draw(path, style: style)
        case "circle":
            let cx = Self.length(attributeDict["cx"]) ?? 0
            let cy = Self.length(attributeDict["cy"]) ?? 0
            let radius = Self.length(attributeDict["r"]) ?? 0
            draw(UIBezierPath(ovalIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)), style: style)
        case "rect":
            let rect = CGRect(
                x: Self.length(attributeDict["x"]) ?? 0,
                y: Self.length(attributeDict["y"]) ?? 0,
                width: Self.length(attributeDict["width"]) ?? 0,
                height: Self.length(attributeDict["height"]) ?? 0
            )
            let radius = Self.length(attributeDict["rx"]) ?? Self.length(attributeDict["ry"]) ?? 0
            let path = radius > 0 ? UIBezierPath(roundedRect: rect, cornerRadius: radius) : UIBezierPath(rect: rect)
            draw(path, style: style)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if styleStack.count > 1 {
            styleStack.removeLast()
        }
    }

    private func draw(_ path: UIBezierPath, style: SVGRenderStyle) {
        context.saveGState()
        path.lineWidth = style.strokeWidth
        path.lineCapStyle = style.lineCap
        path.lineJoinStyle = style.lineJoin
        UIColor.black.withAlphaComponent(style.opacity).setFill()
        UIColor.black.withAlphaComponent(style.opacity).setStroke()
        if style.fill {
            path.fill()
        }
        if style.stroke {
            path.stroke()
        }
        context.restoreGState()
    }

    static func length(_ value: String?) -> CGFloat? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        let allowed = CharacterSet(charactersIn: "-+.0123456789eE")
        let prefix = String(value.unicodeScalars.prefix { allowed.contains($0) })
        guard let double = Double(prefix) else {
            return nil
        }
        return CGFloat(double)
    }

    static func points(_ value: String?) -> [CGPoint] {
        let numbers = numbers(in: value ?? "")
        var points: [CGPoint] = []
        var index = 0
        while index + 1 < numbers.count {
            points.append(CGPoint(x: numbers[index], y: numbers[index + 1]))
            index += 2
        }
        return points
    }

    private static func viewBox(in svg: String) -> CGRect? {
        if let rawViewBox = attribute("viewBox", in: svg) {
            let values = numbers(in: rawViewBox)
            if values.count >= 4 {
                return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
            }
        }
        guard let width = length(attribute("width", in: svg)),
              let height = length(attribute("height", in: svg)) else {
            return nil
        }
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    private static func attribute(_ name: String, in svg: String) -> String? {
        let pattern = "\(name)\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(svg.startIndex..<svg.endIndex, in: svg)
        guard let match = expression.firstMatch(in: svg, range: range),
              let valueRange = Range(match.range(at: 1), in: svg) else {
            return nil
        }
        return String(svg[valueRange])
    }

    private static func numbers(in value: String) -> [CGFloat] {
        let pattern = "[-+]?(?:\\d*\\.\\d+|\\d+\\.?)(?:[eE][-+]?\\d+)?"
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        var values: [CGFloat] = []
        for match in expression.matches(in: value, range: range) {
            if let valueRange = Range(match.range, in: value),
               let double = Double(value[valueRange]) {
                values.append(CGFloat(double))
            }
        }
        return values
    }
}

private final class SVGPathParser {
    private let tokens: [String]
    private var index = 0
    private var command: Character?
    private var current = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControl: CGPoint?
    private var lastQuadControl: CGPoint?

    init(_ data: String) {
        tokens = Self.tokenize(data)
    }

    func parse() -> UIBezierPath {
        let path = UIBezierPath()
        while index < tokens.count {
            if let nextCommand = commandToken() {
                command = nextCommand
                index += 1
            }
            guard let command = command else {
                break
            }
            consume(command, into: path)
        }
        return path
    }

    private func consume(_ command: Character, into path: UIBezierPath) {
        let relative = command.isLowercase
        switch command.uppercased() {
        case "M":
            guard let firstPoint = point(relative: relative) else {
                return
            }
            path.move(to: firstPoint)
            current = firstPoint
            subpathStart = firstPoint
            while let nextPoint = point(relative: relative) {
                path.addLine(to: nextPoint)
                current = nextPoint
            }
            resetControls()
        case "L":
            while let nextPoint = point(relative: relative) {
                path.addLine(to: nextPoint)
                current = nextPoint
            }
            resetControls()
        case "H":
            while let value = number() {
                current = CGPoint(x: relative ? current.x + value : value, y: current.y)
                path.addLine(to: current)
            }
            resetControls()
        case "V":
            while let value = number() {
                current = CGPoint(x: current.x, y: relative ? current.y + value : value)
                path.addLine(to: current)
            }
            resetControls()
        case "C":
            while let control1 = point(relative: relative),
                  let control2 = point(relative: relative),
                  let end = point(relative: relative) {
                path.addCurve(to: end, controlPoint1: control1, controlPoint2: control2)
                current = end
                lastCubicControl = control2
                lastQuadControl = nil
            }
        case "S":
            while let control2 = point(relative: relative),
                  let end = point(relative: relative) {
                let control1 = reflected(lastCubicControl)
                path.addCurve(to: end, controlPoint1: control1, controlPoint2: control2)
                current = end
                lastCubicControl = control2
                lastQuadControl = nil
            }
        case "Q":
            while let control = point(relative: relative),
                  let end = point(relative: relative) {
                path.addQuadCurve(to: end, controlPoint: control)
                current = end
                lastQuadControl = control
                lastCubicControl = nil
            }
        case "T":
            while let end = point(relative: relative) {
                let control = reflected(lastQuadControl)
                path.addQuadCurve(to: end, controlPoint: control)
                current = end
                lastQuadControl = control
                lastCubicControl = nil
            }
        case "A":
            while let arc = arcSegment(relative: relative) {
                nativeNavigationAddSVGArc(
                    to: path,
                    from: current,
                    to: arc.end,
                    radii: arc.radii,
                    rotation: arc.rotation,
                    largeArc: arc.largeArc,
                    sweep: arc.sweep
                )
                current = arc.end
            }
            resetControls()
        case "Z":
            path.close()
            current = subpathStart
            resetControls()
        default:
            index += 1
        }
    }

    private func point(relative: Bool) -> CGPoint? {
        guard let x = number(),
              let y = number() else {
            return nil
        }
        return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    }

    private func arcSegment(relative: Bool) -> NativeNavigationSVGArc? {
        guard let radiusX = number(),
              let radiusY = number(),
              let rotation = number(),
              let largeArc = number(),
              let sweep = number(),
              let x = number(),
              let y = number() else {
            return nil
        }
        let end = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        return NativeNavigationSVGArc(
            radii: CGSize(width: radiusX, height: radiusY),
            rotation: rotation,
            largeArc: largeArc != 0,
            sweep: sweep != 0,
            end: end
        )
    }

    private func number() -> CGFloat? {
        guard index < tokens.count,
              commandToken() == nil,
              let value = Double(tokens[index]) else {
            return nil
        }
        index += 1
        return CGFloat(value)
    }

    private func commandToken() -> Character? {
        guard index < tokens.count,
              tokens[index].count == 1,
              let character = tokens[index].first,
              character.isLetter else {
            return nil
        }
        return character
    }

    private func reflected(_ point: CGPoint?) -> CGPoint {
        guard let point = point else {
            return current
        }
        return CGPoint(x: current.x * 2 - point.x, y: current.y * 2 - point.y)
    }

    private func resetControls() {
        lastCubicControl = nil
        lastQuadControl = nil
    }

    private static func tokenize(_ data: String) -> [String] {
        var tokens: [String] = []
        var index = data.startIndex
        while index < data.endIndex {
            let character = data[index]
            if character.isWhitespace || character == "," {
                index = data.index(after: index)
                continue
            }
            if character.isLetter {
                tokens.append(String(character))
                index = data.index(after: index)
                continue
            }

            let start = index
            var end = index
            var hasDigits = false

            if data[end] == "-" || data[end] == "+" {
                end = data.index(after: end)
            }

            while end < data.endIndex, data[end].isNumber {
                hasDigits = true
                end = data.index(after: end)
            }

            if end < data.endIndex, data[end] == "." {
                end = data.index(after: end)
                while end < data.endIndex, data[end].isNumber {
                    hasDigits = true
                    end = data.index(after: end)
                }
            }

            if hasDigits, end < data.endIndex, data[end] == "e" || data[end] == "E" {
                let exponentStart = end
                var exponentEnd = data.index(after: end)
                if exponentEnd < data.endIndex, data[exponentEnd] == "-" || data[exponentEnd] == "+" {
                    exponentEnd = data.index(after: exponentEnd)
                }
                var hasExponentDigits = false
                while exponentEnd < data.endIndex, data[exponentEnd].isNumber {
                    hasExponentDigits = true
                    exponentEnd = data.index(after: exponentEnd)
                }
                if hasExponentDigits {
                    end = exponentEnd
                } else {
                    end = exponentStart
                }
            }

            if hasDigits, end > start {
                tokens.append(String(data[start..<end]))
                index = end
            } else {
                index = data.index(after: index)
            }
        }
        return tokens
    }
}
// swiftlint:enable cyclomatic_complexity function_body_length identifier_name

private extension UIColor {
    convenience init?(hexString: String) {
        var value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        var hex: UInt64 = 0
        guard Scanner(string: value).scanHexInt64(&hex) else {
            return nil
        }

        switch value.count {
        case 6:
            self.init(
                red: CGFloat((hex & 0xFF0000) >> 16) / 255,
                green: CGFloat((hex & 0x00FF00) >> 8) / 255,
                blue: CGFloat(hex & 0x0000FF) / 255,
                alpha: 1
            )
        case 8:
            self.init(
                red: CGFloat((hex & 0x00FF0000) >> 16) / 255,
                green: CGFloat((hex & 0x0000FF00) >> 8) / 255,
                blue: CGFloat(hex & 0x000000FF) / 255,
                alpha: CGFloat((hex & 0xFF000000) >> 24) / 255
            )
        default:
            return nil
        }
    }
}
