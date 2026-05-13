// swiftlint:disable file_length

import Foundation
import Capacitor
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
        CAPPluginMethod(name: "setTabbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "beginTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "finishTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = NativeNavigation()
    private var navContainer: UIView?
    private var navBlurView: UIVisualEffectView?
    private var navBar: UINavigationBar?
    private var tabContainer: UIView?
    private var tabEffectView: UIVisualEffectView?
    private var tabBar: UITabBar?
    private var tabBarController: NativeNavigationTabController?
    private var tabViewControllers: [UIViewController] = []
    private weak var systemTabRootContainer: UIView?
    private weak var originalWebViewSuperview: UIView?
    private var originalWebViewIndex: Int?
    private var originalWebViewAutoresizingMask: UIView.AutoresizingMask?
    private var liftedWebViewOverlays: [NativeNavigationWeakView] = []
    private var isWebViewHostedInSystemTabController = false
    private var navbarHeight: CGFloat = 44
    private var tabbarHeight: CGFloat = 64
    private let floatingTabbarHorizontalMargin: CGFloat = 24
    private let floatingTabbarMaxWidth: CGFloat = 430
    private let floatingTabbarBottomGap: CGFloat = 10
    private var navbarVisible = false
    private var tabbarVisible = false
    private var contentInsetMode = "css"
    private var isEnabled = true
    private var defaultTransitionDuration: TimeInterval = 0.35
    private var navbarItemPlacement: [String: String] = [:]
    private var navbarItemTitle: [String: String] = [:]
    private var tabIds: [String] = []
    private var tabTitles: [String] = []
    private var suppressTabSelectEvent = false
    private var transitionSnapshot: UIView?
    private var activeTransitionId: String?
    private var activeTransitionDirection = "forward"
    private var activeZoomSourceFrame: CGRect?
    private var activeZoomCornerRadius: CGFloat = 0
    private weak var activeTransitionContainer: UIView?
    private var activeTransitionContainerBackgroundColor: UIColor?
    private var activeTransitionContainerWasOpaque = false
    private var activeTransitionContainerBackgroundCaptured = false

    private var usesSystemLiquidGlass: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    override public func load() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLayoutChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
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
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            let hidden = call.getBool("hidden", false)
            self.navbarVisible = !hidden
            let animated = call.getBool("animated", false)
            let large = call.getBool("large", false)
            self.navbarHeight = large ? 96 : 44

            guard !hidden else {
                self.navContainer?.isHidden = true
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            let navBar = self.ensureNavBar()
            let navItem = UINavigationItem(title: call.getString("title") ?? "")
            navItem.prompt = call.getString("subtitle")
            if #available(iOS 11.0, *) {
                navBar.prefersLargeTitles = large
                navItem.largeTitleDisplayMode = large ? .always : .never
            }

            self.navbarItemPlacement.removeAll()
            self.navbarItemTitle.removeAll()

            if let backButton = call.getObject("backButton"), backButton["visible"] as? Bool == true {
                let title = backButton["title"] as? String
                let item = UIBarButtonItem(title: title ?? "Back", style: .plain, target: self, action: #selector(self.handleNavbarBack))
                self.configureGlassBarButtonItem(item, id: "back")
                navItem.leftBarButtonItem = item
            } else {
                navItem.leftBarButtonItems = self.makeBarButtonItems(call.getArray("leftItems") as? [[String: Any]] ?? [], placement: "left")
            }

            navItem.rightBarButtonItems = self.makeBarButtonItems(call.getArray("rightItems") as? [[String: Any]] ?? [], placement: "right")
            navBar.setItems([navItem], animated: animated)
            self.applyNavBarAppearance(navBar: navBar, options: call)
            self.navContainer?.isHidden = false
            self.layoutChrome()
            self.updateInsetsAndNotify()
            call.resolve(self.insetsResult())
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
            self.tabbarVisible = !hidden

            guard !hidden else {
                self.hideTabBarChrome()
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            let tabBar = self.ensureTabBar()
            let tabs = call.getArray("tabs") as? [[String: Any]] ?? []
            let selectedId = call.getString("selectedId")
            let labels = call.getBool("labels", true)
            let labelVisibilityMode = call.getString("labelVisibilityMode") ?? (labels ? "labeled" : "unlabeled")
            let icons = call.getBool("icons", true)

            let (items, selectedIndex) = self.makeTabBarItems(
                tabs,
                selectedId: selectedId,
                labelVisibilityMode: labelVisibilityMode,
                icons: icons
            )

            if self.usesSystemLiquidGlass {
                self.applySystemTabBarItems(items, selectedIndex: selectedIndex, animated: call.getBool("animated", false))
            } else {
                tabBar.items = items
                if let selectedIndex = selectedIndex, selectedIndex < items.count {
                    tabBar.selectedItem = items[selectedIndex]
                } else if tabBar.selectedItem == nil {
                    tabBar.selectedItem = items.first
                }
            }

            self.applyTabBarAppearance(tabBar: tabBar, options: call)
            self.showTabBarChrome(tabBar)
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
            let transitionSurface = nativeNavigationFallbackBackground(for: webView)
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

    public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        notifyTabSelect(index: item.tag)
    }

    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if usesSystemLiquidGlass {
            hostWebView(in: viewController)
        }
        return true
    }

    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard !suppressTabSelectEvent else {
            hostWebViewInSelectedSystemTab()
            return
        }
        let index = tabBarController.viewControllers?.firstIndex(of: viewController) ?? viewController.tabBarItem.tag
        hostWebViewInSelectedSystemTab()
        notifyTabSelect(index: index)
    }

    private func notifyTabSelect(index: Int) {
        guard index >= 0 && index < tabIds.count else {
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

    private func ensureSystemTabBar() -> UITabBar {
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
        if shouldUpdateControllers {
            tabBarController.setViewControllers(controllers, animated: shouldAnimate)
        }
        if !controllers.isEmpty {
            let fallbackIndex = selectedIndex ?? previousSelectedIndex
            let index = min(max(fallbackIndex, 0), controllers.count - 1)
            hostWebView(in: controllers[index])
            tabBarController.selectedIndex = index
        }
        suppressTabSelectEvent = false

        tabViewControllers = controllers
    }

    private func systemTabContentControllers(for items: [UITabBarItem]) -> [UIViewController] {
        let existingControllers = tabViewControllers.compactMap { $0 as? NativeNavigationTabContentController }
        if existingControllers.count == items.count {
            zip(existingControllers, items).forEach { controller, item in
                controller.tabBarItem = item
            }
            return existingControllers
        }

        return items.map { item -> UIViewController in
            let controller = NativeNavigationTabContentController()
            controller.tabBarItem = item
            return controller
        }
    }

    private func setSystemTabBarHidden(_ hidden: Bool) {
        guard let tabBarController = tabBarController else {
            return
        }

        if #available(iOS 18.0, *) {
            tabBarController.setTabBarHidden(hidden, animated: false)
        } else {
            tabBarController.tabBar.isHidden = hidden
        }
    }

    private func hideTabBarChrome() {
        if usesSystemLiquidGlass {
            setSystemTabBarHidden(true)
            tabBarController?.view.isHidden = false
            hostWebViewInSelectedSystemTab()
        } else {
            tabContainer?.isHidden = true
            tabBar?.isHidden = true
        }
    }

    private func showTabBarChrome(_ tabBar: UITabBar) {
        tabContainer?.isHidden = false
        tabBarController?.view.isHidden = false
        if usesSystemLiquidGlass {
            setSystemTabBarHidden(false)
            liftWebViewOverlaysAboveSystemTabs()
            hostWebViewInSelectedSystemTab()
        } else {
            tabBar.isHidden = false
        }
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
              let selectedController = viewController as? NativeNavigationTabContentController else {
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
            .compactMap { $0 as? NativeNavigationTabContentController }
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
        var selectedIndex: Int?

        let items = tabs.enumerated().map { index, tab -> UITabBarItem in
            let id = tab["id"] as? String ?? "tab-\(index)"
            let title = tabTitle(
                tab["title"] as? String,
                id: id,
                index: index,
                selectedId: selectedId,
                labelVisibilityMode: labelVisibilityMode
            )
            let image = icons ? self.image(from: tab["icon"] as? [String: Any]) : nil
            let selectedImage = icons ? self.image(from: tab["selectedIcon"] as? [String: Any]) : nil
            let item = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
            item.tag = index
            item.isEnabled = tab["enabled"] as? Bool ?? true
            if let badge = tab["badge"] {
                item.badgeValue = String(describing: badge)
            }
            tabIds.append(id)
            tabTitles.append(tab["title"] as? String ?? "")
            if id == selectedId {
                selectedIndex = index
            }
            return item
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
            let compact = bridge?.viewController?.traitCollection.horizontalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone
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

        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
    }

    private func applyTabBarAppearance(tabBar: UITabBar, options call: CAPPluginCall) {
        if usesSystemLiquidGlass {
            let standardAppearance = UITabBarAppearance()
            configureSystemTabBarStandardBackground(standardAppearance)
            applyTabBarColorOptions(standardAppearance, tabBar: tabBar, options: call)
            applyTabBarBadgeOptions(standardAppearance, options: call)

            let scrollEdgeAppearance = UITabBarAppearance()
            configureSystemTabBarScrollEdgeBackground(scrollEdgeAppearance, options: call)
            applyTabBarColorOptions(scrollEdgeAppearance, tabBar: tabBar, options: call)
            applyTabBarBadgeOptions(scrollEdgeAppearance, options: call)

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
        if call.getBool("disableTransparentOnScrollEdge", false) {
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
            if let color = colorValue(colors["inactiveTint"]) {
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

    private func applyTabItemAppearances(
        _ appearance: UITabBarAppearance,
        update: (UITabBarItemAppearance) -> Void
    ) {
        update(appearance.stackedLayoutAppearance)
        update(appearance.inlineLayoutAppearance)
        update(appearance.compactInlineLayoutAppearance)
    }

    private func layoutChrome() {
        guard let rootView = bridge?.viewController?.view else {
            return
        }
        rootView.layoutIfNeeded()
        let safeInsets = rootView.safeAreaInsets
        let width = rootView.bounds.width
        let height = rootView.bounds.height

        if let container = navContainer {
            container.frame = CGRect(x: 0, y: 0, width: width, height: safeInsets.top + navbarHeight)
            navBlurView?.frame = container.bounds
            navBar?.frame = CGRect(x: 0, y: safeInsets.top, width: width, height: navbarHeight)
        }

        if let container = tabContainer {
            let availableWidth = max(0, width - (floatingTabbarHorizontalMargin * 2))
            let tabbarWidth = min(availableWidth, floatingTabbarMaxWidth)
            let originX = (width - tabbarWidth) / 2
            let originY = height - safeInsets.bottom - floatingTabbarBottomGap - tabbarHeight
            container.frame = CGRect(x: originX, y: originY, width: tabbarWidth, height: tabbarHeight)
            container.layer.cornerRadius = tabbarHeight / 2
            container.layer.shadowPath = UIBezierPath(roundedRect: container.bounds, cornerRadius: tabbarHeight / 2).cgPath
            tabEffectView?.frame = container.bounds
            tabEffectView?.layer.cornerRadius = tabbarHeight / 2
            tabBar?.frame = container.bounds
            tabBar?.layer.cornerRadius = tabbarHeight / 2
        }

        if let tabBarController = tabBarController {
            tabBarController.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
        }

        bringChromeToFront()
    }

    private func bringChromeToFront() {
        if usesSystemLiquidGlass {
            if let navContainer = navContainer {
                bridge?.viewController?.view.bringSubviewToFront(navContainer)
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

    private func configureGlassBarButtonItem(_ item: UIBarButtonItem, id: String) {
        guard #available(iOS 26.0, *) else {
            return
        }

        // Keep older SDK builds working while adopting the native iOS 26 bar
        // button Liquid Glass grouping APIs when the runtime exposes them.
        let object = item as NSObject
        if object.responds(to: NSSelectorFromString("setIdentifier:")) {
            object.setValue(id, forKey: "identifier")
        }
        if object.responds(to: NSSelectorFromString("setSharesBackground:")) {
            object.setValue(true, forKey: "sharesBackground")
        }
        if object.responds(to: NSSelectorFromString("setHidesSharedBackground:")) {
            object.setValue(false, forKey: "hidesSharedBackground")
        }
    }

    private func currentInsets() -> [String: Any] {
        let safeInsets = bridge?.viewController?.view.safeAreaInsets ?? .zero
        let navHeight = isEnabled && navbarVisible ? navbarHeight + safeInsets.top : 0
        let nativeTabHeight = max(tabBar?.frame.height ?? 0, 49 + safeInsets.bottom)
        let tabHeight = isEnabled && tabbarVisible
            ? (usesSystemLiquidGlass ? nativeTabHeight : tabbarHeight + safeInsets.bottom + floatingTabbarBottomGap)
            : 0
        return [
            "top": navHeight,
            "right": safeInsets.right,
            "bottom": tabHeight,
            "left": safeInsets.left,
            "navbarHeight": navHeight,
            "tabbarHeight": tabHeight
        ]
    }

    private func insetsResult() -> [String: Any] {
        return ["insets": currentInsets()]
    }

    private func updateInsetsAndNotify() {
        layoutChrome()
        let insets = currentInsets()
        notifyListeners("safeAreaChanged", data: ["insets": insets])
        guard contentInsetMode != "none" else {
            return
        }
        let top = insets["top"] as? CGFloat ?? 0
        let right = insets["right"] as? CGFloat ?? 0
        let bottom = insets["bottom"] as? CGFloat ?? 0
        let left = insets["left"] as? CGFloat ?? 0
        let navbar = insets["navbarHeight"] as? CGFloat ?? 0
        let tabbar = insets["tabbarHeight"] as? CGFloat ?? 0
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
          window.dispatchEvent(new CustomEvent('capNativeNavigation:safeAreaChanged', { detail: \(detailJson) }));
        })();
        """
        bridge?.webView?.evaluateJavaScript(script)
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
        tabBar.isTranslucent = true
    }
}

final class NativeNavigationTabContentController: UIViewController {
    private weak var hostedWebView: UIView?
    private var snapshotPlaceholder: UIView?

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.isOpaque = true
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
            webView.removeFromSuperview()
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
        return color
    }
    return .systemBackground
}

func nativeNavigationUsesStationaryTransitionCrossfade(direction: String) -> Bool {
    direction == "tab" || direction == "root" || direction == "none"
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
            while let end = arcEndpoint(relative: relative) {
                path.addLine(to: end)
                current = end
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

    private func arcEndpoint(relative: Bool) -> CGPoint? {
        guard number() != nil,
              number() != nil,
              number() != nil,
              number() != nil,
              number() != nil,
              let x = number(),
              let y = number() else {
            return nil
        }
        return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
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
